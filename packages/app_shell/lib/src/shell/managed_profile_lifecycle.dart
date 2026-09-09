import 'dart:async';

import 'package:pokrov_runtime_engine/runtime_engine.dart';

/// Owns local profile-input revision and the bounded host invalidation lifecycle.
/// This counter is not the revision assigned by the server.
class ManagedProfileLifecycle {
  ManagedProfileLifecycle({
    required this.invalidateProfile,
    required this.invalidateOnHost,
    required this.timeout,
    required this.onInvalidated,
  });

  final Future<RuntimeSnapshot> Function() invalidateProfile;
  final bool Function() invalidateOnHost;
  final Duration Function() timeout;
  final void Function(RuntimeSnapshot) onInvalidated;
  bool dirty = true;
  int _revision = 0;
  int get revision => _revision;
  int _requestedRevision = 0;
  int _completedRevision = 0;
  Future<bool>? _inFlight;
  int _generation = 0;
  Timer? _timer;
  Completer<bool>? _completion;
  bool _disposed = false;

  void invalidate() {
    _revision += 1;
    if (_disposed || !invalidateOnHost()) {
      return;
    }
    _requestedRevision = _revision;
    _inFlight ??= _drainInvalidations();
  }

  Future<bool> waitForInvalidation(int revision) async {
    if (_disposed || !invalidateOnHost()) {
      return true;
    }
    while (_completedRevision < revision) {
      final pending = _inFlight ??= _drainInvalidations();
      if (!await pending) {
        return false;
      }
    }
    return true;
  }

  Future<bool> _drainInvalidations() async {
    try {
      // Snapshot the desired revision for each host call. All edits that land
      // while it is running collapse into one follow-up call for the latest
      // revision instead of building an unbounded timeout queue.
      while (!_disposed) {
        final targetRevision = _requestedRevision;
        final invalidated = await _runInvalidation();
        if (!invalidated) {
          return false;
        }
        _completedRevision = targetRevision;
        if (_requestedRevision <= targetRevision) {
          return true;
        }
      }
      return false;
    } finally {
      _inFlight = null;
    }
  }

  Future<bool> _runInvalidation() {
    if (_disposed) {
      return Future<bool>.value(false);
    }
    final generation = ++_generation;
    final completion = Completer<bool>();
    _completion = completion;
    final timer = Timer(timeout(), () {
      if (_disposed || generation != _generation || completion.isCompleted) {
        return;
      }
      _timer = null;
      completion.complete(false);
      if (identical(_completion, completion)) {
        _completion = null;
      }
    });
    _timer = timer;

    void complete(bool invalidated, [RuntimeSnapshot? snapshot]) {
      if (_disposed || generation != _generation || completion.isCompleted) {
        return;
      }
      timer.cancel();
      if (identical(_timer, timer)) {
        _timer = null;
      }
      if (identical(_completion, completion)) {
        _completion = null;
      }
      if (invalidated && snapshot != null) onInvalidated(snapshot);
      completion.complete(invalidated);
    }

    unawaited(
      invalidateProfile()
          .then((snapshot) => complete(true, snapshot))
          .catchError((Object _) => complete(false)),
    );
    return completion.future;
  }

  void dispose() {
    _disposed = true;
    _generation += 1;
    _timer?.cancel();
    _timer = null;
    final pending = _completion;
    if (pending != null && !pending.isCompleted) pending.complete(false);
    _completion = null;
  }
}
