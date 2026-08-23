#include "service_recovery.h"

#include <windows.h>

#include <bcrypt.h>

#include <array>
#include <cctype>
#include <string>
#include <utility>
#include <vector>

namespace pokrov::service {
namespace {

constexpr char kJournalMagic[] = "POKROV_RECOVERY_V1";
constexpr std::size_t kMaximumNetworkSnapshotSize = 64 * 1024;
constexpr std::size_t kMaximumJournalSize =
    kMaximumNetworkSnapshotSize * 2 + 256;
constexpr wchar_t kJournalName[] = L"recovery-journal.v1";
constexpr wchar_t kPendingJournalName[] = L"recovery-journal.pending";

std::wstring AppendPath(const std::wstring& base, const wchar_t* child) {
  if (base.empty()) {
    return L"";
  }
  return base + (base.back() == L'\\' ? L"" : L"\\") + child;
}

const char* StageName(RecoveryStage stage) {
  switch (stage) {
    case RecoveryStage::kClean:
      return "clean";
    case RecoveryStage::kSnapshotted:
      return "snapshotted";
    case RecoveryStage::kCoreStarted:
      return "core_started";
    case RecoveryStage::kNetworkApplied:
      return "network_applied";
    case RecoveryStage::kVerified:
      return "verified";
    case RecoveryStage::kCommitted:
      return "committed";
    case RecoveryStage::kRollingBack:
      return "rolling_back";
    case RecoveryStage::kRecovered:
      return "recovered";
  }
  return "invalid";
}

bool ParseStage(const std::string& value, RecoveryStage* output) {
  if (output == nullptr) {
    return false;
  }
  constexpr std::array<RecoveryStage, 8> stages = {
      RecoveryStage::kClean,          RecoveryStage::kSnapshotted,
      RecoveryStage::kCoreStarted,    RecoveryStage::kNetworkApplied,
      RecoveryStage::kVerified,       RecoveryStage::kCommitted,
      RecoveryStage::kRollingBack,    RecoveryStage::kRecovered,
  };
  for (const auto stage : stages) {
    if (value == StageName(stage)) {
      *output = stage;
      return true;
    }
  }
  return false;
}

bool IsHexGeneration(const std::string& value) {
  if (value.size() != 32) {
    return false;
  }
  for (const unsigned char character : value) {
    if (!std::isxdigit(character) || std::isupper(character)) {
      return false;
    }
  }
  return true;
}

std::string HexEncode(const std::string& value) {
  constexpr char hex[] = "0123456789abcdef";
  std::string result(value.size() * 2, '0');
  for (std::size_t index = 0; index < value.size(); ++index) {
    const auto byte = static_cast<unsigned char>(value[index]);
    result[index * 2] = hex[byte >> 4];
    result[index * 2 + 1] = hex[byte & 0x0f];
  }
  return result;
}

bool HexDecode(const std::string& value, std::string* output) {
  if (output == nullptr || value.size() % 2 != 0 ||
      value.size() > kMaximumNetworkSnapshotSize * 2) {
    return false;
  }
  const auto nibble = [](unsigned char character) -> int {
    if (character >= '0' && character <= '9') {
      return character - '0';
    }
    if (character >= 'a' && character <= 'f') {
      return character - 'a' + 10;
    }
    return -1;
  };
  std::string result(value.size() / 2, '\0');
  for (std::size_t index = 0; index < result.size(); ++index) {
    const int high = nibble(static_cast<unsigned char>(value[index * 2]));
    const int low = nibble(static_cast<unsigned char>(value[index * 2 + 1]));
    if (high < 0 || low < 0) {
      return false;
    }
    result[index] = static_cast<char>((high << 4) | low);
  }
  *output = std::move(result);
  return true;
}

std::string NewGeneration() {
  std::array<unsigned char, 16> bytes{};
  if (::BCryptGenRandom(nullptr, bytes.data(),
                        static_cast<ULONG>(bytes.size()),
                        BCRYPT_USE_SYSTEM_PREFERRED_RNG) != 0) {
    return "";
  }
  constexpr char hex[] = "0123456789abcdef";
  std::string result(bytes.size() * 2, '0');
  for (std::size_t index = 0; index < bytes.size(); ++index) {
    result[index * 2] = hex[bytes[index] >> 4];
    result[index * 2 + 1] = hex[bytes[index] & 0x0f];
  }
  return result;
}

bool ReadBoundedFile(const std::wstring& path, std::string* output) {
  if (output == nullptr) {
    return false;
  }
  HANDLE file = ::CreateFileW(path.c_str(), GENERIC_READ, FILE_SHARE_READ,
                              nullptr, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL,
                              nullptr);
  if (file == INVALID_HANDLE_VALUE) {
    return false;
  }
  LARGE_INTEGER size{};
  const bool bounded = ::GetFileSizeEx(file, &size) != FALSE &&
                       size.QuadPart > 0 &&
                       size.QuadPart <= kMaximumJournalSize;
  std::string content(bounded ? static_cast<std::size_t>(size.QuadPart) : 0,
                      '\0');
  DWORD read = 0;
  const bool success = bounded &&
                       ::ReadFile(file, content.data(),
                                  static_cast<DWORD>(content.size()), &read,
                                  nullptr) != FALSE &&
                       read == content.size();
  ::CloseHandle(file);
  if (!success) {
    return false;
  }
  *output = std::move(content);
  return true;
}

bool WriteAtomicFile(const std::wstring& target, const std::wstring& pending,
                     const std::string& content) {
  HANDLE file = ::CreateFileW(pending.c_str(), GENERIC_WRITE, 0, nullptr,
                              CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
  if (file == INVALID_HANDLE_VALUE) {
    return false;
  }
  DWORD written = 0;
  const bool flushed =
      ::WriteFile(file, content.data(), static_cast<DWORD>(content.size()),
                  &written, nullptr) != FALSE &&
      written == content.size() && ::FlushFileBuffers(file) != FALSE;
  ::CloseHandle(file);
  if (!flushed ||
      ::MoveFileExW(pending.c_str(), target.c_str(),
                    MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH) ==
          FALSE) {
    ::DeleteFileW(pending.c_str());
    return false;
  }
  return true;
}

bool IsForwardTransition(RecoveryStage current, RecoveryStage next) {
  switch (current) {
    case RecoveryStage::kClean:
      return next == RecoveryStage::kSnapshotted;
    case RecoveryStage::kSnapshotted:
      return next == RecoveryStage::kCoreStarted ||
             next == RecoveryStage::kRollingBack;
    case RecoveryStage::kCoreStarted:
      return next == RecoveryStage::kNetworkApplied ||
             next == RecoveryStage::kRollingBack;
    case RecoveryStage::kNetworkApplied:
      return next == RecoveryStage::kVerified ||
             next == RecoveryStage::kRollingBack;
    case RecoveryStage::kVerified:
      return next == RecoveryStage::kCommitted ||
             next == RecoveryStage::kRollingBack;
    case RecoveryStage::kCommitted:
      return next == RecoveryStage::kRollingBack;
    case RecoveryStage::kRollingBack:
      return next == RecoveryStage::kRecovered;
    case RecoveryStage::kRecovered:
      return next == RecoveryStage::kClean;
  }
  return false;
}

class DurableRuntimeRecovery final : public RuntimeRecovery {
 public:
  DurableRuntimeRecovery(std::wstring runtime_root,
                         std::unique_ptr<NetworkStateBackend> network_state)
      : journal_path_(AppendPath(runtime_root, kJournalName)),
        pending_path_(AppendPath(runtime_root, kPendingJournalName)),
        network_state_(std::move(network_state)) {
    Load();
  }

  bool RequiresRecovery() const override {
    return invalid_ || stage_ != RecoveryStage::kClean;
  }

  const char* StageName() const override {
    return invalid_ ? "invalid" : pokrov::service::StageName(stage_);
  }

  std::string Begin() override {
    if (invalid_) {
      return "recovery_journal_invalid";
    }
    if (stage_ != RecoveryStage::kClean) {
      return "recovery_required";
    }
    const auto generation = NewGeneration();
    if (generation.empty()) {
      return "recovery_generation_failed";
    }
    if (network_state_ == nullptr) {
      return "recovery_network_unavailable";
    }
    std::string snapshot;
    const auto capture_error = network_state_->Capture(&snapshot);
    if (!capture_error.empty()) {
      return capture_error;
    }
    if (snapshot.empty() || snapshot.size() > kMaximumNetworkSnapshotSize) {
      return "recovery_network_snapshot_invalid";
    }
    generation_ = generation;
    network_snapshot_ = std::move(snapshot);
    return Record(RecoveryStage::kSnapshotted);
  }

  std::string Record(RecoveryStage stage) override {
    if (invalid_) {
      return "recovery_journal_invalid";
    }
    if (!IsForwardTransition(stage_, stage)) {
      return "recovery_stage_invalid";
    }
    const auto previous = stage_;
    stage_ = stage;
    if (!Write()) {
      stage_ = previous;
      return "recovery_write_failed";
    }
    return "";
  }

  std::string BeginRollback() override {
    if (invalid_) {
      return "recovery_journal_invalid";
    }
    if (stage_ == RecoveryStage::kClean) {
      return "";
    }
    if (stage_ == RecoveryStage::kRollingBack) {
      return "";
    }
    if (stage_ == RecoveryStage::kRecovered) {
      return Record(RecoveryStage::kClean);
    }
    return Record(RecoveryStage::kRollingBack);
  }

  std::string RestoreNetworkState() override {
    if (invalid_) {
      return "recovery_journal_invalid";
    }
    if (stage_ == RecoveryStage::kClean) {
      return "";
    }
    if (stage_ != RecoveryStage::kRollingBack) {
      return "recovery_stage_invalid";
    }
    if (network_state_ == nullptr) {
      return "recovery_network_unavailable";
    }
    if (network_snapshot_.empty() ||
        network_snapshot_.size() > kMaximumNetworkSnapshotSize) {
      return "recovery_network_snapshot_invalid";
    }
    return network_state_->Restore(network_snapshot_);
  }

  std::string CompleteRollback() override {
    if (invalid_) {
      return "recovery_journal_invalid";
    }
    if (stage_ == RecoveryStage::kClean) {
      return "";
    }
    if (stage_ != RecoveryStage::kRollingBack) {
      return "recovery_stage_invalid";
    }
    auto error = Record(RecoveryStage::kRecovered);
    if (!error.empty()) {
      return error;
    }
    const auto snapshot = network_snapshot_;
    network_snapshot_.clear();
    error = Record(RecoveryStage::kClean);
    if (!error.empty()) {
      network_snapshot_ = snapshot;
    }
    return error;
  }

 private:
  void Load() {
    const DWORD attributes = ::GetFileAttributesW(journal_path_.c_str());
    if (attributes == INVALID_FILE_ATTRIBUTES) {
      if (::GetLastError() == ERROR_FILE_NOT_FOUND ||
          ::GetLastError() == ERROR_PATH_NOT_FOUND) {
        generation_ = std::string(32, '0');
        return;
      }
      invalid_ = true;
      return;
    }
    std::string content;
    if (!ReadBoundedFile(journal_path_, &content)) {
      invalid_ = true;
      return;
    }
    if (content.back() != '\n') {
      invalid_ = true;
      return;
    }
    std::vector<std::string> lines;
    std::size_t start = 0;
    while (start < content.size()) {
      const auto end = content.find('\n', start);
      if (end == std::string::npos) {
        invalid_ = true;
        return;
      }
      lines.push_back(content.substr(start, end - start));
      start = end + 1;
    }
    constexpr char kStagePrefix[] = "stage=";
    constexpr char kGenerationPrefix[] = "generation=";
    constexpr char kNetworkPrefix[] = "network_state=";
    if (lines.size() != 4 || lines[0] != kJournalMagic ||
        lines[1].rfind(kStagePrefix, 0) != 0 ||
        lines[2].rfind(kGenerationPrefix, 0) != 0 ||
        lines[3].rfind(kNetworkPrefix, 0) != 0) {
      invalid_ = true;
      return;
    }
    const auto generation =
        lines[2].substr(sizeof(kGenerationPrefix) - 1);
    std::string network_snapshot;
    RecoveryStage parsed = RecoveryStage::kClean;
    if (!ParseStage(lines[1].substr(sizeof(kStagePrefix) - 1), &parsed) ||
        !IsHexGeneration(generation) ||
        !HexDecode(lines[3].substr(sizeof(kNetworkPrefix) - 1),
                   &network_snapshot) ||
        (parsed != RecoveryStage::kClean &&
         (generation == std::string(32, '0') || network_snapshot.empty())) ||
        (parsed == RecoveryStage::kClean && !network_snapshot.empty())) {
      invalid_ = true;
      return;
    }
    stage_ = parsed;
    generation_ = generation;
    network_snapshot_ = std::move(network_snapshot);
  }

  bool Write() const {
    if (journal_path_.empty() || pending_path_.empty() ||
        !IsHexGeneration(generation_)) {
      return false;
    }
    const std::string content = std::string(kJournalMagic) + "\nstage=" +
                                pokrov::service::StageName(stage_) +
                                "\ngeneration=" + generation_ +
                                "\nnetwork_state=" +
                                HexEncode(network_snapshot_) + "\n";
    return WriteAtomicFile(journal_path_, pending_path_, content);
  }

  std::wstring journal_path_;
  std::wstring pending_path_;
  std::unique_ptr<NetworkStateBackend> network_state_;
  RecoveryStage stage_ = RecoveryStage::kClean;
  std::string generation_ = std::string(32, '0');
  std::string network_snapshot_;
  bool invalid_ = false;
};

}  // namespace

std::unique_ptr<RuntimeRecovery> CreateRuntimeRecovery(
    const std::wstring& runtime_root) {
  return std::make_unique<DurableRuntimeRecovery>(
      runtime_root, CreateWindowsNetworkStateBackend());
}

std::unique_ptr<RuntimeRecovery> CreateRuntimeRecoveryForTesting(
    const std::wstring& runtime_root,
    std::unique_ptr<NetworkStateBackend> network_state) {
  return std::make_unique<DurableRuntimeRecovery>(runtime_root,
                                                  std::move(network_state));
}

}  // namespace pokrov::service
