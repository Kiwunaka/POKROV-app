#include "service_local_dpi_json.h"

#include <roapi.h>
#include <windows.data.json.h>
#include <wrl.h>
#include <winhttp.h>
#include <algorithm>
#include <iterator>
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

std::vector<ComPtr<IJsonObject>> Rows(IJsonArray* array) {
  std::vector<ComPtr<IJsonObject>> result;
  UINT32 count = 0;
  if (!array || !Size(array, &count)) return result;
  for (UINT32 i = 0; i < count; ++i) {
    ComPtr<IJsonObject> row;
    if (SUCCEEDED(array->GetObjectAt(i, row.GetAddressOf()))) result.push_back(row);
  }
  return result;
}

std::optional<std::vector<std::string>> Strings(IJsonArray* array) {
  UINT32 count = 0;
  if (!array || !Size(array, &count)) return std::nullopt;
  std::vector<std::string> result;
  for (UINT32 i = 0; i < count; ++i) {
    HString value;
    if (FAILED(array->GetStringAt(i, &value.value))) return std::nullopt;
    result.push_back(value.Utf8());
  }
  return result;
}

bool Fields(IJsonObject* object, UINT32 expected) {
  ComPtr<JsonMap> map;
  UINT32 count = 0;
  return object && SUCCEEDED(object->QueryInterface(IID_PPV_ARGS(map.GetAddressOf()))) &&
      SUCCEEDED(map->get_Size(&count)) && count == expected;
}

bool Number(IJsonObject* object, const wchar_t* field, double expected) {
  HString name;
  double value = 0;
  return object && name.Set(field) && SUCCEEDED(object->GetNamedNumber(name.value, &value)) && value == expected;
}

bool SingleNumber(IJsonObject* object, const wchar_t* field, double expected) {
  const auto array = Array(object, field);
  UINT32 count = 0;
  double value = 0;
  return array && Size(array.Get(), &count) && count == 1 &&
      SUCCEEDED(array->GetNumberAt(0, &value)) && value == expected;
}

ComPtr<IJsonObject> Tagged(const std::vector<ComPtr<IJsonObject>>& rows, const std::string& tag) {
  ComPtr<IJsonObject> result;
  for (const auto& row : rows) if (String(row.Get(), L"tag") == tag) {
    if (result) return {};
    result = row;
  }
  return result;
}

bool DirectDoh(IJsonObject* server, const std::string& direct) {
  const auto detour = String(server, L"detour");
  if (!detour.empty() && detour != direct) return false;
  const auto tls = Object(server, L"tls");
  HString insecure_name;
  boolean insecure = false;
  if (tls && insecure_name.Set(L"insecure") && SUCCEEDED(tls->GetNamedBoolean(insecure_name.value, &insecure)) && insecure) return false;
  const auto type = String(server, L"type");
  if (type == "https") {
    const auto path = String(server, L"path");
    HString port_name;
    double port = 443;
    if (port_name.Set(L"server_port")) server->GetNamedNumber(port_name.value, &port);
    return !String(server, L"server").empty() && port == 443 && (path.empty() || path == "/dns-query");
  }
  if ((!type.empty() && type != "legacy") || detour != direct) return false;
  HString address;
  if (!address.Utf8(String(server, L"address"))) return false;
  UINT32 length = 0;
  const auto* url = ::WindowsGetStringRawBuffer(address.value, &length);
  URL_COMPONENTS parts{};
  parts.dwStructSize = sizeof(parts);
  parts.dwHostNameLength = parts.dwUserNameLength = parts.dwPasswordLength =
      parts.dwUrlPathLength = parts.dwExtraInfoLength = static_cast<DWORD>(-1);
  return ::WinHttpCrackUrl(url, length, 0, &parts) && parts.nScheme == INTERNET_SCHEME_HTTPS &&
      parts.nPort == 443 && parts.dwHostNameLength > 0 && parts.dwUserNameLength == 0 &&
      parts.dwPasswordLength == 0 && parts.dwExtraInfoLength == 0 &&
      std::wstring(parts.lpszUrlPath, parts.dwUrlPathLength) == L"/dns-query";
}
}  // namespace

std::optional<std::string> ReadWindowsSmartAccessProbeTarget(const std::string& encoded) {
  JsonApartment apartment;
  if (!apartment.Ready()) return std::string{};
  const auto profile = ParseObject(encoded);
  if (!profile) return std::string{};
  const auto route = Object(profile.Get(), L"route");
  const auto outbounds = Rows(Array(profile.Get(), L"outbounds").Get());
  const auto final_tag = route ? String(route.Get(), L"final") : "";
  if (final_tag.empty()) return std::nullopt;
  const auto direct = Tagged(outbounds, final_tag);
  if (!direct || String(direct.Get(), L"type") != "direct") return std::nullopt;
  if (std::none_of(outbounds.begin(), outbounds.end(), [](const auto& row) {
        return String(row.Get(), L"type") == "pokrov-smart-access";
      })) return std::nullopt;
  if (!String(direct.Get(), L"detour").empty()) return std::string{};
  const auto dns = Object(profile.Get(), L"dns");
  if (!dns) return std::string{};
  const auto routes = Rows(Array(route.Get(), L"rules").Get());
  const auto dns_rules = Rows(Array(dns.Get(), L"rules").Get());
  const auto servers = Rows(Array(dns.Get(), L"servers").Get());
  auto owned = [](IJsonObject* rule) {
    for (const auto* field : {L"domain", L"domain_suffix"}) {
      const auto values = Strings(Array(rule, field).Get());
      if (values && std::find(values->begin(), values->end(), "api.pokrov.space") != values->end()) return true;
    }
    return false;
  };
  auto exact_owned = [](IJsonObject* rule) {
    return Strings(Array(rule, L"domain").Get()) ==
        std::optional<std::vector<std::string>>{{"api.pokrov.space"}};
  };
  std::vector<ComPtr<IJsonObject>> owned_routes, owned_dns;
  std::copy_if(routes.begin(), routes.end(), std::back_inserter(owned_routes), [&](const auto& rule) { return owned(rule.Get()); });
  std::copy_if(dns_rules.begin(), dns_rules.end(), std::back_inserter(owned_dns), [&](const auto& rule) { return owned(rule.Get()); });
  if (!owned_routes.empty() || !owned_dns.empty()) {
    // Keep the established exact API/VPN boundary. A partial or malformed
    // boundary cannot silently switch to either Direct or Smart proof.
    if (owned_routes.size() != 1 || owned_dns.size() != 1) return std::string{};
    const auto& rr = owned_routes.front(); const auto& dr = owned_dns.front();
    const auto tag = String(rr.Get(), L"outbound");
    const auto resolver = Tagged(servers, String(dr.Get(), L"server"));
    const auto target = Tagged(outbounds, tag);
    const auto endpoints = Rows(Array(profile.Get(), L"endpoints").Get());
    const auto endpoint = Tagged(endpoints, tag);
    const auto type = target ? String(target.Get(), L"type") : endpoint ? String(endpoint.Get(), L"type") : "";
    const bool protected_proxy = !type.empty() &&
        (endpoint || (type != "direct" && type != "block" && type != "dns" && type != "pokrov-smart-access"));
    HString cache_name;
    boolean disabled = false;
    if (Fields(rr.Get(), 5) && exact_owned(rr.Get()) && String(rr.Get(), L"network") == "tcp" &&
        SingleNumber(rr.Get(), L"port", 443) && String(rr.Get(), L"action") == "route" &&
        tag != final_tag && protected_proxy &&
        Fields(dr.Get(), 5) && exact_owned(dr.Get()) && String(dr.Get(), L"action") == "route" &&
        cache_name.Set(L"disable_cache") && SUCCEEDED(dr->GetNamedBoolean(cache_name.value, &disabled)) && disabled &&
        Number(dr.Get(), L"rewrite_ttl", 0) && resolver && String(resolver.Get(), L"detour") == tag) return std::nullopt;
    return std::string{};
  }
  auto lease_id = [](const std::string& value) {
    return value.size() == 32 && std::all_of(value.begin(), value.end(), [](char c) {
      return (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f');
    });
  };
  for (const auto& rule : routes) {
    const auto key = Array(rule.Get(), L"domain") ? L"domain" : L"domain_suffix";
    const auto names = Strings(Array(rule.Get(), key).Get());
    const auto window = Object(rule.Get(), L"pokrov_catalog_window");
    if (!Fields(rule.Get(), 7) || !names || names->size() != 1 || !Fields(window.Get(), 5) ||
        String(rule.Get(), L"network") != "tcp" || String(rule.Get(), L"action") != "route" ||
        !SingleNumber(rule.Get(), L"port", 443) || !Number(rule.Get(), L"ip_version", 4)) continue;
    const auto lease = String(window.Get(), L"lease_id");
    const auto group = Strings(Array(window.Get(), L"lease_group").Get());
    if (!lease_id(lease) || !group || group->empty() || group->size() > 16 || group->front() != lease ||
        std::set<std::string>(group->begin(), group->end()).size() != group->size() ||
        !std::all_of(group->begin(), group->end(), lease_id) || String(window.Get(), L"service_id").empty() ||
        String(window.Get(), L"issued_at").empty() || String(window.Get(), L"expires_at").empty()) continue;
    const auto tag = "pokrov-smart-access-" + lease;
    const auto outbound = Tagged(outbounds, tag);
    if (String(rule.Get(), L"outbound") != tag || !outbound || String(outbound.Get(), L"type") != "pokrov-smart-access" ||
        String(outbound.Get(), L"lease_id") != lease) continue;
    const auto relays = Strings(Array(outbound.Get(), L"relay_addresses").Get());
    const auto domains = Rows(Array(outbound.Get(), L"domains").Get());
    if (!relays || relays->empty() || std::none_of(domains.begin(), domains.end(), [&](const auto& domain) {
          return Fields(domain.Get(), 2) && String(domain.Get(), L"name") == names->front() &&
              String(domain.Get(), L"match") == (std::wcscmp(key, L"domain") == 0 ? "exact" : "suffix");
        })) continue;
    const auto dns_tag = "pokrov-smart-access-dns-" + lease;
    const auto resolver = Tagged(servers, dns_tag);
    if (!resolver || !DirectDoh(resolver.Get(), final_tag)) continue;
    for (const auto& dns_rule : dns_rules) {
      const auto dns_window = Object(dns_rule.Get(), L"pokrov_catalog_window");
      HString cache_name;
      boolean disabled = false;
      if (Fields(dns_rule.Get(), 7) && Strings(Array(dns_rule.Get(), key).Get()) == names &&
          Strings(Array(dns_rule.Get(), L"query_type").Get()) == std::optional<std::vector<std::string>>{{"A"}} &&
          Fields(dns_window.Get(), 5) && Strings(Array(dns_window.Get(), L"lease_group").Get()) == group &&
          String(dns_window.Get(), L"lease_id") == lease && String(dns_window.Get(), L"service_id") == String(window.Get(), L"service_id") &&
          String(dns_window.Get(), L"issued_at") == String(window.Get(), L"issued_at") &&
          String(dns_window.Get(), L"expires_at") == String(window.Get(), L"expires_at") &&
          String(dns_rule.Get(), L"action") == "route" && String(dns_rule.Get(), L"server") == dns_tag &&
          cache_name.Set(L"disable_cache") && SUCCEEDED(dns_rule->GetNamedBoolean(cache_name.value, &disabled)) &&
          disabled && Number(dns_rule.Get(), L"rewrite_ttl", 0)) return tag;
    }
  }
  return std::string{};
}

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
