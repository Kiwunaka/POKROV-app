#ifndef POKROV_SERVICE_BOOT_CLOCK_H_
#define POKROV_SERVICE_BOOT_CLOCK_H_

#include <optional>
#include <string>
#include "service_protocol.h"

namespace pokrov::service {
// Local-only clock/boot metadata. Never copy this body into operational events.
struct BootClockSnapshot {
  std::string boot_ref;
  std::uint64_t elapsed_ms;
};
std::optional<BootClockSnapshot> ReadBootClock();
std::optional<std::string> ReadBootClockJson();
bool IsConnectDeadlineCurrent(const BoundConnectTarget& target);
std::optional<std::uint64_t> ActiveTransportLeaseDeadline(const TransportLeasePromotion& target);
bool IsActiveTransportLeaseCurrent(const BoundConnectTarget& connect, std::uint64_t deadline_elapsed_ms);
}

#endif
