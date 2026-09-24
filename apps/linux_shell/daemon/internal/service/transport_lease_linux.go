//go:build linux

package service

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"regexp"
	"time"

	"github.com/Kiwunaka/pokrov-app/linux-daemon/internal/auth"
	"github.com/Kiwunaka/pokrov-app/linux-daemon/internal/coreprocess"
	"github.com/Kiwunaka/pokrov-app/linux-daemon/internal/protocol"
)

var transportLeaseRefPattern = regexp.MustCompile(`^lease_[a-f0-9]{32}$`)
var transportConnectRefPattern = regexp.MustCompile(`^[a-f0-9]{32}$`)
var transportProfileDigestPattern = regexp.MustCompile(`^[a-f0-9]{64}$`)

type transportLeasePromotion struct {
	ConnectRequestID string `json:"connect_request_id"`
	ProfileDigest string `json:"profile_digest"`
	EndpointLeaseRef string `json:"endpoint_lease_ref"`
	IssuedAt string `json:"issued_at"`
	NewFlowsUntil string `json:"new_flows_until"`
	ActiveFlowsUntil string `json:"active_flows_until"`
}

func (service *Service) promoteTransportLease(ctx context.Context, peer auth.Peer,
	request protocol.Request) protocol.Response {
	var fields map[string]json.RawMessage
	if json.Unmarshal(request.Payload, &fields) != nil || len(fields) != 6 {
		return protocol.Failure(request.RequestID, "linux_protocol_invalid", "runtime_error")
	}
	decoder := json.NewDecoder(bytes.NewReader(request.Payload))
	decoder.DisallowUnknownFields()
	var target transportLeasePromotion
	var extra any
	if decoder.Decode(&target) != nil || decoder.Decode(&extra) != io.EOF ||
		!transportConnectRefPattern.MatchString(target.ConnectRequestID) ||
		!transportProfileDigestPattern.MatchString(target.ProfileDigest) ||
		!transportLeaseRefPattern.MatchString(target.EndpointLeaseRef) {
		return protocol.Failure(request.RequestID, "linux_protocol_invalid", "runtime_error")
	}
	service.mu.Lock()
	defer service.mu.Unlock()
	service.connectMu.Lock()
	call := service.boundConnectCall
	owned := call != nil && !call.stopped && !call.peerLost && call.requestID == target.ConnectRequestID && call.peer == peer
	networkRef := ""
	if owned { networkRef = call.networkRef }
	service.connectMu.Unlock()
	core := service.core
	if !owned || service.closed || service.phase != "running" || service.transportPromoted ||
		service.transportLeaseRef != "" ||
		service.boundConnectRequestID != target.ConnectRequestID || service.boundConnectPeer != peer ||
		service.stagedProfileDigest != target.ProfileDigest || core == nil || core.Exited() ||
		core.ProfileSHA256() != target.ProfileDigest ||
		!peer.Alive() || !service.networkContext.Matches(ctx, networkRef) {
		return protocol.Failure(request.RequestID, "linux_transport_lease_unavailable", "runtime_error")
	}
	bound, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	if core.PromoteATSLease(bound, target.ProfileDigest, target.EndpointLeaseRef,
		target.IssuedAt, target.NewFlowsUntil, target.ActiveFlowsUntil) != nil {
		// The child may have accepted promotion before its ACK was lost. Restore
		// this exact transaction before any later request can reuse the runtime.
		_ = service.stop(request.RequestID)
		return protocol.Failure(request.RequestID, "linux_transport_lease_unavailable", "runtime_error")
	}
	service.connectMu.Lock()
	peerLost := call.peerLost || call.stopped
	service.connectMu.Unlock()
	if peerLost || !peer.Alive() || core.Exited() || !service.networkContext.Matches(ctx, networkRef) {
		_ = service.stop(request.RequestID)
		return protocol.Failure(request.RequestID, "linux_transport_lease_unavailable", "runtime_error")
	}
	service.transportPromoted = true
	service.transportLeaseRef = target.EndpointLeaseRef
	service.health = &coreprocess.Health{DNSReady: true, EgressValidated: true}
	response := protocol.Success(request.RequestID, service.snapshot(service.probe.Run()))
	response.TransportLeaseHandoff = &protocol.TransportLeaseHandoff{Schema: 1,
		ConnectRequestID: target.ConnectRequestID, EndpointLeaseRef: target.EndpointLeaseRef}
	return response
}

type transportLeaseRevocation struct {
	ConnectRequestID string `json:"connect_request_id"`
	ProfileDigest string `json:"profile_digest"`
	EndpointLeaseRef string `json:"endpoint_lease_ref"`
	TerminateActive *bool `json:"terminate_active"`
}

func (service *Service) revokeTransportLease(ctx context.Context, peer auth.Peer,
	request protocol.Request) protocol.Response {
	var fields map[string]json.RawMessage
	if json.Unmarshal(request.Payload, &fields) != nil || len(fields) != 4 {
		return protocol.Failure(request.RequestID, "linux_protocol_invalid", "runtime_error")
	}
	decoder := json.NewDecoder(bytes.NewReader(request.Payload))
	decoder.DisallowUnknownFields()
	var target transportLeaseRevocation
	var extra any
	if decoder.Decode(&target) != nil || decoder.Decode(&extra) != io.EOF ||
		!transportConnectRefPattern.MatchString(target.ConnectRequestID) ||
		!transportProfileDigestPattern.MatchString(target.ProfileDigest) ||
		!transportLeaseRefPattern.MatchString(target.EndpointLeaseRef) || target.TerminateActive == nil {
		return protocol.Failure(request.RequestID, "linux_protocol_invalid", "runtime_error")
	}
	service.mu.Lock()
	defer service.mu.Unlock()
	service.connectMu.Lock()
	call := service.boundConnectCall
	owned := call != nil && !call.stopped && call.requestID == target.ConnectRequestID && call.peer == peer
	service.connectMu.Unlock()
	core := service.core
	if !owned || service.closed || service.phase != "running" || !service.transportPromoted ||
		service.boundConnectRequestID != target.ConnectRequestID || service.boundConnectPeer != peer ||
		service.stagedProfileDigest != target.ProfileDigest ||
		service.transportLeaseRef != target.EndpointLeaseRef || core == nil || core.Exited() ||
		core.ProfileSHA256() != target.ProfileDigest {
		return protocol.Failure(request.RequestID, "linux_transport_lease_unavailable", "runtime_error")
	}
	bound, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	service.health = &coreprocess.Health{}
	if core.RevokeATSLease(bound, target.ProfileDigest, target.EndpointLeaseRef,
		*target.TerminateActive) != nil || core.Exited() {
		// A lost ACK may hide an accepted revocation. Restore the exact runtime.
		_ = service.stop(request.RequestID)
		return protocol.Failure(request.RequestID, "linux_transport_lease_unavailable", "runtime_error")
	}
	if *target.TerminateActive {
		// The rejecting Core target remains installed until stop, but the
		// terminated lease cannot still be projected as active protection.
		service.transportPromoted = false
	}
	response := protocol.Success(request.RequestID, service.snapshot(service.probe.Run()))
	response.TransportLeaseRevocation = &protocol.TransportLeaseRevocation{Schema: 1,
		ConnectRequestID: target.ConnectRequestID, EndpointLeaseRef: target.EndpointLeaseRef,
		TerminateActive: *target.TerminateActive}
	return response
}
