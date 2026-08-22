#ifndef POKROV_SERVICE_SERVICE_SECURITY_H_
#define POKROV_SERVICE_SERVICE_SECURITY_H_

#include <windows.h>

#include <string>

namespace pokrov::service {

constexpr wchar_t kServiceRegistryPath[] =
    L"SOFTWARE\\space.pokrov\\POKROV\\Service";
constexpr wchar_t kInstallOwnerSidValue[] = L"InstallOwnerSid";

std::wstring CurrentProcessUserSid();
std::wstring InstalledOwnerSid();
std::wstring BuildPipeSddl(const std::wstring& owner_sid);
bool IsCallerIdentityAllowed(const std::wstring& caller_sid,
                             const std::wstring& owner_sid,
                             bool is_local_system, bool is_administrator);
bool AuthorizeNamedPipeCaller(HANDLE pipe, const std::wstring& owner_sid);

class PipeSecurity final {
 public:
  PipeSecurity();
  ~PipeSecurity();

  PipeSecurity(const PipeSecurity&) = delete;
  PipeSecurity& operator=(const PipeSecurity&) = delete;

  bool Initialize(const std::wstring& owner_sid);
  SECURITY_ATTRIBUTES* attributes();

 private:
  PSECURITY_DESCRIPTOR descriptor_ = nullptr;
  SECURITY_ATTRIBUTES attributes_{};
};

}  // namespace pokrov::service

#endif  // POKROV_SERVICE_SERVICE_SECURITY_H_
