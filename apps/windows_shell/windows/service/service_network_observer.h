#ifndef POKROV_SERVICE_SERVICE_NETWORK_OBSERVER_H_
#define POKROV_SERVICE_SERVICE_NETWORK_OBSERVER_H_

#include <cstdint>
#include <memory>
#include <optional>
#include <string>

namespace pokrov::service {

struct ServiceNetworkContext {
  std::uint64_t revision;
  std::string reference;
};

// Local OS metadata only. Revisions and adapter material never leave the service.
class ServiceNetworkObserver {
 public:
  ServiceNetworkObserver();
  ~ServiceNetworkObserver();
  std::optional<std::uint64_t> Sample();
  std::optional<ServiceNetworkContext> ReadContext();
  bool IsCurrent(std::uint64_t revision) const;

 private:
  struct State;
  std::unique_ptr<State> state_;
};

}  // namespace pokrov::service
#endif
