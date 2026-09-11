package networktxn

import (
	"context"
	"errors"
	"net/netip"
	"reflect"
	"strings"
	"testing"
)

type commandCall struct {
	name      string
	arguments []string
	input     string
}

type commandResponse struct {
	output string
	err    error
}

type scriptedCommandRunner struct {
	calls     []commandCall
	responses []commandResponse
}

func (runner *scriptedCommandRunner) Run(
	_ context.Context,
	name string,
	arguments []string,
	input []byte,
) ([]byte, error) {
	runner.calls = append(runner.calls, commandCall{
		name:      name,
		arguments: append([]string(nil), arguments...),
		input:     string(input),
	})
	if len(runner.responses) == 0 {
		return nil, errors.New("unexpected command")
	}
	response := runner.responses[0]
	runner.responses = runner.responses[1:]
	return []byte(response.output), response.err
}

func TestPlanRejectsUnownedOrOpenNetworkInputs(t *testing.T) {
	validDNS := []netip.Addr{netip.MustParseAddr("1.1.1.1")}
	tests := []struct {
		name          string
		interfaceName string
		mark          uint32
		dns           []netip.Addr
	}{
		{"foreign interface", "tun0", 1, validDNS},
		{"open interface", `pokrov0"; flush ruleset`, 1, validDNS},
		{"long interface", "pokrov1234567890", 1, validDNS},
		{"zero mark", "pokrov0", 0, validDNS},
		{"no dns", "pokrov0", 1, nil},
		{"loopback dns", "pokrov0", 1, []netip.Addr{netip.MustParseAddr("127.0.0.1")}},
		{"link local dns", "pokrov0", 1, []netip.Addr{netip.MustParseAddr("fe80::1")}},
		{"duplicate dns", "pokrov0", 1, []netip.Addr{netip.MustParseAddr("1.1.1.1"), netip.MustParseAddr("1.1.1.1")}},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			if _, err := NewPlan(test.interfaceName, test.mark, test.dns); !errors.Is(err, ErrInvalidPlan) {
				t.Fatalf("invalid plan accepted: %v", err)
			}
		})
	}
}

func TestNetworkManagerUsesBoundedSystemDBusCheckpointLifecycle(t *testing.T) {
	runner := &scriptedCommandRunner{responses: []commandResponse{
		{output: `s ":1.42"`},
		{output: "o \"/org/freedesktop/NetworkManager/Devices/8\"\n"},
		{output: "o \"/org/freedesktop/NetworkManager/Checkpoint/17\"\n"},
		{},
	}}
	participant := &networkManagerParticipant{runner: runner}
	if err := participant.Checkpoint(context.Background(), validPlan(t)); err != nil {
		t.Fatal(err)
	}
	if !participant.PendingRollback() {
		t.Fatal("checkpoint was not retained for rollback")
	}
	if err := participant.Apply(context.Background(), validPlan(t)); err != nil {
		t.Fatal(err)
	}
	if participant.PendingRollback() {
		t.Fatal("committed checkpoint remained armed")
	}
	if got := runner.calls[2].arguments[len(runner.calls[2].arguments)-5:]; !reflect.DeepEqual(got, []string{"aouu", "1", "/org/freedesktop/NetworkManager/Devices/8", "90", "0"}) {
		t.Fatalf("unexpected checkpoint contract: %#v", got)
	}
	if got := runner.calls[3].arguments[6]; got != "CheckpointDestroy" {
		t.Fatalf("checkpoint was not committed: %q", got)
	}
}

func TestNetworkManagerRollbackUsesOnlyReturnedObjectPath(t *testing.T) {
	runner := &scriptedCommandRunner{responses: []commandResponse{
		{output: `s ":1.42"`},
		{output: "o /org/freedesktop/NetworkManager/Devices/8"},
		{output: "o /org/freedesktop/NetworkManager/Checkpoint/abc_9"},
		{output: "a{su} 1 \"/org/freedesktop/NetworkManager/Devices/8\" 0"},
	}}
	participant := &networkManagerParticipant{runner: runner}
	if err := participant.Checkpoint(context.Background(), validPlan(t)); err != nil {
		t.Fatal(err)
	}
	if err := participant.Rollback(context.Background(), validPlan(t)); err != nil {
		t.Fatal(err)
	}
	call := runner.calls[3]
	if call.arguments[6] != "CheckpointRollback" ||
		call.arguments[len(call.arguments)-1] != "/org/freedesktop/NetworkManager/Checkpoint/abc_9" {
		t.Fatalf("unexpected rollback call: %#v", call)
	}
	for _, output := range [][]byte{
		[]byte(""),
		[]byte("s not-an-object"),
		[]byte(`o "/tmp/open"`),
		[]byte(`o "/org/freedesktop/NetworkManager/Checkpoint/1`),
		[]byte(`o "/org/freedesktop/NetworkManager/Checkpoint/1" trailing`),
	} {
		if _, err := parseCheckpointPath(output); err == nil {
			t.Fatalf("open checkpoint output accepted: %q", output)
		}
	}
}

func TestResolvedPartialApplyRevertsOnlyOwnedTunnelLink(t *testing.T) {
	runner := &scriptedCommandRunner{responses: []commandResponse{
		{},
		{},
		{err: errors.New("injected domain failure")},
		{},
	}}
	participant := &resolvedParticipant{runner: runner}
	plan := validPlan(t)
	if err := participant.Checkpoint(context.Background(), plan); err != nil {
		t.Fatal(err)
	}
	if err := participant.Apply(context.Background(), plan); err == nil {
		t.Fatal("partial resolved apply unexpectedly passed")
	}
	if !participant.PendingRollback() {
		t.Fatal("partial resolved apply did not arm rollback")
	}
	if err := participant.Rollback(context.Background(), plan); err != nil {
		t.Fatal(err)
	}
	want := [][]string{
		{"status", "pokrov0"},
		{"dns", "pokrov0", "1.1.1.1", "2606:4700:4700::1111"},
		{"domain", "pokrov0", "~."},
		{"revert", "pokrov0"},
	}
	for index, arguments := range want {
		if !reflect.DeepEqual(runner.calls[index].arguments, arguments) {
			t.Fatalf("unexpected resolvectl call %d: %#v", index, runner.calls[index])
		}
	}
}

func TestNftablesOwnsOneAtomicTableAndRestoresIt(t *testing.T) {
	runner := &scriptedCommandRunner{responses: []commandResponse{
		{output: `{"nftables":[{"metainfo":{"json_schema_version":1}}]}`},
		{},
		{},
		{output: `{"nftables":[{"table":{"family":"inet","name":"pokrov"}}]}`},
		{output: `{"nftables":[{"table":{"family":"inet","name":"pokrov","comment":"pokrov-linuxd:0123456789abcdef0123456789abcdef"}}]}`},
		{},
		{},
	}}
	participant := &nftablesParticipant{runner: runner, owner: "0123456789abcdef0123456789abcdef"}
	plan := validPlan(t)
	if err := participant.Checkpoint(context.Background(), plan); err != nil {
		t.Fatal(err)
	}
	if err := participant.Apply(context.Background(), plan); err != nil {
		t.Fatal(err)
	}
	if err := participant.Rollback(context.Background(), plan); err != nil {
		t.Fatal(err)
	}
	rules := runner.calls[1].input
	for _, required := range []string{
		"table inet pokrov",
		`oifname "pokrov0" accept`,
		"meta mark 0x504f4b52 accept",
		"policy drop",
	} {
		if !strings.Contains(rules, required) {
			t.Fatalf("missing nft rule %q in:\n%s", required, rules)
		}
	}
	if strings.Contains(rules, "flush ruleset") {
		t.Fatalf("global nft ownership escaped: %s", rules)
	}
	if runner.calls[1].arguments[0] != "--check" ||
		runner.calls[2].arguments[0] != "--file" {
		t.Fatalf("nft rules were not validated before apply: %#v", runner.calls)
	}
	if got := runner.calls[5].input; got != "delete table inet pokrov\n" {
		t.Fatalf("rollback escaped the owned table: %q", got)
	}
}

func TestNftablesRejectsPreexistingOwnedTable(t *testing.T) {
	runner := &scriptedCommandRunner{responses: []commandResponse{{
		output: `{"nftables":[{"table":{"family":"inet","name":"pokrov"}}]}`,
	}}}
	participant := &nftablesParticipant{runner: runner, owner: "0123456789abcdef0123456789abcdef"}
	if err := participant.Checkpoint(context.Background(), validPlan(t)); err == nil {
		t.Fatal("preexisting owned table was overwritten")
	}
	if len(runner.calls) != 1 {
		t.Fatalf("preexisting table reached mutation: %#v", runner.calls)
	}
}
