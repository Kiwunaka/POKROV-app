#include "windows_crash_profile.h"

#include <windows.h>

#include <aclapi.h>
#include <knownfolders.h>
#include <sddl.h>
#include <shlobj.h>

#include <array>
#include <atomic>
#include <cstdarg>
#include <cstdio>
#include <string>

#include "service_security.h"

namespace pokrov::windows_crash {
namespace {

constexpr wchar_t kCrashDirectoryName[] = L"Crash";
constexpr wchar_t kUiCrashName[] = L"ui-crash-profile.v1.log";
constexpr wchar_t kUiPreviousCrashName[] =
    L"ui-crash-profile.v1.previous.log";
constexpr wchar_t kServiceCrashName[] = L"service-crash-profile.v1.log";
constexpr wchar_t kServicePreviousCrashName[] =
    L"service-crash-profile.v1.previous.log";
constexpr std::size_t kMaximumUnwindAttempts = 64;

struct ModuleRange {
  WindowsCrashModule module = WindowsCrashModule::kUnknown;
  const wchar_t* module_name = nullptr;
  std::atomic<std::uintptr_t> base{0};
  std::atomic<std::uintptr_t> limit{0};
};

std::array<ModuleRange, 4> known_modules = {{
    {WindowsCrashModule::kFlutter, L"flutter_windows.dll"},
    {WindowsCrashModule::kCore, L"pokrov-core.dll"},
    {WindowsCrashModule::kApp, L"app.so"},
    {WindowsCrashModule::kUnknown, nullptr},
}};
std::atomic<std::uintptr_t> process_module_base{0};
std::atomic<std::uintptr_t> process_module_limit{0};
std::atomic<bool> crash_profile_installed{false};
std::atomic_flag crash_filter_active = ATOMIC_FLAG_INIT;
WindowsCrashProcess crash_process = WindowsCrashProcess::kUi;
std::wstring current_crash_path;
std::wstring previous_crash_path;
LPTOP_LEVEL_EXCEPTION_FILTER previous_exception_filter = nullptr;

std::wstring AppendPath(const std::wstring& base, const wchar_t* child) {
  if (base.empty() || child == nullptr || child[0] == L'\0') {
    return L"";
  }
  return base + (base.back() == L'\\' ? L"" : L"\\") + child;
}

bool EnsureDirectory(const std::wstring& path) {
  return !path.empty() &&
         (::CreateDirectoryW(path.c_str(), nullptr) != FALSE ||
          ::GetLastError() == ERROR_ALREADY_EXISTS) &&
         (::GetFileAttributesW(path.c_str()) & FILE_ATTRIBUTE_DIRECTORY) != 0;
}

bool ProtectCrashDirectory(const std::wstring& path,
                           WindowsCrashProcess process) {
  std::wstring sddl = L"D:P(A;OICI;FA;;;SY)(A;OICI;FA;;;BA)";
  if (process == WindowsCrashProcess::kUi) {
    const auto owner_sid = pokrov::service::CurrentProcessUserSid();
    if (owner_sid.empty()) {
      return false;
    }
    sddl += L"(A;OICI;FA;;;" + owner_sid + L")";
  }

  PSECURITY_DESCRIPTOR descriptor = nullptr;
  if (!::ConvertStringSecurityDescriptorToSecurityDescriptorW(
          sddl.c_str(), SDDL_REVISION_1, &descriptor, nullptr)) {
    return false;
  }
  BOOL present = FALSE;
  BOOL defaulted = FALSE;
  PACL dacl = nullptr;
  const bool decoded =
      ::GetSecurityDescriptorDacl(descriptor, &present, &dacl, &defaulted) !=
          FALSE &&
      present != FALSE;
  const DWORD result =
      decoded ? ::SetNamedSecurityInfoW(
                    const_cast<wchar_t*>(path.c_str()), SE_FILE_OBJECT,
                    DACL_SECURITY_INFORMATION |
                        PROTECTED_DACL_SECURITY_INFORMATION,
                    nullptr, nullptr, dacl, nullptr)
              : ERROR_INVALID_SECURITY_DESCR;
  ::LocalFree(descriptor);
  return result == ERROR_SUCCESS;
}

bool ReadModuleRange(HMODULE module, std::uintptr_t* base,
                     std::uintptr_t* limit) {
  if (module == nullptr || base == nullptr || limit == nullptr) {
    return false;
  }
  bool valid = false;
  __try {
    const auto* dos = reinterpret_cast<const IMAGE_DOS_HEADER*>(module);
    if (dos->e_magic == IMAGE_DOS_SIGNATURE) {
      const auto* nt = reinterpret_cast<const IMAGE_NT_HEADERS*>(
          reinterpret_cast<const std::uint8_t*>(module) + dos->e_lfanew);
      if (nt->Signature == IMAGE_NT_SIGNATURE &&
          nt->OptionalHeader.SizeOfImage > 0) {
        *base = reinterpret_cast<std::uintptr_t>(module);
        *limit = *base + nt->OptionalHeader.SizeOfImage;
        valid = *limit > *base;
      }
    }
  } __except (EXCEPTION_EXECUTE_HANDLER) {
    valid = false;
  }
  return valid;
}

void RefreshModuleRange(ModuleRange* range) {
  if (range == nullptr || range->module_name == nullptr) {
    return;
  }
  std::uintptr_t base = 0;
  std::uintptr_t limit = 0;
  if (ReadModuleRange(::GetModuleHandleW(range->module_name), &base, &limit)) {
    range->base.store(base, std::memory_order_release);
    range->limit.store(limit, std::memory_order_release);
  }
}

WindowsCrashModule ModuleForAddress(std::uintptr_t address) {
  const auto process_base =
      process_module_base.load(std::memory_order_acquire);
  const auto process_limit =
      process_module_limit.load(std::memory_order_acquire);
  if (address >= process_base && address < process_limit) {
    return crash_process == WindowsCrashProcess::kUi
               ? WindowsCrashModule::kUi
               : WindowsCrashModule::kService;
  }
  for (const auto& range : known_modules) {
    const auto base = range.base.load(std::memory_order_acquire);
    const auto limit = range.limit.load(std::memory_order_acquire);
    if (base != 0 && address >= base && address < limit) {
      return range.module;
    }
  }
  return WindowsCrashModule::kUnknown;
}

std::uint64_t RelativeAddress(std::uintptr_t address,
                              WindowsCrashModule module) {
  if (module == WindowsCrashModule::kUi ||
      module == WindowsCrashModule::kService) {
    return address - process_module_base.load(std::memory_order_acquire);
  }
  for (const auto& range : known_modules) {
    if (range.module == module) {
      return address - range.base.load(std::memory_order_acquire);
    }
  }
  return 0;
}

const char* ProcessName(WindowsCrashProcess process) {
  return process == WindowsCrashProcess::kUi ? "ui" : "service";
}

const char* ModuleName(WindowsCrashModule module) {
  switch (module) {
    case WindowsCrashModule::kUi:
      return "ui";
    case WindowsCrashModule::kService:
      return "service";
    case WindowsCrashModule::kFlutter:
      return "flutter";
    case WindowsCrashModule::kCore:
      return "core";
    case WindowsCrashModule::kApp:
      return "app";
    case WindowsCrashModule::kUnknown:
      return nullptr;
  }
  return nullptr;
}

bool AppendFormatted(char* output, std::size_t capacity, std::size_t* used,
                     const char* format, ...) {
  if (output == nullptr || used == nullptr || *used >= capacity) {
    return false;
  }
  va_list arguments;
  va_start(arguments, format);
  const int written = std::vsnprintf(output + *used, capacity - *used, format,
                                     arguments);
  va_end(arguments);
  if (written < 0 || static_cast<std::size_t>(written) >= capacity - *used) {
    output[0] = '\0';
    return false;
  }
  *used += static_cast<std::size_t>(written);
  return true;
}

std::size_t CaptureSafeFrames(EXCEPTION_POINTERS* exception,
                              WindowsCrashFrame* frames,
                              std::size_t capacity) {
  if (exception == nullptr || exception->ContextRecord == nullptr ||
      frames == nullptr || capacity == 0) {
    return 0;
  }
  std::size_t count = 0;
#if defined(_M_X64)
  CONTEXT context = *exception->ContextRecord;
  __try {
    for (std::size_t attempt = 0;
         attempt < kMaximumUnwindAttempts && count < capacity; ++attempt) {
      const std::uintptr_t address = static_cast<std::uintptr_t>(context.Rip);
      if (address == 0) {
        break;
      }
      const auto module = ModuleForAddress(address);
      if (module != WindowsCrashModule::kUnknown) {
        frames[count++] = {module, RelativeAddress(address, module)};
      }

      const auto old_rip = context.Rip;
      const auto old_rsp = context.Rsp;
      DWORD64 image_base = 0;
      const auto* function =
          ::RtlLookupFunctionEntry(context.Rip, &image_base, nullptr);
      if (function != nullptr) {
        PVOID handler_data = nullptr;
        DWORD64 establisher_frame = 0;
        ::RtlVirtualUnwind(UNW_FLAG_NHANDLER, image_base, context.Rip,
                           const_cast<PRUNTIME_FUNCTION>(function), &context,
                           &handler_data, &establisher_frame, nullptr);
      } else {
        DWORD64 return_address = 0;
        SIZE_T bytes_read = 0;
        if (::ReadProcessMemory(
                ::GetCurrentProcess(),
                reinterpret_cast<const void*>(context.Rsp), &return_address,
                sizeof(return_address), &bytes_read) == FALSE ||
            bytes_read != sizeof(return_address)) {
          break;
        }
        context.Rip = return_address;
        context.Rsp += sizeof(return_address);
      }
      if (context.Rip == old_rip || context.Rsp <= old_rsp) {
        break;
      }
    }
  } __except (EXCEPTION_EXECUTE_HANDLER) {
    // A damaged stack must not recurse through the crash path.
  }
#else
  const auto address = reinterpret_cast<std::uintptr_t>(
      exception->ExceptionRecord == nullptr
          ? nullptr
          : exception->ExceptionRecord->ExceptionAddress);
  const auto module = ModuleForAddress(address);
  if (module != WindowsCrashModule::kUnknown) {
    frames[count++] = {module, RelativeAddress(address, module)};
  }
#endif
  return count;
}

std::uint64_t FileTimeTicks() {
  FILETIME file_time{};
  ::GetSystemTimeAsFileTime(&file_time);
  ULARGE_INTEGER ticks{};
  ticks.LowPart = file_time.dwLowDateTime;
  ticks.HighPart = file_time.dwHighDateTime;
  return ticks.QuadPart;
}

void WriteCrashRecord(const char* record, std::size_t size) {
  if (record == nullptr || size == 0 ||
      size >= kMaximumWindowsCrashRecordBytes || current_crash_path.empty() ||
      previous_crash_path.empty()) {
    return;
  }
  if (::MoveFileExW(current_crash_path.c_str(), previous_crash_path.c_str(),
                    MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH) ==
          FALSE &&
      ::GetLastError() != ERROR_FILE_NOT_FOUND) {
    return;
  }
  const HANDLE file = ::CreateFileW(
      current_crash_path.c_str(), GENERIC_WRITE, FILE_SHARE_READ, nullptr,
      CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL | FILE_FLAG_WRITE_THROUGH, nullptr);
  if (file == INVALID_HANDLE_VALUE) {
    return;
  }
  DWORD written = 0;
  if (::WriteFile(file, record, static_cast<DWORD>(size), &written, nullptr) !=
          FALSE &&
      written == size) {
    ::FlushFileBuffers(file);
  }
  ::CloseHandle(file);
}

LONG WINAPI HandleUnhandledException(EXCEPTION_POINTERS* exception) {
  if (crash_filter_active.test_and_set(std::memory_order_acquire)) {
    return EXCEPTION_CONTINUE_SEARCH;
  }
  std::array<WindowsCrashFrame, kMaximumWindowsCrashFrames> frames{};
  const auto frame_count = CaptureSafeFrames(exception, frames.data(),
                                             frames.size());
  std::array<char, kMaximumWindowsCrashRecordBytes> record{};
  const std::uint32_t exception_code =
      exception == nullptr || exception->ExceptionRecord == nullptr
          ? 0
          : exception->ExceptionRecord->ExceptionCode;
  const auto record_size = FormatWindowsCrashRecord(
      crash_process, exception_code, FileTimeTicks(), frames.data(),
      frame_count, record.data(), record.size());
  WriteCrashRecord(record.data(), record_size);

  const LONG result = previous_exception_filter == nullptr
                          ? EXCEPTION_CONTINUE_SEARCH
                          : previous_exception_filter(exception);
  crash_filter_active.clear(std::memory_order_release);
  return result;
}

}  // namespace

std::wstring ResolveWindowsUiStateRoot() {
  PWSTR local_app_data = nullptr;
  if (FAILED(::SHGetKnownFolderPath(FOLDERID_LocalAppData, KF_FLAG_DEFAULT,
                                    nullptr, &local_app_data)) ||
      local_app_data == nullptr) {
    return L"";
  }
  const std::wstring root = AppendPath(local_app_data, L"POKROV");
  ::CoTaskMemFree(local_app_data);
  return root;
}

bool InstallWindowsCrashProfile(WindowsCrashProcess process,
                                const std::wstring& state_root) {
  if (crash_profile_installed.load(std::memory_order_acquire)) {
    return true;
  }
  const auto crash_root = AppendPath(state_root, kCrashDirectoryName);
  if (!EnsureDirectory(state_root) || !EnsureDirectory(crash_root) ||
      !ProtectCrashDirectory(crash_root, process)) {
    return false;
  }
  crash_process = process;
  current_crash_path = AppendPath(
      crash_root, process == WindowsCrashProcess::kUi ? kUiCrashName
                                                      : kServiceCrashName);
  previous_crash_path = AppendPath(
      crash_root, process == WindowsCrashProcess::kUi
                      ? kUiPreviousCrashName
                      : kServicePreviousCrashName);
  if (current_crash_path.empty() || previous_crash_path.empty()) {
    return false;
  }
  RefreshWindowsCrashProfileModules();
  previous_exception_filter =
      ::SetUnhandledExceptionFilter(HandleUnhandledException);
  crash_profile_installed.store(true, std::memory_order_release);
  return true;
}

void RefreshWindowsCrashProfileModules() {
  std::uintptr_t base = 0;
  std::uintptr_t limit = 0;
  if (ReadModuleRange(::GetModuleHandleW(nullptr), &base, &limit)) {
    process_module_base.store(base, std::memory_order_release);
    process_module_limit.store(limit, std::memory_order_release);
  }
  for (auto& range : known_modules) {
    RefreshModuleRange(&range);
  }
}

std::size_t FormatWindowsCrashRecord(
    WindowsCrashProcess process, std::uint32_t exception_code,
    std::uint64_t occurred_at_filetime_ticks, const WindowsCrashFrame* frames,
    std::size_t frame_count, char* output, std::size_t output_capacity) {
  if (output == nullptr || output_capacity == 0 ||
      output_capacity > kMaximumWindowsCrashRecordBytes ||
      (frames == nullptr && frame_count != 0)) {
    return 0;
  }
  output[0] = '\0';
  std::size_t used = 0;
  if (!AppendFormatted(
          output, output_capacity, &used,
          "%s|time=%llu|process=%s|exception=0x%08lx|frames=",
          kWindowsCrashProfileMagic,
          static_cast<unsigned long long>(occurred_at_filetime_ticks),
          ProcessName(process), static_cast<unsigned long>(exception_code))) {
    return 0;
  }
  std::size_t safe_frames = 0;
  const auto bounded_count =
      frame_count < kMaximumWindowsCrashFrames ? frame_count
                                               : kMaximumWindowsCrashFrames;
  for (std::size_t index = 0; index < bounded_count; ++index) {
    const char* module = ModuleName(frames[index].module);
    if (module == nullptr) {
      continue;
    }
    if (!AppendFormatted(output, output_capacity, &used, "%s%s+0x%llx",
                         safe_frames == 0 ? "" : ",", module,
                         static_cast<unsigned long long>(
                             frames[index].relative_address))) {
      return 0;
    }
    ++safe_frames;
  }
  if (safe_frames == 0 &&
      !AppendFormatted(output, output_capacity, &used, "none")) {
    return 0;
  }
  if (!AppendFormatted(output, output_capacity, &used, "\n")) {
    return 0;
  }
  return used;
}

}  // namespace pokrov::windows_crash
