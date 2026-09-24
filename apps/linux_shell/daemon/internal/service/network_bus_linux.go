//go:build linux

package service

import (
	"bufio"
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"io"
	"net"
	"os"
	"os/exec"
	"strconv"
	"strings"
	"time"
)

// busctl reports readiness after BecomeMonitor succeeds. Waiting for that
// receipt before sampling closes the gap between the sample and subscription.
func (observer *networkContextObserver) startNetworkManagerSignals() error {
	var nonce [16]byte
	if _, err := rand.Read(nonce[:]); err != nil { return errors.New("network signals unavailable") }
	address := "@pokrov-network-" + hex.EncodeToString(nonce[:])
	notify, err := net.ListenUnixgram("unixgram", &net.UnixAddr{Name: address, Net: "unixgram"})
	if err != nil { return errors.New("network signals unavailable") }
	defer notify.Close()

	ctx, cancel := context.WithCancel(context.Background())
	command := exec.CommandContext(ctx, "/usr/bin/busctl", "--system", "--json=short", "--no-pager",
		"--match=type='signal',sender='org.freedesktop.NetworkManager',path_namespace='/org/freedesktop/NetworkManager'",
		"--match=type='signal',sender='org.freedesktop.resolve1',path_namespace='/org/freedesktop/resolve1/link'",
		"--match=type='signal',sender='org.freedesktop.DBus',member='NameOwnerChanged',arg0='org.freedesktop.NetworkManager'",
		"--match=type='signal',sender='org.freedesktop.DBus',member='NameOwnerChanged',arg0='org.freedesktop.resolve1'",
		"monitor")
	command.Env = append(os.Environ(), "NOTIFY_SOCKET="+address)
	command.Stderr = io.Discard
	stdout, err := command.StdoutPipe()
	if err != nil { cancel(); return errors.New("network signals unavailable") }
	if err := command.Start(); err != nil { cancel(); return errors.New("network signals unavailable") }
	go observer.watchNetworkManagerSignals(ctx, cancel, command, stdout)
	_ = notify.SetReadDeadline(time.Now().Add(2 * time.Second))
	var receipt [128]byte
	count, _, err := notify.ReadFromUnix(receipt[:])
	if err != nil || !strings.Contains(string(receipt[:count]), "READY=1") {
		cancel()
		return errors.New("network signals unavailable")
	}
	observer.busCancel = cancel
	return nil
}

func (observer *networkContextObserver) watchNetworkManagerSignals(ctx context.Context, cancel context.CancelFunc, command *exec.Cmd, output io.Reader) {
	defer func() { cancel(); _ = command.Wait() }()
	scanner := bufio.NewScanner(output)
	scanner.Buffer(make([]byte, 4096), 64*1024)
	for scanner.Scan() {
		var signal networkManagerSignal
		if json.Unmarshal(scanner.Bytes(), &signal) != nil { observer.eventsFailed(); return }
		observer.mu.Lock()
		if observer.closed || observer.failed { observer.mu.Unlock(); return }
		changed, err := signal.invalidates(observer.nmPaths, observer.interfaces)
		if changed {
			observer.reference = ""
			observer.eventRevision++
		}
		callback := observer.onChange
		observer.mu.Unlock()
		if err != nil { observer.eventsFailed(); return }
		if changed && callback != nil { callback() }
	}
	if ctx.Err() == nil { observer.eventsFailed() }
}

type networkManagerSignal struct {
	Type string `json:"type"`
	Path string `json:"path"`
	Interface string `json:"interface"`
	Member string `json:"member"`
	Payload struct { Data []json.RawMessage `json:"data"` } `json:"payload"`
}

func (signal networkManagerSignal) invalidates(selected map[string]struct{}, interfaces map[uint32]struct{}) (bool, error) {
	if signal.Type != "signal" { return false, nil }
	if signal.Interface == "org.freedesktop.DBus" && signal.Member == "NameOwnerChanged" {
		if len(signal.Payload.Data) < 1 { return false, errors.New("network signal invalid") }
		var name string
		if json.Unmarshal(signal.Payload.Data[0], &name) != nil { return false, errors.New("network signal invalid") }
		return name == "org.freedesktop.NetworkManager" || name == "org.freedesktop.resolve1", nil
	}
	const resolveLinkPrefix = "/org/freedesktop/resolve1/link/_"
	if strings.HasPrefix(signal.Path, resolveLinkPrefix) {
		index, err := strconv.ParseUint(strings.TrimPrefix(signal.Path, resolveLinkPrefix), 10, 32)
		if err != nil { return true, nil } // Unknown selected-link format cannot preserve a ref.
		if len(interfaces) == 0 { return true, nil }
		_, relevant := interfaces[uint32(index)]
		return relevant, nil
	}
	if !strings.HasPrefix(signal.Path, "/org/freedesktop/NetworkManager/") { return false, nil }
	if len(selected) == 0 { return true, nil }
	if _, ok := selected[signal.Path]; !ok { return false, nil }
	if signal.Member == "StateChanged" { return true, nil }
	if signal.Interface != "org.freedesktop.DBus.Properties" || signal.Member != "PropertiesChanged" { return false, nil }
	if len(signal.Payload.Data) != 3 { return false, errors.New("network signal invalid") }
	var iface string
	var properties map[string]json.RawMessage
	var invalidated []string
	if json.Unmarshal(signal.Payload.Data[0], &iface) != nil ||
		json.Unmarshal(signal.Payload.Data[1], &properties) != nil ||
		json.Unmarshal(signal.Payload.Data[2], &invalidated) != nil {
		return false, errors.New("network signal invalid")
	}
	for name := range properties {
		if networkManagerPropertyRelevant(iface, name) { return true, nil }
	}
	for _, name := range invalidated {
		if networkManagerPropertyRelevant(iface, name) { return true, nil }
	}
	return false, nil
}

func networkManagerPropertyRelevant(iface, name string) bool {
	switch iface {
	case "org.freedesktop.NetworkManager.Device":
		switch name {
		case "State", "ActiveConnection", "Ip4Config", "Ip6Config", "Mtu", "HwAddress", "Interface", "IpInterface": return true
		}
	case "org.freedesktop.NetworkManager.Device.Wireless":
		return name == "ActiveAccessPoint"
	case "org.freedesktop.NetworkManager.AccessPoint":
		return name == "HwAddress"
	case "org.freedesktop.NetworkManager.Connection.Active":
		switch name {
		case "State", "Default", "Default6", "Ip4Config", "Ip6Config": return true
		}
	case "org.freedesktop.NetworkManager.IP4Config", "org.freedesktop.NetworkManager.IP6Config":
		return true
	}
	return false
}
