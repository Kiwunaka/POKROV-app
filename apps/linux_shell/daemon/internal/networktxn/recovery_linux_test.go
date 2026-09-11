//go:build linux

package networktxn

import (
	"context"
	"os"
	"path/filepath"
	"reflect"
	"testing"
)

func testRecoveryState() recoveryState {
	return recoveryState{Schema: 1, TransactionID: "recovery-test", BootID: "01234567-89ab-cdef-0123-456789abcdef", Token: "0123456789abcdef0123456789abcdef", NftPending: true, RoutesPending: true, TunnelIndex: 8}
}

func TestRecoveryFileSurvivesReloadAndRejectsCorruptRecord(t *testing.T) {
	file := recoveryFile{path: filepath.Join(t.TempDir(), "recovery.json"), ownerUID: uint32(os.Getuid())}
	state := testRecoveryState()
	if err := file.Save(state); err != nil {
		t.Fatal(err)
	}
	loaded, err := file.Load()
	if err != nil || loaded == nil || !reflect.DeepEqual(*loaded, state) {
		t.Fatalf("reload failed: %v", err)
	}
	info, err := os.Stat(file.path)
	if err != nil || info.Mode().Perm() != 0o600 {
		t.Fatal("record is not private")
	}
	if err = os.WriteFile(file.path, []byte(`{"schema":1,"command":"unexpected"}`), 0o600); err != nil {
		t.Fatal(err)
	}
	if _, err = file.Load(); err == nil {
		t.Fatal("corrupt/open recovery record accepted")
	}
	if _, err = os.Stat(file.path); err != nil {
		t.Fatal("invalid recovery evidence was removed")
	}
}

type memoryRecoveryFile struct {
	saved   []recoveryState
	removed bool
}

func (f *memoryRecoveryFile) Save(s recoveryState) error { f.saved = append(f.saved, s); return nil }
func (f *memoryRecoveryFile) Remove() error              { f.removed = true; return nil }

func TestRebootWithNoOwnedTablePreservesCurrentBootRoutes(t *testing.T) {
	state := testRecoveryState()
	file := &memoryRecoveryFile{}
	runner := &scriptedCommandRunner{responses: []commandResponse{{output: `{"nftables":[]}`}}}
	err := recoverRecord(context.Background(), file, &state, "fedcba98-7654-3210-fedc-ba9876543210", runner, &memorySink{})
	if err != nil || !file.removed || len(runner.calls) != 1 {
		t.Fatalf("previous boot mutated current routes: %v", err)
	}
}

func TestRecoveryFailureRetainsRecordAndTrafficBlock(t *testing.T) {
	state := testRecoveryState()
	file := &memoryRecoveryFile{}
	runner := &scriptedCommandRunner{responses: []commandResponse{
		{output: `{"nftables":[{"table":{"family":"inet","name":"pokrov"}}]}`},
		{output: `{"nftables":[{"table":{"family":"inet","name":"pokrov","comment":"pokrov-linuxd:0123456789abcdef0123456789abcdef"}}]}`},
		{output: `[{"priority":20555,"src":"all","fwmark":"0x9999","table":"20555","protocol":"243"}]`},
	}}
	err := recoverRecord(context.Background(), file, &state, state.BootID, runner, &memorySink{})
	if err == nil || file.removed || !state.NftPending || !state.RoutesPending || len(runner.calls) != 3 {
		t.Fatal("failed recovery discarded owned state or traffic block")
	}
}
