//go:build linux

package main

import (
	"errors"
	"fmt"
	"net"
	"os"
	"os/signal"
	"strconv"
	"syscall"

	"github.com/Kiwunaka/pokrov-app/linux-daemon/internal/host"
	"github.com/Kiwunaka/pokrov-app/linux-daemon/internal/journal"
	"github.com/Kiwunaka/pokrov-app/linux-daemon/internal/profile"
	"github.com/Kiwunaka/pokrov-app/linux-daemon/internal/server"
	"github.com/Kiwunaka/pokrov-app/linux-daemon/internal/service"
)

const profileRoot = "/var/lib/pokrov/profiles"

func main() {
	if os.Geteuid() != 0 {
		fmt.Fprintln(os.Stderr, "pokrov-linuxd requires the system service identity")
		os.Exit(1)
	}
	listener, err := activationListener()
	if err != nil {
		fmt.Fprintln(os.Stderr, "pokrov-linuxd socket activation unavailable")
		os.Exit(1)
	}
	defer listener.Close()

	events := journal.New(os.Stdout)
	daemon := service.New(
		host.Probe{},
		profile.NewStore(profileRoot),
		nil,
		events,
	)
	events.Write(journal.Event{
		Name:          "daemon_start",
		Outcome:       "started",
		CorrelationID: "systemd-activation",
	})
	_ = daemon.Recover()

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGINT, syscall.SIGTERM)
	go func() {
		<-stop
		_ = listener.Close()
	}()
	serveErr := server.New(daemon).Serve(listener)
	closeErr := daemon.Close()
	if serveErr != nil || closeErr != nil {
		fmt.Fprintln(os.Stderr, "pokrov-linuxd stopped with a bounded server error")
		os.Exit(1)
	}
}

func activationListener() (*net.UnixListener, error) {
	listenPID, err := strconv.Atoi(os.Getenv("LISTEN_PID"))
	if err != nil || listenPID != os.Getpid() || os.Getenv("LISTEN_FDS") != "1" {
		return nil, errors.New("exactly one systemd socket is required")
	}
	file := os.NewFile(uintptr(3), "pokrov-linuxd.socket")
	if file == nil {
		return nil, errors.New("systemd listener is unavailable")
	}
	defer file.Close()
	listener, err := net.FileListener(file)
	if err != nil {
		return nil, err
	}
	unixListener, ok := listener.(*net.UnixListener)
	if !ok {
		_ = listener.Close()
		return nil, errors.New("systemd listener is not a Unix socket")
	}
	// systemd owns the socket path across daemon stop and reactivation.
	unixListener.SetUnlinkOnClose(false)
	return unixListener, nil
}
