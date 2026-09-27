#include "uplink_status.h"

#define WIN32_LEAN_AND_MEAN
#include <winsock2.h>
#include <ws2tcpip.h>
#include <iphlpapi.h>
#include <netlistmgr.h>
#include <ocidl.h>
#include <wrl/client.h>

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

std::optional<bool> HasCaptivePortal() {
  const auto initialized = ::CoInitializeEx(nullptr, COINIT_MULTITHREADED);
  if (FAILED(initialized) && initialized != RPC_E_CHANGED_MODE) return std::nullopt;
  const auto result = []() -> std::optional<bool> {
    Microsoft::WRL::ComPtr<INetworkListManager> manager;
    if (FAILED(::CoCreateInstance(CLSID_NetworkListManager, nullptr, CLSCTX_ALL,
                                 IID_PPV_ARGS(&manager)))) return std::nullopt;
    Microsoft::WRL::ComPtr<IEnumNetworks> networks;
    if (FAILED(manager->GetNetworks(NLM_ENUM_NETWORK_CONNECTED, &networks))) {
      return std::nullopt;
    }
    bool observed = false;
    bool incomplete = false;
    for (;;) {
      Microsoft::WRL::ComPtr<INetwork> network;
      ULONG fetched = 0;
      const auto next = networks->Next(1, &network, &fetched);
      if (FAILED(next)) return std::nullopt;
      if (fetched == 0) break;
      Microsoft::WRL::ComPtr<IPropertyBag> properties;
      if (FAILED(network.As(&properties))) {
        incomplete = true;
        continue;
      }
      for (const auto name : {NA_InternetConnectivityV4, NA_InternetConnectivityV6}) {
        VARIANT value;
        ::VariantInit(&value);
        const auto read = properties->Read(name, &value, nullptr);
        const bool valid = SUCCEEDED(read) && value.vt == VT_UINT;
        const bool captive = valid &&
            (value.uintVal & NLM_INTERNET_CONNECTIVITY_WEBHIJACK) != 0;
        ::VariantClear(&value);
        if (captive) return true;
        observed |= valid;
        incomplete |= !valid;
      }
    }
    return observed && !incomplete ? std::optional<bool>(false) : std::nullopt;
  }();
  if (SUCCEEDED(initialized)) ::CoUninitialize();
  return result;
}
