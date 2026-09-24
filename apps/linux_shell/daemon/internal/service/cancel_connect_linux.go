//go:build linux

package service

import (
	"context"
	"encoding/json"
	"time"

	"github.com/Kiwunaka/pokrov-app/linux-daemon/internal/auth"
	"github.com/Kiwunaka/pokrov-app/linux-daemon/internal/journal"
	"github.com/Kiwunaka/pokrov-app/linux-daemon/internal/protocol"
)

// One retained invocation covers authorization, startup and its runtime owner.
// connectMu is separate from mu so cancellation can reach a blocked start.
// When both are needed, acquire mu before connectMu.
type boundConnectCall struct {
	requestID string
	peer auth.Peer
	networkRef string
	cancel context.CancelFunc
	done chan struct{}
	stopped bool
	peerLost bool
}

func (service *Service) cancelBoundNetwork() {
	service.connectMu.Lock()
	defer service.connectMu.Unlock()
	if call := service.boundConnectCall; call != nil && !call.stopped { call.cancel() }
}

func (service *Service) beginBoundConnect(ctx context.Context, peer auth.Peer, requestID, networkRef string) (context.Context, func(), bool) {
	service.connectMu.Lock()
	defer service.connectMu.Unlock()
	if previous := service.boundConnectCall; previous != nil {
		if previous.requestID == requestID || !previous.stopped { return ctx, nil, previous.requestID != requestID }
		select {
		case <-previous.done:
		default:
			return ctx, nil, true
		}
	}
	ctx, cancel := context.WithCancel(ctx)
	call := &boundConnectCall{requestID: requestID, peer: peer, networkRef: networkRef, cancel: cancel, done: make(chan struct{})}
	service.boundConnectCall = call
	go service.watchBoundPeer(call)
	return ctx, func() {
		cancel()
		// Handle's runtime lock has been released before this deferred finish.
		// No later authorization callback or startup work belongs to this call.
		service.mu.Lock()
		defer service.mu.Unlock()
		service.connectMu.Lock()
		defer service.connectMu.Unlock()
		call.stopped = service.boundConnectRequestID != requestID
		close(call.done)
	}, false
}

// A dead UI cancels an unpromoted ATS attempt. Once Core has accepted the lease,
// network changes still stop the runtime, but the UI process no longer owns it.
// The kernel peer PID plus /proc start time rejects PID reuse.
func (service *Service) watchBoundPeer(call *boundConnectCall) {
	ticker := time.NewTicker(250 * time.Millisecond)
	defer ticker.Stop()
	var networkCheckedAt time.Time
	for range ticker.C {
		service.connectMu.Lock()
		current := service.boundConnectCall == call && !call.stopped
		service.connectMu.Unlock()
		if !current { return }
		peerAlive := call.peer.Alive()
		if !peerAlive {
			service.connectMu.Lock()
			if service.boundConnectCall != call || call.stopped {
				service.connectMu.Unlock()
				return
			}
			call.peerLost = true
			service.connectMu.Unlock()
		}
		networkChanged := false
		if time.Since(networkCheckedAt) >= time.Second {
			networkCheckedAt = time.Now()
			networkChanged = !service.networkContext.Matches(context.Background(), call.networkRef)
		}
		if peerAlive && !networkChanged { continue }
		service.mu.Lock()
		service.connectMu.Lock()
		current = service.boundConnectCall == call && !call.stopped
		promoted := service.transportPromoted && service.boundConnectRequestID == call.requestID && service.boundConnectPeer == call.peer
		if !current || (promoted && !networkChanged) {
			service.connectMu.Unlock()
			service.mu.Unlock()
			if !current { return }
			continue
		}
		call.cancel()
		service.connectMu.Unlock()
		service.mu.Unlock()
		// Startup or authorization releases the invocation before cleanup takes
		// the runtime lock. Restoration keeps its own independent timeout.
		<-call.done
		service.mu.Lock()
		if service.boundConnectRequestID == call.requestID && service.boundConnectPeer == call.peer {
			if err := service.stop("client-exit"); err == nil {
				service.lastStop = "runtime_error"
				service.lastFailure = "linux_runtime_error"
				if networkChanged { service.lastFailure = "linux_network_context_changed" }
			}
		}
		service.mu.Unlock()
		return
	}
}

// Caller holds mu and has completed restoration of the current bound owner.
func (service *Service) releaseBoundConnect() {
	service.connectMu.Lock()
	defer service.connectMu.Unlock()
	if call := service.boundConnectCall; call != nil && call.requestID == service.boundConnectRequestID {
		call.stopped = true
	}
	service.boundConnectRequestID = ""
	service.boundConnectPeer = auth.Peer{}
	service.transportPromoted = false
	service.transportLeaseRef = ""
}

func connectCancellationResponse(requestID, connectRequestID string, settled bool) protocol.Response {
	return protocol.Response{
		Protocol: protocol.Version, RequestID: requestID, OK: true,
		ConnectCancellation: &protocol.ConnectCancellation{Schema: 1, ConnectRequestID: connectRequestID, Settled: settled},
	}
}

// Only the same kernel-identified process may cancel its exact bound request.
// Unknown calls (including a request not admitted yet or a restarted daemon)
// never produce a stopped receipt from an idle global snapshot.
func (service *Service) cancelConnect(ctx context.Context, peer auth.Peer, request protocol.Request) protocol.Response {
	var payload map[string]string
	if json.Unmarshal(request.Payload, &payload) != nil || len(payload) != 1 ||
		!journal.ValidIdentifier(payload["connect_request_id"]) {
		return protocol.Failure(request.RequestID, "linux_protocol_invalid", "runtime_error")
	}
	requestID := payload["connect_request_id"]
	service.connectMu.Lock()
	call := service.boundConnectCall
	if call == nil || call.requestID != requestID {
		service.connectMu.Unlock()
		return connectCancellationResponse(request.RequestID, requestID, false)
	}
	if call.peer != peer {
		service.connectMu.Unlock()
		return protocol.Failure(request.RequestID, "linux_authorization_denied", "authorization_denied")
	}
	call.cancel()
	service.connectMu.Unlock()
	// Waiting is bounded; a timeout retains the owner and permits an exact retry.
	waitContext, cancel := context.WithTimeout(ctx, 35*time.Second)
	defer cancel()
	select {
	case <-call.done:
	case <-waitContext.Done():
		return connectCancellationResponse(request.RequestID, requestID, false)
	}
	service.mu.Lock()
	defer service.mu.Unlock()
	if service.boundConnectRequestID == requestID && service.boundConnectPeer == peer {
		if err := service.stop(request.RequestID); err != nil { return service.runtimeFailure(request.RequestID) }
		service.lastStop = "requested"
	}
	service.connectMu.Lock()
	settled := call.stopped
	service.connectMu.Unlock()
	return connectCancellationResponse(request.RequestID, requestID, settled)
}
