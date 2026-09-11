package networktxn

import (
	"errors"

	"github.com/Kiwunaka/pokrov-app/linux-daemon/internal/journal"
)

type Subsystem uint8

const (
	NetworkManager Subsystem = iota + 1
	Resolved
	Nftables
	Routes
)

type Result uint8

const (
	Passed Result = iota + 1
	Failed
	Unsupported
)

type Sink interface {
	Write(journal.Event)
}

type Recorder struct {
	sink          Sink
	transactionID string
	correlationID string
	generation    uint64
}

func New(
	sink Sink,
	transactionID string,
	correlationID string,
	generation uint64,
) (Recorder, error) {
	if sink == nil || !journal.ValidIdentifier(transactionID) ||
		!journal.ValidIdentifier(correlationID) {
		return Recorder{}, errors.New("invalid network transaction recorder")
	}
	return Recorder{
		sink:          sink,
		transactionID: transactionID,
		correlationID: correlationID,
		generation:    generation,
	}, nil
}

func (recorder Recorder) Checkpoint(subsystem Subsystem, result Result) error {
	return recorder.record("checkpoint", subsystem, result)
}

func (recorder Recorder) Apply(subsystem Subsystem, result Result) error {
	return recorder.record("apply", subsystem, result)
}

func (recorder Recorder) Rollback(subsystem Subsystem, result Result) error {
	return recorder.record("rollback", subsystem, result)
}

func (recorder Recorder) record(stage string, subsystem Subsystem, result Result) error {
	subsystemName := map[Subsystem]string{
		NetworkManager: "network_manager",
		Resolved:       "resolved",
		Nftables:       "nftables",
		Routes:         "routes",
	}[subsystem]
	if subsystemName == "" {
		return errors.New("invalid network transaction subsystem")
	}
	outcome := ""
	errorCode := ""
	switch result {
	case Passed:
		outcome = "pass"
	case Failed:
		outcome = "reject"
		errorCode = map[string]string{
			"checkpoint": "linux_network_checkpoint_failed",
			"apply":      "linux_network_apply_failed",
			"rollback":   "linux_network_rollback_failed",
		}[stage]
	case Unsupported:
		outcome = "unavailable"
		errorCode = "linux_network_unsupported"
	default:
		return errors.New("invalid network transaction result")
	}
	recorder.sink.Write(journal.Event{
		Name:          "network_transaction",
		Outcome:       outcome,
		CorrelationID: recorder.correlationID,
		ErrorCode:     errorCode,
		Generation:    recorder.generation,
		TransactionID: recorder.transactionID,
		Subsystem:     subsystemName,
		Stage:         stage,
	})
	return nil
}
