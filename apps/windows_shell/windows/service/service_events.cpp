#include "service_events.h"

#include <windows.h>

#include <array>
#include <atomic>
#include <condition_variable>
#include <cstdint>
#include <cstdio>
#include <deque>
#include <mutex>
#include <string>
#include <thread>

namespace pokrov::service {
namespace {

constexpr char kJournalMagic[] = "POKROV_SERVICE_EVENT_V1";
constexpr char kCoreEventJournalMagic[] = "POKROV_CORE_EVENT_V1";

std::wstring AppendPath(const std::wstring& base, const wchar_t* child) {
  if (base.empty()) {
    return L"";
  }
  return base + (base.back() == L'\\' ? L"" : L"\\") + child;
}

const char* EventName(ServiceEvent event) {
  switch (event) {
    case ServiceEvent::kServiceStartPending:
      return "service_start_pending";
    case ServiceEvent::kServiceBootObserved:
      return "service_boot_observed";
    case ServiceEvent::kServiceRunning:
      return "service_running";
    case ServiceEvent::kServiceStopRequested:
      return "service_stop_requested";
    case ServiceEvent::kServiceShutdownRequested:
      return "service_shutdown_requested";
    case ServiceEvent::kServicePreShutdownRequested:
      return "service_preshutdown_requested";
    case ServiceEvent::kServicePowerSuspend:
      return "service_power_suspend";
    case ServiceEvent::kServicePowerResume:
      return "service_power_resume";
    case ServiceEvent::kServiceStopped:
      return "service_stopped";
    case ServiceEvent::kIpcSessionAccepted:
      return "ipc_session_accepted";
    case ServiceEvent::kIpcSessionRejected:
      return "ipc_session_rejected";
    case ServiceEvent::kIpcSessionClosed:
      return "ipc_session_closed";
    case ServiceEvent::kRuntimeInitialize:
      return "runtime_initialize";
    case ServiceEvent::kRuntimeProfileStage:
      return "runtime_profile_stage";
    case ServiceEvent::kRuntimeNetworkSnapshot:
      return "runtime_network_snapshot";
    case ServiceEvent::kRuntimeCoreStart:
      return "runtime_core_start";
    case ServiceEvent::kRuntimeWintunStart:
      return "runtime_wintun_start";
    case ServiceEvent::kRuntimeAdapterApply:
      return "runtime_adapter_apply";
    case ServiceEvent::kRuntimeRouteApply:
      return "runtime_route_apply";
    case ServiceEvent::kRuntimeDnsApply:
      return "runtime_dns_apply";
    case ServiceEvent::kRuntimeEgressVerify:
      return "runtime_egress_verify";
    case ServiceEvent::kRuntimeCommit:
      return "runtime_commit";
    case ServiceEvent::kRuntimeRollbackBegin:
      return "runtime_rollback_begin";
    case ServiceEvent::kRuntimeCoreStop:
      return "runtime_core_stop";
    case ServiceEvent::kRuntimeNetworkRestore:
      return "runtime_network_restore";
    case ServiceEvent::kRuntimeRollbackComplete:
      return "runtime_rollback_complete";
    case ServiceEvent::kRuntimeRecoveryRequired:
      return "runtime_recovery_required";
  }
  return "closed_event_invalid";
}

const char* OutcomeName(ServiceEventOutcome outcome) {
  switch (outcome) {
    case ServiceEventOutcome::kAttempted:
      return "attempted";
    case ServiceEventOutcome::kSucceeded:
      return "succeeded";
    case ServiceEventOutcome::kFailed:
      return "failed";
    case ServiceEventOutcome::kAccepted:
      return "accepted";
    case ServiceEventOutcome::kRejected:
      return "rejected";
  }
  return "invalid";
}

const char* CommandName(Command command) {
  switch (command) {
    case Command::kHello:
      return "hello";
    case Command::kStatus:
      return "status";
    case Command::kConnect:
      return "connect";
    case Command::kDisconnect:
      return "disconnect";
    case Command::kCancel:
      return "cancel";
    case Command::kRecover:
      return "recover";
    case Command::kDiagnosticState:
      return "diagnostic_state";
    case Command::kInitialize:
      return "initialize";
    case Command::kStageProfile:
      return "stage_profile";
    case Command::kInvalidateProfile:
      return "invalidate_profile";
  }
  return "invalid";
}

const char* StatusName(Status status) {
  switch (status) {
    case Status::kNone:
      return "none";
    case Status::kOk:
      return "ok";
    case Status::kInvalid:
      return "invalid";
    case Status::kUnauthorized:
      return "unauthorized";
    case Status::kUnsupported:
      return "unsupported";
    case Status::kNotReady:
      return "not_ready";
    case Status::kReplay:
      return "replay";
    case Status::kDeadlineExceeded:
      return "deadline_exceeded";
  }
  return "invalid";
}

std::string CorrelationHex(const Identifier& correlation_id) {
  constexpr char kHex[] = "0123456789abcdef";
  std::string encoded(correlation_id.size() * 2, '0');
  for (std::size_t index = 0; index < correlation_id.size(); ++index) {
    encoded[index * 2] = kHex[correlation_id[index] >> 4];
    encoded[index * 2 + 1] = kHex[correlation_id[index] & 0x0f];
  }
  return encoded;
}

std::string BootEpochId(std::uint64_t boot_epoch_filetime_ticks) {
  char encoded[17]{};
  const int written = std::snprintf(
      encoded, sizeof(encoded), "%016llx",
      static_cast<unsigned long long>(boot_epoch_filetime_ticks));
  return written == 16 ? std::string("boot-") + encoded : "boot-invalid";
}

std::uint64_t FileTimeTicks() {
  FILETIME file_time{};
  ::GetSystemTimeAsFileTime(&file_time);
  ULARGE_INTEGER ticks{};
  ticks.LowPart = file_time.dwLowDateTime;
  ticks.HighPart = file_time.dwHighDateTime;
  return ticks.QuadPart;
}

class DurableServiceEventJournal final : public ServiceEventSink {
 public:
  explicit DurableServiceEventJournal(const std::wstring& runtime_root)
      : current_path_(AppendPath(runtime_root, kServiceEventJournalName)),
        previous_path_(
            AppendPath(runtime_root, kPreviousServiceEventJournalName)),
        sequence_(::GetTickCount64()) {
    if (valid()) {
      writer_ = std::thread(&DurableServiceEventJournal::WritePending, this);
    }
  }

  ~DurableServiceEventJournal() override {
    {
      std::lock_guard<std::mutex> guard(lock_);
      stopping_ = true;
    }
    ready_.notify_one();
    if (writer_.joinable()) {
      writer_.join();
    }
  }

  bool valid() const {
    return !current_path_.empty() && !previous_path_.empty();
  }

  bool Record(ServiceEvent event, ServiceEventOutcome outcome) override {
    return Append(EventName(event), OutcomeName(outcome), "none", "none",
                  "none");
  }

  bool RecordSystemBoot(std::uint64_t boot_epoch_filetime_ticks) override {
    return Append(EventName(ServiceEvent::kServiceBootObserved), "succeeded",
                  "none", "none", BootEpochId(boot_epoch_filetime_ticks));
  }

  bool RecordIpcRequest(Command command,
                        const Identifier& correlation_id) override {
    return Append("ipc_request", "attempted", CommandName(command), "none",
                  CorrelationHex(correlation_id));
  }

  bool RecordIpcResponse(Command command, Status status,
                         const Identifier& correlation_id) override {
    return Append("ipc_response", status == Status::kOk ? "succeeded" : "failed",
                  CommandName(command), StatusName(status),
                  CorrelationHex(correlation_id));
  }

  bool RecordCoreOperationalEvent(
      const CoreOperationalEventRecord& event) override {
    const auto line = std::string(kCoreEventJournalMagic) + "|" +
                      std::to_string(event.schema_version) + "|" +
                      std::to_string(event.event_abi) + "|" +
                      event.occurred_at_utc + "|" + event.run_id + "|" +
                      event.attempt_id + "|" +
                      std::to_string(event.generation) + "|" +
                      std::to_string(event.sequence) + "|" + event.name +
                      "|" + event.subsystem + "|" + event.stage + "|" +
                      event.severity + "|" + event.outcome + "|" +
                      (event.error_code.empty() ? "none" : event.error_code) +
                      "|" + event.phase + "\n";
    return AppendLine(line);
  }

 private:
  bool Append(const char* event, const char* outcome, const char* command,
              const char* status, const std::string& correlation) {
    const auto line = std::string(kJournalMagic) + "|" +
                      std::to_string(FileTimeTicks()) + "|" +
                      std::to_string(sequence_.fetch_add(1) + 1) + "|" + event + "|" +
                      outcome + "|" + command + "|" + status + "|" +
                      correlation + "\n";
    return AppendLine(line);
  }

  bool AppendLine(const std::string& line) {
    if (line.size() > 512) {
      return false;
    }
    std::lock_guard<std::mutex> guard(lock_);
    if (stopping_ || pending_.size() >= kMaximumPendingServiceEvents) {
      return false;
    }
    pending_.push_back(line);
    ready_.notify_one();
    return true;
  }

  bool WriteLine(const std::string& line) {
    if (!RotateIfNeeded(line.size())) {
      return false;
    }
    HANDLE file = ::CreateFileW(
        current_path_.c_str(), FILE_APPEND_DATA,
        FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, nullptr,
        OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (file == INVALID_HANDLE_VALUE) {
      return false;
    }
    DWORD written = 0;
    const bool success =
        ::WriteFile(file, line.data(), static_cast<DWORD>(line.size()),
                    &written, nullptr) != FALSE &&
        written == line.size() && ::FlushFileBuffers(file) != FALSE;
    ::CloseHandle(file);
    return success;
  }

  void WritePending() {
    for (;;) {
      std::string line;
      {
        std::unique_lock<std::mutex> guard(lock_);
        ready_.wait(guard, [this] { return stopping_ || !pending_.empty(); });
        if (pending_.empty()) {
          if (stopping_) {
            return;
          }
          continue;
        }
        line = std::move(pending_.front());
        pending_.pop_front();
      }
      WriteLine(line);
    }
  }

  bool RotateIfNeeded(std::size_t incoming_size) {
    WIN32_FILE_ATTRIBUTE_DATA attributes{};
    if (::GetFileAttributesExW(current_path_.c_str(), GetFileExInfoStandard,
                               &attributes) == FALSE) {
      return ::GetLastError() == ERROR_FILE_NOT_FOUND;
    }
    ULARGE_INTEGER size{};
    size.LowPart = attributes.nFileSizeLow;
    size.HighPart = attributes.nFileSizeHigh;
    if (size.QuadPart + incoming_size <= kMaximumServiceEventJournalSize) {
      return true;
    }
    return ::MoveFileExW(current_path_.c_str(), previous_path_.c_str(),
                         MOVEFILE_REPLACE_EXISTING |
                             MOVEFILE_WRITE_THROUGH) != FALSE;
  }

  std::wstring current_path_;
  std::wstring previous_path_;
  std::atomic<std::uint64_t> sequence_;
  std::mutex lock_;
  std::condition_variable ready_;
  std::deque<std::string> pending_;
  bool stopping_ = false;
  std::thread writer_;
};

}  // namespace

std::unique_ptr<ServiceEventSink> CreateServiceEventJournal(
    const std::wstring& runtime_root) {
  auto journal = std::make_unique<DurableServiceEventJournal>(runtime_root);
  return journal->valid() ? std::move(journal) : nullptr;
}

}  // namespace pokrov::service
