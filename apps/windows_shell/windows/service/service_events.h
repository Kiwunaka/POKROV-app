#ifndef POKROV_SERVICE_SERVICE_EVENTS_H_
#define POKROV_SERVICE_SERVICE_EVENTS_H_

#include <cstddef>
#include <cstdint>
#include <memory>
#include <string>

#include "service_protocol.h"

namespace pokrov::service {

constexpr wchar_t kServiceEventJournalName[] = L"service-events.v1.log";
constexpr wchar_t kPreviousServiceEventJournalName[] =
    L"service-events.v1.previous.log";
constexpr std::size_t kMaximumServiceEventJournalSize = 256 * 1024;
constexpr std::size_t kMaximumPendingServiceEvents = 4096;

enum class ServiceEvent {
  kServiceStartPending,
  kServiceBootObserved,
  kServiceRunning,
  kServiceStopRequested,
  kServiceShutdownRequested,
  kServicePreShutdownRequested,
  kServicePowerSuspend,
  kServicePowerResume,
  kServiceStopped,
  kIpcSessionAccepted,
  kIpcSessionRejected,
  kIpcSessionClosed,
  kRuntimeInitialize,
  kRuntimeProfileStage,
  kRuntimeNetworkSnapshot,
  kRuntimeCoreStart,
  kRuntimeWintunStart,
  kRuntimeAdapterApply,
  kRuntimeRouteApply,
  kRuntimeDnsApply,
  kRuntimeEgressVerify,
  kRuntimeCommit,
  kRuntimeRollbackBegin,
  kRuntimeCoreStop,
  kRuntimeNetworkRestore,
  kRuntimeRollbackComplete,
  kRuntimeRecoveryRequired,
};

enum class ServiceEventOutcome {
  kAttempted,
  kSucceeded,
  kFailed,
  kAccepted,
  kRejected,
};

struct CoreOperationalEventRecord {
  int schema_version = 0;
  int event_abi = 0;
  std::string occurred_at_utc;
  std::string run_id;
  std::string attempt_id;
  std::int64_t generation = 0;
  std::int64_t sequence = 0;
  std::string name;
  std::string subsystem;
  std::string stage;
  std::string severity;
  std::string outcome;
  std::string error_code;
  std::string phase;
};

class ServiceEventSink {
 public:
  virtual ~ServiceEventSink() = default;

  virtual bool Record(ServiceEvent event, ServiceEventOutcome outcome) = 0;
  virtual bool RecordSystemBoot(std::uint64_t boot_epoch_filetime_ticks) = 0;
  virtual bool RecordIpcRequest(Command command,
                                const Identifier& correlation_id) = 0;
  virtual bool RecordIpcResponse(Command command, Status status,
                                 const Identifier& correlation_id) = 0;
  virtual bool RecordCoreOperationalEvent(
      const CoreOperationalEventRecord& event) {
    return false;
  }
};

std::unique_ptr<ServiceEventSink> CreateServiceEventJournal(
    const std::wstring& runtime_root);

}  // namespace pokrov::service

#endif  // POKROV_SERVICE_SERVICE_EVENTS_H_
