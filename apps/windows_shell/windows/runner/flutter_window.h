#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>

#include <memory>

#include "win32_window.h"
#include "runtime_task_runner.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project,
                         std::string initial_acquisition_uri = "",
                         bool start_hidden = false);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  bool QueueRuntime(pokrov::service::Command command, std::string body,
                    RuntimeTaskRunner::Completion completion);
  std::unique_ptr<RuntimeTaskRunner> runtime_tasks_;
  std::shared_ptr<pokrov::service::ServiceCallControl> pending_connect_;
  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      acquisition_links_channel_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      windows_shell_channel_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      runtime_engine_channel_;
  std::string pending_acquisition_uri_;
  std::string expected_profile_digest_;
  bool start_hidden_;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
