#include "service_profile_identity.h"

#include <windows.h>
#include <bcrypt.h>

#include <algorithm>
#include <array>

#include "service_protocol.h"

namespace pokrov::service {

bool IsProfileDigest(const std::string& value) {
  return value.size() == 64 &&
         std::all_of(value.begin(), value.end(), [](char c) {
           return (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f');
         });
}

std::string ProfileDigest(const std::string& body) {
  if (body.empty() || body.size() > kMaxProfileBodySize) return "";
  std::array<unsigned char, 32> digest{};
  if (::BCryptHash(BCRYPT_SHA256_ALG_HANDLE, nullptr, 0,
                   reinterpret_cast<PUCHAR>(const_cast<char*>(body.data())),
                   static_cast<ULONG>(body.size()), digest.data(),
                   static_cast<ULONG>(digest.size())) != 0) return "";
  constexpr char hex[] = "0123456789abcdef";
  std::string result(digest.size() * 2, '0');
  for (std::size_t i = 0; i < digest.size(); ++i) {
    result[2 * i] = hex[digest[i] >> 4];
    result[2 * i + 1] = hex[digest[i] & 15];
  }
  return result;
}

}  // namespace pokrov::service
