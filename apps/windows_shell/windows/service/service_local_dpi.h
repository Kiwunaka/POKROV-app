#ifndef POKROV_SERVICE_LOCAL_DPI_H_
#define POKROV_SERVICE_LOCAL_DPI_H_

#include <windows.h>
#include <memory>
#include <functional>
#include <string>
#include <vector>
#include <cstdint>

namespace pokrov::service {
class CoreRuntime;

// Private native plan returned by Core PrepareWindowsLocalDpiProfile. Never
// populate this from IPC fields or an unsigned client host list.
struct WindowsLocalDpiDomain {
  std::string name;
  bool exact;
  bool shared = false;
};
struct WindowsLocalDpiService {
  std::string service_id;
  std::string outbound_tag;
  std::string control_host;
  std::vector<WindowsLocalDpiDomain> domains;
  std::string captured_admission_id;  // Private current Core owner, never IPC.
};

struct WindowsLocalDpiRuntimeObservation {
  std::uint64_t services = 0;
  std::uint64_t admitted = 0;
  std::uint64_t failed = 0;
  std::uint64_t withdraw_completed = 0;
  std::uint64_t local_handoffs = 0;
  std::uint64_t vpn_handoffs = 0;
};
enum class WindowsLocalDpiStrategy { kMultisplit568, kMultisplit681 };

// Empty means refused, never upstream's allow-all empty host list.
std::string WindowsLocalDpiHostList(const std::vector<WindowsLocalDpiService>& services);

// Service-owned child and captured native holders. The RuntimeHost supplies
// exact TLS proof/currentness; driver bootstrap is limited to StartPrepared.
class WindowsLocalDpiExecutor final {
 public:
  explicit WindowsLocalDpiExecutor(CoreRuntime& core);
  ~WindowsLocalDpiExecutor();
  WindowsLocalDpiExecutor(const WindowsLocalDpiExecutor&) = delete;
  WindowsLocalDpiExecutor& operator=(const WindowsLocalDpiExecutor&) = delete;

  std::string StartPrepared(const std::vector<WindowsLocalDpiService>& services,
                            const std::string& physical_bind_interface,
                            WindowsLocalDpiStrategy strategy);
  // One other strategy before any admission; retain exact captures/assets.
  std::string RetryPrepared(const std::vector<WindowsLocalDpiService>& services,
                            const std::string& physical_bind_interface,
                            WindowsLocalDpiStrategy strategy);
  bool Alive() const;
  bool AssetsReady();  // Fixed trusted assets and API exports; no driver or child.
  bool AdmitCaptured(const std::string& tag, const std::function<bool()>& current_after_proof);
  std::string CapturedAdmissionID(const std::string& tag) const;
  bool Stop();  // Confirm withdrawal before closing our Job/filter.
  bool StopAfterCoreStopped();  // Only after the native owner confirmed Core Stop.

 private:
  std::string StartChild(const std::string& hostlist, DWORD interface_index,
                         WindowsLocalDpiStrategy strategy);
  struct State;
  CoreRuntime& core_;
  std::unique_ptr<State> state_;
};
}  // namespace pokrov::service
#endif
