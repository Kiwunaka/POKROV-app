//go:build linux

package service

import (
	"encoding/binary"
	"errors"
	"syscall"
	"time"
)

// Route/link/address notifications invalidate a sampled ref even if the
// physical state returns to the same bytes before the next sample. The owned
// POKROV route table and TUN are excluded from this observer.
func (observer *networkContextObserver) startEvents() error {
	const groups = syscall.RTMGRP_LINK | syscall.RTMGRP_IPV4_IFADDR |
		syscall.RTMGRP_IPV4_ROUTE | syscall.RTMGRP_IPV6_IFADDR | syscall.RTMGRP_IPV6_ROUTE
	fd, err := syscall.Socket(syscall.AF_NETLINK, syscall.SOCK_RAW|syscall.SOCK_CLOEXEC, syscall.NETLINK_ROUTE)
	if err != nil { return err }
	if err = syscall.SetNonblock(fd, true); err == nil {
		err = syscall.Bind(fd, &syscall.SockaddrNetlink{Family: syscall.AF_NETLINK, Groups: groups})
	}
	if err != nil {
		_ = syscall.Close(fd)
		return err
	}
	if err := observer.startNetworkManagerSignals(); err != nil {
		_ = syscall.Close(fd)
		return err
	}
	observer.socket = fd
	observer.stop = make(chan struct{})
	go observer.watchEvents(fd, observer.stop)
	return nil
}

func (observer *networkContextObserver) watchEvents(fd int, stop <-chan struct{}) {
	ticker := time.NewTicker(100 * time.Millisecond)
	defer ticker.Stop()
	buffer := make([]byte, 64*1024)
	for {
		count, _, err := syscall.Recvfrom(fd, buffer, 0)
		if errors.Is(err, syscall.EAGAIN) || errors.Is(err, syscall.EINTR) {
			select {
			case <-stop: return
			case <-ticker.C: continue
			}
		}
		if err != nil || count <= 0 || count == len(buffer) {
			observer.eventsFailed()
			return
		}
		messages, err := syscall.ParseNetlinkMessage(buffer[:count])
		if err != nil { observer.eventsFailed(); return }
		for _, message := range messages {
			observer.mu.Lock()
			if observer.closed { observer.mu.Unlock(); return }
			if message.Header.Type == syscall.NLMSG_ERROR || message.Header.Type == syscall.NLMSG_OVERRUN {
				observer.mu.Unlock()
				observer.eventsFailed()
				return
			}
			invalidated := observer.networkEventChanged(message)
			if invalidated {
				observer.reference = ""
				observer.eventRevision++
			}
			changed := observer.onChange
			observer.mu.Unlock()
			if invalidated && changed != nil { changed() }
		}
	}
}

func (observer *networkContextObserver) eventsFailed() {
	observer.mu.Lock()
	if observer.closed { observer.mu.Unlock(); return }
	observer.failed = true
	observer.reference = ""
	observer.eventRevision++
	observer.nmPaths = nil
	if observer.busCancel != nil {
		observer.busCancel()
		observer.busCancel = nil
	}
	if observer.stop != nil {
		close(observer.stop)
		observer.stop = nil
		_ = syscall.Close(observer.socket)
		observer.socket = -1
	}
	changed := observer.onChange
	observer.mu.Unlock()
	if changed != nil { changed() }
}

func (observer *networkContextObserver) networkEventChanged(message syscall.NetlinkMessage) bool {
	switch message.Header.Type {
	case syscall.RTM_NEWLINK, syscall.RTM_DELLINK,
		syscall.RTM_NEWADDR, syscall.RTM_DELADDR:
		if len(message.Data) < 8 { return true }
		index := binary.NativeEndian.Uint32(message.Data[4:8])
		// The first sample has no selected ifindex yet. Fail closed if a
		// link changes while that sample is being assembled.
		if len(observer.interfaces) == 0 { return true }
		_, selected := observer.interfaces[index]
		return selected
	case syscall.RTM_NEWROUTE, syscall.RTM_DELROUTE:
		return physicalDefaultRouteEvent(message.Data)
	default:
		return false
	}
}

func physicalDefaultRouteEvent(data []byte) bool {
	if len(data) < 12 { return true }
	if data[1] != 0 { return false } // Only default routes are sampled.
	table := uint32(data[4])
	for attributes := data[12:]; len(attributes) > 0; {
		if len(attributes) < 4 { return true }
		length := int(binary.NativeEndian.Uint16(attributes[:2]))
		if length < 4 || length > len(attributes) { return true }
		if binary.NativeEndian.Uint16(attributes[2:4]) == syscall.RTA_TABLE {
			if length != 8 { return true }
			table = binary.NativeEndian.Uint32(attributes[4:8])
		}
		aligned := (length + 3) &^ 3
		if aligned > len(attributes) { return true }
		attributes = attributes[aligned:]
	}
	return table != 20555 // POKROV's owned route table; never a physical default.
}

func (observer *networkContextObserver) Close() {
	observer.mu.Lock()
	defer observer.mu.Unlock()
	if observer.closed { return }
	observer.closed = true
	observer.reference = ""
	observer.eventRevision++
	observer.interfaces = nil
	observer.nmPaths = nil
	if observer.busCancel != nil {
		observer.busCancel()
		observer.busCancel = nil
	}
	if observer.stop != nil {
		close(observer.stop)
		_ = syscall.Close(observer.socket)
		observer.stop = nil
		observer.socket = -1
	}
}
