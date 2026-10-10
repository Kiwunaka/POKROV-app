#include "service_dispatcher.h"
#include "service_profile_identity.h"
#include "service_boot_clock.h"
#include "service_server.h"

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
  bool SupportsInterruptibleStart() const override { return true; }
  std::string StartInterruptible(const std::wstring& path, bool disabled,
      const CheckInterruption& interrupted) override {
    return interrupted() == OperationInterruption::kNone ? Start(path, disabled) : "cancelled";
  }
  std::string CoreModuleSHA256() const override { return std::string(64, 'a'); }
  int SmartAccessRuntimeControlVersion() const override { return 1; }
  int SmartAccessProbeVersion() const override { return 1; }
  int ConfigureSmartAccessRuntimeControl(const std::string&, const std::string&) override { return 1; }
  std::string ProbeSmartAccess(const std::string&, bool periodic, const CheckInterruption& interrupted) override {
    ++smart_probes;
    return periodic && interrupted && interrupted() == OperationInterruption::kNone ? "" : "cancelled";
  }
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
  std::atomic<int> starts{0}, stops{0};
  int smart_probes = 0;
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

class HealthProbe final : public RuntimeEgressProbe {
 public:
  std::string Verify(const CheckInterruption& interrupted, bool = false,
                     std::uint64_t = 0) override {
    if (++active > 1) overlapped = true;
    ++calls;
    while (mode == 1 && interrupted() == OperationInterruption::kNone) ::Sleep(1);
    const bool cancelled = interrupted && interrupted() == OperationInterruption::kCancelled;
    if (cancelled) ::Sleep(15);  // Native request teardown must be joined.
    --active;
    return cancelled ? "late failure" : mode == 2 ? "core_egress_connect_failed" : "";
  }
  std::atomic<int> mode{0}, calls{0}, active{0};
  std::atomic<bool> overlapped{false};
};

void TestPeriodicEgressLifecycle(const std::filesystem::path& root, HANDLE stop) {
  auto core = std::make_unique<ProbeCore>();
  auto* observed = core.get();
  auto probe = std::make_unique<HealthProbe>();
  auto* health = probe.get();
  RuntimeHost runtime(std::move(core), std::move(probe), std::make_unique<Recovery>(),
      root.wstring(), false);
  auto dispatcher = std::make_unique<RuntimeDispatcher>(&runtime,
      std::function<std::optional<CandidateNetworkContext>()>{},
      std::function<bool(std::uint64_t)>{}, 10);
  const auto call = [&](Command command, const std::string& body = "") {
    Frame request{};
    request.command = command;
    request.body = body;
    return dispatcher->Execute(request, stop, ::GetTickCount64() + 5000, nullptr);
  };
  const auto wait_for = [&](const auto& ready) {
    const auto deadline = ::GetTickCount64() + 2000;
    while (!ready() && ::GetTickCount64() < deadline) ::Sleep(1);
    Expect(ready(), "periodic egress lifecycle did not settle");
  };
  const std::string profile = "0\n{}";
  Expect(call(Command::kStageProfile, profile).status == Status::kOk &&
             call(Command::kConnect, ProfileDigest(profile)).status == Status::kOk,
         "periodic egress fixture could not connect");
  health->mode = 1;
  wait_for([&] { return health->calls == 2; });
  Expect(call(Command::kStatus).body.find("core_egress_validated=1") != std::string::npos &&
             health->active == 1 && observed->stops == 0,
         "periodic check blocked status, overlapped, or stopped the TUN");
  const auto stop_started = ::GetTickCount64();
  Expect(call(Command::kDisconnect).status == Status::kOk &&
             ::GetTickCount64() - stop_started < 500 && health->active == 0 &&
             observed->stops == 1,
         "disconnect did not promptly cancel and join the periodic probe");
  ::Sleep(250);
  Expect(health->calls == 2 &&
             call(Command::kStatus).body.find("phase=config_staged;") == 0,
         "periodic check survived explicit disconnect");

  health->mode = 0;
  Expect(call(Command::kConnect, ProfileDigest(profile)).status == Status::kOk,
         "new connection inherited cancelled health state");
  health->mode = 2;
  wait_for([&] {
    return call(Command::kStatus).body.find("failure=core_egress_connect_failed") != std::string::npos;
  });
  const auto failed = call(Command::kStatus);
  Expect(failed.body.find("phase=running;") == 0 &&
             failed.body.find("core_egress_validated=0;dns_ready=0") != std::string::npos &&
             observed->stops == 1,
         "periodic failure lost TUN ownership or retained cached green health");
  const auto failed_calls = health->calls.load();
  wait_for([&] { return health->calls >= failed_calls + 2; });
  const auto retrying = call(Command::kStatus);
  Expect(retrying.body.find("phase=running;") == 0 &&
             retrying.body.find("core_egress_validated=0;dns_ready=0") != std::string::npos &&
             health->active <= 1 && !health->overlapped &&
             observed->starts == 2 && observed->stops == 1,
         "failed health did not retry sequentially while retaining the TUN");

  health->mode = 0;
  wait_for([&] {
    const auto recovered = call(Command::kStatus);
    return recovered.body.find("core_egress_validated=1;dns_ready=1") != std::string::npos &&
        recovered.body.find("failure=none;") != std::string::npos;
  });
  Expect(observed->starts == 2 && observed->stops == 1 && !health->overlapped,
         "successful health retry reconnected instead of recovering the current TUN");

  Expect(call(Command::kDisconnect).status == Status::kOk, "failed health could not disconnect");
  health->mode = 0;
  Expect(call(Command::kConnect, ProfileDigest(profile)).status == Status::kOk,
         "healthy successor did not replace failed health");
  const auto successor_calls = health->calls.load();
  health->mode = 1;
  wait_for([&] { return health->calls > successor_calls && health->active == 1; });
  const auto close_started = ::GetTickCount64();
  dispatcher.reset();
  Expect(::GetTickCount64() - close_started < 500 && health->active == 0 &&
             runtime.Snapshot().body.find("core_egress_validated=1") != std::string::npos,
         "shutdown failed to join health check or published its stale failure");
  runtime.Shutdown();
}

void TestPeriodicEgressDeadlineRetainsTun(const std::filesystem::path& root, HANDLE stop) {
  auto core = std::make_unique<ProbeCore>();
  auto* observed = core.get();
  auto probe = std::make_unique<HealthProbe>();
  auto* health = probe.get();
  RuntimeHost runtime(std::move(core), std::move(probe), std::make_unique<Recovery>(),
      root.wstring(), false);
  RuntimeDispatcher dispatcher(&runtime);
  const auto call = [&](Command command, const std::string& body = "") {
    Frame request{};
    request.command = command;
    request.body = body;
    return dispatcher.Execute(request, stop, ::GetTickCount64() + 5000, nullptr);
  };
  const std::string profile = "0\n{}";
  Expect(call(Command::kStageProfile, profile).status == Status::kOk &&
             call(Command::kConnect, ProfileDigest(profile)).status == Status::kOk,
         "deadline fixture could not connect");
  const auto started = ::GetTickCount64();
  health->mode = 1;
  RuntimeResult result;
  do {
    ::Sleep(10);
    result = call(Command::kStatus);
  } while (result.body.find("failure=core_egress_timeout") == std::string::npos &&
           ::GetTickCount64() - started < 5600);
  Expect(result.body.find("phase=running;") == 0 &&
             result.body.find("failure=core_egress_timeout") != std::string::npos &&
             result.body.find("core_egress_validated=0;dns_ready=0") != std::string::npos &&
             health->active == 0 && health->calls == 2 && observed->stops == 0,
         "periodic deadline exceeded detection budget, overlapped, or released the TUN");
  Expect(call(Command::kDisconnect).status == Status::kOk,
         "timed-out periodic probe could not disconnect");
}

void TestBoundSmartAccessStartupHandoff(const std::filesystem::path& root, HANDLE stop) {
  auto core = std::make_unique<ProbeCore>();
  auto* observed = core.get();
  auto probe = std::make_unique<HealthProbe>();
  auto* health = probe.get();
  RuntimeHost runtime(std::move(core), std::move(probe), std::make_unique<Recovery>(), root.wstring(), false);
  RuntimeDispatcher dispatcher(&runtime, {}, {}, 10);
  // A real local pipe supplies the kernel-owned client PID; no production Core or network mutation.
  const auto name = std::wstring(kTestPipePrefix) + L"SmartHandoff." + std::to_wstring(::GetCurrentProcessId());
  const HANDLE pipe = ::CreateNamedPipeW(name.c_str(), PIPE_ACCESS_DUPLEX, PIPE_TYPE_MESSAGE | PIPE_READMODE_MESSAGE,
      1, 4096, 4096, 0, nullptr);
  const HANDLE client = ::CreateFileW(name.c_str(), GENERIC_READ | GENERIC_WRITE, 0, nullptr, OPEN_EXISTING, 0, nullptr);
  if (pipe == INVALID_HANDLE_VALUE || client == INVALID_HANDLE_VALUE) {
    Expect(false, "bound Smart fixture could not create its local owner pipe");
    if (client != INVALID_HANDLE_VALUE) ::CloseHandle(client);
    if (pipe != INVALID_HANDLE_VALUE) ::CloseHandle(pipe);
    return;
  }
  const bool connected_pipe = ::ConnectNamedPipe(pipe, nullptr) || ::GetLastError() == ERROR_PIPE_CONNECTED;
  Expect(connected_pipe, "bound Smart fixture owner pipe was not connected");
  const auto call = [&](Command command, const std::string& body = "", unsigned nonce = 1) {
    Frame request{};
    request.command = command; request.body = body;
    request.session_token[0] = 1; request.operation_nonce[0] = static_cast<std::uint8_t>(nonce);
    return dispatcher.Execute(request, stop, ::GetTickCount64() + 5000, pipe);
  };
  const std::string profile = R"(0
{"inbounds":[{"type":"tun"}],"outbounds":[{"type":"direct","tag":"direct"},{"type":"vless","tag":"vpn"},
 {"type":"pokrov-smart-access","tag":"pokrov-smart-access-00000000000000000000000000000000","lease_id":"00000000000000000000000000000000",
  "domains":[{"name":"service.example","match":"exact"}],"relay_addresses":["203.0.113.1"]}],
 "route":{"final":"direct","rules":[{"domain":["api.pokrov.space"],"network":"tcp","port":[443],"action":"route","outbound":"vpn"},
  {"domain":["service.example"],"network":"tcp","port":[443],"ip_version":4,"action":"route","outbound":"pokrov-smart-access-00000000000000000000000000000000",
   "pokrov_catalog_window":{"issued_at":"2026-10-05T10:00:00Z","expires_at":"2099-01-01T00:00:00Z","service_id":"owned-service",
    "lease_id":"00000000000000000000000000000000","lease_group":["00000000000000000000000000000000"]}}]},
 "dns":{"servers":[{"tag":"dns-vpn","detour":"vpn"},{"tag":"pokrov-smart-access-dns-00000000000000000000000000000000","address":"https://resolver.example/dns-query","detour":"direct"}],
  "rules":[{"domain":["api.pokrov.space"],"action":"route","server":"dns-vpn","disable_cache":true,"rewrite_ttl":0},
   {"domain":["service.example"],"query_type":["A"],"action":"route","server":"pokrov-smart-access-dns-00000000000000000000000000000000","disable_cache":true,"rewrite_ttl":0,
    "pokrov_catalog_window":{"issued_at":"2026-10-05T10:00:00Z","expires_at":"2099-01-01T00:00:00Z","service_id":"owned-service",
     "lease_id":"00000000000000000000000000000000","lease_group":["00000000000000000000000000000000"]}}]}})";
  Expect(call(Command::kStageProfile, profile).status == Status::kOk, "bound Smart fixture could not stage");
  const auto clock = ReadBootClock();
  const auto network = call(Command::kReadTransportNetworkContext);
  if (!clock || network.status != Status::kOk) {
    Expect(clock.has_value(), "bound Smart fixture requires the privileged service boot clock");
    Expect(network.status == Status::kOk, "bound Smart fixture requires an available physical network context");
    ::CloseHandle(client); ::CloseHandle(pipe);
    return;
  }
  const auto digest = ProfileDigest(profile);
  const BoundConnectTarget identity{std::string(64, 'a'), digest, clock->boot_ref,
      clock->elapsed_ms, clock->elapsed_ms + 800, network.body};
  const auto connected = call(Command::kConnectWithIdentity, EncodeBoundConnect(identity));
  Expect(connected.status == Status::kOk && connected.body.find("core_egress_validated=1;dns_ready=1") != std::string::npos &&
      connected.body.find("transport_proof_pending=0;transport_lease_active=0") != std::string::npos,
      "ordinary bound Smart start was masked as an unproven ATS lease");
  Identifier session{}, nonce{}; session[0] = 1; nonce[0] = 1;
  const auto owner = EncodeCancellationTarget({session, nonce});
  const auto config = digest + "|{\"platform\":\"windows\",\"capability\":\"saqa1.fixture." + std::string(64, 'a') + "\"}";
  const auto configured = call(Command::kConfigureBoundSmartAccessRuntimeControl, owner + "|" + config);
  Expect(configured.status == Status::kOk && configured.body == "configured=1" && observed->smart_probes == 1,
      "bound Smart control did not join one native probe");
  while (ReadBootClock()->elapsed_ms < identity.deadline_elapsed_ms + 150) ::Sleep(1);
  const auto running = call(Command::kStatus);
  Expect(running.status == Status::kOk && running.body.find("phase=running;") == 0 &&
      observed->stops == 0 && health->calls > 1,
      "handed-off ordinary owner expired at startup deadline or lost periodic VPN checks");
  Expect(call(Command::kConfigureBoundSmartAccessRuntimeControl, owner + "|" + config).body == "configured=1" &&
      observed->smart_probes == 1, "same native owner reprobed after its startup handoff");
  nonce[0] = 2;
  Expect(call(Command::kConfigureBoundSmartAccessRuntimeControl,
      EncodeCancellationTarget({session, nonce}) + "|" + config).body == "connect_owner_changed",
      "foreign owner crossed the configured Smart fence");
  Expect(call(Command::kCancelConnectAndConfirm, owner).body == "settled=1" && observed->stops == 1,
      "exact stop did not settle the handed-off ordinary native owner");
  ::CloseHandle(client); ::CloseHandle(pipe);
}
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
          return CandidateNetworkContext{{1, reference}, "selection_fixture", "physical-fixture", "ethernet", false};
        }, [&](std::uint64_t revision) { return revision == 1 && current.load(); });
    Frame network_frame{};
    network_frame.command = Command::kReadCandidateNetwork;
    Expect(dispatcher.Execute(network_frame, stop, ::GetTickCount64() + 1000, nullptr).body ==
               "selection_fixture;" + reference + ";ethernet;0",
           "candidate network class and IPv6 capability were not serialized");
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
  TestPeriodicEgressLifecycle(root / "periodic", stop);
  TestPeriodicEgressDeadlineRetainsTun(root / "periodic-deadline", stop);
  TestBoundSmartAccessStartupHandoff(root / "bound-smart", stop);
  ::CloseHandle(stop);
  std::filesystem::remove_all(root);
  return failures == 0 ? 0 : 1;
}
