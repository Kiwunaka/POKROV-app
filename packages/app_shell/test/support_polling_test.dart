import 'dart:async';
import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/app_shell.dart';

void main() {
  test('policy bounds active, quiet and failure delays', () {
    const policy = SupportPollingPolicy();

    expect(
      policy.nextDelay(
        consecutiveFailures: 0,
        unchangedFor: Duration.zero,
        jitterUnit: 0,
      ),
      const Duration(seconds: 8),
    );
    expect(
      policy.nextDelay(
        consecutiveFailures: 0,
        unchangedFor: Duration.zero,
        jitterUnit: 1,
      ),
      const Duration(seconds: 10),
    );
    expect(
      policy.nextDelay(
        consecutiveFailures: 0,
        unchangedFor: const Duration(minutes: 1),
        jitterUnit: 0,
      ),
      const Duration(seconds: 15),
    );
    expect(
      policy.nextDelay(
        consecutiveFailures: 0,
        unchangedFor: const Duration(minutes: 1),
        jitterUnit: 1,
      ),
      const Duration(seconds: 30),
    );
    expect(
      policy.nextDelay(
        consecutiveFailures: 1,
        unchangedFor: const Duration(minutes: 5),
        jitterUnit: 0.5,
      ),
      const Duration(seconds: 17),
    );
    expect(
      policy.nextDelay(
        consecutiveFailures: 8,
        unchangedFor: Duration.zero,
        jitterUnit: 1,
      ),
      const Duration(minutes: 2),
    );
    expect(
      policy.nextDelay(
        consecutiveFailures: 0,
        unchangedFor: Duration.zero,
        jitterUnit: double.nan,
      ),
      const Duration(seconds: 8),
    );
  });

  test('coordinator backs off on failure and resets after success', () async {
    final timers = _FakeTimerFactory();
    final results = Queue<SupportPollingResult>.of(<SupportPollingResult>[
      SupportPollingResult.failed,
      SupportPollingResult.failed,
      SupportPollingResult.changed,
    ]);
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
    expect(timers.latest.delay, const Duration(seconds: 9));

    timers.latest.fire();
    await pumpEventQueue();
    expect(calls, 1);
    expect(coordinator.consecutiveFailures, 1);
    expect(timers.latest.delay, const Duration(seconds: 17));

    timers.latest.fire();
    await pumpEventQueue();
    expect(calls, 2);
    expect(coordinator.consecutiveFailures, 2);
    expect(timers.latest.delay, const Duration(seconds: 33));

    timers.latest.fire();
    await pumpEventQueue();
    expect(calls, 3);
    expect(coordinator.consecutiveFailures, 0);
    expect(timers.latest.delay, const Duration(seconds: 9));
  });

  test(
      'unchanged thread slows after one minute and change restores active pace',
      () async {
    final timers = _FakeTimerFactory();
    final results = Queue<SupportPollingResult>.of(<SupportPollingResult>[
      SupportPollingResult.unchanged,
      SupportPollingResult.unchanged,
      SupportPollingResult.changed,
    ]);
    var now = DateTime.utc(2026, 8, 27, 12);
    final coordinator = SupportPollingCoordinator(
      onPoll: () async => results.removeFirst(),
      timerFactory: timers.schedule,
      jitterSource: () => 0.5,
      clock: () => now,
    );
    addTearDown(coordinator.dispose);

    coordinator.configure(eligible: true, foreground: true);
    expect(timers.latest.delay, const Duration(seconds: 9));

    timers.latest.fire();
    await pumpEventQueue();
    expect(timers.latest.delay, const Duration(seconds: 9));

    now = now.add(const Duration(seconds: 61));
    timers.latest.fire();
    await pumpEventQueue();
    expect(timers.latest.delay, const Duration(milliseconds: 22500));

    timers.latest.fire();
    await pumpEventQueue();
    expect(timers.latest.delay, const Duration(seconds: 9));
  });

  test('background, ineligible state and dispose cancel pending polls',
      () async {
    final timers = _FakeTimerFactory();
    var calls = 0;
    final coordinator = SupportPollingCoordinator(
      onPoll: () async {
        calls += 1;
        return SupportPollingResult.changed;
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
    await pumpEventQueue();
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

  test('foreground resume refreshes immediately before scheduling', () async {
    final timers = _FakeTimerFactory();
    var calls = 0;
    final coordinator = SupportPollingCoordinator(
      onPoll: () async {
        calls += 1;
        return SupportPollingResult.unchanged;
      },
      timerFactory: timers.schedule,
      jitterSource: () => 0,
    );
    addTearDown(coordinator.dispose);

    coordinator.configure(eligible: true, foreground: true);
    final initialTimer = timers.latest;
    coordinator.configure(eligible: true, foreground: false);
    expect(initialTimer.isActive, isFalse);

    coordinator.configure(eligible: true, foreground: true);
    await pumpEventQueue();

    expect(calls, 1);
    expect(timers.latest.delay, const Duration(seconds: 8));
    expect(timers.latest.isActive, isTrue);
  });

  test('manual failure feeds the same backoff policy', () {
    final timers = _FakeTimerFactory();
    final coordinator = SupportPollingCoordinator(
      onPoll: () async => SupportPollingResult.changed,
      timerFactory: timers.schedule,
      jitterSource: () => 0,
    );
    addTearDown(coordinator.dispose);

    coordinator.configure(eligible: true, foreground: true);
    coordinator.recordExternalResult(result: SupportPollingResult.failed);
    expect(coordinator.consecutiveFailures, 1);
    expect(timers.latest.delay, const Duration(seconds: 16));

    coordinator.recordExternalResult(result: SupportPollingResult.changed);
    expect(coordinator.consecutiveFailures, 0);
    expect(timers.latest.delay, const Duration(seconds: 8));
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
