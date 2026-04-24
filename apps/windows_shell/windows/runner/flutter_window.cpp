#include "flutter_window.h"

#include <flutter/method_call.h>
#include <flutter/method_result_functions.h>
#include <flutter/standard_method_codec.h>
#include <shellapi.h>
#include <optional>
#include <string>

#include "flutter/generated_plugin_registrant.h"

namespace {
constexpr char kExternalLinkChannelName[] = "space.pokrov/external_link";
constexpr char kOpenExternalMethod[] = "openExternal";

bool StartsWith(const std::string& value, const std::string& prefix) {
  return value.rfind(prefix, 0) == 0;
}

bool IsAllowedExternalTarget(const std::string& target) {
  return StartsWith(target, "https://") || StartsWith(target, "http://") ||
         StartsWith(target, "tg://") || StartsWith(target, "mailto:");
}

std::string ExtractTarget(const flutter::EncodableValue* arguments) {
  if (!arguments) {
    return "";
  }

  const auto* map = std::get_if<flutter::EncodableMap>(arguments);
  if (!map) {
    return "";
  }

  auto it = map->find(flutter::EncodableValue("target"));
  if (it == map->end()) {
    return "";
  }

  const auto* target = std::get_if<std::string>(&it->second);
  return target ? *target : "";
}

std::wstring Utf8ToWide(const std::string& value) {
  if (value.empty()) {
    return L"";
  }

  const int size = MultiByteToWideChar(
      CP_UTF8, MB_ERR_INVALID_CHARS, value.data(),
      static_cast<int>(value.size()), nullptr, 0);
  if (size <= 0) {
    return L"";
  }

  std::wstring wide(size, L'\0');
  MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, value.data(),
                      static_cast<int>(value.size()), wide.data(), size);
  return wide;
}
}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

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
  external_link_channel_ = std::make_unique<
      flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), kExternalLinkChannelName,
      &flutter::StandardMethodCodec::GetInstance());
  external_link_channel_->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
             result) {
        if (call.method_name() != kOpenExternalMethod) {
          result->NotImplemented();
          return;
        }

        const std::string target = ExtractTarget(call.arguments());
        if (!IsAllowedExternalTarget(target)) {
          result->Success(flutter::EncodableValue(false));
          return;
        }

        const std::wstring wide_target = Utf8ToWide(target);
        if (wide_target.empty()) {
          result->Success(flutter::EncodableValue(false));
          return;
        }

        HINSTANCE launched =
            ShellExecuteW(nullptr, L"open", wide_target.c_str(), nullptr,
                          nullptr, SW_SHOWNORMAL);
        result->Success(flutter::EncodableValue(
            reinterpret_cast<intptr_t>(launched) > 32));
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
  if (external_link_channel_) {
    external_link_channel_->SetMethodCallHandler(nullptr);
    external_link_channel_ = nullptr;
  }

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
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
