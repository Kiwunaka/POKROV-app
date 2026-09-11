package networktxn

import (
	"errors"
	"regexp"

	"github.com/Kiwunaka/pokrov-app/linux-daemon/internal/journal"
)

var ownerTokenPattern = regexp.MustCompile(`^[a-f0-9]{32}$`)
var bootIDPattern = regexp.MustCompile(`^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$`)
var busOwnerPattern = regexp.MustCompile(`^:[0-9]+\.[0-9]+$`)

// This private write-ahead record contains ownership, never profile material.
type recoveryState struct {
	Schema          int    `json:"schema"`
	TransactionID   string `json:"transaction_id"`
	Generation      uint64 `json:"generation"`
	BootID          string `json:"boot_id"`
	Token           string `json:"token"`
	TunnelIndex     int    `json:"tunnel_index"`
	IPv6            bool   `json:"ipv6"`
	NftPending      bool   `json:"nft_pending"`
	RoutesPending   bool   `json:"routes_pending"`
	ResolvedPending bool   `json:"resolved_pending"`
	NMCheckpoint    string `json:"nm_checkpoint"`
	NMDevice        string `json:"nm_device"`
	NMOwner         string `json:"nm_owner"`
}

func (s recoveryState) valid() bool {
	if s.Schema != 1 || !journal.ValidIdentifier(s.TransactionID) || !bootIDPattern.MatchString(s.BootID) || !ownerTokenPattern.MatchString(s.Token) || s.TunnelIndex < 0 {
		return false
	}
	if s.NMCheckpoint == "" {
		return s.NMDevice == "" && s.NMOwner == ""
	}
	return networkManagerCheckpointPath.MatchString(s.NMCheckpoint) && networkManagerDevicePath.MatchString(s.NMDevice) && busOwnerPattern.MatchString(s.NMOwner)
}

type recoveryStorage interface {
	Save(recoveryState) error
	Remove() error
}

type recoveryLog struct {
	state     recoveryState
	file      recoveryStorage
	linkIndex func(string) (int, error)
}

func (transaction *Transaction) beginRecovery(plan Plan) error {
	if transaction.recovery == nil {
		return nil
	} // Injected in-memory transaction tests.
	transaction.recovery.state.IPv6 = plan.ipv6()
	return transaction.recovery.file.Save(transaction.recovery.state)
}

func (transaction *Transaction) recordStartedLink() error {
	if transaction.recovery == nil {
		return nil
	}
	index, err := transaction.recovery.linkIndex(transaction.plan.tunnelInterface)
	if err != nil {
		return err
	}
	transaction.recovery.state.TunnelIndex = index
	return transaction.recovery.file.Save(transaction.recovery.state)
}

func (transaction *Transaction) beforeApply(subsystem Subsystem) error {
	if transaction.recovery == nil {
		return nil
	}
	state := &transaction.recovery.state
	switch subsystem {
	case Nftables:
		state.NftPending = true
	case Routes:
		state.RoutesPending = true
	case Resolved:
		state.ResolvedPending = true
	}
	return transaction.recovery.file.Save(*state)
}

func (transaction *Transaction) saveRecovery() error {
	if transaction.recovery == nil {
		return nil
	}
	state := &transaction.recovery.state
	nm, ok := transaction.participants[NetworkManager].(*networkManagerParticipant)
	if !ok {
		return errors.New("durable network owner unavailable")
	}
	state.NMCheckpoint, state.NMDevice, state.NMOwner = nm.checkpointPath, nm.devicePath, nm.busOwner
	if state.NMCheckpoint == "" {
		state.NMDevice, state.NMOwner = "", ""
	}
	state.NftPending = transaction.participants[Nftables].PendingRollback()
	state.RoutesPending = transaction.participants[Routes].PendingRollback()
	state.ResolvedPending = transaction.participants[Resolved].PendingRollback()
	return transaction.recovery.file.Save(*state)
}
