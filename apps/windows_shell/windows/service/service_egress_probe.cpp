#include "service_runtime.h"

#include <windows.h>
#include <winhttp.h>

#include <array>
#include <atomic>
#include <memory>

namespace pokrov::service {
namespace {

bool Interrupted(const CheckInterruption& check) {
  return check && check() != OperationInterruption::kNone;
}

enum class ProbeStage { kConnect, kTls, kSending, kResponse };

const char* ObservedFailure(DWORD error, ProbeStage stage) {
  switch (error) {
    case ERROR_WINHTTP_NAME_NOT_RESOLVED:
      return "core_egress_dns_failed";
    case ERROR_WINHTTP_CANNOT_CONNECT:
      return "core_egress_connect_failed";
    case ERROR_WINHTTP_SECURE_FAILURE:
    case ERROR_WINHTTP_CLIENT_AUTH_CERT_NEEDED:
      return "core_egress_tls_failed";
    case ERROR_WINHTTP_TIMEOUT:
      if (stage == ProbeStage::kTls) return "core_egress_tls_timeout";
      if (stage == ProbeStage::kResponse) return "core_egress_response_timeout";
      return "core_egress_timeout";
    default:
      return "core_egress_probe_failed";
  }
}

// WinHTTP can call back after CloseHandle returns. The request owns one
// reference until HANDLE_CLOSING; the runtime owns the other while waiting.
class Completion {
 public:
  explicit Completion(bool secure)
      : ready(::CreateEventW(nullptr, FALSE, FALSE, nullptr)), secure_(secure) {}
  void Retain() { references.fetch_add(1); }
  void Release() {
    if (references.fetch_sub(1) == 1) delete this;
  }

  bool Wait(DWORD expected, const CheckInterruption& interrupted) {
    while (!Interrupted(interrupted)) {
      const auto wait = ::WaitForSingleObject(ready, 50);
      if (wait == WAIT_OBJECT_0) return status.load() == expected;
      if (wait != WAIT_TIMEOUT) return false;
    }
    return false;
  }

  static void CALLBACK Callback(HINTERNET, DWORD_PTR context, DWORD status,
                                void* information, DWORD information_size) {
    auto* completion = reinterpret_cast<Completion*>(context);
    if (completion == nullptr) return;
    if (status == WINHTTP_CALLBACK_STATUS_HANDLE_CLOSING) {
      completion->Release();
    } else if (status == WINHTTP_CALLBACK_STATUS_CONNECTING_TO_SERVER) {
      completion->stage.store(ProbeStage::kConnect);
    } else if (status == WINHTTP_CALLBACK_STATUS_CONNECTED_TO_SERVER) {
      completion->stage.store(completion->secure_ ? ProbeStage::kTls
                                                 : ProbeStage::kConnect);
    } else if (status == WINHTTP_CALLBACK_STATUS_SENDING_REQUEST) {
      // With no proxy and no request body, TLS has completed by this point.
      completion->stage.store(ProbeStage::kSending);
    } else if (status == WINHTTP_CALLBACK_STATUS_SENDREQUEST_COMPLETE ||
               status == WINHTTP_CALLBACK_STATUS_HEADERS_AVAILABLE ||
               status == WINHTTP_CALLBACK_STATUS_REQUEST_ERROR) {
      if (status == WINHTTP_CALLBACK_STATUS_SENDREQUEST_COMPLETE) {
        completion->stage.store(ProbeStage::kResponse);
      }
      if (status == WINHTTP_CALLBACK_STATUS_REQUEST_ERROR &&
          information != nullptr && information_size == sizeof(WINHTTP_ASYNC_RESULT)) {
        completion->error.store(
            static_cast<WINHTTP_ASYNC_RESULT*>(information)->dwError);
      }
      completion->status.store(status);
      ::SetEvent(completion->ready);
    }
  }

  HANDLE ready;
  std::atomic<DWORD> error{ERROR_SUCCESS};
  std::atomic<ProbeStage> stage{ProbeStage::kConnect};

 private:
  ~Completion() { if (ready != nullptr) ::CloseHandle(ready); }
  std::atomic<unsigned> references{1};
  std::atomic<DWORD> status{0};
  bool secure_;
};

class AuthenticatedEgressProbe final : public RuntimeEgressProbe {
 public:
  AuthenticatedEgressProbe(const wchar_t* host, INTERNET_PORT port, bool secure)
      : host_(host), port_(port), secure_(secure) {}

  std::string Verify(const CheckInterruption& interrupted) override {
    std::string failure = "core_egress_probe_failed";
    for (int attempt = 0; attempt < 3 && !Interrupted(interrupted); ++attempt) {
      failure = ProbeOnce(interrupted);
      if (failure.empty() && !Interrupted(interrupted)) return "";
      if (attempt < 2) {
        const auto until = ::GetTickCount64() + (attempt == 0 ? 900 : 1500);
        while (::GetTickCount64() < until && !Interrupted(interrupted)) {
          ::Sleep(25);
        }
      }
    }
    return Interrupted(interrupted) ? "core_egress_probe_failed" : failure;
  }

 private:
  std::string ProbeOnce(const CheckInterruption& interrupted) {
    const HINTERNET session = ::WinHttpOpen(
        L"POKROVService/1.2", WINHTTP_ACCESS_TYPE_NO_PROXY,
        WINHTTP_NO_PROXY_NAME, WINHTTP_NO_PROXY_BYPASS, WINHTTP_FLAG_ASYNC);
    if (session == nullptr) return "core_egress_probe_failed";
    ::WinHttpSetTimeouts(session, 3000, 3000, 3000, 6000);
    const HINTERNET connection = ::WinHttpConnect(session, host_, port_, 0);
    const HINTERNET request = connection == nullptr ? nullptr :
        ::WinHttpOpenRequest(connection, L"GET",
            L"/api/public/authenticated-egress-probe", nullptr,
            WINHTTP_NO_REFERER, WINHTTP_DEFAULT_ACCEPT_TYPES,
            WINHTTP_FLAG_REFRESH | (secure_ ? WINHTTP_FLAG_SECURE : 0));
    auto* completion = new Completion(secure_);
    DWORD_PTR context = reinterpret_cast<DWORD_PTR>(completion);
    bool callback_installed = false;
    if (request != nullptr && completion->ready != nullptr &&
        ::WinHttpSetOption(request, WINHTTP_OPTION_CONTEXT_VALUE,
                           &context, sizeof(context))) {
      completion->Retain();
      callback_installed = ::WinHttpSetStatusCallback(
          request, Completion::Callback,
          WINHTTP_CALLBACK_FLAG_ALL_COMPLETIONS | WINHTTP_CALLBACK_FLAG_HANDLES |
              WINHTTP_CALLBACK_FLAG_CONNECT_TO_SERVER | WINHTTP_CALLBACK_FLAG_SEND_REQUEST,
          0) != WINHTTP_INVALID_STATUS_CALLBACK;
      if (!callback_installed) completion->Release();
    }
    bool valid = false;
    DWORD error = ERROR_SUCCESS;
    if (callback_installed && !Interrupted(interrupted)) {
      if (!::WinHttpSendRequest(request, WINHTTP_NO_ADDITIONAL_HEADERS,
                               0, WINHTTP_NO_REQUEST_DATA, 0, 0, context)) {
        error = ::GetLastError();
      } else if (completion->Wait(WINHTTP_CALLBACK_STATUS_SENDREQUEST_COMPLETE, interrupted) &&
                 !Interrupted(interrupted)) {
        if (!::WinHttpReceiveResponse(request, nullptr)) {
          error = ::GetLastError();
        } else {
          valid = completion->Wait(WINHTTP_CALLBACK_STATUS_HEADERS_AVAILABLE, interrupted) &&
                  !Interrupted(interrupted);
        }
      }
    }
    if (error == ERROR_SUCCESS) error = completion->error.load();
    const auto failure = ObservedFailure(error, completion->stage.load());
    DWORD status = 0;
    DWORD status_size = sizeof(status);
    if (valid) {
      valid = ::WinHttpQueryHeaders(request,
          WINHTTP_QUERY_STATUS_CODE | WINHTTP_QUERY_FLAG_NUMBER,
          WINHTTP_HEADER_NAME_BY_INDEX, &status, &status_size,
          WINHTTP_NO_HEADER_INDEX) != FALSE && status == HTTP_STATUS_NO_CONTENT;
    }
    std::array<wchar_t, 64> proof{};
    DWORD proof_size = static_cast<DWORD>(proof.size() * sizeof(wchar_t));
    if (valid) {
      valid = ::WinHttpQueryHeaders(request, WINHTTP_QUERY_CUSTOM,
          L"x-pokrov-egress-probe", proof.data(), &proof_size,
          WINHTTP_NO_HEADER_INDEX) != FALSE &&
          std::wstring(proof.data()) == L"pokrov-authenticated-egress-v1";
    }
    // All request API calls have returned. Closing an async request cancels
    // pending I/O; no other thread calls WinHTTP with this request handle.
    if (request != nullptr) ::WinHttpCloseHandle(request);
    completion->Release();
    if (connection != nullptr) ::WinHttpCloseHandle(connection);
    ::WinHttpCloseHandle(session);
    return valid && !Interrupted(interrupted) ? "" : failure;
  }

  const wchar_t* host_;
  INTERNET_PORT port_;
  bool secure_;
};

}  // namespace

std::unique_ptr<RuntimeEgressProbe> CreateAuthenticatedEgressProbe() {
  return std::make_unique<AuthenticatedEgressProbe>(
      L"api.pokrov.space", static_cast<INTERNET_PORT>(INTERNET_DEFAULT_HTTPS_PORT), true);
}

#ifdef _DEBUG
std::unique_ptr<RuntimeEgressProbe> CreateLoopbackEgressProbeForTest(
    std::uint16_t port, bool secure) {
  return std::make_unique<AuthenticatedEgressProbe>(L"127.0.0.1", port, secure);
}
#endif

}  // namespace pokrov::service
