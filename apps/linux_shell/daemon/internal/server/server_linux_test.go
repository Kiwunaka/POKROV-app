//go:build linux

package server

import (
	"bufio"
	"encoding/json"
	"net"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/Kiwunaka/pokrov-app/linux-daemon/internal/host"
	"github.com/Kiwunaka/pokrov-app/linux-daemon/internal/profile"
	"github.com/Kiwunaka/pokrov-app/linux-daemon/internal/protocol"
	"github.com/Kiwunaka/pokrov-app/linux-daemon/internal/service"
)

func TestDecodeRequestRejectsUnknownAndTrailingData(t *testing.T) {
	valid := []byte("{\"protocol\":\"pokrov-linuxd-v1\",\"request_id\":\"linux-1\",\"action\":\"status\",\"payload\":{}}\n")
	request, err := decodeRequest(valid)
	if err != nil || request.Action != "status" {
		t.Fatalf("valid request rejected: %#v %v", request, err)
	}

	invalid := [][]byte{
		[]byte("{\"protocol\":\"pokrov-linuxd-v1\",\"request_id\":\"linux-1\",\"action\":\"status\",\"payload\":{},\"extra\":true}\n"),
		[]byte("{\"protocol\":\"pokrov-linuxd-v1\",\"request_id\":\"linux-1\",\"action\":\"status\",\"payload\":{}} {}\n"),
		[]byte("{\"protocol\":\"future\",\"request_id\":\"linux-1\",\"action\":\"status\",\"payload\":{}}\n"),
	}
	for index, candidate := range invalid {
		if _, err := decodeRequest(candidate); err == nil {
			t.Fatalf("invalid request %d was accepted", index)
		}
	}
}

type delayedReadyCommands struct {
	delay time.Duration
}

func (commands delayedReadyCommands) Active(string) bool {
	time.Sleep(commands.delay)
	return true
}

func (commands delayedReadyCommands) Available(string) bool {
	time.Sleep(commands.delay)
	return true
}

func TestSlowServiceWorkDoesNotReuseExpiredReadDeadlineForResponse(t *testing.T) {
	directory := t.TempDir()
	osRelease := filepath.Join(directory, "os-release")
	if err := os.WriteFile(osRelease, []byte("ID=ubuntu\nVERSION_ID=24.04\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	daemon := service.New(
		host.Probe{
			Commands:  delayedReadyCommands{delay: 8 * time.Millisecond},
			CorePath:  "/bin/true",
			OSRelease: osRelease,
		},
		profile.NewStore(filepath.Join(directory, "profiles")),
		nil,
		nil,
	)
	server := New(daemon)
	server.ReadTimeout = 5 * time.Millisecond
	server.WriteTimeout = time.Second

	socketPath := filepath.Join(directory, "pokrov-linuxd.sock")
	listener, err := net.ListenUnix("unix", &net.UnixAddr{Name: socketPath, Net: "unix"})
	if err != nil {
		t.Fatal(err)
	}
	serveResult := make(chan error, 1)
	go func() { serveResult <- server.Serve(listener) }()
	t.Cleanup(func() {
		_ = listener.Close()
		select {
		case err := <-serveResult:
			if err != nil {
				t.Errorf("server shutdown failed: %v", err)
			}
		case <-time.After(time.Second):
			t.Error("server did not stop")
		}
	})

	connection, err := net.DialUnix("unix", nil, &net.UnixAddr{Name: socketPath, Net: "unix"})
	if err != nil {
		t.Fatal(err)
	}
	defer connection.Close()
	if err := connection.SetDeadline(time.Now().Add(2 * time.Second)); err != nil {
		t.Fatal(err)
	}
	request := protocol.Request{
		Protocol: protocol.Version, RequestID: "linux-status-slow-1",
		Action: "status", Payload: json.RawMessage(`{}`),
	}
	encoded, err := json.Marshal(request)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := connection.Write(append(encoded, '\n')); err != nil {
		t.Fatal(err)
	}
	line, err := bufio.NewReader(connection).ReadBytes('\n')
	if err != nil {
		t.Fatalf("response was lost after read deadline elapsed: %v", err)
	}
	var response protocol.Response
	if err := json.Unmarshal(line, &response); err != nil {
		t.Fatal(err)
	}
	if !response.OK || response.RequestID != request.RequestID {
		t.Fatalf("unexpected response: %#v", response)
	}
}
