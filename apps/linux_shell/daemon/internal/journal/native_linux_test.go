//go:build linux

package journal

import (
	"bytes"
	"net"
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestWriteNativeAtDeliversOneDatagram(t *testing.T) {
	directory, err := os.MkdirTemp("/tmp", "pokrov-journal-test-")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = os.RemoveAll(directory) })

	socketPath := filepath.Join(directory, "journal.sock")
	listener, err := net.ListenUnixgram(
		"unixgram",
		&net.UnixAddr{Name: socketPath, Net: "unixgram"},
	)
	if err != nil {
		t.Fatal(err)
	}
	defer listener.Close()
	if err := listener.SetReadDeadline(time.Now().Add(2 * time.Second)); err != nil {
		t.Fatal(err)
	}

	payload := []byte("MESSAGE=POKROV Linux daemon event\nPOKROV_EVENT=request\n")
	if err := writeNativeAt(socketPath, payload); err != nil {
		t.Fatal(err)
	}

	received := make([]byte, 4096)
	count, _, err := listener.ReadFromUnix(received)
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(received[:count], payload) {
		t.Fatalf("native datagram mismatch: %q", received[:count])
	}
}

func TestMissingNativeSocketUsesClosedFallback(t *testing.T) {
	directory, err := os.MkdirTemp("/tmp", "pokrov-journal-missing-")
	if err != nil {
		t.Fatal(err)
	}
	if err := os.RemoveAll(directory); err != nil {
		t.Fatal(err)
	}

	var fallback bytes.Buffer
	writer := New(&fallback)
	writer.native = func(payload []byte) error {
		return writeNativeAt(filepath.Join(directory, "missing.sock"), payload)
	}
	writer.Write(Event{
		Name:          "request",
		Outcome:       "pass",
		CorrelationID: "journal-socket-fallback",
		Generation:    43,
	})

	want := "{\"correlation_id\":\"journal-socket-fallback\",\"event\":\"request\",\"generation\":43,\"outcome\":\"pass\",\"schema\":\"pokrov-linux-operational-v1\"}\n"
	if fallback.String() != want {
		t.Fatalf("unexpected fallback record: %q", fallback.String())
	}
}

func TestLiveNativeJournaldProbe(t *testing.T) {
	if os.Getenv("POKROV_LIVE_JOURNAL_TEST") != "1" {
		t.Skip("set POKROV_LIVE_JOURNAL_TEST=1 on an owned systemd host")
	}
	payload, ok := nativePayload(Event{
		Name:          "request",
		Outcome:       "pass",
		CorrelationID: "obs043-live-probe",
		Generation:    43,
	})
	if !ok {
		t.Fatal("live probe event rejected by the closed encoder")
	}
	if err := writeNative(payload); err != nil {
		t.Fatal(err)
	}
}
