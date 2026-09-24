//go:build linux

package service

import (
	"context"
	"encoding/json"
	"errors"
	"net"
	"sync"
	"time"

	"github.com/Kiwunaka/pokrov-app/linux-daemon/internal/auth"
	"github.com/Kiwunaka/pokrov-app/linux-daemon/internal/bootclock"
	"github.com/Kiwunaka/pokrov-app/linux-daemon/internal/coreprocess"
	"github.com/Kiwunaka/pokrov-app/linux-daemon/internal/host"
	"github.com/Kiwunaka/pokrov-app/linux-daemon/internal/journal"
	"github.com/Kiwunaka/pokrov-app/linux-daemon/internal/networktxn"
	"github.com/Kiwunaka/pokrov-app/linux-daemon/internal/profile"
	"github.com/Kiwunaka/pokrov-app/linux-daemon/internal/protocol"
)

type eventSink interface {
	Write(journal.Event)
}

type Service struct {
	mu               sync.Mutex
	probe            host.Probe
	profiles         *profile.Store
	authorizer       auth.Checker
	events           eventSink
	phase            string
	generation       uint64
	lastStop         string
	lastFailure      string
	core             *coreprocess.Session
	transaction      *networktxn.Transaction
	closed           bool
	recoveryRequired bool
	health           *coreprocess.Health
	transportInventory *coreprocess.TransportInventory
	stagedProfileDigest string
	boundStageCurrent bool
	boundConnectRequestID string
	boundConnectPeer auth.Peer
	transportPromoted bool
	transportLeaseRef string
	connectMu sync.Mutex
	boundConnectCall *boundConnectCall
	networkContext networkContextObserver
}

func New(
	probe host.Probe,
	profiles *profile.Store,
	authorizer auth.Checker,
	events eventSink,
) *Service {
	phase := "artifact_missing"
	if profiles.Exists() {
		phase = "config_staged"
	}
	service := &Service{
		probe:      probe,
		profiles:   profiles,
		authorizer: authorizer,
		events:     events,
		phase:      phase,
	}
	service.networkContext.onChange = service.cancelBoundNetwork
	return service
}

func (service *Service) Handle(ctx context.Context, peer auth.Peer, request protocol.Request) protocol.Response {
	switch request.Action {
	case "cancel_connect":
		return service.cancelConnect(ctx, peer, request)
	case "promote_transport_lease":
		return service.promoteTransportLease(ctx, peer, request)
	case "revoke_transport_lease":
		return service.revokeTransportLease(ctx, peer, request)
	case "clock_snapshot":
		return clockSnapshot(request)
	case "read_network_context":
		ref, err := service.networkContext.Read(ctx)
		if err != nil { return protocol.Failure(request.RequestID, "linux_network_context_unavailable", "network_context_unavailable") }
		return protocol.Response{Protocol: protocol.Version, RequestID: request.RequestID, OK: true,
			NetworkContext: &protocol.NetworkContext{Schema: 1, Ref: ref}}
	case "status":
		service.mu.Lock()
		defer service.mu.Unlock()
		if service.core != nil && service.core.Exited() {
			service.settleExitedCore(request.RequestID)
		}
		return protocol.Success(request.RequestID, service.snapshot(service.probe.Run()))
	case "initialize":
		service.mu.Lock()
		defer service.mu.Unlock()
		result := service.probe.Run()
		if result.HostReady() {
			if service.core == nil && service.transaction == nil && !service.recoveryRequired {
				service.transportInventory = coreprocess.ReadTransportInventory(ctx)
			}
			if service.phase == "artifact_missing" || service.phase == "artifact_ready" {
				service.phase = "initialized"
			}
			service.event("host_probe", "pass", request.RequestID, "")
		} else {
			service.phase = "artifact_missing"
			service.event("host_probe", "reject", request.RequestID, "linux_host_unsupported")
		}
		return protocol.Success(request.RequestID, service.snapshot(result))
	case "live_stats":
		return protocol.StatsSuccess(request.RequestID, protocol.Stats{Available: false})
	}

	var expected *coreprocess.ExpectedIdentity
	if request.Action == "connect_with_identity" {
		identity, err := coreprocess.ParseExpectedIdentity(request.Payload)
		if err != nil { return protocol.Failure(request.RequestID, "linux_protocol_invalid", "runtime_error") }
		expected = &identity
		var cancel context.CancelFunc
		ctx, cancel = identity.Deadline.Context(ctx)
		defer cancel()
		var finish func()
		var unowned bool
		ctx, finish, unowned = service.beginBoundConnect(ctx, peer, request.RequestID, identity.NetworkContextRef)
		if finish == nil {
			response := protocol.Failure(request.RequestID, "linux_runtime_busy", "runtime_busy")
			response.ConnectCancellation = &protocol.ConnectCancellation{Schema: 1, ConnectRequestID: request.RequestID, Settled: unowned}
			return response
		}
		defer finish()
		if !service.networkContext.Matches(ctx, identity.NetworkContextRef) {
			if ctx.Err() != nil { return cancelledConnectResponse(ctx, request.RequestID) }
			return protocol.Failure(request.RequestID, "linux_network_context_changed", "network_context_changed")
		}
	}
	if request.IsConnect() && ctx.Err() != nil {
		return cancelledConnectResponse(ctx, request.RequestID)
	}
	authorization := auth.Authorize(ctx, peer, service.authorizer)
	if !authorization.Authorized() {
		if request.IsConnect() && ctx.Err() != nil { return cancelledConnectResponse(ctx, request.RequestID) }
		service.mu.Lock()
		service.authorizationEvent(request.RequestID, authorization)
		service.event("request", "denied", request.RequestID, "linux_authorization_denied")
		service.mu.Unlock()
		return protocol.Failure(
			request.RequestID,
			"linux_authorization_denied",
			"authorization_denied",
		)
	}

	service.mu.Lock()
	defer service.mu.Unlock()
	service.authorizationEvent(request.RequestID, authorization)
	if service.closed {
		return service.runtimeFailure(request.RequestID)
	}
	if request.IsConnect() && ctx.Err() != nil {
		return cancelledConnectResponse(ctx, request.RequestID)
	}

	switch request.Action {
	case "stage_profile", "stage_bound_profile":
		return service.stageProfile(request)
	case "invalidate_profile":
		if service.transaction != nil || service.recoveryRequired {
			return protocol.Failure(request.RequestID, "linux_runtime_busy", "runtime_busy")
		}
		if err := service.profiles.Invalidate(); err != nil {
			service.event("profile", "reject", request.RequestID, "linux_runtime_error")
			return protocol.Failure(request.RequestID, "linux_runtime_error", "runtime_error")
		}
		service.phase = "initialized"
		service.stagedProfileDigest = ""
		service.boundStageCurrent = false
		service.event("profile", "pass", request.RequestID, "")
		return protocol.Success(request.RequestID, service.snapshot(service.probe.Run()))
	case "connect", "connect_with_identity":
		return service.connect(ctx, peer, request, expected)
	case "disconnect":
		if err := service.stop(request.RequestID); err != nil {
			return service.runtimeFailure(request.RequestID)
		}
		service.lastStop = "requested"
		if service.profiles.Exists() {
			service.phase = "config_staged"
		} else {
			service.phase = "initialized"
		}
		service.event("disconnect", "pass", request.RequestID, "")
		snapshot := service.snapshot(service.probe.Run())
		snapshot.MessageCode = "stopped"
		return protocol.Success(request.RequestID, snapshot)
	default:
		return protocol.Failure(request.RequestID, "linux_protocol_invalid", "runtime_error")
	}
}

func cancelledConnectResponse(ctx context.Context, requestID string) protocol.Response {
	if errors.Is(context.Cause(ctx), bootclock.ErrDeadline) {
		return protocol.Failure(requestID, "connect_deadline", "connect_deadline")
	}
	return protocol.Failure(requestID, "linux_operation_cancelled", "operation_cancelled")
}

func (service *Service) connect(requestContext context.Context, peer auth.Peer, request protocol.Request, expected *coreprocess.ExpectedIdentity) protocol.Response {
	result := service.probe.RunContext(requestContext)
	if requestContext.Err() != nil {
		return cancelledConnectResponse(requestContext, request.RequestID)
	}
	if !result.HostReady() {
		return protocol.Failure(request.RequestID, "linux_host_unsupported", "host_unsupported")
	}
	if expected != nil && !service.networkContext.Matches(requestContext, expected.NetworkContextRef) {
		if requestContext.Err() != nil { return cancelledConnectResponse(requestContext, request.RequestID) }
		return protocol.Failure(request.RequestID, "linux_network_context_changed", "network_context_changed")
	}
	if expected == nil && service.profiles.BoundOnly() {
		return protocol.Failure(request.RequestID, "core_identity_mismatch", "core_identity_mismatch")
	}
	if expected != nil && (!service.boundStageCurrent || !service.profiles.BoundOnly() ||
		service.stagedProfileDigest != expected.ProfileSHA256) {
		return protocol.Failure(request.RequestID, "core_identity_mismatch", "core_identity_mismatch")
	}
	if expected != nil && (service.transaction != nil || service.recoveryRequired) {
		// Reject without changing the prior owner's health or restoring its
		// network state as a side effect of this candidate's admission.
		return protocol.Failure(request.RequestID, "linux_runtime_busy", "runtime_busy")
	}
	if service.recoveryRequired && service.recoverPending() != nil {
		return service.runtimeFailure(request.RequestID)
	}
	if service.transaction != nil {
		if service.phase == "running" && service.lastFailure == "" {
			return protocol.Success(request.RequestID, service.snapshot(result))
		}
		return service.runtimeFailure(request.RequestID)
	}
	if !service.profiles.Exists() {
		return protocol.Failure(request.RequestID, "linux_profile_invalid", "profile_invalid")
	}
	recorder, err := networktxn.New(service.events, request.RequestID, request.RequestID, service.generation)
	if err != nil {
		return service.runtimeFailure(request.RequestID)
	}
	transaction, err := networktxn.NewSystemTransaction(recorder)
	if err != nil {
		return service.runtimeFailure(request.RequestID)
	}
	ctx, cancel := context.WithTimeout(requestContext, 30*time.Second)
	defer cancel()
	var core *coreprocess.Session
	var plan networktxn.Plan
	if expected == nil {
		core, plan, err = coreprocess.Prepare(ctx)
	} else {
		core, plan, err = coreprocess.PrepareWithIdentity(ctx, *expected)
	}
	if err != nil {
		if requestContext.Err() != nil {
			return cancelledConnectResponse(requestContext, request.RequestID)
		}
		if errors.Is(err, bootclock.ErrDeadline) {
			return protocol.Failure(request.RequestID, "connect_deadline", "connect_deadline")
		}
		if errors.Is(err, coreprocess.ErrIdentityMismatch) {
			return protocol.Failure(request.RequestID, "core_identity_mismatch", "core_identity_mismatch")
		}
		return service.runtimeFailure(request.RequestID)
	}
	if expected != nil && !service.networkContext.Matches(requestContext, expected.NetworkContextRef) {
		core.AbortPrepared()
		if requestContext.Err() != nil { return cancelledConnectResponse(requestContext, request.RequestID) }
		return protocol.Failure(request.RequestID, "linux_network_context_changed", "network_context_changed")
	}
	service.core = core
	service.transaction = transaction
	if expected != nil {
		service.boundConnectRequestID = request.RequestID
		service.boundConnectPeer = peer
		service.transportPromoted = false
	}
	if err := transaction.Execute(ctx, plan, core); err != nil {
		// Execute already attempted restoration with a fresh timeout. Keep its
		// dirty owners for explicit disconnect/shutdown retry.
		service.phase = "config_staged"
		service.lastFailure = "linux_runtime_error"
		var failure *networktxn.Failure
		if errors.As(err, &failure) && !failure.RollbackFailed {
			service.transaction = nil
			service.core = nil
			service.releaseBoundConnect()
			if requestContext.Err() != nil {
				service.lastFailure = ""
				service.lastStop = "requested"
				return cancelledConnectResponse(requestContext, request.RequestID)
			}
			if core.ConnectDeadlineExpired() {
				service.lastFailure = "connect_deadline"
				return protocol.Failure(request.RequestID, "connect_deadline", "connect_deadline")
			}
		}
		return service.runtimeFailure(request.RequestID)
	}
	service.phase = "running"
	service.lastFailure = ""
	// Bound ATS requests use their own reserved proof ladder. The legacy Core
	// health probe performs network IO outside that diagnostic budget.
	health := coreprocess.Health{}
	if expected == nil {
		probeContext, cancelProbe := context.WithTimeout(requestContext, 20*time.Second)
		observed, probeErr := core.Probe(probeContext)
		cancelProbe()
		if probeErr == nil { health = observed }
	}
	networkChanged := expected != nil && requestContext.Err() == nil &&
		!service.networkContext.Matches(requestContext, expected.NetworkContextRef)
	if requestContext.Err() != nil || (expected != nil && !expected.Deadline.Current()) || networkChanged {
		// Cancellation must not interrupt restoration. stop owns a fresh
		// cleanup deadline and retains dirty state on restoration failure.
		if err := service.stop(request.RequestID); err != nil {
			return service.runtimeFailure(request.RequestID)
		}
		service.lastStop = "requested"
		if networkChanged {
			service.lastFailure = "linux_network_context_changed"
			return protocol.Failure(request.RequestID, "linux_network_context_changed", "network_context_changed")
		}
		if requestContext.Err() == nil {
			return protocol.Failure(request.RequestID, "connect_deadline", "connect_deadline")
		}
		return cancelledConnectResponse(requestContext, request.RequestID)
	}
	service.health = &health
	go service.watchCore(core)
	service.event("connect", "pass", request.RequestID, "")
	return protocol.Success(request.RequestID, service.snapshot(result))
}

func (service *Service) stop(correlationID string) error {
	if service.transaction == nil {
		if service.recoveryRequired {
			return service.recoverPending()
		}
		return nil
	}
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	if err := service.transaction.Restore(ctx); err != nil {
		if service.core != nil && service.core.Exited() {
			if recovered := service.recoverPending(); recovered == nil && service.transaction == nil {
				return nil
			}
		}
		service.lastFailure = "linux_runtime_error"
		service.event("disconnect", "reject", correlationID, "linux_runtime_error")
		return err
	}
	service.transaction = nil
	service.core = nil
	service.releaseBoundConnect()
	service.lastFailure = ""
	service.phase = "config_staged"
	return nil
}

func (service *Service) Close() error {
	service.mu.Lock()
	defer service.mu.Unlock()
	service.closed = true
	service.networkContext.Close()
	return service.stop("systemd-stop")
}

func (service *Service) runtimeFailure(requestID string) protocol.Response {
	service.lastFailure = "linux_runtime_error"
	service.event("request", "reject", requestID, "linux_runtime_error")
	return protocol.Failure(requestID, "linux_runtime_error", "runtime_error")
}

func (service *Service) stageProfile(request protocol.Request) protocol.Response {
	if service.transaction != nil || service.recoveryRequired {
		return protocol.Failure(request.RequestID, "linux_runtime_busy", "runtime_busy")
	}
	result := service.probe.Run()
	if !result.HostReady() {
		service.event("profile", "reject", request.RequestID, "linux_host_unsupported")
		return protocol.Failure(request.RequestID, "linux_host_unsupported", "host_unsupported")
	}
	var stage profile.StageRequest
	if err := json.Unmarshal(request.Payload, &stage); err != nil {
		service.event("profile", "reject", request.RequestID, "linux_profile_invalid")
		return protocol.Failure(request.RequestID, "linux_profile_invalid", "profile_invalid")
	}
	var staged profile.Staged
	var err error
	if request.Action == "stage_bound_profile" {
		staged, err = service.profiles.StageBound(stage)
	} else {
		staged, err = service.profiles.Stage(stage)
	}
	if err != nil {
		// Storage may have replaced the profile before returning an error.
		service.boundStageCurrent = false
		service.event("profile", "reject", request.RequestID, "linux_profile_invalid")
		return protocol.Failure(request.RequestID, "linux_profile_invalid", "profile_invalid")
	}
	service.generation = staged.Generation
	service.stagedProfileDigest = staged.Digest
	service.boundStageCurrent = request.Action == "stage_bound_profile"
	service.phase = "config_staged"
	service.lastFailure = ""
	service.event("profile", "pass", request.RequestID, "")
	snapshot := service.snapshot(result)
	snapshot.MessageCode = "profile_staged"
	return protocol.Success(request.RequestID, snapshot)
}

func (service *Service) snapshot(result host.Result) protocol.Snapshot {
	phase := service.phase
	message := "ready"
	lastFailure := service.lastFailure
	if !result.HostReady() {
		phase = "artifact_missing"
		message = "host_unsupported"
		lastFailure = "linux_host_unsupported"
	} else if phase == "artifact_missing" {
		phase = "artifact_ready"
	}
	health := "healthy"
	if !result.HostReady() || service.lastFailure != "" {
		health = "degraded"
	}
	snapshot := protocol.Snapshot{
		Phase:               phase,
		SupportsLiveConnect: result.HostReady(),
		CanInitialize:       result.InMatrix,
		CanConnect:          result.HostReady() && service.profiles.Exists() && !service.profiles.BoundOnly() && service.transaction == nil && !service.recoveryRequired,
		MessageCode:         message,
		HostHealth:          health,
		DNSState:            "unknown",
		UplinkState:         "unknown",
		DNSReady:            nil,
		CoreEgressValidated: nil,
		LastFailureKind:     lastFailure,
		LastStopReason:      service.lastStop,
		IPv4RouteCount:      nil,
		IPv6RouteCount:      nil,
		ConnectionPending:   service.recoveryRequired || (service.transaction != nil && phase != "running"),
		TransportProofPending: service.boundConnectRequestID != "" && !service.transportPromoted,
		TransportLeaseActive: service.boundConnectRequestID != "" && service.transportPromoted,
		HostStack:           result.Stack,
		StagedProfileDigest: service.stagedProfileDigest,
	}
	if result.HostReady() {
		if service.core != nil {
			snapshot.TransportCapabilities = service.core.TransportCapabilities()
			snapshot.CoreModuleSHA256 = service.core.CoreModuleSHA256()
			snapshot.EffectiveProfileDigest = service.core.ProfileSHA256()
		} else if phase != "running" && service.transaction == nil && !service.recoveryRequired {
			snapshot.TransportCapabilities, snapshot.CoreModuleSHA256 = service.transportInventory.Current()
		}
	}
	if phase == "running" && service.health != nil && service.lastFailure == "" {
		snapshot.DNSReady = &service.health.DNSReady
		snapshot.CoreEgressValidated = &service.health.EgressValidated
		snapshot.DNSState = "degraded"
		snapshot.UplinkState = "degraded"
		if service.health.DNSReady {
			snapshot.DNSState = "healthy"
		}
		if service.health.EgressValidated {
			snapshot.UplinkState = "healthy"
		}
		if service.health.DNSReady && service.health.EgressValidated {
			snapshot.MessageCode = "connected"
		}
	}
	return snapshot
}

// Recover runs before IPC begins. A child from the previous daemon receives
// Pdeathsig, but may still own pokrov0 for a brief interval. Wait only for that
// exact condition; every other recovery failure remains visible and retryable.
func (service *Service) Recover() error {
	service.mu.Lock()
	defer service.mu.Unlock()
	err := service.recoverPending()
	if !errors.Is(err, networktxn.ErrLiveTunnel) { return err }
	timer := time.NewTimer(5 * time.Second)
	defer timer.Stop()
	ticker := time.NewTicker(100 * time.Millisecond)
	defer ticker.Stop()
	for {
		select {
		case <-timer.C:
			return err
		case <-ticker.C:
			links, readErr := net.Interfaces()
			if readErr != nil { return err }
			live := false
			for _, link := range links {
				if link.Name == "pokrov0" { live = true; break }
			}
			if !live { return service.recoverPending() }
		}
	}
}

func (service *Service) recoverPending() error {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	found, err := networktxn.RecoverSystem(ctx, service.events)
	if err != nil {
		service.recoveryRequired = true
		service.lastFailure = "linux_runtime_error"
		service.phase = "config_staged"
		service.event("recovery", "reject", "daemon-recovery", "linux_runtime_error")
		return err
	}
	service.recoveryRequired = false
	if found {
		service.transaction = nil
		service.core = nil
		service.releaseBoundConnect()
		service.lastFailure = ""
		service.lastStop = "runtime_error"
		service.phase = "initialized"
		if service.profiles.Exists() {
			service.phase = "config_staged"
		}
		service.event("recovery", "pass", "daemon-recovery", "")
	}
	return nil
}

func (service *Service) watchCore(core *coreprocess.Session) {
	<-core.Done()
	service.mu.Lock()
	defer service.mu.Unlock()
	if service.closed || service.core != core {
		return
	}
	service.settleExitedCore("core-exit")
}

// Caller holds mu and has identified the current child, not an older watcher.
func (service *Service) settleExitedCore(requestID string) {
	expired := service.core.ConnectDeadlineExpired()
	if service.stop(requestID) != nil { return }
	service.lastStop = "runtime_error"
	service.lastFailure = "linux_runtime_error"
	if expired {
		service.lastStop = "requested"
		service.lastFailure = "connect_deadline"
	}
}

func (service *Service) event(name, outcome, correlationID, errorCode string) {
	if service.events == nil {
		return
	}
	service.events.Write(journal.Event{
		Name:          name,
		Outcome:       outcome,
		CorrelationID: correlationID,
		ErrorCode:     errorCode,
		Generation:    service.generation,
	})
}

func (service *Service) authorizationEvent(correlationID string, result auth.Result) {
	if service.events == nil {
		return
	}
	outcome := "unavailable"
	errorCode := "linux_authorization_unavailable"
	switch result.Decision {
	case auth.DecisionAuthorized:
		outcome = "pass"
		errorCode = ""
	case auth.DecisionDenied:
		outcome = "denied"
		errorCode = "linux_authorization_denied"
	case auth.DecisionAgentUnavailable:
		errorCode = "linux_authorization_agent_unavailable"
	case auth.DecisionDismissed:
		outcome = "denied"
		errorCode = "linux_authorization_dismissed"
	case auth.DecisionTimeout:
		errorCode = "linux_authorization_timeout"
	case auth.DecisionInvalidSubject:
		outcome = "reject"
		errorCode = "linux_authorization_invalid_subject"
	}
	service.events.Write(journal.Event{
		Name:                 "authorization",
		Outcome:              outcome,
		CorrelationID:        correlationID,
		ErrorCode:            errorCode,
		Generation:           service.generation,
		AuthorizationBackend: string(result.Backend),
	})
}
