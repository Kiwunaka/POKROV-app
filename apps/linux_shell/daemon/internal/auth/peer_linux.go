//go:build linux

package auth

import (
	"context"
	"errors"
	"fmt"
	"net"
	"os"
	"os/exec"
	"strconv"
	"strings"
	"syscall"
	"time"
)

const ManageActionID = "space.pokrov.linux.manage"

type Peer struct {
	PID       int
	UID       uint32
	StartTime uint64
}

func PeerFrom(connection *net.UnixConn) (Peer, error) {
	raw, err := connection.SyscallConn()
	if err != nil {
		return Peer{}, errors.New("peer credentials unavailable")
	}
	var credentials *syscall.Ucred
	var socketErr error
	if err := raw.Control(func(fd uintptr) {
		credentials, socketErr = syscall.GetsockoptUcred(
			int(fd),
			syscall.SOL_SOCKET,
			syscall.SO_PEERCRED,
		)
	}); err != nil || socketErr != nil || credentials == nil {
		return Peer{}, errors.New("peer credentials unavailable")
	}
	startTime, err := processStartTime(int(credentials.Pid))
	if err != nil {
		return Peer{}, errors.New("peer process identity unavailable")
	}
	return Peer{
		PID:       int(credentials.Pid),
		UID:       credentials.Uid,
		StartTime: startTime,
	}, nil
}

type Checker interface {
	Check(actionID, process string) bool
}

type PolkitChecker struct{}

func (PolkitChecker) Check(actionID, process string) bool {
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()
	command := exec.CommandContext(
		ctx,
		"pkcheck",
		"--action-id", actionID,
		"--process", process,
		"--allow-user-interaction",
	)
	command.Stdout = nil
	command.Stderr = nil
	return command.Run() == nil
}

func Authorized(peer Peer, checker Checker) bool {
	if peer.PID <= 0 || peer.StartTime == 0 {
		return false
	}
	if peer.UID == 0 {
		return true
	}
	if checker == nil {
		checker = PolkitChecker{}
	}
	process := fmt.Sprintf("%d,%d,%d", peer.PID, peer.StartTime, peer.UID)
	return checker.Check(ManageActionID, process)
}

func processStartTime(pid int) (uint64, error) {
	content, err := os.ReadFile(fmt.Sprintf("/proc/%d/stat", pid))
	if err != nil || len(content) > 16*1024 {
		return 0, errors.New("process stat unavailable")
	}
	closing := strings.LastIndexByte(string(content), ')')
	if closing < 0 || closing+2 >= len(content) {
		return 0, errors.New("process stat invalid")
	}
	fields := strings.Fields(string(content[closing+2:]))
	// The suffix begins with field 3 (state); index 19 is field 22 (starttime).
	if len(fields) <= 19 {
		return 0, errors.New("process stat incomplete")
	}
	value, err := strconv.ParseUint(fields[19], 10, 64)
	if err != nil || value == 0 {
		return 0, errors.New("process start time invalid")
	}
	return value, nil
}
