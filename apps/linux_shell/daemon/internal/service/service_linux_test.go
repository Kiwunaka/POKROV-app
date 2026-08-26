//go:build linux

package service

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	"github.com/Kiwunaka/pokrov-app/linux-daemon/internal/auth"
	"github.com/Kiwunaka/pokrov-app/linux-daemon/internal/host"
	"github.com/Kiwunaka/pokrov-app/linux-daemon/internal/profile"
	"github.com/Kiwunaka/pokrov-app/linux-daemon/internal/protocol"
)

type readyCommands struct{}

func (readyCommands) Active(string) bool {
	return true
}

func (readyCommands) Available(string) bool {
	return true
}

type denyingChecker struct{}

func (denyingChecker) Check(string, string) bool {
	return false
}

func newReadyService(t *testing.T, checker auth.Checker) (*Service, *profile.Store) {
	t.Helper()
	osRelease := filepath.Join(t.TempDir(), "os-release")
	if err := os.WriteFile(osRelease, []byte("ID=ubuntu\nVERSION_ID=24.04\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	store := profile.NewStore(filepath.Join(t.TempDir(), "profiles"))
	return New(
		host.Probe{
			Commands:  readyCommands{},
			CorePath:  "/bin/true",
			OSRelease: osRelease,
		},
		store,
		checker,
		nil,
	), store
}

func stageRequest(t *testing.T) protocol.Request {
	t.Helper()
	payload, err := json.Marshal(profile.StageRequest{
		ProfileName:             "pokrov-test",
		ConfigPayload:           "{\"dns\":{},\"inbounds\":[],\"outbounds\":[],\"route\":{}}",
		RouteMode:               "fullTunnel",
		CoreEgressProbeRequired: true,
	})
	if err != nil {
		t.Fatal(err)
	}
	return protocol.Request{
		Protocol:  protocol.Version,
		RequestID: "linux-stage-1",
		Action:    "stage_profile",
		Payload:   payload,
	}
}

func TestMutationRequiresAuthorizationBeforeProfileWrite(t *testing.T) {
	service, store := newReadyService(t, denyingChecker{})
	response := service.Handle(
		auth.Peer{PID: 123, UID: 1000, StartTime: 456},
		stageRequest(t),
	)
	if response.OK || response.ErrorCode != "linux_authorization_denied" {
		t.Fatalf("unauthorized mutation returned %#v", response)
	}
	if store.Exists() {
		t.Fatal("unauthorized request wrote a profile")
	}
}

func TestRootCanStageButLiveConnectRemainsFailClosed(t *testing.T) {
	service, store := newReadyService(t, nil)
	root := auth.Peer{PID: 1, UID: 0, StartTime: 1}

	staged := service.Handle(root, stageRequest(t))
	if !staged.OK || staged.Snapshot == nil || staged.Snapshot.Phase != "config_staged" {
		t.Fatalf("profile stage failed: %#v", staged)
	}
	if !store.Exists() {
		t.Fatal("authorized profile was not staged")
	}

	connect := service.Handle(root, protocol.Request{
		Protocol:  protocol.Version,
		RequestID: "linux-connect-1",
		Action:    "connect",
		Payload:   json.RawMessage("{}"),
	})
	if connect.OK || connect.ErrorCode != "linux_live_connect_unavailable" {
		t.Fatalf("foundation advertised live connect: %#v", connect)
	}
}
