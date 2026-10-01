#ifndef POKROV_SERVICE_LOCAL_DPI_JSON_H_
#define POKROV_SERVICE_LOCAL_DPI_JSON_H_

#include "service_local_dpi.h"
#include <cstdint>
#include <optional>

namespace pokrov::service {
struct WindowsLocalDpiPreparation {
  std::string profile;
  std::vector<WindowsLocalDpiService> services;
  std::uint64_t expires_utc_ticks = 0;
  std::uint64_t expires_elapsed_ms = 0;
};

// Original signed bytes stay in the host. Only the runtime copy loses _meta.
bool StripWindowsLocalDpiMetadata(const std::string& original,
                                 std::string* runtime_copy, bool* requested);
std::optional<WindowsLocalDpiPreparation> ReadWindowsLocalDpiPreparation(
    const std::string& encoded);
bool WindowsLocalDpiPreparationCurrent(const WindowsLocalDpiPreparation& value);
}  // namespace pokrov::service
#endif
