#include "flutter_window.h"

#include <optional>

#include <flutter/standard_method_codec.h>

#include "flutter/generated_plugin_registrant.h"
#include "utils.h"

namespace {
constexpr ULONG_PTR kPokrovAcquisitionCopyData = 0x504F4B52;
constexpr char kAcquisitionLinksChannel[] = "space.pokrov/acquisition-links";
}

FlutterWindow::FlutterWindow(const flutter::DartProject& project,
                             std::string initial_acquisition_uri)
    : project_(project),
      pending_acquisition_uri_(std::move(initial_acquisition_uri)) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  acquisition_links_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), kAcquisitionLinksChannel,
          &flutter::StandardMethodCodec::GetInstance());
  acquisition_links_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        if (call.method_name() != "getInitialUri") {
          result->NotImplemented();
          return;
        }
        if (pending_acquisition_uri_.empty()) {
          result->Success();
          return;
        }
        const auto uri = pending_acquisition_uri_;
        pending_acquisition_uri_.clear();
        result->Success(flutter::EncodableValue(uri));
      });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  acquisition_links_channel_.reset();
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_COPYDATA: {
      const auto* payload = reinterpret_cast<const COPYDATASTRUCT*>(lparam);
      if (payload == nullptr ||
          payload->dwData != kPokrovAcquisitionCopyData ||
          payload->lpData == nullptr || payload->cbData < sizeof(wchar_t) ||
          payload->cbData > 513 * sizeof(wchar_t) ||
          payload->cbData % sizeof(wchar_t) != 0) {
        break;
      }
      const auto* text = static_cast<const wchar_t*>(payload->lpData);
      const size_t count = payload->cbData / sizeof(wchar_t);
      if (text[count - 1] != L'\0') {
        break;
      }
      const std::wstring wide_uri(text, count - 1);
      pending_acquisition_uri_ = Utf8FromUtf16(wide_uri.c_str());
      if (acquisition_links_channel_) {
        acquisition_links_channel_->InvokeMethod(
            "uriChanged",
            std::make_unique<flutter::EncodableValue>(
                pending_acquisition_uri_));
      }
      return TRUE;
    }
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
