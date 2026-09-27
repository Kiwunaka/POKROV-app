#include "service_dispatcher.h"

#include <atomic>
#include <filesystem>
#include <iostream>
#include <thread>

namespace {
using namespace pokrov::service;
int failures = 0;
void Expect(bool value, const char* message) {
  if (!value) { std::cerr << message << '\n'; ++failures; }
}
class ProbeCore final : public CoreRuntime {
 public:
  std::string Initialize(const RuntimeDirectories&) override { return ""; }
  std::string SecureFile(const std::wstring&) override { return ""; }
  std::string Start(const std::wstring&, bool) override { ++starts; return ""; }
  std::string Stop() override { ++stops; return ""; }
  std::string ProbeCandidate(const CandidateProbeRequest& request, const std::string& binding,
                              const CheckInterruption& interrupted) override {
    if (binding != "physical-fixture" || request.config != "{\"outbounds\":[]}") ++invalid;
    ++active;
    ++entered;
    while (!release && interrupted() == OperationInterruption::kNone) ::Sleep(1);
    const bool cancelled = interrupted() != OperationInterruption::kNone;
    // Model native Close/join: cancellation cannot settle before teardown.
    ::Sleep(15);
    --active;
    return cancelled ? "{\"success\":false,\"failure_kind\":\"cancelled\",\"duration_ms\":15}"
                     : "{\"success\":true,\"failure_kind\":\"\",\"duration_ms\":15}";
  }
  std::atomic<int> active{0}, entered{0}, invalid{0};
  int starts = 0, stops = 0;
  std::atomic<bool> release{false};
};
class Recovery final : public RuntimeRecovery {
 public:
  bool RequiresRecovery() const override { return false; }
  const char* StageName() const override { return "clean"; }
  std::string Begin() override { ++mutations; return ""; }
  std::string Record(RecoveryStage) override { ++mutations; return ""; }
  std::string BeginRollback() override { ++mutations; return ""; }
  std::string RestoreNetworkState() override { ++mutations; return ""; }
  std::string CompleteRollback() override { ++mutations; return ""; }
  int mutations = 0;
};
}

int main() {
  const auto root = std::filesystem::temp_directory_path() /
      ("pokrov-candidate-test-" + std::to_string(::GetCurrentProcessId()));
  auto core = std::make_unique<ProbeCore>();
  auto* observed = core.get();
  auto recovery = std::make_unique<Recovery>();
  auto* network_mutations = recovery.get();
  HANDLE stop = ::CreateEventW(nullptr, TRUE, FALSE, nullptr);
  {
    RuntimeHost runtime(std::move(core), nullptr, std::move(recovery), root.wstring(), false);
    Expect(runtime.Initialize().status == Status::kOk, "runtime initialization failed");
    const auto before = runtime.Snapshot().body;
    std::atomic<bool> current{true};
    const std::string reference = "network_" + std::string(32, 'a');
    RuntimeDispatcher dispatcher(&runtime,
        [&]() -> std::optional<CandidateNetworkContext> {
          return CandidateNetworkContext{{1, reference}, "selection_fixture", "physical-fixture"};
        }, [&](std::uint64_t revision) { return revision == 1 && current.load(); });
    std::array<Frame, 4> frames{};
    std::array<RuntimeResult, 4> results{};
    std::array<std::thread, 4> workers;
    for (std::size_t i = 0; i < workers.size(); ++i) {
      frames[i].command = Command::kProbeCandidate;
      frames[i].session_token[0] = 1;
      frames[i].operation_nonce[0] = static_cast<std::uint8_t>(i + 1);
      frames[i].body = EncodeCandidateProbe({"probe_" + std::to_string(i), 4000, reference, "{\"outbounds\":[]}"});
      workers[i] = std::thread([&, i] {
        results[i] = dispatcher.Execute(frames[i], stop, ::GetTickCount64() + 5000, nullptr);
      });
    }
    const auto deadline = ::GetTickCount64() + 2000;
    while (observed->entered < 4 && ::GetTickCount64() < deadline) ::Sleep(1);
    Expect(observed->active == 4, "candidate probes serialized or changed network ownership");
    Frame fifth = frames[0];
    fifth.body = EncodeCandidateProbe({"fifth", 4000, reference, "{\"outbounds\":[]}"});
    Expect(dispatcher.Execute(fifth, stop, ::GetTickCount64() + 1000, nullptr).body.find("unavailable") != std::string::npos,
           "service admitted more than four probes");
    Frame cancel{};
    cancel.command = Command::kCancelCandidateProbe;
    cancel.body = EncodeCancellationTarget({frames[0].session_token, frames[0].operation_nonce});
    Expect(dispatcher.Execute(cancel, stop, ::GetTickCount64() + 1000, nullptr).status == Status::kOk,
           "exact candidate cancel was rejected");
    workers[0].join();
    Expect(observed->active == 3 && results[0].body.find("cancelled") != std::string::npos,
           "candidate cancellation did not join or cancelled siblings");
    current = false;
    for (std::size_t i = 1; i < workers.size(); ++i) {
      workers[i].join();
      Expect(results[i].body.find("network_changed") != std::string::npos, "late probe proof survived network change");
    }
    current = true;
    observed->release = true;
    Expect(dispatcher.Execute(fifth, stop, ::GetTickCount64() + 1000, nullptr).body.find("\"success\":true") != std::string::npos,
           "settled probe slot could not be reused");
    Expect(observed->active == 0 && observed->starts == 0 && observed->stops == 0 && observed->invalid == 0 &&
               network_mutations->mutations == 0 && runtime.Snapshot().body == before,
           "isolated probe changed TUN state or failed to close");
  }
  ::CloseHandle(stop);
  std::filesystem::remove_all(root);
  return failures == 0 ? 0 : 1;
}
