import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/app_shell.dart';

void main() {
  test('foreground refresh ownership is single-flight and resettable', () {
    final coordinator = DiagnosticsCoordinator();

    expect(coordinator.beginResumeRefresh(), isTrue);
    expect(coordinator.beginResumeRefresh(), isFalse);
    expect(coordinator.resumeRefreshPending, isTrue);
    coordinator.finishResumeRefresh();
    expect(coordinator.resumeRefreshPending, isFalse);
    expect(coordinator.beginResumeRefresh(), isTrue);
  });

  test('post-connect polling is bounded and releases its timer', () async {
    final coordinator = DiagnosticsCoordinator();
    final completed = Completer<void>();
    var polls = 0;

    coordinator.startHealthPolling(
      interval: const Duration(milliseconds: 1),
      pollCount: 2,
      canContinue: () => true,
      onPoll: (_) {
        polls += 1;
        if (polls == 2) {
          completed.complete();
        }
      },
    );

    await completed.future.timeout(const Duration(seconds: 1));
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(polls, 2);
    expect(coordinator.healthPollingActive, isFalse);
  });

  test('generation and in-flight fences reject stale diagnostic work', () {
    final coordinator = DiagnosticsCoordinator();
    final generation = coordinator.startHealthPolling(
      interval: const Duration(seconds: 1),
      pollCount: 0,
      canContinue: () => true,
      onPoll: (_) {},
    );

    expect(coordinator.beginHealthPoll(generation), isTrue);
    expect(coordinator.beginHealthPoll(generation), isFalse);
    coordinator.finishHealthPoll(generation);
    expect(coordinator.beginHealthPoll(generation), isTrue);

    coordinator.stopHealthPolling();
    expect(coordinator.isCurrentHealthGeneration(generation), isFalse);
    expect(coordinator.beginHealthPoll(generation), isFalse);
    coordinator.dispose();
  });
}
