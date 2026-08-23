#ifndef POKROV_SERVICE_SERVICE_SERVER_H_
#define POKROV_SERVICE_SERVICE_SERVER_H_

#include <windows.h>

#include <string>

namespace pokrov::service {

class ServiceEventSink;

constexpr wchar_t kProductionPipeName[] = L"\\\\.\\pipe\\POKROV.Service.v1";
constexpr wchar_t kTestPipePrefix[] =
    L"\\\\.\\pipe\\POKROV.Service.Test.";

DWORD RunPipeServer(const std::wstring& pipe_name,
                    const std::wstring& owner_sid, HANDLE stop_event,
                    bool stop_after_one_client,
                    ServiceEventSink* events = nullptr);

}  // namespace pokrov::service

#endif  // POKROV_SERVICE_SERVICE_SERVER_H_
