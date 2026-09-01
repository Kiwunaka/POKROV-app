//go:build linux

package host

import (
	"context"
	_ "embed"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"runtime"
	"strings"
	"syscall"
	"time"

	"github.com/Kiwunaka/pokrov-app/linux-daemon/internal/protocol"
)

const DefaultCorePath = "/usr/lib/pokrov/pokrov-core"

//go:embed support-matrix.v1.json
var supportMatrixBytes []byte

type matrix struct {
	Schema  string        `json:"schema"`
	Entries []matrixEntry `json:"entries"`
}

type matrixEntry struct {
	DistroID     string `json:"distro_id"`
	VersionID    string `json:"version_id"`
	Architecture string `json:"architecture"`
	Status       string `json:"status"`
}

type CommandRunner interface {
	Active(unit string) bool
	Available(command string) bool
}

type systemCommands struct{}

func (systemCommands) Active(unit string) bool {
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	command := exec.CommandContext(ctx, "systemctl", "is-active", "--quiet", unit)
	return command.Run() == nil
}

func (systemCommands) Available(command string) bool {
	_, err := exec.LookPath(command)
	return err == nil
}

type Probe struct {
	Commands  CommandRunner
	CorePath  string
	OSRelease string
}

type Result struct {
	Stack     protocol.HostStack
	InMatrix  bool
	DistroID  string
	VersionID string
	Arch      string
}

func (probe Probe) Run() Result {
	commands := probe.Commands
	if commands == nil {
		commands = systemCommands{}
	}
	corePath := probe.CorePath
	if corePath == "" {
		corePath = DefaultCorePath
	}
	osReleasePath := probe.OSRelease
	if osReleasePath == "" {
		osReleasePath = "/etc/os-release"
	}
	distroID, versionID := readOSRelease(osReleasePath)
	arch := runtime.GOARCH
	stack := protocol.HostStack{
		Systemd:        commands.Active("systemd-journald.service"),
		NetworkManager: commands.Active("NetworkManager.service") && commands.Available("busctl"),
		Resolved:       commands.Active("systemd-resolved.service") && commands.Available("resolvectl"),
		Nftables:       commands.Available("nft"),
		CoreArtifact:   secureRootArtifact(corePath),
	}
	return Result{
		Stack:     stack,
		InMatrix:  matrixAllows(distroID, versionID, arch),
		DistroID:  distroID,
		VersionID: versionID,
		Arch:      arch,
	}
}

func (result Result) HostReady() bool {
	return result.InMatrix && result.Stack.Systemd && result.Stack.NetworkManager &&
		result.Stack.Resolved && result.Stack.Nftables && result.Stack.CoreArtifact
}

func matrixAllows(distroID, versionID, arch string) bool {
	var parsed matrix
	if err := json.Unmarshal(supportMatrixBytes, &parsed); err != nil ||
		parsed.Schema != "pokrov-linux-support-matrix-v1" {
		return false
	}
	for _, entry := range parsed.Entries {
		if entry.Status == "foundation_supported" &&
			entry.DistroID == distroID && entry.VersionID == versionID &&
			entry.Architecture == arch {
			return true
		}
	}
	return false
}

func readOSRelease(path string) (string, string) {
	content, err := os.ReadFile(path)
	if err != nil || len(content) > 64*1024 {
		return "", ""
	}
	values := map[string]string{}
	for _, line := range strings.Split(string(content), "\n") {
		key, value, ok := strings.Cut(line, "=")
		if !ok || (key != "ID" && key != "VERSION_ID") {
			continue
		}
		values[key] = strings.Trim(strings.TrimSpace(value), `"'`)
	}
	return strings.ToLower(values["ID"]), strings.ToLower(values["VERSION_ID"])
}

func secureRootArtifact(path string) bool {
	info, err := os.Lstat(path)
	if err != nil || !info.Mode().IsRegular() || info.Mode()&os.ModeSymlink != 0 ||
		info.Mode().Perm()&0o022 != 0 {
		return false
	}
	stat, ok := info.Sys().(*syscall.Stat_t)
	return ok && stat.Uid == 0
}

func EmbeddedMatrix() ([]byte, error) {
	var parsed matrix
	if err := json.Unmarshal(supportMatrixBytes, &parsed); err != nil {
		return nil, fmt.Errorf("decode embedded support matrix: %w", err)
	}
	if parsed.Schema != "pokrov-linux-support-matrix-v1" || len(parsed.Entries) == 0 {
		return nil, errors.New("invalid embedded support matrix")
	}
	return append([]byte(nil), supportMatrixBytes...), nil
}
