#include "service_security.h"

#include <iostream>
#include <string>

namespace {

int failures = 0;

void Expect(bool condition, const char* message) {
  if (!condition) {
    std::cerr << message << '\n';
    ++failures;
  }
}

}  // namespace

int main() {
  using namespace pokrov::service;
  const auto owner = CurrentProcessUserSid();
  Expect(!owner.empty(), "current process SID was unavailable");
  const auto sddl = BuildPipeSddl(owner);
  Expect(sddl.find(L";;;SY") != std::wstring::npos,
         "pipe ACL omits LocalSystem");
  Expect(sddl.find(L";;;BA") != std::wstring::npos,
         "pipe ACL omits Administrators");
  Expect(sddl.find(owner) != std::wstring::npos,
         "pipe ACL omits installation owner");
  Expect(sddl.find(L";;;WD") == std::wstring::npos,
         "pipe ACL grants Everyone");
  Expect(sddl.find(L";;;AN") == std::wstring::npos,
         "pipe ACL grants Anonymous");

  PipeSecurity security;
  Expect(security.Initialize(owner), "pipe security descriptor did not parse");
  Expect(security.attributes() != nullptr,
         "pipe security attributes are unavailable");

  Expect(IsCallerIdentityAllowed(owner, owner, false, false),
         "installation owner was rejected");
  Expect(IsCallerIdentityAllowed(L"S-1-5-18", owner, true, false),
         "LocalSystem was rejected");
  Expect(IsCallerIdentityAllowed(L"S-1-5-21-1-2-3-1001", owner, false, true),
         "administrator was rejected");
  Expect(!IsCallerIdentityAllowed(L"S-1-5-21-1-2-3-1002", owner, false,
                                  false),
         "another caller SID was accepted");
  Expect(BuildPipeSddl(L"not-a-sid").empty(),
         "invalid owner SID produced an ACL");
  return failures == 0 ? 0 : 1;
}
