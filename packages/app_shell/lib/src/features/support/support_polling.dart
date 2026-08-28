import 'dart:async';
import 'dart:math';

typedef SupportPollingTimerFactory = Timer Function(
  Duration delay,
  void Function() callback,
);

typedef SupportPollingJitterSource = double Function();
typedef SupportPollingClock = DateTime Function();

enum SupportPollingResult {
  changed,
  unchanged,
  failed,
}

final class SupportPollingPolicy {
  const SupportPollingPolicy({
    this.activeInterval = const Duration(seconds: 8),
    this.activeMaximumJitter = const Duration(seconds: 2),
    this.quietAfter = const Duration(minutes: 1),
    this.quietInterval = const Duration(seconds: 15),
    this.quietMaximumJitter = const Duration(seconds: 15),
    this.failureMaximumInterval = const Duration(minutes: 2),
  });

  final Duration activeInterval;
  final Duration activeMaximumJitter;
  final Duration quietAfter;
  final Duration quietInterval;
  final Duration quietMaximumJitter;
  final Duration failureMaximumInterval;

  Duration nextDelay({
    required int consecutiveFailures,
    required Duration unchangedFor,
    required double jitterUnit,
  }) {
    final failures = consecutiveFailures.clamp(0, 8);
    final boundedJitter = jitterUnit.isNaN
        ? 0.0
        : jitterUnit < 0
            ? 0.0
            : jitterUnit > 1
                ? 1.0
                : jitterUnit;

    if (failures == 0 && unchangedFor >= quietAfter) {
      final quietJitterMicros =
          (quietMaximumJitter.inMicroseconds * boundedJitter).round();
      return Duration(
        microseconds: quietInterval.inMicroseconds + quietJitterMicros,
      );
    }

    final exponentialMicros = activeInterval.inMicroseconds * (1 << failures);
    final activeJitterMicros =
        (activeMaximumJitter.inMicroseconds * boundedJitter).round();
    final delayMicros = (exponentialMicros + activeJitterMicros).clamp(
      activeInterval.inMicroseconds,
      failureMaximumInterval.inMicroseconds,
    );
    return Duration(microseconds: delayMicros);
  }
}

final class SupportPollingCoordinator {
  SupportPollingCoordinator({
    required Future<SupportPollingResult> Function() onPoll,
    SupportPollingPolicy policy = const SupportPollingPolicy(),
    SupportPollingTimerFactory? timerFactory,
    SupportPollingJitterSource? jitterSource,
    SupportPollingClock? clock,
  })  : _onPoll = onPoll,
        _policy = policy,
        _timerFactory = timerFactory ?? _defaultTimerFactory,
        _jitterSource = jitterSource ?? _randomJitter,
        _clock = clock ?? DateTime.now;

  final Future<SupportPollingResult> Function() _onPoll;
  final SupportPollingPolicy _policy;
  final SupportPollingTimerFactory _timerFactory;
  final SupportPollingJitterSource _jitterSource;
  final SupportPollingClock _clock;

  Timer? _timer;
  bool _eligible = false;
  bool _foreground = true;
  bool _inFlight = false;
  bool _disposed = false;
  int _consecutiveFailures = 0;
  DateTime? _unchangedSince;

  bool get isScheduled => _timer?.isActive ?? false;
  bool get isForeground => _foreground;
  int get consecutiveFailures => _consecutiveFailures;

  void configure({required bool eligible, required bool foreground}) {
    if (_disposed) {
      return;
    }
    final resumed = !_foreground && foreground;
    final changed = _eligible != eligible || _foreground != foreground;
    _eligible = eligible;
    _foreground = foreground;
    if (!_canPoll) {
      _cancelTimer();
      return;
    }
    if (resumed) {
      _cancelTimer();
      unawaited(_pollOnce());
      return;
    }
    if (changed || !isScheduled) {
      _schedule();
    }
  }

  void recordExternalResult({required SupportPollingResult result}) {
    if (_disposed) {
      return;
    }
    _record(result);
    _schedule();
  }

  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _eligible = false;
    _cancelTimer();
  }

  bool get _canPoll => !_disposed && _eligible && _foreground && !_inFlight;

  void _schedule() {
    _cancelTimer();
    if (!_canPoll) {
      return;
    }
    final delay = _policy.nextDelay(
      consecutiveFailures: _consecutiveFailures,
      unchangedFor: _unchangedFor,
      jitterUnit: _jitterSource(),
    );
    _timer = _timerFactory(delay, () {
      _timer = null;
      if (_canPoll) {
        unawaited(_pollOnce());
      }
    });
  }

  Future<void> _pollOnce() async {
    if (!_canPoll) {
      return;
    }
    _inFlight = true;
    var result = SupportPollingResult.failed;
    try {
      result = await _onPoll();
    } on Object {
      result = SupportPollingResult.failed;
    } finally {
      _inFlight = false;
    }
    if (_disposed) {
      return;
    }
    _record(result);
    _schedule();
  }

  Duration get _unchangedFor {
    final since = _unchangedSince;
    if (since == null) {
      return Duration.zero;
    }
    final elapsed = _clock().difference(since);
    return elapsed.isNegative ? Duration.zero : elapsed;
  }

  void _record(SupportPollingResult result) {
    switch (result) {
      case SupportPollingResult.changed:
        _consecutiveFailures = 0;
        _unchangedSince = null;
      case SupportPollingResult.unchanged:
        _consecutiveFailures = 0;
        _unchangedSince ??= _clock();
      case SupportPollingResult.failed:
        _consecutiveFailures = (_consecutiveFailures + 1).clamp(0, 8);
    }
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  static Timer _defaultTimerFactory(
    Duration delay,
    void Function() callback,
  ) =>
      Timer(delay, callback);

  static final Random _random = Random();

  static double _randomJitter() => _random.nextDouble();
}
