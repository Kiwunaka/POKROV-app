//go:build !linux

package journal

import "errors"

func writeNative([]byte) error {
	return errors.New("native journald transport is unavailable")
}
