#include "service_client.h"
#include "service_profile_identity.h"

#include <windows.h>

#include <algorithm>
#include <iostream>
#include <string>
#include <thread>

#include "service_server.h"

#ifdef _DEBUG
namespace {
using namespace pokrov::service;

bool Transfer(HANDLE pipe, void* data, std::size_t size, bool write) {
  auto* bytes = static_cast<std::uint8_t*>(data);
  while (size > 0) {
    DWORD transferred = 0;
    const BOOL ok = write ? ::WriteFile(pipe, bytes, static_cast<DWORD>(size), &transferred, nullptr)
                          : ::ReadFile(pipe, bytes, static_cast<DWORD>(size), &transferred, nullptr);
    if (!ok || transferred == 0) return false;
    bytes += transferred;
    size -= transferred;
  }
  return true;
}

std::optional<Frame> ReadFrame(HANDLE pipe) {
  std::array<std::uint8_t, kFrameHeaderSize> header{};
  if (!Transfer(pipe, header.data(), header.size(), false)) return std::nullopt;
  const auto size = ExpectedFrameSize(header.data(), header.size());
  if (!size) return std::nullopt;
  std::vector<std::uint8_t> bytes(*size);
  std::copy(header.begin(), header.end(), bytes.begin());
  if (*size > header.size() &&
      !Transfer(pipe, bytes.data() + header.size(), *size - header.size(), false)) return std::nullopt;
  return Decode(bytes.data(), bytes.size());
}

bool WriteFrame(HANDLE pipe, const Frame& frame) {
  auto bytes = Encode(frame);
  return !bytes.empty() && Transfer(pipe, bytes.data(), bytes.size(), true);
}

ServiceRuntimeSnapshot RuntimeControlReceipt(Command command, Status status,
    const std::string& response, DWORD delay_ms, std::uint64_t* request_wait_ms) {
  const auto name = std::wstring(kTestPipePrefix) + L"RuntimeControlReceipt." +
      std::to_wstring(::GetCurrentProcessId());
  const HANDLE pipe = ::CreateNamedPipeW(name.c_str(), PIPE_ACCESS_DUPLEX,
      PIPE_TYPE_BYTE | PIPE_READMODE_BYTE | PIPE_WAIT | PIPE_REJECT_REMOTE_CLIENTS,
      1, 32768, 32768, 0, nullptr);
  if (pipe == INVALID_HANDLE_VALUE) return {};
  std::thread server([&] {
    if (::ConnectNamedPipe(pipe, nullptr) || ::GetLastError() == ERROR_PIPE_CONNECTED) {
      const auto hello = ReadFrame(pipe);
      Identifier token{};
      token[0] = 1;
      if (hello && WriteFrame(pipe, {FrameKind::kResponse, Command::kHello, Status::kOk,
          hello->correlation_id, token, {}, 0,
          kCapabilityProtocolV1 | kCapabilityStatus | kCapabilityRuntimeControl |
              kCapabilityProfileIdentity | kCapabilityCancellation |
              kCapabilityBoundRuntimeControl | kCapabilitySmartAccessRuntimeControl, ""})) {
        const auto request = ReadFrame(pipe);
        if (request) {
          FILETIME time{};
          ::GetSystemTimeAsFileTime(&time);
          const auto now = ((static_cast<std::uint64_t>(time.dwHighDateTime) << 32) |
              time.dwLowDateTime) / 10000ULL - 11644473600000ULL;
          *request_wait_ms = request->deadline_unix_ms - now;
          ::Sleep(delay_ms);
          WriteFrame(pipe, {FrameKind::kResponse, command, status,
              request->correlation_id, token, {}, 0, 0, response});
        }
      }
    }
    ::FlushFileBuffers(pipe);
    ::DisconnectNamedPipe(pipe);
    ::CloseHandle(pipe);
  });
  const auto config = ProfileDigest("runtime-control-fixture") +
      R"(|{"platform":"windows","capability":"saqa1.fixture"})";
  const auto body = command == Command::kConfigureBoundSmartAccessRuntimeControl
      ? std::string(64, 'a') + "|" + config : config;
  const auto result = InvokeServiceForTest(name, command, body);
  server.join();
  return result;
}
}  // namespace
#endif

int main() {
  using namespace pokrov::service;
  int failures = 0;
  const auto expect = [&failures](bool ok, const char* message) {
    if (!ok) { std::cerr << message << '\n'; ++failures; }
  };
  expect(ProfileDigest("abc") ==
             "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
         "SHA-256 known answer mismatch");
  const auto digest = ProfileDigest("0\n{}");
  expect(digest != ProfileDigest("1\n{}"), "identity omitted runtime flags");
  const auto snapshot = [&digest](const std::string& effective) {
    return "phase=running;core_ready=1;can_initialize=1;can_connect=0;"
           "running=1;core_egress_validated=1;dns_ready=1;staged_profile_digest=" +
           digest + ";effective_profile_digest=" + effective + ";failure=none";
  };
  ServiceRuntimeSnapshot parsed;
  expect(ParseServiceRuntimeSnapshot(snapshot(digest), &parsed) &&
             parsed.running && parsed.effective_profile_digest == digest &&
             !parsed.protection_retained && !parsed.protection_retained_state_available,
         "matching service proof rejected");
  for (const auto& effective : {std::string("none"), std::string(64, '0'),
                                std::string(64, 'g')}) {
    ServiceRuntimeSnapshot rejected;
    expect(!ParseServiceRuntimeSnapshot(snapshot(effective), &rejected) &&
               !rejected.running && !rejected.core_egress_validated,
           "invalid identity accepted or left partial healthy state");
  }
  const auto matching = BindSnapshotToProfileIntent(parsed, digest);
  expect(matching.core_egress_validated, "matching intent lost protection proof");
  const auto mismatch = BindSnapshotToProfileIntent(parsed, std::string(64, '0'));
  expect(!mismatch.core_egress_validated && !mismatch.dns_ready &&
             !mismatch.can_connect && mismatch.failure == "profile_identity_mismatch" &&
             mismatch.effective_profile_digest == digest,
         "polling restored protection for a different desired profile");
  ServiceRuntimeSnapshot rejected;
  expect(!ParseServiceRuntimeSnapshot(snapshot(digest) + ";extra=1", &rejected),
         "trailing service field accepted");
  expect(snapshot(digest).size() <= kMaxControlBodySize,
         "snapshot exceeded bounded IPC response");
  const auto dpi_snapshot = snapshot(digest) +
      ";routing_catalog_window_version=1;smart_access_lease_version=1;"
      "routing_catalog_control_version=4;smart_access_runtime_control_version=1;"
      "transport_capabilities=none;core_module_sha256=none;core_version=1.2.9;"
      "protection_retained=0;windows_local_dpi_admission_version=1;"
      "windows_local_dpi_services=1;windows_local_dpi_admitted=0;windows_local_dpi_failed=0;"
      "windows_local_dpi_withdraw_completed=1;windows_local_dpi_local_handoffs=1;windows_local_dpi_vpn_handoffs=0;"
      "transport_proof_pending=0;transport_lease_active=0";
  ServiceRuntimeSnapshot dpi_parsed;
  expect(ParseServiceRuntimeSnapshot(dpi_snapshot, &dpi_parsed) && dpi_parsed.windows_local_dpi_runtime &&
             dpi_parsed.windows_local_dpi_runtime->withdraw_completed == 1 &&
             dpi_parsed.windows_local_dpi_runtime->vpn_handoffs == 0,
         "withdrawal with no fresh VPN handoff was not carried through the normal snapshot");
  const auto dpi_mismatch = BindSnapshotToProfileIntent(dpi_parsed, std::string(64, '0'));
  expect(!dpi_mismatch.windows_local_dpi_runtime,
         "another desired profile inherited captured-holder observations");
  auto dpi_invalid = dpi_snapshot;
  dpi_invalid.replace(dpi_invalid.find("windows_local_dpi_services=1"),
      std::string("windows_local_dpi_services=1").size(), "windows_local_dpi_services=0");
  ServiceRuntimeSnapshot dpi_rejected;
  expect(!ParseServiceRuntimeSnapshot(dpi_invalid, &dpi_rejected) && !dpi_rejected.windows_local_dpi_runtime,
         "inconsistent captured-holder state was accepted");
  for (const auto* failure : {"deadline_exceeded", "operation_cancelled", "network_context_unavailable", "connect_owner_changed",
                            "core_egress_dns_failed", "core_egress_connect_failed",
                            "core_egress_tls_failed", "core_egress_tls_timeout",
                            "core_egress_response_timeout", "core_egress_timeout",
                            "core_smart_access_lease_expired", "smart_access_profile_changed", "profile_payload_invalid",
                            "invalid_smart_access_runtime_control", "smart_access_runtime_control_unconfirmed"}) {
    const auto body =
        std::string("phase=config_staged;core_ready=1;can_initialize=1;can_connect=1;") +
        "running=0;core_egress_validated=0;dns_ready=0;staged_profile_digest=" +
        digest + ";effective_profile_digest=none;failure=" + failure;
    ServiceRuntimeSnapshot interrupted;
    expect(ParseServiceRuntimeSnapshot(body, &interrupted) &&
               interrupted.failure == failure && !interrupted.running &&
               !interrupted.core_egress_validated && interrupted.can_connect,
           "interrupted runtime response lost retry state or became incompatible");
  }
  auto private_failure = snapshot(digest);
  private_failure.replace(private_failure.find("failure=none"), std::string("failure=none").size(),
                          "failure=unknown_private_control_code");
  expect(!ParseServiceRuntimeSnapshot(private_failure, &rejected),
         "unknown private failure crossed the closed native code boundary");
  for (const auto* phase : {"connecting", "busy"}) {
    const auto pending = std::string("phase=") + phase +
        ";core_ready=1;can_initialize=0;can_connect=0;running=0;"
        "core_egress_validated=0;dns_ready=0;staged_profile_digest=" + digest +
        ";effective_profile_digest=none;failure=none";
    ServiceRuntimeSnapshot parsed_pending;
    expect(ParseServiceRuntimeSnapshot(pending, &parsed_pending) &&
               !parsed_pending.running && !parsed_pending.can_connect,
           "pending service state was rejected or advertised a concurrent connection");
  }
  const auto retained = std::string(
      "phase=config_staged;core_ready=1;can_initialize=1;can_connect=1;"
      "running=0;core_egress_validated=0;dns_ready=0;staged_profile_digest=") +
      digest + ";effective_profile_digest=none;failure=core_egress_dns_failed;"
      "routing_catalog_window_version=0;smart_access_lease_version=0;"
      "routing_catalog_control_version=0;smart_access_runtime_control_version=0;"
      "transport_capabilities=none;core_module_sha256=none;protection_retained=1;"
      "transport_proof_pending=0;transport_lease_active=0";
  ServiceRuntimeSnapshot attached;
  expect(ParseServiceRuntimeSnapshot(retained, &attached) &&
             attached.protection_retained && !attached.running &&
             attached.failure == "core_egress_dns_failed",
         "reattaching after failed handoff lost the retained native guard");
  ServiceRuntimeSnapshot versioned;
  const auto versioned_body = std::string("phase=initialized;core_ready=1;can_initialize=1;can_connect=0;") +
      "running=0;core_egress_validated=0;dns_ready=0;staged_profile_digest=none;" +
      "effective_profile_digest=none;failure=none;routing_catalog_window_version=0;" +
      "smart_access_lease_version=0;routing_catalog_control_version=0;" +
      "smart_access_runtime_control_version=0;transport_capabilities=none;" +
      "core_module_sha256=" + digest + ";core_version=1.1.1;protection_retained=0";
  expect(ParseServiceRuntimeSnapshot(versioned_body, &versioned) &&
             versioned.core_version == "1.1.1" && versioned.protection_retained_state_available &&
             !versioned.slipstream_client_ready,
         "loaded Core version or guard observation was lost");
  auto slipstream_body = versioned_body;
  const std::string slipstream_inventory = "{\"schema\":1,\"features\":[\"singbox_vless_v1\",\"slipstream_vless_v1\"]}";
  slipstream_body.replace(slipstream_body.find("transport_capabilities=none"),
      std::string("transport_capabilities=none").size(), "transport_capabilities=" + slipstream_inventory);
  slipstream_body.insert(slipstream_body.find(";protection_retained="), ";slipstream_client_ready=1");
  ServiceRuntimeSnapshot slipstream;
  expect(ParseServiceRuntimeSnapshot(slipstream_body, &slipstream) &&
             slipstream.slipstream_client_ready && slipstream.transport_capabilities_json == slipstream_inventory,
         "Slipstream readiness changed the raw compiled inventory or was lost");
  auto invalid_slipstream = slipstream_body;
  invalid_slipstream.replace(invalid_slipstream.find("slipstream_client_ready=1"),
      std::string("slipstream_client_ready=1").size(), "slipstream_client_ready=2");
  expect(!ParseServiceRuntimeSnapshot(invalid_slipstream, &slipstream),
         "malformed Slipstream readiness crossed the service boundary");
  expect(BindSnapshotToProfileIntent(versioned, digest).failure == "profile_identity_mismatch",
         "unconfirmed Start/Apply accepted a missing profile");
  auto stopped_intent = digest;
  expect(ClearStoppedProfileIntent(versioned, stopped_intent) && stopped_intent.empty(),
         "completed clean Stop kept its previous profile intent");
  const auto stopped = BindSnapshotToProfileIntent(versioned, stopped_intent);
  expect(stopped.phase == "initialized" && stopped.failure == "none" &&
             !stopped.running && !stopped.can_connect && !stopped.protection_retained,
         "clean stopped runtime inherited the previous profile identity failure");
  auto staged = versioned;
  staged.phase = "config_staged";
  staged.staged_profile_digest = std::string(64, '0');
  staged.can_connect = true;
  auto preserved_intent = digest;
  expect(!ClearStoppedProfileIntent(staged, preserved_intent) && preserved_intent == digest &&
             !ClearStoppedProfileIntent(attached, preserved_intent) && preserved_intent == digest &&
             !ClearStoppedProfileIntent(parsed, preserved_intent) && preserved_intent == digest,
         "Stop discarded an active, staged or retained profile intent");
  expect(BindSnapshotToProfileIntent(staged, digest).failure == "profile_identity_mismatch",
         "another staged profile bypassed the expected identity");
  auto explicit_stop = staged;
  explicit_stop.command_accepted = true;
  explicit_stop.trusted = true;
  explicit_stop.compatible = true;
  auto explicit_intent = digest;
  expect(ClearExplicitStopProfileIntent(explicit_stop, digest, explicit_intent) &&
             explicit_intent.empty() &&
             BindSnapshotToProfileIntent(explicit_stop, explicit_intent).failure == "none" &&
             !IsProfileDigest(explicit_intent),
         "clean explicit Stop retained an obsolete profile intent or authorised reuse");
  auto changed_intent = std::string(64, '1');
  expect(!ClearExplicitStopProfileIntent(explicit_stop, digest, changed_intent) &&
             changed_intent == std::string(64, '1'),
         "completed Stop cleared a newer profile intent");
  auto unconfirmed_stop = explicit_stop;
  unconfirmed_stop.command_accepted = false;
  auto retained_intent = digest;
  expect(!ClearExplicitStopProfileIntent(unconfirmed_stop, digest, retained_intent) &&
             retained_intent == digest,
         "unconfirmed Stop cleared the profile intent");
  auto untrusted_stop = explicit_stop;
  untrusted_stop.trusted = false;
  expect(!ClearExplicitStopProfileIntent(untrusted_stop, digest, retained_intent) &&
             retained_intent == digest,
         "untrusted Stop cleared the profile intent");
  auto guarded_stop = explicit_stop;
  guarded_stop.protection_retained = true;
  expect(!ClearExplicitStopProfileIntent(guarded_stop, digest, retained_intent) &&
             retained_intent == digest,
         "retained protection cleared the profile intent");
  auto running_stop = explicit_stop;
  running_stop.phase = "running";
  running_stop.running = true;
  expect(!ClearExplicitStopProfileIntent(running_stop, digest, retained_intent) &&
             retained_intent == digest,
         "a running connection lost its profile intent");
  auto unknown_guard = explicit_stop;
  unknown_guard.protection_retained_state_available = false;
  expect(!ClearExplicitStopProfileIntent(unknown_guard, digest, retained_intent) &&
             retained_intent == digest,
         "Stop without a retained-protection observation cleared the profile intent");
  expect(BindSnapshotToProfileIntent(attached, std::string(64, '0')).failure ==
             "profile_identity_mismatch",
         "retained protection bypassed the expected identity");
  auto invalid_version = versioned_body;
  invalid_version.replace(invalid_version.find("core_version=1.1.1"),
                          std::string("core_version=1.1.1").size(), "core_version=1..1");
  expect(!ParseServiceRuntimeSnapshot(invalid_version, &versioned),
         "malformed Core version was accepted");
#ifdef _DEBUG
  std::uint64_t request_wait_ms = 0;
  const auto delayed_control = RuntimeControlReceipt(Command::kConfigureBoundSmartAccessRuntimeControl,
      Status::kNotReady, "core_egress_connect_failed", 3500, &request_wait_ms);
  expect(request_wait_ms > 3000 && request_wait_ms <= 6000,
         "bound runtime control did not budget setup separately from its native probe");
  expect(delayed_control.trusted && delayed_control.compatible && !delayed_control.command_accepted &&
             !delayed_control.smart_access_runtime_control_configured &&
             delayed_control.status == Status::kNotReady && delayed_control.failure == "core_egress_connect_failed",
         "a delayed native rejection became service_unavailable or accepted QA proof");
  request_wait_ms = 0;
  const auto ordinary_control = RuntimeControlReceipt(Command::kConfigureSmartAccessRuntimeControl,
      Status::kOk, "configured=1", 0, &request_wait_ms);
  expect(request_wait_ms > 0 && request_wait_ms <= 3000 &&
             ordinary_control.command_accepted && ordinary_control.smart_access_runtime_control_configured,
         "ordinary runtime control lost its short IPC budget or configuration receipt");
#endif
  return failures == 0 ? 0 : 1;
}
