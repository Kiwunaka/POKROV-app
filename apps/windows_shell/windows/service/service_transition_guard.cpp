#include <winsock2.h>
#include <windows.h>
#include <fwpmu.h>
#include <iphlpapi.h>
#include <objbase.h>
#include <sddl.h>

#include "service_transition_guard.h"

#include <array>
#include <cstring>
#include <utility>

namespace pokrov::service {
namespace {

// Stable ownership keys allow recovery after service termination. No provider
// service association: disabling/uninstalling the SCM service must not silently
// disable the persisted block. ExplicitOff removes these objects atomically.
constexpr GUID kSubLayer = {0x541c71c5, 0x2ab4, 0x49b7,
                           {0xa1, 0xa3, 0x56, 0x4f, 0xc8, 0x5c, 0xef, 0x31}};
constexpr GUID kFilterBase = {0x0a06bf20, 0xc38a, 0x4e21,
                             {0x94, 0xc6, 0x30, 0x06, 0xa8, 0x92, 0x5d, 0x10}};
constexpr size_t kGuardFilterCount = 8;
constexpr size_t kLoopbackFilterEnd = 12;
constexpr size_t kFilterCount = 16;
// Request high priority. Observed BFE readback varies with installed sublayers;
// verify actual arbitration against competing ALE permits instead of a number.
constexpr UINT16 kSubLayerWeight = 0xfffe;
const std::array<const GUID*, 4> kLayers = {
    &FWPM_LAYER_ALE_AUTH_CONNECT_V4, &FWPM_LAYER_ALE_AUTH_CONNECT_V6,
    &FWPM_LAYER_ALE_AUTH_RECV_ACCEPT_V4, &FWPM_LAYER_ALE_AUTH_RECV_ACCEPT_V6};

GUID FilterKey(size_t index) {
  GUID key = kFilterBase;
  key.Data1 += static_cast<unsigned long>(index);
  return key;
}

bool SameBlob(const FWP_BYTE_BLOB* a, const FWP_BYTE_BLOB* b) {
  return a && b && a->size == b->size &&
         (a->size == 0 || (a->data && b->data &&
                          std::memcmp(a->data, b->data, a->size) == 0));
}

class FilterDefinitions {
 public:
  ~FilterDefinitions() {
    if (app_) ::FwpmFreeMemory0(reinterpret_cast<void**>(&app_));
    if (system_sd_) ::LocalFree(system_sd_);
    if (dhcp_sd_) ::LocalFree(dhcp_sd_);
  }

  std::string Initialize(DWORD* error_code = nullptr) {
    // Core is a DLL in this SYSTEM service, not a separate allowed application.
    std::array<wchar_t, 32768> executable{};
    const DWORD length = ::GetModuleFileNameW(
        nullptr, executable.data(), static_cast<DWORD>(executable.size()));
    if (length == 0 || length >= executable.size()) {
      if (error_code) *error_code = length == 0 ? ::GetLastError() : ERROR_INSUFFICIENT_BUFFER;
      return "transition_guard_identity_failed";
    }
    const DWORD app_error = ::FwpmGetAppIdFromFileName0(executable.data(), &app_);
    if (app_error != ERROR_SUCCESS) {
      if (error_code) *error_code = app_error;
      return "transition_guard_identity_failed";
    }
    ULONG sd_size = 0;
    // CC is FWP_ACTRL_MATCH_FILTER (1): only the LocalSystem SID matches.
    if (!::ConvertStringSecurityDescriptorToSecurityDescriptorW(
            L"D:(A;;CC;;;SY)", SDDL_REVISION_1, &system_sd_, &sd_size)) {
      if (error_code) *error_code = ::GetLastError();
      return "transition_guard_identity_failed";
    }
    system_blob_ = {sd_size, static_cast<UINT8*>(system_sd_)};
    if (!::ConvertStringSecurityDescriptorToSecurityDescriptorW(
            L"D:(A;;CC;;;LS)(A;;CC;;;SY)", SDDL_REVISION_1, &dhcp_sd_, &sd_size)) {
      if (error_code) *error_code = ::GetLastError();
      return "transition_guard_identity_failed";
    }
    dhcp_blob_ = {sd_size, static_cast<UINT8*>(dhcp_sd_)};
    conditions_[0].fieldKey = FWPM_CONDITION_ALE_APP_ID;
    conditions_[0].matchType = FWP_MATCH_EQUAL;
    conditions_[0].conditionValue.type = FWP_BYTE_BLOB_TYPE;
    conditions_[0].conditionValue.byteBlob = app_;
    conditions_[1].fieldKey = FWPM_CONDITION_ALE_USER_ID;
    conditions_[1].matchType = FWP_MATCH_EQUAL;
    conditions_[1].conditionValue.type = FWP_SECURITY_DESCRIPTOR_TYPE;
    conditions_[1].conditionValue.sd = &system_blob_;
    loopback_condition_.fieldKey = FWPM_CONDITION_FLAGS;
    loopback_condition_.matchType = FWP_MATCH_FLAGS_ALL_SET;
    loopback_condition_.conditionValue.type = FWP_UINT32;
    loopback_condition_.conditionValue.uint32 = FWP_CONDITION_FLAG_IS_LOOPBACK;
    for (size_t layer = 0; layer < kLayers.size(); ++layer) {
      const UINT16 local_port = layer % 2 == 0 ? 68 : 546;
      auto& dhcp = dhcp_conditions_[layer];
      dhcp[0].fieldKey = FWPM_CONDITION_IP_PROTOCOL;
      dhcp[0].matchType = FWP_MATCH_EQUAL;
      dhcp[0].conditionValue.type = FWP_UINT8;
      dhcp[0].conditionValue.uint8 = IPPROTO_UDP;
      dhcp[1].fieldKey = FWPM_CONDITION_IP_LOCAL_PORT;
      dhcp[1].matchType = FWP_MATCH_EQUAL;
      dhcp[1].conditionValue.type = FWP_UINT16;
      dhcp[1].conditionValue.uint16 = local_port;
      dhcp[2].fieldKey = FWPM_CONDITION_IP_REMOTE_PORT;
      dhcp[2].matchType = FWP_MATCH_EQUAL;
      dhcp[2].conditionValue.type = FWP_UINT16;
      dhcp[2].conditionValue.uint16 = layer % 2 == 0 ? local_port - 1 : local_port + 1;
      dhcp[3].fieldKey = FWPM_CONDITION_ALE_USER_ID;
      dhcp[3].matchType = FWP_MATCH_EQUAL;
      dhcp[3].conditionValue.type = FWP_SECURITY_DESCRIPTOR_TYPE;
      dhcp[3].conditionValue.sd = &dhcp_blob_;
    }
    return {};
  }

  FWPM_FILTER0 At(size_t index) {
    const bool service = index < kGuardFilterCount;
    const bool loopback = !service && index < kLoopbackFilterEnd;
    const bool permit = !service || index % 2 == 0;
    const size_t layer = service ? index / 2 :
        loopback ? index - kGuardFilterCount : index - kLoopbackFilterEnd;
    FWPM_FILTER0 filter{};
    filter.filterKey = FilterKey(index);
    filter.displayData.name = const_cast<wchar_t*>(
        loopback ? L"POKROV loopback" : !service ? L"POKROV DHCP" :
        permit ? L"POKROV transition service" : L"POKROV transition block");
    filter.flags = FWPM_FILTER_FLAG_PERSISTENT;
    filter.layerKey = *kLayers[layer];
    filter.subLayerKey = kSubLayer;
    filter.weight.type = FWP_UINT64;
    filter.weight.uint64 = permit ? &permit_weight_ : &block_weight_;
    filter.action.type = permit ? FWP_ACTION_PERMIT : FWP_ACTION_BLOCK;
    if (service && permit) {
      filter.numFilterConditions = static_cast<UINT32>(conditions_.size());
      filter.filterCondition = conditions_.data();
    } else if (loopback) {
      filter.numFilterConditions = 1;
      filter.filterCondition = &loopback_condition_;
    } else if (!service) {
      filter.numFilterConditions = static_cast<UINT32>(dhcp_conditions_[layer].size());
      filter.filterCondition = dhcp_conditions_[layer].data();
    }
    // Soft permit applies only inside our sublayer; it cannot override another
    // firewall's block. The unconditional default block is a hard block.
    return filter;
  }

 private:
  FWP_BYTE_BLOB* app_ = nullptr;
  PSECURITY_DESCRIPTOR system_sd_ = nullptr;
  PSECURITY_DESCRIPTOR dhcp_sd_ = nullptr;
  FWP_BYTE_BLOB system_blob_{};
  FWP_BYTE_BLOB dhcp_blob_{};
  std::array<FWPM_FILTER_CONDITION0, 2> conditions_{};
  FWPM_FILTER_CONDITION0 loopback_condition_{};
  std::array<std::array<FWPM_FILTER_CONDITION0, 4>, kLayers.size()> dhcp_conditions_{};
  UINT64 permit_weight_ = 2;
  UINT64 block_weight_ = 1;
};

class LocalDpiControlFilter {
 public:
  LocalDpiControlFilter(const sockaddr_in& local, const sockaddr_in& remote,
                       NET_LUID interface_luid, const GUID& sublayer = kSubLayer)
      : interface_luid_(interface_luid), sublayer_(sublayer) {
    const std::array<const GUID*, 6> keys = {
        &FWPM_CONDITION_IP_PROTOCOL, &FWPM_CONDITION_IP_LOCAL_ADDRESS,
        &FWPM_CONDITION_IP_REMOTE_ADDRESS, &FWPM_CONDITION_IP_LOCAL_PORT,
        &FWPM_CONDITION_IP_REMOTE_PORT, &FWPM_CONDITION_IP_LOCAL_INTERFACE};
    for (size_t i = 0; i < keys.size(); ++i) {
      conditions_[i].fieldKey = *keys[i];
      conditions_[i].matchType = FWP_MATCH_EQUAL;
    }
    conditions_[0].conditionValue.type = FWP_UINT8;
    conditions_[0].conditionValue.uint8 = IPPROTO_TCP;
    conditions_[1].conditionValue.type = FWP_UINT32;
    conditions_[1].conditionValue.uint32 = ntohl(local.sin_addr.s_addr);
    conditions_[2].conditionValue.type = FWP_UINT32;
    conditions_[2].conditionValue.uint32 = ntohl(remote.sin_addr.s_addr);
    conditions_[3].conditionValue.type = FWP_UINT16;
    conditions_[3].conditionValue.uint16 = ntohs(local.sin_port);
    conditions_[4].conditionValue.type = FWP_UINT16;
    conditions_[4].conditionValue.uint16 = ntohs(remote.sin_port);
    conditions_[5].conditionValue.type = FWP_UINT64;
    conditions_[5].conditionValue.uint64 = &interface_luid_.Value;
  }

  FWPM_FILTER0 Definition() {
    FWPM_FILTER0 filter{};
    filter.displayData.name = const_cast<wchar_t*>(L"POKROV local DPI control socket");
    filter.layerKey = FWPM_LAYER_ALE_AUTH_CONNECT_V4;
    filter.subLayerKey = sublayer_;
    filter.weight.type = FWP_UINT64;
    filter.weight.uint64 = &weight_;
    filter.action.type = FWP_ACTION_PERMIT;
    filter.numFilterConditions = static_cast<UINT32>(conditions_.size());
    filter.filterCondition = conditions_.data();
    // Soft permit overrides only our block for this held socket and physical
    // interface. Other applications, destinations and firewall blocks remain.
    return filter;
  }

 private:
  NET_LUID interface_luid_{};
  GUID sublayer_{};
  std::array<FWPM_FILTER_CONDITION0, 6> conditions_{};
  UINT64 weight_ = 3;
};

bool ReadLocalDpiControlEndpoints(SOCKET socket, std::uint32_t remote_ipv4_network_order,
                                  sockaddr_in* local, sockaddr_in* remote) {
  int size = sizeof(*local), exclusive_size = sizeof(BOOL);
  BOOL exclusive = FALSE;
  if (::getsockname(socket, reinterpret_cast<sockaddr*>(local), &size) != 0 ||
      local->sin_family != AF_INET || local->sin_port == 0 ||
      ::getsockopt(socket, SOL_SOCKET, SO_EXCLUSIVEADDRUSE,
          reinterpret_cast<char*>(&exclusive), &exclusive_size) != 0 || !exclusive) return false;
  remote->sin_family = AF_INET;
  remote->sin_port = htons(443);
  remote->sin_addr.s_addr = remote_ipv4_network_order;
  return true;
}

bool Matches(const FWPM_FILTER0& actual, const FWPM_FILTER0& expected) {
  // BFE adds INDEXED to the service permits; it does not change their policy.
  // DISABLED, CLEAR_ACTION_RIGHT and every other unexpected flag still fail.
  if ((actual.flags & ~FWPM_FILTER_FLAG_INDEXED) != expected.flags ||
      actual.providerKey != nullptr ||
      actual.subLayerKey != expected.subLayerKey ||
      actual.layerKey != expected.layerKey ||
      actual.action.type != expected.action.type ||
      actual.weight.type != FWP_UINT64 || !actual.weight.uint64 ||
      *actual.weight.uint64 != *expected.weight.uint64 ||
      actual.numFilterConditions != expected.numFilterConditions) return false;
  for (UINT32 i = 0; i < expected.numFilterConditions; ++i) {
    const auto& a = actual.filterCondition[i];
    const auto& e = expected.filterCondition[i];
    if (a.fieldKey != e.fieldKey || a.matchType != e.matchType ||
        a.conditionValue.type != e.conditionValue.type) return false;
    switch (e.conditionValue.type) {
      case FWP_BYTE_BLOB_TYPE:
        if (!SameBlob(a.conditionValue.byteBlob, e.conditionValue.byteBlob)) return false;
        break;
      case FWP_SECURITY_DESCRIPTOR_TYPE:
        if (!SameBlob(a.conditionValue.sd, e.conditionValue.sd)) return false;
        break;
      case FWP_UINT8:
        if (a.conditionValue.uint8 != e.conditionValue.uint8) return false;
        break;
      case FWP_UINT16:
        if (a.conditionValue.uint16 != e.conditionValue.uint16) return false;
        break;
      case FWP_UINT32:
        if (a.conditionValue.uint32 != e.conditionValue.uint32) return false;
        break;
      default:
        return false;
    }
  }
  return true;
}

bool MatchesSubLayer(const FWPM_SUBLAYER0& actual) {
  return actual.flags == FWPM_SUBLAYER_FLAG_PERSISTENT &&
         actual.providerKey == nullptr;
}

bool IsPotentialGuardOverride(const FWPM_FILTER0& filter) {
  if (filter.subLayerKey == kSubLayer ||
      (filter.flags & FWPM_FILTER_FLAG_DISABLED) != 0) return false;
  bool protected_layer = false;
  for (const auto* layer : kLayers) protected_layer |= filter.layerKey == *layer;
  if (!protected_layer) return false;
  // Higher hard permits can suppress a lower static block. A terminating or
  // unknown callout may also return a hard permit; inspection cannot do so.
  return (filter.action.type == FWP_ACTION_PERMIT &&
          (filter.flags & FWPM_FILTER_FLAG_CLEAR_ACTION_RIGHT) != 0) ||
         filter.action.type == FWP_ACTION_CALLOUT_TERMINATING ||
         filter.action.type == FWP_ACTION_CALLOUT_UNKNOWN;
}

bool IsGuardServicePermit(const FWPM_FILTER0& filter, const FWPM_FILTER0& permit) {
  // Core runs inside this service. Its hard permit is harmless only when it
  // matches the guard's exact executable AND LocalSystem exception.
  if (filter.action.type != FWP_ACTION_PERMIT ||
      filter.numFilterConditions != permit.numFilterConditions ||
      !filter.filterCondition) return false;
  for (UINT32 i = 0; i < permit.numFilterConditions; ++i) {
    const auto& expected = permit.filterCondition[i];
    bool matched = false;
    for (UINT32 j = 0; j < filter.numFilterConditions; ++j) {
      const auto& actual = filter.filterCondition[j];
      if (actual.fieldKey != expected.fieldKey ||
          actual.matchType != expected.matchType ||
          actual.conditionValue.type != expected.conditionValue.type) continue;
      matched = expected.conditionValue.type == FWP_BYTE_BLOB_TYPE
          ? SameBlob(actual.conditionValue.byteBlob, expected.conditionValue.byteBlob)
          : SameBlob(actual.conditionValue.sd, expected.conditionValue.sd);
      if (matched) break;
    }
    if (!matched) return false;
  }
  return true;
}

bool CanOverrideGuard(const FWPM_FILTER0& filter, UINT16 sublayer_weight,
                      UINT16 guard_weight, const FWPM_FILTER0& service_permit) {
  return sublayer_weight >= guard_weight && IsPotentialGuardOverride(filter) &&
         !IsGuardServicePermit(filter, service_permit);
}

DWORD VerifyGuardPriority(HANDLE engine, UINT16 guard_weight,
                          const FWPM_FILTER0& service_permit, bool* safe) {
  *safe = false;
  for (const auto* layer : kLayers) {
    FWPM_FILTER_ENUM_TEMPLATE0 query{};
    query.layerKey = *layer;
    query.enumType = FWP_FILTER_ENUM_FULLY_CONTAINED;
    query.actionMask = 0xffffffff;
    HANDLE enumeration = nullptr;
    DWORD result = ::FwpmFilterCreateEnumHandle0(engine, &query, &enumeration);
    if (result != ERROR_SUCCESS) return result;
    bool conflict = false;
    while (result == ERROR_SUCCESS && !conflict) {
      FWPM_FILTER0** filters = nullptr;
      UINT32 count = 0;
      result = ::FwpmFilterEnum0(engine, enumeration, 128, &filters, &count);
      for (UINT32 i = 0; result == ERROR_SUCCESS && i < count && !conflict; ++i) {
        const auto& filter = *filters[i];
        if (!IsPotentialGuardOverride(filter)) continue;
        FWPM_SUBLAYER0* sublayer = nullptr;
        result = ::FwpmSubLayerGetByKey0(engine, &filter.subLayerKey, &sublayer);
        if (result == ERROR_SUCCESS) {
          conflict = CanOverrideGuard(filter, sublayer->weight, guard_weight, service_permit);
          ::FwpmFreeMemory0(reinterpret_cast<void**>(&sublayer));
        }
      }
      if (filters) ::FwpmFreeMemory0(reinterpret_cast<void**>(&filters));
      if (count == 0) break;
    }
    const DWORD close_result = ::FwpmFilterDestroyEnumHandle0(engine, enumeration);
    if (result != ERROR_SUCCESS) return result;
    if (close_result != ERROR_SUCCESS) return close_result;
    if (conflict) return ERROR_SUCCESS;
  }
  *safe = true;
  return ERROR_SUCCESS;
}

class WindowsGuardBackend final : public TransitionGuardBackend {
 public:
  ~WindowsGuardBackend() override {
    if (tunnel_engine_) ::FwpmEngineClose0(tunnel_engine_);
    // Non-dynamic session: closing the handle NEVER removes committed filters.
    if (engine_) ::FwpmEngineClose0(engine_);
  }

  std::string Read(TransitionGuardState* state) override {
    last_failure_ = {TransitionGuardStage::kReadVerify, 0};
    *state = TransitionGuardState::kIncomplete;
    if (const auto error = Open(); !error.empty()) return error;
    FilterDefinitions definitions;
    DWORD code = 0;
    if (const auto error = definitions.Initialize(&code); !error.empty())
      return Fail(TransitionGuardStage::kIdentity, code, error);
    code = ::FwpmTransactionBegin0(engine_, FWPM_TXN_READ_ONLY);
    if (code != ERROR_SUCCESS)
      return Fail(TransitionGuardStage::kReadBegin, code, "transition_guard_read_failed");
    bool any = false;
    bool complete = true;
    UINT16 guard_weight = 0;
    DWORD result = ERROR_SUCCESS;
    FWPM_SUBLAYER0* layer = nullptr;
    result = ::FwpmSubLayerGetByKey0(engine_, &kSubLayer, &layer);
    if (result == ERROR_SUCCESS) {
      any = true;
      complete = MatchesSubLayer(*layer);
      guard_weight = layer->weight;
      ::FwpmFreeMemory0(reinterpret_cast<void**>(&layer));
    } else if (result == FWP_E_SUBLAYER_NOT_FOUND) {
      complete = false;
      result = ERROR_SUCCESS;
    }
    for (size_t i = 0; result == ERROR_SUCCESS && i < kFilterCount; ++i) {
      const auto expected = definitions.At(i);
      FWPM_FILTER0* actual = nullptr;
      result = ::FwpmFilterGetByKey0(engine_, &expected.filterKey, &actual);
      if (result == ERROR_SUCCESS) {
        any = true;
        complete = Matches(*actual, expected) && complete;
        ::FwpmFreeMemory0(reinterpret_cast<void**>(&actual));
      } else if (result == FWP_E_FILTER_NOT_FOUND) {
        complete = false;
        result = ERROR_SUCCESS;
      }
    }
    if (result == ERROR_SUCCESS && complete)
      result = VerifyGuardPriority(engine_, guard_weight, definitions.At(0), &complete);
    ::FwpmTransactionAbort0(engine_);
    if (result != ERROR_SUCCESS)
      return Fail(TransitionGuardStage::kReadQuery, result, "transition_guard_read_failed");
    *state = complete ? TransitionGuardState::kArmed
                     : any ? TransitionGuardState::kIncomplete
                           : TransitionGuardState::kOff;
    return {};
  }

  std::string Install() override {
    last_failure_ = {TransitionGuardStage::kInstallApply, 0};
    if (const auto error = Open(); !error.empty()) return error;
    FilterDefinitions definitions;
    DWORD code = 0;
    if (const auto error = definitions.Initialize(&code); !error.empty())
      return Fail(TransitionGuardStage::kIdentity, code, error);
    code = ::FwpmTransactionBegin0(engine_, 0);
    if (code != ERROR_SUCCESS)
      return Fail(TransitionGuardStage::kInstallBegin, code, "transition_guard_install_failed");
    DWORD result = DeleteOwned();
    FWPM_SUBLAYER0 layer{};
    layer.subLayerKey = kSubLayer;
    layer.displayData.name = const_cast<wchar_t*>(L"POKROV transition guard");
    layer.flags = FWPM_SUBLAYER_FLAG_PERSISTENT;
    layer.weight = kSubLayerWeight;
    if (result == ERROR_SUCCESS) result = ::FwpmSubLayerAdd0(engine_, &layer, nullptr);
    for (size_t i = 0; result == ERROR_SUCCESS && i < kFilterCount; ++i) {
      const auto filter = definitions.At(i);
      result = ::FwpmFilterAdd0(engine_, &filter, nullptr, nullptr);
    }
    return Complete(result, "transition_guard_install_failed",
                    TransitionGuardStage::kInstallApply,
                    TransitionGuardStage::kInstallCommit);
  }

  std::string PermitTunnel() override {
    NET_LUID luid{};
    DWORD result = ::ConvertInterfaceAliasToLuid(L"POKROV", &luid);
    if (result != NO_ERROR)
      return Fail(TransitionGuardStage::kInstallApply, result, "transition_guard_tun_missing");
    FWPM_SESSION0 session{};
    session.flags = FWPM_SESSION_FLAG_DYNAMIC;
    session.txnWaitTimeoutInMSec = 5000;
    session.displayData.name = const_cast<wchar_t*>(L"POKROV verified tunnel");
    HANDLE engine = nullptr;
    result = ::FwpmEngineOpen0(nullptr, RPC_C_AUTHN_WINNT, nullptr, &session, &engine);
    if (result != ERROR_SUCCESS)
      return Fail(TransitionGuardStage::kEngineOpen, result, "transition_guard_tun_failed");
    result = ::FwpmTransactionBegin0(engine, 0);
    if (result == ERROR_SUCCESS) {
      UINT64 weight = 2;
      FWPM_FILTER_CONDITION0 condition{};
      condition.fieldKey = FWPM_CONDITION_IP_LOCAL_INTERFACE;
      condition.matchType = FWP_MATCH_EQUAL;
      condition.conditionValue.type = FWP_UINT64;
      condition.conditionValue.uint64 = &luid.Value;
      for (size_t layer = 0; layer < kLayers.size() && result == ERROR_SUCCESS; ++layer) {
        FWPM_FILTER0 filter{};
        filter.displayData.name = const_cast<wchar_t*>(L"POKROV tunnel permit");
        filter.layerKey = *kLayers[layer];
        filter.subLayerKey = kSubLayer;
        filter.weight.type = FWP_UINT64;
        filter.weight.uint64 = &weight;
        filter.action.type = FWP_ACTION_PERMIT;
        filter.numFilterConditions = 1;
        filter.filterCondition = &condition;
        result = ::FwpmFilterAdd0(engine, &filter, nullptr, nullptr);
      }
      if (result == ERROR_SUCCESS) result = ::FwpmTransactionCommit0(engine);
      if (result != ERROR_SUCCESS) ::FwpmTransactionAbort0(engine);
    }
    if (result != ERROR_SUCCESS) {
      ::FwpmEngineClose0(engine);
      return Fail(TransitionGuardStage::kInstallApply, result, "transition_guard_tun_failed");
    }
    tunnel_engine_ = engine;
    return {};
  }

  std::string BlockTunnel() override {
    if (!tunnel_engine_) return {};
    const DWORD result = ::FwpmEngineClose0(tunnel_engine_);
    if (result != ERROR_SUCCESS)
      return Fail(TransitionGuardStage::kRemoveApply, result, "transition_guard_tun_block_failed");
    tunnel_engine_ = nullptr;
    return {};
  }

  std::string Remove() override {
    last_failure_ = {TransitionGuardStage::kRemoveApply, 0};
    if (const auto error = Open(); !error.empty()) return error;
    const DWORD code = ::FwpmTransactionBegin0(engine_, 0);
    if (code != ERROR_SUCCESS)
      return Fail(TransitionGuardStage::kRemoveBegin, code, "transition_guard_remove_failed");
    return Complete(DeleteOwned(), "transition_guard_remove_failed",
                    TransitionGuardStage::kRemoveApply,
                    TransitionGuardStage::kRemoveCommit);
  }

  TransitionGuardFailure LastFailure() const override { return last_failure_; }

 private:
  std::string Open() {
    if (engine_) return {};
    FWPM_SESSION0 session{};
    session.displayData.name = const_cast<wchar_t*>(L"POKROV transition guard");
    session.txnWaitTimeoutInMSec = 5000;
    const DWORD code = ::FwpmEngineOpen0(nullptr, RPC_C_AUTHN_WINNT, nullptr,
                                         &session, &engine_);
    return code == ERROR_SUCCESS ? "" :
        Fail(TransitionGuardStage::kEngineOpen, code, "transition_guard_engine_failed");
  }

  DWORD DeleteOwned() {
    for (size_t i = 0; i < kFilterCount; ++i) {
      const GUID key = FilterKey(i);
      const DWORD result = ::FwpmFilterDeleteByKey0(engine_, &key);
      if (result != ERROR_SUCCESS && result != FWP_E_FILTER_NOT_FOUND) return result;
    }
    const DWORD result = ::FwpmSubLayerDeleteByKey0(engine_, &kSubLayer);
    return result == FWP_E_SUBLAYER_NOT_FOUND ? ERROR_SUCCESS : result;
  }

  std::string Complete(DWORD result, const char* error,
                       TransitionGuardStage apply_stage,
                       TransitionGuardStage commit_stage) {
    TransitionGuardStage stage = apply_stage;
    if (result == ERROR_SUCCESS) {
      result = ::FwpmTransactionCommit0(engine_);
      stage = commit_stage;
    }
    if (result == ERROR_SUCCESS) return {};
    ::FwpmTransactionAbort0(engine_);
    return Fail(stage, result, error);
  }

  std::string Fail(TransitionGuardStage stage, DWORD code,
                   const std::string& error) {
    last_failure_ = {stage, code};
    return error;
  }

  HANDLE engine_ = nullptr;
  HANDLE tunnel_engine_ = nullptr;
  TransitionGuardFailure last_failure_;
};

class Guard final : public RuntimeTransitionGuard {
 public:
  Guard(std::unique_ptr<TransitionGuardBackend> backend,
        ServiceEventSink* events)
      : backend_(std::move(backend)), events_(events) {
    Refresh();  // Adopt persisted state. Never remove it at startup.
  }

  std::string Start() override {
    if (const auto error = backend_->BlockTunnel(); !error.empty())
      return Report(TransitionGuardOperation::kStart, error);
    tunnel_allowed_ = false;
    const auto read_error = Refresh();
    if (!read_error.empty()) return Report(TransitionGuardOperation::kStart, read_error);
    if (state_ == TransitionGuardState::kArmed) return {};
    const auto error = backend_->Install();
    // An interrupted/readback-failed mutation is unknown, never reported off.
    state_ = TransitionGuardState::kIncomplete;
    if (!error.empty()) return Report(TransitionGuardOperation::kStart, error);
    if (const auto read = Refresh(); !read.empty())
      return Report(TransitionGuardOperation::kStart, read);
    if (state_ == TransitionGuardState::kArmed) return {};
    state_ = TransitionGuardState::kIncomplete;
    return Report(TransitionGuardOperation::kStart, "transition_guard_not_verified");
  }

  std::string Finish() override {
    if (tunnel_allowed_) return {};
    if (state_ != TransitionGuardState::kArmed)
      return Report(TransitionGuardOperation::kFinish, "transition_guard_not_verified");
    if (const auto error = backend_->PermitTunnel(); !error.empty())
      return Report(TransitionGuardOperation::kFinish, error);
    tunnel_allowed_ = true;
    return {};
  }

  std::string ExplicitOff() override {
    if (const auto error = backend_->BlockTunnel(); !error.empty()) return error;
    tunnel_allowed_ = false;
    state_ = TransitionGuardState::kIncomplete;
    if (const auto error = backend_->Remove(); !error.empty()) return error;
    if (const auto error = Refresh(); !error.empty()) return error;
    return state_ == TransitionGuardState::kOff
        ? "" : "transition_guard_remove_not_verified";
  }

  bool IsArmed() const override {
    return state_ != TransitionGuardState::kOff && !tunnel_allowed_;
  }

 private:
  std::string Refresh() {
    state_ = TransitionGuardState::kIncomplete;
    const auto error = backend_->Read(&state_);
    if (!error.empty()) state_ = TransitionGuardState::kIncomplete;
    return error;
  }

  std::string Report(TransitionGuardOperation operation,
                     const std::string& error) {
    if (events_ != nullptr) {
      const auto failure = backend_->LastFailure();
      events_->RecordTransitionGuardFailure(operation, failure.stage,
                                            failure.wfp_error);
    }
    return error;
  }

  std::unique_ptr<TransitionGuardBackend> backend_;
  ServiceEventSink* events_ = nullptr;
  TransitionGuardState state_ = TransitionGuardState::kIncomplete;
  bool tunnel_allowed_ = false;
};

}  // namespace

WindowsLocalDpiControlPermit::~WindowsLocalDpiControlPermit() {
#ifdef _DEBUG
  if (engine_ && test_ops_) { test_ops_->close(engine_); return; }
#endif
  if (engine_) ::FwpmEngineClose0(engine_);
}

bool WindowsLocalDpiControlPermit::OpenBoundSocket(std::uintptr_t bound_socket,
    std::uint32_t remote_ipv4_network_order, std::uint32_t physical_interface_index, bool standalone) {
  if (engine_ != nullptr) return false;
  sockaddr_in local{}, remote{};
  NET_LUID luid{};
  if (!ReadLocalDpiControlEndpoints(static_cast<SOCKET>(bound_socket),
          remote_ipv4_network_order, &local, &remote) ||
      ::ConvertInterfaceIndexToLuid(physical_interface_index, &luid) != NO_ERROR) return false;
  FWPM_SESSION0 session{};
  session.flags = FWPM_SESSION_FLAG_DYNAMIC;
  session.displayData.name = const_cast<wchar_t*>(L"POKROV local DPI control socket");
  DWORD opened = ERROR_SUCCESS;
#ifdef _DEBUG
  if (test_ops_) opened = test_ops_->open(session, &engine_);
  else
#endif
  opened = ::FwpmEngineOpen0(nullptr, RPC_C_AUTHN_WINNT, nullptr, &session, &engine_);
  if (opened != ERROR_SUCCESS)
    return false;
  GUID sublayer = kSubLayer;
  if (standalone) {
    // Standalone proof uses a separate scope before the guard is installed.
    if (FAILED(::CoCreateGuid(&sublayer))) return false;
    FWPM_SUBLAYER0 layer{};
    layer.subLayerKey = sublayer;
    layer.displayData.name = const_cast<wchar_t*>(L"POKROV local DPI control socket");
    layer.weight = kSubLayerWeight;
    DWORD added = ERROR_SUCCESS;
#ifdef _DEBUG
    if (test_ops_) added = test_ops_->add_sublayer(engine_, layer);
    else
#endif
    added = ::FwpmSubLayerAdd0(engine_, &layer, nullptr);
    if (added != ERROR_SUCCESS) return false;
  }
  LocalDpiControlFilter definition(local, remote, luid, sublayer);
  const auto filter = definition.Definition();
#ifdef _DEBUG
  if (test_ops_) return test_ops_->add_filter(engine_, filter) == ERROR_SUCCESS;
#endif
  return ::FwpmFilterAdd0(engine_, &filter, nullptr, nullptr) == ERROR_SUCCESS;
}

std::unique_ptr<RuntimeTransitionGuard> CreateWindowsTransitionGuard(
    ServiceEventSink* events) {
  return std::make_unique<Guard>(std::make_unique<WindowsGuardBackend>(), events);
}

std::unique_ptr<RuntimeTransitionGuard> CreateTransitionGuardForTesting(
    std::unique_ptr<TransitionGuardBackend> backend,
    ServiceEventSink* events) {
  return std::make_unique<Guard>(std::move(backend), events);
}

#ifdef _DEBUG
std::string VisitTransitionGuardFiltersForTesting(
    const std::function<void(const FWPM_FILTER0_&)>& visitor) {
  FilterDefinitions definitions;
  if (const auto error = definitions.Initialize(); !error.empty()) return error;
  for (size_t i = 0; i < kFilterCount; ++i) visitor(definitions.At(i));
  return {};
}

bool TransitionGuardFilterMatchesForTesting(
    const FWPM_FILTER0_& actual, const FWPM_FILTER0_& expected) {
  return Matches(actual, expected);
}

bool TransitionGuardSubLayerMatchesForTesting(const FWPM_SUBLAYER0_& actual) {
  return MatchesSubLayer(actual);
}

bool TransitionGuardFilterCanOverrideForTesting(const FWPM_FILTER0_& filter,
    std::uint16_t sublayer_weight, std::uint16_t guard_weight) {
  FilterDefinitions definitions;
  if (!definitions.Initialize().empty()) return true;
  return CanOverrideGuard(filter, sublayer_weight, guard_weight, definitions.At(0));
}

bool VisitLocalDpiControlPermitForTesting(std::uintptr_t bound_socket,
    std::uint32_t remote_ipv4_network_order,
    const std::function<void(const FWPM_FILTER0_&)>& visitor) {
  sockaddr_in local{}, remote{};
  if (!ReadLocalDpiControlEndpoints(static_cast<SOCKET>(bound_socket),
          remote_ipv4_network_order, &local, &remote)) return false;
  NET_LUID luid{};
  luid.Value = 0x600000c000000;
  LocalDpiControlFilter definition(local, remote, luid);
  visitor(definition.Definition());
  return true;
}
#endif

}  // namespace pokrov::service
