#include "service_client.h"
#include "service_profile_identity.h"

#include <windows.h>

#include <bcrypt.h>

#include <algorithm>
#include <array>
#include <cstdint>
#include <optional>
#include <string>
#include <vector>
#include <thread>

#include "service_protocol.h"
#include "service_pipe_client.h"
#include "service_server.h"

namespace pokrov::service {
namespace {

constexpr wchar_t kProductionServiceName[] = L"POKROVService";
constexpr wchar_t kLocalSystemServiceAccount[] = L"LocalSystem";
constexpr DWORD kProductionPipeConnectTimeoutMs = 5000;
constexpr DWORD kStandardConnectIpcWaitMs = 90000;
// The service rejects frame deadlines more than five minutes ahead.
constexpr std::uint64_t kMaximumBoundIpcWaitMs = 299000;

std::optional<DWORD> BoundIpcWaitMs(const std::string& body) {
  const auto target = DecodeBoundConnect(body);
  if (!target) return std::nullopt;
  using QueryTime = VOID(WINAPI*)(PULONGLONG);
  const auto query = reinterpret_cast<QueryTime>(::GetProcAddress(
      ::GetModuleHandleW(L"kernel32.dll"), "QueryInterruptTimePrecise"));
  if (query == nullptr) return std::nullopt;
  ULONGLONG ticks = 0;
  query(&ticks);
  const auto elapsed_ms = ticks / 10000ULL;
  if (elapsed_ms < target->started_elapsed_ms ||
      elapsed_ms >= target->deadline_elapsed_ms) return std::nullopt;
  return static_cast<DWORD>((std::min)(target->deadline_elapsed_ms - elapsed_ms,
                                        kMaximumBoundIpcWaitMs));
}

std::uint64_t UnixTimeMilliseconds() {
  FILETIME file_time{};
  ::GetSystemTimeAsFileTime(&file_time);
  ULARGE_INTEGER ticks{};
  ticks.LowPart = file_time.dwLowDateTime;
  ticks.HighPart = file_time.dwHighDateTime;
  return (ticks.QuadPart - 116444736000000000ULL) / 10000ULL;
}

bool GenerateIdentifier(Identifier* output) {
  return output != nullptr &&
         ::BCryptGenRandom(nullptr, output->data(),
                           static_cast<ULONG>(output->size()),
                           BCRYPT_USE_SYSTEM_PREFERRED_RNG) == 0 &&
         !IsZeroIdentifier(*output);
}

bool TransferExact(HANDLE pipe, void* buffer, std::size_t size, bool write,
                   ULONGLONG deadline, ServiceCallControl* control) {
  auto* bytes = static_cast<std::uint8_t*>(buffer);
  std::size_t offset = 0;
  while (offset < size) {
    if (::GetTickCount64() >= deadline || (control && control->abandon_wait)) return false;
    OVERLAPPED overlapped{};
    overlapped.hEvent = ::CreateEventW(nullptr, TRUE, FALSE, nullptr);
    if (overlapped.hEvent == nullptr) return false;
    DWORD transferred = 0;
    const DWORD chunk = static_cast<DWORD>(size - offset);
    bool success = (write
                             ? ::WriteFile(pipe, bytes + offset, chunk,
                                           &transferred, &overlapped)
                             : ::ReadFile(pipe, bytes + offset, chunk,
                                          &transferred, &overlapped)) != FALSE;
    if (!success && ::GetLastError() == ERROR_IO_PENDING) {
      while (::GetTickCount64() < deadline && !(control && control->abandon_wait)) {
        const auto wait = ::WaitForSingleObject(overlapped.hEvent, 25);
        if (wait == WAIT_OBJECT_0) {
          success = ::GetOverlappedResult(pipe, &overlapped, &transferred, FALSE) != FALSE;
          break;
        }
        if (wait != WAIT_TIMEOUT) break;
      }
      if (!success) {
        ::CancelIoEx(pipe, &overlapped);
        ::GetOverlappedResult(pipe, &overlapped, &transferred, TRUE);
      }
    }
    ::CloseHandle(overlapped.hEvent);
    if (!success || transferred == 0) {
      return false;
    }
    offset += transferred;
  }
  return true;
}

bool WriteFrame(HANDLE pipe, const Frame& frame, ULONGLONG deadline,
                ServiceCallControl* control) {
  auto bytes = Encode(frame);
  return !bytes.empty() &&
         TransferExact(pipe, bytes.data(), bytes.size(), true, deadline, control);
}

std::optional<Frame> ReadFrame(HANDLE pipe, ULONGLONG deadline, ServiceCallControl* control) {
  std::array<std::uint8_t, kFrameHeaderSize> header{};
  if (!TransferExact(pipe, header.data(), header.size(), false, deadline, control)) {
    return std::nullopt;
  }
  const auto expected = ExpectedFrameSize(header.data(), header.size());
  if (!expected.has_value()) {
    return std::nullopt;
  }
  std::vector<std::uint8_t> bytes(*expected);
  std::copy(header.begin(), header.end(), bytes.begin());
  if (bytes.size() > header.size() &&
      !TransferExact(pipe, bytes.data() + header.size(),
                     bytes.size() - header.size(), false, deadline, control)) {
    return std::nullopt;
  }
  return Decode(bytes.data(), bytes.size());
}

std::wstring CurrentExecutableDirectory() {
  std::wstring path(32768, L'\0');
  const DWORD length = ::GetModuleFileNameW(
      nullptr, path.data(), static_cast<DWORD>(path.size()));
  if (length == 0 || length >= path.size()) {
    return L"";
  }
  path.resize(length);
  const auto separator = path.find_last_of(L"\\/");
  return separator == std::wstring::npos ? L""
                                         : path.substr(0, separator + 1);
}

std::wstring ServiceBinaryPath(const wchar_t* configured_path) {
  if (configured_path == nullptr) {
    return L"";
  }
  std::wstring path(configured_path);
  if (path.size() >= 2 && path.front() == L'"' && path.back() == L'"') {
    path = path.substr(1, path.size() - 2);
  }
  return path;
}

bool IsExpectedRegisteredService(ULONG server_process_id,
                                 const std::wstring& expected_path) {
  // An ordinary UI cannot query the LocalSystem process token. Bind the pipe
  // PID to the protected SCM record instead of requiring process elevation.
  SC_HANDLE manager =
      ::OpenSCManagerW(nullptr, nullptr, SC_MANAGER_CONNECT);
  if (manager == nullptr) {
    return false;
  }
  SC_HANDLE service = ::OpenServiceW(
      manager, kProductionServiceName,
      SERVICE_QUERY_STATUS | SERVICE_QUERY_CONFIG);
  if (service == nullptr) {
    ::CloseServiceHandle(manager);
    return false;
  }

  SERVICE_STATUS_PROCESS status{};
  DWORD bytes_needed = 0;
  const bool status_valid =
      ::QueryServiceStatusEx(service, SC_STATUS_PROCESS_INFO,
                             reinterpret_cast<BYTE*>(&status), sizeof(status),
                             &bytes_needed) != FALSE;

  bytes_needed = 0;
  ::QueryServiceConfigW(service, nullptr, 0, &bytes_needed);
  const bool config_size_valid =
      ::GetLastError() == ERROR_INSUFFICIENT_BUFFER &&
      bytes_needed >= sizeof(QUERY_SERVICE_CONFIGW);
  std::vector<std::uint8_t> config_bytes(
      config_size_valid ? bytes_needed : 0);
  auto* config = config_bytes.empty()
                     ? nullptr
                     : reinterpret_cast<QUERY_SERVICE_CONFIGW*>(
                           config_bytes.data());
  const bool config_valid =
      config != nullptr &&
      ::QueryServiceConfigW(service, config, bytes_needed, &bytes_needed) !=
          FALSE;

  const bool expected =
      status_valid && config_valid && status.dwCurrentState == SERVICE_RUNNING &&
      status.dwProcessId == static_cast<DWORD>(server_process_id) &&
      status.dwServiceType == SERVICE_WIN32_OWN_PROCESS &&
      config->dwServiceType == SERVICE_WIN32_OWN_PROCESS &&
      ::CompareStringOrdinal(ServiceBinaryPath(config->lpBinaryPathName).c_str(),
                             -1, expected_path.c_str(), -1, TRUE) ==
          CSTR_EQUAL &&
      config->lpServiceStartName != nullptr &&
      ::CompareStringOrdinal(config->lpServiceStartName, -1,
                             kLocalSystemServiceAccount, -1, TRUE) ==
          CSTR_EQUAL;
  ::CloseServiceHandle(service);
  ::CloseServiceHandle(manager);
  return expected;
}

bool IsExpectedServer(HANDLE pipe) {
  ULONG server_process_id = 0;
  if (!::GetNamedPipeServerProcessId(pipe, &server_process_id) ||
      server_process_id == 0) {
    return false;
  }
  const auto expected_path =
      CurrentExecutableDirectory() + L"pokrov_service.exe";
  return !expected_path.empty() &&
         IsExpectedRegisteredService(server_process_id, expected_path);
}

struct ExchangeResult {
  ClientProbe probe;
  std::optional<Frame> response;
  // Kept only for semantic response rejection by InvokeService; never exposed
  // in a runtime snapshot. Bound requests may also retain it in their private
  // ServiceCallControl so the runner can cancel after receiving the response.
  std::string connect_cancellation_target;
};

ExchangeResult Exchange(Command command, const std::string& body,
                        ServiceCallControl* control = nullptr,
                        const wchar_t* pipe_name = kProductionPipeName,
                        bool verify_server = true) {
  ExchangeResult result;
  if (control && (control->abandon_wait ||
                  (IsConnectCommand(command) && control->cancel_requested))) {
    return result;
  }
  HANDLE pipe = OpenNamedPipeClient(pipe_name, kProductionPipeConnectTimeoutMs,
                                    FILE_FLAG_OVERLAPPED);
  if (pipe == INVALID_HANDLE_VALUE) {
    return result;
  }
  result.probe.available = true;
  if (verify_server && !IsExpectedServer(pipe)) {
    result.probe.state = ClientState::kServerUntrusted;
    ::CloseHandle(pipe);
    return result;
  }
  result.probe.trusted = true;

  Identifier correlation{};
  if (!GenerateIdentifier(&correlation)) {
    ::CloseHandle(pipe);
    return result;
  }
  const Frame hello{
      FrameKind::kHelloRequest,
      Command::kHello,
      Status::kNone,
      correlation,
      {},
      {},
      0,
      kCapabilityProtocolV1 | kCapabilityStatus | kCapabilityRuntimeControl |
          kCapabilityProfileIdentity | kCapabilityCancellation | kCapabilitySanitizedDiagnostic |
          kCapabilityRoutingCatalogWindow | kCapabilitySmartAccessLease | kCapabilityRoutingCatalogControl |
          kCapabilitySmartAccessPolicyControl | kCapabilityRoutingCatalogServiceControl | kCapabilitySmartAccessRenewal |
          kCapabilitySmartAccessRuntimeControl | kCapabilityBootClock | kCapabilityBoundConnect | kCapabilityConnectSettlement | kCapabilityBoundRuntimeControl | kCapabilityTransportNetworkContext | kCapabilityBoundProfileStage | kCapabilityTransportLeaseHandoff,
      "",
  };
  if (!WriteFrame(pipe, hello, ::GetTickCount64() + 3000, control)) {
    ::CloseHandle(pipe);
    return result;
  }
  const auto hello_response = ReadFrame(pipe, ::GetTickCount64() + 3000, control);
  if (!hello_response.has_value() ||
      hello_response->kind != FrameKind::kResponse ||
      hello_response->command != Command::kHello ||
      hello_response->correlation_id != correlation ||
      hello_response->status != Status::kOk ||
      (hello_response->capabilities & kCapabilityProtocolV1) == 0 ||
      (hello_response->capabilities & kCapabilityStatus) == 0 ||
      (hello_response->capabilities & kCapabilityRuntimeControl) == 0 ||
      (hello_response->capabilities & kCapabilityProfileIdentity) == 0 ||
      (hello_response->capabilities & kCapabilityCancellation) == 0) {
    result.probe.state = ClientState::kProtocolIncompatible;
    ::CloseHandle(pipe);
    return result;
  }
  result.probe.compatible = true;
  if ((command == Command::kConfigureBoundSmartAccessRuntimeControl &&
       (hello_response->capabilities & (kCapabilityBoundRuntimeControl | kCapabilitySmartAccessRuntimeControl)) !=
           (kCapabilityBoundRuntimeControl | kCapabilitySmartAccessRuntimeControl)) ||
      (command == Command::kConnectWithIdentity &&
       (hello_response->capabilities & (kCapabilityBoundConnect | kCapabilityBootClock | kCapabilityConnectSettlement | kCapabilityTransportNetworkContext)) !=
           (kCapabilityBoundConnect | kCapabilityBootClock | kCapabilityConnectSettlement | kCapabilityTransportNetworkContext)) ||
      (command == Command::kStageBoundProfile &&
       (hello_response->capabilities & kCapabilityBoundProfileStage) == 0) ||
      (command == Command::kCancelConnectAndConfirm &&
       (hello_response->capabilities & kCapabilityConnectSettlement) == 0) ||
      (command == Command::kReadBootClock &&
       (hello_response->capabilities & kCapabilityBootClock) == 0) ||
      (command == Command::kReadTransportNetworkContext &&
       (hello_response->capabilities & kCapabilityTransportNetworkContext) == 0) ||
      ((command == Command::kPromoteTransportLease || command == Command::kRevokeTransportLease) &&
       (hello_response->capabilities & kCapabilityTransportLeaseHandoff) == 0) ||
      (command == Command::kRevokeSmartAccessLease &&
       (hello_response->capabilities & kCapabilitySmartAccessLease) == 0) ||
      (command == Command::kRevokeRoutingCatalog &&
       (hello_response->capabilities & kCapabilityRoutingCatalogControl) == 0) ||
      (command == Command::kRevokeSmartAccessPolicy &&
       (hello_response->capabilities & kCapabilitySmartAccessPolicyControl) == 0) ||
      (command == Command::kRevokeRoutingCatalogService &&
       (hello_response->capabilities & kCapabilityRoutingCatalogServiceControl) == 0) ||
      (command == Command::kRenewSmartAccessLease &&
       (hello_response->capabilities & kCapabilitySmartAccessRenewal) == 0) ||
      ((command == Command::kConfigureSmartAccessRuntimeControl || command == Command::kReadSmartAccessRestrictions ||
        command == Command::kAcknowledgeSmartAccessRestrictions || command == Command::kReadSmartAccessLeases ||
        command == Command::kConfigureSmartAccessRenewal) &&
       (hello_response->capabilities & kCapabilitySmartAccessRuntimeControl) == 0)) {
    result.probe.compatible = false;
    result.probe.state = ClientState::kProtocolIncompatible;
    ::CloseHandle(pipe);
    return result;
  }

  Identifier request_correlation{};
  Identifier operation_nonce{};
  if (!GenerateIdentifier(&request_correlation) ||
      !GenerateIdentifier(&operation_nonce)) {
    ::CloseHandle(pipe);
    return result;
  }
  const bool short_control = command == Command::kCancel || command == Command::kReadBootClock ||
      command == Command::kReadTransportNetworkContext ||
      command == Command::kDiagnosticState || command == Command::kRevokeSmartAccessLease ||
      command == Command::kRevokeRoutingCatalog || command == Command::kRevokeSmartAccessPolicy ||
      command == Command::kRevokeRoutingCatalogService || command == Command::kRenewSmartAccessLease ||
      command == Command::kConfigureSmartAccessRuntimeControl || command == Command::kReadSmartAccessRestrictions ||
      command == Command::kAcknowledgeSmartAccessRestrictions || command == Command::kReadSmartAccessLeases ||
      command == Command::kConfigureSmartAccessRenewal || command == Command::kConfigureBoundSmartAccessRuntimeControl ||
      command == Command::kPromoteTransportLease || command == Command::kRevokeTransportLease;
  const auto bound_wait_ms = command == Command::kConnectWithIdentity
      ? BoundIpcWaitMs(body) : std::optional<DWORD>{};
  if (command == Command::kConnectWithIdentity && !bound_wait_ms) {
    ::CloseHandle(pipe);
    return result;
  }
  const DWORD ipc_wait_ms = short_control ? 3000
      : command == Command::kConnect ? kStandardConnectIpcWaitMs
      : bound_wait_ms.value_or(30000);
  const Frame request{
      FrameKind::kRequest,
      command,
      Status::kNone,
      request_correlation,
      hello_response->session_token,
      operation_nonce,
      UnixTimeMilliseconds() + ipc_wait_ms,
      0,
      body,
  };
  const auto cancellation_target = IsConnectCommand(command)
      ? EncodeCancellationTarget({request.session_token, request.operation_nonce})
      : std::string{};
  if (IsConnectCommand(command) && control && control->cancel_requested) {
    ::CloseHandle(pipe);
    return result;
  }
  if (command == Command::kConnectWithIdentity && control != nullptr) {
    std::lock_guard<std::mutex> guard(control->cancellation_lock);
    // From this point a failed write is ambiguous and requires native proof.
    control->bound_cancellation_target = cancellation_target;
  }
  if (!WriteFrame(pipe, request, ::GetTickCount64() + 3000, control)) {
    ::CloseHandle(pipe);
    if (IsConnectCommand(command)) {
      // A failed overlapped write does not prove the server received no request.
      // Cancel only this authenticated request; never substitute Disconnect.
      Exchange(Command::kCancel, cancellation_target, nullptr, pipe_name, verify_server);
    }
    return result;
  }
  std::atomic<bool> finished{false};
  std::thread cancellation;
  if (IsConnectCommand(command) && control != nullptr) {
    const auto target = cancellation_target;
    cancellation = std::thread([&, target] {
      for (;;) {
        const bool done = finished.load();
        if (control->cancel_requested) {
          const auto cancelled = Exchange(Command::kCancel, target, nullptr, pipe_name, verify_server);
          if ((cancelled.response && cancelled.response->status == Status::kOk) ||
              done || finished.load()) break;
        } else if (done) {
          break;
        }
        ::Sleep(25);
      }
    });
  }
  result.response = ReadFrame(pipe,
      ::GetTickCount64() + ipc_wait_ms + (short_control ? 0 : 3000), control);
  if (!result.response && IsConnectCommand(command) && control) {
    // Publish cancellation before completion so the companion cannot exit on
    // the lost-response path without making its final bounded cancel attempt.
    control->cancel_requested = true;
  }
  finished = true;
  if (cancellation.joinable()) cancellation.join();
  ::CloseHandle(pipe);
  if (!result.response.has_value()) {
    if (IsConnectCommand(command) && control == nullptr) {
      Exchange(Command::kCancel, cancellation_target, nullptr, pipe_name, verify_server);
    }
    result.probe.state = ClientState::kUnavailable;
    return result;
  }
  if (result.response->kind != FrameKind::kResponse ||
      result.response->command != command ||
      result.response->correlation_id != request_correlation ||
      result.response->session_token != hello_response->session_token) {
    if (IsConnectCommand(command)) {
      Exchange(Command::kCancel, cancellation_target, nullptr, pipe_name, verify_server);
    }
    result.probe.state = ClientState::kProtocolIncompatible;
    result.probe.compatible = false;
    result.response.reset();
    return result;
  }
  result.connect_cancellation_target = cancellation_target;
  result.probe.state = ClientState::kBootstrap;
  return result;
}

bool ReadField(const std::string& body, std::size_t* offset,
               const char* key, std::string* value, bool last) {
  if (offset == nullptr || value == nullptr || key == nullptr) {
    return false;
  }
  const std::string prefix = std::string(key) + "=";
  if (body.compare(*offset, prefix.size(), prefix) != 0) {
    return false;
  }
  const auto start = *offset + prefix.size();
  const auto end = last ? body.size() : body.find(';', start);
  if (end == std::string::npos || end == start) {
    return false;
  }
  *value = body.substr(start, end - start);
  *offset = last ? body.size() : end + 1;
  return true;
}

bool ParseBool(const std::string& value, bool* output) {
  if (output == nullptr || (value != "0" && value != "1")) {
    return false;
  }
  *output = value == "1";
  return true;
}

bool IsKnownPhase(const std::string& value) {
  return value == "artifact_missing" || value == "artifact_ready" ||
         value == "connecting" || value == "busy" ||
         value == "initialized" || value == "config_staged" ||
         value == "running" || value == "recovery_required";
}

bool IsKnownFailure(const std::string& value) {
  static constexpr std::array<const char*, 46> failures = {
      "none",
      "core_not_initialized",
      "core_missing",
      "runtime_directory_failed",
      "core_load_failed",
      "core_abi_incompatible",
      "core_capabilities_incompatible",
      "runtime_path_invalid",
      "core_setup_failed",
      "profile_request_invalid",
      "profile_payload_invalid",
      "profile_write_failed",
      "profile_security_failed",
      "runtime_running",
      "profile_not_staged",
      "profile_identity_failed",
      "profile_identity_mismatch",
      "core_identity_mismatch",
      "connect_deadline",
      "core_start_failed",
      "core_egress_probe_failed",
      "core_egress_dns_failed",
      "core_egress_connect_failed",
      "core_egress_tls_failed",
      "core_egress_tls_timeout",
      "core_egress_response_timeout",
      "core_egress_timeout",
      "deadline_exceeded",
      "operation_cancelled",
      "runtime_busy",
      "core_stop_failed",
      "recovery_unavailable",
      "recovery_journal_invalid",
      "recovery_required",
      "recovery_generation_failed",
      "recovery_stage_invalid",
      "recovery_write_failed",
      "recovery_core_stop_failed",
      "recovery_network_unavailable",
      "recovery_network_capture_failed",
      "recovery_network_snapshot_invalid",
      "recovery_network_snapshot_too_large",
      "recovery_network_owner_ambiguous",
      "recovery_network_owner_missing",
      "recovery_network_restore_failed",
      "runtime_failure",
  };
  return std::find_if(failures.begin(), failures.end(),
                      [&value](const char* candidate) {
                        return value == candidate;
                      }) != failures.end();
}

bool ParseSnapshotBodyInternal(const std::string& body,
                               ServiceRuntimeSnapshot* output) {
  if (output == nullptr || body.size() > kMaxRuntimeSnapshotBodySize) {
    return false;
  }
  std::size_t offset = 0;
  std::string phase;
  std::string core_ready;
  std::string can_initialize;
  std::string can_connect;
  std::string running;
  std::string egress;
  std::string dns_ready;
  std::string staged_digest;
  std::string effective_digest;
  std::string failure;
  const bool has_catalog_window =
      body.find(";routing_catalog_window_version=") != std::string::npos;
  std::string catalog_window = "0";
  const bool has_smart_access =
      body.find(";smart_access_lease_version=") != std::string::npos;
  std::string smart_access = "0";
  const bool has_catalog_control = body.find(";routing_catalog_control_version=") != std::string::npos;
  std::string catalog_control = "0";
  const bool has_runtime_control = body.find(";smart_access_runtime_control_version=") != std::string::npos;
  std::string runtime_control = "0";
  const bool has_transport_capabilities = body.find(";transport_capabilities=") != std::string::npos;
  std::string transport_capabilities = "none";
  const bool has_module_digest = body.find(";core_module_sha256=") != std::string::npos;
  std::string module_digest = "none";
  const bool has_proof_state = body.find(";transport_proof_pending=") != std::string::npos;
  std::string proof_pending = "0";
  const bool has_lease_state = body.find(";transport_lease_active=") != std::string::npos;
  std::string lease_active = "0";
  if (has_lease_state && !has_proof_state) return false;
  if (has_proof_state && !has_module_digest) return false;
  if (has_module_digest && !has_transport_capabilities) return false;
  if (has_transport_capabilities && !has_runtime_control) return false;
  if (has_smart_access && !has_catalog_window) return false;
  if (has_catalog_control && (!has_catalog_window || !has_smart_access)) return false;
  if (has_runtime_control && !has_catalog_control) return false;
  if (!ReadField(body, &offset, "phase", &phase, false) ||
      !ReadField(body, &offset, "core_ready", &core_ready, false) ||
      !ReadField(body, &offset, "can_initialize", &can_initialize, false) ||
      !ReadField(body, &offset, "can_connect", &can_connect, false) ||
      !ReadField(body, &offset, "running", &running, false) ||
      !ReadField(body, &offset, "core_egress_validated", &egress, false) ||
      !ReadField(body, &offset, "dns_ready", &dns_ready, false) ||
      !ReadField(body, &offset, "staged_profile_digest", &staged_digest, false) ||
      !ReadField(body, &offset, "effective_profile_digest", &effective_digest,
                 false) ||
      !ReadField(body, &offset, "failure", &failure, !has_catalog_window) ||
      (has_catalog_window && !ReadField(body, &offset,
          "routing_catalog_window_version", &catalog_window, !has_smart_access)) ||
      (has_smart_access && !ReadField(body, &offset,
          "smart_access_lease_version", &smart_access, !has_catalog_control)) ||
      (has_catalog_control && !ReadField(body, &offset,
          "routing_catalog_control_version", &catalog_control, !has_runtime_control)) ||
      (has_runtime_control && !ReadField(body, &offset,
          "smart_access_runtime_control_version", &runtime_control, !has_transport_capabilities)) ||
      (has_transport_capabilities && !ReadField(body, &offset,
          "transport_capabilities", &transport_capabilities, !has_module_digest)) ||
      (has_module_digest && !ReadField(body, &offset, "core_module_sha256", &module_digest, !has_proof_state)) ||
      (has_proof_state && !ReadField(body, &offset, "transport_proof_pending", &proof_pending, !has_lease_state)) ||
      (has_lease_state && !ReadField(body, &offset, "transport_lease_active", &lease_active, true)) ||
      (module_digest != "none" && !IsProfileDigest(module_digest)) ||
      transport_capabilities.size() > 4096 ||
      !std::all_of(transport_capabilities.begin(), transport_capabilities.end(), [](unsigned char character) {
        return character >= 32 && character <= 126 && character != ';';
      }) ||
      (runtime_control != "0" && runtime_control != "1") ||
      (runtime_control == "1" && catalog_control != "4") ||
      (catalog_window != "0" && catalog_window != "1") ||
      (smart_access != "0" && smart_access != "1") ||
      (smart_access == "1" && catalog_window != "1") ||
      (catalog_control != "0" && catalog_control != "1" && catalog_control != "2" && catalog_control != "3" && catalog_control != "4") ||
      (catalog_control != "0" && catalog_window != "1") ||
      ((catalog_control == "2" || catalog_control == "3" || catalog_control == "4") && smart_access != "1") ||
      offset != body.size() || !IsKnownPhase(phase) ||
      !IsKnownFailure(failure) ||
      !ParseBool(core_ready, &output->core_ready) ||
      !ParseBool(can_initialize, &output->can_initialize) ||
      !ParseBool(can_connect, &output->can_connect) ||
      !ParseBool(running, &output->running) ||
      !ParseBool(egress, &output->core_egress_validated) ||
      !ParseBool(dns_ready, &output->dns_ready) ||
      !ParseBool(proof_pending, &output->transport_proof_pending) ||
      !ParseBool(lease_active, &output->transport_lease_active)) {
    return false;
  }
  if ((phase == "running") != output->running ||
      ((phase == "connecting" || phase == "busy") &&
       (output->can_initialize || output->can_connect || output->running)) ||
      output->dns_ready != output->core_egress_validated ||
      (output->core_egress_validated && !output->running) ||
      (!has_proof_state && output->running && !output->core_egress_validated) ||
      (output->running && !output->core_ready) ||
      (output->can_connect && !output->core_ready)) {
    return false;
  }
  if ((staged_digest != "none" && !IsProfileDigest(staged_digest)) ||
      (effective_digest != "none" && !IsProfileDigest(effective_digest)) ||
      (output->can_connect && staged_digest == "none") ||
      (output->running &&
       (effective_digest == "none" || (staged_digest != "none" && effective_digest != staged_digest))) ||
      (!output->running && effective_digest != "none")) {
    return false;
  }
  output->staged_profile_digest = staged_digest == "none" ? "" : staged_digest;
  output->effective_profile_digest =
      effective_digest == "none" ? "" : effective_digest;
  output->phase = phase;
  output->failure = failure;
  output->routing_catalog_window_version =
      output->core_ready && catalog_window == "1" ? 1 : 0;
  output->smart_access_lease_version =
      output->core_ready && smart_access == "1" ? 1 : 0;
  output->routing_catalog_control_version =
      output->core_ready ? (catalog_control == "4" ? 4 : catalog_control == "3" ? 3 : catalog_control == "2" ? 2 : catalog_control == "1" ? 1 : 0) : 0;
  output->smart_access_runtime_control_version = output->core_ready && runtime_control == "1" ? 1 : 0;
  output->transport_capabilities_json = output->core_ready && transport_capabilities != "none"
      ? transport_capabilities : "";
  output->core_module_sha256 = output->core_ready && module_digest != "none" ? module_digest : "";
  output->transport_proof_state_available = has_proof_state;
  output->transport_lease_state_available = has_lease_state;
  return true;
}

}  // namespace

bool ParseServiceRuntimeSnapshot(const std::string& body,
                                 ServiceRuntimeSnapshot* output) {
  if (output == nullptr) return false;
  auto parsed = *output;
  if (!ParseSnapshotBodyInternal(body, &parsed)) return false;
  *output = std::move(parsed);
  return true;
}

ServiceRuntimeSnapshot BindSnapshotToProfileIntent(
    ServiceRuntimeSnapshot snapshot, const std::string& expected_profile_digest) {
  const bool matches_running_without_reuse = snapshot.running && snapshot.staged_profile_digest.empty() &&
      snapshot.effective_profile_digest == expected_profile_digest;
  if (!expected_profile_digest.empty() &&
      snapshot.staged_profile_digest != expected_profile_digest && !matches_running_without_reuse) {
    snapshot.core_egress_validated = false;
    snapshot.dns_ready = false;
    snapshot.can_connect = false;
    snapshot.failure = "profile_identity_mismatch";
  }
  return snapshot;
}

ClientProbe ProbeInstalledService() {
  const auto snapshot = InvokeInstalledService(Command::kStatus, "");
  ClientProbe result;
  result.state = snapshot.client_state;
  result.available = snapshot.available;
  result.trusted = snapshot.trusted;
  result.compatible = snapshot.compatible;
  result.runtime_ready = snapshot.core_ready;
  return result;
}

ServiceRuntimeSnapshot InvokeService(Command command, const std::string& body,
                                     ServiceCallControl* control,
                                     const wchar_t* pipe_name, bool verify_server) {
  ServiceRuntimeSnapshot result;
  const auto bound = command == Command::kConnectWithIdentity ? DecodeBoundConnect(body) : std::nullopt;
  if (command == Command::kConnectWithIdentity && !bound) {
    result.failure = "core_identity_mismatch";
    return result;
  }
  const auto exchange = Exchange(command, body, control, pipe_name, verify_server);
  result.client_state = exchange.probe.state;
  result.available = exchange.probe.available;
  result.trusted = exchange.probe.trusted;
  result.compatible = exchange.probe.compatible;
  if (!exchange.response.has_value()) {
    return result;
  }
  result.status = exchange.response->status;
  result.command_accepted = result.status == Status::kOk;
  if (command == Command::kCancelConnectAndConfirm) {
    if (result.command_accepted && (exchange.response->body == "settled=0" || exchange.response->body == "settled=1")) {
      result.connect_stopped = exchange.response->body == "settled=1";
    } else {
      result.command_accepted = false;
    }
    return result;
  }
  if (command == Command::kReadSmartAccessLeases) {
    if (result.command_accepted && !exchange.response->body.empty() && exchange.response->body.size() <= kMaxSmartAccessLeasesBodySize) {
      result.smart_access_lease_ids_json = exchange.response->body;
    } else { result.command_accepted = false; }
    return result;
  }
  if (command == Command::kReadBootClock) {
    if (result.command_accepted && !exchange.response->body.empty() && exchange.response->body.size() <= 256) {
      result.boot_clock_json = exchange.response->body;
    } else { result.command_accepted = false; }
    return result;
  }
  if (command == Command::kReadTransportNetworkContext) {
    if (result.command_accepted && IsTransportNetworkContextRef(exchange.response->body)) {
      result.transport_network_context_ref = exchange.response->body;
    } else {
      result.command_accepted = false;
    }
    return result;
  }
  if (command == Command::kReadSmartAccessRestrictions) {
    if (result.command_accepted && !exchange.response->body.empty() && exchange.response->body.size() <= kMaxRestrictionSnapshotBodySize) {
      result.smart_access_restriction_journal = exchange.response->body;
    } else { result.command_accepted = false; }
    return result;
  }
  if (command == Command::kAcknowledgeSmartAccessRestrictions) {
    if (result.command_accepted && exchange.response->body != "acknowledged=0" && exchange.response->body != "acknowledged=1") {
      result.compatible = false;
      result.command_accepted = false;
    }
    result.smart_access_restrictions_acknowledged = result.command_accepted && exchange.response->body == "acknowledged=1";
    return result;
  }
  if (command == Command::kConfigureSmartAccessRuntimeControl || command == Command::kConfigureSmartAccessRenewal ||
      command == Command::kConfigureBoundSmartAccessRuntimeControl) {
    if (result.command_accepted && exchange.response->body != "configured=0" && exchange.response->body != "configured=1") {
      result.compatible = false;
      result.command_accepted = false;
    }
    result.smart_access_runtime_control_configured = result.command_accepted && exchange.response->body == "configured=1";
    return result;
  }
  if (command == Command::kRenewSmartAccessLease) {
    if (result.command_accepted && exchange.response->body != "renewed=0" && exchange.response->body != "renewed=1") {
      result.compatible = false;
      result.command_accepted = false;
    }
    result.smart_access_lease_renewed = result.command_accepted && exchange.response->body == "renewed=1";
    return result;
  }
  if (command == Command::kRevokeRoutingCatalog || command == Command::kRevokeRoutingCatalogService) {
    if (result.command_accepted && exchange.response->body != "catalog_revoked=0" &&
        exchange.response->body != "catalog_revoked=1") {
      result.compatible = false;
      result.command_accepted = false;
    }
    result.routing_catalog_found = result.command_accepted && exchange.response->body == "catalog_revoked=1";
    return result;
  }
  if (command == Command::kRevokeSmartAccessLease || command == Command::kRevokeSmartAccessPolicy) {
    if (result.command_accepted && exchange.response->body != "revoked=0" &&
        exchange.response->body != "revoked=1") {
      result.compatible = false;
      result.command_accepted = false;
    }
    result.smart_access_lease_found = result.command_accepted && exchange.response->body == "revoked=1";
    return result;
  }
  if (command == Command::kDiagnosticState) {
    if (result.command_accepted &&
        !windows_crash::DecodeWindowsCrashDiagnostics(exchange.response->body,
                                                      &result.crash_diagnostics)) {
      result.compatible = false;
      result.command_accepted = false;
    }
    return result;
  }
  if (bound && !result.command_accepted && IsKnownFailure(exchange.response->body)) {
    result.failure = exchange.response->body;
    return result;
  }
  if (!ParseServiceRuntimeSnapshot(exchange.response->body, &result)) {
    if (IsConnectCommand(command)) {
      Exchange(Command::kCancel, exchange.connect_cancellation_target, nullptr,
               pipe_name, verify_server);
    }
    result.client_state = ClientState::kProtocolIncompatible;
    result.compatible = false;
    result.command_accepted = false;
    return result;
  }
  if (result.command_accepted &&
      (((command == Command::kStageProfile || command == Command::kStageBoundProfile) &&
        result.staged_profile_digest != ProfileDigest(body)) ||
       (IsConnectCommand(command) &&
        (result.effective_profile_digest != (bound ? bound->profile_digest : body) ||
         (bound && result.core_module_sha256 != bound->core_module_sha256))))) {
    if (IsConnectCommand(command)) {
      Exchange(Command::kCancel, exchange.connect_cancellation_target, nullptr,
               pipe_name, verify_server);
    }
    result.command_accepted = false;
    result.running = false;
    result.core_egress_validated = false;
    result.dns_ready = false;
    result.failure = bound ? "core_identity_mismatch" : "profile_identity_mismatch";
  }
  result.client_state = result.core_ready ? ClientState::kReady
                                          : ClientState::kBootstrap;
  return result;
}

bool CancelInstalledServiceConnect(ServiceCallControl* control) {
  if (control == nullptr) return false;
  control->cancel_requested = true;
  std::string target;
  {
    std::lock_guard<std::mutex> guard(control->cancellation_lock);
    target = control->bound_cancellation_target;
  }
  // A completed bound call with no published target never wrote its request.
  if (target.empty()) return control->completed.load();
  const auto result = Exchange(Command::kCancel, target);
  const bool accepted = result.response && (result.response->status == Status::kOk ||
      (result.response->status == Status::kNotReady && result.response->body == "operation_not_active"));
  // Retain the target until the exact settlement receipt. An admission ACK
  // can precede failed cleanup and must not remove the exact retry capability.
  return accepted;  // cancellation admission, not completed TUN restoration
}

ServiceRuntimeSnapshot InvokeInstalledService(Command command,
                                              const std::string& body,
                                              ServiceCallControl* control) {
  if (command == Command::kCancelConnectAndConfirm && body.empty() && control != nullptr) {
    ServiceRuntimeSnapshot result;
    control->cancel_requested = true;
    // The runner queues this after the original invocation on the same worker.
    if (!control->completed.load()) return result;
    std::string target;
    {
      std::lock_guard<std::mutex> guard(control->cancellation_lock);
      target = control->bound_cancellation_target;
    }
    if (target.empty()) {
      result.command_accepted = true;
      result.connect_stopped = true;  // no request could have been written
      return result;
    }
    // The cancelled start's control must not interrupt its own cleanup IPC.
    return InvokeService(command, target, nullptr, kProductionPipeName, true);
  }
  if (command == Command::kCancel && body.empty() && control != nullptr) {
    ServiceRuntimeSnapshot result;
    result.command_accepted = CancelInstalledServiceConnect(control);
    result.failure = result.command_accepted ? "none" : "operation_cancel_unconfirmed";
    return result;
  }
  auto result = InvokeService(command, body, control, kProductionPipeName, true);
  if (command == Command::kDiagnosticState && result.command_accepted) {
    std::vector<windows_crash::WindowsCrashDiagnostic> ui_records;
    if (!windows_crash::ReadWindowsCrashDiagnostics(
            windows_crash::WindowsCrashProcess::kUi,
            windows_crash::ResolveWindowsUiStateRoot(), &ui_records)) {
      result.command_accepted = false;
      result.crash_diagnostics.clear();
    } else {
      result.crash_diagnostics.insert(result.crash_diagnostics.end(),
                                     ui_records.begin(), ui_records.end());
    }
  }
  return result;
}

#ifdef _DEBUG
ServiceRuntimeSnapshot InvokeServiceForTest(const std::wstring& pipe_name,
                                            Command command, const std::string& body,
                                            ServiceCallControl* control) {
  if (pipe_name.rfind(kTestPipePrefix, 0) != 0) return {};
  return InvokeService(command, body, control, pipe_name.c_str(), false);
}
#endif

const char* ClientStateName(ClientState state) {
  switch (state) {
    case ClientState::kUnavailable:
      return "unavailable";
    case ClientState::kServerUntrusted:
      return "server_untrusted";
    case ClientState::kProtocolIncompatible:
      return "protocol_incompatible";
    case ClientState::kBootstrap:
      return "service_bootstrap";
    case ClientState::kReady:
      return "service_ready";
  }
  return "protocol_incompatible";
}

}  // namespace pokrov::service
