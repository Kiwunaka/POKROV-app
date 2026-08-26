package protocol

import (
	"encoding/json"
	"testing"
)

func TestRequestValidation(t *testing.T) {
	valid := Request{
		Protocol:  Version,
		RequestID: "linux-123-1",
		Action:    "status",
		Payload:   json.RawMessage(`{}`),
	}
	if err := valid.Validate(); err != nil {
		t.Fatalf("valid request rejected: %v", err)
	}

	tests := []Request{
		{Protocol: "future", RequestID: "linux-123-1", Action: "status", Payload: json.RawMessage(`{}`)},
		{Protocol: Version, RequestID: "../unsafe", Action: "status", Payload: json.RawMessage(`{}`)},
		{Protocol: Version, RequestID: "linux-123-1", Action: "shell", Payload: json.RawMessage(`{}`)},
		{Protocol: Version, RequestID: "linux-123-1", Action: "status", Payload: json.RawMessage(`[]`)},
	}
	for index, request := range tests {
		if err := request.Validate(); err == nil {
			t.Fatalf("invalid request %d was accepted", index)
		}
	}
}

func TestFailureReturnsOnlyClosedEnvelope(t *testing.T) {
	response := Failure("linux-123-1", "linux_protocol_invalid", "runtime_error")
	encoded, err := json.Marshal(response)
	if err != nil {
		t.Fatal(err)
	}
	var decoded map[string]any
	if err := json.Unmarshal(encoded, &decoded); err != nil {
		t.Fatal(err)
	}
	for _, forbidden := range []string{"profile", "host", "path", "detail"} {
		if _, exists := decoded[forbidden]; exists {
			t.Fatalf("failure response leaked forbidden field %q", forbidden)
		}
	}
}
