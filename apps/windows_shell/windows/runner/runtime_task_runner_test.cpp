#include <windows.h>

#include <atomic>
#include <iostream>
#include <vector>

#include "runtime_task_runner.h"

int main() {
  using namespace pokrov::service;
  const auto owner = ::GetCurrentThreadId();
  const HANDLE ready = ::CreateEventW(nullptr, FALSE, FALSE, nullptr);
  std::atomic<bool> entered{false};
  std::vector<Command> operations;
  std::vector<Command> completed;
  std::atomic<bool> wrong_thread{false};
  std::mutex completed_lock;
  const auto completed_count = [&] {
    std::lock_guard<std::mutex> guard(completed_lock);
    return completed.size();
  };
  RuntimeTaskRunner runner([&] { ::SetEvent(ready); },
      [&](Command command, const std::string&, ServiceCallControl* control) {
        operations.push_back(command);
        if (command == Command::kConnect) {
          entered = true;
          const auto deadline = ::GetTickCount64() + 3000;
          while (!control->cancel_requested && ::GetTickCount64() < deadline) ::Sleep(1);
        }
        ServiceRuntimeSnapshot result;
        result.command_accepted = !control->cancel_requested;
        return result;
      });
  auto connect = std::make_shared<ServiceCallControl>();
  const auto start = ::GetTickCount64();
  if (!runner.Submit(Command::kConnect, "", connect, [&](auto) {
    if (::GetCurrentThreadId() != owner) wrong_thread = true;
    std::lock_guard<std::mutex> guard(completed_lock);
    completed.push_back(Command::kConnect);
  }) || ::GetTickCount64() - start > 500) return 1;
  while (!entered && ::GetTickCount64() - start < 1000) ::Sleep(1);
  // The owner thread is free to process a stop action while work is pending.
  if (!entered || completed_count() != 0) return 1;
  connect->cancel_requested = true;
  if (!runner.Submit(Command::kDisconnect, "", std::make_shared<ServiceCallControl>(), [&](auto) {
    if (::GetCurrentThreadId() != owner) wrong_thread = true;
    std::lock_guard<std::mutex> guard(completed_lock);
    completed.push_back(Command::kDisconnect);
  })) return 1;
  const auto deadline = ::GetTickCount64() + 3000;
  while (completed_count() < 2 && ::GetTickCount64() < deadline) {
    ::WaitForSingleObject(ready, 50);
    runner.Drain();
  }
  runner.Shutdown();
  ::CloseHandle(ready);
  const std::vector<Command> expected{Command::kConnect, Command::kDisconnect};
  if (wrong_thread || completed != expected || operations != expected) {
    std::cerr << "worker blocked the owner, reordered runtime work or completed on the wrong thread\n";
    return 1;
  }
  return 0;
}
