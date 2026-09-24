//go:build linux

package service

import (
	"bytes"
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"net"
	"os/exec"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"
)

var networkDevicePath = regexp.MustCompile(`^/org/freedesktop/NetworkManager/Devices/[0-9]+$`)
var networkAccessPointPath = regexp.MustCompile(`^/org/freedesktop/NetworkManager/AccessPoint/[0-9]+$`)
var networkIP4ConfigPath = regexp.MustCompile(`^/org/freedesktop/NetworkManager/IP4Config/[0-9]+$`)
var networkIP6ConfigPath = regexp.MustCompile(`^/org/freedesktop/NetworkManager/IP6Config/[0-9]+$`)
var networkBusOwner = regexp.MustCompile(`^:[0-9]+\.[0-9]+$`)
var networkContextRefPattern = regexp.MustCompile(`^network_[a-f0-9]{32}$`)

// The raw observation stays in the daemon. Only a random process-local ref
// crosses the socket. Sampling is serial, while netlink events can invalidate
// the ref during a slow sample.
type networkContextObserver struct {
	mu sync.Mutex
	sampleMu sync.Mutex
	sample string
	reference string
	eventRevision uint64
	interfaces map[uint32]struct{}
	nmPaths map[string]struct{}
	stop chan struct{}
	socket int
	busCancel context.CancelFunc
	closed bool
	failed bool
	onChange func()
}

func (observer *networkContextObserver) Read(ctx context.Context) (string, error) {
	observer.sampleMu.Lock()
	defer observer.sampleMu.Unlock()
	observer.mu.Lock()
	if observer.closed || observer.failed {
		observer.mu.Unlock()
		return "", errors.New("network context unavailable")
	}
	if observer.stop == nil {
		if err := observer.startEvents(); err != nil {
			observer.failed = true
			observer.mu.Unlock()
			return "", errors.New("network context unavailable")
		}
	}
	revision := observer.eventRevision
	observer.mu.Unlock()
	sampleCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	current, interfaces, err := physicalNetworkSample(sampleCtx)
	observer.mu.Lock()
	if observer.closed || observer.failed || observer.eventRevision != revision {
		observer.mu.Unlock()
		return "", errors.New("network context changed")
	}
	if err != nil {
		if ctx.Err() != nil {
			observer.mu.Unlock()
			return "", ctx.Err()
		}
		wasCurrent, changed := observer.reference != "", observer.onChange
		observer.sample, observer.reference, observer.interfaces, observer.nmPaths = "", "", nil, nil
		observer.eventRevision++
		observer.mu.Unlock()
		if wasCurrent && changed != nil { changed() }
		return "", err
	}
	previousRef := observer.reference
	observer.interfaces = interfaces
	observer.nmPaths = selectedNetworkManagerPaths(current)
	if observer.reference == "" || observer.sample != current {
		var random [16]byte
		if _, err := rand.Read(random[:]); err != nil {
			wasCurrent, changed := observer.reference != "", observer.onChange
			observer.sample, observer.reference, observer.interfaces, observer.nmPaths = "", "", nil, nil
			observer.eventRevision++
			observer.mu.Unlock()
			if wasCurrent && changed != nil { changed() }
			return "", errors.New("network context unavailable")
		}
		observer.sample = current
		observer.reference = "network_" + hex.EncodeToString(random[:])
	}
	ref := observer.reference
	changed := observer.onChange
	observer.mu.Unlock()
	if previousRef != "" && previousRef != ref && changed != nil { changed() }
	return ref, nil
}

func selectedNetworkManagerPaths(sample string) map[string]struct{} {
	var observed struct { Links []physicalLink `json:"links"` }
	// The input is serialized locally by physicalNetworkSample, so this decode
	// cannot accept external data or fail after a successful sample.
	_ = json.Unmarshal([]byte(sample), &observed)
	paths := make(map[string]struct{}, len(observed.Links)*5)
	for _, link := range observed.Links {
		paths[link.NMDevice] = struct{}{}
		paths[link.NMConnection] = struct{}{}
		if link.AccessPoint != "" { paths[link.AccessPoint] = struct{}{} }
		if link.NMIP4Config != "" { paths[link.NMIP4Config] = struct{}{} }
		if link.NMIP6Config != "" { paths[link.NMIP6Config] = struct{}{} }
	}
	return paths
}

func (observer *networkContextObserver) Matches(ctx context.Context, expected string) bool {
	if !networkContextRefPattern.MatchString(expected) { return false }
	current, err := observer.Read(ctx)
	return err == nil && current == expected
}

type defaultRoute struct {
	Family string `json:"family"`
	Dst string `json:"dst"`
	Gateway string `json:"gateway"`
	Dev string `json:"dev"`
	Metric int `json:"metric"`
	PrefSrc string `json:"prefsrc"`
	Protocol string `json:"protocol"`
}

type physicalLink struct {
	Name string `json:"name"`
	Index int `json:"index"`
	MTU int `json:"mtu"`
	Hardware string `json:"hardware"`
	Addresses []string `json:"addresses"`
	Resolver string `json:"resolver"`
	NMOwner string `json:"nm_owner"`
	NMDevice string `json:"nm_device"`
	NMConnection string `json:"nm_connection"`
	NMIP4Config string `json:"nm_ip4_config,omitempty"`
	NMIP6Config string `json:"nm_ip6_config,omitempty"`
	NMType uint64 `json:"nm_type"`
	AccessPoint string `json:"access_point,omitempty"`
	BSSID string `json:"bssid,omitempty"`
}

func physicalNetworkSample(ctx context.Context) (string, map[uint32]struct{}, error) {
	routes := make([]defaultRoute, 0)
	devices := map[string]struct{}{}
	for _, family := range []string{"-4", "-6"} {
		output, err := localNetworkCommand(ctx, "/usr/sbin/ip", "-j", family, "route", "show", "default")
		if err != nil { return "", nil, err }
		var listed []defaultRoute
		if json.Unmarshal(output, &listed) != nil || listed == nil { return "", nil, errors.New("default routes unavailable") }
		for _, route := range listed {
			if route.Dev == "" || route.Dev == "pokrov0" || route.Dst != "default" { return "", nil, errors.New("physical route unavailable") }
			route.Family = family
			routes = append(routes, route)
			devices[route.Dev] = struct{}{}
		}
	}
	if len(routes) == 0 { return "", nil, errors.New("default route unavailable") }
	sort.Slice(routes, func(i, j int) bool {
		a, _ := json.Marshal(routes[i]); b, _ := json.Marshal(routes[j]); return bytes.Compare(a, b) < 0
	})
	ownerOutput, err := localNetworkCommand(ctx, "/usr/bin/busctl", "--system", "--no-pager", "call",
		"org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus", "GetNameOwner", "s", "org.freedesktop.NetworkManager")
	if err != nil { return "", nil, err }
	owner, err := networkProperty(ownerOutput, "s")
	if err != nil || !networkBusOwner.MatchString(owner) { return "", nil, errors.New("network manager unavailable") }
	names := make([]string, 0, len(devices))
	for name := range devices { names = append(names, name) }
	sort.Strings(names)
	links := make([]physicalLink, 0, len(names))
	interfaces := make(map[uint32]struct{}, len(names))
	for _, name := range names {
		link, err := readPhysicalLink(ctx, owner, name)
		if err != nil { return "", nil, err }
		links = append(links, link)
		interfaces[uint32(link.Index)] = struct{}{}
	}
	value, err := json.Marshal(struct {
		Routes []defaultRoute `json:"routes"`
		Links []physicalLink `json:"links"`
	}{routes, links})
	if err != nil { return "", nil, errors.New("network context unavailable") }
	return string(value), interfaces, nil
}

func readPhysicalLink(ctx context.Context, owner, name string) (physicalLink, error) {
	iface, err := net.InterfaceByName(name)
	if err != nil || iface.Flags&net.FlagUp == 0 || iface.Flags&net.FlagLoopback != 0 {
		return physicalLink{}, errors.New("physical link unavailable")
	}
	addresses, err := iface.Addrs()
	if err != nil || len(addresses) == 0 { return physicalLink{}, errors.New("physical addresses unavailable") }
	addressStrings := make([]string, 0, len(addresses))
	for _, address := range addresses { addressStrings = append(addressStrings, address.String()) }
	sort.Strings(addressStrings)
	resolver, err := localNetworkCommand(ctx, "/usr/bin/resolvectl", "status", name)
	if err != nil { return physicalLink{}, err }
	deviceOutput, err := localNetworkCommand(ctx, "/usr/bin/busctl", "--system", "--no-pager", "call", owner,
		"/org/freedesktop/NetworkManager", "org.freedesktop.NetworkManager", "GetDeviceByIpIface", "s", name)
	if err != nil { return physicalLink{}, err }
	device, err := networkProperty(deviceOutput, "o")
	if err != nil || !networkDevicePath.MatchString(device) { return physicalLink{}, errors.New("network manager device unavailable") }
	property := func(object, iface, key string) (string, error) {
		output, err := localNetworkCommand(ctx, "/usr/bin/busctl", "--system", "--no-pager", "get-property", owner, object, iface, key)
		if err != nil { return "", err }
		return string(output), nil
	}
	stateRaw, err := property(device, "org.freedesktop.NetworkManager.Device", "State")
	if err != nil { return physicalLink{}, err }
	state, err := networkProperty([]byte(stateRaw), "u")
	if err != nil || state != "100" { return physicalLink{}, errors.New("network manager device inactive") }
	typeRaw, err := property(device, "org.freedesktop.NetworkManager.Device", "DeviceType")
	if err != nil { return physicalLink{}, err }
	typeText, err := networkProperty([]byte(typeRaw), "u")
	if err != nil { return physicalLink{}, err }
	deviceType, err := strconv.ParseUint(typeText, 10, 32)
	if err != nil { return physicalLink{}, errors.New("network manager device type invalid") }
	// A default route through another VPN or virtual device is not the physical
	// uplink this ATS binding claims to observe.
	if deviceType != 1 && deviceType != 2 { return physicalLink{}, errors.New("physical uplink unavailable") }
	connectionRaw, err := property(device, "org.freedesktop.NetworkManager.Device", "ActiveConnection")
	if err != nil { return physicalLink{}, err }
	connection, err := networkProperty([]byte(connectionRaw), "o")
	if err != nil || connection == "/" { return physicalLink{}, errors.New("network manager connection unavailable") }
	ip4Raw, err := property(device, "org.freedesktop.NetworkManager.Device", "Ip4Config")
	if err != nil { return physicalLink{}, err }
	ip4, err := networkProperty([]byte(ip4Raw), "o")
	if err != nil || (ip4 != "/" && !networkIP4ConfigPath.MatchString(ip4)) { return physicalLink{}, errors.New("network manager IPv4 config unavailable") }
	ip6Raw, err := property(device, "org.freedesktop.NetworkManager.Device", "Ip6Config")
	if err != nil { return physicalLink{}, err }
	ip6, err := networkProperty([]byte(ip6Raw), "o")
	if err != nil || (ip6 != "/" && !networkIP6ConfigPath.MatchString(ip6)) { return physicalLink{}, errors.New("network manager IPv6 config unavailable") }
	link := physicalLink{Name: name, Index: iface.Index, MTU: iface.MTU, Hardware: iface.HardwareAddr.String(),
		Addresses: addressStrings, Resolver: strings.TrimSpace(string(resolver)),
		NMOwner: owner, NMDevice: device, NMConnection: connection, NMType: deviceType}
	if ip4 != "/" { link.NMIP4Config = ip4 }
	if ip6 != "/" { link.NMIP6Config = ip6 }
	if deviceType == 2 {
		apRaw, err := property(device, "org.freedesktop.NetworkManager.Device.Wireless", "ActiveAccessPoint")
		if err != nil { return physicalLink{}, err }
		ap, err := networkProperty([]byte(apRaw), "o")
		if err != nil || !networkAccessPointPath.MatchString(ap) { return physicalLink{}, errors.New("wifi access point unavailable") }
		bssidRaw, err := property(ap, "org.freedesktop.NetworkManager.AccessPoint", "HwAddress")
		if err != nil { return physicalLink{}, err }
		bssid, err := networkProperty([]byte(bssidRaw), "s")
		if err != nil || len(bssid) != 17 { return physicalLink{}, errors.New("wifi bssid unavailable") }
		link.AccessPoint, link.BSSID = ap, bssid
	}
	return link, nil
}

func networkProperty(output []byte, kind string) (string, error) {
	value := strings.TrimSpace(string(output))
	if !strings.HasPrefix(value, kind+" ") { return "", errors.New("network property unavailable") }
	value = strings.TrimSpace(strings.TrimPrefix(value, kind+" "))
	if strings.HasPrefix(value, `"`) {
		decoded, err := strconv.Unquote(value)
		if err != nil { return "", errors.New("network property invalid") }
		return decoded, nil
	}
	if value == "" || strings.ContainsAny(value, " \t\r\n") { return "", errors.New("network property invalid") }
	return value, nil
}

func localNetworkCommand(ctx context.Context, path string, args ...string) ([]byte, error) {
	command := exec.CommandContext(ctx, path, args...)
	var output bytes.Buffer
	command.Stdout = &output
	if err := command.Run(); err != nil || output.Len() > 64*1024 {
		return nil, errors.New("network observation unavailable")
	}
	return output.Bytes(), nil
}
