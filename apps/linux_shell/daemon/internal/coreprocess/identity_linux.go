//go:build linux

package coreprocess

import (
	"bytes"
	"encoding/json"
	"errors"
	"io"
	"regexp"

	"github.com/Kiwunaka/pokrov-app/linux-daemon/internal/bootclock"
)

var ErrIdentityMismatch = errors.New("linux core identity mismatch")
var networkContextRefPattern = regexp.MustCompile(`^network_[a-f0-9]{32}$`)

// ExpectedIdentity binds a single prepared child to the caller's candidate.
// It is not a signature, server authorization or proof of working connectivity.
type ExpectedIdentity struct {
	CoreModuleSHA256 string `json:"expected_core_module_sha256"`
	ProfileSHA256 string `json:"expected_profile_sha256"`
	NetworkContextRef string `json:"expected_network_context_ref"`
	bootclock.Deadline
}

func ParseExpectedIdentity(payload []byte) (ExpectedIdentity, error) {
	var fields map[string]json.RawMessage
	if json.Unmarshal(payload, &fields) != nil || len(fields) != 6 ||
		fields["expected_core_module_sha256"] == nil || fields["expected_profile_sha256"] == nil ||
		fields["expected_network_context_ref"] == nil ||
		fields["boot_ref"] == nil || fields["started_elapsed_ms"] == nil || fields["deadline_elapsed_ms"] == nil {
		return ExpectedIdentity{}, ErrIdentityMismatch
	}
	for _, value := range fields {
		if bytes.Equal(bytes.TrimSpace(value), []byte("null")) { return ExpectedIdentity{}, ErrIdentityMismatch }
	}
	decoder := json.NewDecoder(bytes.NewReader(payload))
	decoder.DisallowUnknownFields()
	var expected ExpectedIdentity
	if decoder.Decode(&expected) != nil || !expected.valid() {
		return ExpectedIdentity{}, ErrIdentityMismatch
	}
	var extra any
	if decoder.Decode(&extra) != io.EOF { return ExpectedIdentity{}, ErrIdentityMismatch }
	return expected, nil
}

func (expected ExpectedIdentity) valid() bool {
	return boundedModuleSHA256(expected.CoreModuleSHA256) != "" &&
		boundedModuleSHA256(expected.ProfileSHA256) != "" &&
		networkContextRefPattern.MatchString(expected.NetworkContextRef) && expected.Deadline.Valid()
}

func (expected ExpectedIdentity) matches(response reply) bool {
	return response.IdentitySchema == 1 && response.DeadlineSchema == 1 &&
		response.CoreModuleSHA256 == expected.CoreModuleSHA256 &&
		response.ProfileSHA256 == expected.ProfileSHA256
}
