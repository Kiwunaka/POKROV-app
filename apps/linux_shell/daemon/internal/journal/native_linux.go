//go:build linux

package journal

import "net"

func writeNative(payload []byte) error {
	address := &net.UnixAddr{Name: "/run/systemd/journal/socket", Net: "unixgram"}
	connection, err := net.DialUnix("unixgram", nil, address)
	if err != nil {
		return err
	}
	defer connection.Close()
	_ = connection.SetWriteBuffer(16 * 1024)
	_, err = connection.Write(payload)
	return err
}
