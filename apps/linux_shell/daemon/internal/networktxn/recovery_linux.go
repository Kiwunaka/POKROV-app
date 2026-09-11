//go:build linux

package networktxn

import (
	"bytes"
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"io"
	"net"
	"net/netip"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
)

const recoveryPath = "/var/lib/pokrov/network-recovery.json"
const recoveryLimit = 4096

type recoveryFile struct {
	path     string
	ownerUID uint32
}

func (file recoveryFile) Load() (*recoveryState, error) {
	f, err := os.OpenFile(file.path, os.O_RDONLY|syscall.O_NOFOLLOW, 0)
	if errors.Is(err, os.ErrNotExist) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	defer f.Close()
	info, err := f.Stat()
	if err != nil || !info.Mode().IsRegular() || info.Mode().Perm()&0o077 != 0 {
		return nil, errors.New("recovery record permissions invalid")
	}
	stat, ok := info.Sys().(*syscall.Stat_t)
	if !ok || stat.Uid != file.ownerUID {
		return nil, errors.New("recovery record owner invalid")
	}
	data, err := io.ReadAll(io.LimitReader(f, recoveryLimit+1))
	if err != nil || len(data) > recoveryLimit {
		return nil, errors.New("recovery record bounds invalid")
	}
	decoder := json.NewDecoder(bytes.NewReader(data))
	decoder.DisallowUnknownFields()
	var state recoveryState
	if decoder.Decode(&state) != nil || !state.valid() {
		return nil, errors.New("recovery record invalid")
	}
	var extra any
	if decoder.Decode(&extra) != io.EOF {
		return nil, errors.New("recovery record trailing data")
	}
	return &state, nil
}

func (file recoveryFile) Save(state recoveryState) error {
	if !state.valid() {
		return errors.New("recovery record invalid")
	}
	data, err := json.Marshal(state)
	if err != nil || len(data) > recoveryLimit {
		return errors.New("recovery record bounds invalid")
	}
	directory := filepath.Dir(file.path)
	f, err := os.CreateTemp(directory, ".network-recovery-*.tmp")
	if err != nil {
		return err
	}
	defer func() { _ = f.Close(); _ = os.Remove(f.Name()) }()
	if err = f.Chmod(0o600); err != nil {
		return err
	}
	if _, err = f.Write(data); err != nil {
		return err
	}
	if err = f.Sync(); err != nil {
		return err
	}
	if err = f.Close(); err != nil {
		return err
	}
	if err = os.Rename(f.Name(), file.path); err != nil {
		return err
	}
	return syncDirectory(directory)
}

func (file recoveryFile) Remove() error {
	if err := os.Remove(file.path); err != nil && !errors.Is(err, os.ErrNotExist) {
		return err
	}
	return syncDirectory(filepath.Dir(file.path))
}

func syncDirectory(path string) error {
	dir, err := os.Open(path)
	if err != nil {
		return err
	}
	defer dir.Close()
	return dir.Sync()
}

func currentBootID() (string, error) {
	data, err := os.ReadFile("/proc/sys/kernel/random/boot_id")
	value := strings.TrimSpace(string(data))
	if err != nil || !bootIDPattern.MatchString(value) {
		return "", errors.New("boot identity unavailable")
	}
	return value, nil
}

func newRecoveryLog(recorder Recorder) (*recoveryLog, error) {
	file := recoveryFile{path: recoveryPath}
	previous, err := file.Load()
	if err != nil || previous != nil {
		return nil, errors.New("previous network recovery required")
	}
	bootID, err := currentBootID()
	if err != nil {
		return nil, err
	}
	token := make([]byte, 16)
	if _, err = rand.Read(token); err != nil {
		return nil, err
	}
	return &recoveryLog{file: file, state: recoveryState{Schema: 1, TransactionID: recorder.transactionID, Generation: recorder.generation, BootID: bootID, Token: hex.EncodeToString(token)}, linkIndex: func(name string) (int, error) {
		link, err := net.InterfaceByName(name)
		if err != nil {
			return 0, err
		}
		return link.Index, nil
	}}, nil
}

// RecoverSystem runs at service start or after its known Core child has exited.
// A live/replaced TUN is never removed here. It needs the normal Core lifecycle.
func RecoverSystem(ctx context.Context, sink Sink) (bool, error) {
	file := recoveryFile{path: recoveryPath}
	state, err := file.Load()
	if err != nil {
		return true, err
	}
	if state == nil {
		return false, nil
	}
	links, err := net.Interfaces()
	if err != nil {
		return true, err
	}
	for _, link := range links {
		if link.Name == "pokrov0" {
			return true, errors.New("live tunnel ownership requires recovery")
		}
	}
	bootID, err := currentBootID()
	if err != nil {
		return true, err
	}
	runner := systemCommandRunner{}
	return true, recoverRecord(ctx, file, state, bootID, runner, sink)
}

func recoverRecord(ctx context.Context, file recoveryStorage, state *recoveryState, bootID string, runner commandRunner, sink Sink) error {
	dns := []netip.Addr{netip.MustParseAddr("172.19.0.2")}
	if state.IPv6 {
		dns = append(dns, netip.MustParseAddr("fdfe:dcba:9876::2"))
	}
	plan, _ := NewPlan("pokrov0", 0x504b, dns)
	nft := &nftablesParticipant{runner: runner, dirty: state.NftPending, owner: state.Token}
	present, err := nft.tablePresent(ctx)
	if err != nil {
		return err
	}
	if present && state.NftPending {
		if err = nft.verifyOwner(ctx); err != nil {
			return err
		}
	}
	// A reboot erased ephemeral kernel/link state. Do not touch current-boot
	// foreign routes based only on an older journal when our table is absent.
	if bootID != state.BootID && !present {
		return file.Remove()
	}
	recorder, err := New(sink, state.TransactionID, "daemon-recovery", state.Generation)
	if err != nil {
		return err
	}
	if state.ResolvedPending {
		// The non-persistent TUN is absent; resolved already dropped its link.
		state.ResolvedPending = false
		if err = file.Save(*state); err != nil {
			return err
		}
		_ = recorder.Rollback(Resolved, Passed)
	}
	if state.NMCheckpoint != "" {
		if bootID == state.BootID {
			if err = destroyOwnedCheckpoint(ctx, runner, *state); err != nil {
				_ = recorder.Rollback(NetworkManager, Failed)
				return err
			}
		}
		state.NMCheckpoint, state.NMDevice, state.NMOwner = "", "", ""
		if err = file.Save(*state); err != nil {
			return err
		}
		_ = recorder.Rollback(NetworkManager, Passed)
	}
	if state.RoutesPending {
		routes := &routeParticipant{runner: runner, dirty: true}
		if err = routes.Rollback(ctx, plan); err != nil {
			_ = recorder.Rollback(Routes, Failed)
			return err
		}
		state.RoutesPending = false
		if err = file.Save(*state); err != nil {
			return err
		}
		_ = recorder.Rollback(Routes, Passed)
	}
	if state.NftPending {
		if err = nft.Rollback(ctx, plan); err != nil {
			_ = recorder.Rollback(Nftables, Failed)
			return err
		}
		state.NftPending = false
		if err = file.Save(*state); err != nil {
			return err
		}
		_ = recorder.Rollback(Nftables, Passed)
	}
	return file.Remove()
}

func destroyOwnedCheckpoint(ctx context.Context, runner commandRunner, state recoveryState) error {
	data, err := runner.Run(ctx, "busctl", []string{"--system", "--no-pager", "call", "org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus", "NameHasOwner", "s", state.NMOwner}, nil)
	if err != nil {
		return err
	}
	if strings.TrimSpace(string(data)) == "b false" {
		return nil
	}
	if strings.TrimSpace(string(data)) != "b true" {
		return errors.New("network manager owner response invalid")
	}
	data, err = runner.Run(ctx, "busctl", []string{"--system", "--no-pager", "get-property", state.NMOwner, "/org/freedesktop/NetworkManager", "org.freedesktop.NetworkManager", "Checkpoints"}, nil)
	if err != nil {
		return err
	}
	fields := strings.Fields(string(data))
	if len(fields) < 2 || fields[0] != "ao" {
		return errors.New("network manager checkpoint listing invalid")
	}
	count, err := strconv.Atoi(fields[1])
	if err != nil || count != len(fields)-2 {
		return errors.New("network manager checkpoint listing invalid")
	}
	found := false
	for _, field := range fields[2:] {
		path := strings.Trim(field, "\"")
		if !networkManagerCheckpointPath.MatchString(path) {
			return errors.New("network manager checkpoint listing invalid")
		}
		if path == state.NMCheckpoint {
			found = true
		}
	}
	if !found {
		return nil
	}
	_, err = runner.Run(ctx, "busctl", []string{"--system", "--no-pager", "call", state.NMOwner, "/org/freedesktop/NetworkManager", "org.freedesktop.NetworkManager", "CheckpointDestroy", "o", state.NMCheckpoint}, nil)
	return err
}
