#include "service_security.h"

#include <sddl.h>

#include <cstdint>
#include <vector>

namespace pokrov::service {
namespace {

std::wstring SidToString(PSID sid) {
  if (sid == nullptr || !::IsValidSid(sid)) {
    return L"";
  }
  wchar_t* value = nullptr;
  if (!::ConvertSidToStringSidW(sid, &value) || value == nullptr) {
    return L"";
  }
  const std::wstring result(value);
  ::LocalFree(value);
  return result;
}

std::wstring TokenUserSid(HANDLE token) {
  DWORD required = 0;
  ::GetTokenInformation(token, TokenUser, nullptr, 0, &required);
  if (required == 0 || ::GetLastError() != ERROR_INSUFFICIENT_BUFFER) {
    return L"";
  }
  std::vector<std::uint8_t> buffer(required);
  if (!::GetTokenInformation(token, TokenUser, buffer.data(), required,
                             &required)) {
    return L"";
  }
  const auto* user = reinterpret_cast<const TOKEN_USER*>(buffer.data());
  return SidToString(user->User.Sid);
}

bool TokenHasWellKnownSid(HANDLE token, WELL_KNOWN_SID_TYPE type) {
  DWORD size = SECURITY_MAX_SID_SIZE;
  std::vector<std::uint8_t> sid(size);
  if (!::CreateWellKnownSid(type, nullptr, sid.data(), &size)) {
    return false;
  }
  BOOL member = FALSE;
  return ::CheckTokenMembership(token, sid.data(), &member) != FALSE &&
         member != FALSE;
}

bool IsValidSidText(const std::wstring& value) {
  PSID sid = nullptr;
  const bool valid = !value.empty() &&
                     ::ConvertStringSidToSidW(value.c_str(), &sid) != FALSE &&
                     sid != nullptr && ::IsValidSid(sid) != FALSE;
  if (sid != nullptr) {
    ::LocalFree(sid);
  }
  return valid;
}

}  // namespace

std::wstring CurrentProcessUserSid() {
  HANDLE token = nullptr;
  if (!::OpenProcessToken(::GetCurrentProcess(), TOKEN_QUERY, &token)) {
    return L"";
  }
  const auto result = TokenUserSid(token);
  ::CloseHandle(token);
  return result;
}

std::wstring InstalledOwnerSid() {
  wchar_t value[256]{};
  DWORD size = sizeof(value);
  DWORD type = 0;
  if (::RegGetValueW(HKEY_LOCAL_MACHINE, kServiceRegistryPath,
                     kInstallOwnerSidValue, RRF_RT_REG_SZ, &type, value,
                     &size) != ERROR_SUCCESS ||
      !IsValidSidText(value)) {
    return L"";
  }
  return value;
}

std::wstring BuildPipeSddl(const std::wstring& owner_sid) {
  if (!IsValidSidText(owner_sid)) {
    return L"";
  }
  return L"D:P(A;;GA;;;SY)(A;;GA;;;BA)(A;;GA;;;" + owner_sid + L")";
}

bool IsCallerIdentityAllowed(const std::wstring& caller_sid,
                             const std::wstring& owner_sid,
                             bool is_local_system, bool is_administrator) {
  return IsValidSidText(caller_sid) && IsValidSidText(owner_sid) &&
         (is_local_system || is_administrator || caller_sid == owner_sid);
}

bool AuthorizeNamedPipeCaller(HANDLE pipe, const std::wstring& owner_sid) {
  if (pipe == nullptr || pipe == INVALID_HANDLE_VALUE ||
      !IsValidSidText(owner_sid) || !::ImpersonateNamedPipeClient(pipe)) {
    return false;
  }

  HANDLE token = nullptr;
  bool allowed = false;
  if (::OpenThreadToken(::GetCurrentThread(), TOKEN_QUERY, TRUE, &token)) {
    const auto caller_sid = TokenUserSid(token);
    const bool is_system = caller_sid == L"S-1-5-18";
    const bool is_administrator =
        TokenHasWellKnownSid(token, WinBuiltinAdministratorsSid);
    allowed = IsCallerIdentityAllowed(caller_sid, owner_sid, is_system,
                                      is_administrator);
    ::CloseHandle(token);
  }
  ::RevertToSelf();
  return allowed;
}

PipeSecurity::PipeSecurity() = default;

PipeSecurity::~PipeSecurity() {
  if (descriptor_ != nullptr) {
    ::LocalFree(descriptor_);
  }
}

bool PipeSecurity::Initialize(const std::wstring& owner_sid) {
  if (descriptor_ != nullptr) {
    return false;
  }
  const auto sddl = BuildPipeSddl(owner_sid);
  if (sddl.empty() ||
      !::ConvertStringSecurityDescriptorToSecurityDescriptorW(
          sddl.c_str(), SDDL_REVISION_1, &descriptor_, nullptr)) {
    descriptor_ = nullptr;
    return false;
  }
  attributes_.nLength = sizeof(attributes_);
  attributes_.lpSecurityDescriptor = descriptor_;
  attributes_.bInheritHandle = FALSE;
  return true;
}

SECURITY_ATTRIBUTES* PipeSecurity::attributes() {
  return descriptor_ == nullptr ? nullptr : &attributes_;
}

}  // namespace pokrov::service
