#include "service_client.h"
#include "service_profile_identity.h"

#include <iostream>
#include <string>

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
             !parsed.protection_retained,
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
  for (const auto* failure : {"deadline_exceeded", "operation_cancelled",
                            "core_egress_dns_failed", "core_egress_connect_failed",
                            "core_egress_tls_failed", "core_egress_tls_timeout",
                            "core_egress_response_timeout", "core_egress_timeout",
                            "core_smart_access_lease_expired"}) {
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
             versioned.core_version == "1.1.1", "loaded Core version was lost");
  auto invalid_version = versioned_body;
  invalid_version.replace(invalid_version.find("core_version=1.1.1"),
                          std::string("core_version=1.1.1").size(), "core_version=1..1");
  expect(!ParseServiceRuntimeSnapshot(invalid_version, &versioned),
         "malformed Core version was accepted");
  return failures == 0 ? 0 : 1;
}
