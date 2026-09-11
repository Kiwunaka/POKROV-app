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
	"github.com/Kiwunaka/pokrov-app/linux-daemon/internal/networktxn"
)

const protocol = "pokrov-linux-core-v1"

var errRuntime = errors.New("linux core child unavailable")

type reply struct {
	Protocol string `json:"protocol"`
	Phase    string `json:"phase"`
	Plan     *struct {
		TunnelInterface string   `json:"tunnel_interface"`
		RoutingMark     uint32   `json:"routing_mark"`
		DNSServers      []string `json:"dns_servers"`
	} `json:"plan,omitempty"`
}

type Session struct {
	command *exec.Cmd
	input   io.WriteCloser
	control *os.File
	reader  *bufio.Reader
	done    chan struct{}
	stopped bool
}

func Prepare(ctx context.Context) (*Session, networktxn.Plan, error) {
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

func prepareCommand(_ context.Context, command *exec.Cmd) (*Session, error) {
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
	session := &Session{command: command, input: input, control: control, reader: bufio.NewReaderSize(control, 4096), done: make(chan struct{})}
	go func() { _ = command.Wait(); close(session.done) }()
	return session, nil
}

func (session *Session) Start(ctx context.Context) error {
	if _, err := io.WriteString(session.input, "{\"protocol\":\""+protocol+"\",\"action\":\"start\"}\n"); err != nil {
		return errRuntime
	}
	response, err := session.read(ctx)
	if err != nil || response.Phase != "started" {
		return errRuntime
	}
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

func (session *Session) read(ctx context.Context) (reply, error) {
	deadline := time.Now().Add(30 * time.Second)
	if value, ok := ctx.Deadline(); ok && value.Before(deadline) {
		deadline = value
	}
	if session.control.SetReadDeadline(deadline) != nil {
		return reply{}, errRuntime
	}
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
	case "prepared", "started":
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
