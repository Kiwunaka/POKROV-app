#ifndef POKROV_SERVICE_LOCAL_DPI_JSON_H_
#define POKROV_SERVICE_LOCAL_DPI_JSON_H_

#include "service_local_dpi.h"
#include <cstdint>
#include <optional>
#include <utility>

namespace pokrov::service {
struct WindowsLocalDpiPreparation {
  std::string profile;
  std::vector<WindowsLocalDpiService> services;
  std::uint64_t expires_utc_ticks = 0;
  std::uint64_t expires_elapsed_ms = 0;
};

struct WindowsTelegramWSPreparation {
  std::string profile;
  std::vector<std::pair<std::string, std::string>> services;
  std::uint64_t expires_utc_ticks = 0;
  std::uint64_t expires_elapsed_ms = 0;
};

// Original signed bytes stay in the host. Only the runtime copy loses _meta.
bool StripWindowsLocalDpiMetadata(const std::string& original,
                                 std::string* runtime_copy, bool* requested,
                                 bool* telegram_requested = nullptr);
std::optional<WindowsLocalDpiPreparation> ReadWindowsLocalDpiPreparation(
    const std::string& encoded);
bool WindowsLocalDpiPreparationCurrent(const WindowsLocalDpiPreparation& value);
struct WindowsLocalDpiHolderObservation {
  std::string state;
  std::string failure_reason;  // Empty means the older Core did not report it.
  bool withdraw_completed = false;
  std::uint64_t local_handoffs = 0;
  std::uint64_t vpn_handoffs = 0;
  std::uint64_t quic_rejected = 0;
};
std::optional<WindowsLocalDpiHolderObservation> ReadWindowsLocalDpiHolderObservation(
    const std::string& encoded);
void InvalidateWindowsLocalDpiStrategyHint(
    std::pair<std::string, WindowsLocalDpiStrategy>& hint,
    const WindowsLocalDpiHolderObservation& observation);
std::optional<WindowsTelegramWSPreparation> ReadWindowsTelegramWSPreparation(
    const std::string& encoded);
bool WindowsTelegramWSPreparationCurrent(const WindowsTelegramWSPreparation& value);
// No value means the ordinary VPN verifier. An empty target is a local
// SmartAccess intent without a valid bound anchor and must fail closed.
// First-provider QA selects the service only behind a valid owned VPN boundary.
std::optional<std::string> ReadWindowsSmartAccessProbeTarget(const std::string& profile,
    bool first_provider_qa = false);
// Purpose check only; Core validates the complete worker config before admission.
bool IsWindowsFirstProviderQaRuntimeControl(const std::string& config);
// Override only cancellation status; retain the trusted Core's completed stages.
// Invalid JSON has no diagnostic to preserve.
std::string CancelWindowsCandidateProbeResult(const std::string& encoded,
    bool network_changed);
}  // namespace pokrov::service
#endif
