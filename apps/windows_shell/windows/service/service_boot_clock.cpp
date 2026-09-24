#include "service_boot_clock.h"

#include <windows.h>
#include <bcrypt.h>
#include <sddl.h>

#include <array>
#include <mutex>

namespace pokrov::service {
namespace {
constexpr wchar_t kClockKey[] = L"SOFTWARE\\space.pokrov\\POKROV\\Service\\TransportClock";
std::mutex clock_lock;

std::optional<std::string> BootReference() {
  PSECURITY_DESCRIPTOR descriptor = nullptr;
  if (!::ConvertStringSecurityDescriptorToSecurityDescriptorW(
      L"D:P(A;;KA;;;SY)(A;;KA;;;BA)", SDDL_REVISION_1, &descriptor, nullptr)) return std::nullopt;
  SECURITY_ATTRIBUTES attributes{sizeof(SECURITY_ATTRIBUTES), descriptor, FALSE};
  HKEY key = nullptr;
  DWORD disposition = 0;
  const auto opened = ::RegCreateKeyExW(HKEY_LOCAL_MACHINE, kClockKey, 0, nullptr,
      REG_OPTION_VOLATILE, KEY_QUERY_VALUE | KEY_SET_VALUE, &attributes, &key, &disposition);
  ::LocalFree(descriptor);
  if (opened != ERROR_SUCCESS) return std::nullopt;
  // The OS discards this protected volatile key at reboot. It survives ordinary
  // app/service restarts and sleep. Never derive a boot ID from calendar time.
  std::array<char, 33> value{};
  DWORD length = static_cast<DWORD>(value.size());
  DWORD type = 0;
  auto status = ::RegQueryValueExA(key, "BootRef", nullptr, &type,
      reinterpret_cast<BYTE*>(value.data()), &length);
  if (status == ERROR_FILE_NOT_FOUND) {
    std::array<BYTE, 16> random{};
    if (::BCryptGenRandom(nullptr, random.data(), static_cast<ULONG>(random.size()), BCRYPT_USE_SYSTEM_PREFERRED_RNG) < 0) {
      ::RegCloseKey(key);
      return std::nullopt;
    }
    constexpr char hex[] = "0123456789abcdef";
    for (std::size_t i = 0; i < random.size(); ++i) {
      value[2 * i] = hex[random[i] >> 4];
      value[2 * i + 1] = hex[random[i] & 15];
    }
    status = ::RegSetValueExA(key, "BootRef", 0, REG_SZ,
        reinterpret_cast<const BYTE*>(value.data()), static_cast<DWORD>(value.size()));
    type = REG_SZ;
    length = static_cast<DWORD>(value.size());
  }
  ::RegCloseKey(key);
  if (status != ERROR_SUCCESS || type != REG_SZ || length != value.size() || value[32] != '\0') return std::nullopt;
  const std::string result(value.data(), 32);
  if (result.find_first_not_of("0123456789abcdef") != std::string::npos) return std::nullopt;
  return result;
}

std::optional<std::uint64_t> UtcTicks(const std::string& value) {
  if (value.size() != 20 || value[4] != '-' || value[7] != '-' || value[10] != 'T' ||
      value[13] != ':' || value[16] != ':' || value[19] != 'Z') return std::nullopt;
  for (std::size_t index = 0; index < 19; ++index) {
    if (index == 4 || index == 7 || index == 10 || index == 13 || index == 16) continue;
    if (value[index] < '0' || value[index] > '9') return std::nullopt;
  }
  const auto number = [&value](int start) { return (value[start] - '0') * 10 + value[start + 1] - '0'; };
  SYSTEMTIME utc{};
  utc.wYear = static_cast<WORD>(number(0) * 100 + number(2));
  utc.wMonth = static_cast<WORD>(number(5));
  utc.wDay = static_cast<WORD>(number(8));
  utc.wHour = static_cast<WORD>(number(11));
  utc.wMinute = static_cast<WORD>(number(14));
  utc.wSecond = static_cast<WORD>(number(17));
  FILETIME encoded{};
  SYSTEMTIME decoded{};
  if (!::SystemTimeToFileTime(&utc, &encoded) || !::FileTimeToSystemTime(&encoded, &decoded) ||
      utc.wYear != decoded.wYear || utc.wMonth != decoded.wMonth || utc.wDay != decoded.wDay ||
      utc.wHour != decoded.wHour || utc.wMinute != decoded.wMinute || utc.wSecond != decoded.wSecond) return std::nullopt;
  return (static_cast<std::uint64_t>(encoded.dwHighDateTime) << 32) | encoded.dwLowDateTime;
}
}

std::optional<BootClockSnapshot> ReadBootClock() {
  std::lock_guard<std::mutex> guard(clock_lock);
  using QueryTime = VOID(WINAPI*)(PULONGLONG);
  const auto query = reinterpret_cast<QueryTime>(::GetProcAddress(
      ::GetModuleHandleW(L"kernel32.dll"), "QueryInterruptTimePrecise"));
  if (query == nullptr) return std::nullopt;
  const auto boot = BootReference();
  if (!boot) return std::nullopt;
  ULONGLONG ticks = 0;
  query(&ticks);
  const auto millis = ticks / 10000ULL;
  if (millis > 9007199254740991ULL) return std::nullopt;
  return BootClockSnapshot{"windows:" + *boot, millis};
}

std::optional<std::string> ReadBootClockJson() {
  const auto clock = ReadBootClock();
  if (!clock) return std::nullopt;
  return "{\"schema\":1,\"boot_ref\":\"" + clock->boot_ref +
      "\",\"elapsed_ms\":" + std::to_string(clock->elapsed_ms) + ",\"quantum_ms\":1}";
}

bool IsConnectDeadlineCurrent(const BoundConnectTarget& target) {
  const auto clock = ReadBootClock();
  return clock && clock->boot_ref == target.boot_ref &&
      clock->elapsed_ms >= target.started_elapsed_ms && clock->elapsed_ms < target.deadline_elapsed_ms;
}

std::optional<std::uint64_t> ActiveTransportLeaseDeadline(const TransportLeasePromotion& target) {
  const auto issued = UtcTicks(target.issued_at);
  const auto new_until = UtcTicks(target.new_flows_until);
  const auto active_until = UtcTicks(target.active_flows_until);
  if (!issued || !new_until || !active_until) return std::nullopt;
  FILETIME current{};
  ::GetSystemTimePreciseAsFileTime(&current);
  const auto now = (static_cast<std::uint64_t>(current.dwHighDateTime) << 32) | current.dwLowDateTime;
  constexpr std::uint64_t minute = 60ULL * 10000000ULL;
  if (now < *issued || now >= *new_until || *new_until <= *issued ||
      *active_until < *new_until || *new_until - *issued > 10 * minute ||
      *active_until - *issued > 60 * minute) return std::nullopt;
  const auto clock = ReadBootClock();
  if (!clock || *active_until <= now) return std::nullopt;
  const auto remaining = (*active_until - now) / 10000ULL;
  if (remaining == 0 || remaining > 3'600'000ULL ||
      clock->elapsed_ms > 9007199254740991ULL - remaining) return std::nullopt;
  return clock->elapsed_ms + remaining;
}

bool IsActiveTransportLeaseCurrent(const BoundConnectTarget& connect, std::uint64_t deadline_elapsed_ms) {
  const auto clock = ReadBootClock();
  return clock && clock->boot_ref == connect.boot_ref && clock->elapsed_ms < deadline_elapsed_ms;
}
}
