//go:build linux

package coreprocess

import (
	"bufio"
	"context"
	"fmt"
	"os"
	"os/exec"
	"os/signal"
	"strings"
	"syscall"
	"testing"
	"time"
)

func TestCoreChildFixture(t *testing.T) {
	mode := os.Getenv("POKROV_CORE_CHILD_TEST")
	if mode == "" {
		return
	}
	control := os.NewFile(3, "test-control")
	stopping := make(chan os.Signal, 1)
	signal.Notify(stopping, syscall.SIGTERM)
	if mode == "unknown-field" {
		fmt.Fprintln(control, "{\"protocol\":\""+protocol+"\",\"phase\":\"prepared\",\"config_payload\":\"synthetic-private-canary\"}")
	} else {
		fmt.Fprintln(control, "{\"protocol\":\""+protocol+"\",\"phase\":\"prepared\"}")
		reader := bufio.NewReader(os.Stdin)
		_, _ = reader.ReadString('\n')
		fmt.Fprintln(control, "{\"protocol\":\""+protocol+"\",\"phase\":\"started\"}")
	}
	<-stopping
	if mode != "missing-stop-ack" {
		fmt.Fprintln(control, "{\"protocol\":\""+protocol+"\",\"phase\":\"stopped\"}")
	}
	os.Exit(0)
}

func child(t *testing.T, mode string) (*Session, context.Context) {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	t.Cleanup(cancel)
	command := exec.Command(os.Args[0], "-test.run=^TestCoreChildFixture$")
	command.Env = append(os.Environ(), "POKROV_CORE_CHILD_TEST="+mode)
	session, err := prepareCommand(ctx, command)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(session.abort)
	return session, ctx
}

func TestChildStartStopWaitsForExplicitCleanupAcknowledgement(t *testing.T) {
	session, ctx := child(t, "normal")
	if response, err := session.read(ctx); err != nil || response.Phase != "prepared" {
		t.Fatal("prepare reply missing")
	}
	if err := session.Start(ctx); err != nil {
		t.Fatal(err)
	}
	if err := session.Stop(ctx); err != nil {
		t.Fatal(err)
	}
	if !session.Exited() {
		t.Fatal("stop returned while child remained alive")
	}
}

func TestChildRejectsUnknownFieldsWithoutExportingTheirValues(t *testing.T) {
	session, ctx := child(t, "unknown-field")
	_, err := session.read(ctx)
	if err == nil || strings.Contains(err.Error(), "canary") {
		t.Fatal("unbounded child reply accepted or exposed")
	}
}

func TestChildExitAloneDoesNotProveNetworkCleanup(t *testing.T) {
	session, ctx := child(t, "missing-stop-ack")
	if _, err := session.read(ctx); err != nil {
		t.Fatal(err)
	}
	if err := session.Start(ctx); err != nil {
		t.Fatal(err)
	}
	if err := session.Stop(ctx); err == nil {
		t.Fatal("exit without stop acknowledgement was accepted")
	}
}
