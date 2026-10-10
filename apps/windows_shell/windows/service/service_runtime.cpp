#include "service_runtime.h"
#include "service_boot_clock.h"
#include "windows_crash_profile.h"
#include "service_profile_identity.h"
#include "service_core_identity.h"
#include "service_local_dpi.h"
#include "service_local_dpi_json.h"
#include "service_local_dpi_probe.h"
#include "service_catalog_trust.h"

#include <windows.h>

#include <aclapi.h>
#include <knownfolders.h>
#include <sddl.h>
#include <shlobj.h>
#include <winhttp.h>

#include <algorithm>
#include <array>
#include <cctype>
#include <climits>
#include <cstdio>
#include <memory>
#include <mutex>
#include <string>
#include <utility>
#include <vector>

namespace pokrov::service {

bool CoreDescriptorHasRuntimeControl(const std::string& descriptor);
bool CoreDescriptorHasWindowsLocalDpi(const std::string& descriptor);
bool CoreDescriptorHasTelegramWS(const std::string& descriptor);
bool CoreDescriptorHasSmartAccessProbe(const std::string& descriptor);

RuntimeResult RuntimeHost::CrashDiagnostics() const {
  std::vector<windows_crash::WindowsCrashDiagnostic> records;
  if (!windows_crash::ReadWindowsCrashDiagnostics(
          windows_crash::WindowsCrashProcess::kService, runtime_root_, &records)) {
    return {Status::kNotReady, "crash_diagnostics_unavailable"};
  }
  return {Status::kOk, windows_crash::EncodeWindowsCrashDiagnostics(records)};
}
namespace {

const char* SafeEgressFailure(const std::string& failure) {
  for (const auto* known : {
           "core_egress_dns_failed", "core_egress_connect_failed",
           "core_egress_tls_failed", "core_egress_tls_timeout",
           "core_egress_response_timeout", "core_egress_timeout",
           "core_egress_probe_unavailable", "core_smart_access_lease_expired"}) {
    if (failure == known) return known;
  }
  return "core_egress_probe_failed";
}

constexpr char kCoreCapabilities[] =
    "{\"schema_version\":1,\"desktop_abi\":2,\"event_abi\":1,"
    "\"capabilities\":[\"bounded_stop_reason\",\"core_start_stop\","
    "\"materialized_profile\",\"secure_profile_file\","
    "\"structured_operational_events\",\"typed_lifecycle_events\"],"
    "\"lifecycle_events\":[\"initialization\","
    "\"profile\",\"core_start\",\"tun\",\"routes\",\"dns\",\"egress\","
    "\"recovery\",\"stop\"],\"operational_events\":{"
    "\"contract\":\"config/core-event-abi.json\",\"schema_version\":1,"
    "\"event_abi\":1,\"callback_symbol\":\"pokrovCoreSetEventCallback\","
    "\"context_symbol\":\"pokrovCoreSetEventContext\","
    "\"maximum_pending_events\":128}}";
constexpr char kLegacyCoreCapabilities[] =
    "{\"schema_version\":1,\"desktop_abi\":2,\"event_abi\":1,"
    "\"capabilities\":[\"bounded_stop_reason\",\"core_start_stop\","
    "\"materialized_profile\",\"secure_profile_file\","
    "\"typed_lifecycle_events\"],\"lifecycle_events\":[\"initialization\","
    "\"profile\",\"core_start\",\"tun\",\"routes\",\"dns\",\"egress\","
    "\"recovery\",\"stop\"]}";
constexpr wchar_t kPrivateRuntimeSddl[] =
    L"D:P(A;OICI;FA;;;SY)(A;OICI;FA;;;BA)";
constexpr char kProfileBundleHeader[] = "POKROV_PROFILE_BUNDLE_V1";
constexpr char kProfileBundleJsonMarker[] = "POKROV_PROFILE_JSON";
constexpr char kRuleSetSlotMarker[] = "__POKROV_RULE_SET_SLOT__";
constexpr std::size_t kMaximumBundledRuleSets = 8;
constexpr std::size_t kMaximumBundledRuleSetBytes = 128 * 1024;
constexpr std::size_t kMaximumBundledRuleSetTotalBytes = 160 * 1024;

struct ParsedProfileBundle {
  std::string profile;
  std::vector<std::vector<std::uint8_t>> rule_sets;
};

std::wstring AppendPath(const std::wstring& base, const wchar_t* child) {
  if (base.empty()) {
    return L"";
  }
  return base + (base.back() == L'\\' ? L"" : L"\\") + child;
}

std::wstring AppendPath(const std::wstring& base,
                        const std::wstring& child) {
  return AppendPath(base, child.c_str());
}

bool ReadBundleLine(const std::string& value, std::size_t* offset,
                    std::string* line) {
  if (offset == nullptr || line == nullptr || *offset >= value.size()) {
    return false;
  }
  const auto end = value.find('\n', *offset);
  if (end == std::string::npos || end == *offset ||
      value.find('\r', *offset) < end) {
    return false;
  }
  *line = value.substr(*offset, end - *offset);
  *offset = end + 1;
  return true;
}

int Base64Value(char value) {
  if (value >= 'A' && value <= 'Z') {
    return value - 'A';
  }
  if (value >= 'a' && value <= 'z') {
    return value - 'a' + 26;
  }
  if (value >= '0' && value <= '9') {
    return value - '0' + 52;
  }
  if (value == '+') {
    return 62;
  }
  if (value == '/') {
    return 63;
  }
  return -1;
}

bool DecodeBase64(const std::string& encoded,
                  std::vector<std::uint8_t>* decoded) {
  if (decoded == nullptr || encoded.empty() || encoded.size() % 4 != 0 ||
      encoded.size() > ((kMaximumBundledRuleSetBytes + 2) / 3) * 4) {
    return false;
  }
  decoded->clear();
  decoded->reserve((encoded.size() / 4) * 3);
  for (std::size_t offset = 0; offset < encoded.size(); offset += 4) {
    const bool last = offset + 4 == encoded.size();
    const bool pad2 = encoded[offset + 2] == '=';
    const bool pad3 = encoded[offset + 3] == '=';
    const int a = Base64Value(encoded[offset]);
    const int b = Base64Value(encoded[offset + 1]);
    const int c = pad2 ? 0 : Base64Value(encoded[offset + 2]);
    const int d = pad3 ? 0 : Base64Value(encoded[offset + 3]);
    if (a < 0 || b < 0 || c < 0 || d < 0 ||
        (!last && (pad2 || pad3)) || (pad2 && !pad3) ||
        (pad2 && (b & 0x0f) != 0) ||
        (!pad2 && pad3 && (c & 0x03) != 0)) {
      decoded->clear();
      return false;
    }
    decoded->push_back(static_cast<std::uint8_t>((a << 2) | (b >> 4)));
    if (!pad2) {
      decoded->push_back(
          static_cast<std::uint8_t>(((b & 0x0f) << 4) | (c >> 2)));
    }
    if (!pad3) {
      decoded->push_back(
          static_cast<std::uint8_t>(((c & 0x03) << 6) | d));
    }
  }
  return !decoded->empty() &&
         decoded->size() <= kMaximumBundledRuleSetBytes;
}

std::size_t CountOccurrences(const std::string& value,
                             const char* needle) {
  std::size_t count = 0;
  std::size_t offset = 0;
  const std::size_t length = std::char_traits<char>::length(needle);
  while ((offset = value.find(needle, offset)) != std::string::npos) {
    ++count;
    offset += length;
  }
  return count;
}

void ReplaceAll(std::string* value, const char* needle,
                const char* replacement) {
  std::size_t offset = 0;
  const std::size_t needle_length = std::char_traits<char>::length(needle);
  const std::size_t replacement_length =
      std::char_traits<char>::length(replacement);
  while ((offset = value->find(needle, offset)) != std::string::npos) {
    value->replace(offset, needle_length, replacement);
    offset += replacement_length;
  }
}

bool ParseProfilePayload(const std::string& value,
                         ParsedProfileBundle* output) {
  if (output == nullptr) {
    return false;
  }
  output->profile.clear();
  output->rule_sets.clear();
  if (value.rfind(std::string(kProfileBundleHeader) + "\n", 0) != 0) {
    output->profile = value;
    return true;
  }

  std::size_t offset = std::char_traits<char>::length(kProfileBundleHeader) + 1;
  std::string line;
  if (!ReadBundleLine(value, &offset, &line) || line.size() > 1 ||
      line[0] < '1' || line[0] > '8') {
    return false;
  }
  const std::size_t count = static_cast<std::size_t>(line[0] - '0');
  std::size_t total_bytes = 0;
  for (std::size_t index = 0; index < count; ++index) {
    std::string name;
    std::string encoded;
    const std::string expected =
        "ruleset-" + std::to_string(index) + ".srs";
    if (!ReadBundleLine(value, &offset, &name) || name != expected ||
        !ReadBundleLine(value, &offset, &encoded)) {
      return false;
    }
    std::vector<std::uint8_t> decoded;
    if (!DecodeBase64(encoded, &decoded) ||
        total_bytes + decoded.size() > kMaximumBundledRuleSetTotalBytes) {
      return false;
    }
    total_bytes += decoded.size();
    output->rule_sets.push_back(std::move(decoded));
  }
  if (!ReadBundleLine(value, &offset, &line) ||
      line != kProfileBundleJsonMarker || offset >= value.size()) {
    return false;
  }
  output->profile = value.substr(offset);
  return CountOccurrences(output->profile, kRuleSetSlotMarker) == count;
}

std::wstring CurrentExecutableDirectory() {
  std::wstring path(32768, L'\0');
  const DWORD length = ::GetModuleFileNameW(
      nullptr, path.data(), static_cast<DWORD>(path.size()));
  if (length == 0 || length >= path.size()) {
    return L"";
  }
  path.resize(length);
  const auto separator = path.find_last_of(L"\\/");
  return separator == std::wstring::npos ? L"" : path.substr(0, separator);
}

std::string Utf8(const std::wstring& value) {
  if (value.empty()) {
    return "";
  }
  const int size = ::WideCharToMultiByte(
      CP_UTF8, WC_ERR_INVALID_CHARS, value.data(),
      static_cast<int>(value.size()), nullptr, 0, nullptr, nullptr);
  if (size <= 0) {
    return "";
  }
  std::string encoded(static_cast<std::size_t>(size), '\0');
  if (::WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, value.data(),
                            static_cast<int>(value.size()), encoded.data(),
                            size, nullptr, nullptr) != size) {
    return "";
  }
  return encoded;
}

bool IsValidUtf8JsonObject(const std::string& value) {
  if (value.empty() || value.find('\0') != std::string::npos) {
    return false;
  }
  const auto first = value.find_first_not_of(" \t\r\n");
  const auto last = value.find_last_not_of(" \t\r\n");
  if (first == std::string::npos || value[first] != '{' ||
      value[last] != '}') {
    return false;
  }
  return ::MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, value.data(),
                               static_cast<int>(value.size()), nullptr, 0) > 0;
}

bool IsLowerHex(char value) {
  return (value >= '0' && value <= '9') ||
         (value >= 'a' && value <= 'f');
}

bool IsLowerUuid(const std::string& value) {
  if (value.size() != 36 || value[8] != '-' || value[13] != '-' ||
      value[18] != '-' || value[23] != '-' || value[14] < '1' ||
      value[14] > '5' || std::string("89ab").find(value[19]) ==
                               std::string::npos) {
    return false;
  }
  for (std::size_t index = 0; index < value.size(); ++index) {
    if (index == 8 || index == 13 || index == 18 || index == 23) {
      continue;
    }
    if (!IsLowerHex(value[index])) {
      return false;
    }
  }
  return true;
}

bool IsUtcTimestamp(const std::string& value) {
  if (value.size() < 20 || value.size() > 30 || value.back() != 'Z' ||
      value[4] != '-' || value[7] != '-' || value[10] != 'T' ||
      value[13] != ':' || value[16] != ':') {
    return false;
  }
  for (std::size_t index = 0; index + 1 < value.size(); ++index) {
    const char character = value[index];
    if (!std::isdigit(static_cast<unsigned char>(character)) &&
        character != '-' && character != 'T' && character != ':' &&
        character != '.') {
      return false;
    }
  }
  return true;
}

std::string NewUuid() {
  GUID value{};
  if (FAILED(::CoCreateGuid(&value))) {
    return "";
  }
  char encoded[37]{};
  const int written = std::snprintf(
      encoded, sizeof(encoded),
      "%08lx-%04x-%04x-%02x%02x-%02x%02x%02x%02x%02x%02x",
      static_cast<unsigned long>(value.Data1), value.Data2, value.Data3,
      value.Data4[0], value.Data4[1], value.Data4[2], value.Data4[3],
      value.Data4[4], value.Data4[5], value.Data4[6], value.Data4[7]);
  return written == 36 ? std::string(encoded) : "";
}

bool IsCoreEventDefinition(const CoreOperationalEventRecord& event) {
  return (event.name == "core.runtime.initialize" &&
          event.subsystem == "core" && event.stage == "initialize" &&
          event.phase == "initialization") ||
         (event.name == "core.runtime.start" &&
          event.subsystem == "core" && event.stage == "start" &&
          event.phase == "core_start") ||
         (event.name == "core.runtime.stop" &&
          event.subsystem == "core" && event.stage == "stop" &&
          event.phase == "stop") ||
         (event.name == "core.egress.probe" &&
          event.subsystem == "egress" && event.stage == "verify" &&
          event.phase == "egress") ||
         (event.name == "core.dns.probe" && event.subsystem == "dns" &&
          event.phase == "dns" &&
          (event.stage == "receive" || event.stage == "exchange" || event.stage == "reply"));
}

bool IsCoreErrorCode(const std::string& value) {
  return value == "CORE-003" || value == "CORE-005" ||
         value == "CORE-006" || value == "CORE-008" ||
         value == "TRANSPORT-001" || value == "TRANSPORT-002" ||
         value == "TRANSPORT-003" || value == "TRANSPORT-004" ||
         value == "TRANSPORT-005" || value == "TRANSPORT-006" ||
         value == "TRANSPORT-007" || value == "DNS-002" ||
         value == "EGRESS-001";
}

bool EnsureDirectory(const std::wstring& path) {
  return !path.empty() &&
         (::CreateDirectoryW(path.c_str(), nullptr) != FALSE ||
          ::GetLastError() == ERROR_ALREADY_EXISTS) &&
         (::GetFileAttributesW(path.c_str()) & FILE_ATTRIBUTE_DIRECTORY) != 0;
}

bool ProtectDirectory(const std::wstring& path) {
  PSECURITY_DESCRIPTOR descriptor = nullptr;
  if (!::ConvertStringSecurityDescriptorToSecurityDescriptorW(
          kPrivateRuntimeSddl, SDDL_REVISION_1, &descriptor, nullptr)) {
    return false;
  }
  BOOL present = FALSE;
  BOOL defaulted = FALSE;
  PACL dacl = nullptr;
  const bool decoded =
      ::GetSecurityDescriptorDacl(descriptor, &present, &dacl, &defaulted) !=
          FALSE &&
      present != FALSE;
  const DWORD result = decoded
                           ? ::SetNamedSecurityInfoW(
                                 const_cast<wchar_t*>(path.c_str()),
                                 SE_FILE_OBJECT,
                                 DACL_SECURITY_INFORMATION |
                                     PROTECTED_DACL_SECURITY_INFORMATION,
                                 nullptr, nullptr, dacl, nullptr)
                           : ERROR_INVALID_SECURITY_DESCR;
  ::LocalFree(descriptor);
  return result == ERROR_SUCCESS;
}

const char* PhaseName(int phase) {
  switch (phase) {
    case 0:
      return "artifact_missing";
    case 1:
      return "artifact_ready";
    case 2:
      return "initialized";
    case 3:
      return "config_staged";
    case 4:
      return "running";
    case 5:
      return "recovery_required";
    default:
      return "artifact_missing";
  }
}

class InstalledCoreRuntime final : public CoreRuntime {
 public:
  ~InstalledCoreRuntime() override {
    if (set_event_callback_ != nullptr) {
      set_event_callback_(nullptr);
    }
    std::lock_guard<std::mutex> guard(callback_lock_);
    if (callback_runtime_ == this) {
      callback_runtime_ = nullptr;
    }
  }

  void SetOperationalEventSink(ServiceEventSink* events) override {
    events_ = events;
  }

  FirstOwnedDnsState FirstOwnedDnsObservation() const override {
    std::lock_guard<std::mutex> guard(callback_lock_);
    return event_fence_.FirstOwnedDnsObservation();
  }

  int RoutingCatalogWindowVersion() const override {
    return initialized_ ? routing_catalog_window_version_ : 0;
  }

  std::string TransportCapabilities() const override {
    return initialized_ ? transport_capabilities_json_ : "";
  }

  std::string CoreModuleSHA256() const override {
    return initialized_ ? core_module_sha256_ : "";
  }

  std::string CoreVersion() const override {
    return initialized_ ? core_version_ : "";
  }

  int WindowsLocalDpiAdmissionVersion() const override {
    return initialized_ && windows_local_dpi_version_ != nullptr ? 1 : 0;
  }

  std::string PrepareWindowsLocalDpiProfile(
      const std::string& config, const std::string& compiled_public_keys,
      const std::string& compiled_audience, const std::string& bind_interface) override {
    if (WindowsLocalDpiAdmissionVersion() != 1) return "";
    return StringResult(prepare_windows_local_dpi_(config.c_str(),
        compiled_public_keys.c_str(), compiled_audience.c_str(), bind_interface.c_str()));
  }

  std::string ReadLocalDpiAdmissionID(const std::string& tag) override {
    return WindowsLocalDpiAdmissionVersion() == 1
        ? StringResult(read_local_dpi_admission_(tag.c_str())) : "";
  }

  int AdmitLocalDpiAdmission(const std::string& id) override {
    return WindowsLocalDpiAdmissionVersion() == 1 ? admit_local_dpi_admission_(id.c_str()) : -1;
  }

  int WithdrawLocalDpiAdmission(const std::string& id) override {
    return WindowsLocalDpiAdmissionVersion() == 1 ? withdraw_local_dpi_admission_(id.c_str()) : -1;
  }

  std::string ReadLocalDpiObservation(const std::string& id) override {
    return initialized_ && read_local_dpi_observation_ != nullptr
        ? StringResult(read_local_dpi_observation_(id.c_str())) : "";
  }

  int TelegramWSAdmissionVersion() const override {
    return initialized_ && telegram_ws_version_ != nullptr ? 1 : 0;
  }
  std::string PrepareTelegramWSProfile(const std::string& config, const std::string& keys,
      const std::string& audience, const std::string& bind_interface) override {
    return TelegramWSAdmissionVersion() == 1 ? StringResult(prepare_telegram_ws_(
        config.c_str(), keys.c_str(), audience.c_str(), bind_interface.c_str())) : "";
  }
  std::string ReadTelegramWSAdmissionID(const std::string& tag) override {
    return TelegramWSAdmissionVersion() == 1 ? StringResult(read_telegram_ws_(tag.c_str())) : "";
  }
  int AdmitTelegramWSAdmission(const std::string& id) override {
    return TelegramWSAdmissionVersion() == 1 ? admit_telegram_ws_(id.c_str()) : -1;
  }
  int WithdrawTelegramWSAdmission(const std::string& id) override {
    return TelegramWSAdmissionVersion() == 1 ? withdraw_telegram_ws_(id.c_str()) : -1;
  }

  int SmartAccessLeaseVersion() const override {
    return initialized_ ? smart_access_lease_version_ : 0;
  }

  int RoutingCatalogControlVersion() const override {
    return initialized_ ? routing_catalog_control_version_ : 0;
  }

  int SmartAccessRuntimeControlVersion() const override {
    return initialized_ && configure_smart_access_control_ != nullptr && read_smart_access_restrictions_ != nullptr &&
        configure_smart_access_renewal_ != nullptr && read_smart_access_leases_ != nullptr && acknowledge_smart_access_restrictions_ != nullptr ? 1 : 0;
  }

  int SmartAccessProbeVersion() const override {
    return initialized_ && smart_access_probe_version_ == 1 &&
        probe_selected_outbound_ != nullptr && probe_runtime_egress_ != nullptr ? 1 : 0;
  }

  std::string ProbeSmartAccess(const std::string& tag, bool periodic,
                             const CheckInterruption& interrupted) override {
    if (SmartAccessProbeVersion() != 1) return "core_egress_probe_unavailable";
    const CheckInterruption current = interrupted ? interrupted : [] { return OperationInterruption::kNone; };
    char* value = periodic ? probe_runtime_egress_(tag.c_str(), 3000, &CheckCoreInterruption,
        const_cast<CheckInterruption*>(&current)) : probe_selected_outbound_(tag.c_str());
    if (value == nullptr) return "core_egress_probe_unavailable";
    const auto result = StringResult(value);
    if (result.empty()) return "";
    if (result == "URL probe DNS resolution failed") return "core_egress_dns_failed";
    if (result == "URL probe connection failed") return "core_egress_connect_failed";
    if (result == "URL probe TLS negotiation failed") return "core_egress_tls_failed";
    if (result == "Smart Access lease expired") return "core_smart_access_lease_expired";
    if (result == "context deadline exceeded") return "core_egress_timeout";
    if (result == "URL probe response failed" || result == "URL probe failed") return "core_egress_probe_failed";
    return "core_egress_probe_unavailable";
  }

  std::string ReadSmartAccessRestrictions() override {
    return SmartAccessRuntimeControlVersion() == 1 ? StringResult(read_smart_access_restrictions_()) : "";
  }

  std::string ReadSmartAccessLeases() override {
    return SmartAccessRuntimeControlVersion() == 1 ? StringResult(read_smart_access_leases_()) : "";
  }

  int AcknowledgeSmartAccessRestrictions(const std::string& digest) override {
    return SmartAccessRuntimeControlVersion() == 1 ? acknowledge_smart_access_restrictions_(digest.c_str()) : -1;
  }

  int ConfigureSmartAccessRuntimeControl(const std::string& profile_digest, const std::string& config) override {
    return SmartAccessRuntimeControlVersion() == 1
        ? configure_smart_access_control_(profile_digest.c_str(), config.c_str()) : -1;
  }

  int ConfigureSmartAccessRenewal(const std::string& profile_digest, const std::string& config) override {
    return SmartAccessRuntimeControlVersion() == 1
        ? configure_smart_access_renewal_(profile_digest.c_str(), config.c_str()) : -1;
  }

  int RevokeRoutingCatalog() override {
    return RoutingCatalogControlVersion() >= 1 && revoke_catalog_ != nullptr
        ? revoke_catalog_() : -1;
  }

  int RevokeSmartAccessPolicy(bool terminate_active) override {
    return RoutingCatalogControlVersion() >= 2 && revoke_smart_access_policy_ != nullptr
        ? revoke_smart_access_policy_(terminate_active ? 1 : 0) : -1;
  }

  int RevokeRoutingCatalogService(const std::string& service_id) override {
    return RoutingCatalogControlVersion() >= 3 && revoke_catalog_service_ != nullptr
        ? revoke_catalog_service_(service_id.c_str()) : -1;
  }

  int RevokeSmartAccessLease(const std::string& lease_id, bool terminate_active) override {
    return SmartAccessLeaseVersion() == 1 && revoke_smart_access_ != nullptr
        ? revoke_smart_access_(lease_id.c_str(), terminate_active ? 1 : 0) : -1;
  }

  int RenewSmartAccessLease(const SmartAccessRenewalTarget& target) override {
    return RoutingCatalogControlVersion() == 4 && renew_smart_access_ != nullptr
        ? renew_smart_access_(target.expected_lease_id.c_str(), target.next_lease_id.c_str(),
            target.issued_at.c_str(), target.new_flows_until.c_str(), target.active_flows_until.c_str()) : -1;
  }

  int ConfirmATSLease(const TransportLeasePromotion& target) override {
    return initialized_ && confirm_ats_lease_ != nullptr
        ? confirm_ats_lease_(target.endpoint_lease_ref.c_str(), target.issued_at.c_str(),
            target.new_flows_until.c_str(), target.active_flows_until.c_str()) : -1;
  }
  int RevokeATSLease(const TransportLeaseRevocation& target) override {
    return initialized_ && revoke_ats_lease_ != nullptr
        ? revoke_ats_lease_(target.endpoint_lease_ref.c_str(), target.terminate_active ? 1 : 0) : -1;
  }

  std::string Initialize(const RuntimeDirectories& directories) override {
    if (initialized_) {
      return "";
    }
    routing_catalog_window_version_ = 0;
    transport_capabilities_json_.clear();
    core_version_.clear();
    configure_smart_access_control_ = nullptr;
    configure_smart_access_renewal_ = nullptr;
    read_smart_access_restrictions_ = nullptr;
    read_smart_access_leases_ = nullptr;
    acknowledge_smart_access_restrictions_ = nullptr;
    windows_local_dpi_version_ = nullptr;
    prepare_windows_local_dpi_ = nullptr;
    read_local_dpi_admission_ = nullptr;
    admit_local_dpi_admission_ = nullptr;
    withdraw_local_dpi_admission_ = nullptr;
    read_local_dpi_observation_ = nullptr;
    telegram_ws_version_ = nullptr;
    prepare_telegram_ws_ = nullptr;
    read_telegram_ws_ = nullptr;
    admit_telegram_ws_ = nullptr;
    withdraw_telegram_ws_ = nullptr;
    smart_access_lease_version_ = 0;
    smart_access_probe_version_ = 0;
    probe_selected_outbound_ = nullptr;
    probe_runtime_egress_ = nullptr;
    routing_catalog_control_version_ = 0;
    const auto directory = CurrentExecutableDirectory();
    const auto library_path = AppendPath(directory, L"pokrov-core.dll");
    if (directory.empty() ||
        ::GetFileAttributesW(library_path.c_str()) == INVALID_FILE_ATTRIBUTES) {
      return "core_missing";
    }
    module_ = LoadCoreModuleWithIdentity(library_path, &core_module_sha256_);
    if (module_ == nullptr) {
      return "core_load_failed";
    }

    abi_ = reinterpret_cast<AbiFunction>(
        ::GetProcAddress(module_, "pokrovCoreAbiVersion"));
    capabilities_ = reinterpret_cast<CapabilitiesFunction>(
        ::GetProcAddress(module_, "pokrovCoreCapabilities"));
    set_event_callback_ = reinterpret_cast<SetEventCallbackFunction>(
        ::GetProcAddress(module_, "pokrovCoreSetEventCallback"));
    set_event_context_ = reinterpret_cast<SetEventContextFunction>(
        ::GetProcAddress(module_, "pokrovCoreSetEventContext"));
    setup_ = reinterpret_cast<SetupFunction>(
        ::GetProcAddress(module_, "setup"));
    secure_file_ = reinterpret_cast<SecureFileFunction>(
        ::GetProcAddress(module_, "pokrovSecureFile"));
    start_ = reinterpret_cast<StartFunction>(
        ::GetProcAddress(module_, "start"));
    start_interruptible_ = reinterpret_cast<StartInterruptibleFunction>(
        ::GetProcAddress(module_, "pokrovCoreStartInterruptibleV1"));
    probe_candidate_ = reinterpret_cast<ProbeCandidateFunction>(
        ::GetProcAddress(module_, "pokrovCoreProbeCandidateV1"));
    stop_ = reinterpret_cast<StopFunction>(::GetProcAddress(module_, "stop"));
    confirm_ats_lease_ = reinterpret_cast<ConfirmATSLeaseFunction>(
        ::GetProcAddress(module_, "pokrovCoreConfirmATSLease"));
    revoke_ats_lease_ = reinterpret_cast<RevokeATSLeaseFunction>(
        ::GetProcAddress(module_, "pokrovCoreRevokeATSLease"));
    free_string_ = reinterpret_cast<FreeStringFunction>(
        ::GetProcAddress(module_, "freeString"));
    if (abi_ == nullptr || setup_ == nullptr || secure_file_ == nullptr ||
        start_ == nullptr || stop_ == nullptr || free_string_ == nullptr ||
        abi_() != 2) {
      return "core_abi_incompatible";
    }
    const auto read_core_version = reinterpret_cast<CapabilitiesFunction>(
        ::GetProcAddress(module_, "pokrovCoreVersion"));
    if (read_core_version != nullptr) {
      const auto version = StringResult(read_core_version());
      if (version.size() <= 32 && std::all_of(version.begin(), version.end(),
          [](unsigned char character) { return (character >= '0' && character <= '9') || character == '.'; })) {
        core_version_ = version;
      }
    }
    if (capabilities_ != nullptr) {
      const auto descriptor = StringResult(capabilities_());
      // Match only the additive descriptor emitted by the owned Core. Do not
      // accept an arbitrary field or unknown lifetime semantics by substring.
      std::string catalog_descriptor(kCoreCapabilities);
      const auto fields = catalog_descriptor.find("\"capabilities\"");
      catalog_descriptor.insert(fields, "\"routing_catalog_window_version\":1,");
      std::string smart_access_descriptor(catalog_descriptor);
      smart_access_descriptor.insert(smart_access_descriptor.find("\"capabilities\""),
          "\"smart_access_lease_version\":1,");
      std::string catalog_control_descriptor(smart_access_descriptor);
      catalog_control_descriptor.insert(catalog_control_descriptor.find("\"capabilities\""),
          "\"routing_catalog_control_version\":1,");
      std::string policy_control_descriptor(smart_access_descriptor);
      policy_control_descriptor.insert(policy_control_descriptor.find("\"capabilities\""),
          "\"routing_catalog_control_version\":2,");
      std::string service_control_descriptor(smart_access_descriptor);
      service_control_descriptor.insert(service_control_descriptor.find("\"capabilities\""),
          "\"routing_catalog_control_version\":3,");
      std::string renewal_descriptor(smart_access_descriptor);
      renewal_descriptor.insert(renewal_descriptor.find("\"capabilities\""),
          "\"routing_catalog_control_version\":4,");
      const bool has_runtime_control = CoreDescriptorHasRuntimeControl(descriptor);
      if (CoreDescriptorHasSmartAccessProbe(descriptor)) {
        smart_access_probe_version_ = 1;
        probe_selected_outbound_ = reinterpret_cast<ProbeSelectedOutboundFunction>(
            ::GetProcAddress(module_, "pokrovCoreProbeSelectedOutbound"));
        probe_runtime_egress_ = reinterpret_cast<ProbeRuntimeEgressFunction>(
            ::GetProcAddress(module_, "pokrovCoreProbeRuntimeEgressV1"));
      }
      if (CoreDescriptorHasWindowsLocalDpi(descriptor)) {
        windows_local_dpi_version_ = reinterpret_cast<AbiFunction>(
            ::GetProcAddress(module_, "pokrovCoreWindowsLocalDpiAdmissionVersion"));
        prepare_windows_local_dpi_ = reinterpret_cast<PrepareWindowsLocalDpiFunction>(
            ::GetProcAddress(module_, "pokrovCorePrepareWindowsLocalDpiProfile"));
        read_local_dpi_admission_ = reinterpret_cast<ReadLocalDpiAdmissionFunction>(
            ::GetProcAddress(module_, "pokrovCoreReadLocalDpiAdmissionID"));
        admit_local_dpi_admission_ = reinterpret_cast<LocalDpiAdmissionFunction>(
            ::GetProcAddress(module_, "pokrovCoreAdmitLocalDpiAdmission"));
        withdraw_local_dpi_admission_ = reinterpret_cast<LocalDpiAdmissionFunction>(
            ::GetProcAddress(module_, "pokrovCoreWithdrawLocalDpiAdmission"));
        if (windows_local_dpi_version_ == nullptr || windows_local_dpi_version_() != 1 ||
            prepare_windows_local_dpi_ == nullptr || read_local_dpi_admission_ == nullptr ||
            admit_local_dpi_admission_ == nullptr || withdraw_local_dpi_admission_ == nullptr) {
          return "core_abi_incompatible";
        }
        if (descriptor.find("\"windows_local_dpi_observation_version\":1,") != std::string::npos) {
          read_local_dpi_observation_ = reinterpret_cast<ReadLocalDpiAdmissionFunction>(
              ::GetProcAddress(module_, "pokrovCoreReadLocalDpiObservation"));
          if (read_local_dpi_observation_ == nullptr) return "core_abi_incompatible";
        }
      }
      const bool has_renewal = descriptor == renewal_descriptor || has_runtime_control;
      if (CoreDescriptorHasTelegramWS(descriptor)) {
        telegram_ws_version_ = reinterpret_cast<AbiFunction>(
            ::GetProcAddress(module_, "pokrovCoreTelegramWSAdmissionVersion"));
        prepare_telegram_ws_ = reinterpret_cast<PrepareWindowsLocalDpiFunction>(
            ::GetProcAddress(module_, "pokrovCorePrepareTelegramWSProfile"));
        read_telegram_ws_ = reinterpret_cast<ReadLocalDpiAdmissionFunction>(
            ::GetProcAddress(module_, "pokrovCoreReadTelegramWSAdmissionID"));
        admit_telegram_ws_ = reinterpret_cast<LocalDpiAdmissionFunction>(
            ::GetProcAddress(module_, "pokrovCoreAdmitTelegramWSAdmission"));
        withdraw_telegram_ws_ = reinterpret_cast<LocalDpiAdmissionFunction>(
            ::GetProcAddress(module_, "pokrovCoreWithdrawTelegramWSAdmission"));
        if (telegram_ws_version_ == nullptr || telegram_ws_version_() != 1 ||
            prepare_telegram_ws_ == nullptr || read_telegram_ws_ == nullptr ||
            admit_telegram_ws_ == nullptr || withdraw_telegram_ws_ == nullptr) return "core_abi_incompatible";
      }
      if (descriptor == smart_access_descriptor || descriptor == catalog_control_descriptor ||
          descriptor == policy_control_descriptor || descriptor == service_control_descriptor || has_renewal) {
        revoke_smart_access_ = reinterpret_cast<RevokeSmartAccessFunction>(
            ::GetProcAddress(module_, "pokrovCoreRevokeSmartAccessLease"));
        if (revoke_smart_access_ == nullptr) {
          return "core_abi_incompatible";
        }
        structured_events_ = true;
        routing_catalog_window_version_ = 1;
        smart_access_lease_version_ = 1;
        if (descriptor == catalog_control_descriptor || descriptor == policy_control_descriptor ||
            descriptor == service_control_descriptor || has_renewal) {
          revoke_catalog_ = reinterpret_cast<RevokeCatalogFunction>(
              ::GetProcAddress(module_, "pokrovCoreRevokeRoutingCatalog"));
          if (revoke_catalog_ == nullptr) return "core_abi_incompatible";
          routing_catalog_control_version_ = 1;
          if (descriptor == policy_control_descriptor || descriptor == service_control_descriptor || has_renewal) {
            revoke_smart_access_policy_ = reinterpret_cast<RevokeSmartAccessPolicyFunction>(
                ::GetProcAddress(module_, "pokrovCoreRevokeSmartAccessPolicy"));
            if (revoke_smart_access_policy_ == nullptr) return "core_abi_incompatible";
            routing_catalog_control_version_ = 2;
            if (descriptor == service_control_descriptor || has_renewal) {
              revoke_catalog_service_ = reinterpret_cast<RevokeCatalogServiceFunction>(
                  ::GetProcAddress(module_, "pokrovCoreRevokeRoutingCatalogService"));
              if (revoke_catalog_service_ == nullptr) return "core_abi_incompatible";
              routing_catalog_control_version_ = 3;
              if (has_renewal) {
                renew_smart_access_ = reinterpret_cast<RenewSmartAccessFunction>(
                    ::GetProcAddress(module_, "pokrovCoreRenewSmartAccessLease"));
                if (renew_smart_access_ == nullptr) return "core_abi_incompatible";
                routing_catalog_control_version_ = 4;
                if (has_runtime_control) {
                  configure_smart_access_control_ = reinterpret_cast<ConfigureSmartAccessControlFunction>(
                      ::GetProcAddress(module_, "pokrovCoreConfigureSmartAccessRuntimeControl"));
                  configure_smart_access_renewal_ = reinterpret_cast<ConfigureSmartAccessControlFunction>(
                      ::GetProcAddress(module_, "pokrovCoreConfigureSmartAccessRenewal"));
                  read_smart_access_restrictions_ = reinterpret_cast<CapabilitiesFunction>(
                      ::GetProcAddress(module_, "pokrovCoreReadSmartAccessRestrictions"));
                  read_smart_access_leases_ = reinterpret_cast<CapabilitiesFunction>(
                      ::GetProcAddress(module_, "pokrovCoreReadSmartAccessLeases"));
                  acknowledge_smart_access_restrictions_ = reinterpret_cast<AcknowledgeSmartAccessRestrictionsFunction>(
                      ::GetProcAddress(module_, "pokrovCoreAcknowledgeSmartAccessRestrictions"));
                  if (configure_smart_access_control_ == nullptr || read_smart_access_restrictions_ == nullptr ||
                      configure_smart_access_renewal_ == nullptr || read_smart_access_leases_ == nullptr ||
                      acknowledge_smart_access_restrictions_ == nullptr) return "core_abi_incompatible";
                }
              }
            }
          }
        }
      } else if (descriptor == catalog_descriptor) {
        structured_events_ = true;
        routing_catalog_window_version_ = 1;
      } else if (descriptor == kCoreCapabilities) {
        structured_events_ = true;
      } else if (descriptor != kLegacyCoreCapabilities) {
        return "core_capabilities_incompatible";
      }
    }

    if (structured_events_) {
      if (set_event_callback_ == nullptr || set_event_context_ == nullptr) {
        return "core_abi_incompatible";
      }
      run_id_ = NewUuid();
      attempt_id_ = NewUuid();
      generation_ = 1;
      if (run_id_.empty() || attempt_id_.empty() ||
          !event_fence_.Activate(run_id_, attempt_id_, generation_)) {
        return "core_event_context_failed";
      }
      {
        std::lock_guard<std::mutex> guard(callback_lock_);
        callback_runtime_ = this;
      }
      set_event_callback_(&InstalledCoreRuntime::ReceiveOperationalEvent);
      if (!StringResult(set_event_context_(run_id_.c_str(),
                                           attempt_id_.c_str(), generation_))
               .empty()) {
        set_event_callback_(nullptr);
        std::lock_guard<std::mutex> guard(callback_lock_);
        callback_runtime_ = nullptr;
        return "core_event_context_failed";
      }
    }

    const auto base = Utf8(directories.base);
    const auto working = Utf8(directories.working);
    const auto temporary = Utf8(directories.temporary);
    if (base.empty() || working.empty() || temporary.empty()) {
      return "runtime_path_invalid";
    }
    const auto error = StringResult(setup_(base.c_str(), working.c_str(),
                                           temporary.c_str(), 0, "", "", 0,
                                           false));
    if (!error.empty()) {
      return "core_setup_failed";
    }
    const auto read_transport_capabilities = reinterpret_cast<CapabilitiesFunction>(
        ::GetProcAddress(module_, "pokrovCoreTransportCapabilities"));
    if (read_transport_capabilities != nullptr) {
      char* value = read_transport_capabilities();
      if (value != nullptr) {
        std::size_t length = 0;
        while (length <= 4096 && value[length] != '\0') ++length;
        // Delimited service metadata must not admit field injection. The Dart
        // consumer additionally validates the closed inventory schema.
        if (length > 0 && length <= 4096 &&
            std::all_of(value, value + length, [](unsigned char character) {
              return character >= 32 && character <= 126 && character != ';';
            })) {
          transport_capabilities_json_.assign(value, length);
        }
        free_string_(value);
      }
    }
    initialized_ = true;
    return "";
  }

  std::string SecureFile(const std::wstring& path) override {
    const auto encoded = Utf8(path);
    if (!initialized_ || encoded.empty()) {
      return "core_not_initialized";
    }
    return StringResult(secure_file_(encoded.c_str())).empty()
               ? ""
               : "profile_security_failed";
  }

  std::string Start(const std::wstring& config_path,
                    bool disable_memory_limit) override {
    const auto encoded = Utf8(config_path);
    if (!initialized_ || encoded.empty()) {
      return "core_not_initialized";
    }
    if (structured_events_ && start_attempts_ > 0 && !BeginNextAttempt()) {
      return "core_event_context_failed";
    }
    ++start_attempts_;
    return StringResult(start_(encoded.c_str(), disable_memory_limit)).empty()
               ? ""
               : "core_start_failed";
  }

  bool SupportsInterruptibleStart() const override {
    return start_interruptible_ != nullptr;
  }

  std::string ProbeCandidate(const CandidateProbeRequest& request,
                             const std::string& bind_interface,
                             const CheckInterruption& interrupted) override {
    if (probe_candidate_ == nullptr || bind_interface.empty()) return "";
    const auto result = StringResult(probe_candidate_(request.config.c_str(), request.probe_id.c_str(),
        static_cast<int>(request.timeout_ms), bind_interface.c_str(),
        CheckCoreInterruption, const_cast<CheckInterruption*>(&interrupted)));
    if (events_ != nullptr) {
      // The verified Core ABI emits this canonical result only after its fixed
      // HTTPS endpoint returns 204. Keep profile/id/raw JSON out of the journal.
      constexpr char success_prefix[] = "{\"success\":true,\"failure_kind\":\"\",\"duration_ms\":";
      events_->Record(ServiceEvent::kRuntimeCandidateProbe,
          result.rfind(success_prefix, 0) == 0 ? ServiceEventOutcome::kSucceeded
                                             : ServiceEventOutcome::kFailed);
    }
    return result;
  }

  std::string StartInterruptible(const std::wstring& config_path,
                                bool disable_memory_limit,
                                const CheckInterruption& interrupted) override {
    const auto encoded = Utf8(config_path);
    if (!initialized_ || encoded.empty()) return "core_not_initialized";
    if (start_interruptible_ == nullptr || !interrupted) return "core_abi_incompatible";
    if (structured_events_ && start_attempts_ > 0 && !BeginNextAttempt()) {
      return "core_event_context_failed";
    }
    ++start_attempts_;
    // The DLL joins its callback observer before returning. This call-scoped
    // copy never survives the exact serial connect operation.
    auto check = interrupted;
    char* result = start_interruptible_(encoded.c_str(), disable_memory_limit,
                                       CheckCoreInterruption, &check);
    if (result == nullptr) return "core_start_failed";
    return StringResult(result).empty() ? "" : "core_start_failed";
  }

  std::string Stop() override {
    if (!initialized_) {
      return "";
    }
    return StringResult(stop_()).empty() ? "" : "core_stop_failed";
  }

 private:
  using EventCallback = void(__cdecl*)(
      int, int, const char*, const char*, const char*, long long, long long,
      const char*, const char*, const char*, const char*, const char*,
      const char*, const char*);
  using AbiFunction = int(__cdecl*)();
  using PrepareWindowsLocalDpiFunction = char*(__cdecl*)(const char*, const char*, const char*, const char*);
  using ReadLocalDpiAdmissionFunction = char*(__cdecl*)(const char*);
  using LocalDpiAdmissionFunction = int(__cdecl*)(const char*);
  using CapabilitiesFunction = char*(__cdecl*)();
  using RevokeSmartAccessFunction = int(__cdecl*)(const char*, int);
  using RenewSmartAccessFunction = int(__cdecl*)(const char*, const char*, const char*, const char*, const char*);
  using ConfigureSmartAccessControlFunction = int(__cdecl*)(const char*, const char*);
  using ConfirmATSLeaseFunction = int(__cdecl*)(const char*, const char*, const char*, const char*);
  using RevokeATSLeaseFunction = int(__cdecl*)(const char*, int);
  using AcknowledgeSmartAccessRestrictionsFunction = int(__cdecl*)(const char*);
  using RevokeCatalogFunction = int(__cdecl*)();
  using RevokeCatalogServiceFunction = int(__cdecl*)(const char*);
  using RevokeSmartAccessPolicyFunction = int(__cdecl*)(int);
  using SetEventCallbackFunction = void(__cdecl*)(EventCallback);
  using SetEventContextFunction = char*(__cdecl*)(const char*, const char*,
                                                  long long);
  using SetupFunction = char*(__cdecl*)(const char*, const char*, const char*,
                                        int, const char*, const char*,
                                        long long, bool);
  using SecureFileFunction = char*(__cdecl*)(const char*);
  using StartFunction = char*(__cdecl*)(const char*, bool);
  using InterruptionCallback = int(__cdecl*)(void*);
  using StartInterruptibleFunction = char*(__cdecl*)(const char*, bool,
                                                   InterruptionCallback, void*);
  using ProbeCandidateFunction = char*(__cdecl*)(const char*, const char*, int,
                                                 const char*, InterruptionCallback, void*);
  using ProbeSelectedOutboundFunction = char*(__cdecl*)(const char*);
  using ProbeRuntimeEgressFunction = char*(__cdecl*)(const char*, int, InterruptionCallback, void*);
  using StopFunction = char*(__cdecl*)();
  using FreeStringFunction = void(__cdecl*)(char*);

  static int __cdecl CheckCoreInterruption(void* owner) noexcept {
    try {
      const auto& check = *static_cast<const CheckInterruption*>(owner);
      return check() == OperationInterruption::kNone ? 0 : 1;
    } catch (...) {
      // Never unwind a C++ exception across the Go/C callback boundary.
      return 1;
    }
  }

  bool BeginNextAttempt() {
    const auto attempt_id = NewUuid();
    const auto generation = generation_ + 1;
    std::lock_guard<std::mutex> guard(callback_lock_);
    if (attempt_id.empty() || generation > INT_MAX ||
        !event_fence_.Activate(run_id_, attempt_id, generation)) {
      return false;
    }
    if (!StringResult(set_event_context_(run_id_.c_str(), attempt_id.c_str(),
                                         generation))
             .empty()) {
      return false;
    }
    attempt_id_ = attempt_id;
    generation_ = generation;
    return true;
  }

  static void __cdecl ReceiveOperationalEvent(
      int schema_version, int event_abi, const char* occurred_at_utc,
      const char* run_id, const char* attempt_id, long long generation,
      long long sequence, const char* name, const char* subsystem,
      const char* stage, const char* severity, const char* outcome,
      const char* error_code, const char* phase) {
    std::lock_guard<std::mutex> guard(callback_lock_);
    if (callback_runtime_ == nullptr || occurred_at_utc == nullptr ||
        run_id == nullptr || attempt_id == nullptr || name == nullptr ||
        subsystem == nullptr || stage == nullptr || severity == nullptr ||
        outcome == nullptr || error_code == nullptr || phase == nullptr) {
      return;
    }
    callback_runtime_->AcceptOperationalEvent(CoreOperationalEventRecord{
        schema_version,
        event_abi,
        occurred_at_utc,
        run_id,
        attempt_id,
        generation,
        sequence,
        name,
        subsystem,
        stage,
        severity,
        outcome,
        error_code,
        phase,
    });
  }

  void AcceptOperationalEvent(const CoreOperationalEventRecord& event) {
    if (!event_fence_.Accept(event)) return;
    if (events_ != nullptr) {
      events_->RecordCoreOperationalEvent(event);
    }
  }

  std::string StringResult(char* value) const {
    if (value == nullptr) {
      return "";
    }
    const std::string result(value);
    free_string_(value);
    return result;
  }

  HMODULE module_ = nullptr;
  AbiFunction abi_ = nullptr;
  CapabilitiesFunction capabilities_ = nullptr;
  AbiFunction windows_local_dpi_version_ = nullptr;
  PrepareWindowsLocalDpiFunction prepare_windows_local_dpi_ = nullptr;
  ReadLocalDpiAdmissionFunction read_local_dpi_admission_ = nullptr;
  LocalDpiAdmissionFunction admit_local_dpi_admission_ = nullptr;
  LocalDpiAdmissionFunction withdraw_local_dpi_admission_ = nullptr;
  ReadLocalDpiAdmissionFunction read_local_dpi_observation_ = nullptr;
  AbiFunction telegram_ws_version_ = nullptr;
  PrepareWindowsLocalDpiFunction prepare_telegram_ws_ = nullptr;
  ReadLocalDpiAdmissionFunction read_telegram_ws_ = nullptr;
  LocalDpiAdmissionFunction admit_telegram_ws_ = nullptr;
  LocalDpiAdmissionFunction withdraw_telegram_ws_ = nullptr;
  std::string transport_capabilities_json_;
  std::string core_module_sha256_;
  std::string core_version_;
  RevokeSmartAccessFunction revoke_smart_access_ = nullptr;
  RenewSmartAccessFunction renew_smart_access_ = nullptr;
  ConfigureSmartAccessControlFunction configure_smart_access_control_ = nullptr;
  ConfigureSmartAccessControlFunction configure_smart_access_renewal_ = nullptr;
  CapabilitiesFunction read_smart_access_restrictions_ = nullptr;
  CapabilitiesFunction read_smart_access_leases_ = nullptr;
  AcknowledgeSmartAccessRestrictionsFunction acknowledge_smart_access_restrictions_ = nullptr;
  ConfirmATSLeaseFunction confirm_ats_lease_ = nullptr;
  RevokeATSLeaseFunction revoke_ats_lease_ = nullptr;
  RevokeCatalogFunction revoke_catalog_ = nullptr;
  RevokeCatalogServiceFunction revoke_catalog_service_ = nullptr;
  RevokeSmartAccessPolicyFunction revoke_smart_access_policy_ = nullptr;
  int routing_catalog_control_version_ = 0;
  int routing_catalog_window_version_ = 0;
  int smart_access_lease_version_ = 0;
  int smart_access_probe_version_ = 0;
  SetEventCallbackFunction set_event_callback_ = nullptr;
  SetEventContextFunction set_event_context_ = nullptr;
  SetupFunction setup_ = nullptr;
  SecureFileFunction secure_file_ = nullptr;
  StartFunction start_ = nullptr;
  StartInterruptibleFunction start_interruptible_ = nullptr;
  ProbeCandidateFunction probe_candidate_ = nullptr;
  ProbeSelectedOutboundFunction probe_selected_outbound_ = nullptr;
  ProbeRuntimeEgressFunction probe_runtime_egress_ = nullptr;
  StopFunction stop_ = nullptr;
  FreeStringFunction free_string_ = nullptr;
  ServiceEventSink* events_ = nullptr;
  CoreOperationalEventFence event_fence_;
  std::string run_id_;
  std::string attempt_id_;
  std::int64_t generation_ = 0;
  int start_attempts_ = 0;
  bool structured_events_ = false;
  bool initialized_ = false;
  static std::mutex callback_lock_;
  static InstalledCoreRuntime* callback_runtime_;
};

std::mutex InstalledCoreRuntime::callback_lock_;
InstalledCoreRuntime* InstalledCoreRuntime::callback_runtime_ = nullptr;

}  // namespace

bool CoreDescriptorHasRuntimeControl(const std::string& descriptor) {
  std::string compatible(descriptor);
  const std::string observation_field = "\"windows_local_dpi_observation_version\":1,";
  const auto observation_position = compatible.find(observation_field);
  if (observation_position != std::string::npos &&
      compatible.find("\"windows_local_dpi_admission_version\":1,") == std::string::npos) return false;
  if (observation_position != std::string::npos) compatible.erase(observation_position, observation_field.size());
  const std::string probe_field = "\"smart_access_probe_version\":1,";
  const auto probe_position = compatible.find(probe_field);
  if (probe_position != std::string::npos) compatible.erase(probe_position, probe_field.size());
  std::string runtime_control(kCoreCapabilities);
  runtime_control.insert(runtime_control.find("\"capabilities\""),
      "\"routing_catalog_window_version\":1,\"smart_access_lease_version\":1,"
      "\"smart_access_runtime_control_version\":1,\"routing_catalog_control_version\":4,");
  if (compatible == runtime_control) return true;
  // Core 1.2.2 adds platform admission metadata; ordinary Windows runtime
  // compatibility does not grant Windows DPI execution capability.
  runtime_control.insert(runtime_control.find("\"capabilities\""),
      "\"local_dpi_admission_version\":1,");
  if (compatible == runtime_control) return true;
  runtime_control.insert(runtime_control.find("\"capabilities\""),
      "\"windows_local_dpi_admission_version\":1,");
  if (compatible == runtime_control) return true;
  runtime_control.insert(runtime_control.find("\"capabilities\""),
      "\"telegram_ws_admission_version\":1,");
  return compatible == runtime_control;
}

bool CoreDescriptorHasSmartAccessProbe(const std::string& descriptor) {
  return descriptor.find("\"smart_access_probe_version\":1,") != std::string::npos &&
      CoreDescriptorHasRuntimeControl(descriptor);
}

bool CoreDescriptorHasWindowsLocalDpi(const std::string& descriptor) {
  const auto field = descriptor.find("\"windows_local_dpi_admission_version\":1,");
  return field != std::string::npos && CoreDescriptorHasRuntimeControl(descriptor);
}

bool CoreDescriptorHasTelegramWS(const std::string& descriptor) {
  return descriptor.find("\"telegram_ws_admission_version\":1,") != std::string::npos &&
      CoreDescriptorHasRuntimeControl(descriptor);
}

bool CoreOperationalEventFence::Activate(const std::string& run_id,
                                         const std::string& attempt_id,
                                         std::int64_t generation) {
  if (!IsLowerUuid(run_id) || !IsLowerUuid(attempt_id) || generation < 1 ||
      generation > INT_MAX || generation < generation_) {
    return false;
  }
  if (generation > generation_) {
    last_sequence_ = 0;
  }
  if (run_id != run_id_ || attempt_id != attempt_id_ || generation != generation_) {
    first_owned_dns_state_ = FirstOwnedDnsState::kUnknown;
  }
  run_id_ = run_id;
  attempt_id_ = attempt_id;
  generation_ = generation;
  return true;
}

bool CoreOperationalEventFence::Accept(
    const CoreOperationalEventRecord& event) {
  if (event.schema_version != 1 || event.event_abi != 1 ||
      event.run_id != run_id_ || event.attempt_id != attempt_id_ ||
      event.generation != generation_ || event.sequence <= last_sequence_ ||
      !IsUtcTimestamp(event.occurred_at_utc) ||
      !IsCoreEventDefinition(event)) {
    return false;
  }
  const bool failed = event.outcome == "failed";
  if ((event.outcome != "started" && event.outcome != "succeeded" &&
       !failed) ||
      (failed &&
       (event.severity != "error" || !IsCoreErrorCode(event.error_code))) ||
      (!failed &&
       (event.severity != "info" || !event.error_code.empty()))) {
    return false;
  }
  if (event.name == "core.dns.probe") {
    if ((event.stage == "receive" && event.outcome != "started") ||
        (event.stage != "receive" && event.outcome == "started") ||
        (failed && event.error_code != "DNS-002")) return false;
    if (event.stage == "receive") first_owned_dns_state_ = FirstOwnedDnsState::kReceived;
    else if (event.stage == "exchange" && failed) first_owned_dns_state_ = FirstOwnedDnsState::kExchangeFailed;
    else if (event.stage == "reply") first_owned_dns_state_ = failed
        ? FirstOwnedDnsState::kReplyFailed : FirstOwnedDnsState::kReplyWritten;
  }
  last_sequence_ = event.sequence;
  return true;
}

RuntimeHost::RuntimeHost(std::unique_ptr<CoreRuntime> core,
                         std::unique_ptr<RuntimeEgressProbe> egress_probe,
                         std::unique_ptr<RuntimeRecovery> recovery,
                         std::wstring runtime_root, bool secure_storage,
                         ServiceEventSink* events,
                         std::unique_ptr<RuntimeTransitionGuard> transition_guard)
    : core_(std::move(core)),
      egress_probe_(std::move(egress_probe)),
      recovery_(std::move(recovery)),
      transition_guard_(std::move(transition_guard)),
      runtime_root_(std::move(runtime_root)),
      events_(events),
      secure_storage_(secure_storage) {
  if (core_ != nullptr) {
    core_->SetOperationalEventSink(events_);
    // Inert until a native proof/currentness integration supplies a prepared
    // plan. Asset existence alone never exposes a user activation path.
    local_dpi_executor_ = std::make_unique<WindowsLocalDpiExecutor>(*core_);
  }
  if (core_ != nullptr && !runtime_root_.empty()) {
    phase_ = Phase::kArtifactReady;
    failure_.clear();
  }
}

RuntimeHost::~RuntimeHost() { Shutdown(); }

RuntimeResult RuntimeHost::Snapshot() const {
  return RuntimeResult{Status::kOk, SnapshotBody()};
}

RuntimeResult RuntimeHost::PendingSnapshot(Command command) const {
  return RuntimeResult{Status::kOk,
      SnapshotBody(IsConnectCommand(command) ? "connecting" : "busy")};
}

RuntimeResult RuntimeHost::RecoverOnStartup() {
  if (recovery_ == nullptr || !recovery_->RequiresRecovery()) {
    return Snapshot();
  }
  return Initialize();
}

RuntimeResult RuntimeHost::Initialize() {
  if (initialized_) {
    return Snapshot();
  }
  if (core_ == nullptr || runtime_root_.empty()) {
    RecordEvent(ServiceEvent::kRuntimeInitialize,
                ServiceEventOutcome::kFailed);
    return Fail(Status::kNotReady, "core_missing");
  }
  RecordEvent(ServiceEvent::kRuntimeInitialize,
              ServiceEventOutcome::kAttempted);
  if (!PrepareDirectories()) {
    RecordEvent(ServiceEvent::kRuntimeInitialize,
                ServiceEventOutcome::kFailed);
    return Fail(Status::kNotReady, "runtime_directory_failed");
  }
  const auto error = core_->Initialize(directories_);
  if (!error.empty()) {
    RecordEvent(ServiceEvent::kRuntimeInitialize,
                ServiceEventOutcome::kFailed);
    return Fail(Status::kNotReady, error.c_str());
  }
  initialized_ = true;
  phase_ = Phase::kInitialized;
  const auto recovery_error = RecoverPendingRuntime();
  if (!recovery_error.empty()) {
    phase_ = Phase::kRecoveryRequired;
    RecordEvent(ServiceEvent::kRuntimeRecoveryRequired,
                ServiceEventOutcome::kFailed);
    RecordEvent(ServiceEvent::kRuntimeInitialize,
                ServiceEventOutcome::kFailed);
    return Fail(Status::kNotReady, recovery_error.c_str());
  }
  failure_.clear();
  RecordEvent(ServiceEvent::kRuntimeInitialize,
              ServiceEventOutcome::kSucceeded);
  local_dpi_ready_ = kWindowsCatalogTrustEnabled && transition_guard_ != nullptr &&
      core_->WindowsLocalDpiAdmissionVersion() == 1 && local_dpi_executor_->AssetsReady();
  telegram_ws_ready_ = kWindowsCatalogTrustEnabled && core_->TelegramWSAdmissionVersion() == 1;
  return Snapshot();
}

RuntimeResult RuntimeHost::StageProfile(const std::string& body, bool requires_bound_connect) {
  RecordEvent(ServiceEvent::kRuntimeProfileStage,
              ServiceEventOutcome::kAttempted);
  if (!initialized_) {
    const auto initialized = Initialize();
    if (initialized.status != Status::kOk) {
      RecordEvent(ServiceEvent::kRuntimeProfileStage,
                  ServiceEventOutcome::kFailed);
      return initialized;
    }
  }
  if (phase_ == Phase::kRunning || phase_ == Phase::kRecoveryRequired ||
      body.size() < 4 ||
      (body[0] != '0' && body[0] != '1') || body[1] != '\n') {
    RecordEvent(ServiceEvent::kRuntimeProfileStage,
                ServiceEventOutcome::kFailed);
    return Fail(Status::kInvalid, "profile_request_invalid");
  }
  const auto profile_digest = ProfileDigest(body);
  if (profile_digest.empty()) {
    return Fail(Status::kNotReady, "profile_identity_failed");
  }
  ParsedProfileBundle bundle;
  if (!ParseProfilePayload(body.substr(2), &bundle)) {
    RecordEvent(ServiceEvent::kRuntimeProfileStage,
                ServiceEventOutcome::kFailed);
    return Fail(Status::kInvalid, "profile_payload_invalid");
  }
  std::string profile = std::move(bundle.profile);
  const int staged_rule_set_slot = bundle.rule_sets.empty()
                                       ? 0
                                       : (bundled_rule_set_slot_ == 1 ? 2 : 1);
  std::vector<std::wstring> staged_rule_set_paths;
  if (staged_rule_set_slot != 0) {
    ReplaceAll(&profile, kRuleSetSlotMarker,
               staged_rule_set_slot == 1 ? "profile-a" : "profile-b");
  }
  if (!IsValidUtf8JsonObject(profile)) {
    RecordEvent(ServiceEvent::kRuntimeProfileStage,
                ServiceEventOutcome::kFailed);
    return Fail(Status::kInvalid, "profile_payload_invalid");
  }
  if (staged_rule_set_slot != 0 &&
      !WriteBundledRuleSets(staged_rule_set_slot, bundle.rule_sets,
                            &staged_rule_set_paths)) {
    RecordEvent(ServiceEvent::kRuntimeProfileStage,
                ServiceEventOutcome::kFailed);
    return Fail(Status::kNotReady, "profile_write_failed");
  }
  for (const auto& path : staged_rule_set_paths) {
    if (!core_->SecureFile(path).empty()) {
      CleanupBundledRuleSets(staged_rule_set_slot);
      RecordEvent(ServiceEvent::kRuntimeProfileStage,
                  ServiceEventOutcome::kFailed);
      return Fail(Status::kNotReady, "profile_security_failed");
    }
  }
  std::string runtime_copy;
  bool requests_local_dpi = false;
  bool requests_telegram_ws = false;
  if (!StripWindowsLocalDpiMetadata(profile, &runtime_copy, &requests_local_dpi, &requests_telegram_ws)) {
    CleanupBundledRuleSets(staged_rule_set_slot);
    return Fail(Status::kInvalid, "profile_payload_invalid");
  }
  const auto profile_error = WriteProfileAtomically(runtime_copy);
  if (!profile_error.empty()) {
    CleanupBundledRuleSets(staged_rule_set_slot);
    RecordEvent(ServiceEvent::kRuntimeProfileStage,
                ServiceEventOutcome::kFailed);
    return Fail(Status::kNotReady, profile_error.c_str());
  }
  disable_memory_limit_ = body[0] == '1';
  const int previous_rule_set_slot = bundled_rule_set_slot_;
  bundled_rule_set_slot_ = staged_rule_set_slot;
  if (previous_rule_set_slot != 0 &&
      previous_rule_set_slot != bundled_rule_set_slot_) {
    CleanupBundledRuleSets(previous_rule_set_slot);
  }
  staged_profile_digest_ = profile_digest;
  original_staged_config_ = std::move(profile);
  staged_runtime_config_ = std::move(runtime_copy);
  local_dpi_requested_ = requests_local_dpi;
  telegram_ws_requested_ = requests_telegram_ws;
  requires_bound_connect_ = requires_bound_connect;
  effective_profile_digest_.clear();
  profile_staged_ = true;
  egress_failure_observation_.reset();
  phase_ = Phase::kConfigStaged;
  failure_.clear();
  RecordEvent(ServiceEvent::kRuntimeProfileStage,
              ServiceEventOutcome::kSucceeded);
  return Snapshot();
}

RuntimeResult RuntimeHost::InvalidateProfile() {
  if (phase_ == Phase::kRunning) {
    return Fail(Status::kNotReady, "runtime_running");
  }
  if (phase_ == Phase::kRecoveryRequired) {
    return Fail(Status::kNotReady, "recovery_required");
  }
  if (local_dpi_executor_ && !local_dpi_executor_->Stop()) {
    return Fail(Status::kNotReady, "local_dpi_withdraw_failed");
  }
  local_dpi_preparation_.reset();
  telegram_ws_preparation_.reset();
  telegram_ws_holders_.clear();
  original_staged_config_.clear();
  staged_runtime_config_.clear();
  local_dpi_requested_ = false;
  telegram_ws_requested_ = false;
  if (!profile_path_.empty()) {
    ::DeleteFileW(profile_path_.c_str());
  }
  CleanupBundledRuleSets(bundled_rule_set_slot_);
  bundled_rule_set_slot_ = 0;
  profile_staged_ = false;
  requires_bound_connect_ = false;
  staged_profile_digest_.clear();
  effective_profile_digest_.clear();
  disable_memory_limit_ = false;
  phase_ = initialized_ ? Phase::kInitialized : Phase::kArtifactReady;
  failure_.clear();
  return Snapshot();
}

RuntimeResult RuntimeHost::Connect(const std::string& expected_profile_digest,
                                  const CheckInterruption& interrupted,
                                  const std::optional<CandidateNetworkContext>& local_dpi_network,
                                  const CheckInterruption& telegram_interrupted) {
  if (requires_bound_connect_) return Fail(Status::kNotReady, "profile_identity_mismatch");
  return ConnectImpl(expected_profile_digest, interrupted, "", true, local_dpi_network, telegram_interrupted);
}

RuntimeResult RuntimeHost::ConnectWithIdentity(const BoundConnectTarget& target,
                                              const CheckInterruption& interrupted,
                                              const std::optional<CandidateNetworkContext>& local_dpi_network,
                                              const CheckInterruption& telegram_interrupted) {
  if (EncodeBoundConnect(target).empty()) return {Status::kInvalid, "invalid_connect_identity"};
  if (phase_ == Phase::kRunning || phase_ == Phase::kRecoveryRequired) {
    return {Status::kNotReady, "runtime_busy"};
  }
  return ConnectImpl(target.profile_digest, [&target, &interrupted] {
    const auto pending = interrupted ? interrupted() : OperationInterruption::kNone;
    if (pending != OperationInterruption::kNone) return pending;
    return IsConnectDeadlineCurrent(target) ? OperationInterruption::kNone
                                           : OperationInterruption::kDeadlineExceeded;
  }, target.core_module_sha256, true, local_dpi_network, telegram_interrupted);
}

RuntimeResult RuntimeHost::PromoteTransportLease(const TransportLeasePromotion& target) {
  if (EncodeTransportLeasePromotion(target).empty() || !initialized_ ||
      phase_ != Phase::kRunning || !requires_bound_connect_ ||
      effective_profile_digest_ != target.profile_digest ||
      core_->ConfirmATSLease(target) != 1) {
    return {Status::kNotReady, "transport_lease_handoff_unconfirmed"};
  }
  core_egress_validated_ = true;
  return Snapshot();
}

RuntimeResult RuntimeHost::RevokeTransportLease(const TransportLeaseRevocation& target) {
  if (EncodeTransportLeaseRevocation(target).empty() || !initialized_ ||
      phase_ != Phase::kRunning || !requires_bound_connect_ ||
      effective_profile_digest_ != target.profile_digest) {
    return {Status::kNotReady, "transport_lease_revocation_unconfirmed"};
  }
  core_egress_validated_ = false;
  if (core_->RevokeATSLease(target) != 1) {
    return {Status::kNotReady, "transport_lease_revocation_unconfirmed"};
  }
  return Snapshot();
}

RuntimeResult RuntimeHost::ConnectImpl(const std::string& expected_profile_digest,
                                      const CheckInterruption& interrupted,
                                      const std::string& expected_core_digest,
                                      bool finish_transition_guard,
                                      const std::optional<CandidateNetworkContext>& local_dpi_network,
                                      const CheckInterruption& telegram_interrupted) {
  // Core and network state stay on this serial owner. An interruption never
  // races Stop against Start, and rollback must finish even after the deadline.
  const auto interruption = [&](bool rollback) -> std::optional<RuntimeResult> {
    const auto reason =
        interrupted ? interrupted() : OperationInterruption::kNone;
    const bool identity_mismatch = !expected_core_digest.empty() &&
        core_->CoreModuleSHA256() != expected_core_digest;
    if (reason == OperationInterruption::kNone && !identity_mismatch) return std::nullopt;
    if (rollback) {
      const auto error = RollbackRuntime();
      effective_profile_digest_.clear();
      core_egress_validated_ = false;
      phase_ = error.empty() ? Phase::kConfigStaged : Phase::kRecoveryRequired;
      if (!error.empty()) {
        RecordEvent(ServiceEvent::kRuntimeRecoveryRequired,
                    ServiceEventOutcome::kFailed);
        return Fail(Status::kNotReady, error.c_str());
      }
    }
    if (identity_mismatch) return Fail(Status::kNotReady, "core_identity_mismatch");
    return reason == OperationInterruption::kDeadlineExceeded
               ? Fail(Status::kDeadlineExceeded, expected_core_digest.empty() ? "deadline_exceeded" : "connect_deadline")
               : Fail(Status::kNotReady, "operation_cancelled");
  };
  if (!initialized_ || !profile_staged_) {
    return Fail(Status::kNotReady, "profile_not_staged");
  }
  if (!IsProfileDigest(expected_profile_digest) ||
      expected_profile_digest != staged_profile_digest_) {
    return Fail(Status::kNotReady, "profile_identity_mismatch");
  }
  if (const auto result = interruption(false)) return *result;
  if (!expected_core_digest.empty() && !core_->SupportsInterruptibleStart()) {
    return Fail(Status::kNotReady, "core_abi_incompatible");
  }
  if (phase_ == Phase::kRunning) {
    return Snapshot();
  }
  if (phase_ == Phase::kRecoveryRequired) {
    return Fail(Status::kNotReady, "recovery_required");
  }
  if (recovery_ == nullptr) {
    return Fail(Status::kNotReady, "recovery_unavailable");
  }
  egress_failure_observation_.reset();
  local_dpi_preparation_.reset();
  first_provider_qa_control_config_.clear();
  first_provider_qa_admission_result_.reset();
  const auto staged_write_error = WriteProfileAtomically(staged_runtime_config_);
  if (!staged_write_error.empty()) return Fail(Status::kNotReady, staged_write_error.c_str());
  // Native compiled trust and the captured physical interface are the only
  // inputs to preparation. Stored/staged identity remains the original bytes.
  std::string prepared_config = original_staged_config_;
  telegram_ws_preparation_.reset();
  telegram_ws_holders_.clear();
  if (telegram_ws_requested_ && telegram_ws_ready_ && local_dpi_network &&
      !local_dpi_network->bind_interface.empty()) {
    auto prepared = ReadWindowsTelegramWSPreparation(core_->PrepareTelegramWSProfile(
        prepared_config, kWindowsCatalogPublicKeys, kWindowsCatalogAudience,
        local_dpi_network->bind_interface));
    if (prepared && !core_->CoreModuleSHA256().empty()) {
      prepared_config = prepared->profile;  // Signed metadata remains private for DPI composition.
      telegram_ws_preparation_ = std::make_unique<WindowsTelegramWSPreparation>(std::move(*prepared));
      telegram_ws_original_digest_ = staged_profile_digest_;
      telegram_ws_core_digest_ = core_->CoreModuleSHA256();
    }
  }
  if (local_dpi_requested_ && local_dpi_ready_ && local_dpi_network &&
      !local_dpi_network->bind_interface.empty()) {
    auto prepared = ReadWindowsLocalDpiPreparation(core_->PrepareWindowsLocalDpiProfile(
        prepared_config, kWindowsCatalogPublicKeys, kWindowsCatalogAudience,
        local_dpi_network->bind_interface));
    if (prepared && !core_->CoreModuleSHA256().empty()) {
      if (!TransitionGuardArmed() && !transition_guard_->Start().empty()) {
        return Fail(Status::kNotReady, "transition_guard_failed");
      }
      prepared_config = prepared->profile;
      local_dpi_preparation_ = std::make_unique<WindowsLocalDpiPreparation>(std::move(*prepared));
      local_dpi_disabled_ = false;
      local_dpi_profile_digest_ = staged_profile_digest_;
      local_dpi_core_digest_ = core_->CoreModuleSHA256();
    }
  }
  if (telegram_ws_preparation_ || local_dpi_preparation_) {
    std::string final_profile;
    bool ignored = false;
    if (!StripWindowsLocalDpiMetadata(prepared_config, &final_profile, &ignored))
      return Fail(Status::kInvalid, "profile_payload_invalid");
    const auto write_error = WriteProfileAtomically(final_profile);
    if (!write_error.empty()) return Fail(Status::kNotReady, write_error.c_str());
    if (telegram_ws_preparation_) {
      telegram_ws_preparation_->profile = final_profile;
      telegram_ws_prepared_digest_ = ProfileDigest(final_profile);
      if (telegram_ws_prepared_digest_.empty()) return Fail(Status::kNotReady, "profile_identity_failed");
    }
  }
  RecordEvent(ServiceEvent::kRuntimeNetworkSnapshot,
              ServiceEventOutcome::kAttempted);
  auto recovery_error = recovery_->Begin();
  if (!recovery_error.empty()) {
    RecordEvent(ServiceEvent::kRuntimeNetworkSnapshot,
                ServiceEventOutcome::kFailed);
    return Fail(Status::kNotReady, recovery_error.c_str());
  }
  RecordEvent(ServiceEvent::kRuntimeNetworkSnapshot,
              ServiceEventOutcome::kSucceeded);
  if (const auto result = interruption(true)) return *result;
  recovery_error = recovery_->Record(RecoveryStage::kCoreStarted);
  if (!recovery_error.empty()) {
    const auto rollback_error = RollbackRuntime();
    phase_ = rollback_error.empty() ? Phase::kConfigStaged
                                    : Phase::kRecoveryRequired;
    if (!rollback_error.empty()) {
      RecordEvent(ServiceEvent::kRuntimeRecoveryRequired,
                  ServiceEventOutcome::kFailed);
      return Fail(Status::kNotReady, rollback_error.c_str());
    }
    return Fail(Status::kNotReady, recovery_error.c_str());
  }
  if (const auto result = interruption(true)) return *result;
  RecordEvent(ServiceEvent::kRuntimeCoreStart,
              ServiceEventOutcome::kAttempted);
  RecordEvent(ServiceEvent::kRuntimeWintunStart,
              ServiceEventOutcome::kAttempted);
  RecordEvent(ServiceEvent::kRuntimeAdapterApply,
              ServiceEventOutcome::kAttempted);
  RecordEvent(ServiceEvent::kRuntimeRouteApply,
              ServiceEventOutcome::kAttempted);
  RecordEvent(ServiceEvent::kRuntimeDnsApply,
              ServiceEventOutcome::kAttempted);
  if (const auto result = interruption(true)) return *result;
  const auto start_error = expected_core_digest.empty()
      ? core_->Start(profile_path_, disable_memory_limit_)
      : core_->StartInterruptible(profile_path_, disable_memory_limit_, interrupted);
  if (!start_error.empty()) {
    if (const auto result = interruption(true)) return *result;
    RecordEvent(ServiceEvent::kRuntimeCoreStart,
                ServiceEventOutcome::kFailed);
    RecordEvent(ServiceEvent::kRuntimeWintunStart,
                ServiceEventOutcome::kFailed);
    RecordEvent(ServiceEvent::kRuntimeAdapterApply,
                ServiceEventOutcome::kFailed);
    RecordEvent(ServiceEvent::kRuntimeRouteApply,
                ServiceEventOutcome::kFailed);
    RecordEvent(ServiceEvent::kRuntimeDnsApply,
                ServiceEventOutcome::kFailed);
    const auto rollback_error = RollbackRuntime();
    phase_ = rollback_error.empty() ? Phase::kConfigStaged
                                    : Phase::kRecoveryRequired;
    if (!rollback_error.empty()) {
      RecordEvent(ServiceEvent::kRuntimeRecoveryRequired,
                  ServiceEventOutcome::kFailed);
      return Fail(Status::kNotReady, rollback_error.c_str());
    }
    return Fail(Status::kNotReady, "core_start_failed");
  }
  if (const auto result = interruption(true)) return *result;
  std::optional<WindowsLocalDpiStrategy> proved_local_dpi_strategy;
  const auto local_dpi_owner_current = [&] {
    return local_dpi_preparation_ &&
        (!interrupted || interrupted() == OperationInterruption::kNone) &&
        staged_profile_digest_ == local_dpi_profile_digest_ &&
        core_->CoreModuleSHA256() == local_dpi_core_digest_ &&
        WindowsLocalDpiPreparationCurrent(*local_dpi_preparation_);
  };
  const auto local_dpi_current = [&] {
    return local_dpi_owner_current() && local_dpi_executor_->Alive();
  };
  if (local_dpi_preparation_) {
    std::array<WindowsLocalDpiStrategy, 2> strategies{
        WindowsLocalDpiStrategy::kMultisplit568, WindowsLocalDpiStrategy::kMultisplit681};
    if (local_dpi_success_strategy_ &&
        local_dpi_success_strategy_->first == local_dpi_network->selection_key &&
        local_dpi_success_strategy_->second == strategies[1]) {
      std::swap(strategies[0], strategies[1]);
    }
    bool proved = false;
    WindowsLocalDpiStrategy successful_strategy = strategies[0];
    for (std::size_t attempt = 0; attempt < strategies.size(); ++attempt) {
      if (!local_dpi_owner_current()) break;
      const auto dpi_start_error = attempt == 0
          ? local_dpi_executor_->StartPrepared(local_dpi_preparation_->services,
                local_dpi_network->bind_interface, strategies[attempt])
          : local_dpi_executor_->RetryPrepared(local_dpi_preparation_->services,
                local_dpi_network->bind_interface, strategies[attempt]);
      if (!dpi_start_error.empty()) break;
      if (attempt == 0) {
        for (auto& service : local_dpi_preparation_->services) {
          service.captured_admission_id = local_dpi_executor_->CapturedAdmissionID(service.outbound_tag);
        }
      }
      proved = true;
      for (const auto& service : local_dpi_preparation_->services) {
        if (!local_dpi_current() ||
            !VerifyWindowsLocalDpiControlHost(service.control_host,
                local_dpi_network->bind_interface, interrupted).empty() || !local_dpi_current()) {
          proved = false;
          break;
        }
      }
      if (proved) { successful_strategy = strategies[attempt]; break; }
    }
    // Both trials retain unpublished holders. Publish only after every proof
    // succeeds; admission failure must never reopen a terminal holder.
    if (proved) {
      for (const auto& service : local_dpi_preparation_->services) {
        if (!local_dpi_current() ||
            !local_dpi_executor_->AdmitCaptured(service.outbound_tag, local_dpi_current)) {
          proved = false;
          break;
        }
      }
    }
    if (proved) proved_local_dpi_strategy = successful_strategy;
    if (!proved && !local_dpi_executor_->Stop()) {
      const auto rollback_error = RollbackRuntime();
      phase_ = rollback_error.empty() ? Phase::kConfigStaged : Phase::kRecoveryRequired;
      return Fail(Status::kNotReady, rollback_error.empty() ? "local_dpi_withdraw_failed" : rollback_error.c_str());
    }
    if (!proved) local_dpi_disabled_ = true;
    // Keep the signed expiry owner even after failed proof: the prepared
    // catalog rows must never outlive their window into route.final direct.
    if (!WindowsLocalDpiPreparationCurrent(*local_dpi_preparation_)) {
      const auto rollback_error = RollbackRuntime();
      phase_ = rollback_error.empty() ? Phase::kConfigStaged : Phase::kRecoveryRequired;
      return Fail(Status::kNotReady, rollback_error.empty() ? "local_dpi_catalog_expired" : rollback_error.c_str());
    }
  }
  recovery_error = recovery_->Record(RecoveryStage::kNetworkApplied);
  if (!recovery_error.empty()) {
    RecordEvent(ServiceEvent::kRuntimeCoreStart,
                ServiceEventOutcome::kSucceeded);
    RecordEvent(ServiceEvent::kRuntimeWintunStart,
                ServiceEventOutcome::kFailed);
    RecordEvent(ServiceEvent::kRuntimeAdapterApply,
                ServiceEventOutcome::kFailed);
    RecordEvent(ServiceEvent::kRuntimeRouteApply,
                ServiceEventOutcome::kFailed);
    RecordEvent(ServiceEvent::kRuntimeDnsApply,
                ServiceEventOutcome::kFailed);
    const auto rollback_error = RollbackRuntime();
    phase_ = rollback_error.empty() ? Phase::kConfigStaged
                                    : Phase::kRecoveryRequired;
    if (!rollback_error.empty()) {
      RecordEvent(ServiceEvent::kRuntimeRecoveryRequired,
                  ServiceEventOutcome::kFailed);
      return Fail(Status::kNotReady, rollback_error.c_str());
    }
    return Fail(Status::kNotReady, recovery_error.c_str());
  }
  RecordEvent(ServiceEvent::kRuntimeCoreStart,
              ServiceEventOutcome::kSucceeded);
  RecordEvent(ServiceEvent::kRuntimeWintunStart,
              ServiceEventOutcome::kSucceeded);
  RecordEvent(ServiceEvent::kRuntimeAdapterApply,
              ServiceEventOutcome::kSucceeded);
  RecordEvent(ServiceEvent::kRuntimeRouteApply,
              ServiceEventOutcome::kSucceeded);
  RecordEvent(ServiceEvent::kRuntimeDnsApply,
              ServiceEventOutcome::kSucceeded);
  if (const auto result = interruption(true)) return *result;
  if (!requires_bound_connect_) {
    RecordEvent(ServiceEvent::kRuntimeEgressVerify,
                ServiceEventOutcome::kAttempted);
    const auto egress_failure = VerifyEgress(false, interrupted);
    if (const auto result = interruption(true)) return *result;
    if (!egress_failure.empty()) {
      RecordEvent(ServiceEvent::kRuntimeEgressVerify,
                  ServiceEventOutcome::kFailed);
      const auto rollback_error = RollbackRuntime();
      effective_profile_digest_.clear();
      core_egress_validated_ = false;
      phase_ = rollback_error.empty() ? Phase::kConfigStaged
                                      : Phase::kRecoveryRequired;
      if (!rollback_error.empty()) {
        RecordEvent(ServiceEvent::kRuntimeRecoveryRequired,
                    ServiceEventOutcome::kFailed);
        return Fail(Status::kNotReady, rollback_error.c_str());
      }
      return Fail(Status::kNotReady, SafeEgressFailure(egress_failure));
    }
    RecordEvent(ServiceEvent::kRuntimeEgressVerify,
                ServiceEventOutcome::kSucceeded);
  }
  RecordEvent(ServiceEvent::kRuntimeCommit,
              ServiceEventOutcome::kAttempted);
  recovery_error = recovery_->Record(RecoveryStage::kVerified);
  if (recovery_error.empty()) {
    if (const auto result = interruption(true)) return *result;
    recovery_error = recovery_->Record(RecoveryStage::kCommitted);
  }
  if (!recovery_error.empty()) {
    RecordEvent(ServiceEvent::kRuntimeCommit,
                ServiceEventOutcome::kFailed);
    const auto rollback_error = RollbackRuntime();
    effective_profile_digest_.clear();
    core_egress_validated_ = false;
    phase_ = rollback_error.empty() ? Phase::kConfigStaged
                                    : Phase::kRecoveryRequired;
    if (!rollback_error.empty()) {
      RecordEvent(ServiceEvent::kRuntimeRecoveryRequired,
                  ServiceEventOutcome::kFailed);
      return Fail(Status::kNotReady, rollback_error.c_str());
    }
    return Fail(Status::kNotReady, recovery_error.c_str());
  }
  if (const auto result = interruption(true)) return *result;
  // The ordinary egress gate completes over the encrypted fallback. TG owner
  // loss during that gate only prevents TG admission, never rolls back VPN/DPI.
  if (telegram_ws_preparation_) {
    const auto current = [&] {
      return (!interrupted || interrupted() == OperationInterruption::kNone) &&
          (!telegram_interrupted || telegram_interrupted() == OperationInterruption::kNone) &&
          staged_profile_digest_ == telegram_ws_original_digest_ &&
          core_->CoreModuleSHA256() == telegram_ws_core_digest_ &&
          WindowsTelegramWSPreparationCurrent(*telegram_ws_preparation_) &&
          ProfileDigest(telegram_ws_preparation_->profile) == telegram_ws_prepared_digest_;
    };
    bool admitted = current();
    for (const auto& service : telegram_ws_preparation_->services) {
      const auto id = core_->ReadTelegramWSAdmissionID(service.second);
      if (id.empty()) { admitted = false; break; }
      telegram_ws_holders_.emplace_back(service.second, id);
    }
    for (const auto& holder : telegram_ws_holders_) {
      if (!admitted || !current() || core_->ReadTelegramWSAdmissionID(holder.first) != holder.second ||
          core_->AdmitTelegramWSAdmission(holder.second) != 1 || !current() ||
          core_->ReadTelegramWSAdmissionID(holder.first) != holder.second) {
        admitted = false;
        break;
      }
    }
    if (!admitted) WithdrawTelegramWS();  // Only TG latches; ordinary VPN and DPI continue.
  }
  effective_profile_digest_ = staged_profile_digest_;
  core_egress_validated_ = !requires_bound_connect_;
  phase_ = Phase::kRunning;
  failure_.clear();
  RecordEvent(ServiceEvent::kRuntimeCommit,
              ServiceEventOutcome::kSucceeded);
  if (finish_transition_guard && core_egress_validated_ && TransitionGuardArmed() &&
      !transition_guard_->Finish().empty()) {
    core_egress_validated_ = false;
    return Fail(Status::kNotReady, "transition_guard_failed");
  }
  if (proved_local_dpi_strategy && local_dpi_network && local_dpi_current()) {
    local_dpi_success_strategy_ = std::make_pair(local_dpi_network->selection_key, *proved_local_dpi_strategy);
  }
  return Snapshot();
}

RuntimeResult RuntimeHost::RevokeSmartAccessLease(const std::string& body) {
  const auto target = DecodeSmartAccessRevocation(body);
  if (!target) return {Status::kInvalid, "invalid_smart_access_revocation"};
  if (!initialized_ || phase_ != Phase::kRunning ||
      effective_profile_digest_ != target->profile_digest) {
    return {Status::kNotReady, "smart_access_profile_changed"};
  }
  const auto result = core_->RevokeSmartAccessLease(target->lease_id, target->terminate_active);
  if (result != 0 && result != 1) return {Status::kNotReady, "smart_access_revoke_unavailable"};
  if (result == 1 && staged_profile_digest_ == target->profile_digest) {
    // Preserve the live instance and its bundled assets for a drain, but do
    // not recreate a revoked lease from this profile on the next Connect.
    // A service restart already requires a fresh StageProfile acknowledgement.
    profile_staged_ = false;
    staged_profile_digest_.clear();
  }
  return {Status::kOk, result == 1 ? "revoked=1" : "revoked=0"};
}

RuntimeResult RuntimeHost::ReadSmartAccessRestrictions() {
  if (!initialized_ || core_->SmartAccessRuntimeControlVersion() != 1) return {Status::kNotReady, "smart_access_restriction_read_unavailable"};
  const auto body = core_->ReadSmartAccessRestrictions();
  if (body.empty() || body.size() > kMaxRestrictionSnapshotBodySize) return {Status::kNotReady, "smart_access_restriction_read_unconfirmed"};
  return {Status::kOk, body};
}

RuntimeResult RuntimeHost::ReadSmartAccessLeases(const std::string& profile_digest) {
  if (!IsProfileDigest(profile_digest)) return {Status::kInvalid, "invalid_smart_access_profile"};
  if (!initialized_ || phase_ != Phase::kRunning || effective_profile_digest_ != profile_digest) {
    return {Status::kNotReady, "smart_access_profile_changed"};
  }
  if (core_->SmartAccessRuntimeControlVersion() != 1) return {Status::kUnsupported, "smart_access_lease_read_unsupported"};
  const auto body = core_->ReadSmartAccessLeases();
  if (body.empty() || body.size() > kMaxSmartAccessLeasesBodySize) return {Status::kNotReady, "smart_access_lease_read_unconfirmed"};
  return {Status::kOk, body};
}

RuntimeResult RuntimeHost::AcknowledgeSmartAccessRestrictions(const std::string& digest) {
  if (!IsProfileDigest(digest)) return {Status::kInvalid, "smart_access_restriction_ack_invalid"};
  if (!initialized_ || core_->SmartAccessRuntimeControlVersion() != 1) return {Status::kNotReady, "smart_access_restriction_ack_unavailable"};
  const auto acknowledged = core_->AcknowledgeSmartAccessRestrictions(digest);
  if (acknowledged != 0 && acknowledged != 1) return {Status::kNotReady, "smart_access_restriction_ack_unconfirmed"};
  return {Status::kOk, acknowledged == 1 ? "acknowledged=1" : "acknowledged=0"};
}

RuntimeResult RuntimeHost::ConfigureSmartAccessRuntimeControl(const std::string& body, bool renewal,
    const CheckInterruption& qa_interrupted) {
  if (!IsSmartAccessRuntimeControl(body)) return {Status::kInvalid, "invalid_smart_access_runtime_control"};
  const auto profile_digest = body.substr(0, 64);
  if (!initialized_ || phase_ != Phase::kRunning || effective_profile_digest_ != profile_digest) {
    return {Status::kNotReady, "smart_access_profile_changed"};
  }
  if (core_->SmartAccessRuntimeControlVersion() != 1) return {Status::kUnsupported, "smart_access_runtime_control_unsupported"};
  const auto config = body.substr(65);
  const bool qa_admission = !renewal && qa_interrupted && IsWindowsFirstProviderQaRuntimeControl(config);
  if (qa_admission && (!core_egress_validated_ || requires_bound_connect_)) {
    return {Status::kNotReady, "core_egress_probe_unavailable"};
  }
  if (qa_admission && !first_provider_qa_control_config_.empty() && first_provider_qa_control_config_ != config) {
    return {Status::kNotReady, "smart_access_runtime_control_unconfirmed"};
  }
  // Background restriction delivery outlives Flutter. Old saved bytes must not
  // restart before fresh preparation; the live instance and assets stay intact.
  if (staged_profile_digest_ == profile_digest) {
    profile_staged_ = false;
    staged_profile_digest_.clear();
  }
  const auto result = renewal ? core_->ConfigureSmartAccessRenewal(profile_digest, config)
                              : core_->ConfigureSmartAccessRuntimeControl(profile_digest, config);
  if (result != 0 && result != 1) return {Status::kNotReady, "smart_access_runtime_control_unconfirmed"};
  if (result == 1 && qa_admission) {
    const auto interrupted = [&]() -> std::optional<RuntimeResult> {
      const auto reason = qa_interrupted();
      if (reason == OperationInterruption::kNone) return std::nullopt;
      return RuntimeResult{reason == OperationInterruption::kDeadlineExceeded ? Status::kDeadlineExceeded : Status::kNotReady,
          reason == OperationInterruption::kDeadlineExceeded ? "connect_deadline" : "operation_cancelled"};
    };
    if (const auto stopped = interrupted()) {
      if (!first_provider_qa_admission_result_) {
        first_provider_qa_control_config_ = config;
        first_provider_qa_admission_result_ = *stopped;
      }
      return *stopped;
    }
    if (first_provider_qa_admission_result_) return *first_provider_qa_admission_result_;
    first_provider_qa_control_config_ = config;
    const auto target = ReadWindowsSmartAccessProbeTarget(staged_runtime_config_, true);
    const auto failure = !target || target->empty() || core_->SmartAccessProbeVersion() != 1
        ? "core_egress_probe_unavailable" : core_->ProbeSmartAccess(*target, true, qa_interrupted);
    first_provider_qa_admission_result_ = failure.empty()
        ? RuntimeResult{Status::kOk, "configured=1"} : RuntimeResult{Status::kNotReady, failure};
    if (failure.empty()) {
      if (const auto stopped = interrupted()) first_provider_qa_admission_result_ = *stopped;
    }
    // This ACK admits the worker under the captured owner. Actual stage proof
    // stays in Core readiness; ordinary VPN egress is never replaced by it.
    return *first_provider_qa_admission_result_;
  }
  return {Status::kOk, result == 1 ? "configured=1" : "configured=0"};
}

RuntimeResult RuntimeHost::RenewSmartAccessLease(const std::string& body) {
  const auto target = DecodeSmartAccessRenewal(body);
  if (!target) return {Status::kInvalid, "invalid_smart_access_renewal"};
  if (!initialized_ || phase_ != Phase::kRunning || effective_profile_digest_ != target->profile_digest) {
    return {Status::kNotReady, "smart_access_profile_changed"};
  }
  if (core_->RoutingCatalogControlVersion() != 4) return {Status::kUnsupported, "smart_access_renewal_unsupported"};
  // Retain the running instance/assets, but old profile bytes cannot recreate
  // the renewed generation. Service restart already requires a fresh stage.
  if (staged_profile_digest_ == target->profile_digest) {
    profile_staged_ = false;
    staged_profile_digest_.clear();
  }
  const auto result = core_->RenewSmartAccessLease(*target);
  if (result != 0 && result != 1) return {Status::kNotReady, "smart_access_renewal_unconfirmed"};
  return {Status::kOk, result == 1 ? "renewed=1" : "renewed=0"};
}

RuntimeResult RuntimeHost::RevokeRoutingCatalog(const std::string& profile_digest) {
  if (!IsProfileDigest(profile_digest)) return {Status::kInvalid, "invalid_catalog_revocation"};
  if (!initialized_ || phase_ != Phase::kRunning || effective_profile_digest_ != profile_digest) {
    return {Status::kNotReady, "catalog_profile_changed"};
  }
  if (!WithdrawTelegramWS()) return Fail(Status::kNotReady, "telegram_ws_withdraw_failed");
  if (local_dpi_preparation_) {
    const auto stopped = CancelProtectedHandoff();
    if (stopped.status != Status::kOk) return stopped;
    profile_staged_ = false;
    staged_profile_digest_.clear();
    return {Status::kOk, "catalog_revoked=1"};
  }
  if (local_dpi_executor_ && !local_dpi_executor_->Stop()) return Fail(Status::kNotReady, "local_dpi_withdraw_failed");
  const auto result = core_->RevokeRoutingCatalog();
  if (result != 0 && result != 1) return {Status::kNotReady, "catalog_revoke_unavailable"};
  if (result == 1 && staged_profile_digest_ == profile_digest) {
    profile_staged_ = false;
    staged_profile_digest_.clear();
  }
  return {Status::kOk, result == 1 ? "catalog_revoked=1" : "catalog_revoked=0"};
}

RuntimeResult RuntimeHost::RevokeRoutingCatalogService(const std::string& body) {
  if (!IsRoutingCatalogServiceRevocation(body)) return {Status::kInvalid, "invalid_catalog_revocation"};
  const auto profile_digest = body.substr(0, 64);
  if (!initialized_ || phase_ != Phase::kRunning || effective_profile_digest_ != profile_digest) {
    return {Status::kNotReady, "catalog_profile_changed"};
  }
  const auto service_id = body.substr(65);
  if (telegram_ws_preparation_ && std::any_of(telegram_ws_preparation_->services.begin(),
      telegram_ws_preparation_->services.end(), [&](const auto& service) { return service.first == service_id; })) {
    if (!WithdrawTelegramWS(service_id)) return Fail(Status::kNotReady, "telegram_ws_withdraw_failed");
  }
  if (local_dpi_preparation_ && std::any_of(local_dpi_preparation_->services.begin(),
      local_dpi_preparation_->services.end(), [&](const auto& service) { return service.service_id == service_id; })) {
    const auto stopped = CancelProtectedHandoff();
    if (stopped.status != Status::kOk) return stopped;
    profile_staged_ = false;
    staged_profile_digest_.clear();
    return {Status::kOk, "catalog_revoked=1"};
  }
  if (!local_dpi_preparation_ && local_dpi_executor_ && !local_dpi_executor_->Stop())
    return Fail(Status::kNotReady, "local_dpi_withdraw_failed");
  const auto result = core_->RevokeRoutingCatalogService(service_id);
  if (result != 0 && result != 1) return {Status::kNotReady, "catalog_revoke_unavailable"};
  if (result == 1 && staged_profile_digest_ == profile_digest) {
    profile_staged_ = false;
    staged_profile_digest_.clear();
  }
  return {Status::kOk, result == 1 ? "catalog_revoked=1" : "catalog_revoked=0"};
}

RuntimeResult RuntimeHost::RevokeSmartAccessPolicy(const std::string& body) {
  if (!IsSmartAccessPolicyRevocation(body)) return {Status::kInvalid, "invalid_smart_access_revocation"};
  const auto profile_digest = body.substr(0, 64);
  if (!initialized_ || phase_ != Phase::kRunning || effective_profile_digest_ != profile_digest) {
    return {Status::kNotReady, "smart_access_profile_changed"};
  }
  const auto result = core_->RevokeSmartAccessPolicy(body[65] == '1');
  if (result != 0 && result != 1) return {Status::kNotReady, "smart_access_revoke_unavailable"};
  if (result == 1 && staged_profile_digest_ == profile_digest) {
    profile_staged_ = false;
    staged_profile_digest_.clear();
  }
  return {Status::kOk, result == 1 ? "revoked=1" : "revoked=0"};
}

bool RuntimeHost::CanRecheckEgress() const {
  return phase_ == Phase::kRunning && !requires_bound_connect_ &&
      !TransitionGuardArmed();
}

std::string RuntimeHost::VerifyEgress(bool periodic, const CheckInterruption& interrupted,
                                    std::uint64_t deadline_tick) {
  egress_failure_observation_.reset();
  const auto target = ReadWindowsSmartAccessProbeTarget(staged_runtime_config_);
  if (target) {
    if (target->empty() || core_->SmartAccessProbeVersion() != 1) return "core_egress_probe_unavailable";
    return core_->ProbeSmartAccess(*target, periodic, interrupted);
  }
  if (!egress_probe_) return "core_egress_probe_failed";
  const auto failure = egress_probe_->Verify(interrupted, periodic, deadline_tick);
  if (!failure.empty()) {
    egress_failure_observation_ = egress_probe_->LastObservation();
    if (egress_failure_observation_) {
      // This first owned query is independent of the final native probe retry.
      // Copy before rollback can stop Core and cancel its outstanding DNS work.
      egress_failure_observation_->first_owned_dns_state = core_->FirstOwnedDnsObservation();
    }
  }
  return failure;
}

RuntimeResult RuntimeHost::RecheckEgress(const CheckInterruption& interrupted,
                                       std::uint64_t deadline_tick) {
  if (!CanRecheckEgress() ||
      (interrupted && interrupted() == OperationInterruption::kCancelled)) return Snapshot();
  RecordEvent(ServiceEvent::kRuntimeEgressVerify, ServiceEventOutcome::kAttempted);
  const auto failure = VerifyEgress(true, interrupted, deadline_tick);
  const auto interruption = interrupted ? interrupted() : OperationInterruption::kNone;
  // A lifecycle command cancels and joins this check before changing its owner.
  // Failed health leaves the current TUN in place for protected replacement.
  if (interruption == OperationInterruption::kCancelled) {
    egress_failure_observation_.reset();
    return Snapshot();
  }
  if (!failure.empty() || interruption == OperationInterruption::kDeadlineExceeded) {
    core_egress_validated_ = false;
    RecordEvent(ServiceEvent::kRuntimeEgressVerify, ServiceEventOutcome::kFailed);
    return Fail(Status::kNotReady, interruption == OperationInterruption::kDeadlineExceeded
        ? "core_egress_timeout" : SafeEgressFailure(failure));
  }
  RecordEvent(ServiceEvent::kRuntimeEgressVerify, ServiceEventOutcome::kSucceeded);
  core_egress_validated_ = true;
  failure_.clear();
  return Snapshot();
}

RuntimeResult RuntimeHost::ReplaceManagedProfile(const std::string& body,
                                                 const CheckInterruption& interrupted,
                                                 const std::optional<CandidateNetworkContext>& local_dpi_network,
                                                 const CheckInterruption& telegram_interrupted) {
  if (transition_guard_ == nullptr || requires_bound_connect_ ||
      (phase_ != Phase::kRunning && !transition_guard_->IsArmed())) {
    return Fail(Status::kNotReady, "protected_handoff_unavailable");
  }
  const auto guard_error = transition_guard_->Start();
  if (!guard_error.empty()) return Fail(Status::kNotReady, "transition_guard_failed");
  const auto stopped = Disconnect(false);
  if (stopped.status != Status::kOk) return stopped;
  if (interrupted && interrupted() != OperationInterruption::kNone) {
    return Fail(Status::kNotReady, "operation_cancelled");
  }
  const auto staged = StageProfile(body);
  if (staged.status != Status::kOk) return staged;
  const auto connected = ConnectImpl(ProfileDigest(body), interrupted, "", false, local_dpi_network, telegram_interrupted);
  if (connected.status != Status::kOk) return connected;
  if (phase_ != Phase::kRunning || !core_egress_validated_ ||
      effective_profile_digest_ != ProfileDigest(body)) {
    return Fail(Status::kNotReady, "protected_handoff_unavailable");
  }
  if (interrupted && interrupted() != OperationInterruption::kNone) {
    const auto cancelled = Disconnect(false);
    return cancelled.status == Status::kOk ? Fail(Status::kNotReady, "operation_cancelled") : cancelled;
  }
  if (!transition_guard_->Finish().empty()) {
    core_egress_validated_ = false;
    return Fail(Status::kNotReady, "transition_guard_failed");
  }
  return Snapshot();
}

bool RuntimeHost::ReplacementRequestsWindowsLocalDpi(const std::string& body) const {
  if (!local_dpi_ready_ || body.size() < 4 ||
      (body[0] != '0' && body[0] != '1') || body[1] != '\n') return false;
  ParsedProfileBundle bundle;
  if (!ParseProfilePayload(body.substr(2), &bundle)) return false;
  std::string runtime_copy;
  bool requested = false;
  return StripWindowsLocalDpiMetadata(bundle.profile, &runtime_copy, &requested) && requested;
}

bool RuntimeHost::ReplacementRequestsTelegramWS(const std::string& body) const {
  if (!telegram_ws_ready_ || body.size() < 4 ||
      (body[0] != '0' && body[0] != '1') || body[1] != '\n') return false;
  ParsedProfileBundle bundle;
  if (!ParseProfilePayload(body.substr(2), &bundle)) return false;
  std::string copy;
  bool dpi = false, telegram = false;
  return StripWindowsLocalDpiMetadata(bundle.profile, &copy, &dpi, &telegram) && telegram;
}

RuntimeResult RuntimeHost::CancelProtectedHandoff() {
  if (transition_guard_ == nullptr || !transition_guard_->Start().empty()) {
    return Fail(Status::kNotReady, "transition_guard_failed");
  }
  return Disconnect(false);
}

RuntimeResult RuntimeHost::Disconnect(bool explicit_disconnect) {
  if (!initialized_ ||
      (phase_ != Phase::kRunning &&
       phase_ != Phase::kRecoveryRequired)) {
    if (explicit_disconnect && transition_guard_ != nullptr && !transition_guard_->ExplicitOff().empty()) {
      return Fail(Status::kNotReady, "transition_guard_failed");
    }
    return Snapshot();
  }
  const auto rollback_error = RollbackRuntime();
  effective_profile_digest_.clear();
  core_egress_validated_ = false;
  phase_ = rollback_error.empty()
               ? (profile_staged_ ? Phase::kConfigStaged
                                  : Phase::kInitialized)
               : Phase::kRecoveryRequired;
  if (!rollback_error.empty()) {
    RecordEvent(ServiceEvent::kRuntimeRecoveryRequired,
                ServiceEventOutcome::kFailed);
    return Fail(Status::kNotReady, rollback_error.c_str());
  }
  failure_.clear();
  if (explicit_disconnect && transition_guard_ != nullptr && !transition_guard_->ExplicitOff().empty()) {
    return Fail(Status::kNotReady, "transition_guard_failed");
  }
  return Snapshot();
}

void RuntimeHost::Shutdown() {
  WithdrawTelegramWS();
  if (local_dpi_executor_) local_dpi_executor_->Stop();
  if (core_ != nullptr && initialized_ &&
      (phase_ == Phase::kRunning ||
       phase_ == Phase::kRecoveryRequired)) {
    const auto rollback_error = RollbackRuntime();
    effective_profile_digest_.clear();
    core_egress_validated_ = false;
    phase_ = rollback_error.empty()
                 ? (profile_staged_ ? Phase::kConfigStaged
                                    : Phase::kInitialized)
                 : Phase::kRecoveryRequired;
  }
}

RuntimeResult RuntimeHost::MaintainWindowsLocalDpi(const CheckInterruption& interrupted) {
  if (!local_dpi_preparation_ || phase_ != Phase::kRunning) return Snapshot();
  const bool expired = !WindowsLocalDpiPreparationCurrent(*local_dpi_preparation_);
  const bool changed = effective_profile_digest_ != local_dpi_profile_digest_ ||
      core_->CoreModuleSHA256() != local_dpi_core_digest_;
  // Expired/revoked catalog windows skip their rules. Retain the existing
  // protected transition rather than exposing route.final after withdrawal.
  if (expired || changed) {
    const auto stopped = CancelProtectedHandoff();
    if (stopped.status != Status::kOk) return stopped;
    profile_staged_ = false;
    staged_profile_digest_.clear();
    return Fail(Status::kNotReady, expired ? "local_dpi_catalog_expired" : "local_dpi_owner_changed");
  }
  if (!local_dpi_disabled_ && ((interrupted && interrupted() != OperationInterruption::kNone) ||
      !local_dpi_executor_->Alive())) {
    // Before expiry unpublished/withdrawn holders use their protected VPN
    // outbound. Keep the expiry owner even if the child has already exited.
    if (!local_dpi_executor_->Stop()) {
      const auto stopped = CancelProtectedHandoff();
      return stopped.status == Status::kOk
          ? Fail(Status::kNotReady, "local_dpi_withdraw_failed") : stopped;
    }
    local_dpi_disabled_ = true;
  }
  return Snapshot();
}

bool RuntimeHost::WithdrawTelegramWS(const std::string& service_id) {
  if (!telegram_ws_preparation_) return true;
  for (auto holder = telegram_ws_holders_.begin(); holder != telegram_ws_holders_.end();) {
    const auto selected = service_id.empty() || std::any_of(telegram_ws_preparation_->services.begin(),
        telegram_ws_preparation_->services.end(), [&](const auto& service) {
          return service.first == service_id && service.second == holder->first;
        });
    if (!selected) { ++holder; continue; }
    // A successor's fresh ID is never substituted for this captured runtime.
    if (core_->ReadTelegramWSAdmissionID(holder->first) == holder->second &&
        core_->WithdrawTelegramWSAdmission(holder->second) < 0) return false;
    holder = telegram_ws_holders_.erase(holder);
  }
  return true;
}

RuntimeResult RuntimeHost::MaintainTelegramWS(const CheckInterruption& interrupted) {
  if (!telegram_ws_preparation_ || phase_ != Phase::kRunning) return Snapshot();
  const bool changed = effective_profile_digest_ != telegram_ws_original_digest_ ||
      core_->CoreModuleSHA256() != telegram_ws_core_digest_ ||
      ProfileDigest(telegram_ws_preparation_->profile) != telegram_ws_prepared_digest_ ||
      std::any_of(telegram_ws_holders_.begin(), telegram_ws_holders_.end(), [&](const auto& holder) {
        return core_->ReadTelegramWSAdmissionID(holder.first) != holder.second;
      });
  if (changed || !WindowsTelegramWSPreparationCurrent(*telegram_ws_preparation_) ||
      (interrupted && interrupted() != OperationInterruption::kNone)) {
    if (!WithdrawTelegramWS()) return Fail(Status::kNotReady, "telegram_ws_withdraw_failed");
  }
  return Snapshot();  // Untimed exact-IP TG rules now use the encrypted VPN fallback.
}

bool RuntimeHost::ClearWindowsLocalDpiAfterCoreStopped() {
  if (local_dpi_executor_ && !local_dpi_executor_->StopAfterCoreStopped()) return false;
  local_dpi_preparation_.reset();
  telegram_ws_preparation_.reset();
  telegram_ws_holders_.clear();
  telegram_ws_original_digest_.clear();
  telegram_ws_prepared_digest_.clear();
  telegram_ws_core_digest_.clear();
  local_dpi_profile_digest_.clear();
  local_dpi_core_digest_.clear();
  local_dpi_disabled_ = false;
  if (profile_staged_ && !staged_runtime_config_.empty()) {
    // A later Connect must prepare fresh holders; never restart transformed
    // bytes from an old proof or a cancelled operation.
    if (!WriteProfileAtomically(staged_runtime_config_).empty()) profile_staged_ = false;
  }
  return true;
}

std::string RuntimeHost::RecoverPendingRuntime() {
  WithdrawTelegramWS();
  if (local_dpi_executor_) local_dpi_executor_->Stop();
  if (recovery_ == nullptr) {
    return "recovery_unavailable";
  }
  if (!recovery_->RequiresRecovery()) {
    return "";
  }
  RecordEvent(ServiceEvent::kRuntimeRollbackBegin,
              ServiceEventOutcome::kAttempted);
  const auto begin_error = recovery_->BeginRollback();
  RecordEvent(ServiceEvent::kRuntimeCoreStop,
              ServiceEventOutcome::kAttempted);
  const auto stop_error = core_->Stop();
  const bool local_dpi_stopped = stop_error.empty() && ClearWindowsLocalDpiAfterCoreStopped();
  if (!begin_error.empty()) {
    RecordEvent(ServiceEvent::kRuntimeRollbackBegin,
                ServiceEventOutcome::kFailed);
    return begin_error;
  }
  RecordEvent(ServiceEvent::kRuntimeRollbackBegin,
              ServiceEventOutcome::kSucceeded);
  if (!stop_error.empty()) {
    RecordEvent(ServiceEvent::kRuntimeCoreStop,
                ServiceEventOutcome::kFailed);
    return "recovery_core_stop_failed";
  }
  RecordEvent(ServiceEvent::kRuntimeCoreStop,
              ServiceEventOutcome::kSucceeded);
  if (!local_dpi_stopped) return "local_dpi_withdraw_failed";
  RecordEvent(ServiceEvent::kRuntimeNetworkRestore,
              ServiceEventOutcome::kAttempted);
  const auto network_error = recovery_->RestoreNetworkState();
  if (!network_error.empty()) {
    RecordEvent(ServiceEvent::kRuntimeNetworkRestore,
                ServiceEventOutcome::kFailed);
    return network_error;
  }
  RecordEvent(ServiceEvent::kRuntimeNetworkRestore,
              ServiceEventOutcome::kSucceeded);
  RecordEvent(ServiceEvent::kRuntimeRollbackComplete,
              ServiceEventOutcome::kAttempted);
  const auto complete_error = recovery_->CompleteRollback();
  RecordEvent(ServiceEvent::kRuntimeRollbackComplete,
              complete_error.empty() ? ServiceEventOutcome::kSucceeded
                                     : ServiceEventOutcome::kFailed);
  return complete_error.empty() ? "" : complete_error;
}

std::string RuntimeHost::RollbackRuntime() {
  WithdrawTelegramWS();
  if (local_dpi_executor_) local_dpi_executor_->Stop();
  if (recovery_ == nullptr) {
    RecordEvent(ServiceEvent::kRuntimeCoreStop,
                ServiceEventOutcome::kAttempted);
    if (core_->Stop().empty()) ClearWindowsLocalDpiAfterCoreStopped();
    RecordEvent(ServiceEvent::kRuntimeCoreStop,
                ServiceEventOutcome::kFailed);
    return "recovery_unavailable";
  }
  RecordEvent(ServiceEvent::kRuntimeRollbackBegin,
              ServiceEventOutcome::kAttempted);
  const auto begin_error = recovery_->BeginRollback();
  RecordEvent(ServiceEvent::kRuntimeCoreStop,
              ServiceEventOutcome::kAttempted);
  const auto stop_error = core_->Stop();
  const bool local_dpi_stopped = stop_error.empty() && ClearWindowsLocalDpiAfterCoreStopped();
  if (!begin_error.empty()) {
    RecordEvent(ServiceEvent::kRuntimeRollbackBegin,
                ServiceEventOutcome::kFailed);
    return begin_error;
  }
  RecordEvent(ServiceEvent::kRuntimeRollbackBegin,
              ServiceEventOutcome::kSucceeded);
  if (!stop_error.empty()) {
    RecordEvent(ServiceEvent::kRuntimeCoreStop,
                ServiceEventOutcome::kFailed);
    return "core_stop_failed";
  }
  RecordEvent(ServiceEvent::kRuntimeCoreStop,
              ServiceEventOutcome::kSucceeded);
  if (!local_dpi_stopped) return "local_dpi_withdraw_failed";
  RecordEvent(ServiceEvent::kRuntimeNetworkRestore,
              ServiceEventOutcome::kAttempted);
  const auto network_error = recovery_->RestoreNetworkState();
  if (!network_error.empty()) {
    RecordEvent(ServiceEvent::kRuntimeNetworkRestore,
                ServiceEventOutcome::kFailed);
    return network_error;
  }
  RecordEvent(ServiceEvent::kRuntimeNetworkRestore,
              ServiceEventOutcome::kSucceeded);
  RecordEvent(ServiceEvent::kRuntimeRollbackComplete,
              ServiceEventOutcome::kAttempted);
  const auto complete_error = recovery_->CompleteRollback();
  RecordEvent(ServiceEvent::kRuntimeRollbackComplete,
              complete_error.empty() ? ServiceEventOutcome::kSucceeded
                                     : ServiceEventOutcome::kFailed);
  return complete_error.empty() ? "" : complete_error;
}

void RuntimeHost::RecordEvent(ServiceEvent event,
                              ServiceEventOutcome outcome) {
  if (events_ != nullptr) {
    events_->Record(event, outcome);
  }
}

RuntimeResult RuntimeHost::Fail(Status status, const char* failure) {
  failure_ = failure == nullptr ? "runtime_failure" : failure;
  return RuntimeResult{status, SnapshotBody()};
}

std::string RuntimeHost::SnapshotBody(const char* pending_phase) const {
  const auto phase = static_cast<int>(phase_);
  const bool pending = pending_phase != nullptr;
  const bool guarded = TransitionGuardArmed();
  const bool core_ready = initialized_;
  const bool can_initialize = !pending && core_ != nullptr && !runtime_root_.empty();
  const bool can_connect = !pending && initialized_ && profile_staged_ &&
                           !requires_bound_connect_ &&
                           phase_ == Phase::kConfigStaged;
  std::string local_dpi_observation;
  if (!pending) {
    if (const auto value = ReadLocalDpiRuntimeObservation()) {
      local_dpi_observation = ";windows_local_dpi_services=" + std::to_string(value->services) +
          ";windows_local_dpi_admitted=" + std::to_string(value->admitted) +
          ";windows_local_dpi_failed=" + std::to_string(value->failed) +
          ";windows_local_dpi_withdraw_completed=" + std::to_string(value->withdraw_completed) +
          ";windows_local_dpi_local_handoffs=" + std::to_string(value->local_handoffs) +
          ";windows_local_dpi_vpn_handoffs=" + std::to_string(value->vpn_handoffs);
    }
  }
  return std::string("phase=") + (pending ? pending_phase : PhaseName(phase)) +
         ";core_ready=" + (core_ready ? "1" : "0") +
         ";can_initialize=" + (can_initialize ? "1" : "0") +
         ";can_connect=" + (can_connect ? "1" : "0") +
         ";running=" + (!pending && phase_ == Phase::kRunning ? "1" : "0") +
         ";core_egress_validated=" +
         (!pending && !guarded && core_egress_validated_ ? "1" : "0") +
         ";dns_ready=" + (!pending && !guarded && core_egress_validated_ ? "1" : "0") +
         ";staged_profile_digest=" +
         (staged_profile_digest_.empty() ? "none" : staged_profile_digest_) +
         ";effective_profile_digest=" +
         (pending || effective_profile_digest_.empty() ? "none" : effective_profile_digest_) +
         ";failure=" +
         (pending ? "none" : failure_.empty() ? (guarded ? "transition_guard_active" : "none") : failure_) +
         ";routing_catalog_window_version=" +
         std::to_string(initialized_ ? core_->RoutingCatalogWindowVersion() : 0) +
         ";smart_access_lease_version=" +
         std::to_string(initialized_ ? core_->SmartAccessLeaseVersion() : 0) +
         ";routing_catalog_control_version=" +
         std::to_string(initialized_ ? core_->RoutingCatalogControlVersion() : 0) +
         ";smart_access_runtime_control_version=" +
         std::to_string(initialized_ ? core_->SmartAccessRuntimeControlVersion() : 0) +
         ";transport_capabilities=" +
         (initialized_ && !core_->TransportCapabilities().empty()
             ? core_->TransportCapabilities() : "none") +
         ";core_module_sha256=" +
         (initialized_ && !core_->CoreModuleSHA256().empty() ? core_->CoreModuleSHA256() : "none") +
         ";core_version=" +
         (initialized_ && !core_->CoreVersion().empty() ? core_->CoreVersion() : "none") +
         ";protection_retained=" + (guarded ? "1" : "0") +
         ";windows_local_dpi_admission_version=" + (local_dpi_ready_ ? "1" : "0") +
         local_dpi_observation +
         (!pending && failure_.rfind("core_egress_", 0) == 0 && egress_failure_observation_
              ? EncodeEgressProbeObservation(*egress_failure_observation_) : "");
}

std::optional<WindowsLocalDpiRuntimeObservation> RuntimeHost::ReadLocalDpiRuntimeObservation() const {
  if (!initialized_ || phase_ != Phase::kRunning || !local_dpi_preparation_ ||
      effective_profile_digest_ != local_dpi_profile_digest_ ||
      core_->CoreModuleSHA256() != local_dpi_core_digest_ ||
      !WindowsLocalDpiPreparationCurrent(*local_dpi_preparation_)) return std::nullopt;
  WindowsLocalDpiRuntimeObservation result;
  for (const auto& service : local_dpi_preparation_->services) {
    if (service.captured_admission_id.empty()) return std::nullopt;
    const auto value = ReadWindowsLocalDpiHolderObservation(
        core_->ReadLocalDpiObservation(service.captured_admission_id));
    if (!value) return std::nullopt;
    ++result.services;
    if (value->state == "ready") ++result.admitted;
    if (value->state == "failed") ++result.failed;
    if (value->withdraw_completed) ++result.withdraw_completed;
    constexpr std::uint64_t maximum = 9007199254740991ULL;
    if (value->local_handoffs > maximum - result.local_handoffs ||
        value->vpn_handoffs > maximum - result.vpn_handoffs) return std::nullopt;
    result.local_handoffs += value->local_handoffs;
    result.vpn_handoffs += value->vpn_handoffs;
  }
  return result;
}

bool RuntimeHost::PrepareDirectories() {
  directories_.base = runtime_root_;
  directories_.working = AppendPath(runtime_root_, L"working");
  directories_.temporary = AppendPath(runtime_root_, L"temp");
  directories_.config = AppendPath(directories_.working, L"configs");
  const std::array<std::wstring, 6> paths = {
      directories_.base,
      directories_.working,
      directories_.temporary,
      directories_.config,
      AppendPath(directories_.base, L"data"),
      AppendPath(directories_.working, L"data"),
  };
  for (const auto& path : paths) {
    if (!EnsureDirectory(path) ||
        (secure_storage_ && !ProtectDirectory(path))) {
      return false;
    }
  }
  profile_path_ = AppendPath(directories_.config, L"managed-profile.json");
  return true;
}

std::string RuntimeHost::WriteProfileAtomically(const std::string& profile) {
  const auto pending =
      AppendPath(directories_.config, L"managed-profile.pending");
  HANDLE file = ::CreateFileW(pending.c_str(), GENERIC_WRITE, 0, nullptr,
                              CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
  if (file == INVALID_HANDLE_VALUE) {
    return "profile_write_failed";
  }
  DWORD written = 0;
  const bool success =
      ::WriteFile(file, profile.data(), static_cast<DWORD>(profile.size()),
                  &written, nullptr) != FALSE &&
      written == profile.size() && ::FlushFileBuffers(file) != FALSE;
  ::CloseHandle(file);
  if (!success) {
    ::DeleteFileW(pending.c_str());
    return "profile_write_failed";
  }
  // Secure the new file before replacing the last acknowledged profile. A
  // security failure must not destroy the old bytes while leaving staged=true.
  if (!core_->SecureFile(pending).empty()) {
    ::DeleteFileW(pending.c_str());
    return "profile_security_failed";
  }
  if (::MoveFileExW(pending.c_str(), profile_path_.c_str(),
                    MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH) ==
          FALSE) {
    ::DeleteFileW(pending.c_str());
    return "profile_write_failed";
  }
  return "";
}

bool RuntimeHost::WriteBundledRuleSets(
    int slot, const std::vector<std::vector<std::uint8_t>>& rule_sets,
    std::vector<std::wstring>* written_paths) {
  if ((slot != 1 && slot != 2) || written_paths == nullptr ||
      rule_sets.empty() || rule_sets.size() > kMaximumBundledRuleSets) {
    return false;
  }
  written_paths->clear();
  const auto data_root = AppendPath(directories_.working, L"data");
  const auto rule_set_root = AppendPath(data_root, L"rule-set");
  const auto slot_root =
      AppendPath(rule_set_root, slot == 1 ? L"profile-a" : L"profile-b");
  if (!EnsureDirectory(rule_set_root) || !EnsureDirectory(slot_root) ||
      (secure_storage_ &&
       (!ProtectDirectory(rule_set_root) || !ProtectDirectory(slot_root)))) {
    return false;
  }

  CleanupBundledRuleSets(slot);
  if (!EnsureDirectory(slot_root) ||
      (secure_storage_ && !ProtectDirectory(slot_root))) {
    return false;
  }
  for (std::size_t index = 0; index < rule_sets.size(); ++index) {
    const auto& bytes = rule_sets[index];
    if (bytes.empty() || bytes.size() > kMaximumBundledRuleSetBytes) {
      CleanupBundledRuleSets(slot);
      return false;
    }
    const std::wstring name =
        L"ruleset-" + std::to_wstring(index) + L".srs";
    const auto path = AppendPath(slot_root, name);
    const auto pending = path + L".pending";
    HANDLE file = ::CreateFileW(pending.c_str(), GENERIC_WRITE, 0, nullptr,
                                CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (file == INVALID_HANDLE_VALUE) {
      CleanupBundledRuleSets(slot);
      return false;
    }
    DWORD written = 0;
    const bool success =
        ::WriteFile(file, bytes.data(), static_cast<DWORD>(bytes.size()),
                    &written, nullptr) != FALSE &&
        written == bytes.size() && ::FlushFileBuffers(file) != FALSE;
    ::CloseHandle(file);
    if (!success ||
        ::MoveFileExW(pending.c_str(), path.c_str(),
                      MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH) ==
            FALSE) {
      ::DeleteFileW(pending.c_str());
      CleanupBundledRuleSets(slot);
      return false;
    }
    written_paths->push_back(path);
  }
  return true;
}

void RuntimeHost::CleanupBundledRuleSets(int slot) {
  if (slot != 1 && slot != 2) {
    return;
  }
  const auto slot_root = AppendPath(
      AppendPath(AppendPath(directories_.working, L"data"), L"rule-set"),
      slot == 1 ? L"profile-a" : L"profile-b");
  for (std::size_t index = 0; index < kMaximumBundledRuleSets; ++index) {
    const std::wstring name =
        L"ruleset-" + std::to_wstring(index) + L".srs";
    const auto path = AppendPath(slot_root, name);
    ::DeleteFileW((path + L".pending").c_str());
    ::DeleteFileW(path.c_str());
  }
  ::RemoveDirectoryW(slot_root.c_str());
}

std::unique_ptr<CoreRuntime> CreateInstalledCoreRuntime() {
  return std::make_unique<InstalledCoreRuntime>();
}



std::wstring ResolveServiceRuntimeRoot() {
  PWSTR program_data = nullptr;
  if (FAILED(::SHGetKnownFolderPath(FOLDERID_ProgramData, KF_FLAG_DEFAULT,
                                    nullptr, &program_data)) ||
      program_data == nullptr) {
    return L"";
  }
  const std::wstring pokrov_root = AppendPath(program_data, L"POKROV");
  ::CoTaskMemFree(program_data);
  const std::wstring runtime_root = AppendPath(pokrov_root, L"ServiceRuntime");
  if (!EnsureDirectory(pokrov_root) || !EnsureDirectory(runtime_root) ||
      !ProtectDirectory(runtime_root)) {
    return L"";
  }
  return runtime_root;
}

}  // namespace pokrov::service
