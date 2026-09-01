//go:build linux

package auth

import (
	"os"
	"testing"
)

type recordingChecker struct {
	action  string
	process string
	result  Decision
}

func (checker *recordingChecker) Check(actionID, process string) Decision {
	checker.action = actionID
	checker.process = process
	return checker.result
}

func TestProcessStartTimeReadsCurrentProcessIdentity(t *testing.T) {
	startTime, err := processStartTime(os.Getpid())
	if err != nil {
		t.Fatal(err)
	}
	if startTime == 0 {
		t.Fatal("current process start time is zero")
	}
}

func TestAuthorizedBindsPolkitToExactPeerTuple(t *testing.T) {
	checker := &recordingChecker{result: DecisionAuthorized}
	peer := Peer{PID: 321, UID: 1000, StartTime: 654}

	result := Authorize(peer, checker)
	if !result.Authorized() || result.Backend != BackendPolkitDBus {
		t.Fatal("authorized peer was rejected")
	}
	if checker.action != ManageActionID || checker.process != "321,654,1000" {
		t.Fatalf("unexpected polkit identity: %q %q", checker.action, checker.process)
	}
}

func TestAuthorizedRejectsIncompletePeerBeforePolkit(t *testing.T) {
	checker := &recordingChecker{result: DecisionAuthorized}
	result := Authorize(Peer{PID: 321, UID: 1000}, checker)
	if result.Authorized() || result.Decision != DecisionInvalidSubject ||
		result.Backend != BackendPeerCredential {
		t.Fatal("peer without start time was authorized")
	}
	if checker.action != "" || checker.process != "" {
		t.Fatal("polkit was called for an incomplete peer identity")
	}
}

func TestRootAuthorizationUsesPeerCredentialWithoutPolkit(t *testing.T) {
	checker := &recordingChecker{result: DecisionDenied}
	result := Authorize(Peer{PID: 1, UID: 0, StartTime: 1}, checker)
	if !result.Authorized() || result.Backend != BackendPeerCredential {
		t.Fatalf("unexpected root authorization result: %#v", result)
	}
	if checker.action != "" || checker.process != "" {
		t.Fatal("polkit was called for root peer")
	}
}

func TestPolkitExitCodesMapToClosedDecisions(t *testing.T) {
	tests := map[int]Decision{
		0:   DecisionAuthorized,
		1:   DecisionDenied,
		2:   DecisionAgentUnavailable,
		3:   DecisionDismissed,
		126: DecisionUnavailable,
		127: DecisionUnavailable,
		255: DecisionUnavailable,
	}
	for exitCode, expected := range tests {
		if actual := decisionFromExitCode(exitCode); actual != expected {
			t.Fatalf("exit code %d mapped to %q, want %q", exitCode, actual, expected)
		}
	}
}
