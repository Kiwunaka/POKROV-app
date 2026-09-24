#include "service_core_identity.h"

#include <bcrypt.h>
#include <array>
#include <mutex>

namespace pokrov::service {
namespace {
struct PinnedCoreModule {
  HMODULE module = nullptr;
  HANDLE file = INVALID_HANDLE_VALUE;
  std::wstring path;
  std::string digest;
  ~PinnedCoreModule() {
    // Existing Go runtime libraries are not unloaded. Retain the file lock for
    // that same process lifetime, including failed setup/retry of the module.
    if (file != INVALID_HANDLE_VALUE) ::CloseHandle(file);
  }
};

std::string HashLoadedCore(HMODULE module, HANDLE file) {
  BY_HANDLE_FILE_INFORMATION pinned{};
  if (file == INVALID_HANDLE_VALUE || !::GetFileInformationByHandle(file, &pinned) ||
      (pinned.dwFileAttributes & (FILE_ATTRIBUTE_DIRECTORY | FILE_ATTRIBUTE_REPARSE_POINT)) != 0) return "";
  const auto size = (static_cast<ULONGLONG>(pinned.nFileSizeHigh) << 32) | pinned.nFileSizeLow;
  if (size == 0 || size > (1ULL << 30)) return "";
  std::array<wchar_t, 32768> path{};
  const DWORD length = ::GetModuleFileNameW(module, path.data(), static_cast<DWORD>(path.size()));
  if (length == 0 || length >= path.size()) return "";
  HANDLE loaded = ::CreateFileW(path.data(), GENERIC_READ, FILE_SHARE_READ, nullptr,
      OPEN_EXISTING, FILE_FLAG_OPEN_REPARSE_POINT, nullptr);
  if (loaded == INVALID_HANDLE_VALUE) return "";
  BY_HANDLE_FILE_INFORMATION actual{};
  const bool same = ::GetFileInformationByHandle(loaded, &actual) &&
      pinned.dwVolumeSerialNumber == actual.dwVolumeSerialNumber &&
      pinned.nFileIndexHigh == actual.nFileIndexHigh && pinned.nFileIndexLow == actual.nFileIndexLow;
  ::CloseHandle(loaded);
  if (!same) return "";
  struct Hash {
    BCRYPT_HASH_HANDLE value = nullptr;
    ~Hash() { if (value != nullptr) ::BCryptDestroyHash(value); }
  } hash;
  if (::BCryptCreateHash(BCRYPT_SHA256_ALG_HANDLE, &hash.value, nullptr, 0, nullptr, 0, 0) != 0) return "";
  std::array<unsigned char, 65536> buffer{};
  ULONGLONG total = 0;
  for (;;) {
    DWORD count = 0;
    if (!::ReadFile(file, buffer.data(), static_cast<DWORD>(buffer.size()), &count, nullptr)) return "";
    if (count == 0) break;
    total += count;
    if (total > size || ::BCryptHashData(hash.value, buffer.data(), count, 0) != 0) return "";
  }
  std::array<unsigned char, 32> bytes{};
  if (total != size || ::BCryptFinishHash(hash.value, bytes.data(), static_cast<ULONG>(bytes.size()), 0) != 0) return "";
  constexpr char hex[] = "0123456789abcdef";
  std::string result(64, '0');
  for (std::size_t i = 0; i < bytes.size(); ++i) {
    result[2 * i] = hex[bytes[i] >> 4];
    result[2 * i + 1] = hex[bytes[i] & 15];
  }
  return result;
}
}

HMODULE LoadCoreModuleWithIdentity(const std::wstring& path, std::string* digest) {
  static std::mutex lock;
  static PinnedCoreModule pinned;
  std::lock_guard<std::mutex> guard(lock);
  digest->clear();
  if (pinned.module != nullptr) {
    if (pinned.path != path) return nullptr;
    *digest = pinned.digest;
    return pinned.module;
  }
  // An image already loaded outside this owner cannot acquire a new file-based
  // identity retrospectively. Keep ordinary ABI compatibility but no ATS hash.
  const bool previously_loaded = ::GetModuleHandleW(path.c_str()) != nullptr;
  pinned.file = ::CreateFileW(path.c_str(), GENERIC_READ, FILE_SHARE_READ, nullptr,
      OPEN_EXISTING, FILE_FLAG_OPEN_REPARSE_POINT | FILE_FLAG_SEQUENTIAL_SCAN, nullptr);
  pinned.module = ::LoadLibraryExW(path.c_str(), nullptr,
      LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR | LOAD_LIBRARY_SEARCH_SYSTEM32);
  if (pinned.module == nullptr) {
    if (pinned.file != INVALID_HANDLE_VALUE) ::CloseHandle(pinned.file);
    pinned.file = INVALID_HANDLE_VALUE;
    return nullptr;
  }
  pinned.path = path;
  if (!previously_loaded) pinned.digest = HashLoadedCore(pinned.module, pinned.file);
  *digest = pinned.digest;
  return pinned.module;
}
}
