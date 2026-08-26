package protocol

import (
	"encoding/json"
	"errors"
	"regexp"
)

const (
	Version             = "pokrov-linuxd-v1"
	MaximumRequestBytes = 768 * 1024
)

var (
	requestIDPattern = regexp.MustCompile(`^[A-Za-z0-9_.:-]{1,96}$`)
	actions          = map[string]struct{}{
		"status":             {},
		"initialize":         {},
		"stage_profile":      {},
		"invalidate_profile": {},
		"connect":            {},
		"disconnect":         {},
		"live_stats":         {},
	}
)

type Request struct {
	Protocol  string          `json:"protocol"`
	RequestID string          `json:"request_id"`
	Action    string          `json:"action"`
	Payload   json.RawMessage `json:"payload"`
}

func (request Request) Validate() error {
	if request.Protocol != Version {
		return errors.New("invalid protocol")
	}
	if !requestIDPattern.MatchString(request.RequestID) {
		return errors.New("invalid request id")
	}
	if _, ok := actions[request.Action]; !ok {
		return errors.New("unsupported action")
	}
	if len(request.Payload) == 0 || string(request.Payload) == "null" {
		request.Payload = json.RawMessage(`{}`)
	}
	var payload map[string]json.RawMessage
	if err := json.Unmarshal(request.Payload, &payload); err != nil {
		return errors.New("invalid payload")
	}
	return nil
}

type HostStack struct {
	Systemd        bool `json:"systemd"`
	NetworkManager bool `json:"network_manager"`
	Resolved       bool `json:"resolved"`
	Nftables       bool `json:"nftables"`
	CoreArtifact   bool `json:"core_artifact"`
}

type Snapshot struct {
	Phase               string    `json:"phase"`
	SupportsLiveConnect bool      `json:"supports_live_connect"`
	CanInitialize       bool      `json:"can_initialize"`
	CanConnect          bool      `json:"can_connect"`
	MessageCode         string    `json:"message_code"`
	HostHealth          string    `json:"host_health"`
	DNSState            string    `json:"dns_state"`
	UplinkState         string    `json:"uplink_state"`
	DNSReady            *bool     `json:"dns_ready"`
	CoreEgressValidated *bool     `json:"core_egress_validated"`
	LastFailureKind     string    `json:"last_failure_kind,omitempty"`
	LastStopReason      string    `json:"last_stop_reason,omitempty"`
	IPv4RouteCount      *int      `json:"ipv4_route_count"`
	IPv6RouteCount      *int      `json:"ipv6_route_count"`
	ConnectionPending   bool      `json:"connection_pending"`
	HostStack           HostStack `json:"host_stack"`
}

type Stats struct {
	Available bool `json:"available"`
}

type Response struct {
	Protocol    string    `json:"protocol"`
	RequestID   string    `json:"request_id"`
	OK          bool      `json:"ok"`
	ErrorCode   string    `json:"error_code,omitempty"`
	MessageCode string    `json:"message_code,omitempty"`
	Snapshot    *Snapshot `json:"snapshot,omitempty"`
	Stats       *Stats    `json:"stats,omitempty"`
}

func Success(requestID string, snapshot Snapshot) Response {
	return Response{
		Protocol:  Version,
		RequestID: requestID,
		OK:        true,
		Snapshot:  &snapshot,
	}
}

func StatsSuccess(requestID string, stats Stats) Response {
	return Response{
		Protocol:  Version,
		RequestID: requestID,
		OK:        true,
		Stats:     &stats,
	}
}

func Failure(requestID, errorCode, messageCode string) Response {
	return Response{
		Protocol:    Version,
		RequestID:   requestID,
		OK:          false,
		ErrorCode:   errorCode,
		MessageCode: messageCode,
	}
}
