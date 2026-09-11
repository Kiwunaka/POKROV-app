package networktxn

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strconv"
)

const (
	ownedRouteTable    = 20555
	ownedRulePriority  = 20555
	ownedRouteProtocol = 243
	ownedRouteMetric   = 42700
)

type routeParticipant struct {
	runner commandRunner
	dirty  bool
}

func (p *routeParticipant) Subsystem() Subsystem  { return Routes }
func (p *routeParticipant) PendingRollback() bool { return p.dirty }

func (p *routeParticipant) Checkpoint(ctx context.Context, _ Plan) error {
	for _, family := range []string{"-4", "-6"} {
		rules, err := p.list(ctx, family, "rule")
		if err != nil {
			return err
		}
		for _, rule := range rules {
			if number(rule["priority"]) == ownedRulePriority || number(rule["table"]) == ownedRouteTable {
				return errors.New("policy route ownership unavailable")
			}
		}
		routes, err := p.list(ctx, family, "route")
		if err != nil {
			return err
		}
		for _, route := range routes {
			if number(route["table"]) == ownedRouteTable {
				return errors.New("route table ownership unavailable")
			}
		}
	}
	return nil
}

func (p *routeParticipant) Apply(ctx context.Context, plan Plan) error {
	p.dirty = true
	for _, family := range []string{"-4", "-6"} {
		if _, err := p.runner.Run(ctx, "ip", routeArguments(family, "add", plan), nil); err != nil {
			return err
		}
		if _, err := p.runner.Run(ctx, "ip", ruleArguments(family, "add", plan), nil); err != nil {
			return err
		}
	}
	return nil
}

func (p *routeParticipant) Rollback(ctx context.Context, plan Plan) error {
	if !p.dirty {
		return nil
	}
	for _, family := range []string{"-4", "-6"} {
		for _, kind := range []string{"rule", "route"} {
			objects, err := p.list(ctx, family, kind)
			if err != nil {
				return err
			}
			matches := 0
			for _, object := range objects {
				if number(object["table"]) != ownedRouteTable || number(object["protocol"]) != ownedRouteProtocol {
					continue
				}
				if !ownedRouteObject(kind, family, object, plan) {
					return errors.New("policy route ownership changed")
				}
				matches++
			}
			if matches > 1 {
				return errors.New("ambiguous policy route ownership")
			}
			if matches == 1 {
				args := ruleArguments(family, "del", plan)
				if kind == "route" {
					args = routeArguments(family, "del", plan)
				}
				if _, err := p.runner.Run(ctx, "ip", args, nil); err != nil {
					return err
				}
			}
		}
	}
	p.dirty = false
	return nil
}

func (p *routeParticipant) list(ctx context.Context, family, kind string) ([]map[string]json.RawMessage, error) {
	args := []string{"-N", "-j", family, kind, "show"}
	if kind == "route" {
		args = append(args, "table", "all")
	}
	data, err := p.runner.Run(ctx, "ip", args, nil)
	if err != nil {
		return nil, err
	}
	var entries []map[string]json.RawMessage
	if json.Unmarshal(data, &entries) != nil || entries == nil {
		return nil, errors.New("policy route listing invalid")
	}
	return entries, nil
}

func ruleArguments(family, action string, plan Plan) []string {
	return []string{family, "rule", action, "priority", strconv.Itoa(ownedRulePriority), "not", "fwmark", fmt.Sprintf("0x%x/0xffffffff", plan.routingMark), "table", strconv.Itoa(ownedRouteTable), "protocol", strconv.Itoa(ownedRouteProtocol)}
}

func routeArguments(family, action string, plan Plan) []string {
	args := []string{family, "route", action}
	if family == "-6" && !plan.ipv6() {
		args = append(args, "unreachable", "default")
	} else {
		args = append(args, "default", "dev", plan.tunnelInterface)
	}
	return append(args, "table", strconv.Itoa(ownedRouteTable), "proto", strconv.Itoa(ownedRouteProtocol), "metric", strconv.Itoa(ownedRouteMetric))
}

func ownedRouteObject(kind, family string, object map[string]json.RawMessage, plan Plan) bool {
	allowed := map[string]bool{"table": true, "protocol": true}
	if kind == "rule" {
		for _, key := range []string{"priority", "not", "src", "fwmark", "fwmask"} {
			allowed[key] = true
		}
		if number(object["priority"]) != ownedRulePriority || string(object["src"]) != `"all"` || string(object["fwmark"]) != fmt.Sprintf(`"0x%x"`, plan.routingMark) {
			return false
		}
		if _, ok := object["not"]; !ok {
			return false
		}
		if mask, ok := object["fwmask"]; ok && string(mask) != `"0xffffffff"` {
			return false
		}
	} else {
		for _, key := range []string{"dst", "dev", "type", "scope", "metric", "flags", "pref"} {
			allowed[key] = true
		}
		if string(object["dst"]) != `"default"` || number(object["metric"]) != ownedRouteMetric {
			return false
		}
		if family == "-6" && !plan.ipv6() {
			if string(object["type"]) != `"unreachable"` || len(object["dev"]) != 0 {
				return false
			}
		} else if string(object["dev"]) != strconv.Quote(plan.tunnelInterface) || (len(object["type"]) != 0 && string(object["type"]) != `"unicast"`) {
			return false
		}
		if flags, ok := object["flags"]; ok && string(flags) != "[]" {
			return false
		}
		// ip -N renders route scopes numerically (253=link, 0=global).
		if scope, ok := object["scope"]; ok && number(scope) != 253 && number(scope) != 0 {
			return false
		}
		if pref, ok := object["pref"]; ok && string(pref) != `"medium"` {
			return false
		}
	}
	for key := range object {
		if !allowed[key] {
			return false
		}
	}
	return true
}

func number(raw json.RawMessage) int {
	var text string
	if json.Unmarshal(raw, &text) != nil {
		text = string(raw)
	}
	value, err := strconv.Atoi(text)
	if err != nil {
		return -1
	}
	return value
}

func (plan Plan) ipv6() bool {
	for _, address := range plan.dnsServers {
		if address.Is6() {
			return true
		}
	}
	return false
}
