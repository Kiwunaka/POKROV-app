//go:build linux

package coreprocess

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"os"
	"os/exec"
	"strings"
	"syscall"
	"time"

	"github.com/Kiwunaka/pokrov-app/linux-daemon/internal/host"
)

// TransportInventory is preflight metadata from a short-lived Core process.
// It does not identify the executable of a later tunnel or replace its reply.
type TransportInventory struct {
	json string
	moduleSHA256 string
	artifact os.FileInfo
}

func (inventory *TransportInventory) Current() (string, string) {
	if inventory == nil { return "", "" }
	current := transportArtifact()
	if !sameTransportArtifact(inventory.artifact, current) { return "", "" }
	return inventory.json, inventory.moduleSHA256
}

func transportArtifact() os.FileInfo {
	info, err := os.Lstat(host.DefaultCorePath)
	if err != nil || !info.Mode().IsRegular() || info.Mode().Perm()&0o022 != 0 || info.Mode().Perm()&0o100 == 0 {
		return nil
	}
	stat, ok := info.Sys().(*syscall.Stat_t)
	if !ok || stat.Uid != 0 { return nil }
	return info
}

func sameTransportArtifact(before, after os.FileInfo) bool {
	return before != nil && after != nil && os.SameFile(before, after) &&
		before.Size() == after.Size() && before.ModTime().Equal(after.ModTime()) && before.Mode() == after.Mode()
}

type transportOutput struct { bytes.Buffer }

func (output *transportOutput) Write(value []byte) (int, error) {
	if output.Len()+len(value) > 8449 { return 0, errRuntime }
	return output.Buffer.Write(value)
}

// ReadTransportInventory has one fixed command, no profile/user arguments and
// no raw stdout/stderr logging. Older binaries reject the flag and stay unknown.
func ReadTransportInventory(parent context.Context) *TransportInventory {
	before := transportArtifact()
	if before == nil { return nil }
	ctx, cancel := context.WithTimeout(parent, 3*time.Second)
	defer cancel()
	command := exec.CommandContext(ctx, host.DefaultCorePath, "--transport-capabilities")
	command.Env = []string{"PATH=/usr/sbin:/usr/bin:/sbin:/bin", "HOME=/var/lib/pokrov/core"}
	command.SysProcAttr = &syscall.SysProcAttr{Pdeathsig: syscall.SIGKILL}
	command.WaitDelay = time.Second
	var output transportOutput
	command.Stdout = &output
	command.Stderr = io.Discard
	if command.Run() != nil || ctx.Err() != nil || !sameTransportArtifact(before, transportArtifact()) { return nil }
	raw := strings.TrimSuffix(output.String(), "\n")
	var metadata struct {
		Schema int `json:"schema"`
		Capabilities string `json:"transport_capabilities_json"`
		ModuleSHA256 string `json:"core_module_sha256"`
	}
	if json.Unmarshal([]byte(raw), &metadata) != nil || metadata.Schema != 1 { return nil }
	canonical, err := json.Marshal(metadata)
	if err != nil || string(canonical) != raw { return nil }
	value := boundedTransportInventory(metadata.Capabilities)
	if value == "" { return nil }
	if metadata.ModuleSHA256 != "" && boundedModuleSHA256(metadata.ModuleSHA256) == "" { return nil }
	return &TransportInventory{json: value, moduleSHA256: metadata.ModuleSHA256, artifact: before}
}

func boundedModuleSHA256(value string) string {
	if len(value) != 64 { return "" }
	for _, char := range value {
		if !(char >= '0' && char <= '9' || char >= 'a' && char <= 'f') { return "" }
	}
	return value
}

func boundedTransportInventory(value string) string {
	if len(value) == 0 || len(value) > 4096 { return "" }
	for index := range value {
		if value[index] < 32 || value[index] > 126 { return "" }
	}
	// The shared Dart boundary admits the closed canonical feature schema.
	return value
}
