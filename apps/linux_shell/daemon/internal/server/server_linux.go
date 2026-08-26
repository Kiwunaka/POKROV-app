//go:build linux

package server

import (
	"bufio"
	"bytes"
	"encoding/json"
	"errors"
	"io"
	"net"
	"time"

	"github.com/Kiwunaka/pokrov-app/linux-daemon/internal/auth"
	"github.com/Kiwunaka/pokrov-app/linux-daemon/internal/protocol"
	"github.com/Kiwunaka/pokrov-app/linux-daemon/internal/service"
)

type Server struct {
	Service     *service.Service
	IdleTimeout time.Duration
	concurrency chan struct{}
}

func New(service *service.Service) *Server {
	return &Server{
		Service:     service,
		IdleTimeout: 12 * time.Second,
		concurrency: make(chan struct{}, 32),
	}
}

func (server *Server) Serve(listener *net.UnixListener) error {
	for {
		connection, err := listener.AcceptUnix()
		if err != nil {
			if errors.Is(err, net.ErrClosed) {
				return nil
			}
			return err
		}
		select {
		case server.concurrency <- struct{}{}:
			go func() {
				defer func() { <-server.concurrency }()
				server.serveConnection(connection)
			}()
		default:
			_ = connection.Close()
		}
	}
}

func (server *Server) serveConnection(connection *net.UnixConn) {
	defer connection.Close()
	_ = connection.SetDeadline(time.Now().Add(server.IdleTimeout))
	peer, err := auth.PeerFrom(connection)
	if err != nil {
		server.writeResponse(connection, protocol.Failure("invalid", "linux_protocol_invalid", "runtime_error"))
		return
	}
	reader := bufio.NewReaderSize(
		io.LimitReader(connection, protocol.MaximumRequestBytes+1),
		protocol.MaximumRequestBytes+1,
	)
	line, err := reader.ReadBytes('\n')
	if err != nil || len(line) > protocol.MaximumRequestBytes {
		server.writeResponse(connection, protocol.Failure("invalid", "linux_protocol_invalid", "runtime_error"))
		return
	}
	request, err := decodeRequest(line)
	if err != nil {
		server.writeResponse(connection, protocol.Failure("invalid", "linux_protocol_invalid", "runtime_error"))
		return
	}
	server.writeResponse(connection, server.Service.Handle(peer, request))
}

func decodeRequest(line []byte) (protocol.Request, error) {
	decoder := json.NewDecoder(bytes.NewReader(line))
	decoder.DisallowUnknownFields()
	var request protocol.Request
	if err := decoder.Decode(&request); err != nil {
		return protocol.Request{}, errors.New("invalid request envelope")
	}
	var trailing any
	if err := decoder.Decode(&trailing); !errors.Is(err, io.EOF) {
		return protocol.Request{}, errors.New("trailing request data")
	}
	if err := request.Validate(); err != nil {
		return protocol.Request{}, err
	}
	return request, nil
}

func (server *Server) writeResponse(connection *net.UnixConn, response protocol.Response) {
	encoded, err := json.Marshal(response)
	if err != nil || len(encoded) > 64*1024 {
		encoded, _ = json.Marshal(protocol.Failure("invalid", "linux_runtime_error", "runtime_error"))
	}
	encoded = append(encoded, '\n')
	_, _ = connection.Write(encoded)
}
