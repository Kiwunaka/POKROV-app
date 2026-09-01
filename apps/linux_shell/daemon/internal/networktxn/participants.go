package networktxn

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"regexp"
	"strconv"
	"strings"
)

const (
	networkManagerCheckpointSeconds = 90
	networkManagerCheckpointFlags   = 0x02 | 0x04 | 0x20
	pokrovNftFamily                 = "inet"
	pokrovNftTable                  = "pokrov"
)

var networkManagerCheckpointPath = regexp.MustCompile(
	`^/org/freedesktop/NetworkManager/Checkpoint/[A-Za-z0-9_]+$`,
)

type commandRunner interface {
	Run(context.Context, string, []string, []byte) ([]byte, error)
}

type networkManagerParticipant struct {
	runner         commandRunner
	checkpointPath string
}

func (participant *networkManagerParticipant) Subsystem() Subsystem {
	return NetworkManager
}

func (participant *networkManagerParticipant) Checkpoint(
	ctx context.Context,
	_ Plan,
) error {
	if participant.runner == nil || participant.checkpointPath != "" {
		return errors.New("network manager checkpoint unavailable")
	}
	output, err := participant.runner.Run(ctx, "busctl", []string{
		"--system",
		"--no-pager",
		"call",
		"org.freedesktop.NetworkManager",
		"/org/freedesktop/NetworkManager",
		"org.freedesktop.NetworkManager",
		"CheckpointCreate",
		"aouu",
		"0",
		strconv.Itoa(networkManagerCheckpointSeconds),
		strconv.Itoa(networkManagerCheckpointFlags),
	}, nil)
	if err != nil {
		return errors.New("network manager checkpoint unavailable")
	}
	path, err := parseCheckpointPath(output)
	if err != nil {
		return err
	}
	participant.checkpointPath = path
	return nil
}

func (participant *networkManagerParticipant) Apply(
	ctx context.Context,
	_ Plan,
) error {
	if participant.checkpointPath == "" {
		return errors.New("network manager checkpoint missing")
	}
	_, err := participant.runner.Run(ctx, "busctl", []string{
		"--system",
		"--no-pager",
		"call",
		"org.freedesktop.NetworkManager",
		"/org/freedesktop/NetworkManager",
		"org.freedesktop.NetworkManager",
		"CheckpointDestroy",
		"o",
		participant.checkpointPath,
	}, nil)
	if err != nil {
		return errors.New("network manager checkpoint commit failed")
	}
	participant.checkpointPath = ""
	return nil
}

func (participant *networkManagerParticipant) Rollback(
	ctx context.Context,
	_ Plan,
) error {
	if participant.checkpointPath == "" {
		return nil
	}
	_, err := participant.runner.Run(ctx, "busctl", []string{
		"--system",
		"--no-pager",
		"call",
		"org.freedesktop.NetworkManager",
		"/org/freedesktop/NetworkManager",
		"org.freedesktop.NetworkManager",
		"CheckpointRollback",
		"o",
		participant.checkpointPath,
	}, nil)
	if err != nil {
		return errors.New("network manager rollback failed")
	}
	participant.checkpointPath = ""
	return nil
}

func (participant *networkManagerParticipant) PendingRollback() bool {
	return participant.checkpointPath != ""
}

func parseCheckpointPath(output []byte) (string, error) {
	value := strings.TrimSpace(string(output))
	if !strings.HasPrefix(value, "o ") {
		return "", errors.New("network manager checkpoint response invalid")
	}
	value = strings.TrimSpace(strings.TrimPrefix(value, "o "))
	if strings.HasPrefix(value, `"`) || strings.HasSuffix(value, `"`) {
		if len(value) < 2 || !strings.HasPrefix(value, `"`) ||
			!strings.HasSuffix(value, `"`) {
			return "", errors.New("network manager checkpoint response invalid")
		}
		unquoted, err := strconv.Unquote(value)
		if err != nil {
			return "", errors.New("network manager checkpoint response invalid")
		}
		value = unquoted
	}
	if !networkManagerCheckpointPath.MatchString(value) {
		return "", errors.New("network manager checkpoint response invalid")
	}
	return value, nil
}

type resolvedParticipant struct {
	runner commandRunner
	dirty  bool
}

func (participant *resolvedParticipant) Subsystem() Subsystem {
	return Resolved
}

func (participant *resolvedParticipant) Checkpoint(
	ctx context.Context,
	plan Plan,
) error {
	if participant.runner == nil || participant.dirty {
		return errors.New("resolved checkpoint unavailable")
	}
	_, err := participant.runner.Run(
		ctx,
		"resolvectl",
		[]string{"status", plan.tunnelInterface},
		nil,
	)
	if err != nil {
		return errors.New("resolved link unavailable")
	}
	return nil
}

func (participant *resolvedParticipant) Apply(
	ctx context.Context,
	plan Plan,
) error {
	if participant.dirty {
		return errors.New("resolved transaction already active")
	}
	participant.dirty = true
	dnsArguments := []string{"dns", plan.tunnelInterface}
	for _, server := range plan.dnsServers {
		dnsArguments = append(dnsArguments, server.String())
	}
	commands := [][]string{
		dnsArguments,
		{"domain", plan.tunnelInterface, "~."},
		{"default-route", plan.tunnelInterface, "true"},
	}
	for _, arguments := range commands {
		if _, err := participant.runner.Run(ctx, "resolvectl", arguments, nil); err != nil {
			return errors.New("resolved apply failed")
		}
	}
	return nil
}

func (participant *resolvedParticipant) Rollback(
	ctx context.Context,
	plan Plan,
) error {
	if !participant.dirty {
		return nil
	}
	if _, err := participant.runner.Run(
		ctx,
		"resolvectl",
		[]string{"revert", plan.tunnelInterface},
		nil,
	); err != nil {
		return errors.New("resolved rollback failed")
	}
	participant.dirty = false
	return nil
}

func (participant *resolvedParticipant) PendingRollback() bool {
	return participant.dirty
}

type nftablesParticipant struct {
	runner commandRunner
	dirty  bool
}

func (participant *nftablesParticipant) Subsystem() Subsystem {
	return Nftables
}

func (participant *nftablesParticipant) Checkpoint(
	ctx context.Context,
	_ Plan,
) error {
	if participant.runner == nil || participant.dirty {
		return errors.New("nftables checkpoint unavailable")
	}
	present, err := participant.tablePresent(ctx)
	if err != nil || present {
		return errors.New("nftables table ownership unavailable")
	}
	return nil
}

func (participant *nftablesParticipant) Apply(
	ctx context.Context,
	plan Plan,
) error {
	if participant.dirty {
		return errors.New("nftables transaction already active")
	}
	rules := nftRules(plan)
	if _, err := participant.runner.Run(
		ctx,
		"nft",
		[]string{"--check", "--file", "-"},
		rules,
	); err != nil {
		return errors.New("nftables validation failed")
	}
	participant.dirty = true
	if _, err := participant.runner.Run(
		ctx,
		"nft",
		[]string{"--file", "-"},
		rules,
	); err != nil {
		return errors.New("nftables apply failed")
	}
	return nil
}

func (participant *nftablesParticipant) Rollback(
	ctx context.Context,
	_ Plan,
) error {
	if !participant.dirty {
		return nil
	}
	present, err := participant.tablePresent(ctx)
	if err != nil {
		return errors.New("nftables rollback inspection failed")
	}
	if !present {
		participant.dirty = false
		return nil
	}
	rollback := []byte("delete table inet pokrov\n")
	if _, err := participant.runner.Run(
		ctx,
		"nft",
		[]string{"--check", "--file", "-"},
		rollback,
	); err != nil {
		return errors.New("nftables rollback validation failed")
	}
	if _, err := participant.runner.Run(
		ctx,
		"nft",
		[]string{"--file", "-"},
		rollback,
	); err != nil {
		return errors.New("nftables rollback failed")
	}
	participant.dirty = false
	return nil
}

func (participant *nftablesParticipant) PendingRollback() bool {
	return participant.dirty
}

func (participant *nftablesParticipant) tablePresent(ctx context.Context) (bool, error) {
	output, err := participant.runner.Run(
		ctx,
		"nft",
		[]string{"--json", "list", "tables"},
		nil,
	)
	if err != nil {
		return false, err
	}
	return containsPokrovTable(output)
}

func containsPokrovTable(output []byte) (bool, error) {
	var listing struct {
		Nftables []struct {
			Table *struct {
				Family string `json:"family"`
				Name   string `json:"name"`
			} `json:"table"`
		} `json:"nftables"`
	}
	if err := json.Unmarshal(output, &listing); err != nil || listing.Nftables == nil {
		return false, errors.New("nftables table listing invalid")
	}
	for _, entry := range listing.Nftables {
		if entry.Table != nil && entry.Table.Family == pokrovNftFamily &&
			entry.Table.Name == pokrovNftTable {
			return true, nil
		}
	}
	return false, nil
}

func nftRules(plan Plan) []byte {
	return []byte(fmt.Sprintf(`table inet pokrov {
  chain output {
    type filter hook output priority -150; policy drop;
    oifname "lo" accept
    oifname "%s" accept
    meta mark 0x%08x accept
    ip saddr 0.0.0.0 ip daddr 255.255.255.255 udp sport 68 udp dport 67 accept
    ip6 saddr fe80::/10 ip6 daddr ff02::/16 udp sport 546 udp dport 547 accept
    icmpv6 type { nd-router-solicit, nd-router-advert, nd-neighbor-solicit, nd-neighbor-advert } accept
  }
}
`, plan.tunnelInterface, plan.routingMark))
}
