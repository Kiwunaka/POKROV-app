#ifndef POKROV_SERVICE_SERVICE_CLIENT_H_
#define POKROV_SERVICE_SERVICE_CLIENT_H_

#include <string>
#include <atomic>
#include <mutex>

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
  bool connect_stopped = false;  // exact private target, never a global snapshot inference
  bool smart_access_lease_found = false;
  bool smart_access_lease_renewed = false;
  bool smart_access_runtime_control_configured = false;
  bool smart_access_restrictions_acknowledged = false;
  std::string smart_access_restriction_journal;
  std::string smart_access_lease_ids_json;
  std::string boot_clock_json;
  std::string transport_network_context_ref;
  bool routing_catalog_found = false;
  bool core_ready = false;
  bool can_initialize = false;
  bool can_connect = false;
  bool running = false;
  bool core_egress_validated = false;
  bool dns_ready = false;
  bool transport_proof_state_available = false;
  bool transport_proof_pending = false;
  bool transport_lease_state_available = false;
  bool transport_lease_active = false;
  int routing_catalog_window_version = 0;
  int smart_access_lease_version = 0;
  int routing_catalog_control_version = 0;
  int smart_access_runtime_control_version = 0;
  std::string transport_capabilities_json;
  std::string core_module_sha256;
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
  // Invocation completion is not proof that the service's tunnel is stopped.
  std::atomic<bool> completed{false};
  // Bound-connect cancellation survives the response. Keep its secret target
  // in this invocation owner only, never in snapshots, logs or diagnostics.
  std::mutex cancellation_lock;
  std::string bound_cancellation_target;
};
bool CancelInstalledServiceConnect(ServiceCallControl* control);
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
