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
};

ExchangeResult Exchange(Command command, const std::string& body,
                        ServiceCallControl* control = nullptr,
                        const wchar_t* pipe_name = kProductionPipeName,
                        bool verify_server = true) {
  ExchangeResult result;
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
          kCapabilityProfileIdentity | kCapabilityCancellation | kCapabilitySanitizedDiagnostic,
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

  Identifier request_correlation{};
  Identifier operation_nonce{};
  if (!GenerateIdentifier(&request_correlation) ||
      !GenerateIdentifier(&operation_nonce)) {
    ::CloseHandle(pipe);
    return result;
  }
  const Frame request{
      FrameKind::kRequest,
      command,
      Status::kNone,
      request_correlation,
      hello_response->session_token,
      operation_nonce,
      UnixTimeMilliseconds() + ((command == Command::kCancel || command == Command::kDiagnosticState) ? 3000 : 30000),
      0,
      body,
  };
  if ((command == Command::kConnect && control && control->cancel_requested) ||
      !WriteFrame(pipe, request, ::GetTickCount64() + 3000, control)) {
    ::CloseHandle(pipe);
    return result;
  }
  std::atomic<bool> finished{false};
  std::thread cancellation;
  if (command == Command::kConnect && control != nullptr) {
    const auto target = EncodeCancellationTarget({request.session_token, request.operation_nonce});
    cancellation = std::thread([&, target] {
      for (;;) {
        if (control->cancel_requested) {
          const auto cancelled = Exchange(Command::kCancel, target, nullptr, pipe_name, verify_server);
          if (cancelled.response && cancelled.response->status == Status::kOk) break;
        }
        if (finished) break;
        ::Sleep(25);
      }
    });
  }
  result.response = ReadFrame(pipe,
      ::GetTickCount64() + ((command == Command::kCancel || command == Command::kDiagnosticState) ? 3000 : 33000), control);
  finished = true;
  if (cancellation.joinable()) cancellation.join();
  ::CloseHandle(pipe);
  if (!result.response.has_value()) {
    result.probe.state = ClientState::kUnavailable;
    return result;
  }
  if (result.response->kind != FrameKind::kResponse ||
      result.response->command != command ||
      result.response->correlation_id != request_correlation ||
      result.response->session_token != hello_response->session_token) {
    result.probe.state = ClientState::kProtocolIncompatible;
    result.response.reset();
    return result;
  }
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
  static constexpr std::array<const char*, 38> failures = {
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
      "core_start_failed",
      "core_egress_probe_failed",
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
  if (output == nullptr || body.size() > kMaxControlBodySize) {
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
      !ReadField(body, &offset, "failure", &failure, true) ||
      offset != body.size() || !IsKnownPhase(phase) ||
      !IsKnownFailure(failure) ||
      !ParseBool(core_ready, &output->core_ready) ||
      !ParseBool(can_initialize, &output->can_initialize) ||
      !ParseBool(can_connect, &output->can_connect) ||
      !ParseBool(running, &output->running) ||
      !ParseBool(egress, &output->core_egress_validated) ||
      !ParseBool(dns_ready, &output->dns_ready)) {
    return false;
  }
  if ((phase == "running") != output->running ||
      ((phase == "connecting" || phase == "busy") &&
       (output->can_initialize || output->can_connect || output->running)) ||
      output->dns_ready != output->core_egress_validated ||
      output->running != output->core_egress_validated ||
      (output->running && !output->core_ready) ||
      (output->can_connect && !output->core_ready)) {
    return false;
  }
  if ((staged_digest != "none" && !IsProfileDigest(staged_digest)) ||
      (effective_digest != "none" && !IsProfileDigest(effective_digest)) ||
      (output->can_connect && staged_digest == "none") ||
      (output->running &&
       (staged_digest == "none" || effective_digest != staged_digest)) ||
      (!output->running && effective_digest != "none")) {
    return false;
  }
  output->staged_profile_digest = staged_digest == "none" ? "" : staged_digest;
  output->effective_profile_digest =
      effective_digest == "none" ? "" : effective_digest;
  output->phase = phase;
  output->failure = failure;
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
  if (!expected_profile_digest.empty() &&
      snapshot.staged_profile_digest != expected_profile_digest) {
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
  if (command == Command::kDiagnosticState) {
    if (result.command_accepted &&
        !windows_crash::DecodeWindowsCrashDiagnostics(exchange.response->body,
                                                      &result.crash_diagnostics)) {
      result.compatible = false;
      result.command_accepted = false;
    }
    return result;
  }
  if (!ParseServiceRuntimeSnapshot(exchange.response->body, &result)) {
    result.client_state = ClientState::kProtocolIncompatible;
    result.compatible = false;
    result.command_accepted = false;
    return result;
  }
  if (result.command_accepted &&
      ((command == Command::kStageProfile &&
        result.staged_profile_digest != ProfileDigest(body)) ||
       (command == Command::kConnect &&
        result.effective_profile_digest != body))) {
    result.command_accepted = false;
    result.running = false;
    result.core_egress_validated = false;
    result.dns_ready = false;
    result.failure = "profile_identity_mismatch";
  }
  result.client_state = result.core_ready ? ClientState::kReady
                                          : ClientState::kBootstrap;
  return result;
}

ServiceRuntimeSnapshot InvokeInstalledService(Command command,
                                              const std::string& body,
                                              ServiceCallControl* control) {
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
