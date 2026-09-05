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
             parsed.running && parsed.effective_profile_digest == digest,
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
  return failures == 0 ? 0 : 1;
}
