//go:build linux

package service

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	"github.com/Kiwunaka/pokrov-app/linux-daemon/internal/auth"
	"github.com/Kiwunaka/pokrov-app/linux-daemon/internal/host"
	"github.com/Kiwunaka/pokrov-app/linux-daemon/internal/journal"
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

func (denyingChecker) Check(string, string) auth.Decision {
	return auth.DecisionDenied
}

type fixedChecker struct {
	decision auth.Decision
}

func (checker fixedChecker) Check(string, string) auth.Decision {
	return checker.decision
}

type memoryEvents struct {
	events []journal.Event
}

func (events *memoryEvents) Write(event journal.Event) {
	events.events = append(events.events, event)
}

func newReadyService(t *testing.T, checker auth.Checker) (*Service, *profile.Store) {
	return newReadyServiceWithEvents(t, checker, nil)
}

func newReadyServiceWithEvents(
	t *testing.T,
	checker auth.Checker,
	events eventSink,
) (*Service, *profile.Store) {
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
		events,
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

func TestUnavailableConnectEmitsClosedNetworkPreflightReasons(t *testing.T) {
	events := &memoryEvents{}
	service, _ := newReadyServiceWithEvents(t, nil, events)
	root := auth.Peer{PID: 1, UID: 0, StartTime: 1}

	if staged := service.Handle(root, stageRequest(t)); !staged.OK {
		t.Fatalf("profile stage failed: %#v", staged)
	}
	connect := service.Handle(root, protocol.Request{
		Protocol:  protocol.Version,
		RequestID: "linux-connect-observed-1",
		Action:    "connect",
		Payload:   json.RawMessage("{}"),
	})
	if connect.OK || connect.ErrorCode != "linux_live_connect_unavailable" {
		t.Fatalf("foundation advertised live connect: %#v", connect)
	}

	networkEvents := make([]journal.Event, 0, 3)
	for _, event := range events.events {
		if event.Name == "network_transaction" {
			networkEvents = append(networkEvents, event)
		}
	}
	if len(networkEvents) != 3 {
		t.Fatalf("expected three network preflight events, got %#v", networkEvents)
	}
	wantSubsystems := []string{"network_manager", "resolved", "nftables"}
	for index, event := range networkEvents {
		if event.Subsystem != wantSubsystems[index] || event.Stage != "checkpoint" ||
			event.Outcome != "unavailable" || event.ErrorCode != "linux_network_unsupported" ||
			event.TransactionID != "linux-connect-observed-1" ||
			event.CorrelationID != "linux-connect-observed-1" {
			t.Fatalf("unexpected network event %d: %#v", index, event)
		}
	}
}

func TestMutationAuthorizationEmitsBoundedPolkitDBusDecision(t *testing.T) {
	tests := []struct {
		name      string
		decision  auth.Decision
		outcome   string
		errorCode string
		allowed   bool
	}{
		{
			name: "allowed", decision: auth.DecisionAuthorized,
			outcome: "pass", allowed: true,
		},
		{
			name: "denied", decision: auth.DecisionDenied,
			outcome: "denied", errorCode: "linux_authorization_denied",
		},
		{
			name: "no agent", decision: auth.DecisionAgentUnavailable,
			outcome: "unavailable", errorCode: "linux_authorization_agent_unavailable",
		},
		{
			name: "dismissed", decision: auth.DecisionDismissed,
			outcome: "denied", errorCode: "linux_authorization_dismissed",
		},
		{
			name: "timeout", decision: auth.DecisionTimeout,
			outcome: "unavailable", errorCode: "linux_authorization_timeout",
		},
		{
			name: "service unavailable", decision: auth.DecisionUnavailable,
			outcome: "unavailable", errorCode: "linux_authorization_unavailable",
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			events := &memoryEvents{}
			service, store := newReadyServiceWithEvents(
				t,
				fixedChecker{decision: test.decision},
				events,
			)
			response := service.Handle(
				auth.Peer{PID: 123, UID: 1000, StartTime: 456},
				stageRequest(t),
			)
			if response.OK != test.allowed {
				t.Fatalf("unexpected authorization response: %#v", response)
			}
			if !test.allowed && response.ErrorCode != "linux_authorization_denied" {
				t.Fatalf("authorization detail escaped the generic IPC error: %#v", response)
			}
			if store.Exists() != test.allowed {
				t.Fatalf("profile mutation mismatch: allowed=%t exists=%t", test.allowed, store.Exists())
			}

			authorizationEvents := make([]journal.Event, 0, 1)
			for _, event := range events.events {
				if event.Name == "authorization" {
					authorizationEvents = append(authorizationEvents, event)
				}
			}
			if len(authorizationEvents) != 1 {
				t.Fatalf("expected one authorization event, got %#v", authorizationEvents)
			}
			event := authorizationEvents[0]
			if event.AuthorizationBackend != "polkit_dbus" ||
				event.Outcome != test.outcome || event.ErrorCode != test.errorCode ||
				event.CorrelationID != "linux-stage-1" {
				t.Fatalf("unexpected authorization event: %#v", event)
			}
		})
	}
}

func TestRootMutationAuthorizationTraceUsesPeerCredential(t *testing.T) {
	events := &memoryEvents{}
	service, _ := newReadyServiceWithEvents(t, nil, events)
	response := service.Handle(
		auth.Peer{PID: 1, UID: 0, StartTime: 1},
		stageRequest(t),
	)
	if !response.OK {
		t.Fatalf("root mutation failed: %#v", response)
	}
	for _, event := range events.events {
		if event.Name == "authorization" {
			if event.AuthorizationBackend != "peer_credential" ||
				event.Outcome != "pass" || event.ErrorCode != "" {
				t.Fatalf("unexpected root authorization event: %#v", event)
			}
			return
		}
	}
	t.Fatal("root authorization event was not emitted")
}
