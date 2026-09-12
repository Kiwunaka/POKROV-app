#include <windows.h>
#include <iostream>
#include <string>
#include <vector>
#include "service_client.h"

static const std::vector<std::string> kCanaries = {
  "r126b-20260912-credential",
  "{\"r126b-20260912-config\":\"synthetic\"}",
  "https://r126b-20260912.invalid/private?token=r126b-20260912-token",
  "203.0.113.198",
  "C:\\r126b-20260912-private\\customer.txt",
  "r126b-20260912-person@example.invalid"
};
static bool ContainsCanary(const std::string& value) {
  for (const auto& canary : kCanaries) if (value.find(canary) != std::string::npos) return true;
  return value.find("r126b-20260912") != std::string::npos;
}
static std::string JsonString(const std::string& value) {
  std::string result = "\"";
  for (char c : value) {
    if (c == '"' || c == '\\') result += '\\';
    result += c;
  }
  return result + "\"";
}
int main(int argc, char** argv) {
  using namespace pokrov::service;
  if (argc != 2 || std::string(argv[1]).size() != 1 || argv[1][0] < '0' || argv[1][0] > '5') return 64;
  const int index = argv[1][0] - '0';
  const auto before = InvokeInstalledService(Command::kStatus, "");
  if (!before.trusted || !before.compatible || before.running) return 65;
  // The unknown outbound type fails Core parsing before an outbound can be constructed.
  const std::string body = "0\n{\"outbounds\":[{\"type\":" + JsonString(kCanaries[index]) + "}]}";
  const auto staged = InvokeInstalledService(Command::kStageProfile, body);
  if (!staged.trusted || !staged.compatible || !staged.command_accepted || staged.staged_profile_digest.empty()) return 66;
  const auto started = ::GetTickCount64();
  const auto result = InvokeInstalledService(Command::kConnect, staged.staged_profile_digest);
  const bool leak = ContainsCanary(result.failure) || ContainsCanary(result.phase);
  const bool failed_closed = !result.command_accepted && result.failure == "core_start_failed" && !result.running && result.phase == "config_staged";
  std::cout << std::boolalpha << "{\"canary_index\":" << index
    << ",\"stage_accepted\":" << staged.command_accepted
    << ",\"core_failed_closed\":" << failed_closed
    << ",\"core_start_failed\":" << (result.failure == "core_start_failed")
    << ",\"phase_config_staged\":" << (result.phase == "config_staged")
    << ",\"response_contains_canary\":" << leak
    << ",\"trusted\":" << result.trusted << ",\"compatible\":" << result.compatible
    << ",\"running\":" << result.running << ",\"elapsed_ms\":" << (::GetTickCount64()-started) << "}\n";
  return result.trusted && result.compatible && failed_closed && !leak ? 0 : 1;
}
