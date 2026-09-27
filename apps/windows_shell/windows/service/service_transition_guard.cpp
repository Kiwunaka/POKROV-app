#include <winsock2.h>
#include <windows.h>
#include <fwpmu.h>
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
constexpr size_t kFilterCount = 8;
// The VM's BFE roundtrip normalized requested 65535 to 65534. Use the actual
// supported priority explicitly, without accepting arbitrary lower priorities.
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
    conditions_[0].fieldKey = FWPM_CONDITION_ALE_APP_ID;
    conditions_[0].matchType = FWP_MATCH_EQUAL;
    conditions_[0].conditionValue.type = FWP_BYTE_BLOB_TYPE;
    conditions_[0].conditionValue.byteBlob = app_;
    conditions_[1].fieldKey = FWPM_CONDITION_ALE_USER_ID;
    conditions_[1].matchType = FWP_MATCH_EQUAL;
    conditions_[1].conditionValue.type = FWP_SECURITY_DESCRIPTOR_TYPE;
    conditions_[1].conditionValue.sd = &system_blob_;
    return {};
  }

  FWPM_FILTER0 At(size_t index) {
    const bool permit = index % 2 == 0;
    FWPM_FILTER0 filter{};
    filter.filterKey = FilterKey(index);
    filter.displayData.name = const_cast<wchar_t*>(
        permit ? L"POKROV transition service" : L"POKROV transition block");
    filter.flags = FWPM_FILTER_FLAG_PERSISTENT;
    filter.layerKey = *kLayers[index / 2];
    filter.subLayerKey = kSubLayer;
    filter.weight.type = FWP_UINT64;
    filter.weight.uint64 = permit ? &permit_weight_ : &block_weight_;
    filter.action.type = permit ? FWP_ACTION_PERMIT : FWP_ACTION_BLOCK;
    if (permit) {
      filter.numFilterConditions = static_cast<UINT32>(conditions_.size());
      filter.filterCondition = conditions_.data();
    }
    // Soft permit applies only inside our sublayer; it cannot override another
    // firewall's block. The unconditional default block is a hard block.
    return filter;
  }

 private:
  FWP_BYTE_BLOB* app_ = nullptr;
  PSECURITY_DESCRIPTOR system_sd_ = nullptr;
  FWP_BYTE_BLOB system_blob_{};
  std::array<FWPM_FILTER_CONDITION0, 2> conditions_{};
  UINT64 permit_weight_ = 2;
  UINT64 block_weight_ = 1;
};

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
    const bool equal = e.conditionValue.type == FWP_BYTE_BLOB_TYPE
        ? SameBlob(a.conditionValue.byteBlob, e.conditionValue.byteBlob)
        : SameBlob(a.conditionValue.sd, e.conditionValue.sd);
    if (!equal) return false;
  }
  return true;
}

bool MatchesSubLayer(const FWPM_SUBLAYER0& actual) {
  return actual.flags == FWPM_SUBLAYER_FLAG_PERSISTENT &&
         actual.weight == kSubLayerWeight && actual.providerKey == nullptr;
}

class WindowsGuardBackend final : public TransitionGuardBackend {
 public:
  ~WindowsGuardBackend() override {
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
    DWORD result = ERROR_SUCCESS;
    FWPM_SUBLAYER0* layer = nullptr;
    result = ::FwpmSubLayerGetByKey0(engine_, &kSubLayer, &layer);
    if (result == ERROR_SUCCESS) {
      any = true;
      complete = MatchesSubLayer(*layer);
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
    const auto error = ExplicitOff();
    return error.empty() ? error : Report(TransitionGuardOperation::kFinish, error);
  }

  std::string ExplicitOff() override {
    state_ = TransitionGuardState::kIncomplete;
    if (const auto error = backend_->Remove(); !error.empty()) return error;
    if (const auto error = Refresh(); !error.empty()) return error;
    return state_ == TransitionGuardState::kOff
        ? "" : "transition_guard_remove_not_verified";
  }

  bool IsArmed() const override { return state_ != TransitionGuardState::kOff; }

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
      auto failure = backend_->LastFailure();
      if (operation == TransitionGuardOperation::kFinish &&
          error == "transition_guard_remove_not_verified") {
        failure = {TransitionGuardStage::kRemoveVerify, 0};
      }
      events_->RecordTransitionGuardFailure(operation, failure.stage,
                                            failure.wfp_error);
    }
    return error;
  }

  std::unique_ptr<TransitionGuardBackend> backend_;
  ServiceEventSink* events_ = nullptr;
  TransitionGuardState state_ = TransitionGuardState::kIncomplete;
};

}  // namespace

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
#endif

}  // namespace pokrov::service
