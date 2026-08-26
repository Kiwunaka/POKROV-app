//go:build linux

package host

import (
	"os"
	"path/filepath"
	"runtime"
	"testing"
)

type fixedCommands struct {
	active    map[string]bool
	available map[string]bool
}

func (commands fixedCommands) Active(unit string) bool {
	return commands.active[unit]
}

func (commands fixedCommands) Available(command string) bool {
	return commands.available[command]
}

func TestProbeRequiresExactFoundationMatrixAndHostStack(t *testing.T) {
	osRelease := filepath.Join(t.TempDir(), "os-release")
	if err := os.WriteFile(osRelease, []byte("ID=ubuntu\nVERSION_ID=\"24.04\"\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	probe := Probe{
		Commands: fixedCommands{
			active: map[string]bool{
				"systemd-journald.service": true,
				"NetworkManager.service":   true,
				"systemd-resolved.service": true,
			},
			available: map[string]bool{
				"nmcli":      true,
				"resolvectl": true,
				"nft":        true,
			},
		},
		CorePath:  "/bin/true",
		OSRelease: osRelease,
	}

	result := probe.Run()
	wantMatrix := runtime.GOARCH == "amd64"
	if result.InMatrix != wantMatrix {
		t.Fatalf("unexpected matrix result for %s: %#v", runtime.GOARCH, result)
	}
	if result.HostReady() != wantMatrix {
		t.Fatalf("unexpected host readiness for %s: %#v", runtime.GOARCH, result)
	}

	result.Stack.Resolved = false
	if result.HostReady() {
		t.Fatal("host remained ready without systemd-resolved")
	}
}

func TestProbeRejectsSymlinkedCoreArtifact(t *testing.T) {
	corePath := filepath.Join(t.TempDir(), "pokrov-core")
	if err := os.Symlink("/bin/true", corePath); err != nil {
		t.Fatal(err)
	}
	if secureRootArtifact(corePath) {
		t.Fatal("symlinked Core artifact was accepted")
	}
}

func TestEmbeddedMatrixIsVersionedAndNonEmpty(t *testing.T) {
	matrix, err := EmbeddedMatrix()
	if err != nil {
		t.Fatal(err)
	}
	if len(matrix) == 0 {
		t.Fatal("embedded support matrix is empty")
	}
}
