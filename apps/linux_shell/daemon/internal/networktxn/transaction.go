package networktxn

import (
	"context"
	"errors"
	"net/netip"
	"regexp"
	"sync"
	"time"

	"github.com/Kiwunaka/pokrov-app/linux-daemon/internal/journal"
)

var (
	ErrInvalidPlan         = errors.New("invalid network transaction plan")
	ErrInvalidParticipants = errors.New("invalid network transaction participants")
	ErrInvalidState        = errors.New("invalid network transaction state")
)

var tunnelInterfacePattern = regexp.MustCompile(`^pokrov[A-Za-z0-9_.-]{0,9}$`)

type Stage uint8

const (
	CheckpointStage Stage = iota + 1
	ApplyStage
	RollbackStage
)

type Plan struct {
	tunnelInterface string
	routingMark     uint32
	dnsServers      []netip.Addr
}

func NewPlan(
	tunnelInterface string,
	routingMark uint32,
	dnsServers []netip.Addr,
) (Plan, error) {
	if !tunnelInterfacePattern.MatchString(tunnelInterface) ||
		routingMark == 0 || len(dnsServers) == 0 || len(dnsServers) > 4 {
		return Plan{}, ErrInvalidPlan
	}
	normalized := make([]netip.Addr, 0, len(dnsServers))
	seen := make(map[netip.Addr]struct{}, len(dnsServers))
	for _, server := range dnsServers {
		server = server.Unmap()
		if !server.IsValid() || server.Zone() != "" || server.IsUnspecified() ||
			server.IsLoopback() || server.IsMulticast() || server.IsLinkLocalUnicast() {
			return Plan{}, ErrInvalidPlan
		}
		if _, exists := seen[server]; exists {
			return Plan{}, ErrInvalidPlan
		}
		seen[server] = struct{}{}
		normalized = append(normalized, server)
	}
	return Plan{
		tunnelInterface: tunnelInterface,
		routingMark:     routingMark,
		dnsServers:      normalized,
	}, nil
}

func (plan Plan) valid() bool {
	_, err := NewPlan(plan.tunnelInterface, plan.routingMark, plan.dnsServers)
	return err == nil
}

type Participant interface {
	Subsystem() Subsystem
	Checkpoint(context.Context, Plan) error
	Apply(context.Context, Plan) error
	Rollback(context.Context, Plan) error
	PendingRollback() bool
}

// Core is the one child runtime owned by this network transaction.
type Core interface {
	Start(context.Context) error
	Stop(context.Context) error
}

type Failure struct {
	Stage          Stage
	Subsystem      Subsystem
	RollbackFailed bool
}

func (failure *Failure) Error() string {
	if failure.RollbackFailed {
		return "network transaction failed and requires recovery"
	}
	return "network transaction failed"
}

type transactionState uint8

const (
	transactionFresh transactionState = iota
	transactionActive
	transactionRecovered
	transactionRecoveryRequired
)

type Transaction struct {
	mu           sync.Mutex
	recorder     Recorder
	participants map[Subsystem]Participant
	plan         Plan
	state        transactionState
	core         Core
	corePending  bool
	recovery     *recoveryLog
}

var (
	checkpointOrder = []Subsystem{NetworkManager, Resolved, Nftables, Routes}
)

func NewTransaction(recorder Recorder, participants ...Participant) (*Transaction, error) {
	if recorder.sink == nil || !journalIdentifiersValid(recorder) ||
		len(participants) != len(checkpointOrder) {
		return nil, ErrInvalidParticipants
	}
	bySubsystem := make(map[Subsystem]Participant, len(participants))
	for _, participant := range participants {
		if participant == nil {
			return nil, ErrInvalidParticipants
		}
		subsystem := participant.Subsystem()
		if _, exists := bySubsystem[subsystem]; exists {
			return nil, ErrInvalidParticipants
		}
		bySubsystem[subsystem] = participant
	}
	for _, subsystem := range checkpointOrder {
		if bySubsystem[subsystem] == nil {
			return nil, ErrInvalidParticipants
		}
	}
	return &Transaction{
		recorder:     recorder,
		participants: bySubsystem,
		state:        transactionFresh,
	}, nil
}

func (transaction *Transaction) Execute(ctx context.Context, plan Plan, core Core) error {
	transaction.mu.Lock()
	defer transaction.mu.Unlock()
	if !plan.valid() {
		return ErrInvalidPlan
	}
	if transaction.state != transactionFresh {
		return ErrInvalidState
	}
	if core == nil {
		return ErrInvalidParticipants
	}
	transaction.plan = plan
	transaction.core = core
	// Prepare already created the child; stop it even if a checkpoint fails
	// before the start command reaches Core.
	transaction.corePending = true
	fail := func(stage Stage, subsystem Subsystem) error {
		// Cancellation of connect must not cancel restoration of host state.
		cleanup, cancel := context.WithTimeout(context.WithoutCancel(ctx), 30*time.Second)
		defer cancel()
		rollbackFailed := transaction.rollback(cleanup, plan)
		transaction.setFailureState(rollbackFailed)
		return &Failure{Stage: stage, Subsystem: subsystem, RollbackFailed: rollbackFailed}
	}
	if transaction.beginRecovery(plan) != nil {
		return fail(CheckpointStage, 0)
	}
	if transaction.checkpoint(ctx, Routes) != nil {
		return fail(CheckpointStage, Routes)
	}
	// Block uplink traffic before Core creates routes. Only Core's fixed mark,
	// the owned TUN and necessary link configuration pass this filter.
	if transaction.checkpoint(ctx, Nftables) != nil {
		return fail(CheckpointStage, Nftables)
	}
	if transaction.apply(ctx, Nftables) != nil {
		return fail(ApplyStage, Nftables)
	}
	if core.Start(ctx) != nil {
		return fail(ApplyStage, 0)
	}
	if transaction.recordStartedLink() != nil {
		return fail(ApplyStage, 0)
	}
	if transaction.apply(ctx, Routes) != nil {
		return fail(ApplyStage, Routes)
	}
	// Both owners refer to the actual newly created TUN, never all host links.
	if transaction.checkpoint(ctx, NetworkManager) != nil {
		return fail(CheckpointStage, NetworkManager)
	}
	if transaction.checkpoint(ctx, Resolved) != nil {
		return fail(CheckpointStage, Resolved)
	}
	if transaction.apply(ctx, Resolved) != nil {
		return fail(ApplyStage, Resolved)
	}
	if transaction.apply(ctx, NetworkManager) != nil {
		return fail(ApplyStage, NetworkManager)
	}
	transaction.state = transactionActive
	return nil
}

func (transaction *Transaction) checkpoint(ctx context.Context, subsystem Subsystem) error {
	if err := transaction.participants[subsystem].Checkpoint(ctx, transaction.plan); err != nil {
		_ = transaction.recorder.Checkpoint(subsystem, Failed)
		return err
	}
	if err := transaction.saveRecovery(); err != nil {
		return err
	}
	return transaction.recorder.Checkpoint(subsystem, Passed)
}

func (transaction *Transaction) apply(ctx context.Context, subsystem Subsystem) error {
	if err := transaction.beforeApply(subsystem); err != nil {
		return err
	}
	if err := transaction.participants[subsystem].Apply(ctx, transaction.plan); err != nil {
		_ = transaction.recorder.Apply(subsystem, Failed)
		return err
	}
	if err := transaction.saveRecovery(); err != nil {
		return err
	}
	return transaction.recorder.Apply(subsystem, Passed)
}

func (transaction *Transaction) Restore(ctx context.Context) error {
	transaction.mu.Lock()
	defer transaction.mu.Unlock()
	if transaction.state == transactionRecovered {
		return nil
	}
	if transaction.state != transactionActive &&
		transaction.state != transactionRecoveryRequired {
		return ErrInvalidState
	}
	if transaction.rollback(ctx, transaction.plan) {
		transaction.state = transactionRecoveryRequired
		return &Failure{Stage: RollbackStage, RollbackFailed: true}
	}
	transaction.state = transactionRecovered
	return nil
}

func (transaction *Transaction) rollback(ctx context.Context, plan Plan) bool {
	failed := false
	// Restore per-link owners while the TUN still exists. Keep the traffic
	// block and Core available if one needs a retry.
	for _, subsystem := range []Subsystem{Resolved, NetworkManager} {
		participant := transaction.participants[subsystem]
		if !participant.PendingRollback() {
			continue
		}
		if err := participant.Rollback(ctx, plan); err != nil {
			failed = true
			_ = transaction.recorder.Rollback(subsystem, Failed)
			continue
		}
		if err := transaction.recorder.Rollback(subsystem, Passed); err != nil {
			failed = true
		}
		if err := transaction.saveRecovery(); err != nil {
			failed = true
		}
	}
	if failed {
		return true
	}
	routes := transaction.participants[Routes]
	if routes.PendingRollback() {
		if routes.Rollback(ctx, plan) != nil {
			_ = transaction.recorder.Rollback(Routes, Failed)
			return true
		}
		if transaction.saveRecovery() != nil {
			return true
		}
		_ = transaction.recorder.Rollback(Routes, Passed)
	}
	if transaction.corePending {
		if transaction.core.Stop(ctx) != nil {
			return true
		}
		transaction.corePending = false
	}
	nft := transaction.participants[Nftables]
	if nft.PendingRollback() {
		if nft.Rollback(ctx, plan) != nil {
			_ = transaction.recorder.Rollback(Nftables, Failed)
			return true
		}
		if transaction.recorder.Rollback(Nftables, Passed) != nil {
			return true
		}
		if transaction.saveRecovery() != nil {
			return true
		}
	}
	if transaction.recovery != nil && transaction.recovery.file.Remove() != nil {
		return true
	}
	return false
}

func (transaction *Transaction) setFailureState(rollbackFailed bool) {
	if rollbackFailed {
		transaction.state = transactionRecoveryRequired
		return
	}
	transaction.state = transactionRecovered
}

func journalIdentifiersValid(recorder Recorder) bool {
	return journal.ValidIdentifier(recorder.transactionID) &&
		journal.ValidIdentifier(recorder.correlationID)
}
