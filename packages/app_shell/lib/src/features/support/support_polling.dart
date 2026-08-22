import 'dart:async';
import 'dart:math';

typedef SupportPollingTimerFactory = Timer Function(
  Duration delay,
  void Function() callback,
);

typedef SupportPollingJitterSource = double Function();

final class SupportPollingPolicy {
  const SupportPollingPolicy({
    this.baseInterval = const Duration(seconds: 10),
    this.maximumInterval = const Duration(minutes: 2),
    this.maximumJitter = const Duration(seconds: 2),
  });

  final Duration baseInterval;
  final Duration maximumInterval;
  final Duration maximumJitter;

  Duration delayAfterFailures(int consecutiveFailures, double jitterUnit) {
    final failures = consecutiveFailures.clamp(0, 8);
    final exponentialMicros = baseInterval.inMicroseconds * (1 << failures);
    final boundedJitter = jitterUnit.isNaN
        ? 0.0
        : jitterUnit < 0
            ? 0.0
            : jitterUnit > 1
                ? 1.0
                : jitterUnit;
    final jitterMicros = (maximumJitter.inMicroseconds * boundedJitter).round();
    final delayMicros = (exponentialMicros + jitterMicros).clamp(
      baseInterval.inMicroseconds,
      maximumInterval.inMicroseconds,
    );
    return Duration(microseconds: delayMicros);
  }
}

final class SupportPollingCoordinator {
  SupportPollingCoordinator({
    required Future<bool> Function() onPoll,
    SupportPollingPolicy policy = const SupportPollingPolicy(),
    SupportPollingTimerFactory? timerFactory,
    SupportPollingJitterSource? jitterSource,
  })  : _onPoll = onPoll,
        _policy = policy,
        _timerFactory = timerFactory ?? _defaultTimerFactory,
        _jitterSource = jitterSource ?? _randomJitter;

  final Future<bool> Function() _onPoll;
  final SupportPollingPolicy _policy;
  final SupportPollingTimerFactory _timerFactory;
  final SupportPollingJitterSource _jitterSource;

  Timer? _timer;
  bool _eligible = false;
  bool _foreground = true;
  bool _inFlight = false;
  bool _disposed = false;
  int _consecutiveFailures = 0;

  bool get isScheduled => _timer?.isActive ?? false;
  bool get isForeground => _foreground;
  int get consecutiveFailures => _consecutiveFailures;

  void configure({required bool eligible, required bool foreground}) {
    if (_disposed) {
      return;
    }
    final changed = _eligible != eligible || _foreground != foreground;
    _eligible = eligible;
    _foreground = foreground;
    if (!_canPoll) {
      _cancelTimer();
      return;
    }
    if (changed || !isScheduled) {
      _schedule();
    }
  }

  void recordExternalResult({required bool success}) {
    if (_disposed) {
      return;
    }
    _record(success);
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
    final delay = _policy.delayAfterFailures(
      _consecutiveFailures,
      _jitterSource(),
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
    var success = false;
    try {
      success = await _onPoll();
    } on Object {
      success = false;
    } finally {
      _inFlight = false;
    }
    if (_disposed) {
      return;
    }
    _record(success);
    _schedule();
  }

  void _record(bool success) {
    if (success) {
      _consecutiveFailures = 0;
      return;
    }
    _consecutiveFailures = (_consecutiveFailures + 1).clamp(0, 8);
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
