package networktxn

import (
	"context"
	"errors"
	"net/netip"
	"reflect"
	"testing"
)

type fakeTransactionParticipant struct {
	subsystem        Subsystem
	calls            *[]string
	failCheckpoint   bool
	failApply        bool
	rollbackFailures int
	pending          bool
}

type fakeTransactionCore struct {
	calls        *[]string
	failStart    bool
	stopFailures int
	cancel       context.CancelFunc
}

func (core *fakeTransactionCore) Start(context.Context) error {
	*core.calls = append(*core.calls, "core:start")
	if core.cancel != nil {
		core.cancel()
	}
	if core.failStart {
		return errors.New("injected Core start failure")
	}
	return nil
}

func (core *fakeTransactionCore) Stop(ctx context.Context) error {
	*core.calls = append(*core.calls, "core:stop")
	if ctx.Err() != nil {
		return ctx.Err()
	}
	if core.stopFailures > 0 {
		core.stopFailures--
		return errors.New("injected Core stop failure")
	}
	return nil
}

func (participant *fakeTransactionParticipant) Subsystem() Subsystem {
	return participant.subsystem
}

func (participant *fakeTransactionParticipant) Checkpoint(context.Context, Plan) error {
	*participant.calls = append(*participant.calls, participant.name()+":checkpoint")
	if participant.failCheckpoint {
		return errors.New("injected checkpoint failure")
	}
	if participant.subsystem == NetworkManager {
		participant.pending = true
	}
	return nil
}

func (participant *fakeTransactionParticipant) Apply(context.Context, Plan) error {
	*participant.calls = append(*participant.calls, participant.name()+":apply")
	if participant.subsystem != NetworkManager {
		participant.pending = true
	}
	if participant.failApply {
		return errors.New("injected apply failure")
	}
	if participant.subsystem == NetworkManager {
		participant.pending = false
	}
	return nil
}

func (participant *fakeTransactionParticipant) Rollback(context.Context, Plan) error {
	*participant.calls = append(*participant.calls, participant.name()+":rollback")
	if participant.rollbackFailures > 0 {
		participant.rollbackFailures--
		return errors.New("injected rollback failure")
	}
	participant.pending = false
	return nil
}

func (participant *fakeTransactionParticipant) PendingRollback() bool {
	return participant.pending
}

func (participant *fakeTransactionParticipant) name() string {
	return map[Subsystem]string{
		NetworkManager: "network_manager",
		Resolved:       "resolved",
		Nftables:       "nftables",
		Routes:         "routes",
	}[participant.subsystem]
}

func validPlan(t *testing.T) Plan {
	t.Helper()
	plan, err := NewPlan(
		"pokrov0",
		0x504f4b52,
		[]netip.Addr{netip.MustParseAddr("1.1.1.1"), netip.MustParseAddr("2606:4700:4700::1111")},
	)
	if err != nil {
		t.Fatal(err)
	}
	return plan
}

func newFakeTransaction(
	t *testing.T,
	participants ...*fakeTransactionParticipant,
) (*Transaction, *memorySink) {
	t.Helper()
	sink := &memorySink{}
	recorder, err := New(sink, "network-transaction-1", "linux-connect-1", 7)
	if err != nil {
		t.Fatal(err)
	}
	values := make([]Participant, 0, len(participants))
	for _, participant := range participants {
		values = append(values, participant)
	}
	transaction, err := NewTransaction(recorder, values...)
	if err != nil {
		t.Fatal(err)
	}
	return transaction, sink
}

func allFakeParticipants(calls *[]string) (
	*fakeTransactionParticipant,
	*fakeTransactionParticipant,
	*fakeTransactionParticipant,
	*fakeTransactionParticipant,
) {
	return &fakeTransactionParticipant{subsystem: NetworkManager, calls: calls},
		&fakeTransactionParticipant{subsystem: Resolved, calls: calls},
		&fakeTransactionParticipant{subsystem: Nftables, calls: calls},
		&fakeTransactionParticipant{subsystem: Routes, calls: calls}
}

func TestTransactionUsesProtectedStageOrderAndRestoresOwnedState(t *testing.T) {
	calls := []string{}
	networkManager, resolved, nftables, routes := allFakeParticipants(&calls)
	transaction, sink := newFakeTransaction(t, nftables, networkManager, resolved, routes)
	plan := validPlan(t)
	if err := transaction.Execute(context.Background(), plan, &fakeTransactionCore{calls: &calls}); err != nil {
		t.Fatal(err)
	}
	if err := transaction.Restore(context.Background()); err != nil {
		t.Fatal(err)
	}
	callCount := len(calls)
	if err := transaction.Restore(context.Background()); err != nil {
		t.Fatalf("repeated restore was not idempotent: %v", err)
	}
	if len(calls) != callCount {
		t.Fatalf("repeated restore mutated clean state: %#v", calls[callCount:])
	}
	wantCalls := []string{
		"routes:checkpoint",
		"nftables:checkpoint",
		"nftables:apply",
		"core:start",
		"routes:apply",
		"network_manager:checkpoint",
		"resolved:checkpoint",
		"resolved:apply",
		"network_manager:apply",
		"resolved:rollback",
		"routes:rollback",
		"core:stop",
		"nftables:rollback",
	}
	if !reflect.DeepEqual(calls, wantCalls) {
		t.Fatalf("unexpected transaction order:\n got %#v\nwant %#v", calls, wantCalls)
	}
	if len(sink.events) != 11 {
		t.Fatalf("unexpected event count: %d", len(sink.events))
	}
	for _, event := range sink.events {
		if event.Outcome != "pass" || event.ErrorCode != "" {
			t.Fatalf("successful transaction emitted failure: %#v", event)
		}
	}
}

func TestTransactionRollsBackPartialApplyInReverseOrder(t *testing.T) {
	calls := []string{}
	networkManager, resolved, nftables, routes := allFakeParticipants(&calls)
	nftables.failApply = true
	transaction, sink := newFakeTransaction(t, networkManager, resolved, nftables, routes)
	err := transaction.Execute(context.Background(), validPlan(t), &fakeTransactionCore{calls: &calls})
	var failure *Failure
	if !errors.As(err, &failure) || failure.Stage != ApplyStage ||
		failure.Subsystem != Nftables || failure.RollbackFailed {
		t.Fatalf("unexpected transaction failure: %#v", err)
	}
	wantSuffix := []string{
		"routes:checkpoint",
		"nftables:checkpoint",
		"nftables:apply",
		"core:stop",
		"nftables:rollback",
	}
	if !reflect.DeepEqual(calls[len(calls)-len(wantSuffix):], wantSuffix) {
		t.Fatalf("partial apply did not rollback in reverse: %#v", calls)
	}
	foundReject := false
	for _, event := range sink.events {
		if event.Subsystem == "nftables" && event.Stage == "apply" &&
			event.Outcome == "reject" && event.ErrorCode == "linux_network_apply_failed" {
			foundReject = true
		}
	}
	if !foundReject {
		t.Fatalf("missing closed apply failure event: %#v", sink.events)
	}
}

func TestTransactionContinuesRollbackAndRetriesOnlyDirtyParticipant(t *testing.T) {
	calls := []string{}
	networkManager, resolved, nftables, routes := allFakeParticipants(&calls)
	resolved.failApply = true
	resolved.rollbackFailures = 1
	transaction, _ := newFakeTransaction(t, networkManager, resolved, nftables, routes)
	err := transaction.Execute(context.Background(), validPlan(t), &fakeTransactionCore{calls: &calls})
	var failure *Failure
	if !errors.As(err, &failure) || !failure.RollbackFailed {
		t.Fatalf("rollback failure was not retained: %#v", err)
	}
	if calls[len(calls)-1] != "network_manager:rollback" {
		t.Fatalf("rollback stopped after the injected fault: %#v", calls)
	}
	beforeRetry := len(calls)
	if err := transaction.Restore(context.Background()); err != nil {
		t.Fatal(err)
	}
	if got := calls[beforeRetry:]; !reflect.DeepEqual(got, []string{"resolved:rollback", "routes:rollback", "core:stop", "nftables:rollback"}) {
		t.Fatalf("recovery retried clean participants: %#v", got)
	}
}

func TestTransactionCheckpointFaultRollsBackOnlyArmedOwner(t *testing.T) {
	calls := []string{}
	networkManager, resolved, nftables, routes := allFakeParticipants(&calls)
	resolved.failCheckpoint = true
	transaction, _ := newFakeTransaction(t, networkManager, resolved, nftables, routes)
	err := transaction.Execute(context.Background(), validPlan(t), &fakeTransactionCore{calls: &calls})
	var failure *Failure
	if !errors.As(err, &failure) || failure.Stage != CheckpointStage ||
		failure.Subsystem != Resolved || failure.RollbackFailed {
		t.Fatalf("unexpected checkpoint failure: %#v", err)
	}
	want := []string{
		"routes:checkpoint",
		"nftables:checkpoint",
		"nftables:apply",
		"core:start",
		"routes:apply",
		"network_manager:checkpoint",
		"resolved:checkpoint",
		"network_manager:rollback",
		"routes:rollback",
		"core:stop",
		"nftables:rollback",
	}
	if !reflect.DeepEqual(calls, want) {
		t.Fatalf("checkpoint fault touched an unarmed owner: %#v", calls)
	}
}

func TestTransactionRejectsInvalidPlanBeforeParticipantCall(t *testing.T) {
	calls := []string{}
	networkManager, resolved, nftables, routes := allFakeParticipants(&calls)
	transaction, sink := newFakeTransaction(t, networkManager, resolved, nftables, routes)
	if err := transaction.Execute(context.Background(), Plan{}, &fakeTransactionCore{calls: &calls}); !errors.Is(err, ErrInvalidPlan) {
		t.Fatalf("invalid plan result: %v", err)
	}
	if len(calls) != 0 || len(sink.events) != 0 {
		t.Fatalf("invalid plan reached transaction participants: %#v %#v", calls, sink.events)
	}
}

func TestCancelledCoreStartStillStopsBeforeRemovingTrafficBlock(t *testing.T) {
	calls := []string{}
	nm, dns, nft, routes := allFakeParticipants(&calls)
	transaction, _ := newFakeTransaction(t, nm, dns, nft, routes)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	core := &fakeTransactionCore{calls: &calls, failStart: true, cancel: cancel}
	err := transaction.Execute(ctx, validPlan(t), core)
	var failure *Failure
	if !errors.As(err, &failure) || failure.RollbackFailed {
		t.Fatalf("cleanup failed: %v", err)
	}
	want := []string{"routes:checkpoint", "nftables:checkpoint", "nftables:apply", "core:start", "core:stop", "nftables:rollback"}
	if !reflect.DeepEqual(calls, want) {
		t.Fatalf("unsafe cancelled-start order: %#v", calls)
	}
}

func TestCoreStopFailureKeepsTrafficBlockedUntilRetry(t *testing.T) {
	calls := []string{}
	nm, dns, nft, routes := allFakeParticipants(&calls)
	transaction, _ := newFakeTransaction(t, nm, dns, nft, routes)
	core := &fakeTransactionCore{calls: &calls, stopFailures: 1}
	if err := transaction.Execute(context.Background(), validPlan(t), core); err != nil {
		t.Fatal(err)
	}
	if err := transaction.Restore(context.Background()); err == nil || !nft.pending {
		t.Fatal("stop failure removed traffic block")
	}
	before := len(calls)
	if err := transaction.Restore(context.Background()); err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(calls[before:], []string{"core:stop", "nftables:rollback"}) {
		t.Fatal("retry repeated clean work")
	}
}

func TestTransactionRequiresExactlyOneClosedParticipantSet(t *testing.T) {
	sink := &memorySink{}
	recorder, err := New(sink, "network-1", "connect-1", 1)
	if err != nil {
		t.Fatal(err)
	}
	calls := []string{}
	networkManager, resolved, _, routes := allFakeParticipants(&calls)
	duplicate := &fakeTransactionParticipant{subsystem: Resolved, calls: &calls}
	if _, err := NewTransaction(
		recorder,
		networkManager,
		resolved,
		duplicate,
		routes,
	); !errors.Is(err, ErrInvalidParticipants) {
		t.Fatalf("duplicate participant set accepted: %v", err)
	}
}
