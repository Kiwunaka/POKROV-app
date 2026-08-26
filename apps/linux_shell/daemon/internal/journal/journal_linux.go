//go:build linux

package journal

import (
	"encoding/json"
	"fmt"
	"io"
	"net"
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
	}
	outcomes = map[string]struct{}{
		"started": {}, "pass": {}, "reject": {}, "denied": {}, "unavailable": {},
	}
	errors = map[string]struct{}{
		"": {}, "linux_authorization_denied": {}, "linux_host_unsupported": {},
		"linux_live_connect_unavailable": {}, "linux_profile_invalid": {},
		"linux_protocol_invalid": {}, "linux_runtime_error": {},
	}
)

type Event struct {
	Name          string
	Outcome       string
	CorrelationID string
	ErrorCode     string
	Generation    uint64
}

type Writer struct {
	fallback io.Writer
	mu       sync.Mutex
}

func New(fallback io.Writer) *Writer {
	return &Writer{fallback: fallback}
}

func (writer *Writer) Write(event Event) {
	if _, ok := events[event.Name]; !ok {
		return
	}
	if _, ok := outcomes[event.Outcome]; !ok {
		return
	}
	if _, ok := errors[event.ErrorCode]; !ok {
		return
	}
	if !identifierPattern.MatchString(event.CorrelationID) {
		return
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
	payload := []byte(strings.Join(fields, "\n") + "\n")
	if writeNative(payload) == nil {
		return
	}
	writer.writeFallback(event)
}

func writeNative(payload []byte) error {
	address := &net.UnixAddr{Name: "/run/systemd/journal/socket", Net: "unixgram"}
	connection, err := net.DialUnix("unixgram", nil, address)
	if err != nil {
		return err
	}
	defer connection.Close()
	_ = connection.SetWriteBuffer(16 * 1024)
	_, err = connection.Write(payload)
	return err
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
	encoded, err := json.Marshal(record)
	if err != nil || len(encoded) > 1024 {
		return
	}
	writer.mu.Lock()
	defer writer.mu.Unlock()
	_, _ = fmt.Fprintln(writer.fallback, string(encoded))
}
