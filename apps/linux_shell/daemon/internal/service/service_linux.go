//go:build linux

package service

import (
	"encoding/json"
	"sync"

	"github.com/Kiwunaka/pokrov-app/linux-daemon/internal/auth"
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
	mu         sync.Mutex
	probe      host.Probe
	profiles   *profile.Store
	authorizer auth.Checker
	events     eventSink
	phase      string
	generation uint64
	lastStop   string
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

	switch request.Action {
	case "stage_profile":
		return service.stageProfile(request)
	case "invalidate_profile":
		if err := service.profiles.Invalidate(); err != nil {
			service.event("profile", "reject", request.RequestID, "linux_runtime_error")
			return protocol.Failure(request.RequestID, "linux_runtime_error", "runtime_error")
		}
		service.phase = "initialized"
		service.event("profile", "pass", request.RequestID, "")
		return protocol.Success(request.RequestID, service.snapshot(service.probe.Run()))
	case "connect":
		service.recordUnavailableNetworkTransaction(request.RequestID)
		service.event("connect", "unavailable", request.RequestID, "linux_live_connect_unavailable")
		return protocol.Failure(
			request.RequestID,
			"linux_live_connect_unavailable",
			"live_connect_unavailable",
		)
	case "disconnect":
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

func (service *Service) recordUnavailableNetworkTransaction(correlationID string) {
	if service.events == nil {
		return
	}
	recorder, err := networktxn.New(
		service.events,
		correlationID,
		correlationID,
		service.generation,
	)
	if err != nil {
		return
	}
	for _, subsystem := range []networktxn.Subsystem{
		networktxn.NetworkManager,
		networktxn.Resolved,
		networktxn.Nftables,
	} {
		_ = recorder.Checkpoint(subsystem, networktxn.Unsupported)
	}
}

func (service *Service) stageProfile(request protocol.Request) protocol.Response {
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
	service.event("profile", "pass", request.RequestID, "")
	snapshot := service.snapshot(result)
	snapshot.MessageCode = "profile_staged"
	return protocol.Success(request.RequestID, snapshot)
}

func (service *Service) snapshot(result host.Result) protocol.Snapshot {
	phase := service.phase
	message := "ready"
	lastFailure := ""
	if !result.HostReady() {
		phase = "artifact_missing"
		message = "host_unsupported"
		lastFailure = "linux_host_unsupported"
	} else if phase == "artifact_missing" {
		phase = "artifact_ready"
	}
	health := "healthy"
	if !result.HostReady() {
		health = "degraded"
	}
	return protocol.Snapshot{
		Phase:               phase,
		SupportsLiveConnect: false,
		CanInitialize:       result.InMatrix,
		CanConnect:          false,
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
