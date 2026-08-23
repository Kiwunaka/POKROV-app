#include "service_recovery.h"

#ifndef _WIN32_WINNT
#define _WIN32_WINNT 0x0A00
#endif
#ifndef WINVER
#define WINVER 0x0A00
#endif
#define WIN32_LEAN_AND_MEAN
#include <winsock2.h>
#include <ws2tcpip.h>
#include <iphlpapi.h>
#include <windows.h>

#include <array>
#include <charconv>
#include <cstdint>
#include <cstring>
#include <memory>
#include <limits>
#include <sstream>
#include <string>
#include <type_traits>
#include <utility>
#include <vector>

namespace pokrov::service {
namespace {

constexpr wchar_t kOwnedInterfaceName[] = L"POKROV";
constexpr char kSnapshotMagic[] = "POKROV_NETWORK_V1";
constexpr std::size_t kMaximumRoutes = 256;
constexpr std::size_t kMaximumAddresses = 32;
constexpr std::size_t kMaximumDnsTextLength = 2048;

struct InterfaceRecord {
  ADDRESS_FAMILY family = AF_UNSPEC;
  bool forwarding = false;
  bool weak_host_send = false;
  bool weak_host_receive = false;
  bool automatic_metric = true;
  ULONG metric = 0;
  ULONG mtu = 0;
  NL_ROUTER_DISCOVERY_BEHAVIOR router_discovery = RouterDiscoveryUnchanged;
  ULONG dad_transmits = 0;
  bool managed = false;
  bool other = false;
  bool advertise_default_route = false;
};

struct AddressRecord {
  SOCKADDR_INET address{};
  NL_PREFIX_ORIGIN prefix_origin = IpPrefixOriginOther;
  NL_SUFFIX_ORIGIN suffix_origin = IpSuffixOriginOther;
  ULONG valid_lifetime = 0;
  ULONG preferred_lifetime = 0;
  UINT8 prefix_length = 0;
  bool skip_as_source = false;
  NL_DAD_STATE dad_state = IpDadStateInvalid;
};

struct RouteRecord {
  IP_ADDRESS_PREFIX destination{};
  SOCKADDR_INET next_hop{};
  ULONG site_prefix_length = 0;
  ULONG valid_lifetime = 0;
  ULONG preferred_lifetime = 0;
  ULONG metric = 0;
  NL_ROUTE_PROTOCOL protocol = RouteProtocolOther;
  bool loopback = false;
  bool autoconfigure = false;
  bool publish = false;
  bool immortal = false;
  NL_ROUTE_ORIGIN origin = NlroManual;
};

struct DnsRecord {
  bool present = false;
  bool ipv6 = false;
  ULONG64 flags = 0;
  ULONG registration_enabled = 0;
  ULONG register_adapter_name = 0;
  ULONG enable_llmnr = 0;
  ULONG query_adapter_name = 0;
  std::wstring domain;
  std::wstring name_server;
  std::wstring search_list;
  std::wstring profile_name_server;
};

struct NetworkSnapshot {
  bool adapter_existed = false;
  GUID adapter_guid{};
  std::vector<InterfaceRecord> interfaces;
  std::vector<AddressRecord> addresses;
  std::vector<RouteRecord> routes;
  std::vector<DnsRecord> dns;
};

template <typename Table>
struct MibTableDeleter {
  void operator()(Table* table) const {
    if (table != nullptr) {
      ::FreeMibTable(table);
    }
  }
};

std::vector<std::string> Split(const std::string& value, char delimiter) {
  std::vector<std::string> result;
  std::size_t start = 0;
  while (start <= value.size()) {
    const auto end = value.find(delimiter, start);
    result.push_back(value.substr(start, end - start));
    if (end == std::string::npos) {
      break;
    }
    start = end + 1;
  }
  return result;
}

template <typename T>
bool ParseUnsigned(const std::string& value, T* output) {
  static_assert(std::is_unsigned_v<T>);
  if (output == nullptr || value.empty()) {
    return false;
  }
  unsigned long long parsed = 0;
  const auto result =
      std::from_chars(value.data(), value.data() + value.size(), parsed);
  if (result.ec != std::errc() || result.ptr != value.data() + value.size() ||
      parsed > static_cast<unsigned long long>((std::numeric_limits<T>::max)())) {
    return false;
  }
  *output = static_cast<T>(parsed);
  return true;
}

std::string HexBytes(const void* data, std::size_t size) {
  constexpr char hex[] = "0123456789abcdef";
  const auto* bytes = static_cast<const unsigned char*>(data);
  std::string result(size * 2, '0');
  for (std::size_t index = 0; index < size; ++index) {
    result[index * 2] = hex[bytes[index] >> 4];
    result[index * 2 + 1] = hex[bytes[index] & 0x0f];
  }
  return result;
}

bool ParseHexBytes(const std::string& value, void* output, std::size_t size) {
  if (output == nullptr || value.size() != size * 2) {
    return false;
  }
  const auto nibble = [](unsigned char character) -> int {
    if (character >= '0' && character <= '9') {
      return character - '0';
    }
    if (character >= 'a' && character <= 'f') {
      return character - 'a' + 10;
    }
    return -1;
  };
  auto* bytes = static_cast<unsigned char*>(output);
  for (std::size_t index = 0; index < size; ++index) {
    const int high = nibble(static_cast<unsigned char>(value[index * 2]));
    const int low = nibble(static_cast<unsigned char>(value[index * 2 + 1]));
    if (high < 0 || low < 0) {
      return false;
    }
    bytes[index] = static_cast<unsigned char>((high << 4) | low);
  }
  return true;
}

std::string WideToHex(const wchar_t* value) {
  if (value == nullptr) {
    return "";
  }
  const std::size_t length = wcsnlen_s(value, kMaximumDnsTextLength + 1);
  if (length > kMaximumDnsTextLength) {
    return "";
  }
  return HexBytes(value, length * sizeof(wchar_t));
}

bool HexToWide(const std::string& value, std::wstring* output) {
  if (output == nullptr || value.size() % (sizeof(wchar_t) * 2) != 0 ||
      value.size() > kMaximumDnsTextLength * sizeof(wchar_t) * 2) {
    return false;
  }
  std::wstring result(value.size() / (sizeof(wchar_t) * 2), L'\0');
  if (!ParseHexBytes(value, result.data(), result.size() * sizeof(wchar_t))) {
    return false;
  }
  *output = std::move(result);
  return true;
}

std::string AddressToString(const SOCKADDR_INET& address) {
  std::array<char, INET6_ADDRSTRLEN> buffer{};
  if (address.si_family == AF_INET &&
      ::InetNtopA(AF_INET, &address.Ipv4.sin_addr, buffer.data(),
                  static_cast<DWORD>(buffer.size())) != nullptr) {
    return buffer.data();
  }
  if (address.si_family == AF_INET6 &&
      ::InetNtopA(AF_INET6, &address.Ipv6.sin6_addr, buffer.data(),
                  static_cast<DWORD>(buffer.size())) != nullptr) {
    return buffer.data();
  }
  return "";
}

bool ParseAddress(const std::string& value, ADDRESS_FAMILY family,
                  ULONG scope_id, SOCKADDR_INET* output) {
  if (output == nullptr || (family != AF_INET && family != AF_INET6)) {
    return false;
  }
  SOCKADDR_INET parsed{};
  parsed.si_family = family;
  if (family == AF_INET) {
    if (::InetPtonA(AF_INET, value.c_str(), &parsed.Ipv4.sin_addr) != 1) {
      return false;
    }
  } else {
    if (::InetPtonA(AF_INET6, value.c_str(), &parsed.Ipv6.sin6_addr) != 1) {
      return false;
    }
    parsed.Ipv6.sin6_scope_id = scope_id;
  }
  *output = parsed;
  return true;
}

ULONG AddressScope(const SOCKADDR_INET& address) {
  return address.si_family == AF_INET6 ? address.Ipv6.sin6_scope_id : 0;
}

bool GuidEqual(const GUID& left, const GUID& right) {
  return std::memcmp(&left, &right, sizeof(GUID)) == 0;
}

struct OwnedAdapter {
  NET_LUID luid{};
  GUID guid{};
};

std::string FindOwnedAdapter(const GUID* preferred, OwnedAdapter* output,
                             bool* found) {
  if (output == nullptr || found == nullptr) {
    return "recovery_network_capture_failed";
  }
  *found = false;
  ULONG size = 16 * 1024;
  std::vector<unsigned char> buffer(size);
  auto* adapters =
      reinterpret_cast<IP_ADAPTER_ADDRESSES*>(buffer.data());
  ULONG status = ::GetAdaptersAddresses(AF_UNSPEC, GAA_FLAG_INCLUDE_PREFIX,
                                        nullptr, adapters, &size);
  if (status == ERROR_BUFFER_OVERFLOW && size <= 1024 * 1024) {
    buffer.resize(size);
    adapters = reinterpret_cast<IP_ADAPTER_ADDRESSES*>(buffer.data());
    status = ::GetAdaptersAddresses(AF_UNSPEC, GAA_FLAG_INCLUDE_PREFIX,
                                    nullptr, adapters, &size);
  }
  if (status != NO_ERROR) {
    return "recovery_network_capture_failed";
  }
  for (auto* adapter = adapters; adapter != nullptr; adapter = adapter->Next) {
    GUID guid{};
    if (::ConvertInterfaceLuidToGuid(&adapter->Luid, &guid) != NO_ERROR) {
      continue;
    }
    const bool preferred_match = preferred != nullptr &&
                                 GuidEqual(*preferred, guid);
    const bool name_match =
        adapter->FriendlyName != nullptr &&
        std::wstring(adapter->FriendlyName) == kOwnedInterfaceName;
    if (!preferred_match && !name_match) {
      continue;
    }
    if (*found) {
      return "recovery_network_owner_ambiguous";
    }
    output->luid = adapter->Luid;
    output->guid = guid;
    *found = true;
  }
  return "";
}

bool CaptureInterface(const NET_LUID& luid, ADDRESS_FAMILY family,
                      InterfaceRecord* output) {
  if (output == nullptr) {
    return false;
  }
  MIB_IPINTERFACE_ROW row{};
  ::InitializeIpInterfaceEntry(&row);
  row.InterfaceLuid = luid;
  row.Family = family;
  if (::GetIpInterfaceEntry(&row) != NO_ERROR) {
    return false;
  }
  output->family = family;
  output->forwarding = row.ForwardingEnabled != FALSE;
  output->weak_host_send = row.WeakHostSend != FALSE;
  output->weak_host_receive = row.WeakHostReceive != FALSE;
  output->automatic_metric = row.UseAutomaticMetric != FALSE;
  output->metric = row.Metric;
  output->mtu = row.NlMtu;
  output->router_discovery = row.RouterDiscoveryBehavior;
  output->dad_transmits = row.DadTransmits;
  output->managed = row.ManagedAddressConfigurationSupported != FALSE;
  output->other = row.OtherStatefulConfigurationSupported != FALSE;
  output->advertise_default_route = row.AdvertiseDefaultRoute != FALSE;
  return true;
}

bool CaptureDns(const GUID& guid, bool ipv6, DnsRecord* output) {
  if (output == nullptr) {
    return false;
  }
  DNS_INTERFACE_SETTINGS settings{};
  settings.Version = DNS_INTERFACE_SETTINGS_VERSION1;
  settings.Flags = ipv6 ? DNS_SETTING_IPV6 : 0;
  const ULONG status = ::GetInterfaceDnsSettings(guid, &settings);
  if (status != NO_ERROR) {
    return false;
  }
  output->present = true;
  output->ipv6 = ipv6;
  output->flags = settings.Flags;
  output->registration_enabled = settings.RegistrationEnabled;
  output->register_adapter_name = settings.RegisterAdapterName;
  output->enable_llmnr = settings.EnableLLMNR;
  output->query_adapter_name = settings.QueryAdapterName;
  if (settings.Domain != nullptr) {
    output->domain = settings.Domain;
  }
  if (settings.NameServer != nullptr) {
    output->name_server = settings.NameServer;
  }
  if (settings.SearchList != nullptr) {
    output->search_list = settings.SearchList;
  }
  if (settings.ProfileNameServer != nullptr) {
    output->profile_name_server = settings.ProfileNameServer;
  }
  ::FreeInterfaceDnsSettings(&settings);
  return output->domain.size() <= kMaximumDnsTextLength &&
         output->name_server.size() <= kMaximumDnsTextLength &&
         output->search_list.size() <= kMaximumDnsTextLength &&
         output->profile_name_server.size() <= kMaximumDnsTextLength;
}

std::string CaptureSnapshot(NetworkSnapshot* snapshot) {
  if (snapshot == nullptr) {
    return "recovery_network_capture_failed";
  }
  OwnedAdapter adapter{};
  bool found = false;
  auto error = FindOwnedAdapter(nullptr, &adapter, &found);
  if (!error.empty() || !found) {
    return error;
  }
  snapshot->adapter_existed = true;
  snapshot->adapter_guid = adapter.guid;

  constexpr std::array<ADDRESS_FAMILY, 2> families = {
      static_cast<ADDRESS_FAMILY>(AF_INET),
      static_cast<ADDRESS_FAMILY>(AF_INET6)};
  for (const ADDRESS_FAMILY family : families) {
    InterfaceRecord record{};
    if (!CaptureInterface(adapter.luid, family, &record)) {
      return "recovery_network_capture_failed";
    }
    snapshot->interfaces.push_back(record);
  }

  PMIB_UNICASTIPADDRESS_TABLE raw_addresses = nullptr;
  if (::GetUnicastIpAddressTable(AF_UNSPEC, &raw_addresses) != NO_ERROR) {
    return "recovery_network_capture_failed";
  }
  std::unique_ptr<MIB_UNICASTIPADDRESS_TABLE,
                  MibTableDeleter<MIB_UNICASTIPADDRESS_TABLE>>
      addresses(raw_addresses);
  for (ULONG index = 0; index < addresses->NumEntries; ++index) {
    const auto& row = addresses->Table[index];
    if (row.InterfaceLuid.Value != adapter.luid.Value) {
      continue;
    }
    if (snapshot->addresses.size() >= kMaximumAddresses) {
      return "recovery_network_snapshot_too_large";
    }
    snapshot->addresses.push_back(AddressRecord{
        row.Address, row.PrefixOrigin, row.SuffixOrigin, row.ValidLifetime,
        row.PreferredLifetime, row.OnLinkPrefixLength,
        row.SkipAsSource != FALSE, row.DadState});
  }

  PMIB_IPFORWARD_TABLE2 raw_routes = nullptr;
  if (::GetIpForwardTable2(AF_UNSPEC, &raw_routes) != NO_ERROR) {
    return "recovery_network_capture_failed";
  }
  std::unique_ptr<MIB_IPFORWARD_TABLE2,
                  MibTableDeleter<MIB_IPFORWARD_TABLE2>>
      routes(raw_routes);
  for (ULONG index = 0; index < routes->NumEntries; ++index) {
    const auto& row = routes->Table[index];
    if (row.InterfaceLuid.Value != adapter.luid.Value) {
      continue;
    }
    if (snapshot->routes.size() >= kMaximumRoutes) {
      return "recovery_network_snapshot_too_large";
    }
    snapshot->routes.push_back(RouteRecord{
        row.DestinationPrefix, row.NextHop, row.SitePrefixLength,
        row.ValidLifetime, row.PreferredLifetime, row.Metric, row.Protocol,
        row.Loopback != FALSE, row.AutoconfigureAddress != FALSE,
        row.Publish != FALSE, row.Immortal != FALSE, row.Origin});
  }

  for (const bool ipv6 : {false, true}) {
    DnsRecord record{};
    if (!CaptureDns(adapter.guid, ipv6, &record)) {
      return "recovery_network_capture_failed";
    }
    snapshot->dns.push_back(std::move(record));
  }
  return "";
}

std::string Serialize(const NetworkSnapshot& snapshot) {
  std::ostringstream output;
  output << kSnapshotMagic << '\n';
  output << "adapter=" << (snapshot.adapter_existed ? "present" : "absent")
         << '\n';
  if (!snapshot.adapter_existed) {
    return output.str();
  }
  output << "guid=" << HexBytes(&snapshot.adapter_guid, sizeof(GUID)) << '\n';
  for (const auto& record : snapshot.interfaces) {
    output << "if=" << (record.family == AF_INET ? 4 : 6) << ','
           << record.forwarding << ',' << record.weak_host_send << ','
           << record.weak_host_receive << ',' << record.automatic_metric << ','
           << record.metric << ',' << record.mtu << ','
           << static_cast<unsigned long>(record.router_discovery) << ','
           << record.dad_transmits << ',' << record.managed << ','
           << record.other << ',' << record.advertise_default_route << '\n';
  }
  for (const auto& record : snapshot.addresses) {
    output << "addr=" << (record.address.si_family == AF_INET ? 4 : 6) << ','
           << AddressToString(record.address) << ','
           << AddressScope(record.address) << ','
           << static_cast<unsigned long>(record.prefix_origin) << ','
           << static_cast<unsigned long>(record.suffix_origin) << ','
           << record.valid_lifetime << ',' << record.preferred_lifetime << ','
           << static_cast<unsigned int>(record.prefix_length) << ','
           << record.skip_as_source << ','
           << static_cast<unsigned long>(record.dad_state) << '\n';
  }
  for (const auto& record : snapshot.routes) {
    output << "route="
           << (record.destination.Prefix.si_family == AF_INET ? 4 : 6) << ','
           << AddressToString(record.destination.Prefix) << ','
           << AddressScope(record.destination.Prefix) << ','
           << static_cast<unsigned int>(record.destination.PrefixLength) << ','
           << AddressToString(record.next_hop) << ','
           << AddressScope(record.next_hop) << ',' << record.site_prefix_length
           << ',' << record.valid_lifetime << ',' << record.preferred_lifetime
           << ',' << record.metric << ','
           << static_cast<unsigned long>(record.protocol) << ','
           << record.loopback << ',' << record.autoconfigure << ','
           << record.publish << ',' << record.immortal << ','
           << static_cast<unsigned long>(record.origin) << '\n';
  }
  for (const auto& record : snapshot.dns) {
    output << "dns=" << (record.ipv6 ? 6 : 4) << ',' << record.flags << ','
           << record.registration_enabled << ',' << record.register_adapter_name
           << ',' << record.enable_llmnr << ',' << record.query_adapter_name
           << ',' << WideToHex(record.domain.c_str()) << ','
           << WideToHex(record.name_server.c_str()) << ','
           << WideToHex(record.search_list.c_str()) << ','
           << WideToHex(record.profile_name_server.c_str()) << '\n';
  }
  return output.str();
}

bool ParseBool(const std::string& value, bool* output) {
  unsigned int parsed = 0;
  if (output == nullptr || !ParseUnsigned(value, &parsed) || parsed > 1) {
    return false;
  }
  *output = parsed == 1;
  return true;
}

bool ParseSnapshot(const std::string& serialized, NetworkSnapshot* snapshot) {
  if (snapshot == nullptr || serialized.empty() || serialized.back() != '\n') {
    return false;
  }
  const auto lines = Split(serialized.substr(0, serialized.size() - 1), '\n');
  if (lines.size() < 2 || lines[0] != kSnapshotMagic) {
    return false;
  }
  if (lines[1] == "adapter=absent") {
    return lines.size() == 2;
  }
  if (lines[1] != "adapter=present" || lines.size() < 3 ||
      lines[2].rfind("guid=", 0) != 0 ||
      !ParseHexBytes(lines[2].substr(5), &snapshot->adapter_guid,
                     sizeof(GUID))) {
    return false;
  }
  snapshot->adapter_existed = true;
  for (std::size_t line_index = 3; line_index < lines.size(); ++line_index) {
    const auto fields = Split(lines[line_index], ',');
    if (lines[line_index].rfind("if=", 0) == 0) {
      if (fields.size() != 12) {
        return false;
      }
      InterfaceRecord record{};
      unsigned int family = 0;
      unsigned long router = 0;
      if (!ParseUnsigned(fields[0].substr(3), &family) ||
          (family != 4 && family != 6) ||
          !ParseBool(fields[1], &record.forwarding) ||
          !ParseBool(fields[2], &record.weak_host_send) ||
          !ParseBool(fields[3], &record.weak_host_receive) ||
          !ParseBool(fields[4], &record.automatic_metric) ||
          !ParseUnsigned(fields[5], &record.metric) ||
          !ParseUnsigned(fields[6], &record.mtu) ||
          !ParseUnsigned(fields[7], &router) ||
          !ParseUnsigned(fields[8], &record.dad_transmits) ||
          !ParseBool(fields[9], &record.managed) ||
          !ParseBool(fields[10], &record.other) ||
          !ParseBool(fields[11], &record.advertise_default_route)) {
        return false;
      }
      record.family = family == 4 ? AF_INET : AF_INET6;
      record.router_discovery =
          static_cast<NL_ROUTER_DISCOVERY_BEHAVIOR>(router);
      snapshot->interfaces.push_back(record);
    } else if (lines[line_index].rfind("addr=", 0) == 0) {
      if (fields.size() != 10 ||
          snapshot->addresses.size() >= kMaximumAddresses) {
        return false;
      }
      AddressRecord record{};
      unsigned int family = 0;
      ULONG scope = 0;
      unsigned long prefix_origin = 0;
      unsigned long suffix_origin = 0;
      unsigned int prefix_length = 0;
      unsigned long dad_state = 0;
      if (!ParseUnsigned(fields[0].substr(5), &family) ||
          (family != 4 && family != 6) ||
          !ParseUnsigned(fields[2], &scope) ||
          !ParseAddress(fields[1], family == 4 ? AF_INET : AF_INET6, scope,
                        &record.address) ||
          !ParseUnsigned(fields[3], &prefix_origin) ||
          !ParseUnsigned(fields[4], &suffix_origin) ||
          !ParseUnsigned(fields[5], &record.valid_lifetime) ||
          !ParseUnsigned(fields[6], &record.preferred_lifetime) ||
          !ParseUnsigned(fields[7], &prefix_length) || prefix_length > 128 ||
          !ParseBool(fields[8], &record.skip_as_source) ||
          !ParseUnsigned(fields[9], &dad_state)) {
        return false;
      }
      record.prefix_origin = static_cast<NL_PREFIX_ORIGIN>(prefix_origin);
      record.suffix_origin = static_cast<NL_SUFFIX_ORIGIN>(suffix_origin);
      record.prefix_length = static_cast<UINT8>(prefix_length);
      record.dad_state = static_cast<NL_DAD_STATE>(dad_state);
      snapshot->addresses.push_back(record);
    } else if (lines[line_index].rfind("route=", 0) == 0) {
      if (fields.size() != 16 ||
          snapshot->routes.size() >= kMaximumRoutes) {
        return false;
      }
      RouteRecord record{};
      unsigned int family = 0;
      ULONG destination_scope = 0;
      unsigned int prefix_length = 0;
      ULONG next_scope = 0;
      unsigned long protocol = 0;
      unsigned long origin = 0;
      if (!ParseUnsigned(fields[0].substr(6), &family) ||
          (family != 4 && family != 6) ||
          !ParseUnsigned(fields[2], &destination_scope) ||
          !ParseAddress(fields[1], family == 4 ? AF_INET : AF_INET6,
                        destination_scope, &record.destination.Prefix) ||
          !ParseUnsigned(fields[3], &prefix_length) || prefix_length > 128 ||
          !ParseUnsigned(fields[5], &next_scope) ||
          !ParseAddress(fields[4], family == 4 ? AF_INET : AF_INET6,
                        next_scope, &record.next_hop) ||
          !ParseUnsigned(fields[6], &record.site_prefix_length) ||
          record.site_prefix_length > 128 ||
          !ParseUnsigned(fields[7], &record.valid_lifetime) ||
          !ParseUnsigned(fields[8], &record.preferred_lifetime) ||
          !ParseUnsigned(fields[9], &record.metric) ||
          !ParseUnsigned(fields[10], &protocol) ||
          !ParseBool(fields[11], &record.loopback) ||
          !ParseBool(fields[12], &record.autoconfigure) ||
          !ParseBool(fields[13], &record.publish) ||
          !ParseBool(fields[14], &record.immortal) ||
          !ParseUnsigned(fields[15], &origin)) {
        return false;
      }
      record.destination.PrefixLength = static_cast<UINT8>(prefix_length);
      record.protocol = static_cast<NL_ROUTE_PROTOCOL>(protocol);
      record.origin = static_cast<NL_ROUTE_ORIGIN>(origin);
      snapshot->routes.push_back(record);
    } else if (lines[line_index].rfind("dns=", 0) == 0) {
      if (fields.size() != 10 || snapshot->dns.size() >= 2) {
        return false;
      }
      DnsRecord record{};
      unsigned int family = 0;
      if (!ParseUnsigned(fields[0].substr(4), &family) ||
          (family != 4 && family != 6) ||
          !ParseUnsigned(fields[1], &record.flags) ||
          !ParseUnsigned(fields[2], &record.registration_enabled) ||
          !ParseUnsigned(fields[3], &record.register_adapter_name) ||
          !ParseUnsigned(fields[4], &record.enable_llmnr) ||
          !ParseUnsigned(fields[5], &record.query_adapter_name) ||
          !HexToWide(fields[6], &record.domain) ||
          !HexToWide(fields[7], &record.name_server) ||
          !HexToWide(fields[8], &record.search_list) ||
          !HexToWide(fields[9], &record.profile_name_server)) {
        return false;
      }
      record.present = true;
      record.ipv6 = family == 6;
      snapshot->dns.push_back(std::move(record));
    } else {
      return false;
    }
  }
  return snapshot->interfaces.size() == 2 && snapshot->dns.size() == 2;
}

bool DeleteOwnedRoutes(const NET_LUID& luid) {
  PMIB_IPFORWARD_TABLE2 raw = nullptr;
  if (::GetIpForwardTable2(AF_UNSPEC, &raw) != NO_ERROR) {
    return false;
  }
  std::unique_ptr<MIB_IPFORWARD_TABLE2,
                  MibTableDeleter<MIB_IPFORWARD_TABLE2>>
      routes(raw);
  for (ULONG index = 0; index < routes->NumEntries; ++index) {
    const auto& row = routes->Table[index];
    if (row.InterfaceLuid.Value == luid.Value) {
      const ULONG status = ::DeleteIpForwardEntry2(&row);
      if (status != NO_ERROR && status != ERROR_NOT_FOUND) {
        return false;
      }
    }
  }
  return true;
}

bool DeleteOwnedAddresses(const NET_LUID& luid) {
  PMIB_UNICASTIPADDRESS_TABLE raw = nullptr;
  if (::GetUnicastIpAddressTable(AF_UNSPEC, &raw) != NO_ERROR) {
    return false;
  }
  std::unique_ptr<MIB_UNICASTIPADDRESS_TABLE,
                  MibTableDeleter<MIB_UNICASTIPADDRESS_TABLE>>
      addresses(raw);
  for (ULONG index = 0; index < addresses->NumEntries; ++index) {
    const auto& row = addresses->Table[index];
    if (row.InterfaceLuid.Value == luid.Value) {
      const ULONG status = ::DeleteUnicastIpAddressEntry(&row);
      if (status != NO_ERROR && status != ERROR_NOT_FOUND) {
        return false;
      }
    }
  }
  return true;
}

bool ApplyDns(const GUID& guid, const DnsRecord& record) {
  DNS_INTERFACE_SETTINGS settings{};
  settings.Version = DNS_INTERFACE_SETTINGS_VERSION1;
  settings.Flags =
      DNS_SETTING_NAMESERVER | DNS_SETTING_SEARCHLIST | DNS_SETTING_DOMAIN |
      DNS_SETTING_REGISTRATION_ENABLED | DNS_SETTING_REGISTER_ADAPTER_NAME |
      DNS_SETTINGS_ENABLE_LLMNR | DNS_SETTINGS_QUERY_ADAPTER_NAME |
      DNS_SETTING_PROFILE_NAMESERVER;
  if (record.ipv6) {
    settings.Flags |= DNS_SETTING_IPV6;
  }
  settings.Domain = const_cast<PWSTR>(record.domain.c_str());
  settings.NameServer = const_cast<PWSTR>(record.name_server.c_str());
  settings.SearchList = const_cast<PWSTR>(record.search_list.c_str());
  settings.RegistrationEnabled = record.registration_enabled;
  settings.RegisterAdapterName = record.register_adapter_name;
  settings.EnableLLMNR = record.enable_llmnr;
  settings.QueryAdapterName = record.query_adapter_name;
  settings.ProfileNameServer =
      const_cast<PWSTR>(record.profile_name_server.c_str());
  return ::SetInterfaceDnsSettings(guid, &settings) == NO_ERROR;
}

bool ClearDns(const GUID& guid, bool ipv6) {
  DnsRecord empty{};
  empty.present = true;
  empty.ipv6 = ipv6;
  return ApplyDns(guid, empty);
}

bool RestoreInterface(const NET_LUID& luid, const InterfaceRecord& record) {
  MIB_IPINTERFACE_ROW row{};
  ::InitializeIpInterfaceEntry(&row);
  row.InterfaceLuid = luid;
  row.Family = record.family;
  if (::GetIpInterfaceEntry(&row) != NO_ERROR) {
    return false;
  }
  row.ForwardingEnabled = record.forwarding;
  row.WeakHostSend = record.weak_host_send;
  row.WeakHostReceive = record.weak_host_receive;
  row.UseAutomaticMetric = record.automatic_metric;
  row.Metric = record.metric;
  row.NlMtu = record.mtu;
  row.RouterDiscoveryBehavior = record.router_discovery;
  row.DadTransmits = record.dad_transmits;
  row.ManagedAddressConfigurationSupported = record.managed;
  row.OtherStatefulConfigurationSupported = record.other;
  row.AdvertiseDefaultRoute = record.advertise_default_route;
  return ::SetIpInterfaceEntry(&row) == NO_ERROR;
}

bool RestoreAddress(const NET_LUID& luid, const AddressRecord& record) {
  MIB_UNICASTIPADDRESS_ROW row{};
  ::InitializeUnicastIpAddressEntry(&row);
  row.InterfaceLuid = luid;
  row.Address = record.address;
  row.PrefixOrigin = record.prefix_origin;
  row.SuffixOrigin = record.suffix_origin;
  row.ValidLifetime = record.valid_lifetime;
  row.PreferredLifetime = record.preferred_lifetime;
  row.OnLinkPrefixLength = record.prefix_length;
  row.SkipAsSource = record.skip_as_source;
  row.DadState = record.dad_state;
  const ULONG status = ::CreateUnicastIpAddressEntry(&row);
  return status == NO_ERROR || status == ERROR_OBJECT_ALREADY_EXISTS;
}

bool RestoreRoute(const NET_LUID& luid, const RouteRecord& record) {
  MIB_IPFORWARD_ROW2 row{};
  ::InitializeIpForwardEntry(&row);
  row.InterfaceLuid = luid;
  row.DestinationPrefix = record.destination;
  row.NextHop = record.next_hop;
  row.SitePrefixLength = static_cast<UINT8>(record.site_prefix_length);
  row.ValidLifetime = record.valid_lifetime;
  row.PreferredLifetime = record.preferred_lifetime;
  row.Metric = record.metric;
  row.Protocol = record.protocol;
  row.Loopback = record.loopback;
  row.AutoconfigureAddress = record.autoconfigure;
  row.Publish = record.publish;
  row.Immortal = record.immortal;
  row.Origin = record.origin;
  const ULONG status = ::CreateIpForwardEntry2(&row);
  return status == NO_ERROR || status == ERROR_OBJECT_ALREADY_EXISTS;
}

class WindowsNetworkStateBackend final : public NetworkStateBackend {
 public:
  std::string Capture(std::string* snapshot) override {
    if (snapshot == nullptr) {
      return "recovery_network_capture_failed";
    }
    NetworkSnapshot captured{};
    OwnedAdapter adapter{};
    bool found = false;
    auto error = FindOwnedAdapter(nullptr, &adapter, &found);
    if (!error.empty()) {
      return error;
    }
    if (found) {
      error = CaptureSnapshot(&captured);
      if (!error.empty()) {
        return error;
      }
    }
    const auto serialized = Serialize(captured);
    if (serialized.empty() || serialized.size() > 64 * 1024) {
      return "recovery_network_snapshot_too_large";
    }
    *snapshot = serialized;
    return "";
  }

  std::string Restore(const std::string& serialized) override {
    NetworkSnapshot snapshot{};
    if (!ParseSnapshot(serialized, &snapshot)) {
      return "recovery_network_snapshot_invalid";
    }
    OwnedAdapter adapter{};
    bool found = false;
    const GUID* preferred =
        snapshot.adapter_existed ? &snapshot.adapter_guid : nullptr;
    auto error = FindOwnedAdapter(preferred, &adapter, &found);
    if (!error.empty()) {
      return error;
    }
    if (!found) {
      return snapshot.adapter_existed ? "recovery_network_owner_missing" : "";
    }
    if (!DeleteOwnedRoutes(adapter.luid) ||
        !DeleteOwnedAddresses(adapter.luid) ||
        !ClearDns(adapter.guid, false) || !ClearDns(adapter.guid, true)) {
      return "recovery_network_restore_failed";
    }
    if (!snapshot.adapter_existed) {
      return "";
    }
    for (const auto& record : snapshot.interfaces) {
      if (!RestoreInterface(adapter.luid, record)) {
        return "recovery_network_restore_failed";
      }
    }
    for (const auto& record : snapshot.addresses) {
      if (!RestoreAddress(adapter.luid, record)) {
        return "recovery_network_restore_failed";
      }
    }
    for (const auto& record : snapshot.routes) {
      if (!RestoreRoute(adapter.luid, record)) {
        return "recovery_network_restore_failed";
      }
    }
    for (const auto& record : snapshot.dns) {
      if (!ApplyDns(adapter.guid, record)) {
        return "recovery_network_restore_failed";
      }
    }
    return "";
  }
};

}  // namespace

std::unique_ptr<NetworkStateBackend> CreateWindowsNetworkStateBackend() {
  return std::make_unique<WindowsNetworkStateBackend>();
}

}  // namespace pokrov::service
