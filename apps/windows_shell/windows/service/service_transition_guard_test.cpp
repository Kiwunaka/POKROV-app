#include <winsock2.h>
#include <windows.h>
#include <fwpmu.h>
#include <sddl.h>

#include "service_transition_guard.h"

#include <array>
#include <iostream>
#include <memory>
#include <string>
#include <vector>

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
  // Actual VM readback changed from 65534 to 65515 with twenty higher
  // WinDivert sublayers, none containing filters at our protected ALE layers.
  FWPM_SUBLAYER0 persisted_layer{};
  persisted_layer.flags = FWPM_SUBLAYER_FLAG_PERSISTENT;
  persisted_layer.weight = 65515;
  expect(TransitionGuardSubLayerMatchesForTesting(persisted_layer),
         "normalized priority does not invalidate an intact persistent sublayer");
  persisted_layer.flags = 0;
  expect(!TransitionGuardSubLayerMatchesForTesting(persisted_layer),
         "priority verification cannot accept a nonpersistent sublayer");
  FWPM_FILTER0 competing{};
  competing.layerKey = FWPM_LAYER_ALE_AUTH_CONNECT_V4;
  competing.action.type = FWP_ACTION_PERMIT;
  expect(!TransitionGuardFilterCanOverrideForTesting(competing, 65535, 65515),
         "higher soft permit remains overridable by the guard block");
  competing.flags = FWPM_FILTER_FLAG_CLEAR_ACTION_RIGHT;
  expect(TransitionGuardFilterCanOverrideForTesting(competing, 65535, 65515) &&
             TransitionGuardFilterCanOverrideForTesting(competing, 65515, 65515),
         "higher or equal hard permit must reject normalized priority");
  expect(!TransitionGuardFilterCanOverrideForTesting(competing, 65514, 65515),
         "lower hard permit cannot override the guard block");
  competing.flags |= FWPM_FILTER_FLAG_DISABLED;
  expect(!TransitionGuardFilterCanOverrideForTesting(competing, 65535, 65515),
         "disabled hard permit is not an arbitration conflict");
  competing.flags = 0;
  for (const auto action : {FWP_ACTION_CALLOUT_TERMINATING, FWP_ACTION_CALLOUT_UNKNOWN}) {
    competing.action.type = action;
    expect(TransitionGuardFilterCanOverrideForTesting(competing, 65535, 65515) &&
               TransitionGuardFilterCanOverrideForTesting(competing, 65515, 65515),
           "higher or equal permitting callout must reject normalized priority");
  }
  competing.layerKey = FWPM_LAYER_OUTBOUND_IPPACKET_V4;
  expect(!TransitionGuardFilterCanOverrideForTesting(competing, 65535, 65515),
         "a WinDivert network-layer filter does not compete in protected ALE");
  competing.layerKey = FWPM_LAYER_ALE_AUTH_CONNECT_V4;
  competing.action.type = FWP_ACTION_CALLOUT_INSPECTION;
  expect(!TransitionGuardFilterCanOverrideForTesting(competing, 65535, 65515),
         "inspection-only callout cannot return a permit");
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
      if (index == 0) {
        auto core_permit = f;
        core_permit.subLayerKey = {};
        core_permit.flags = FWPM_FILTER_FLAG_CLEAR_ACTION_RIGHT;
        std::array<FWPM_FILTER_CONDITION0, 2> conditions{user, app};
        core_permit.filterCondition = conditions.data();
        expect(!TransitionGuardFilterCanOverrideForTesting(core_permit, 65535, 65534),
               "higher hard permit for the same service and System identity is already allowed");
        core_permit.numFilterConditions = 1;
        core_permit.filterCondition = &conditions[1];
        expect(TransitionGuardFilterCanOverrideForTesting(core_permit, 65535, 65534),
               "APP_ID-only Core permit still overrides the guard");
        core_permit.numFilterConditions = 2;
        core_permit.filterCondition = conditions.data();
        std::vector<UINT8> other_app(app.conditionValue.byteBlob->data,
                                    app.conditionValue.byteBlob->data + app.conditionValue.byteBlob->size);
        other_app[0] ^= 1;
        FWP_BYTE_BLOB other_app_blob{static_cast<UINT32>(other_app.size()), other_app.data()};
        conditions[1].conditionValue.byteBlob = &other_app_blob;
        expect(TransitionGuardFilterCanOverrideForTesting(core_permit, 65535, 65534),
               "another executable cannot use the System exception");
        conditions[1] = app;
        PSECURITY_DESCRIPTOR other_sd = nullptr;
        ULONG other_sd_size = 0;
        const bool other_sd_ready = ::ConvertStringSecurityDescriptorToSecurityDescriptorW(
            L"D:(A;;CC;;;WD)", SDDL_REVISION_1, &other_sd, &other_sd_size) != FALSE;
        expect(other_sd_ready, "different SID fixture builds");
        if (other_sd_ready) {
          FWP_BYTE_BLOB other_user_blob{other_sd_size, static_cast<UINT8*>(other_sd)};
          conditions[0].conditionValue.sd = &other_user_blob;
          expect(TransitionGuardFilterCanOverrideForTesting(core_permit, 65535, 65534),
                 "the same executable under another identity is not already allowed");
          conditions[0] = user;
          ::LocalFree(other_sd);
        }
        core_permit.action.type = FWP_ACTION_CALLOUT_TERMINATING;
        expect(TransitionGuardFilterCanOverrideForTesting(core_permit, 65535, 65534),
               "matching identities cannot authorize an unknown callout permit");
      }
    } else {
      expect(f.numFilterConditions == 0, "block covers existing/new TCP/UDP, including DNS");
    }
    ++index;
  });
  expect(error.empty() && index == 8, "actual policy builds read-only");

  // Observed Flowseal failure: the guard blocked injected control packets at
  // ALE_AUTH_CONNECT_V4. Inspect the actual temporary exception without
  // changing host WFP policy; no app-wide or destination-wide permit is valid.
  WSADATA winsock{};
  const bool winsock_ready = ::WSAStartup(MAKEWORD(2, 2), &winsock) == 0;
  const SOCKET control = winsock_ready ? ::socket(AF_INET, SOCK_STREAM, IPPROTO_TCP) : INVALID_SOCKET;
  sockaddr_in bound{};
  bound.sin_family = AF_INET;
  bound.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
  const BOOL exclusive = TRUE;
  int bound_size = sizeof(bound);
  const bool bound_ready = control != INVALID_SOCKET &&
      ::setsockopt(control, SOL_SOCKET, SO_EXCLUSIVEADDRUSE,
          reinterpret_cast<const char*>(&exclusive), sizeof(exclusive)) == 0 &&
      ::bind(control, reinterpret_cast<const sockaddr*>(&bound), sizeof(bound)) == 0 &&
      ::getsockname(control, reinterpret_cast<sockaddr*>(&bound), &bound_size) == 0;
  expect(bound_ready && bound.sin_port != 0, "control fixture could not reserve an exclusive ephemeral port");
  sockaddr_in peer{};
  int peer_size = sizeof(peer);
  expect(!bound_ready || ::getpeername(control, reinterpret_cast<sockaddr*>(&peer), &peer_size) == SOCKET_ERROR,
         "pre-connect fixture unexpectedly has a peer");
  const bool inspected = bound_ready && VisitLocalDpiControlPermitForTesting(
      control, htonl(0xcb007114), [&](const FWPM_FILTER0& f) {
    expect(f.layerKey == FWPM_LAYER_ALE_AUTH_CONNECT_V4 &&
               f.subLayerKey == GUID{0x541c71c5, 0x2ab4, 0x49b7,
                   {0xa1, 0xa3, 0x56, 0x4f, 0xc8, 0x5c, 0xef, 0x31}} &&
               f.flags == 0 && f.action.type == FWP_ACTION_PERMIT &&
               f.weight.type == FWP_UINT64 && f.weight.uint64 && *f.weight.uint64 == 3,
           "control socket permit must be nonpersistent and soft in the guard sublayer");
    expect(f.numFilterConditions == 6, "control permit must retain exact tuple and physical interface");
    if (f.numFilterConditions != 6) return;
    const std::array<const GUID*, 6> keys = {
        &FWPM_CONDITION_IP_PROTOCOL, &FWPM_CONDITION_IP_LOCAL_ADDRESS,
        &FWPM_CONDITION_IP_REMOTE_ADDRESS, &FWPM_CONDITION_IP_LOCAL_PORT,
        &FWPM_CONDITION_IP_REMOTE_PORT, &FWPM_CONDITION_IP_LOCAL_INTERFACE};
    for (size_t i = 0; i < keys.size(); ++i) {
      expect(f.filterCondition[i].fieldKey == *keys[i] &&
                 f.filterCondition[i].matchType == FWP_MATCH_EQUAL,
             "control permit cannot omit a tuple field or allow an address range");
    }
    const auto* c = f.filterCondition;
    expect(c[0].conditionValue.type == FWP_UINT8 && c[0].conditionValue.uint8 == IPPROTO_TCP &&
               c[1].conditionValue.type == FWP_UINT32 && c[1].conditionValue.uint32 == INADDR_LOOPBACK &&
               c[2].conditionValue.type == FWP_UINT32 && c[2].conditionValue.uint32 == 0xcb007114 &&
               c[3].conditionValue.type == FWP_UINT16 && c[3].conditionValue.uint16 == ntohs(bound.sin_port) &&
               c[4].conditionValue.type == FWP_UINT16 && c[4].conditionValue.uint16 == 443 &&
               c[5].conditionValue.type == FWP_UINT64 && c[5].conditionValue.uint64 &&
               *c[5].conditionValue.uint64 == 0x600000c000000,
           "only the held pre-connect TCP443 tuple on its physical interface may bypass our block");
  });
  expect(inspected, "exact permit must be constructible before SYN/getpeername succeeds");
  if (control != INVALID_SOCKET) ::closesocket(control);
  if (winsock_ready) ::WSACleanup();
#endif
  return failures == 0 ? 0 : 1;
}
