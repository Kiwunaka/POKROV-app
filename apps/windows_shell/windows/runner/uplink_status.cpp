#include "uplink_status.h"

#define WIN32_LEAN_AND_MEAN
#include <winsock2.h>
#include <ws2tcpip.h>
#include <iphlpapi.h>

std::optional<bool> HasDefaultUplink() {
  MIB_IPFORWARD_TABLE2* routes = nullptr;
  if (::GetIpForwardTable2(AF_UNSPEC, &routes) != NO_ERROR) {
    return std::nullopt;
  }
  bool available = false;
  bool incomplete = false;
  for (ULONG index = 0; index < routes->NumEntries; ++index) {
    const auto& route = routes->Table[index];
    if (route.DestinationPrefix.PrefixLength != 0 || route.Loopback ||
        route.ValidLifetime == 0) {
      continue;
    }
    MIB_IF_ROW2 adapter{};
    adapter.InterfaceLuid = route.InterfaceLuid;
    if (::GetIfEntry2(&adapter) != NO_ERROR) {
      incomplete = true;
      continue;
    }
    // An enabled VPN interface alone cannot establish external connectivity.
    if (adapter.Type == IF_TYPE_SOFTWARE_LOOPBACK ||
        adapter.Type == IF_TYPE_TUNNEL || adapter.Type == IF_TYPE_PROP_VIRTUAL) {
      continue;
    }
    if (adapter.OperStatus == IfOperStatusUp &&
        adapter.MediaConnectState != MediaConnectStateDisconnected) {
      available = true;
      break;
    }
  }
  ::FreeMibTable(routes);
  if (available) return true;
  return incomplete ? std::nullopt : std::optional<bool>(false);
}
