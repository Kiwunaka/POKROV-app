package profile

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"regexp"
)

const MaximumConfigBytes = 512 * 1024

var profileNamePattern = regexp.MustCompile(`^[A-Za-z0-9_.-]{1,80}$`)

type StageRequest struct {
	ProfileName             string `json:"profile_name"`
	ConfigPayload           string `json:"config_payload"`
	RouteMode               string `json:"route_mode"`
	CoreEgressProbeRequired bool   `json:"core_egress_probe_required"`
	ResolvedNodeCode        string `json:"resolved_node_code"`
}

type Staged struct {
	Digest     string
	Generation uint64
}

type Store struct {
	root       string
	generation uint64
}

func (store *Store) Exists() bool {
	info, err := os.Lstat(filepath.Join(store.root, "active-profile.json"))
	return err == nil && info.Mode().IsRegular() && info.Mode()&os.ModeSymlink == 0 &&
		info.Mode().Perm()&0o077 == 0
}

func NewStore(root string) *Store {
	return &Store{root: root}
}

func (store *Store) Stage(request StageRequest) (Staged, error) {
	config := []byte(request.ConfigPayload)
	if !profileNamePattern.MatchString(request.ProfileName) ||
		len(config) == 0 || len(config) > MaximumConfigBytes {
		return Staged{}, errors.New("invalid profile bounds")
	}
	if request.RouteMode != "fullTunnel" && request.RouteMode != "allExceptRu" {
		return Staged{}, errors.New("unsupported route mode")
	}
	if err := validateConfig(config); err != nil {
		return Staged{}, err
	}
	if err := ensurePrivateDirectory(store.root); err != nil {
		return Staged{}, err
	}

	finalPath := filepath.Join(store.root, "active-profile.json")
	temporary, err := os.CreateTemp(store.root, ".active-profile-*.tmp")
	if err != nil {
		return Staged{}, fmt.Errorf("create staged profile: %w", err)
	}
	temporaryPath := temporary.Name()
	committed := false
	defer func() {
		_ = temporary.Close()
		if !committed {
			_ = os.Remove(temporaryPath)
		}
	}()
	if err := temporary.Chmod(0o600); err != nil {
		return Staged{}, fmt.Errorf("chmod staged profile: %w", err)
	}
	if _, err := temporary.Write(config); err != nil {
		return Staged{}, fmt.Errorf("write staged profile: %w", err)
	}
	if err := temporary.Sync(); err != nil {
		return Staged{}, fmt.Errorf("sync staged profile: %w", err)
	}
	if err := temporary.Close(); err != nil {
		return Staged{}, fmt.Errorf("close staged profile: %w", err)
	}
	if err := os.Rename(temporaryPath, finalPath); err != nil {
		return Staged{}, fmt.Errorf("promote staged profile: %w", err)
	}
	committed = true
	store.generation++
	digest := sha256.Sum256(config)
	return Staged{
		Digest:     hex.EncodeToString(digest[:]),
		Generation: store.generation,
	}, nil
}

func (store *Store) Invalidate() error {
	path := filepath.Join(store.root, "active-profile.json")
	info, err := os.Lstat(path)
	if errors.Is(err, os.ErrNotExist) {
		return nil
	}
	if err != nil {
		return fmt.Errorf("inspect staged profile: %w", err)
	}
	if !info.Mode().IsRegular() || info.Mode()&os.ModeSymlink != 0 {
		return errors.New("staged profile is not a regular file")
	}
	if err := os.Remove(path); err != nil {
		return fmt.Errorf("remove staged profile: %w", err)
	}
	return nil
}

func validateConfig(config []byte) error {
	decoder := json.NewDecoder(bytes.NewReader(config))
	decoder.UseNumber()
	var root map[string]json.RawMessage
	if err := decoder.Decode(&root); err != nil {
		return errors.New("profile is not valid JSON")
	}
	var trailing any
	if err := decoder.Decode(&trailing); !errors.Is(err, io.EOF) {
		return errors.New("profile contains trailing JSON")
	}
	for _, required := range []string{"dns", "inbounds", "outbounds", "route"} {
		if len(root[required]) == 0 {
			return fmt.Errorf("profile missing %s", required)
		}
	}
	if rawLog := root["log"]; len(rawLog) > 0 {
		var logConfig map[string]json.RawMessage
		if err := json.Unmarshal(rawLog, &logConfig); err != nil {
			return errors.New("profile log section is invalid")
		}
		if output := logConfig["output"]; len(output) > 0 && string(output) != `""` {
			return errors.New("profile-controlled log output is forbidden")
		}
	}
	return nil
}

func ensurePrivateDirectory(path string) error {
	info, err := os.Lstat(path)
	if errors.Is(err, os.ErrNotExist) {
		if err := os.MkdirAll(path, 0o700); err != nil {
			return fmt.Errorf("create profile root: %w", err)
		}
		return nil
	}
	if err != nil {
		return fmt.Errorf("inspect profile root: %w", err)
	}
	if !info.IsDir() || info.Mode()&os.ModeSymlink != 0 {
		return errors.New("profile root is not a private directory")
	}
	if err := os.Chmod(path, 0o700); err != nil {
		return fmt.Errorf("secure profile root: %w", err)
	}
	return nil
}
