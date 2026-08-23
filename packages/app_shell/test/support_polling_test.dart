import 'dart:async';
import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/app_shell.dart';

void main() {
  test('policy applies bounded jitter and exponential failure backoff', () {
    const policy = SupportPollingPolicy();

    expect(policy.delayAfterFailures(0, 0), const Duration(seconds: 10));
    expect(policy.delayAfterFailures(0, 1), const Duration(seconds: 12));
    expect(policy.delayAfterFailures(1, 0.5), const Duration(seconds: 21));
    expect(policy.delayAfterFailures(2, 0.5), const Duration(seconds: 41));
    expect(policy.delayAfterFailures(8, 1), const Duration(minutes: 2));
    expect(
        policy.delayAfterFailures(0, double.nan), const Duration(seconds: 10));
  });

  test('coordinator backs off on failure and resets after success', () async {
    final timers = _FakeTimerFactory();
    final results = Queue<bool>.of(<bool>[false, false, true]);
    var calls = 0;
    final coordinator = SupportPollingCoordinator(
      onPoll: () async {
        calls += 1;
        return results.removeFirst();
      },
      timerFactory: timers.schedule,
      jitterSource: () => 0.5,
    );
    addTearDown(coordinator.dispose);

    coordinator.configure(eligible: true, foreground: true);
    expect(timers.latest.delay, const Duration(seconds: 11));

    timers.latest.fire();
    await pumpEventQueue();
    expect(calls, 1);
    expect(coordinator.consecutiveFailures, 1);
    expect(timers.latest.delay, const Duration(seconds: 21));

    timers.latest.fire();
    await pumpEventQueue();
    expect(calls, 2);
    expect(coordinator.consecutiveFailures, 2);
    expect(timers.latest.delay, const Duration(seconds: 41));

    timers.latest.fire();
    await pumpEventQueue();
    expect(calls, 3);
    expect(coordinator.consecutiveFailures, 0);
    expect(timers.latest.delay, const Duration(seconds: 11));
  });

  test('background, ineligible state and dispose cancel pending polls',
      () async {
    final timers = _FakeTimerFactory();
    var calls = 0;
    final coordinator = SupportPollingCoordinator(
      onPoll: () async {
        calls += 1;
        return true;
      },
      timerFactory: timers.schedule,
      jitterSource: () => 0,
    );

    coordinator.configure(eligible: true, foreground: true);
    final foregroundTimer = timers.latest;
    expect(foregroundTimer.isActive, isTrue);

    coordinator.configure(eligible: true, foreground: false);
    expect(foregroundTimer.isActive, isFalse);
    foregroundTimer.fire();
    await pumpEventQueue();
    expect(calls, 0);
    expect(coordinator.isScheduled, isFalse);

    coordinator.configure(eligible: true, foreground: true);
    expect(timers.latest.isActive, isTrue);
    coordinator.configure(eligible: false, foreground: true);
    expect(timers.latest.isActive, isFalse);

    coordinator.configure(eligible: true, foreground: true);
    final beforeDispose = timers.latest;
    coordinator.dispose();
    expect(beforeDispose.isActive, isFalse);
    coordinator.configure(eligible: true, foreground: true);
    expect(coordinator.isScheduled, isFalse);
  });

  test('manual failure feeds the same backoff policy', () {
    final timers = _FakeTimerFactory();
    final coordinator = SupportPollingCoordinator(
      onPoll: () async => true,
      timerFactory: timers.schedule,
      jitterSource: () => 0,
    );
    addTearDown(coordinator.dispose);

    coordinator.configure(eligible: true, foreground: true);
    coordinator.recordExternalResult(success: false);
    expect(coordinator.consecutiveFailures, 1);
    expect(timers.latest.delay, const Duration(seconds: 20));

    coordinator.recordExternalResult(success: true);
    expect(coordinator.consecutiveFailures, 0);
    expect(timers.latest.delay, const Duration(seconds: 10));
  });
}

final class _FakeTimerFactory {
  final List<_FakeTimer> timers = <_FakeTimer>[];

  _FakeTimer get latest => timers.last;

  Timer schedule(Duration delay, void Function() callback) {
    final timer = _FakeTimer(delay, callback);
    timers.add(timer);
    return timer;
  }
}

final class _FakeTimer implements Timer {
  _FakeTimer(this.delay, this._callback);

  final Duration delay;
  final void Function() _callback;
  bool _active = true;

  @override
  bool get isActive => _active;

  @override
  int get tick => _active ? 0 : 1;

  @override
  void cancel() {
    _active = false;
  }

  void fire() {
    if (!_active) {
      return;
    }
    _active = false;
    _callback();
  }
}
