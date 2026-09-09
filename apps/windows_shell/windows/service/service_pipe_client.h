#ifndef POKROV_SERVICE_SERVICE_PIPE_CLIENT_H_
#define POKROV_SERVICE_SERVICE_PIPE_CLIENT_H_

#include <windows.h>

namespace pokrov::service {

// Opens a local named-pipe client while tolerating another client briefly
// occupying the service's single pipe instance. The caller owns the handle.
HANDLE OpenNamedPipeClient(const wchar_t* pipe_name, DWORD timeout_ms,
                          DWORD flags = 0);

}  // namespace pokrov::service

#endif  // POKROV_SERVICE_SERVICE_PIPE_CLIENT_H_
