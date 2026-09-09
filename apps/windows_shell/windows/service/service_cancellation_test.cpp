#include <windows.h>

#include <atomic>
#include <cstring>
#include <iostream>
#include <thread>
#include <vector>

#include "service_pipe_client.h"
#include "service_client.h"
#include "service_profile_identity.h"
#include "service_runtime.h"
#include "service_security.h"
#include "service_server.h"

#ifdef _DEBUG
namespace {
using namespace pokrov::service;
int failures = 0;
void Expect(bool value, const char* message) {
  if (!value) { std::cerr << message << '\n'; ++failures; }
}
Identifier NewId() {
  static std::atomic<unsigned> next{1};
  const unsigned value = next++;
  Identifier result{};
  std::memcpy(result.data(), &value, sizeof(value));
  return result;
}
std::uint64_t Now() {
  FILETIME time{};
  ::GetSystemTimeAsFileTime(&time);
  ULARGE_INTEGER ticks{};
  ticks.LowPart = time.dwLowDateTime;
  ticks.HighPart = time.dwHighDateTime;
  return (ticks.QuadPart - 116444736000000000ULL) / 10000ULL;
}
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
class Session {
 public:
  explicit Session(const std::wstring& name) {
    const auto deadline = ::GetTickCount64() + 3000;
    do {
      pipe = OpenNamedPipeClient(name.c_str(), 100);
      if (pipe != INVALID_HANDLE_VALUE) break;
      ::Sleep(10);
    } while (::GetTickCount64() < deadline);
    if (pipe == INVALID_HANDLE_VALUE) return;
    Send({FrameKind::kHelloRequest, Command::kHello, Status::kNone, NewId(), {}, {}, 0,
          kCapabilityProtocolV1 | kCapabilityStatus | kCapabilityRuntimeControl |
              kCapabilityProfileIdentity | kCapabilityCancellation, ""});
    const auto hello = Read();
    if (hello) token = hello->session_token;
  }
  ~Session() { if (pipe != INVALID_HANDLE_VALUE) ::CloseHandle(pipe); }
  Frame Request(Command command, const std::string& body = "") {
    return {FrameKind::kRequest, command, Status::kNone, NewId(), token, NewId(), Now() + 10000, 0, body};
  }
  bool Send(const Frame& frame) {
    auto bytes = Encode(frame);
    return !bytes.empty() && Transfer(pipe, bytes.data(), bytes.size(), true);
  }
  std::optional<Frame> Read() {
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
  std::optional<Frame> Call(Command command, const std::string& body = "") {
    return Send(Request(command, body)) ? Read() : std::nullopt;
  }
  HANDLE pipe = INVALID_HANDLE_VALUE;
  Identifier token{};
};
bool Has(const std::optional<Frame>& frame, Status status, const char* body = "") {
  return frame && frame->status == status && frame->body.find(body) != std::string::npos;
}
class FakeCore final : public CoreRuntime {
 public:
  std::string Initialize(const RuntimeDirectories&) override { return ""; }
  std::string SecureFile(const std::wstring&) override { return ""; }
  std::string Start(const std::wstring&, bool) override { ++starts; return ""; }
  std::string Stop() override { ++stops; return ""; }
  std::atomic<int> starts{0}, stops{0};
};
class BlockingProbe final : public RuntimeEgressProbe {
 public:
  std::string Verify(const CheckInterruption& interrupted) override {
    const auto generation = ++entered;
    const auto deadline = ::GetTickCount64() + 5000;
    while (released < generation && ::GetTickCount64() < deadline) {
      if (!ignore_interruption && interrupted &&
          interrupted() != OperationInterruption::kNone) return "cancelled";
      ::Sleep(1);
    }
    return released >= generation ? "" : "fixture_timeout";
  }
  void WaitFor(int generation) {
    const auto deadline = ::GetTickCount64() + 3000;
    while (entered < generation && ::GetTickCount64() < deadline) ::Sleep(1);
    Expect(entered == generation, "Connect never reached the controlled probe");
  }
  std::atomic<int> entered{0}, released{0};
  std::atomic<bool> ignore_interruption{false};
};
class FakeRecovery final : public RuntimeRecovery {
 public:
  bool RequiresRecovery() const override { return false; }
  const char* StageName() const override { return "fixture"; }
  std::string Begin() override { return ""; }
  std::string Record(RecoveryStage) override { return ""; }
  std::string BeginRollback() override { return ""; }
  std::string RestoreNetworkState() override { ++restores; return ""; }
  std::string CompleteRollback() override { return ""; }
  std::atomic<int> restores{0};
};
class CommitBarrier final : public ServiceEventSink {
 public:
  bool Record(ServiceEvent event, ServiceEventOutcome outcome) override {
    if (pause && event == ServiceEvent::kRuntimeCommit && outcome == ServiceEventOutcome::kSucceeded) {
      entered = true;
      const auto deadline = ::GetTickCount64() + 5000;
      while (!resume && ::GetTickCount64() < deadline) ::Sleep(1);
    }
    return true;
  }
  bool RecordSystemBoot(std::uint64_t) override { return true; }
  bool RecordIpcRequest(Command, const Identifier&) override { return true; }
  bool RecordIpcResponse(Command, Status, const Identifier&) override { return true; }
  std::atomic<bool> pause{false}, entered{false}, resume{false};
};
}  // namespace
#endif

int main() {
#ifdef _DEBUG
  using namespace pokrov::service;
  wchar_t temporary[MAX_PATH]{}, root_path[MAX_PATH]{};
  if (!::GetTempPathW(MAX_PATH, temporary) ||
      !::GetTempFileNameW(temporary, L"pkc", 0, root_path)) return 1;
  ::DeleteFileW(root_path);
  if (!::CreateDirectoryW(root_path, nullptr)) return 1;
  const std::wstring root(root_path);
  const auto pipe = std::wstring(kTestPipePrefix) + L"Cancellation." + std::to_wstring(::GetCurrentProcessId());
  const HANDLE stop = ::CreateEventW(nullptr, TRUE, FALSE, nullptr);
  auto core = std::make_unique<FakeCore>();
  auto* core_state = core.get();
  auto probe = std::make_unique<BlockingProbe>();
  auto* probe_state = probe.get();
  auto recovery = std::make_unique<FakeRecovery>();
  auto* recovery_state = recovery.get();
  {
    CommitBarrier commit;
    RuntimeHost runtime(std::move(core), std::move(probe), std::move(recovery), root, false, &commit);
    DWORD server_result = ERROR_INVALID_DATA;
    std::thread server([&] { server_result = RunPipeServerForTest(pipe, CurrentProcessUserSid(), stop, &runtime); });
    {
      Session first(pipe), control(pipe);
      Expect(!IsZeroIdentifier(first.token) && !IsZeroIdentifier(control.token), "IPC hello failed");
      const std::string profile = "0\n{\"inbounds\":[{\"type\":\"tun\"}]}";
      Expect(Has(control.Call(Command::kInitialize), Status::kOk), "IPC initialize failed");
      Expect(Has(control.Call(Command::kStageProfile, profile), Status::kOk), "IPC stage failed");
      const auto connect = first.Request(Command::kConnect, ProfileDigest(profile));
      Expect(first.Send(connect), "first connect was not sent");
      probe_state->WaitFor(1);
      Expect(Has(control.Call(Command::kStatus), Status::kOk, "phase=connecting"),
             "status blocked behind Connect or did not expose pending state");
      Expect(Has(control.Call(Command::kStageProfile, profile), Status::kNotReady, "runtime_busy"),
             "concurrent mutation crossed the runtime owner");
      const auto wrong_target = EncodeCancellationTarget({first.token, NewId()});
      Expect(Has(control.Call(Command::kCancel, wrong_target), Status::kNotReady, "operation_not_active"),
             "foreign operation nonce cancelled the active connection");
      Expect(Has(control.Call(Command::kCancel,
                 EncodeCancellationTarget({control.token, connect.operation_nonce})),
                 Status::kNotReady, "operation_not_active"),
             "foreign session token cancelled the active connection");
      const auto target = EncodeCancellationTarget({first.token, connect.operation_nonce});
      const auto cancel = control.Request(Command::kCancel, target);
      const auto start = ::GetTickCount64();
      Expect(control.Send(cancel) && Has(control.Read(), Status::kOk, "cancellation_requested"),
             "valid correlated cancellation was not accepted");
      Expect(Has(first.Read(), Status::kNotReady, "operation_cancelled"),
             "cancelled Connect published success");
      std::cout << "ipc_cancel_rollback_ms=" << ::GetTickCount64() - start << '\n';
      Expect(core_state->starts == 1 && core_state->stops == 1 && recovery_state->restores == 1,
             "cancellation did not serialize one Core stop and network restore");
      Expect(control.Send(cancel) && Has(control.Read(), Status::kReplay), "cancel replay was accepted");
      const auto next = first.Request(Command::kConnect, ProfileDigest(profile));
      Expect(first.Send(next), "second connect was not sent");
      probe_state->WaitFor(2);
      Expect(Has(control.Call(Command::kCancel, target), Status::kNotReady, "operation_not_active"),
             "late cancellation reached the next connection generation");
      Expect(Has(control.Call(Command::kDisconnect), Status::kNotReady, "runtime_busy"),
             "concurrent disconnect raced the pending connection");
      probe_state->released = 2;
      Expect(Has(first.Read(), Status::kOk, "phase=running"), "fresh operation did not survive stale cancellation");
      Expect(Has(control.Call(Command::kDisconnect), Status::kOk, "phase=config_staged"),
             "final network rollback failed");
      Expect(core_state->stops == 2 && recovery_state->restores == 2, "final runtime ownership counts differ");
      // Cancel after RuntimeHost's final cooperative check, while its commit
      // event is being recorded. Dispatcher completion must still fence it.
      commit.pause = true;
      probe_state->released = 3;
      const auto committed_connect = first.Request(Command::kConnect, ProfileDigest(profile));
      Expect(first.Send(committed_connect), "commit-race connect was not sent");
      const auto barrier_deadline = ::GetTickCount64() + 3000;
      while (!commit.entered && ::GetTickCount64() < barrier_deadline) ::Sleep(1);
      Expect(commit.entered, "runtime did not reach post-commit barrier");
      Expect(Has(control.Call(Command::kCancel,
                 EncodeCancellationTarget({first.token, committed_connect.operation_nonce})),
                 Status::kOk, "cancellation_requested"), "post-commit cancellation was not accepted");
      commit.resume = true;
      Expect(Has(first.Read(), Status::kNotReady, "operation_cancelled"),
             "completion race published success after acknowledging cancellation");
      Expect(core_state->stops == 3 && recovery_state->restores == 3,
             "post-commit cancellation did not roll back the network owner");
      ServiceCallControl automatic;
      ServiceRuntimeSnapshot automatic_result;
      std::thread native_client([&] {
        automatic_result = InvokeServiceForTest(pipe, Command::kConnect,
                                                ProfileDigest(profile), &automatic);
      });
      probe_state->WaitFor(4);
      automatic.cancel_requested = true;
      native_client.join();
      Expect(!automatic_result.command_accepted && automatic_result.compatible &&
                 automatic_result.failure == "operation_cancelled" &&
                 core_state->stops == 4 && recovery_state->restores == 4,
             "native client's cancellation monitor did not complete correlated rollback");

      probe_state->ignore_interruption = true;
      ServiceCallControl closing;
      std::thread closing_client([&] {
        InvokeServiceForTest(pipe, Command::kConnect, ProfileDigest(profile), &closing);
      });
      probe_state->WaitFor(5);
      const auto close_started = ::GetTickCount64();
      closing.cancel_requested = true;
      closing.abandon_wait = true;
      closing_client.join();
      Expect(::GetTickCount64() - close_started < 1500,
             "native shutdown waited for a blocking remote operation");
      probe_state->released = 5;
      const auto rollback_deadline = ::GetTickCount64() + 3000;
      while (core_state->stops < 5 && ::GetTickCount64() < rollback_deadline) ::Sleep(1);
      Expect(core_state->stops == 5, "abandoned wait failed to request remote cancellation");
    }
    ::SetEvent(stop);
    server.join();
    Expect(server_result == ERROR_SUCCESS, "IPC server did not shut down cleanly");
  }
  ::CloseHandle(stop);
  ::DeleteFileW((root + L"\\working\\configs\\managed-profile.json").c_str());
  for (const auto* suffix : {L"\\working\\configs", L"\\working\\data", L"\\working", L"\\data", L"\\temp", L""}) {
    ::RemoveDirectoryW((root + suffix).c_str());
  }
  return failures == 0 ? 0 : 1;
#else
  return 1;
#endif
}
