#include "service_local_dpi_json.h"

#include <roapi.h>
#include <windows.data.json.h>
#include <wrl.h>
#include <climits>
#include <cwchar>
#include <set>

namespace pokrov::service {
namespace {
using Microsoft::WRL::ComPtr;
using namespace ABI::Windows::Data::Json;
using JsonMap = ABI::Windows::Foundation::Collections::IMap<HSTRING, IJsonValue*>;
using JsonVector = ABI::Windows::Foundation::Collections::IVector<IJsonValue*>;

struct HString {
  HSTRING value = nullptr;
  ~HString() { ::WindowsDeleteString(value); }
  bool Set(const wchar_t* text) {
    return SUCCEEDED(::WindowsCreateString(text, static_cast<UINT32>(std::wcslen(text)), &value));
  }
  bool Utf8(const std::string& text) {
    if (text.empty() || text.size() > INT_MAX) return false;
    const int size = ::MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS,
        text.data(), static_cast<int>(text.size()), nullptr, 0);
    if (size == 0) return false;
    std::wstring wide(static_cast<std::size_t>(size), L'\0');
    return ::MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, text.data(),
        static_cast<int>(text.size()), wide.data(), size) == size &&
        SUCCEEDED(::WindowsCreateString(wide.data(), static_cast<UINT32>(size), &value));
  }
  std::string Utf8() const {
    UINT32 length = 0;
    const auto* text = ::WindowsGetStringRawBuffer(value, &length);
    if (length == 0 || length > INT_MAX) return "";
    const int size = ::WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, text,
        static_cast<int>(length), nullptr, 0, nullptr, nullptr);
    if (size == 0) return "";
    std::string result(static_cast<std::size_t>(size), '\0');
    return ::WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, text,
        static_cast<int>(length), result.data(), size, nullptr, nullptr) == size ? result : "";
  }
};

struct JsonApartment {
  HRESULT result = ::RoInitialize(RO_INIT_MULTITHREADED);
  ~JsonApartment() { if (SUCCEEDED(result)) ::RoUninitialize(); }
  bool Ready() const { return SUCCEEDED(result) || result == RPC_E_CHANGED_MODE; }
};

ComPtr<IJsonObject> ParseObject(const std::string& encoded) {
  HString class_name, input;
  ComPtr<IJsonValueStatics> factory;
  ComPtr<IJsonValue> value;
  ComPtr<IJsonObject> object;
  boolean parsed = false;
  if (encoded.size() > 4 * 1024 * 1024 || !class_name.Set(RuntimeClass_Windows_Data_Json_JsonValue) ||
      !input.Utf8(encoded) || FAILED(::RoGetActivationFactory(class_name.value,
          __uuidof(IJsonValueStatics), reinterpret_cast<void**>(factory.GetAddressOf()))) ||
      FAILED(factory->TryParse(input.value, value.GetAddressOf(), &parsed)) || !parsed ||
      FAILED(value->GetObject(object.GetAddressOf()))) return {};
  return object;
}

std::string String(IJsonObject* object, const wchar_t* field) {
  HString name, value;
  return name.Set(field) && SUCCEEDED(object->GetNamedString(name.value, &value.value)) ? value.Utf8() : "";
}

ComPtr<IJsonObject> Object(IJsonObject* object, const wchar_t* field) {
  HString name;
  ComPtr<IJsonObject> result;
  if (!name.Set(field) || FAILED(object->GetNamedObject(name.value, result.GetAddressOf()))) return {};
  return result;
}

ComPtr<IJsonArray> Array(IJsonObject* object, const wchar_t* field) {
  HString name;
  ComPtr<IJsonArray> result;
  if (!name.Set(field) || FAILED(object->GetNamedArray(name.value, result.GetAddressOf()))) return {};
  return result;
}

std::string Encode(IJsonObject* object) {
  ComPtr<IJsonValue> value;
  HString encoded;
  return SUCCEEDED(object->QueryInterface(IID_PPV_ARGS(value.GetAddressOf()))) &&
      SUCCEEDED(value->Stringify(&encoded.value)) ? encoded.Utf8() : "";
}

std::uint64_t UtcTicks() {
  FILETIME value{};
  ::GetSystemTimeAsFileTime(&value);
  return (static_cast<std::uint64_t>(value.dwHighDateTime) << 32) | value.dwLowDateTime;
}

std::uint64_t Expiry(const std::string& value) {
  if (value.size() != 20 || value[4] != '-' || value[7] != '-' || value[10] != 'T' ||
      value[13] != ':' || value[16] != ':' || value[19] != 'Z') return 0;
  auto number = [&](std::size_t start, std::size_t size) -> WORD {
    WORD result = 0;
    for (auto i = start; i < start + size; ++i) {
      if (value[i] < '0' || value[i] > '9') return 0xffff;
      result = static_cast<WORD>(result * 10 + value[i] - '0');
    }
    return result;
  };
  SYSTEMTIME time{};
  time.wYear = number(0, 4); time.wMonth = number(5, 2); time.wDay = number(8, 2);
  time.wHour = number(11, 2); time.wMinute = number(14, 2); time.wSecond = number(17, 2);
  FILETIME file{};
  if (!::SystemTimeToFileTime(&time, &file)) return 0;
  return (static_cast<std::uint64_t>(file.dwHighDateTime) << 32) | file.dwLowDateTime;
}

bool Size(IJsonArray* array, UINT32* size) {
  ComPtr<JsonVector> vector;
  return SUCCEEDED(array->QueryInterface(IID_PPV_ARGS(vector.GetAddressOf()))) && SUCCEEDED(vector->get_Size(size));
}
}  // namespace

bool StripWindowsLocalDpiMetadata(const std::string& original,
                                 std::string* runtime_copy, bool* requested,
                                 bool* telegram_requested) {
  *requested = false;
  if (telegram_requested) *telegram_requested = false;
  JsonApartment apartment;
  if (!apartment.Ready()) return false;
  const auto profile = ParseObject(original);
  if (!profile) return false;
  ComPtr<JsonMap> fields;
  HString meta_name;
  boolean has_meta = false;
  if (!meta_name.Set(L"_meta") || FAILED(profile.As(&fields)) ||
      FAILED(fields->HasKey(meta_name.value, &has_meta))) return false;
  if (!has_meta) { *runtime_copy = original; return true; }
  const auto meta = Object(profile.Get(), L"_meta");
  const auto dpi = meta ? Object(meta.Get(), L"local_dpi") : ComPtr<IJsonObject>{};
  if (dpi) *requested = String(dpi.Get(), L"platform") == "windows" && String(dpi.Get(), L"mode") == "selective";
  if (telegram_requested) {
    const auto telegram = meta ? Object(meta.Get(), L"telegram_ws") : ComPtr<IJsonObject>{};
    if (telegram) *telegram_requested = String(telegram.Get(), L"platform") == "windows" &&
        String(telegram.Get(), L"mode") == "selective";
  }
  if (FAILED(fields->Remove(meta_name.value))) return false;
  *runtime_copy = Encode(profile.Get());
  return !runtime_copy->empty();
}

std::optional<WindowsLocalDpiPreparation> ReadWindowsLocalDpiPreparation(const std::string& encoded) {
  JsonApartment apartment;
  if (!apartment.Ready()) return std::nullopt;
  const auto receipt = ParseObject(encoded);
  if (!receipt) return std::nullopt;
  const auto profile = Object(receipt.Get(), L"profile");
  const auto services = Array(receipt.Get(), L"services");
  UINT32 service_count = 0;
  WindowsLocalDpiPreparation result;
  result.expires_utc_ticks = Expiry(String(receipt.Get(), L"expires_at"));
  const auto now = UtcTicks();
  if (!profile || !services || !Size(services.Get(), &service_count) ||
      service_count == 0 || service_count > 256 || result.expires_utc_ticks <= now) return std::nullopt;
  result.profile = Encode(profile.Get());
  if (result.profile.empty()) return std::nullopt;
  result.expires_elapsed_ms = ::GetTickCount64() + (result.expires_utc_ticks - now) / 10000;
  std::set<std::string> tags;
  for (UINT32 i = 0; i < service_count; ++i) {
    ComPtr<IJsonObject> row;
    if (FAILED(services->GetObjectAt(i, row.GetAddressOf()))) return std::nullopt;
    WindowsLocalDpiService service{String(row.Get(), L"service_id"), String(row.Get(), L"outbound_tag"),
        String(row.Get(), L"control_host"), {}};
    const auto domains = Array(row.Get(), L"domains");
    UINT32 domain_count = 0;
    if (service.service_id.empty() || !tags.insert(service.outbound_tag).second ||
        !domains || !Size(domains.Get(), &domain_count) || domain_count == 0 || domain_count > 1024) return std::nullopt;
    for (UINT32 j = 0; j < domain_count; ++j) {
      ComPtr<IJsonObject> domain;
      HString shared_name;
      boolean shared = true;
      if (FAILED(domains->GetObjectAt(j, domain.GetAddressOf())) || !shared_name.Set(L"shared") ||
          FAILED(domain->GetNamedBoolean(shared_name.value, &shared)) || shared) return std::nullopt;
      const auto match = String(domain.Get(), L"match");
      if (match != "exact" && match != "suffix") return std::nullopt;
      service.domains.push_back({String(domain.Get(), L"name"), match == "exact", false});
    }
    result.services.push_back(std::move(service));
  }
  if (WindowsLocalDpiHostList(result.services).empty()) return std::nullopt;
  return result;
}

bool WindowsLocalDpiPreparationCurrent(const WindowsLocalDpiPreparation& value) {
  return ::GetTickCount64() < value.expires_elapsed_ms && UtcTicks() < value.expires_utc_ticks;
}

std::optional<WindowsTelegramWSPreparation> ReadWindowsTelegramWSPreparation(const std::string& encoded) {
  JsonApartment apartment;
  if (!apartment.Ready()) return std::nullopt;
  const auto receipt = ParseObject(encoded);
  double schema = 0;
  HString schema_name;
  if (!receipt || !schema_name.Set(L"schema_version") ||
      FAILED(receipt->GetNamedNumber(schema_name.value, &schema)) || schema != 1) return std::nullopt;
  const auto profile = Object(receipt.Get(), L"profile");
  const auto services = Array(receipt.Get(), L"services");
  UINT32 count = 0;
  WindowsTelegramWSPreparation result;
  const auto issued = Expiry(String(receipt.Get(), L"issued_at"));
  result.expires_utc_ticks = Expiry(String(receipt.Get(), L"expires_at"));
  const auto now = UtcTicks();
  if (!profile || !services || !Size(services.Get(), &count) || count == 0 || count > 256 ||
      issued == 0 || issued > now || issued >= result.expires_utc_ticks ||
      result.expires_utc_ticks <= now) return std::nullopt;
  result.profile = Encode(profile.Get());
  if (result.profile.empty()) return std::nullopt;
  result.expires_elapsed_ms = ::GetTickCount64() + (result.expires_utc_ticks - now) / 10000;
  std::set<std::string> ids, tags;
  for (UINT32 i = 0; i < count; ++i) {
    ComPtr<IJsonObject> row;
    if (FAILED(services->GetObjectAt(i, row.GetAddressOf()))) return std::nullopt;
    const auto id = String(row.Get(), L"service_id"), tag = String(row.Get(), L"outbound_tag");
    if (id.empty() || tag.empty() || !ids.insert(id).second || !tags.insert(tag).second) return std::nullopt;
    result.services.emplace_back(id, tag);
  }
  return result;
}

bool WindowsTelegramWSPreparationCurrent(const WindowsTelegramWSPreparation& value) {
  return ::GetTickCount64() < value.expires_elapsed_ms && UtcTicks() < value.expires_utc_ticks;
}
}  // namespace pokrov::service
