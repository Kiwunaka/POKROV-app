package networktxn

import (
	"context"
	"encoding/json"
	"testing"
)

func TestRouteRecoveryPreservesForeignRuleAtSamePriority(t *testing.T) {
	runner := &scriptedCommandRunner{responses: []commandResponse{
		{output: `[{"priority":20555,"src":"198.18.99.0","srclen":24,"table":"main","protocol":"99"},{"priority":20555,"not":null,"src":"all","fwmark":"0x504f4b52","table":"20555","protocol":"243"}]`},
		{}, {output: `[]`}, {output: `[]`}, {output: `[]`},
	}}
	p := &routeParticipant{runner: runner, dirty: true}
	if err := p.Rollback(context.Background(), validPlan(t)); err != nil {
		t.Fatal(err)
	}
	if p.PendingRollback() {
		t.Fatal("clean route state remained pending")
	}
	if len(runner.calls) != 5 {
		t.Fatalf("unexpected route calls: %d", len(runner.calls))
	}
	call := runner.calls[1]
	if call.name != "ip" || call.arguments[2] != "del" || call.arguments[len(call.arguments)-2] != "protocol" || call.arguments[len(call.arguments)-1] != "243" {
		t.Fatal("recovery did not delete the exact owned rule")
	}
}

func TestRouteRecoveryKeepsChangedOwnedObjectForRetry(t *testing.T) {
	runner := &scriptedCommandRunner{responses: []commandResponse{
		{output: `[{"priority":20555,"not":null,"src":"198.18.99.0","srclen":24,"fwmark":"0x504f4b52","table":"20555","protocol":"243"}]`},
	}}
	p := &routeParticipant{runner: runner, dirty: true}
	if p.Rollback(context.Background(), validPlan(t)) == nil || !p.PendingRollback() || len(runner.calls) != 1 {
		t.Fatal("changed ownership was deleted or forgotten")
	}
}

func TestRouteRecoveryAcceptsNativeNumericLinkScope(t *testing.T) {
	runner := &scriptedCommandRunner{responses: []commandResponse{
		{output: `[]`},
		{output: `[{"dst":"default","dev":"pokrov0","table":"20555","protocol":"243","scope":"253","metric":42700,"flags":[]}]`},
		{}, {output: `[]`}, {output: `[]`},
	}}
	p := &routeParticipant{runner: runner, dirty: true}
	if err := p.Rollback(context.Background(), validPlan(t)); err != nil {
		t.Fatal(err)
	}
	if p.PendingRollback() || len(runner.calls) != 5 || runner.calls[2].arguments[2] != "del" {
		t.Fatal("native IPv4 route was not restored")
	}
}

func TestRecoveryRejectsReplacementNftTable(t *testing.T) {
	runner := &scriptedCommandRunner{responses: []commandResponse{
		{output: `{"nftables":[{"table":{"family":"inet","name":"pokrov"}}]}`},
		{output: `{"nftables":[{"table":{"family":"inet","name":"pokrov","comment":"foreign-owner"}}]}`},
	}}
	p := &nftablesParticipant{runner: runner, dirty: true, owner: "0123456789abcdef0123456789abcdef"}
	if p.Rollback(context.Background(), validPlan(t)) == nil || !p.PendingRollback() || len(runner.calls) != 2 {
		t.Fatal("foreign replacement table was deleted or forgotten")
	}
}

func TestRouteMatcherRejectsUnrecognizedSelector(t *testing.T) {
	var object map[string]json.RawMessage
	_ = json.Unmarshal([]byte(`{"priority":20555,"not":null,"src":"all","fwmark":"0x504f4b52","table":"20555","protocol":"243","iif":"foreign0"}`), &object)
	if ownedRouteObject("rule", "-4", object, validPlan(t)) {
		t.Fatal("unrecognized selector accepted")
	}
}
