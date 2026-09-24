//go:build linux

// Package bootclock owns the suspend-inclusive clock used by Linux attempts.
package bootclock

import (
	"context"
	"errors"
	"os"
	"regexp"
	"strings"
	"syscall"
	"time"
	"unsafe"

	"github.com/Kiwunaka/pokrov-app/linux-daemon/internal/protocol"
)

var ErrDeadline = errors.New("connect_deadline")
var bootPattern = regexp.MustCompile(`^linux:[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$`)

func Read() (*protocol.BootClock, error) {
	data, err := os.ReadFile("/proc/sys/kernel/random/boot_id")
	boot := "linux:" + strings.TrimSpace(string(data))
	if err != nil || !bootPattern.MatchString(boot) { return nil, ErrDeadline }
	var elapsed syscall.Timespec
	_, _, errno := syscall.Syscall(syscall.SYS_CLOCK_GETTIME, 7, uintptr(unsafe.Pointer(&elapsed)), 0)
	seconds, nanos := int64(elapsed.Sec), int64(elapsed.Nsec)
	if errno != 0 || seconds < 0 || nanos < 0 || nanos >= 1000000000 || seconds > 9007199254740 {
		return nil, ErrDeadline
	}
	ms := seconds*1000 + nanos/1000000
	if ms > 9007199254740991 { return nil, ErrDeadline }
	return &protocol.BootClock{Schema: 1, BootRef: boot, ElapsedMS: ms, QuantumMS: 1}, nil
}

type Deadline struct {
	BootRef string `json:"boot_ref"`
	StartedElapsedMS int64 `json:"started_elapsed_ms"`
	DeadlineElapsedMS int64 `json:"deadline_elapsed_ms"`
}

func (deadline Deadline) Valid() bool {
	return bootPattern.MatchString(deadline.BootRef) && deadline.StartedElapsedMS >= 0 &&
		deadline.DeadlineElapsedMS <= 9007199254740991 &&
		deadline.DeadlineElapsedMS > deadline.StartedElapsedMS &&
		deadline.DeadlineElapsedMS-deadline.StartedElapsedMS <= 86400000
}

func (deadline Deadline) Current() bool {
	now, err := Read()
	return err == nil && now.BootRef == deadline.BootRef &&
		now.ElapsedMS >= deadline.StartedElapsedMS && now.ElapsedMS < deadline.DeadlineElapsedMS
}

// The timer only schedules observations. The boot clock, not Go's timer or
// wall clock, decides expiry. Cleanup must use a different context.
func (deadline Deadline) Context(parent context.Context) (context.Context, context.CancelFunc) {
	ctx, cancel := context.WithCancelCause(parent)
	if !deadline.Valid() || !deadline.Current() {
		cancel(ErrDeadline)
		return ctx, func() { cancel(context.Canceled) }
	}
	go func() {
		ticker := time.NewTicker(100 * time.Millisecond)
		defer ticker.Stop()
		for {
			select {
			case <-ctx.Done(): return
			case <-ticker.C:
				if !deadline.Current() { cancel(ErrDeadline); return }
			}
		}
	}()
	return ctx, func() { cancel(context.Canceled) }
}
