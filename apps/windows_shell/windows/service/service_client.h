#ifndef POKROV_SERVICE_SERVICE_CLIENT_H_
#define POKROV_SERVICE_SERVICE_CLIENT_H_

#include <string>
#include <atomic>

#include "service_protocol.h"
#include "windows_crash_profile.h"

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
  std::string staged_profile_digest;
  std::string effective_profile_digest;
  std::string phase = "artifact_missing";
  std::string failure = "service_unavailable";
  std::vector<windows_crash::WindowsCrashDiagnostic> crash_diagnostics;
};

// Parse atomically: rejected service data cannot leave partially healthy state.
bool ParseServiceRuntimeSnapshot(const std::string& body,
                                 ServiceRuntimeSnapshot* output);
ServiceRuntimeSnapshot BindSnapshotToProfileIntent(
    ServiceRuntimeSnapshot snapshot, const std::string& expected_profile_digest);
ClientProbe ProbeInstalledService();
struct ServiceCallControl {
  std::atomic<bool> cancel_requested{false};
  std::atomic<bool> abandon_wait{false};
};
ServiceRuntimeSnapshot InvokeInstalledService(Command command,
                                              const std::string& body,
                                              ServiceCallControl* control = nullptr);
#ifdef _DEBUG
ServiceRuntimeSnapshot InvokeServiceForTest(const std::wstring& pipe_name,
                                            Command command, const std::string& body,
                                            ServiceCallControl* control = nullptr);
#endif
const char* ClientStateName(ClientState state);

}  // namespace pokrov::service

#endif  // POKROV_SERVICE_SERVICE_CLIENT_H_
