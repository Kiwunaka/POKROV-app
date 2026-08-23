#ifndef POKROV_SERVICE_WINDOWS_CRASH_PROFILE_H_
#define POKROV_SERVICE_WINDOWS_CRASH_PROFILE_H_

#include <cstddef>
#include <cstdint>
#include <string>

namespace pokrov::windows_crash {

constexpr char kWindowsCrashProfileMagic[] = "POKROV_WINDOWS_CRASH_V1";
constexpr std::size_t kMaximumWindowsCrashFrames = 32;
constexpr std::size_t kMaximumWindowsCrashRecordBytes = 2048;

enum class WindowsCrashProcess {
  kUi,
  kService,
};

enum class WindowsCrashModule {
  kUi,
  kService,
  kFlutter,
  kCore,
  kApp,
  kUnknown,
};

struct WindowsCrashFrame {
  WindowsCrashModule module = WindowsCrashModule::kUnknown;
  std::uint64_t relative_address = 0;
};

// Resolves the ordinary user's private state root. No directory is created by
// this resolver.
std::wstring ResolveWindowsUiStateRoot();

// Installs one process-wide unhandled-exception filter. The filter writes only
// the closed stack profile declared above into a protected Crash directory
// below state_root. It never creates a minidump or serializes memory, registers,
// paths, command lines, exception text, profiles or network material.
bool InstallWindowsCrashProfile(WindowsCrashProcess process,
                                const std::wstring& state_root);

// Refreshes fixed, allowlisted module ranges after late-loaded runtime modules
// become available. Module paths and symbol names are never resolved.
void RefreshWindowsCrashProfileModules();

// Pure formatter used by the crash filter and isolated native tests. Unknown
// modules are omitted and frame values are module-relative RVAs only.
std::size_t FormatWindowsCrashRecord(
    WindowsCrashProcess process, std::uint32_t exception_code,
    std::uint64_t occurred_at_filetime_ticks, const WindowsCrashFrame* frames,
    std::size_t frame_count, char* output, std::size_t output_capacity);

}  // namespace pokrov::windows_crash

#endif  // POKROV_SERVICE_WINDOWS_CRASH_PROFILE_H_
