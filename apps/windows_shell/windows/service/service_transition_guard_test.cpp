#include <winsock2.h>
#include <windows.h>
#include <fwpmu.h>

#include "service_transition_guard.h"

#include <array>
#include <iostream>
#include <memory>
#include <string>

namespace {
using pokrov::service::TransitionGuardState;

struct StoredPolicy {
  TransitionGuardState state = TransitionGuardState::kOff;
  int installs = 0;
  int removes = 0;
  bool read_fails = false;
  bool install_fails = false;
  bool remove_fails = false;
  bool read_fails_after_install = false;
};

class FakeBackend final : public pokrov::service::TransitionGuardBackend {
 public:
  explicit FakeBackend(StoredPolicy& policy) : policy_(policy) {}
  std::string Read(TransitionGuardState* state) override {
    *state = policy_.state;
    return policy_.read_fails ? "read_failed" : "";
  }
  std::string Install() override {
    ++policy_.installs;
    if (policy_.install_fails) return "install_failed";
    policy_.state = TransitionGuardState::kArmed;
    policy_.read_fails = policy_.read_fails_after_install;
    return {};
  }
  std::string Remove() override {
    ++policy_.removes;
    if (policy_.remove_fails) return "remove_failed";
    policy_.state = TransitionGuardState::kOff;
    return {};
  }
 private:
  StoredPolicy& policy_;
};
}  // namespace

int main() {
  using namespace pokrov::service;
  int failures = 0;
  const auto expect = [&](bool value, const char* message) {
    if (!value) { std::cerr << message << '\n'; ++failures; }
  };
  const auto create = [](StoredPolicy& policy) {
    return CreateTransitionGuardForTesting(std::make_unique<FakeBackend>(policy));
  };

  StoredPolicy persisted;
  {
    auto guard = create(persisted);
    expect(!guard->IsArmed(), "clean startup is off");
    expect(guard->Start().empty() && guard->IsArmed(), "arm before Core stop");
    expect(guard->Start().empty() && persisted.installs == 1, "arm is idempotent");
  }
  expect(persisted.state == TransitionGuardState::kArmed && persisted.removes == 0,
         "destruction/crash must retain persisted block");
  {
    auto restarted = create(persisted);
    expect(restarted->IsArmed() && persisted.removes == 0,
           "restart adopts block without clearing it");
    persisted.remove_fails = true;
    expect(!restarted->Finish().empty() && restarted->IsArmed(),
           "failed finish stays armed");
    persisted.remove_fails = false;
    expect(restarted->ExplicitOff().empty() && !restarted->IsArmed(),
           "explicit off recovers persisted policy");
  }
  {
    StoredPolicy partial;
    partial.state = TransitionGuardState::kIncomplete;
    auto guard = create(partial);
    expect(guard->IsArmed() && partial.removes == 0, "partial startup requires action");
    partial.install_fails = true;
    expect(!guard->Start().empty() && guard->IsArmed(), "failed repair stays blocked");
    partial.install_fails = false;
    partial.read_fails_after_install = true;
    expect(!guard->Start().empty() && guard->IsArmed(),
           "install without readback cannot authorize Core stop");
    partial.read_fails = false;
    expect(guard->Start().empty(), "explicit retry verifies existing policy");
    expect(guard->Finish().empty() && !guard->IsArmed(), "verified replacement releases");
  }
  {
    StoredPolicy unknown;
    unknown.read_fails = true;
    auto guard = create(unknown);
    expect(guard->IsArmed() && !guard->Start().empty() && unknown.installs == 0,
           "unknown startup cannot be reported unprotected/ready");
  }

#ifdef _DEBUG
  // Actual SYSTEM-created objects read back on the Windows VM: BFE returned
  // sublayer weight 65534 and added INDEXED to the four permit filters.
  FWPM_SUBLAYER0 persisted_layer{};
  persisted_layer.flags = FWPM_SUBLAYER_FLAG_PERSISTENT;
  persisted_layer.weight = 65534;
  expect(TransitionGuardSubLayerMatchesForTesting(persisted_layer),
         "accept observed BFE sublayer priority");
  persisted_layer.weight = 65533;
  expect(!TransitionGuardSubLayerMatchesForTesting(persisted_layer),
         "reject a lower-priority sublayer");
  // Inspect actual policy definitions; this NEVER opens a WFP engine or calls
  // add/delete. Existing-flow enforcement itself is a separate opt-in VM gate.
  const std::array<const GUID*, 4> layers = {
      &FWPM_LAYER_ALE_AUTH_CONNECT_V4, &FWPM_LAYER_ALE_AUTH_CONNECT_V6,
      &FWPM_LAYER_ALE_AUTH_RECV_ACCEPT_V4, &FWPM_LAYER_ALE_AUTH_RECV_ACCEPT_V6};
  size_t index = 0;
  const auto error = VisitTransitionGuardFiltersForTesting([&](const FWPM_FILTER0& f) {
    expect(index < 8, "exactly eight owned filters");
    if (index >= 8) return;
    const bool permit = index % 2 == 0;
    expect(f.layerKey == *layers[index / 2], "both ALE directions and IP families");
    expect(f.flags == FWPM_FILTER_FLAG_PERSISTENT && f.providerKey == nullptr,
           "persistent, no dynamic/disabled-provider dependency");
    expect(f.action.type == static_cast<FWP_ACTION_TYPE>(
               permit ? FWP_ACTION_PERMIT : FWP_ACTION_BLOCK),
           "service exception precedes default block");
    auto readback = f;
    if (permit) readback.flags |= FWPM_FILTER_FLAG_INDEXED;
    expect(TransitionGuardFilterMatchesForTesting(readback, f),
           "accept actual BFE indexed permit/unmodified block");
    readback.flags |= FWPM_FILTER_FLAG_DISABLED;
    expect(!TransitionGuardFilterMatchesForTesting(readback, f),
           "indexed must not hide a disabled filter");
    readback.flags = f.flags | FWPM_FILTER_FLAG_CLEAR_ACTION_RIGHT;
    expect(!TransitionGuardFilterMatchesForTesting(readback, f),
           "reject changed filter arbitration");
    if (permit) {
      expect(f.numFilterConditions == 2, "no broad DNS/system/loopback exception");
      const auto& app = f.filterCondition[0];
      const auto& user = f.filterCondition[1];
      expect(app.fieldKey == FWPM_CONDITION_ALE_APP_ID &&
                 app.matchType == FWP_MATCH_EQUAL &&
                 app.conditionValue.type == FWP_BYTE_BLOB_TYPE &&
                 app.conditionValue.byteBlob->size > 0,
             "allow exact executable identity");
      expect(user.fieldKey == FWPM_CONDITION_ALE_USER_ID &&
                 user.matchType == FWP_MATCH_EQUAL &&
                 user.conditionValue.type == FWP_SECURITY_DESCRIPTOR_TYPE,
             "allow only System identity on that executable");
      BOOL present = FALSE, defaulted = FALSE;
      PACL acl = nullptr;
      auto sd = reinterpret_cast<PSECURITY_DESCRIPTOR>(user.conditionValue.sd->data);
      expect(::GetSecurityDescriptorDacl(sd, &present, &acl, &defaulted) &&
                 present && acl && acl->AceCount == 1, "one identity ACE");
      void* raw_ace = nullptr;
      expect(acl && ::GetAce(acl, 0, &raw_ace), "System ACE readable");
      if (raw_ace) {
        const auto* ace = static_cast<ACCESS_ALLOWED_ACE*>(raw_ace);
        expect(ace->Header.AceType == ACCESS_ALLOWED_ACE_TYPE && ace->Mask == 1 &&
                   ::IsWellKnownSid(const_cast<DWORD*>(&ace->SidStart), WinLocalSystemSid),
               "System SID is sole exception");
      }
    } else {
      expect(f.numFilterConditions == 0, "block covers existing/new TCP/UDP, including DNS");
    }
    ++index;
  });
  expect(error.empty() && index == 8, "actual policy builds read-only");
#endif
  return failures == 0 ? 0 : 1;
}
