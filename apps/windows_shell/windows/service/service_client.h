#ifndef POKROV_SERVICE_SERVICE_CLIENT_H_
#define POKROV_SERVICE_SERVICE_CLIENT_H_

#include <string>

#include "service_protocol.h"

namespace pokrov::service {

enum class ClientState {
  kUnavailable,
  kServerUntrusted,
  kProtocolIncompatible,
  kBootstrap,
  kReady,
};

struct ClientProbe {
  ClientState state = ClientState::kUnavailable;
  bool available = false;
  bool trusted = false;
  bool compatible = false;
  bool runtime_ready = false;
};

struct ServiceRuntimeSnapshot {
  ClientState client_state = ClientState::kUnavailable;
  Status status = Status::kNotReady;
  bool available = false;
  bool trusted = false;
  bool compatible = false;
  bool command_accepted = false;
  bool core_ready = false;
  bool can_initialize = false;
  bool can_connect = false;
  bool running = false;
  bool core_egress_validated = false;
  bool dns_ready = false;
  std::string phase = "artifact_missing";
  std::string failure = "service_unavailable";
};

ClientProbe ProbeInstalledService();
ServiceRuntimeSnapshot InvokeInstalledService(Command command,
                                              const std::string& body);
const char* ClientStateName(ClientState state);

}  // namespace pokrov::service

#endif  // POKROV_SERVICE_SERVICE_CLIENT_H_
