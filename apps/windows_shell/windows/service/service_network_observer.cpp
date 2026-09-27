#ifndef _WIN32_WINNT
#define _WIN32_WINNT 0x0A00
#endif
#define WIN32_LEAN_AND_MEAN
#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>
#include <iphlpapi.h>
#include <bcrypt.h>
#include <wlanapi.h>

#include "service_network_observer.h"
#include "service_profile_identity.h"

#include <algorithm>
#include <atomic>
#include <array>
#include <mutex>
#include <string>
#include <utility>
#include <vector>

namespace pokrov::service {
namespace {

template <typename T>
void Append(std::string& output, const T& value) {
  output.append(reinterpret_cast<const char*>(&value), sizeof(value));
}

void AppendText(std::string& output, const std::wstring& value) {
  Append(output, value.size());
  output.append(reinterpret_cast<const char*>(value.data()), value.size() * sizeof(wchar_t));
}

std::optional<std::string> Address(const SOCKET_ADDRESS& address) {
  if (address.lpSockaddr == nullptr) return std::nullopt;
  std::string output;
  const auto family = address.lpSockaddr->sa_family;
  Append(output, family);
  if (family == AF_INET && address.iSockaddrLength >= static_cast<int>(sizeof(sockaddr_in))) {
    Append(output, reinterpret_cast<const sockaddr_in*>(address.lpSockaddr)->sin_addr);
  } else if (family == AF_INET6 && address.iSockaddrLength >= static_cast<int>(sizeof(sockaddr_in6))) {
    const auto* ipv6 = reinterpret_cast<const sockaddr_in6*>(address.lpSockaddr);
    Append(output, ipv6->sin6_addr);
    Append(output, ipv6->sin6_scope_id);
  } else {
    return std::nullopt;
  }
  return output;
}

void AppendRows(std::string& output, std::vector<std::string> rows) {
  std::sort(rows.begin(), rows.end());
  Append(output, rows.size());
  for (const auto& row : rows) {
    Append(output, row.size());
    output += row;
  }
}

}  // namespace

struct ServiceNetworkObserver::State {
  std::atomic<std::uint64_t> revision{1};
  std::atomic<bool> ready{false};
  std::atomic<ULONG64> owned_luid{0};
  HANDLE interfaces = nullptr;
  HANDLE addresses = nullptr;
  HANDLE routes = nullptr;
  HANDLE wlan = nullptr;
  bool wlan_notifications = false;
  std::mutex sample_lock;
  std::optional<std::string> previous;
  std::mutex reference_lock;
  std::optional<ServiceNetworkContext> retained_context;
  std::string selection_salt;

  State() {
    std::array<BYTE, 32> salt{};
    if (::BCryptGenRandom(nullptr, salt.data(), static_cast<ULONG>(salt.size()),
                         BCRYPT_USE_SYSTEM_PREFERRED_RNG) >= 0) {
      selection_salt.assign(reinterpret_cast<const char*>(salt.data()), salt.size());
    }
    if (::NotifyIpInterfaceChange(AF_UNSPEC, InterfaceChanged, this, FALSE, &interfaces) == NO_ERROR &&
        ::NotifyUnicastIpAddressChange(AF_UNSPEC, AddressChanged, this, FALSE, &addresses) == NO_ERROR &&
        ::NotifyRouteChange2(AF_UNSPEC, RouteChanged, this, FALSE, &routes) == NO_ERROR) {
      ready = true;
    }
  }

  ~State() {
    ready = false;
    // Called by the dispatcher owner, never from a notification callback.
    // Cancellation joins callbacks before their context is destroyed.
    if (interfaces != nullptr) ::CancelMibChangeNotify2(interfaces);
    if (addresses != nullptr) ::CancelMibChangeNotify2(addresses);
    if (routes != nullptr) ::CancelMibChangeNotify2(routes);
    if (wlan != nullptr) {
      if (wlan_notifications) ::WlanRegisterNotification(wlan, WLAN_NOTIFICATION_SOURCE_NONE,
          FALSE, nullptr, nullptr, nullptr, nullptr);
      ::WlanCloseHandle(wlan, nullptr);
    }
  }

  bool IsOwned(const NET_LUID& luid) {
    if (luid.Value != 0 && luid.Value == owned_luid.load()) return true;
    WCHAR alias[IF_MAX_STRING_SIZE + 1]{};
    if (::ConvertInterfaceLuidToAlias(&luid, alias, IF_MAX_STRING_SIZE + 1) == NO_ERROR &&
        std::wstring(alias) == L"POKROV") {
      owned_luid = luid.Value;
      return true;
    }
    return false;
  }

  void Changed(const NET_LUID* luid) {
    if (luid == nullptr || !IsOwned(*luid)) ++revision;
  }

  static void CALLBACK InterfaceChanged(PVOID context, PMIB_IPINTERFACE_ROW row, MIB_NOTIFICATION_TYPE) {
    static_cast<State*>(context)->Changed(row == nullptr ? nullptr : &row->InterfaceLuid);
  }
  static void CALLBACK AddressChanged(PVOID context, PMIB_UNICASTIPADDRESS_ROW row, MIB_NOTIFICATION_TYPE) {
    static_cast<State*>(context)->Changed(row == nullptr ? nullptr : &row->InterfaceLuid);
  }
  static void CALLBACK RouteChanged(PVOID context, PMIB_IPFORWARD_ROW2 row, MIB_NOTIFICATION_TYPE) {
    static_cast<State*>(context)->Changed(row == nullptr ? nullptr : &row->InterfaceLuid);
  }

  static void WINAPI WifiChanged(PWLAN_NOTIFICATION_DATA event, PVOID context) {
    if (event == nullptr) return;
    const bool connection_change = event->NotificationSource == WLAN_NOTIFICATION_SOURCE_ACM &&
        (event->NotificationCode == wlan_notification_acm_connection_start ||
         event->NotificationCode == wlan_notification_acm_connection_complete ||
         event->NotificationCode == wlan_notification_acm_disconnecting ||
         event->NotificationCode == wlan_notification_acm_disconnected ||
         event->NotificationCode == wlan_notification_acm_interface_arrival ||
         event->NotificationCode == wlan_notification_acm_interface_removal ||
         event->NotificationCode == wlan_notification_acm_operational_state_change);
    const bool roaming_change = event->NotificationSource == WLAN_NOTIFICATION_SOURCE_MSM &&
        (event->NotificationCode == wlan_notification_msm_roaming_start ||
         event->NotificationCode == wlan_notification_msm_roaming_end ||
         event->NotificationCode == wlan_notification_msm_connected ||
         event->NotificationCode == wlan_notification_msm_disconnected);
    if (connection_change || roaming_change) ++static_cast<State*>(context)->revision;
  }

  std::optional<std::string> ReadWifi(std::vector<ULONG64> required_luids) {
    if (wlan == nullptr) {
      DWORD negotiated = 0;
      if (::WlanOpenHandle(2, nullptr, &negotiated, &wlan) != ERROR_SUCCESS) return std::nullopt;
    }
    if (!wlan_notifications) {
      if (::WlanRegisterNotification(wlan, WLAN_NOTIFICATION_SOURCE_ACM | WLAN_NOTIFICATION_SOURCE_MSM,
          FALSE, WifiChanged, this, nullptr, nullptr) != ERROR_SUCCESS) return std::nullopt;
      wlan_notifications = true;
    }
    PWLAN_INTERFACE_INFO_LIST wifi_interfaces = nullptr;
    if (::WlanEnumInterfaces(wlan, nullptr, &wifi_interfaces) != ERROR_SUCCESS) return std::nullopt;
    std::vector<std::string> rows;
    bool valid = wifi_interfaces->dwNumberOfItems > 0 && wifi_interfaces->dwNumberOfItems <= 256;
    for (DWORD index = 0; valid && index < wifi_interfaces->dwNumberOfItems; ++index) {
      const auto& info = wifi_interfaces->InterfaceInfo[index];
      NET_LUID luid{};
      if (::ConvertInterfaceGuidToLuid(&info.InterfaceGuid, &luid) != NO_ERROR) {
        valid = false;
        break;
      }
      const auto required = std::find(required_luids.begin(), required_luids.end(), luid.Value);
      if (required != required_luids.end()) required_luids.erase(required);
      std::string row;
      Append(row, info.InterfaceGuid);
      Append(row, info.isState);
      if (info.isState == wlan_interface_state_connected ||
          info.isState == wlan_interface_state_ad_hoc_network_formed) {
        DWORD size = 0;
        PVOID raw = nullptr;
        const auto status = ::WlanQueryInterface(wlan, &info.InterfaceGuid,
            wlan_intf_opcode_current_connection, nullptr, &size, &raw, nullptr);
        if (status != ERROR_SUCCESS || raw == nullptr || size < sizeof(WLAN_CONNECTION_ATTRIBUTES)) {
          if (raw != nullptr) ::WlanFreeMemory(raw);
          valid = false;
          break;
        }
        const auto* connection = static_cast<PWLAN_CONNECTION_ATTRIBUTES>(raw);
        const auto& association = connection->wlanAssociationAttributes;
        const auto ssid_length = association.dot11Ssid.uSSIDLength;
        if (ssid_length > sizeof(association.dot11Ssid.ucSSID)) {
          valid = false;
        } else {
          Append(row, ssid_length);
          row.append(reinterpret_cast<const char*>(association.dot11Ssid.ucSSID), ssid_length);
          row.append(reinterpret_cast<const char*>(association.dot11Bssid), sizeof(association.dot11Bssid));
          Append(row, connection->wlanSecurityAttributes.dot11AuthAlgorithm);
          Append(row, connection->wlanSecurityAttributes.dot11CipherAlgorithm);
        }
        ::WlanFreeMemory(raw);
      }
      rows.push_back(std::move(row));
    }
    ::WlanFreeMemory(wifi_interfaces);
    if (!valid || !required_luids.empty()) return std::nullopt;
    std::string result;
    AppendRows(result, std::move(rows));
    return result;
  }

  std::optional<std::string> ReadAdapters() {
    ULONG size = 16 * 1024;
    std::vector<unsigned char> buffer(size);
    auto* adapters = reinterpret_cast<IP_ADAPTER_ADDRESSES*>(buffer.data());
    constexpr ULONG flags = GAA_FLAG_SKIP_ANYCAST | GAA_FLAG_SKIP_MULTICAST;
    auto status = ::GetAdaptersAddresses(AF_UNSPEC, flags, nullptr, adapters, &size);
    // Match the existing service recovery adapter-read bound.
    if (status == ERROR_BUFFER_OVERFLOW && size <= 1024 * 1024) {
      buffer.resize(size);
      adapters = reinterpret_cast<IP_ADAPTER_ADDRESSES*>(buffer.data());
      status = ::GetAdaptersAddresses(AF_UNSPEC, flags, nullptr, adapters, &size);
    }
    if (status != NO_ERROR) return std::nullopt;
    std::vector<std::string> rows;
    std::vector<ULONG64> wifi_luids;
    for (auto* adapter = adapters; adapter != nullptr; adapter = adapter->Next) {
      if (adapter->IfType == IF_TYPE_SOFTWARE_LOOPBACK || IsOwned(adapter->Luid)) continue;
      if (adapter->IfType == IF_TYPE_IEEE80211 && adapter->OperStatus == IfOperStatusUp) {
        wifi_luids.push_back(adapter->Luid.Value);
      }
      std::string row;
      Append(row, adapter->Luid.Value);
      Append(row, adapter->OperStatus);
      Append(row, adapter->Mtu);
      Append(row, adapter->Ipv4Metric);
      Append(row, adapter->Ipv6Metric);
      AppendText(row, adapter->DnsSuffix == nullptr ? L"" : adapter->DnsSuffix);
      std::vector<std::string> unicast;
      for (auto* item = adapter->FirstUnicastAddress; item != nullptr; item = item->Next) {
        auto address = Address(item->Address);
        if (!address) return std::nullopt;
        Append(*address, item->OnLinkPrefixLength);
        Append(*address, item->DadState);
        unicast.push_back(std::move(*address));
      }
      AppendRows(row, std::move(unicast));
      // DNS order affects resolver choice, so preserve it rather than sorting.
      for (auto* item = adapter->FirstDnsServerAddress; item != nullptr; item = item->Next) {
        const auto address = Address(item->Address);
        if (!address) return std::nullopt;
        Append(row, address->size());
        row += *address;
      }
      rows.push_back(std::move(row));
    }
    std::string result;
    AppendRows(result, std::move(rows));
    if (!wifi_luids.empty()) {
      const auto wifi = ReadWifi(std::move(wifi_luids));
      if (!wifi) return std::nullopt;
      Append(result, wifi->size());
      result += *wifi;
    }
    return result;
  }
};

ServiceNetworkObserver::ServiceNetworkObserver() : state_(std::make_unique<State>()) {}
ServiceNetworkObserver::~ServiceNetworkObserver() = default;

std::optional<std::uint64_t> ServiceNetworkObserver::Sample() {
  if (!state_->ready) return std::nullopt;
  std::lock_guard<std::mutex> lock(state_->sample_lock);
  const auto before = state_->revision.load();
  const auto current = state_->ReadAdapters();
  if (!current || before != state_->revision.load()) {
    ++state_->revision;
    state_->previous.reset();
    return std::nullopt;
  }
  auto captured = before;
  if (state_->previous && state_->previous != current) {
    auto expected = before;
    if (!state_->revision.compare_exchange_strong(expected, before + 1)) {
      state_->previous.reset();
      return std::nullopt;
    }
    captured = before + 1;
  }
  state_->previous = current;
  return captured;  // A later callback invalidates this value, never joins it.
}

bool ServiceNetworkObserver::IsCurrent(std::uint64_t revision) const {
  return state_->ready && state_->revision.load() == revision;
}

std::optional<ServiceNetworkContext> ServiceNetworkObserver::ReadContext() {
  const auto revision = Sample();
  if (!revision) return std::nullopt;
  std::lock_guard<std::mutex> lock(state_->reference_lock);
  if (!IsCurrent(*revision)) return std::nullopt;
  if (!state_->retained_context || state_->retained_context->revision != *revision) {
    std::array<BYTE, 16> bytes{};
    if (::BCryptGenRandom(nullptr, bytes.data(), static_cast<ULONG>(bytes.size()),
        BCRYPT_USE_SYSTEM_PREFERRED_RNG) < 0) return std::nullopt;
    constexpr char hex[] = "0123456789abcdef";
    std::string reference = "network_";
    for (const auto byte : bytes) {
      reference += hex[byte >> 4];
      reference += hex[byte & 15];
    }
    state_->retained_context = ServiceNetworkContext{*revision, std::move(reference)};
  }
  if (!IsCurrent(*revision)) return std::nullopt;
  return state_->retained_context;
}

std::optional<CandidateNetworkContext> ServiceNetworkObserver::ReadCandidateContext() {
  const auto context = ReadContext();
  if (!context || state_->selection_salt.empty()) return std::nullopt;
  MIB_IPFORWARD_TABLE2* routes = nullptr;
  if (::GetIpForwardTable2(AF_UNSPEC, &routes) != NO_ERROR) return std::nullopt;
  std::optional<MIB_IPFORWARD_ROW2> chosen;
  MIB_IF_ROW2 chosen_adapter{};
  std::uint64_t best_metric = UINT64_MAX;
  for (ULONG index = 0; index < routes->NumEntries; ++index) {
    const auto& route = routes->Table[index];
    if (route.DestinationPrefix.PrefixLength != 0 || route.Loopback || route.ValidLifetime == 0) continue;
    MIB_IF_ROW2 adapter{};
    adapter.InterfaceLuid = route.InterfaceLuid;
    if (::GetIfEntry2(&adapter) != NO_ERROR || !adapter.InterfaceAndOperStatusFlags.HardwareInterface ||
        adapter.OperStatus != IfOperStatusUp || adapter.MediaConnectState == MediaConnectStateDisconnected ||
        adapter.Type == IF_TYPE_SOFTWARE_LOOPBACK || adapter.Type == IF_TYPE_TUNNEL ||
        adapter.Type == IF_TYPE_PROP_VIRTUAL || state_->IsOwned(route.InterfaceLuid)) continue;
    MIB_IPINTERFACE_ROW family{};
    family.Family = route.DestinationPrefix.Prefix.si_family;
    family.InterfaceLuid = route.InterfaceLuid;
    if (::GetIpInterfaceEntry(&family) != NO_ERROR) continue;
    const auto metric = static_cast<std::uint64_t>(route.Metric) + family.Metric;
    if (metric < best_metric) { chosen = route; chosen_adapter = adapter; best_metric = metric; }
  }
  ::FreeMibTable(routes);
  if (!chosen) return std::nullopt;
  std::string identity = state_->selection_salt;
  Append(identity, chosen->InterfaceLuid.Value);
  // Metrics/DNS/address renewals fence an in-flight probe, but do not erase
  // the manager's remembered failures for the same physical network.
  Append(identity, chosen->NextHop.si_family);
  if (chosen->NextHop.si_family == AF_INET) Append(identity, chosen->NextHop.Ipv4.sin_addr);
  else {
    Append(identity, chosen->NextHop.Ipv6.sin6_addr);
    Append(identity, chosen->NextHop.Ipv6.sin6_scope_id);
  }
  if (chosen_adapter.Type == IF_TYPE_IEEE80211) {
    HANDLE wlan = nullptr;
    DWORD version = 0;
    if (::WlanOpenHandle(2, nullptr, &version, &wlan) != ERROR_SUCCESS) return std::nullopt;
    DWORD size = 0;
    PVOID raw = nullptr;
    const auto status = ::WlanQueryInterface(wlan, &chosen_adapter.InterfaceGuid,
        wlan_intf_opcode_current_connection, nullptr, &size, &raw, nullptr);
    bool valid = status == ERROR_SUCCESS && raw != nullptr && size >= sizeof(WLAN_CONNECTION_ATTRIBUTES);
    if (valid) {
      const auto* connection = static_cast<WLAN_CONNECTION_ATTRIBUTES*>(raw);
      const auto& ssid = connection->wlanAssociationAttributes.dot11Ssid;
      valid = ssid.uSSIDLength <= sizeof(ssid.ucSSID);
      if (valid) {
        Append(identity, ssid.uSSIDLength);
        identity.append(reinterpret_cast<const char*>(ssid.ucSSID), ssid.uSSIDLength);
        Append(identity, connection->wlanSecurityAttributes.dot11AuthAlgorithm);
      }
    }
    if (raw != nullptr) ::WlanFreeMemory(raw);
    ::WlanCloseHandle(wlan, nullptr);
    if (!valid) return std::nullopt;
  }
  const auto length = ::WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, chosen_adapter.Alias,
      -1, nullptr, 0, nullptr, nullptr);
  if (length <= 1 || !IsCurrent(context->revision)) return std::nullopt;
  std::string alias(static_cast<std::size_t>(length), '\0');
  if (::WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, chosen_adapter.Alias,
      -1, alias.data(), length, nullptr, nullptr) != length) return std::nullopt;
  alias.pop_back();
  const auto digest = ProfileDigest(identity);
  if (digest.empty()) return std::nullopt;
  return CandidateNetworkContext{*context, "selection_" + digest, std::move(alias)};
}

}  // namespace pokrov::service
