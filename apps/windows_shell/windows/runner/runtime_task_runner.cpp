#include "runtime_task_runner.h"

RuntimeTaskRunner::RuntimeTaskRunner(std::function<void()> notify, Invoke invoke)
    : notify_(std::move(notify)), invoke_(std::move(invoke)),
      worker_([this] { Work(); }) {}

RuntimeTaskRunner::~RuntimeTaskRunner() { Shutdown(); }

bool RuntimeTaskRunner::Submit(pokrov::service::Command command, std::string body,
                              std::shared_ptr<Control> control, Completion completion) {
  std::lock_guard<std::mutex> guard(lock_);
  if (stopping_ || tasks_.size() >= 16 || control == nullptr) return false;
  tasks_.push_back({command, std::move(body), std::move(control), std::move(completion)});
  ready_.notify_one();
  return true;
}

void RuntimeTaskRunner::Work() {
  for (;;) {
    Task task;
    {
      std::unique_lock<std::mutex> guard(lock_);
      ready_.wait(guard, [&] { return stopping_ || !tasks_.empty(); });
      if (stopping_) return;
      task = std::move(tasks_.front());
      tasks_.pop_front();
      running_ = task.control;
    }
    Snapshot snapshot;
    try {
      snapshot = invoke_(task.command, task.body, task.control.get());
    } catch (...) {
      snapshot.failure = "runtime_failure";
    }
    {
      std::lock_guard<std::mutex> guard(lock_);
      running_.reset();
      completions_.push_back([completion = std::move(task.completion),
                              snapshot = std::move(snapshot)]() mutable {
        completion(std::move(snapshot));
      });
    }
    notify_();
  }
}

void RuntimeTaskRunner::Drain() {
  std::deque<std::function<void()>> completions;
  {
    std::lock_guard<std::mutex> guard(lock_);
    if (stopping_) return;
    completions.swap(completions_);
  }
  for (auto& completion : completions) completion();
}

void RuntimeTaskRunner::Shutdown() {
  {
    std::lock_guard<std::mutex> guard(lock_);
    stopping_ = true;
    if (running_) {
      running_->cancel_requested = true;
      running_->abandon_wait = true;
    }
    tasks_.clear();
    ready_.notify_one();
  }
  if (worker_.joinable()) worker_.join();
  // Flutter callbacks are discarded on the owner thread before engine teardown.
  completions_.clear();
}
