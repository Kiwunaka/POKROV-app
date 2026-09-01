//go:build linux

package networktxn

import (
	"context"
	"testing"
)

func TestSystemCommandRunnerRejectsCommandsOutsideClosedSet(t *testing.T) {
	if _, err := (systemCommandRunner{}).Run(
		context.Background(),
		"sh",
		[]string{"-c", "true"},
		nil,
	); err == nil {
		t.Fatal("open command reached the system runner")
	}
}

func TestBoundedOutputConsumesWriteButRetainsOnlyLimit(t *testing.T) {
	output := &boundedOutput{limit: 4}
	written, err := output.Write([]byte("abcdef"))
	if err != nil || written != 6 {
		t.Fatalf("bounded writer returned a short write: written=%d err=%v", written, err)
	}
	if !output.overflow || output.buffer.String() != "abcd" {
		t.Fatalf("bounded writer did not retain its ceiling: %#v", output)
	}
}
