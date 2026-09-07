#ifndef POKROV_RUNNER_RUNTIME_TASK_RUNNER_H_
#define POKROV_RUNNER_RUNTIME_TASK_RUNNER_H_

#include <condition_variable>
#include <deque>
#include <functional>
#include <memory>
#include <mutex>
#include <thread>

#include "service_client.h"

// One UI-side worker preserves method order while the window thread continues
// pumping Flutter and cancellation input. Completions run only through Drain.
class RuntimeTaskRunner {
 public:
  using Snapshot = pokrov::service::ServiceRuntimeSnapshot;
  using Control = pokrov::service::ServiceCallControl;
  using Completion = std::function<void(Snapshot)>;
  using Invoke = std::function<Snapshot(pokrov::service::Command, const std::string&, Control*)>;
  explicit RuntimeTaskRunner(std::function<void()> notify,
      Invoke invoke = pokrov::service::InvokeInstalledService);
  ~RuntimeTaskRunner();
  bool Submit(pokrov::service::Command command, std::string body,
              std::shared_ptr<Control> control, Completion completion);
  void Drain();
  void Shutdown();

 private:
  struct Task {
    pokrov::service::Command command;
    std::string body;
    std::shared_ptr<Control> control;
    Completion completion;
  };
  void Work();
  std::function<void()> notify_;
  Invoke invoke_;
  std::mutex lock_;
  std::condition_variable ready_;
  std::deque<Task> tasks_;
  std::deque<std::function<void()>> completions_;
  std::shared_ptr<Control> running_;
  bool stopping_ = false;
  std::thread worker_;
};
#endif
