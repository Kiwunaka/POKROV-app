package networktxn

import (
	"context"
	"errors"
	"net/netip"
	"regexp"
	"sync"

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
}

var (
	checkpointOrder = []Subsystem{NetworkManager, Resolved, Nftables}
	applyOrder      = []Subsystem{Resolved, Nftables, NetworkManager}
	rollbackOrder   = []Subsystem{Nftables, Resolved, NetworkManager}
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

func (transaction *Transaction) Execute(ctx context.Context, plan Plan) error {
	transaction.mu.Lock()
	defer transaction.mu.Unlock()
	if !plan.valid() {
		return ErrInvalidPlan
	}
	if transaction.state != transactionFresh {
		return ErrInvalidState
	}
	transaction.plan = plan
	for _, subsystem := range checkpointOrder {
		participant := transaction.participants[subsystem]
		if err := participant.Checkpoint(ctx, plan); err != nil {
			_ = transaction.recorder.Checkpoint(subsystem, Failed)
			rollbackFailed := transaction.rollback(ctx, plan)
			transaction.setFailureState(rollbackFailed)
			return &Failure{
				Stage:          CheckpointStage,
				Subsystem:      subsystem,
				RollbackFailed: rollbackFailed,
			}
		}
		if err := transaction.recorder.Checkpoint(subsystem, Passed); err != nil {
			rollbackFailed := transaction.rollback(ctx, plan)
			transaction.setFailureState(rollbackFailed)
			return ErrInvalidParticipants
		}
	}
	for _, subsystem := range applyOrder {
		participant := transaction.participants[subsystem]
		if err := participant.Apply(ctx, plan); err != nil {
			_ = transaction.recorder.Apply(subsystem, Failed)
			rollbackFailed := transaction.rollback(ctx, plan)
			transaction.setFailureState(rollbackFailed)
			return &Failure{
				Stage:          ApplyStage,
				Subsystem:      subsystem,
				RollbackFailed: rollbackFailed,
			}
		}
		if err := transaction.recorder.Apply(subsystem, Passed); err != nil {
			rollbackFailed := transaction.rollback(ctx, plan)
			transaction.setFailureState(rollbackFailed)
			return ErrInvalidParticipants
		}
	}
	transaction.state = transactionActive
	return nil
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
	for _, subsystem := range rollbackOrder {
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
	}
	return failed
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
