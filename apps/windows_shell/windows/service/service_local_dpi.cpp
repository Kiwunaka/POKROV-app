#include "service_local_dpi.h"
#include "service_runtime.h"

#include <iphlpapi.h>
#include <sddl.h>
#include <aclapi.h>
#include <algorithm>
#include <array>
#include <climits>
#include <cstdint>
#include <set>
#include <utility>

namespace pokrov::service {
namespace {
bool IsHolderID(const std::string& value) {
  return value.size() == 32 && std::all_of(value.begin(), value.end(),
      [](unsigned char c) { return (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f'); });
}

bool IsDomain(const std::string& value) {
  if (value.empty() || value.size() > 253) return false;
  std::size_t label = 0;
  for (std::size_t i = 0; i < value.size(); ++i) {
    const unsigned char c = value[i];
    if (c == '.') {
      if (label == 0 || value[i - 1] == '-') return false;
      label = 0;
    } else {
      if (!((c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == '-') ||
          (label == 0 && c == '-') || ++label > 63) return false;
    }
  }
  return label > 0 && value.back() != '-' && value.find('.') != std::string::npos;
}

std::wstring WideUtf8(const std::string& value) {
  if (value.empty() || value.size() > INT_MAX || value.find('\0') != std::string::npos) return L"";
  const int length = ::MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS,
      value.data(), static_cast<int>(value.size()), nullptr, 0);
  if (length == 0) return L"";
  std::wstring result(static_cast<std::size_t>(length), L'\0');
  return ::MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, value.data(),
      static_cast<int>(value.size()), result.data(), length) == length ? result : L"";
}

std::wstring AssetDirectory() {
  std::array<wchar_t, 32768> path{};
  const DWORD size = ::GetModuleFileNameW(nullptr, path.data(), static_cast<DWORD>(path.size()));
  if (size == 0 || size >= path.size()) return L"";
  const std::wstring executable(path.data(), size);
  const auto slash = executable.find_last_of(L"\\/");
  return slash == std::wstring::npos ? L"" : executable.substr(0, slash + 1) + L"local-dpi\\";
}

// Hold immutable, non-reparse files from the administrator-owned installed
// asset directory. This is not approval of asset provenance or a DPI capability.
HANDLE LockAsset(const std::wstring& path, bool directory = false) {
  HANDLE file = ::CreateFileW(path.c_str(), GENERIC_READ | READ_CONTROL,
      FILE_SHARE_READ, nullptr, OPEN_EXISTING,
      FILE_FLAG_OPEN_REPARSE_POINT | FILE_FLAG_BACKUP_SEMANTICS, nullptr);
  if (file == INVALID_HANDLE_VALUE) return file;
  BY_HANDLE_FILE_INFORMATION info{};
  bool trusted = ::GetFileInformationByHandle(file, &info) &&
      (info.dwFileAttributes & FILE_ATTRIBUTE_REPARSE_POINT) == 0 &&
      ((info.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) != 0) == directory &&
      (directory || info.nFileSizeHigh != 0 || info.nFileSizeLow != 0);
  PSECURITY_DESCRIPTOR descriptor = nullptr;
  PACL dacl = nullptr;
  PSID owner = nullptr;
  if (trusted) trusted = ::GetSecurityInfo(file, SE_FILE_OBJECT,
      OWNER_SECURITY_INFORMATION | DACL_SECURITY_INFORMATION,
      &owner, nullptr, &dacl, nullptr, &descriptor) == ERROR_SUCCESS && dacl != nullptr && owner != nullptr;
  BYTE system_sid[SECURITY_MAX_SID_SIZE]{}, admin_sid[SECURITY_MAX_SID_SIZE]{};
  DWORD system_size = sizeof(system_sid), admin_size = sizeof(admin_sid);
  trusted = trusted && ::CreateWellKnownSid(WinLocalSystemSid, nullptr, system_sid, &system_size) &&
      ::CreateWellKnownSid(WinBuiltinAdministratorsSid, nullptr, admin_sid, &admin_size);
  trusted = trusted && (::EqualSid(owner, system_sid) || ::EqualSid(owner, admin_sid));
  constexpr DWORD writes = GENERIC_ALL | GENERIC_WRITE | FILE_WRITE_DATA |
      FILE_APPEND_DATA | FILE_WRITE_EA | FILE_WRITE_ATTRIBUTES | DELETE | WRITE_DAC | WRITE_OWNER;
  for (DWORD i = 0; trusted && i < dacl->AceCount; ++i) {
    void* raw = nullptr;
    trusted = ::GetAce(dacl, i, &raw) != FALSE;
    if (!trusted) break;
    const auto* header = static_cast<ACE_HEADER*>(raw);
    if ((header->AceFlags & INHERIT_ONLY_ACE) != 0 || header->AceType == ACCESS_DENIED_ACE_TYPE) continue;
    if (header->AceType != ACCESS_ALLOWED_ACE_TYPE) { trusted = false; break; }
    const auto* ace = static_cast<ACCESS_ALLOWED_ACE*>(raw);
    if ((ace->Mask & writes) == 0) continue;
    PSID sid = const_cast<DWORD*>(&ace->SidStart);
    trusted = ::EqualSid(sid, system_sid) || ::EqualSid(sid, admin_sid);
  }
  if (descriptor != nullptr) ::LocalFree(descriptor);
  if (trusted) return file;
  ::CloseHandle(file);
  return INVALID_HANDLE_VALUE;
}

std::wstring Quote(const std::wstring& value) {
  // All paths are fixed native asset paths; domain/interface argv are validated
  // ASCII/numeric. Escape Windows argv quotes and trailing backslashes.
  std::wstring result = L"\"";
  std::size_t backslashes = 0;
  for (const auto c : value) {
    if (c == L'\\') { ++backslashes; continue; }
    result.append(backslashes * (c == L'\"' ? 2 : 1), L'\\');
    backslashes = 0;
    if (c == L'\"') result += L'\\';
    result += c;
  }
  result.append(backslashes * 2, L'\\');
  return result + L'\"';
}
}  // namespace

struct WindowsLocalDpiExecutor::State {
  using Open = HANDLE (__cdecl*)(const char*, int, std::int16_t, std::uint64_t);
  using Close = BOOL (__cdecl*)(HANDLE);
  using GetParam = BOOL (__cdecl*)(HANDLE, int, std::uint64_t*);
  HANDLE job = nullptr;
  HANDLE process = nullptr;
  HANDLE driver_guard = INVALID_HANDLE_VALUE;
  HMODULE driver_module = nullptr;
  Close close_driver = nullptr;
  std::vector<HANDLE> files;
  std::vector<std::pair<std::string, std::string>> holders;
};

WindowsLocalDpiExecutor::WindowsLocalDpiExecutor(CoreRuntime& core)
    : core_(core), state_(std::make_unique<State>()) {}
WindowsLocalDpiExecutor::~WindowsLocalDpiExecutor() { Stop(); }

std::string WindowsLocalDpiHostList(const std::vector<WindowsLocalDpiService>& services) {
  if (services.empty()) return "";
  std::string hostlist;
  std::set<std::string> seen;
  for (const auto& service : services) {
    bool control_in_scope = false;
    if (service.domains.empty() || !IsDomain(service.control_host) ||
        service.outbound_tag != "pokrov-local-dpi-" + service.service_id) return "";
    for (const auto& domain : service.domains) {
      if (domain.shared || !IsDomain(domain.name)) return "";
      control_in_scope |= domain.exact && domain.name == service.control_host;
      const auto entry = (domain.exact ? "^" : "") + domain.name;
      if (seen.insert(entry).second) hostlist += (hostlist.empty() ? "" : ",") + entry;
    }
    if (!control_in_scope) return "";
  }
  return hostlist.size() <= 16000 ? hostlist : "";
}

bool WindowsLocalDpiExecutor::AssetsReady() {
  if (core_.WindowsLocalDpiAdmissionVersion() != 1) return false;
  if (state_->driver_guard != INVALID_HANDLE_VALUE) return true;
  const auto directory = AssetDirectory();
  if (directory.empty()) return false;
  const auto directory_handle = LockAsset(directory.substr(0, directory.size() - 1), true);
  if (directory_handle == INVALID_HANDLE_VALUE) return false;
  state_->files.push_back(directory_handle);
  for (const auto* name : {L"winws.exe", L"cygwin1.dll", L"WinDivert.dll", L"WinDivert64.sys",
                         L"tls_clienthello_4pda_to.bin", L"tls_clienthello_www_google_com.bin"}) {
    const auto file = LockAsset(directory + name);
    if (file == INVALID_HANDLE_VALUE) { Stop(); return false; }
    state_->files.push_back(file);
  }
  state_->driver_module = ::LoadLibraryExW((directory + L"WinDivert.dll").c_str(), nullptr,
      LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR | LOAD_LIBRARY_SEARCH_SYSTEM32);
  auto open = state_->driver_module == nullptr ? nullptr : reinterpret_cast<State::Open>(
      ::GetProcAddress(state_->driver_module, "WinDivertOpen"));
  state_->close_driver = state_->driver_module == nullptr ? nullptr : reinterpret_cast<State::Close>(
      ::GetProcAddress(state_->driver_module, "WinDivertClose"));
  auto get_param = state_->driver_module == nullptr ? nullptr : reinterpret_cast<State::GetParam>(
      ::GetProcAddress(state_->driver_module, "WinDivertGetParam"));
  if (open == nullptr || state_->close_driver == nullptr || get_param == nullptr) {
    Stop(); return false;
  }
  // Official WinDivert REFLECT(4), SNIFF|RECV_ONLY|NO_INSTALL. This guard
  // cannot install a missing driver and retains the existing driver while the
  // ordinary upstream child opens its NETWORK handle. Never read packet data.
  state_->driver_guard = open("true", 4, 0, 0x0001 | 0x0004 | 0x0010);
  std::uint64_t major = 0, minor = 0;
  if (state_->driver_guard == INVALID_HANDLE_VALUE ||
      !get_param(state_->driver_guard, 3, &major) || !get_param(state_->driver_guard, 4, &minor) ||
      major != 2 || minor != 2) { Stop(); return false; }
  return true;
}

std::string WindowsLocalDpiExecutor::StartPrepared(
    const std::vector<WindowsLocalDpiService>& services,
    const std::string& physical_bind_interface, WindowsLocalDpiStrategy strategy) {
  if (state_->process != nullptr) return "local_dpi_executor_running";
  if (core_.WindowsLocalDpiAdmissionVersion() != 1) return "local_dpi_executor_unavailable";
  const auto hostlist = WindowsLocalDpiHostList(services);
  // Never let an empty hostlist become upstream's allow-all mode. Bound the
  // Windows command line and make strategy selection a closed native enum.
  if (hostlist.empty() ||
      (strategy != WindowsLocalDpiStrategy::kMultisplit568 && strategy != WindowsLocalDpiStrategy::kMultisplit681)) {
    return "local_dpi_scope_invalid";
  }
  const auto wide_interface = WideUtf8(physical_bind_interface);
  NET_LUID luid{};
  NET_IFINDEX index = 0;
  if (wide_interface.empty() ||
      ::ConvertInterfaceAliasToLuid(wide_interface.c_str(), &luid) != NO_ERROR ||
      ::ConvertInterfaceLuidToIndex(&luid, &index) != NO_ERROR || index == 0) return "local_dpi_interface_unavailable";

  const auto directory = AssetDirectory();
  if (!AssetsReady()) return "local_dpi_assets_unavailable";
  for (const auto& service : services) {
    const auto id = core_.ReadLocalDpiAdmissionID(service.outbound_tag);
    if (!IsHolderID(id)) { Stop(); return "local_dpi_holder_unavailable"; }
    state_->holders.emplace_back(service.outbound_tag, id);
  }
  state_->job = ::CreateJobObjectW(nullptr, nullptr);
  JOBOBJECT_EXTENDED_LIMIT_INFORMATION limits{};
  limits.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE | JOB_OBJECT_LIMIT_ACTIVE_PROCESS;
  limits.BasicLimitInformation.ActiveProcessLimit = 1;
  if (state_->job == nullptr || !::SetInformationJobObject(state_->job, JobObjectExtendedLimitInformation,
      &limits, sizeof(limits))) { Stop(); return "local_dpi_child_failed"; }
  const bool variant681 = strategy == WindowsLocalDpiStrategy::kMultisplit681;
  const auto pattern = directory + (variant681 ? L"tls_clienthello_www_google_com.bin" : L"tls_clienthello_4pda_to.bin");
  std::wstring command = Quote(directory + L"winws.exe") + L" --wf-iface=" + std::to_wstring(index) +
      L" --wf-tcp=443 --filter-tcp=443 --filter-l7=tls --hostlist-domains=" +
      std::wstring(hostlist.begin(), hostlist.end()) +
      (variant681 ? L" --ip-id=zero" : L"") +
      L" --dpi-desync=multisplit --dpi-desync-split-pos=1 --dpi-desync-split-seqovl=" +
      (variant681 ? L"681" : L"568") + L" --dpi-desync-split-seqovl-pattern=" + Quote(pattern);
  STARTUPINFOW startup{};
  startup.cb = sizeof(startup);
  PROCESS_INFORMATION process{};
  if (!::CreateProcessW((directory + L"winws.exe").c_str(), command.data(), nullptr, nullptr, FALSE,
      CREATE_SUSPENDED | CREATE_NO_WINDOW, nullptr, directory.c_str(), &startup, &process)) {
    Stop(); return "local_dpi_child_failed";
  }
  state_->process = process.hProcess;
  if (!::AssignProcessToJobObject(state_->job, process.hProcess)) {
    ::TerminateProcess(process.hProcess, 1);  // Only our suspended child.
    ::CloseHandle(process.hThread);
    Stop(); return "local_dpi_child_failed";
  }
  const auto resumed = ::ResumeThread(process.hThread);
  ::CloseHandle(process.hThread);
  if (resumed == static_cast<DWORD>(-1) || !Alive()) { Stop(); return "local_dpi_child_failed"; }
  return "";  // Holder remains unpublished until separate exact TLS proof.
}

bool WindowsLocalDpiExecutor::Alive() const {
  return state_->process != nullptr && ::WaitForSingleObject(state_->process, 0) == WAIT_TIMEOUT;
}

bool WindowsLocalDpiExecutor::AdmitCaptured(const std::string& tag,
                                          const std::function<bool()>& current_after_proof) {
  for (const auto& holder : state_->holders) {
    if (holder.first != tag) continue;
    if (!current_after_proof || !current_after_proof() || !Alive() ||
        core_.ReadLocalDpiAdmissionID(tag) != holder.second || !current_after_proof()) return false;
    return core_.AdmitLocalDpiAdmission(holder.second) == 1 &&
        current_after_proof() && Alive() && core_.ReadLocalDpiAdmissionID(tag) == holder.second;
  }
  return false;
}

bool WindowsLocalDpiExecutor::Stop() {
  for (const auto& holder : state_->holders) {
    // A replaced/stopped Core has no authority for this captured old holder.
    // Never substitute or withdraw the new ID returned for the same tag.
    if (core_.ReadLocalDpiAdmissionID(holder.first) == holder.second &&
        core_.WithdrawLocalDpiAdmission(holder.second) < 0) return false;
  }
  StopAfterCoreStopped();
  return true;
}

void WindowsLocalDpiExecutor::StopAfterCoreStopped() {
  state_->holders.clear();
  if (state_->job != nullptr) { ::CloseHandle(state_->job); state_->job = nullptr; }
  if (state_->process != nullptr) {
    ::WaitForSingleObject(state_->process, 2000);
    ::CloseHandle(state_->process);
    state_->process = nullptr;
  }
  if (state_->driver_guard != INVALID_HANDLE_VALUE && state_->close_driver != nullptr) {
    state_->close_driver(state_->driver_guard);
    state_->driver_guard = INVALID_HANDLE_VALUE;
  }
  if (state_->driver_module != nullptr) { ::FreeLibrary(state_->driver_module); state_->driver_module = nullptr; }
  state_->close_driver = nullptr;
  for (const auto file : state_->files) ::CloseHandle(file);
  state_->files.clear();
}
}  // namespace pokrov::service
