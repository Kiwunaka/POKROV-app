//go:build linux

package networktxn

import (
	"bytes"
	"context"
	"errors"
	"io"
	"os/exec"
	"time"
)

const (
	commandTimeout     = 5 * time.Second
	commandOutputLimit = 64 * 1024
)

var commandPaths = map[string]string{
	"busctl":     "/usr/bin/busctl",
	"resolvectl": "/usr/bin/resolvectl",
	"nft":        "/usr/sbin/nft",
	"ip":         "/usr/sbin/ip",
}

type systemCommandRunner struct{}

func (systemCommandRunner) Run(
	ctx context.Context,
	name string,
	arguments []string,
	input []byte,
) ([]byte, error) {
	path := commandPaths[name]
	if path == "" {
		return nil, errors.New("network command unavailable")
	}
	commandContext, cancel := context.WithTimeout(ctx, commandTimeout)
	defer cancel()
	command := exec.CommandContext(commandContext, path, arguments...)
	if input != nil {
		command.Stdin = bytes.NewReader(input)
	}
	output := &boundedOutput{limit: commandOutputLimit}
	command.Stdout = output
	command.Stderr = io.Discard
	if err := command.Run(); err != nil {
		return nil, errors.New("network command failed")
	}
	if output.overflow {
		return nil, errors.New("network command output rejected")
	}
	return append([]byte(nil), output.buffer.Bytes()...), nil
}

type boundedOutput struct {
	buffer   bytes.Buffer
	limit    int
	overflow bool
}

func (output *boundedOutput) Write(value []byte) (int, error) {
	written := len(value)
	remaining := output.limit - output.buffer.Len()
	if remaining <= 0 {
		output.overflow = true
		return written, nil
	}
	if len(value) > remaining {
		_, _ = output.buffer.Write(value[:remaining])
		output.overflow = true
		return written, nil
	}
	_, _ = output.buffer.Write(value)
	return written, nil
}

func NewSystemTransaction(recorder Recorder) (*Transaction, error) {
	runner := systemCommandRunner{}
	recovery, err := newRecoveryLog(recorder)
	if err != nil {
		return nil, err
	}
	transaction, err := NewTransaction(
		recorder,
		&networkManagerParticipant{runner: runner},
		&resolvedParticipant{runner: runner},
		&nftablesParticipant{runner: runner, owner: recovery.state.Token},
		&routeParticipant{runner: runner},
	)
	if err != nil {
		return nil, err
	}
	transaction.recovery = recovery
	return transaction, nil
}
