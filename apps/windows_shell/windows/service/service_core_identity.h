#ifndef POKROV_SERVICE_CORE_IDENTITY_H_
#define POKROV_SERVICE_CORE_IDENTITY_H_

#include <windows.h>
#include <string>

namespace pokrov::service {
// The service owns one process-lifetime Go Core module. Empty digest means
// identity unavailable; it never substitutes a package/profile checksum.
HMODULE LoadCoreModuleWithIdentity(const std::wstring& path, std::string* digest);
}

#endif
