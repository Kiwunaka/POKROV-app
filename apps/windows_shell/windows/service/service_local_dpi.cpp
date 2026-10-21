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

bool StopWindowsLocalDpiChild(HANDLE& job, HANDLE& process) {
  if (job != nullptr) {
    if (!::CloseHandle(job)) return false;
    job = nullptr;
  }
  if (process != nullptr) {
    if (::WaitForSingleObject(process, 2000) != WAIT_OBJECT_0 ||
        !::CloseHandle(process)) return false;
    process = nullptr;
  }
  return true;
}

bool CloseWindowsLocalDpiDriver(HANDLE& guard, BOOL (__cdecl* close)(HANDLE)) {
  if (guard == INVALID_HANDLE_VALUE) return true;
  if (close == nullptr || !close(guard)) return false;
  guard = INVALID_HANDLE_VALUE;
  return true;
}

DWORD WaitWindowsLocalDpiSignal(HANDLE child, HANDLE signal,
                               const std::function<bool()>& current, ULONGLONG deadline) {
  const HANDLE handles[]{child, signal};
  for (;;) {
    if (!current || !current()) return WAIT_FAILED;
    const auto now = ::GetTickCount64();
    if (now >= deadline) return WAIT_TIMEOUT;
    const auto result = ::WaitForMultipleObjects(2, handles, FALSE,
        static_cast<DWORD>(std::min<ULONGLONG>(50, deadline - now)));
    if (result != WAIT_TIMEOUT) return result;
  }
}

struct WindowsLocalDpiExecutor::State {
  using Open = HANDLE (__cdecl*)(const char*, int, std::int16_t, std::uint64_t);
  using Close = BOOL (__cdecl*)(HANDLE);
  using GetParam = BOOL (__cdecl*)(HANDLE, int, std::uint64_t*);
  using RecvEx = BOOL (__cdecl*)(HANDLE, void*, UINT, UINT*, std::uint64_t,
                                void*, UINT*, OVERLAPPED*);
  using Shutdown = BOOL (__cdecl*)(HANDLE, int);
  HANDLE job = nullptr;
  HANDLE process = nullptr;
  HANDLE driver_guard = INVALID_HANDLE_VALUE;
  HMODULE driver_module = nullptr;
  Open open_driver = nullptr;
  Close close_driver = nullptr;
  GetParam get_driver_param = nullptr;
  RecvEx recv_driver = nullptr;
  Shutdown shutdown_driver = nullptr;
  std::vector<HANDLE> files;
  std::vector<std::pair<std::string, std::string>> holders;
  std::vector<WindowsLocalDpiService> prepared_services;
  std::string physical_bind_interface;
  NET_IFINDEX interface_index = 0;
  WindowsLocalDpiStrategy first_strategy = WindowsLocalDpiStrategy::kFakeMultisplitAlt4;
  bool retry_attempted = false;
  bool admission_attempted = false;

  // WinDivert 2.2 WINDIVERT_ADDRESS layout, using only its REFLECT member.
  // The public ABI reserves 64 bytes for layer data (include/windivert.h).
  struct ReflectAddress {
    std::int64_t timestamp;
    std::uint32_t layer : 8, event : 8, flags : 16;
    std::uint32_t reserved;
    struct {
      std::int64_t timestamp;
      std::uint32_t process_id;
      std::int32_t layer;
      std::uint64_t flags;
      std::int16_t priority;
    } reflect;
    std::array<unsigned char, 32> padding;
  };
  static_assert(sizeof(ReflectAddress) == 80);

  bool ReadNetworkOpen(HANDLE observer, DWORD pid, const std::function<bool()>& current,
                       ULONGLONG deadline) {
    OVERLAPPED io{};
    io.hEvent = ::CreateEventW(nullptr, TRUE, FALSE, nullptr);
    if (io.hEvent == nullptr) return false;
    const bool ready = [&] {
      while (current && current() && ::GetTickCount64() < deadline) {
        std::array<unsigned char, 16384> filter{};  // Never logged or interpreted.
        ReflectAddress address{};
        UINT address_size = sizeof(address), received = 0;
        ::ResetEvent(io.hEvent);
        bool completed = recv_driver(observer, filter.data(), static_cast<UINT>(filter.size()),
            &received, 0, &address, &address_size, &io) != FALSE;
        if (!completed && ::GetLastError() == ERROR_IO_PENDING) {
          const auto result = WaitWindowsLocalDpiSignal(process, io.hEvent, current, deadline);
          DWORD transferred = 0;
          if (result != WAIT_OBJECT_0 + 1) {
            ::CancelIoEx(observer, &io);
            // Drain cancelled I/O before releasing its stack buffers/event.
            ::GetOverlappedResult(observer, &io, &transferred, TRUE);
            return false;
          }
          completed = ::GetOverlappedResult(observer, &io, &transferred, FALSE) != FALSE;
        }
        if (!completed) return false;
        if (address_size == sizeof(address) && address.layer == 4 && address.event == 8 &&
            address.reflect.process_id == pid && address.reflect.layer == 0 &&
            address.reflect.flags == 0) return current() && ::WaitForSingleObject(process, 0) == WAIT_TIMEOUT;
      }
      return false;
    }();
    ::CloseHandle(io.hEvent);
    return ready;
  }

  bool WaitNetworkReady(DWORD pid, HANDLE init_mutex, const std::function<bool()>& current) {
    const auto deadline = ::GetTickCount64() + 3000;
    if (!ReadNetworkOpen(driver_guard, pid, current, deadline)) return false;
    // Upstream queues REFLECT_OPEN before installing callouts. Its named mutex
    // surrounds the complete WinDivertOpen call, so wait for that to return.
    const auto result = WaitWindowsLocalDpiSignal(process, init_mutex, current, deadline);
    if (result == WAIT_OBJECT_0 + 1 || result == WAIT_ABANDONED_0 + 1) ::ReleaseMutex(init_mutex);
    if (result != WAIT_OBJECT_0 + 1 || !current() || ::GetTickCount64() >= deadline) return false;
    // A failed Open closes its handle before releasing the mutex. A fresh
    // REFLECT snapshot is ordered after that CLOSE and rejects the stale OPEN.
    const auto filter = "processId == " + std::to_string(pid) + " and layer == 0";
    HANDLE snapshot = open_driver(filter.c_str(), 4, 0, 0x0001 | 0x0004);
    if (snapshot == INVALID_HANDLE_VALUE) return false;
    // Shutdown waits for the initial snapshot to be queued, then returns EOF.
    const bool ready = shutdown_driver(snapshot, 1) && ReadNetworkOpen(snapshot, pid, current, deadline);
    const bool closed = close_driver(snapshot) != FALSE;
    return ready && closed;
  }
};

WindowsLocalDpiExecutor::WindowsLocalDpiExecutor(CoreRuntime& core)
    : core_(core), state_(std::make_unique<State>()) {}
WindowsLocalDpiExecutor::~WindowsLocalDpiExecutor() { Stop(); }

std::array<WindowsLocalDpiStrategy, 2> WindowsLocalDpiStrategyOrder(
    WindowsLocalDpiStrategy preferred) {
  std::array<WindowsLocalDpiStrategy, 2> strategies{
      WindowsLocalDpiStrategy::kFakeMultisplitAlt4, WindowsLocalDpiStrategy::kMultisplit681};
  if (preferred == strategies[1]) std::swap(strategies[0], strategies[1]);
  return strategies;
}

std::wstring WindowsLocalDpiCommand(const std::wstring& directory,
    const std::string& hostlist, DWORD interface_index, WindowsLocalDpiStrategy strategy) {
  const auto pattern = Quote(directory + L"tls_clienthello_www_google_com.bin");
  const auto scope = Quote(directory + L"winws.exe") + L" --wf-iface=" + std::to_wstring(interface_index) +
      L" --wf-tcp=443 --filter-tcp=443 --filter-l7=tls --hostlist-domains=" +
      std::wstring(hostlist.begin(), hostlist.end()) + L" --ip-id=zero";
  if (strategy == WindowsLocalDpiStrategy::kFakeMultisplitAlt4) {
    // Flowseal 1.10.3 ALT4 Google TCP/443 branch; upstream's split position is 2.
    return scope + L" --dpi-desync=fake,multisplit --dpi-desync-repeats=6"
        L" --dpi-desync-fooling=badseq --dpi-desync-badseq-increment=1000 --dpi-desync-fake-tls=" + pattern;
  }
  return scope + L" --dpi-desync=multisplit --dpi-desync-split-pos=1 --dpi-desync-split-seqovl=681"
      L" --dpi-desync-split-seqovl-pattern=" + pattern;
}

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
  if (state_->driver_module != nullptr) {
    return state_->open_driver != nullptr && state_->close_driver != nullptr &&
        state_->get_driver_param != nullptr && state_->recv_driver != nullptr &&
        state_->shutdown_driver != nullptr;
  }
  const auto directory = AssetDirectory();
  if (directory.empty()) return false;
  const auto directory_handle = LockAsset(directory.substr(0, directory.size() - 1), true);
  if (directory_handle == INVALID_HANDLE_VALUE) return false;
  state_->files.push_back(directory_handle);
  for (const auto* name : {L"winws.exe", L"cygwin1.dll", L"WinDivert.dll", L"WinDivert64.sys",
                         L"tls_clienthello_www_google_com.bin"}) {
    const auto file = LockAsset(directory + name);
    if (file == INVALID_HANDLE_VALUE) { Stop(); return false; }
    state_->files.push_back(file);
  }
  state_->driver_module = ::LoadLibraryExW((directory + L"WinDivert.dll").c_str(), nullptr,
      LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR | LOAD_LIBRARY_SEARCH_SYSTEM32);
  state_->open_driver = state_->driver_module == nullptr ? nullptr : reinterpret_cast<State::Open>(
      ::GetProcAddress(state_->driver_module, "WinDivertOpen"));
  state_->close_driver = state_->driver_module == nullptr ? nullptr : reinterpret_cast<State::Close>(
      ::GetProcAddress(state_->driver_module, "WinDivertClose"));
  state_->get_driver_param = state_->driver_module == nullptr ? nullptr : reinterpret_cast<State::GetParam>(
      ::GetProcAddress(state_->driver_module, "WinDivertGetParam"));
  state_->recv_driver = state_->driver_module == nullptr ? nullptr : reinterpret_cast<State::RecvEx>(
      ::GetProcAddress(state_->driver_module, "WinDivertRecvEx"));
  state_->shutdown_driver = state_->driver_module == nullptr ? nullptr : reinterpret_cast<State::Shutdown>(
      ::GetProcAddress(state_->driver_module, "WinDivertShutdown"));
  if (state_->open_driver == nullptr || state_->close_driver == nullptr || state_->get_driver_param == nullptr ||
      state_->recv_driver == nullptr || state_->shutdown_driver == nullptr) {
    Stop(); return false;
  }
  return true;
}

std::string WindowsLocalDpiExecutor::StartPrepared(
    const std::vector<WindowsLocalDpiService>& services,
    const std::string& physical_bind_interface, WindowsLocalDpiStrategy strategy,
    const std::function<bool()>& current) {
  if (!current || !current()) return "local_dpi_owner_changed";
  if (state_->process != nullptr || state_->job != nullptr ||
      state_->driver_guard != INVALID_HANDLE_VALUE || !state_->holders.empty()) {
    return "local_dpi_executor_running";
  }
  if (core_.WindowsLocalDpiAdmissionVersion() != 1) return "local_dpi_executor_unavailable";
  const auto hostlist = WindowsLocalDpiHostList(services);
  // Never let an empty hostlist become upstream's allow-all mode. Bound the
  // Windows command line and make strategy selection a closed native enum.
  if (hostlist.empty() ||
      (strategy != WindowsLocalDpiStrategy::kFakeMultisplitAlt4 && strategy != WindowsLocalDpiStrategy::kMultisplit681)) {
    return "local_dpi_scope_invalid";
  }
  const auto wide_interface = WideUtf8(physical_bind_interface);
  NET_LUID luid{};
  NET_IFINDEX index = 0;
  if (wide_interface.empty() ||
      ::ConvertInterfaceAliasToLuid(wide_interface.c_str(), &luid) != NO_ERROR ||
      ::ConvertInterfaceLuidToIndex(&luid, &index) != NO_ERROR || index == 0) return "local_dpi_interface_unavailable";

  if (!AssetsReady()) return "local_dpi_assets_unavailable";
  for (const auto& service : services) {
    const auto id = core_.ReadLocalDpiAdmissionID(service.outbound_tag);
    if (!IsHolderID(id)) { Stop(); return "local_dpi_holder_unavailable"; }
    state_->holders.emplace_back(service.outbound_tag, id);
  }
  // Only this consented, Core-prepared path may install the packaged driver.
  // Official REFLECT(4), SNIFF|RECV_ONLY retains it while our child opens its
  // NETWORK handle. Capability discovery never opens a driver handle.
  state_->driver_guard = state_->open_driver("true", 4, 0, 0x0001 | 0x0004);
  std::uint64_t major = 0, minor = 0;
  if (state_->driver_guard == INVALID_HANDLE_VALUE ||
      !state_->get_driver_param(state_->driver_guard, 3, &major) ||
      !state_->get_driver_param(state_->driver_guard, 4, &minor) ||
      major != 2 || minor != 2) { Stop(); return "local_dpi_assets_unavailable"; }
  state_->prepared_services = services;
  state_->physical_bind_interface = physical_bind_interface;
  state_->interface_index = index;
  state_->first_strategy = strategy;
  return StartChild(hostlist, index, strategy, current);
}

std::string WindowsLocalDpiExecutor::RetryPrepared(
    const std::vector<WindowsLocalDpiService>& services,
    const std::string& physical_bind_interface, WindowsLocalDpiStrategy strategy,
    const std::function<bool()>& current) {
  if (!current || !current()) return "local_dpi_owner_changed";
  if (state_->admission_attempted || state_->retry_attempted || state_->holders.empty() ||
      state_->process == nullptr || state_->job == nullptr || state_->driver_guard == INVALID_HANDLE_VALUE ||
      services.size() != state_->prepared_services.size() || services.size() != state_->holders.size() ||
      physical_bind_interface != state_->physical_bind_interface || strategy == state_->first_strategy ||
      (strategy != WindowsLocalDpiStrategy::kFakeMultisplitAlt4 && strategy != WindowsLocalDpiStrategy::kMultisplit681)) {
    return "local_dpi_retry_unavailable";
  }
  for (std::size_t i = 0; i < services.size(); ++i) {
    const auto& original = state_->prepared_services[i];
    const auto& service = services[i];
    if (service.service_id != original.service_id || service.outbound_tag != original.outbound_tag ||
        service.control_host != original.control_host || service.domains.size() != original.domains.size() ||
        core_.ReadLocalDpiAdmissionID(state_->holders[i].first) != state_->holders[i].second) {
      return "local_dpi_retry_unavailable";
    }
    for (std::size_t j = 0; j < service.domains.size(); ++j) {
      if (service.domains[j].name != original.domains[j].name ||
          service.domains[j].exact != original.domains[j].exact ||
          service.domains[j].shared != original.domains[j].shared) return "local_dpi_retry_unavailable";
    }
  }
  state_->retry_attempted = true;
  // Close only our Job and wait for its child; keep unpublished holders and
  // the driver/assets. A cleanup failure forbids a replacement child.
  if (!StopWindowsLocalDpiChild(state_->job, state_->process)) return "local_dpi_child_failed";
  const auto wide_interface = WideUtf8(physical_bind_interface);
  NET_LUID luid{};
  NET_IFINDEX index = 0;
  if (wide_interface.empty() ||
      ::ConvertInterfaceAliasToLuid(wide_interface.c_str(), &luid) != NO_ERROR ||
      ::ConvertInterfaceLuidToIndex(&luid, &index) != NO_ERROR || index != state_->interface_index) {
    return "local_dpi_interface_unavailable";
  }
  for (const auto& holder : state_->holders) {
    if (core_.ReadLocalDpiAdmissionID(holder.first) != holder.second) return "local_dpi_retry_unavailable";
  }
  return StartChild(WindowsLocalDpiHostList(services), index, strategy, current);
}

std::string WindowsLocalDpiExecutor::StartChild(
    const std::string& hostlist, DWORD interface_index, WindowsLocalDpiStrategy strategy,
    const std::function<bool()>& current) {
  const auto directory = AssetDirectory();
  state_->job = ::CreateJobObjectW(nullptr, nullptr);
  JOBOBJECT_EXTENDED_LIMIT_INFORMATION limits{};
  limits.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE | JOB_OBJECT_LIMIT_ACTIVE_PROCESS;
  limits.BasicLimitInformation.ActiveProcessLimit = 1;
  if (state_->job == nullptr || !::SetInformationJobObject(state_->job, JobObjectExtendedLimitInformation,
      &limits, sizeof(limits))) { Stop(); return "local_dpi_child_failed"; }
  auto command = WindowsLocalDpiCommand(directory, hostlist, interface_index, strategy);
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
  // Retain (without owning) upstream's mutex before the child runs. Otherwise
  // its fast release/CloseHandle can destroy the object before our wait opens it.
  HANDLE init_mutex = ::CreateMutexW(nullptr, FALSE, L"Global\\winws_windivert_mutex");
  if (init_mutex == nullptr) {
    ::CloseHandle(process.hThread);
    Stop(); return "local_dpi_filter_unavailable";
  }
  const auto resumed = ::ResumeThread(process.hThread);
  ::CloseHandle(process.hThread);
  const bool ready = resumed != static_cast<DWORD>(-1) && Alive() &&
      state_->WaitNetworkReady(process.dwProcessId, init_mutex, current);
  ::CloseHandle(init_mutex);
  if (!ready) {
    const bool owner_current = current && current();
    if (!Stop()) return "local_dpi_child_failed";
    return owner_current ? "local_dpi_filter_unavailable" : "local_dpi_owner_changed";
  }
  return "";  // Holder remains unpublished until separate exact TLS proof.
}

bool WindowsLocalDpiExecutor::Alive() const {
  return state_->process != nullptr && ::WaitForSingleObject(state_->process, 0) == WAIT_TIMEOUT;
}

std::string WindowsLocalDpiExecutor::CapturedAdmissionID(const std::string& tag) const {
  for (const auto& holder : state_->holders) {
    if (holder.first == tag) return holder.second;
  }
  return "";
}

bool WindowsLocalDpiExecutor::AdmitCaptured(const std::string& tag,
                                          const std::function<bool()>& current_after_proof) {
  for (const auto& holder : state_->holders) {
    if (holder.first != tag) continue;
    if (!current_after_proof || !current_after_proof() || !Alive() ||
        core_.ReadLocalDpiAdmissionID(tag) != holder.second || !current_after_proof()) return false;
    state_->admission_attempted = true;
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
  return StopAfterCoreStopped();
}

bool WindowsLocalDpiExecutor::StopAfterCoreStopped() {
  if (!StopWindowsLocalDpiChild(state_->job, state_->process) ||
      !CloseWindowsLocalDpiDriver(state_->driver_guard, state_->close_driver)) return false;
  state_->holders.clear();
  state_->prepared_services.clear();
  state_->physical_bind_interface.clear();
  state_->interface_index = 0;
  state_->retry_attempted = false;
  state_->admission_attempted = false;
  if (state_->driver_module != nullptr) { ::FreeLibrary(state_->driver_module); state_->driver_module = nullptr; }
  state_->open_driver = nullptr;
  state_->close_driver = nullptr;
  state_->get_driver_param = nullptr;
  state_->recv_driver = nullptr;
  state_->shutdown_driver = nullptr;
  for (const auto file : state_->files) ::CloseHandle(file);
  state_->files.clear();
  return true;
}
}  // namespace pokrov::service
