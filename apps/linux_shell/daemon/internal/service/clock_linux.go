//go:build linux

package service

import (
	"encoding/json"

	"github.com/Kiwunaka/pokrov-app/linux-daemon/internal/bootclock"
	"github.com/Kiwunaka/pokrov-app/linux-daemon/internal/protocol"
)

// CLOCK_BOOTTIME includes suspend. Wall-clock/mtime never identifies this boot.
func clockSnapshot(request protocol.Request) protocol.Response {
	var payload map[string]json.RawMessage
	if json.Unmarshal(request.Payload, &payload) != nil || len(payload) != 0 {
		return protocol.Failure(request.RequestID, "runtime_clock_invalid_request", "runtime_clock_invalid_request")
	}
	now, err := bootclock.Read()
	if err != nil {
		return protocol.Failure(request.RequestID, "runtime_clock_unavailable", "runtime_clock_unavailable")
	}
	return protocol.Response{Protocol: protocol.Version, RequestID: request.RequestID, OK: true,
		Clock: now}
}
