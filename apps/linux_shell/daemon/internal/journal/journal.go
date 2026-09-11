package journal

import (
	"encoding/json"
	"fmt"
	"io"
	"regexp"
	"strconv"
	"strings"
	"sync"
)

const schema = "pokrov-linux-operational-v1"

var (
	identifierPattern = regexp.MustCompile(`^[A-Za-z0-9_.:-]{1,96}$`)
	events            = map[string]struct{}{
		"daemon_start": {}, "request": {}, "host_probe": {}, "profile": {},
		"connect": {}, "disconnect": {}, "recovery": {},
		"authorization": {}, "network_transaction": {},
	}
	outcomes = map[string]struct{}{
		"started": {}, "pass": {}, "reject": {}, "denied": {}, "unavailable": {},
	}
	errorCodes = map[string]struct{}{
		"": {}, "linux_authorization_denied": {}, "linux_host_unsupported": {},
		"linux_authorization_agent_unavailable": {},
		"linux_authorization_dismissed":         {},
		"linux_authorization_invalid_subject":   {},
		"linux_authorization_timeout":           {},
		"linux_authorization_unavailable":       {},
		"linux_live_connect_unavailable":        {}, "linux_profile_invalid": {},
		"linux_protocol_invalid": {}, "linux_runtime_error": {},
		"linux_network_unsupported": {}, "linux_network_checkpoint_failed": {},
		"linux_network_apply_failed": {}, "linux_network_rollback_failed": {},
	}
	networkSubsystems = map[string]struct{}{
		"network_manager": {}, "resolved": {}, "nftables": {}, "routes": {},
	}
	networkStages = map[string]struct{}{
		"checkpoint": {}, "apply": {}, "rollback": {},
	}
	authorizationBackends = map[string]struct{}{
		"peer_credential": {}, "polkit_dbus": {},
	}
)

type Event struct {
	Name                 string
	Outcome              string
	CorrelationID        string
	ErrorCode            string
	Generation           uint64
	TransactionID        string
	Subsystem            string
	Stage                string
	AuthorizationBackend string
}

type Writer struct {
	fallback io.Writer
	native   func([]byte) error
	mu       sync.Mutex
}

func New(fallback io.Writer) *Writer {
	return &Writer{fallback: fallback, native: writeNative}
}

func ValidIdentifier(value string) bool {
	return identifierPattern.MatchString(value)
}

func (writer *Writer) Write(event Event) {
	payload, ok := nativePayload(event)
	if !ok {
		return
	}
	native := writer.native
	if native != nil && native(payload) == nil {
		return
	}
	writer.writeFallback(event)
}

func nativePayload(event Event) ([]byte, bool) {
	if !validEvent(event) {
		return nil, false
	}
	fields := []string{
		"MESSAGE=POKROV Linux daemon event",
		"PRIORITY=6",
		"SYSLOG_IDENTIFIER=pokrov-linuxd",
		"POKROV_SCHEMA=" + schema,
		"POKROV_EVENT=" + event.Name,
		"POKROV_OUTCOME=" + event.Outcome,
		"POKROV_CORRELATION_ID=" + event.CorrelationID,
		"POKROV_GENERATION=" + strconv.FormatUint(event.Generation, 10),
	}
	if event.ErrorCode != "" {
		fields = append(fields, "POKROV_ERROR_CODE="+event.ErrorCode)
	}
	if event.Name == "network_transaction" {
		fields = append(fields,
			"POKROV_TRANSACTION_ID="+event.TransactionID,
			"POKROV_NETWORK_SUBSYSTEM="+event.Subsystem,
			"POKROV_NETWORK_STAGE="+event.Stage,
		)
	}
	if event.Name == "authorization" {
		fields = append(fields,
			"POKROV_AUTHORIZATION_BACKEND="+event.AuthorizationBackend,
		)
	}
	return []byte(strings.Join(fields, "\n") + "\n"), true
}

func validEvent(event Event) bool {
	if _, ok := events[event.Name]; !ok {
		return false
	}
	if _, ok := outcomes[event.Outcome]; !ok {
		return false
	}
	if _, ok := errorCodes[event.ErrorCode]; !ok {
		return false
	}
	if !ValidIdentifier(event.CorrelationID) {
		return false
	}
	switch event.Name {
	case "network_transaction":
		if event.AuthorizationBackend != "" || !ValidIdentifier(event.TransactionID) {
			return false
		}
		if _, ok := networkSubsystems[event.Subsystem]; !ok {
			return false
		}
		if _, ok := networkStages[event.Stage]; !ok {
			return false
		}
		return validNetworkResult(event)
	case "authorization":
		if event.TransactionID != "" || event.Subsystem != "" || event.Stage != "" {
			return false
		}
		if _, ok := authorizationBackends[event.AuthorizationBackend]; !ok {
			return false
		}
		return validAuthorizationResult(event)
	default:
		return event.TransactionID == "" && event.Subsystem == "" &&
			event.Stage == "" && event.AuthorizationBackend == ""
	}
}

func validAuthorizationResult(event Event) bool {
	if event.AuthorizationBackend == "peer_credential" {
		return (event.Outcome == "pass" && event.ErrorCode == "") ||
			(event.Outcome == "reject" &&
				event.ErrorCode == "linux_authorization_invalid_subject")
	}
	if event.AuthorizationBackend != "polkit_dbus" {
		return false
	}
	switch event.Outcome {
	case "pass":
		return event.ErrorCode == ""
	case "denied":
		return event.ErrorCode == "linux_authorization_denied" ||
			event.ErrorCode == "linux_authorization_dismissed"
	case "unavailable":
		return event.ErrorCode == "linux_authorization_agent_unavailable" ||
			event.ErrorCode == "linux_authorization_timeout" ||
			event.ErrorCode == "linux_authorization_unavailable"
	default:
		return false
	}
}

func validNetworkResult(event Event) bool {
	switch event.Outcome {
	case "pass":
		return event.ErrorCode == ""
	case "unavailable":
		return event.ErrorCode == "linux_network_unsupported"
	case "reject":
		expected := map[string]string{
			"checkpoint": "linux_network_checkpoint_failed",
			"apply":      "linux_network_apply_failed",
			"rollback":   "linux_network_rollback_failed",
		}[event.Stage]
		return event.ErrorCode == expected
	default:
		return false
	}
}

func (writer *Writer) writeFallback(event Event) {
	if writer.fallback == nil {
		return
	}
	record := map[string]any{
		"schema":         schema,
		"event":          event.Name,
		"outcome":        event.Outcome,
		"correlation_id": event.CorrelationID,
		"generation":     event.Generation,
	}
	if event.ErrorCode != "" {
		record["error_code"] = event.ErrorCode
	}
	if event.Name == "network_transaction" {
		record["transaction_id"] = event.TransactionID
		record["network_subsystem"] = event.Subsystem
		record["network_stage"] = event.Stage
	}
	if event.Name == "authorization" {
		record["authorization_backend"] = event.AuthorizationBackend
	}
	encoded, err := json.Marshal(record)
	if err != nil || len(encoded) > 1024 {
		return
	}
	writer.mu.Lock()
	defer writer.mu.Unlock()
	_, _ = fmt.Fprintln(writer.fallback, string(encoded))
}
