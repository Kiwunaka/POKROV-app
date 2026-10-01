#ifndef POKROV_SERVICE_LOCAL_DPI_H_
#define POKROV_SERVICE_LOCAL_DPI_H_

#include <windows.h>
#include <memory>
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

// Service-owned child only: no admission, TLS proof, driver installation or
// driver removal. The dispatcher must withdraw on currentness/proof failure.
// There is no public activation path or capability until that integration and
// approved packaged assets have passed their gates.
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
  void Stop();  // Withdraw captured holder IDs before closing our Job/filter.

 private:
  struct State;
  CoreRuntime& core_;
  std::unique_ptr<State> state_;
};
}  // namespace pokrov::service
#endif
