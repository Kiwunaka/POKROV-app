#ifndef POKROV_SERVICE_PROFILE_IDENTITY_H_
#define POKROV_SERVICE_PROFILE_IDENTITY_H_

#include <string>

namespace pokrov::service {

// SHA-256 of the exact bounded stage request, including flags and bundled rules.
// This is local content identity, never a server assignment revision.
std::string ProfileDigest(const std::string& body);
bool IsProfileDigest(const std::string& value);

}  // namespace pokrov::service
#endif
