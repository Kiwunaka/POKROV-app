package profile

import (
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"testing"
)

const validConfig = `{"log":{"level":"info"},"dns":{},"inbounds":[],"outbounds":[],"route":{}}`

func TestStageUsesPrivateAtomicFileAndDigest(t *testing.T) {
	root := filepath.Join(t.TempDir(), "profiles")
	store := NewStore(root)
	staged, err := store.Stage(StageRequest{
		ProfileName:             "pokrov-test",
		ConfigPayload:           validConfig,
		RouteMode:               "fullTunnel",
		CoreEgressProbeRequired: true,
	})
	if err != nil {
		t.Fatal(err)
	}
	if staged.Generation != 1 || len(staged.Digest) != 64 {
		t.Fatalf("unexpected staged result: %#v", staged)
	}
	if runtime.GOOS != "windows" && !store.Exists() {
		t.Fatal("private staged profile was not detected")
	}
	path := filepath.Join(root, "active-profile.json")
	info, err := os.Lstat(path)
	if err != nil {
		t.Fatal(err)
	}
	if runtime.GOOS != "windows" && info.Mode().Perm()&0o077 != 0 {
		t.Fatalf("profile permissions are not private: %o", info.Mode().Perm())
	}
	content, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	if string(content) != validConfig {
		t.Fatal("staged profile bytes changed")
	}
	if err := store.Invalidate(); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Lstat(path); !os.IsNotExist(err) {
		t.Fatal("profile still exists after exact invalidation")
	}
}

func TestStageRejectsUnsafeProfiles(t *testing.T) {
	store := NewStore(filepath.Join(t.TempDir(), "profiles"))
	tests := []StageRequest{
		{ProfileName: "../unsafe", ConfigPayload: validConfig, RouteMode: "fullTunnel"},
		{ProfileName: "pokrov", ConfigPayload: `{}`, RouteMode: "fullTunnel"},
		{ProfileName: "pokrov", ConfigPayload: validConfig, RouteMode: "selectedApps"},
		{
			ProfileName:   "pokrov",
			ConfigPayload: `{"log":{"output":"/tmp/raw.log"},"dns":{},"inbounds":[],"outbounds":[],"route":{}}`,
			RouteMode:     "fullTunnel",
		},
		{ProfileName: "pokrov", ConfigPayload: strings.Repeat("x", MaximumConfigBytes+1), RouteMode: "fullTunnel"},
	}
	for index, request := range tests {
		if _, err := store.Stage(request); err == nil {
			t.Fatalf("unsafe profile %d was accepted", index)
		}
	}
}
