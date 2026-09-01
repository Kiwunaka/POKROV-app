package journal

import (
	"bytes"
	"encoding/json"
	"errors"
	"strings"
	"testing"
)

func networkEvent() Event {
	return Event{
		Name:          "network_transaction",
		Outcome:       "reject",
		CorrelationID: "linux-connect-1",
		ErrorCode:     "linux_network_apply_failed",
		Generation:    7,
		TransactionID: "network-7-1",
		Subsystem:     "resolved",
		Stage:         "apply",
	}
}

func TestNetworkTransactionUsesClosedNativeFields(t *testing.T) {
	var native []byte
	var fallback bytes.Buffer
	writer := New(&fallback)
	writer.native = func(payload []byte) error {
		native = append([]byte(nil), payload...)
		return nil
	}

	writer.Write(networkEvent())

	text := string(native)
	for _, expected := range []string{
		"POKROV_EVENT=network_transaction",
		"POKROV_OUTCOME=reject",
		"POKROV_ERROR_CODE=linux_network_apply_failed",
		"POKROV_TRANSACTION_ID=network-7-1",
		"POKROV_NETWORK_SUBSYSTEM=resolved",
		"POKROV_NETWORK_STAGE=apply",
	} {
		if !strings.Contains(text, expected+"\n") {
			t.Fatalf("native payload omitted %q: %q", expected, text)
		}
	}
	if fallback.Len() != 0 {
		t.Fatalf("successful native write also used fallback: %q", fallback.String())
	}
}

func TestNetworkTransactionFallbackContainsOnlyClosedProjection(t *testing.T) {
	var fallback bytes.Buffer
	writer := New(&fallback)
	writer.native = func([]byte) error { return errors.New("journal unavailable") }

	writer.Write(networkEvent())

	var record map[string]any
	if err := json.Unmarshal(bytes.TrimSpace(fallback.Bytes()), &record); err != nil {
		t.Fatal(err)
	}
	wantKeys := map[string]bool{
		"schema": true, "event": true, "outcome": true, "correlation_id": true,
		"generation": true, "error_code": true, "transaction_id": true,
		"network_subsystem": true, "network_stage": true,
	}
	if len(record) != len(wantKeys) {
		t.Fatalf("unexpected fallback projection: %#v", record)
	}
	for key := range record {
		if !wantKeys[key] {
			t.Fatalf("fallback exposed unexpected field %q", key)
		}
	}
}

func TestNetworkTransactionRejectsOpenOrInconsistentValues(t *testing.T) {
	tests := []Event{
		func() Event { event := networkEvent(); event.CorrelationID = "https://host/token"; return event }(),
		func() Event { event := networkEvent(); event.TransactionID = ""; return event }(),
		func() Event { event := networkEvent(); event.Subsystem = "shell"; return event }(),
		func() Event { event := networkEvent(); event.Stage = "commit"; return event }(),
		func() Event { event := networkEvent(); event.Outcome = "pass"; return event }(),
		func() Event { event := networkEvent(); event.ErrorCode = "linux_runtime_error"; return event }(),
		{
			Name: "request", Outcome: "pass", CorrelationID: "linux-1",
			TransactionID: "network-1", Subsystem: "resolved", Stage: "apply",
		},
	}

	for index, event := range tests {
		var nativeCalls int
		var fallback bytes.Buffer
		writer := New(&fallback)
		writer.native = func([]byte) error { nativeCalls++; return nil }
		writer.Write(event)
		if nativeCalls != 0 || fallback.Len() != 0 {
			t.Fatalf("invalid event %d reached a writer", index)
		}
	}
}

func authorizationEvent() Event {
	return Event{
		Name:                 "authorization",
		Outcome:              "unavailable",
		CorrelationID:        "linux-stage-1",
		ErrorCode:            "linux_authorization_agent_unavailable",
		Generation:           9,
		AuthorizationBackend: "polkit_dbus",
	}
}

func TestAuthorizationUsesClosedNativeAndFallbackFields(t *testing.T) {
	var native []byte
	var fallback bytes.Buffer
	writer := New(&fallback)
	writer.native = func(payload []byte) error {
		native = append([]byte(nil), payload...)
		return errors.New("journal unavailable")
	}

	writer.Write(authorizationEvent())

	text := string(native)
	for _, expected := range []string{
		"POKROV_EVENT=authorization",
		"POKROV_OUTCOME=unavailable",
		"POKROV_ERROR_CODE=linux_authorization_agent_unavailable",
		"POKROV_AUTHORIZATION_BACKEND=polkit_dbus",
	} {
		if !strings.Contains(text, expected+"\n") {
			t.Fatalf("native authorization payload omitted %q: %q", expected, text)
		}
	}

	var record map[string]any
	if err := json.Unmarshal(bytes.TrimSpace(fallback.Bytes()), &record); err != nil {
		t.Fatal(err)
	}
	wantKeys := map[string]bool{
		"schema": true, "event": true, "outcome": true, "correlation_id": true,
		"generation": true, "error_code": true, "authorization_backend": true,
	}
	if len(record) != len(wantKeys) {
		t.Fatalf("unexpected authorization fallback projection: %#v", record)
	}
	for key := range record {
		if !wantKeys[key] {
			t.Fatalf("authorization fallback exposed unexpected field %q", key)
		}
	}
}

func TestAuthorizationRejectsOpenOrInconsistentValues(t *testing.T) {
	tests := []Event{
		func() Event { event := authorizationEvent(); event.AuthorizationBackend = "shell"; return event }(),
		func() Event {
			event := authorizationEvent()
			event.AuthorizationBackend = "peer_credential"
			return event
		}(),
		func() Event { event := authorizationEvent(); event.Outcome = "pass"; return event }(),
		func() Event { event := authorizationEvent(); event.ErrorCode = "linux_runtime_error"; return event }(),
		func() Event { event := authorizationEvent(); event.TransactionID = "network-1"; return event }(),
		{
			Name: "request", Outcome: "denied", CorrelationID: "linux-1",
			ErrorCode: "linux_authorization_denied", AuthorizationBackend: "polkit_dbus",
		},
	}

	for index, event := range tests {
		var nativeCalls int
		var fallback bytes.Buffer
		writer := New(&fallback)
		writer.native = func([]byte) error { nativeCalls++; return nil }
		writer.Write(event)
		if nativeCalls != 0 || fallback.Len() != 0 {
			t.Fatalf("invalid authorization event %d reached a writer", index)
		}
	}
}
