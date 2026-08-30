//go:build linux

package auth

import (
	"os"
	"testing"
)

type recordingChecker struct {
	action  string
	process string
	result  bool
}

func (checker *recordingChecker) Check(actionID, process string) bool {
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
	checker := &recordingChecker{result: true}
	peer := Peer{PID: 321, UID: 1000, StartTime: 654}

	if !Authorized(peer, checker) {
		t.Fatal("authorized peer was rejected")
	}
	if checker.action != ManageActionID || checker.process != "321,654,1000" {
		t.Fatalf("unexpected polkit identity: %q %q", checker.action, checker.process)
	}
}

func TestAuthorizedRejectsIncompletePeerBeforePolkit(t *testing.T) {
	checker := &recordingChecker{result: true}
	if Authorized(Peer{PID: 321, UID: 1000}, checker) {
		t.Fatal("peer without start time was authorized")
	}
	if checker.action != "" || checker.process != "" {
		t.Fatal("polkit was called for an incomplete peer identity")
	}
}
