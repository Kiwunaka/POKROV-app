package networktxn

import (
	"testing"

	"github.com/Kiwunaka/pokrov-app/linux-daemon/internal/journal"
)

type memorySink struct {
	events []journal.Event
}

func (sink *memorySink) Write(event journal.Event) {
	sink.events = append(sink.events, event)
}

func TestRecorderEmitsTypedCheckpointApplyAndRollbackResults(t *testing.T) {
	sink := &memorySink{}
	recorder, err := New(sink, "network-9-1", "linux-connect-1", 9)
	if err != nil {
		t.Fatal(err)
	}

	steps := []struct {
		record    func(Subsystem, Result) error
		subsystem Subsystem
		result    Result
		stage     string
		outcome   string
		errorCode string
	}{
		{recorder.Checkpoint, NetworkManager, Passed, "checkpoint", "pass", ""},
		{recorder.Checkpoint, Resolved, Failed, "checkpoint", "reject", "linux_network_checkpoint_failed"},
		{recorder.Apply, Nftables, Unsupported, "apply", "unavailable", "linux_network_unsupported"},
		{recorder.Apply, NetworkManager, Failed, "apply", "reject", "linux_network_apply_failed"},
		{recorder.Rollback, Nftables, Passed, "rollback", "pass", ""},
		{recorder.Rollback, Resolved, Failed, "rollback", "reject", "linux_network_rollback_failed"},
	}
	for _, step := range steps {
		if err := step.record(step.subsystem, step.result); err != nil {
			t.Fatal(err)
		}
		event := sink.events[len(sink.events)-1]
		if event.Stage != step.stage || event.Outcome != step.outcome ||
			event.ErrorCode != step.errorCode || event.TransactionID != "network-9-1" ||
			event.CorrelationID != "linux-connect-1" || event.Generation != 9 {
			t.Fatalf("unexpected typed event: %#v", event)
		}
	}
}

func TestRecorderRejectsOpenIdentifiersAndUnknownEnums(t *testing.T) {
	sink := &memorySink{}
	for _, identifiers := range [][2]string{
		{"https://host/token", "linux-connect-1"},
		{"network-1", "../../profile"},
	} {
		if _, err := New(sink, identifiers[0], identifiers[1], 1); err == nil {
			t.Fatalf("open identifier pair was accepted: %#v", identifiers)
		}
	}
	recorder, err := New(sink, "network-1", "linux-connect-1", 1)
	if err != nil {
		t.Fatal(err)
	}
	if err := recorder.Apply(Subsystem(255), Passed); err == nil {
		t.Fatal("unknown subsystem was accepted")
	}
	if err := recorder.Rollback(NetworkManager, Result(255)); err == nil {
		t.Fatal("unknown result was accepted")
	}
	if len(sink.events) != 0 {
		t.Fatalf("invalid input emitted events: %#v", sink.events)
	}
}
