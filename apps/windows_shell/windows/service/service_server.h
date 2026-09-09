#ifndef POKROV_SERVICE_SERVICE_SERVER_H_
#define POKROV_SERVICE_SERVICE_SERVER_H_

#include <windows.h>

#include <cstddef>
#include <string>

namespace pokrov::service {

class ServiceEventSink;
class RuntimeHost;

constexpr wchar_t kProductionPipeName[] = L"\\\\.\\pipe\\POKROV.Service.v1";
constexpr wchar_t kTestPipePrefix[] =
    L"\\\\.\\pipe\\POKROV.Service.Test.";

DWORD RunPipeServer(const std::wstring& pipe_name,
                    const std::wstring& owner_sid, HANDLE stop_event,
                    std::size_t test_client_limit,
                    ServiceEventSink* events = nullptr);

#ifdef _DEBUG
DWORD RunPipeServerForTest(const std::wstring& pipe_name,
                          const std::wstring& owner_sid, HANDLE stop_event,
                          RuntimeHost* runtime);
#endif

}  // namespace pokrov::service

#endif  // POKROV_SERVICE_SERVICE_SERVER_H_
