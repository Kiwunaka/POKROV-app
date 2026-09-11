//go:build linux

package service

import (
	"context"
	"encoding/json"
	"errors"
	"sync"
	"time"

	"github.com/Kiwunaka/pokrov-app/linux-daemon/internal/auth"
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
	return &Service{
		probe:      probe,
		profiles:   profiles,
		authorizer: authorizer,
		events:     events,
		phase:      phase,
	}
}

func (service *Service) Handle(peer auth.Peer, request protocol.Request) protocol.Response {
	switch request.Action {
	case "status":
		service.mu.Lock()
		defer service.mu.Unlock()
		if service.core != nil && service.core.Exited() {
			_ = service.stop(request.RequestID)
			service.lastStop = "runtime_error"
			service.lastFailure = "linux_runtime_error"
		}
		return protocol.Success(request.RequestID, service.snapshot(service.probe.Run()))
	case "initialize":
		service.mu.Lock()
		defer service.mu.Unlock()
		result := service.probe.Run()
		if result.HostReady() {
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

	authorization := auth.Authorize(peer, service.authorizer)
	if !authorization.Authorized() {
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

	switch request.Action {
	case "stage_profile":
		return service.stageProfile(request)
	case "invalidate_profile":
		if service.transaction != nil || service.recoveryRequired {
			return service.runtimeFailure(request.RequestID)
		}
		if err := service.profiles.Invalidate(); err != nil {
			service.event("profile", "reject", request.RequestID, "linux_runtime_error")
			return protocol.Failure(request.RequestID, "linux_runtime_error", "runtime_error")
		}
		service.phase = "initialized"
		service.event("profile", "pass", request.RequestID, "")
		return protocol.Success(request.RequestID, service.snapshot(service.probe.Run()))
	case "connect":
		return service.connect(request)
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

func (service *Service) connect(request protocol.Request) protocol.Response {
	result := service.probe.Run()
	if !result.HostReady() {
		return protocol.Failure(request.RequestID, "linux_host_unsupported", "host_unsupported")
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
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	core, plan, err := coreprocess.Prepare(ctx)
	if err != nil {
		return service.runtimeFailure(request.RequestID)
	}
	service.core = core
	service.transaction = transaction
	if err := transaction.Execute(ctx, plan, core); err != nil {
		// Execute already attempted restoration with a fresh timeout. Keep its
		// dirty owners for explicit disconnect/shutdown retry.
		service.phase = "config_staged"
		service.lastFailure = "linux_runtime_error"
		var failure *networktxn.Failure
		if errors.As(err, &failure) && !failure.RollbackFailed {
			service.transaction = nil
			service.core = nil
		}
		return service.runtimeFailure(request.RequestID)
	}
	service.phase = "running"
	service.lastFailure = ""
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
	service.lastFailure = ""
	service.phase = "config_staged"
	return nil
}

func (service *Service) Close() error {
	service.mu.Lock()
	defer service.mu.Unlock()
	service.closed = true
	return service.stop("systemd-stop")
}

func (service *Service) runtimeFailure(requestID string) protocol.Response {
	service.lastFailure = "linux_runtime_error"
	service.event("request", "reject", requestID, "linux_runtime_error")
	return protocol.Failure(requestID, "linux_runtime_error", "runtime_error")
}

func (service *Service) stageProfile(request protocol.Request) protocol.Response {
	if service.transaction != nil || service.recoveryRequired {
		return service.runtimeFailure(request.RequestID)
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
	staged, err := service.profiles.Stage(stage)
	if err != nil {
		service.event("profile", "reject", request.RequestID, "linux_profile_invalid")
		return protocol.Failure(request.RequestID, "linux_profile_invalid", "profile_invalid")
	}
	service.generation = staged.Generation
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
	return protocol.Snapshot{
		Phase:               phase,
		SupportsLiveConnect: result.HostReady(),
		CanInitialize:       result.InMatrix,
		CanConnect:          result.HostReady() && service.profiles.Exists() && service.transaction == nil && !service.recoveryRequired,
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
		ConnectionPending:   false,
		HostStack:           result.Stack,
	}
}

// Recover runs before IPC begins; failures remain visible and retryable through
// an authorized disconnect/connect instead of discarding the durable record.
func (service *Service) Recover() error {
	service.mu.Lock()
	defer service.mu.Unlock()
	return service.recoverPending()
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
	_ = service.stop("core-exit")
	service.lastStop = "runtime_error"
	service.lastFailure = "linux_runtime_error"
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
