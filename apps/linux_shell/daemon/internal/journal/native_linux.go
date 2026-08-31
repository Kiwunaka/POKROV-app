//go:build linux

package journal

import "net"

const nativeJournalSocketPath = "/run/systemd/journal/socket"

func writeNative(payload []byte) error {
	return writeNativeAt(nativeJournalSocketPath, payload)
}

func writeNativeAt(socketPath string, payload []byte) error {
	address := &net.UnixAddr{Name: socketPath, Net: "unixgram"}
	connection, err := net.DialUnix("unixgram", nil, address)
	if err != nil {
		return err
	}
	defer connection.Close()
	_ = connection.SetWriteBuffer(16 * 1024)
	_, err = connection.Write(payload)
	return err
}
