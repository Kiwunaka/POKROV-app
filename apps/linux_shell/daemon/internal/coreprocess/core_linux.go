//go:build linux

// Package coreprocess owns the single fixed Core child and its private IPC.
package coreprocess

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"io"
	"net"
	"net/netip"
	"os"
	"os/exec"
	"syscall"
	"time"

	"github.com/Kiwunaka/pokrov-app/linux-daemon/internal/host"
	"github.com/Kiwunaka/pokrov-app/linux-daemon/internal/bootclock"
	"github.com/Kiwunaka/pokrov-app/linux-daemon/internal/networktxn"
)

const protocol = "pokrov-linux-core-v1"

var errRuntime = errors.New("linux core child unavailable")

type reply struct {
	Protocol string  `json:"protocol"`
	Phase    string  `json:"phase"`
	Health   *Health `json:"health,omitempty"`
	TransportCapabilities string `json:"transport_capabilities_json,omitempty"`
	CoreModuleSHA256 string `json:"core_module_sha256,omitempty"`
	ProfileSHA256 string `json:"profile_sha256,omitempty"`
	IdentitySchema int `json:"identity_schema,omitempty"`
	DeadlineSchema int `json:"deadline_schema,omitempty"`
	ConnectDeadline *bootclock.Deadline `json:"connect_deadline,omitempty"`
	LeaseID string `json:"endpoint_lease_ref,omitempty"`
	ActiveFlowsUntil string `json:"active_flows_until,omitempty"`
	LeaseRevoked *bool `json:"lease_revoked,omitempty"`
	Plan     *struct {
		TunnelInterface string   `json:"tunnel_interface"`
		RoutingMark     uint32   `json:"routing_mark"`
		DNSServers      []string `json:"dns_servers"`
	} `json:"plan,omitempty"`
}

type Health struct {
	DNSReady        bool `json:"dns_ready"`
	EgressValidated bool `json:"core_egress_validated"`
}

type Session struct {
	command *exec.Cmd
	input   io.WriteCloser
	control *os.File
	reader  *bufio.Reader
	done    chan struct{}
	stopped bool
	transportCapabilities string
	coreModuleSHA256 string
	profileSHA256 string
	expectedIdentity *ExpectedIdentity
	promotedActiveUntil time.Time
}

func Prepare(ctx context.Context) (*Session, networktxn.Plan, error) {
	return prepare(ctx, nil)
}

func PrepareWithIdentity(ctx context.Context, expected ExpectedIdentity) (*Session, networktxn.Plan, error) {
	if !expected.valid() { return nil, networktxn.Plan{}, ErrIdentityMismatch }
	if !expected.Deadline.Current() { return nil, networktxn.Plan{}, bootclock.ErrDeadline }
	return prepare(ctx, &expected)
}

func prepare(ctx context.Context, expected *ExpectedIdentity) (*Session, networktxn.Plan, error) {
	// Attaching Core to an existing TUN would confuse ownership and rollback.
	interfaces, err := net.Interfaces()
	if err != nil {
		return nil, networktxn.Plan{}, errRuntime
	}
	for _, link := range interfaces {
		if link.Name == "pokrov0" {
			return nil, networktxn.Plan{}, errRuntime
		}
	}
	command := exec.Command(host.DefaultCorePath)
	command.Env = []string{"PATH=/usr/sbin:/usr/bin:/sbin:/bin", "HOME=/var/lib/pokrov/core"}
	command.SysProcAttr = &syscall.SysProcAttr{Pdeathsig: syscall.SIGTERM}
	session, err := prepareCommand(ctx, command)
	if err != nil {
		return nil, networktxn.Plan{}, err
	}
	first, err := session.read(ctx)
	if err != nil || first.Phase != "prepared" || first.Plan == nil ||
		first.Plan.TunnelInterface != "pokrov0" || first.Plan.RoutingMark != 0x504b {
		session.abort()
		return nil, networktxn.Plan{}, errRuntime
	}
	session.transportCapabilities = boundedTransportInventory(first.TransportCapabilities)
	session.coreModuleSHA256 = boundedModuleSHA256(first.CoreModuleSHA256)
	session.profileSHA256 = boundedModuleSHA256(first.ProfileSHA256)
	if expected != nil && !expected.matches(first) {
		// No transaction is armed yet. A missing schema also rejects an older
		// Core that cannot enforce the expected pair at Start.
		session.abort()
		return nil, networktxn.Plan{}, ErrIdentityMismatch
	}
	if expected != nil && !expected.Deadline.Current() {
		session.abort()
		return nil, networktxn.Plan{}, bootclock.ErrDeadline
	}
	session.expectedIdentity = expected
	dns := make([]netip.Addr, 0, len(first.Plan.DNSServers))
	for _, value := range first.Plan.DNSServers {
		if value != "172.19.0.2" && value != "fdfe:dcba:9876::2" {
			session.abort()
			return nil, networktxn.Plan{}, errRuntime
		}
		dns = append(dns, netip.MustParseAddr(value))
	}
	plan, err := networktxn.NewPlan(first.Plan.TunnelInterface, first.Plan.RoutingMark, dns)
	if err != nil {
		session.abort()
		return nil, networktxn.Plan{}, errRuntime
	}
	return session, plan, nil
}

func prepareCommand(ctx context.Context, command *exec.Cmd) (*Session, error) {
	if ctx.Err() != nil {
		return nil, errRuntime
	}
	control, writer, err := os.Pipe()
	if err != nil {
		return nil, errRuntime
	}
	command.ExtraFiles = []*os.File{writer}
	command.Stdout = io.Discard
	command.Stderr = io.Discard
	input, err := command.StdinPipe()
	if err != nil {
		control.Close()
		writer.Close()
		return nil, errRuntime
	}
	if command.Start() != nil {
		control.Close()
		writer.Close()
		input.Close()
		return nil, errRuntime
	}
	writer.Close()
	session := &Session{command: command, input: input, control: control, reader: bufio.NewReaderSize(control, 16*1024), done: make(chan struct{})}
	go func() { _ = command.Wait(); close(session.done) }()
	return session, nil
}

func (session *Session) Start(ctx context.Context) error {
	if ctx.Err() != nil {
		return errRuntime
	}
	command := struct {
		Protocol string `json:"protocol"`
		Action string `json:"action"`
		CoreModuleSHA256 string `json:"expected_core_module_sha256,omitempty"`
		ProfileSHA256 string `json:"expected_profile_sha256,omitempty"`
		Deadline *bootclock.Deadline `json:"deadline,omitempty"`
	}{Protocol: protocol, Action: "start"}
	if session.expectedIdentity != nil {
		if !session.expectedIdentity.Deadline.Current() { return bootclock.ErrDeadline }
		command.Action = "start_with_identity"
		command.CoreModuleSHA256 = session.expectedIdentity.CoreModuleSHA256
		command.ProfileSHA256 = session.expectedIdentity.ProfileSHA256
		command.Deadline = &session.expectedIdentity.Deadline
	}
	if err := json.NewEncoder(session.input).Encode(command); err != nil {
		return errRuntime
	}
	response, err := session.read(ctx)
	if err != nil || response.Phase != "started" {
		return errRuntime
	}
	if session.expectedIdentity != nil {
		if !session.expectedIdentity.matches(response) || response.ConnectDeadline == nil ||
			*response.ConnectDeadline != session.expectedIdentity.Deadline { return ErrIdentityMismatch }
		if !session.expectedIdentity.Deadline.Current() { return bootclock.ErrDeadline }
	}
	return nil
}

func (session *Session) Probe(ctx context.Context) (Health, error) {
	if ctx.Err() != nil {
		return Health{}, errRuntime
	}
	if _, err := io.WriteString(session.input, "{\"protocol\":\""+protocol+"\",\"action\":\"health\"}\n"); err != nil {
		return Health{}, errRuntime
	}
	response, err := session.read(ctx)
	if err != nil || response.Phase != "health" || response.Health == nil {
		return Health{}, errRuntime
	}
	return *response.Health, nil
}

func (session *Session) PromoteATSLease(ctx context.Context, profile, lease, issuedAt,
	newFlowsUntil, activeFlowsUntil string) error {
	if session.expectedIdentity == nil || session.promotedActiveUntil != (time.Time{}) ||
		session.profileSHA256 != profile || !session.expectedIdentity.Deadline.Current() { return ErrIdentityMismatch }
	command := struct {
		Protocol string `json:"protocol"`
		Action string `json:"action"`
		ProfileSHA256 string `json:"expected_profile_sha256"`
		LeaseID string `json:"endpoint_lease_ref"`
		IssuedAt string `json:"issued_at"`
		NewFlowsUntil string `json:"new_flows_until"`
		ActiveFlowsUntil string `json:"active_flows_until"`
	}{protocol, "promote_ats_lease", profile, lease, issuedAt, newFlowsUntil, activeFlowsUntil}
	if json.NewEncoder(session.input).Encode(command) != nil { return errRuntime }
	response, err := session.read(ctx)
	if err != nil || response.Phase != "promoted" || response.ProfileSHA256 != profile ||
		response.LeaseID != lease || response.ActiveFlowsUntil != activeFlowsUntil { return errRuntime }
	until, err := time.Parse("2006-01-02T15:04:05Z", activeFlowsUntil)
	if err != nil || !time.Now().Before(until) || session.Exited() { return errRuntime }
	session.promotedActiveUntil = until
	return nil
}

func (session *Session) RevokeATSLease(ctx context.Context, profile, lease string, terminateActive bool) error {
	if session.expectedIdentity == nil || session.promotedActiveUntil.IsZero() ||
		session.profileSHA256 != profile || session.Exited() { return ErrIdentityMismatch }
	command := struct {
		Protocol string `json:"protocol"`
		Action string `json:"action"`
		ProfileSHA256 string `json:"expected_profile_sha256"`
		LeaseID string `json:"endpoint_lease_ref"`
		TerminateActive bool `json:"terminate_active"`
	}{protocol, "revoke_ats_lease", profile, lease, terminateActive}
	if json.NewEncoder(session.input).Encode(command) != nil { return errRuntime }
	response, err := session.read(ctx)
	if err != nil || response.Phase != "lease_revoked" || response.ProfileSHA256 != profile ||
		response.LeaseID != lease || response.LeaseRevoked == nil || !*response.LeaseRevoked { return errRuntime }
	return nil
}

func (session *Session) Stop(ctx context.Context) error {
	defer func() {
		if session.Exited() {
			_ = session.input.Close()
			_ = session.control.Close()
		}
	}()
	if !session.stopped {
		// SIGTERM also interrupts a child waiting for its first start command.
		_ = session.command.Process.Signal(syscall.SIGTERM)
		for count := 0; count < 2 && !session.stopped; count++ {
			if _, err := session.read(ctx); err != nil {
				return errRuntime
			}
		}
	}
	if !session.stopped {
		return errRuntime
	}
	select {
	case <-session.done:
		_ = session.input.Close()
		_ = session.control.Close()
		return nil // The child explicitly acknowledged hcore.Stop.
	case <-ctx.Done():
		_ = session.command.Process.Kill()
		return errRuntime
	}
}

func (session *Session) Exited() bool {
	select {
	case <-session.done:
		return true
	default:
		return false
	}
}

func (session *Session) Done() <-chan struct{} { return session.done }

func (session *Session) TransportCapabilities() string {
	if session.Exited() { return "" }
	return session.transportCapabilities
}

func (session *Session) CoreModuleSHA256() string {
	if session.Exited() { return "" }
	return session.coreModuleSHA256
}

func (session *Session) ProfileSHA256() string {
	if session.Exited() { return "" }
	return session.profileSHA256
}

func (session *Session) ConnectDeadlineExpired() bool {
	if !session.promotedActiveUntil.IsZero() { return !time.Now().Before(session.promotedActiveUntil) }
	return session.expectedIdentity != nil && !session.expectedIdentity.Deadline.Current()
}

func (session *Session) read(ctx context.Context) (reply, error) {
	if ctx.Err() != nil {
		return reply{}, errRuntime
	}
	deadline := time.Now().Add(30 * time.Second)
	if value, ok := ctx.Deadline(); ok && value.Before(deadline) {
		deadline = value
	}
	if session.control.SetReadDeadline(deadline) != nil {
		return reply{}, errRuntime
	}
	cancelDone := make(chan struct{})
	stopCancel := context.AfterFunc(ctx, func() {
		defer close(cancelDone)
		_ = session.control.SetReadDeadline(time.Now())
	})
	defer func() {
		// A late callback must not shorten the following rollback read.
		if !stopCancel() {
			<-cancelDone
		}
	}()
	line, err := session.reader.ReadSlice('\n')
	if err != nil {
		return reply{}, errRuntime
	}
	decoder := json.NewDecoder(bytes.NewReader(line))
	decoder.DisallowUnknownFields()
	var response reply
	if decoder.Decode(&response) != nil || response.Protocol != protocol {
		return reply{}, errRuntime
	}
	var trailing any
	if decoder.Decode(&trailing) != io.EOF {
		return reply{}, errRuntime
	}
	switch response.Phase {
	case "prepared", "started", "health", "promoted", "lease_revoked":
	case "stopped":
		session.stopped = true
	default:
		return reply{}, errRuntime
	}
	return response, nil
}

// Used only when prepare failed before any network transaction was armed.
func (session *Session) abort() {
	_ = session.command.Process.Signal(syscall.SIGTERM)
	select {
	case <-session.done:
	case <-time.After(5 * time.Second):
		_ = session.command.Process.Kill()
		<-session.done
	}
	_ = session.input.Close()
	_ = session.control.Close()
}

// Prepared Core has not entered the network transaction yet.
func (session *Session) AbortPrepared() { session.abort() }
