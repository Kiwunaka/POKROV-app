#ifndef POKROV_RUNNER_UPLINK_STATUS_H_
#define POKROV_RUNNER_UPLINK_STATUS_H_

#include <optional>

// Current local route/link availability, not an Internet or DNS probe.
// Unknown means Windows could not provide a complete observation.
std::optional<bool> HasDefaultUplink();

#endif  // POKROV_RUNNER_UPLINK_STATUS_H_
