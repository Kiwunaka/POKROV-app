import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pokrov_runtime_engine/runtime_engine.dart';

import '../../../routing_catalog_contract.dart';
import 'transport_manifest_time.dart';

/// Process-local view of an admitted, persisted policy. It carries no lease.
/// Time sampling rechecks the captured session and uses the retained boot anchor.
class TransportManifestSelection {
  TransportManifestSelection._({required this.admission, required this.operationStarted,
    required this.operationBudget, required RuntimeBootClock clock, required TransportTimeAnchor anchor,
    required TransportTimeWindow now, required bool Function() isCurrent,
    required Future<void> Function() requireSession, required TransportClockDeadline deadline,
    required void Function() onClose})
      : _clock = clock, _anchor = anchor, _last = now, _isCurrent = isCurrent,
        _requireSession = requireSession, _deadline = deadline, _onClose = onClose {
    final remaining = deadline.expiresElapsedMs - now.sample.elapsedMilliseconds;
    final validity = admission.effectiveExpiresAt.difference(now.latest).inMilliseconds;
    _expiry = Timer(Duration(milliseconds: remaining < validity ? remaining : validity), close);
  }

  final TransportAdmission admission;
  final RuntimeBootClockSnapshot operationStarted;
  final Duration operationBudget;
  final RuntimeBootClock _clock;
  final TransportTimeAnchor _anchor;
  final bool Function() _isCurrent;
  final Future<void> Function() _requireSession;
  final TransportClockDeadline _deadline;
  final void Function() _onClose;
  final _ended = Completer<void>();
  Timer? _expiry;
  TransportTimeWindow _last;
  Future<void> _sampling = Future<void>.value();
  bool _closed = false;

  TransportClockDeadline get deadline => _deadline;
  Future<void> get whenClosed => _ended.future;

  void close() {
    if (_closed) return;
    _closed = true;
    _expiry?.cancel();
    _onClose();
    _ended.complete();
  }

  void requireCurrent() {
    if (_closed || !_isCurrent()) {
      close();
      throw const TransportManifestFailure('transport_selection_superseded');
    }
  }

  Future<TransportTimeWindow> sample() {
    final pending = _sampling.then((_) async {
      try {
        requireCurrent();
        await _requireSession();
        requireCurrent();
        final native = await _clock.readBootClock();
        requireCurrent();
        _deadline.requireCurrent(native);
        final window = _anchor.at(native);
        if (native.elapsedMilliseconds < _last.sample.elapsedMilliseconds ||
            window.latest.isBefore(_last.latest)) {
          throw const TransportManifestFailure('transport_clock_rollback');
        }
        if (!window.latest.isBefore(admission.effectiveExpiresAt)) {
          throw const TransportManifestFailure('transport_document_not_current');
        }
        _last = window;
        return window;
      } on Object {
        close();
        rethrow;
      }
    });
    _sampling = pending.then<void>((_) {}, onError: (Object _) {});
    return pending;
  }
}

/// Atomic secure record for public transport policy and its rollback floor.
/// Call only from the app isolate. This store never activates a transport.
class TransportManifestStore {
  TransportManifestStore({required this.verifier, required this.enabled, required this.clock,
      this.onCommitted, FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage();

  final TransportManifestVerifier verifier;
  final bool enabled;
  final FlutterSecureStorage _storage;
  final RuntimeBootClock clock;
  final Future<void> Function(TransportAdmission admission)? onCommitted;
  bool get available => enabled && verifier.configured;
  String get _key => 'pokrov-transport-manifest-${verifier.audience}-v1';
  static const _maximumRecordBytes = 3 * 1024 * 1024;
  static final Map<String, Future<void>> _queues = {};
  static final Map<String, int> _generations = {};
  static final Map<String, int> _selectionEpochs = {};
  static final Map<String, Set<TransportManifestSelection>> _selectionHandles = {};
  static final Set<String> _suspended = {};
  int get invalidationGeneration => _generations[_key] ?? 0;
  int get _selectionEpoch => _selectionEpochs[_key] ?? 0;

  void _invalidateSelections() {
    _selectionEpochs[_key] = _selectionEpoch + 1;
    for (final handle in (_selectionHandles[_key] ?? <TransportManifestSelection>{}).toList(growable: false)) {
      handle.close();
    }
  }

  Future<T> _serialize<T>(Future<T> Function() operation) {
    if (!available) return Future<T>.error(const TransportManifestFailure('transport_disabled'));
    final next = (_queues[_key] ?? Future<void>.value()).then((_) => operation());
    _queues[_key] = next.then<void>((_) {}, onError: (Object _) {});
    return next;
  }

  void _requireGeneration(int expected) {
    if (expected != invalidationGeneration) {
      throw const TransportManifestFailure('transport_admission_superseded');
    }
  }

  String _snapshot(Object? input) {
    try {
      final raw = jsonEncode(input);
      if (utf8.encode(raw).length > transportManifestMaximumBytes) {
        throw const TransportManifestFailure('transport_document_too_large');
      }
      return raw;
    } on TransportManifestFailure {
      rethrow;
    } on Object {
      throw const TransportManifestFailure('transport_document_invalid');
    }
  }

  Future<Map<String, dynamic>?> _load() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return null;
    try {
      if (raw.length > _maximumRecordBytes || utf8.encode(raw).length > _maximumRecordBytes) {
        throw const TransportManifestFailure('transport_cache_invalid');
      }
      final value = jsonDecode(raw);
      final fields = {'version', 'floor', 'manifest', 'rollback', 'last_observed_at',
        if (value is Map && value['version'] == 2) ...{'clock_anchor', 'last_elapsed_ms'}};
      if (value is! Map<String, dynamic> || value.length != fields.length ||
          !fields.containsAll(value.keys) || value['version'] is! int || !const {1, 2}.contains(value['version']) ||
          (value['manifest'] != null && value['manifest'] is! Map<String, dynamic>) ||
          (value['rollback'] != null && value['rollback'] is! Map<String, dynamic>) ||
          (value['manifest'] == null && value['rollback'] != null)) {
        throw const TransportManifestFailure('transport_cache_invalid');
      }
      final floor = verifier.validateFloor(value['floor']);
      final observed = value['last_observed_at'];
      final parsed = observed is String ? DateTime.tryParse(observed) : null;
      if (parsed == null || !parsed.isUtc || parsed.toIso8601String() != observed ||
          parsed.isBefore(DateTime.parse(floor['last_observed_at'] as String))) {
        throw const TransportManifestFailure('transport_cache_invalid');
      }
      if (value['version'] == 2) {
        final anchor = TransportTimeAnchor.fromRecord(value['clock_anchor']);
        final elapsed = value['last_elapsed_ms'];
        if (elapsed is! int || elapsed < anchor.receivedElapsedMs || elapsed > 9007199254740991 ||
            parsed.isBefore(anchor.latestAtReceipt)) {
          throw const TransportManifestFailure('transport_cache_invalid');
        }
      }
      return value;
    } on Object {
      // Never delete/reset an unreadable record, or infer first enrollment.
      throw const TransportManifestFailure('transport_cache_invalid');
    }
  }

  Future<void> _write(Map<String, dynamic> value) async {
    try {
      final raw = jsonEncode(value);
      if (utf8.encode(raw).length > _maximumRecordBytes) {
        throw const TransportManifestFailure('transport_cache_too_large');
      }
      await _storage.write(key: _key, value: raw);
    } on Object {
      // A storage error can have an uncertain commit outcome. No local reuse.
      _suspended.add(_key);
      _invalidateSelections();
      throw const TransportManifestFailure('transport_cache_write_failed');
    }
  }

  TransportTimeAnchor _anchor(Map<String, dynamic> value) {
    if (value['version'] != 2) throw const TransportManifestFailure('transport_clock_anchor_required');
    return TransportTimeAnchor.fromRecord(value['clock_anchor']);
  }

  Future<TransportTimeWindow> _window(TransportTimeAnchor anchor, Map<String, dynamic>? prior,
      {TransportClockDeadline? deadline}) async {
    final sample = await clock.readBootClock();
    deadline?.requireCurrent(sample);
    final window = anchor.at(sample);
    if (prior != null) {
      if (window.latest.isBefore(DateTime.parse(prior['last_observed_at'] as String)) ||
          (prior['version'] == 2 && _anchor(prior).bootRef == sample.bootRef &&
            sample.elapsedMilliseconds < (prior['last_elapsed_ms'] as int))) {
        throw const TransportManifestFailure('transport_clock_rollback');
      }
    }
    return window;
  }

  void _requireLive(TransportTimeWindow window, DateTime expires) {
    if (!window.latest.isBefore(expires)) throw const TransportManifestFailure('transport_document_not_current');
  }

  Future<TransportTimeWindow> _observe(Map<String, dynamic> value, {TransportClockDeadline? deadline}) async {
    final now = await _window(_anchor(value), value, deadline: deadline);
    value['last_observed_at'] = now.latest.toIso8601String();
    value['last_elapsed_ms'] = now.sample.elapsedMilliseconds;
    value['floor'] = {...verifier.validateFloor(value['floor']),
      'last_observed_at': now.latest.toIso8601String().split('.')[0] + 'Z'};
    // Persist observed expiry/clock before verification can reject stale policy.
    await _write(value);
    return now;
  }

  Future<TransportAdmission?> read({TransportClockDeadline? deadline}) => _serialize(() async {
    final generation = invalidationGeneration;
    final value = await _load();
    if (value == null) throw const TransportManifestFailure('transport_floor_missing');
    final now = await _observe(value, deadline: deadline);
    if (_suspended.contains(_key) || value['manifest'] == null) return null;
    try {
      final result = await verifier.admit(value['manifest'], rollback: value['rollback'],
        floor: value['floor'], now: now.latest, earliestNow: now.earliest);
      final floor = verifier.validateFloor(value['floor']);
      // A retained record is exactly the committed candidate, not a new update.
      for (final name in const ['epoch', 'revision', 'document_kind', 'payload_sha256']) {
        if (result.nextFloor[name] != floor[name]) {
          throw const TransportManifestFailure('transport_cache_binding_invalid');
        }
      }
      _requireGeneration(generation);
      _requireLive(await _observe(value, deadline: deadline), result.effectiveExpiresAt);
      _requireGeneration(generation);
      if (_suspended.contains(_key)) return null;
      return result;
    } on TransportManifestFailure {
      return null;
    }
  });

  Future<TransportAdmission> accept(Object? manifest, {Object? rollback,
      required int expectedGeneration, TransportTimeAnchor? onlineAnchor,
      TransportClockDeadline? deadline, bool Function()? operationIsCurrent}) => _accept(manifest, rollback,
        expectedGeneration: expectedGeneration, firstEnrollment: false,
        onlineAnchor: onlineAnchor, deadline: deadline, operationIsCurrent: operationIsCurrent);

  /// The admission must already have been committed by the normal loader.
  /// A concurrent update cannot substitute a different policy or clock anchor.
  Future<TransportManifestSelection> openSelection({required TransportAdmission admission,
      required int expectedGeneration, required RuntimeBootClockSnapshot operationStarted,
      required Duration operationBudget, required bool Function() operationIsCurrent,
      required Future<void> Function() requireSession}) => _serialize(() async {
    _requireGeneration(expectedGeneration);
    if (!operationIsCurrent()) throw const TransportManifestFailure('transport_selection_superseded');
    final value = await _load();
    _requireGeneration(expectedGeneration);
    if (_suspended.contains(_key) || value == null || value['manifest'] == null) {
      throw const TransportManifestFailure('transport_cache_unavailable');
    }
    final floor = verifier.validateFloor(value['floor']);
    for (final field in const ['epoch', 'revision', 'document_kind', 'payload_sha256']) {
      if (floor[field] != admission.nextFloor[field]) {
        throw const TransportManifestFailure('transport_selection_superseded');
      }
    }
    final kills = floor['kills'] as Map<String, Object?>;
    for (final field in const ['profile_refs', 'endpoint_refs', 'capability_refs']) {
      final stored = kills[field] as List;
      final admitted = admission.effectiveKills[field] as List;
      if (stored.length != admitted.length) throw const TransportManifestFailure('transport_cache_binding_invalid');
      for (var index = 0; index < stored.length; index++) {
        if (stored[index] != admitted[index]) throw const TransportManifestFailure('transport_cache_binding_invalid');
      }
    }
    final epoch = _selectionEpoch;
    final signedBudget = (admission.payload['budget'] as Map<String, Object?>)['total_deadline_ms'] as int;
    final deadline = TransportClockDeadline(operationStarted, Duration(milliseconds:
      operationBudget.inMilliseconds < signedBudget ? operationBudget.inMilliseconds : signedBudget));
    final now = await _observe(value, deadline: deadline);
    _requireLive(now, admission.effectiveExpiresAt);
    bool isCurrent() => available && operationIsCurrent() && !_suspended.contains(_key) &&
        expectedGeneration == invalidationGeneration && epoch == _selectionEpoch;
    late final TransportManifestSelection handle;
    handle = TransportManifestSelection._(admission: admission,
      operationStarted: operationStarted, operationBudget: operationBudget,
      clock: clock, anchor: _anchor(value), now: now, deadline: deadline,
      isCurrent: isCurrent, requireSession: requireSession, onClose: () {
        final handles = _selectionHandles[_key];
        handles?.remove(handle);
        if (handles != null && handles.isEmpty) _selectionHandles.remove(_key);
      });
    (_selectionHandles[_key] ??= {}).add(handle);
    // Do not yield a view after a session change during secure storage or clock IO.
    await handle.sample();
    return handle;
  });

  /// The loader must obtain onlineFloor/observedAt from its fresh authenticated
  /// nonce exchange. Storage absence or an imported response is not authority.
  /// Existing records are never reset, including corrupt or withdrawn records.
  Future<TransportAdmission> enroll(Object? manifest, {Object? rollback,
      required Object onlineFloor, required DateTime observedAt,
      required TransportTimeAnchor onlineAnchor,
      required int expectedGeneration, TransportClockDeadline? deadline,
      bool Function()? operationIsCurrent}) => _accept(manifest, rollback,
        expectedGeneration: expectedGeneration, firstEnrollment: true,
        onlineFloor: onlineFloor, observedAt: observedAt, onlineAnchor: onlineAnchor,
        deadline: deadline, operationIsCurrent: operationIsCurrent);

  Future<TransportAdmission> _accept(Object? manifest, Object? rollback,
      {required int expectedGeneration, required bool firstEnrollment,
      Object? onlineFloor, DateTime? observedAt, TransportTimeAnchor? onlineAnchor,
      TransportClockDeadline? deadline, bool Function()? operationIsCurrent}) {
    final rawManifest = _snapshot(manifest);
    final rawRollback = rollback == null ? null : _snapshot(rollback);
    final enrollmentFloor = firstEnrollment ? verifier.validateFloor(onlineFloor) : null;
    return _serialize(() async {
      void requireCurrent() {
        _requireGeneration(expectedGeneration);
        if (operationIsCurrent != null && !operationIsCurrent()) {
          throw const TransportManifestFailure('transport_admission_superseded');
        }
      }
      requireCurrent();
      final value = await _load();
      requireCurrent();
      if (firstEnrollment && value != null) {
        throw const TransportManifestFailure('transport_already_enrolled');
      }
      if (!firstEnrollment && value == null) {
        throw const TransportManifestFailure('transport_floor_missing');
      }
      final anchor = onlineAnchor ?? _anchor(value!);
      final now = onlineAnchor != null ? await _window(anchor, value, deadline: deadline)
          : await _observe(value!, deadline: deadline);
      requireCurrent();
      if (enrollmentFloor != null && (anchor.earliestAtReceipt != observedAt ||
          DateTime.parse(enrollmentFloor['last_observed_at'] as String).isAfter(observedAt!))) {
        throw const TransportManifestFailure('transport_bootstrap_time_invalid');
      }
      final result = await verifier.admit(jsonDecode(rawManifest),
        rollback: rawRollback == null ? null : jsonDecode(rawRollback),
        floor: value?['floor'] ?? enrollmentFloor, now: now.latest, earliestNow: now.earliest);
      if (enrollmentFloor != null) {
        for (final name in const ['epoch', 'revision', 'document_kind', 'payload_sha256']) {
          if (result.nextFloor[name] != enrollmentFloor[name]) {
            throw const TransportManifestFailure('transport_bootstrap_binding_invalid');
          }
        }
        final expectedKills = enrollmentFloor['kills'] as Map<String, Object?>;
        for (final name in const ['profile_refs', 'endpoint_refs', 'capability_refs']) {
          final expected = expectedKills[name] as List;
          final actual = result.effectiveKills[name] as List;
          if (expected.length != actual.length) {
            throw const TransportManifestFailure('transport_bootstrap_binding_invalid');
          }
          for (var index = 0; index < expected.length; index++) {
            if (expected[index] != actual[index]) {
              throw const TransportManifestFailure('transport_bootstrap_binding_invalid');
            }
          }
        }
      }
      final commitTime = await _window(anchor, value, deadline: deadline);
      if (commitTime.latest.isBefore(now.latest)) throw const TransportManifestFailure('transport_clock_rollback');
      _requireLive(commitTime, result.effectiveExpiresAt);
      requireCurrent();
      final committed = <String, dynamic>{
        'version': 2, 'manifest': result.manifest, 'rollback': result.rollback,
        'floor': {...result.nextFloor,
          'last_observed_at': commitTime.latest.toIso8601String().split('.')[0] + 'Z'},
        'last_observed_at': commitTime.latest.toIso8601String(),
        'clock_anchor': anchor.toRecord(), 'last_elapsed_ms': commitTime.sample.elapsedMilliseconds,
      };
      // Invalidate active selection views before a possibly uncertain write.
      // Time-only observations do not replace the policy/anchor and need no epoch.
      _invalidateSelections();
      await _write(committed);
      requireCurrent();
      _requireLive(await _window(anchor, committed, deadline: deadline), result.effectiveExpiresAt);
      requireCurrent();
      _suspended.remove(_key);
      if (onCommitted != null) await onCommitted!(result);
      return result;
    });
  }

  /// Denial invalidates pending responses immediately, then removes envelopes
  /// durably. Floors, kills and observed clock survive logout/disable/restart.
  Future<void> discardEnvelopes() {
    _invalidateSelections();
    _generations[_key] = invalidationGeneration + 1;
    _suspended.add(_key);
    return _serialize(() async {
      final value = await _load();
      if (value == null) throw const TransportManifestFailure('transport_floor_missing');
      // Withdrawal must remain durable even without a current clock/boot anchor.
      value['manifest'] = null;
      value['rollback'] = null;
      await _write(value);
    });
  }
}
