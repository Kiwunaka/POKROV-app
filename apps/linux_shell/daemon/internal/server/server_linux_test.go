//go:build linux

package server

import "testing"

func TestDecodeRequestRejectsUnknownAndTrailingData(t *testing.T) {
	valid := []byte("{\"protocol\":\"pokrov-linuxd-v1\",\"request_id\":\"linux-1\",\"action\":\"status\",\"payload\":{}}\n")
	request, err := decodeRequest(valid)
	if err != nil || request.Action != "status" {
		t.Fatalf("valid request rejected: %#v %v", request, err)
	}

	invalid := [][]byte{
		[]byte("{\"protocol\":\"pokrov-linuxd-v1\",\"request_id\":\"linux-1\",\"action\":\"status\",\"payload\":{},\"extra\":true}\n"),
		[]byte("{\"protocol\":\"pokrov-linuxd-v1\",\"request_id\":\"linux-1\",\"action\":\"status\",\"payload\":{}} {}\n"),
		[]byte("{\"protocol\":\"future\",\"request_id\":\"linux-1\",\"action\":\"status\",\"payload\":{}}\n"),
	}
	for index, candidate := range invalid {
		if _, err := decodeRequest(candidate); err == nil {
			t.Fatalf("invalid request %d was accepted", index)
		}
	}
}
