#ifndef POKROV_SERVICE_LOCAL_DPI_PROBE_H_
#define POKROV_SERVICE_LOCAL_DPI_PROBE_H_
#include "service_runtime.h"

namespace pokrov::service {
// One bounded TCP/443 Schannel + HEAD/2xx exchange on the captured physical
// adapter. No redirects, payload body, credentials or certificate exceptions.
std::string VerifyWindowsLocalDpiControlHost(const std::string& control_host,
                                           const std::string& bind_interface,
                                           const CheckInterruption& interrupted);
}
#endif
