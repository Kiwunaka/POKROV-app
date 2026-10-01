#ifndef POKROV_SERVICE_LOCAL_DPI_H_
#define POKROV_SERVICE_LOCAL_DPI_H_

#include <windows.h>
#include <memory>
#include <functional>
#include <string>
#include <vector>

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
};
enum class WindowsLocalDpiStrategy { kMultisplit568, kMultisplit681 };

// Empty means refused, never upstream's allow-all empty host list.
std::string WindowsLocalDpiHostList(const std::vector<WindowsLocalDpiService>& services);

// Service-owned child and captured native holders. The RuntimeHost supplies
// exact TLS proof/currentness; no IPC pins, driver installation or removal.
class WindowsLocalDpiExecutor final {
 public:
  explicit WindowsLocalDpiExecutor(CoreRuntime& core);
  ~WindowsLocalDpiExecutor();
  WindowsLocalDpiExecutor(const WindowsLocalDpiExecutor&) = delete;
  WindowsLocalDpiExecutor& operator=(const WindowsLocalDpiExecutor&) = delete;

  std::string StartPrepared(const std::vector<WindowsLocalDpiService>& services,
                            const std::string& physical_bind_interface,
                            WindowsLocalDpiStrategy strategy);
  bool Alive() const;
  bool AssetsReady();  // Fixed trusted assets plus existing driver; no child.
  bool AdmitCaptured(const std::string& tag, const std::function<bool()>& current_after_proof);
  bool Stop();  // Confirm withdrawal before closing our Job/filter.
  void StopAfterCoreStopped();  // Only after the native owner confirmed Core Stop.

 private:
  struct State;
  CoreRuntime& core_;
  std::unique_ptr<State> state_;
};
}  // namespace pokrov::service
#endif
