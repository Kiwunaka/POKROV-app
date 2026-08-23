import 'dart:convert';
import 'dart:io';

import 'package:pokrov_observability_contracts/observability_contracts.dart';

import 'privacy.dart';
import 'queue.dart';

enum PreviousExitKind { none, clean, unclean, crash, corrupt }

final class PreviousExitReport {
  PreviousExitReport({
    required this.kind,
    required this.runId,
    required this.occurredAtUtc,
    required this.errorCode,
    required this.crashSignature,
    required List<OperationalBreadcrumb> breadcrumbs,
  }) : breadcrumbs = List.unmodifiable(breadcrumbs);

  const PreviousExitReport.none()
      : kind = PreviousExitKind.none,
        runId = '',
        occurredAtUtc = null,
        errorCode = null,
        crashSignature = null,
        breadcrumbs = const <OperationalBreadcrumb>[];

  final PreviousExitKind kind;
  final String runId;
  final DateTime? occurredAtUtc;
  final String? errorCode;
  final String? crashSignature;
  final List<OperationalBreadcrumb> breadcrumbs;

  // Previous-exit evidence is diagnostic only. Runtime state must be read from
  // the host/service and its recovery journal.
  bool get isRuntimeAuthority => false;
}

final class PreviousExitMarkerStore {
  PreviousExitMarkerStore({
    required this.file,
    this.maximumBreadcrumbs = 32,
    DateTime Function()? clock,
  }) : clock = clock ?? (() => DateTime.now().toUtc()) {
    if (maximumBreadcrumbs < 1 || maximumBreadcrumbs > 128) {
      throw ArgumentError.value(maximumBreadcrumbs, 'maximumBreadcrumbs');
    }
  }

  final File file;
  final int maximumBreadcrumbs;
  final DateTime Function() clock;
  String? _activeRunId;
  bool _crashMarked = false;

  Future<PreviousExitReport> beginRun(String runId) async {
    _validateUuid(runId, 'runId');
    final previous = await readPrevious();
    _activeRunId = runId;
    _crashMarked = false;
    await _write(<String, Object?>{
      'schema_version': 1,
      'state': 'active',
      'run_id': runId,
      'occurred_at_utc': _formatUtc(clock()),
      'error_code': null,
      'crash_signature': null,
      'breadcrumbs': const <Object?>[],
    });
    return previous;
  }

  Future<void> markCleanExit({
    List<OperationalBreadcrumb> breadcrumbs = const <OperationalBreadcrumb>[],
  }) async {
    final runId = _activeRunId;
    if (runId == null || _crashMarked) {
      return;
    }
    await _writeMarker(
      state: 'clean',
      runId: runId,
      breadcrumbs: breadcrumbs,
    );
  }

  Future<void> markCrash({
    required String errorCode,
    required String crashSignature,
    List<OperationalBreadcrumb> breadcrumbs = const <OperationalBreadcrumb>[],
  }) async {
    final runId = _activeRunId;
    if (runId == null) {
      return;
    }
    if (!const <String>{'CRASH-001', 'CRASH-002', 'CRASH-003'}
        .contains(errorCode)) {
      throw ArgumentError.value(errorCode, 'errorCode');
    }
    if (!RegExp(r'^[0-9a-f]{16,64}$').hasMatch(crashSignature)) {
      throw ArgumentError.value(crashSignature, 'crashSignature');
    }
    _crashMarked = true;
    await _writeMarker(
      state: 'crash',
      runId: runId,
      errorCode: errorCode,
      crashSignature: crashSignature,
      breadcrumbs: breadcrumbs,
    );
  }

  void markCrashSynchronously({
    required String errorCode,
    required String crashSignature,
    List<OperationalBreadcrumb> breadcrumbs = const <OperationalBreadcrumb>[],
  }) {
    final runId = _activeRunId;
    if (runId == null) {
      return;
    }
    if (!const <String>{'CRASH-001', 'CRASH-002', 'CRASH-003'}
        .contains(errorCode)) {
      throw ArgumentError.value(errorCode, 'errorCode');
    }
    if (!RegExp(r'^[0-9a-f]{16,64}$').hasMatch(crashSignature)) {
      throw ArgumentError.value(crashSignature, 'crashSignature');
    }
    _crashMarked = true;
    final retained = breadcrumbs.length <= maximumBreadcrumbs
        ? breadcrumbs
        : breadcrumbs.sublist(breadcrumbs.length - maximumBreadcrumbs);
    _writeSynchronously(<String, Object?>{
      'schema_version': 1,
      'state': 'crash',
      'run_id': runId,
      'occurred_at_utc': _formatUtc(clock()),
      'error_code': errorCode,
      'crash_signature': crashSignature,
      'breadcrumbs': retained.map(_breadcrumbJson).toList(growable: false),
    });
  }

  Future<PreviousExitReport> readPrevious() async {
    if (!await file.exists()) {
      return const PreviousExitReport.none();
    }
    try {
      final bytes = await file.readAsBytes();
      if (bytes.length > 64 * 1024) {
        return _corruptReport();
      }
      final decoded = jsonDecode(utf8.decode(bytes, allowMalformed: false));
      if (decoded is! Map) {
        return _corruptReport();
      }
      final map = decoded.map((key, value) => MapEntry(key.toString(), value));
      const fields = <String>{
        'schema_version',
        'state',
        'run_id',
        'occurred_at_utc',
        'error_code',
        'crash_signature',
        'breadcrumbs',
      };
      if (map.keys.toSet().difference(fields).isNotEmpty ||
          map.keys.toSet().length != fields.length ||
          map['schema_version'] != 1) {
        return _corruptReport();
      }
      final state = map['state'];
      final runId = map['run_id'];
      final occurredAt = map['occurred_at_utc'];
      if (state is! String || runId is! String || occurredAt is! String) {
        return _corruptReport();
      }
      _validateUuid(runId, 'run_id');
      final timestamp = DateTime.parse(occurredAt).toUtc();
      final errorCode = map['error_code'];
      final signature = map['crash_signature'];
      final rawBreadcrumbs = map['breadcrumbs'];
      if (errorCode != null &&
          (errorCode is! String ||
              !KnownOperationalErrorCodes.contains(errorCode))) {
        return _corruptReport();
      }
      if (signature != null &&
          (signature is! String ||
              !RegExp(r'^[0-9a-f]{16,64}$').hasMatch(signature))) {
        return _corruptReport();
      }
      if (rawBreadcrumbs is! List ||
          rawBreadcrumbs.length > maximumBreadcrumbs) {
        return _corruptReport();
      }
      final breadcrumbs = <OperationalBreadcrumb>[];
      for (final raw in rawBreadcrumbs) {
        final breadcrumb = _parseBreadcrumb(raw);
        if (breadcrumb == null) {
          return _corruptReport();
        }
        breadcrumbs.add(breadcrumb);
      }
      final kind = switch (state) {
        'clean' => PreviousExitKind.clean,
        'active' => PreviousExitKind.unclean,
        'crash' => PreviousExitKind.crash,
        _ => PreviousExitKind.corrupt,
      };
      if (kind == PreviousExitKind.corrupt) {
        return _corruptReport();
      }
      if (kind == PreviousExitKind.crash &&
          (errorCode == null || signature == null)) {
        return _corruptReport();
      }
      if (kind != PreviousExitKind.crash &&
          (errorCode != null || signature != null)) {
        return _corruptReport();
      }
      return PreviousExitReport(
        kind: kind,
        runId: runId,
        occurredAtUtc: timestamp,
        errorCode: errorCode as String?,
        crashSignature: signature as String?,
        breadcrumbs: breadcrumbs,
      );
    } on Object {
      return _corruptReport();
    }
  }

  Future<void> _writeMarker({
    required String state,
    required String runId,
    String? errorCode,
    String? crashSignature,
    required List<OperationalBreadcrumb> breadcrumbs,
  }) {
    final retained = breadcrumbs.length <= maximumBreadcrumbs
        ? breadcrumbs
        : breadcrumbs.sublist(breadcrumbs.length - maximumBreadcrumbs);
    return _write(<String, Object?>{
      'schema_version': 1,
      'state': state,
      'run_id': runId,
      'occurred_at_utc': _formatUtc(clock()),
      'error_code': errorCode,
      'crash_signature': crashSignature,
      'breadcrumbs': retained.map(_breadcrumbJson).toList(growable: false),
    });
  }

  Future<void> _write(Map<String, Object?> value) async {
    final encoded = jsonEncode(value);
    OperationalPrivacyGuard.validateSerialized(encoded);
    final temporary = File('${file.path}.next');
    await file.parent.create(recursive: true);
    if (await temporary.exists()) {
      await temporary.delete();
    }
    await temporary.writeAsString(encoded, flush: true);
    if (await file.exists()) {
      await file.delete();
    }
    await temporary.rename(file.path);
  }

  void _writeSynchronously(Map<String, Object?> value) {
    final encoded = jsonEncode(value);
    OperationalPrivacyGuard.validateSerialized(encoded);
    final temporary = File('${file.path}.next');
    file.parent.createSync(recursive: true);
    if (temporary.existsSync()) {
      temporary.deleteSync();
    }
    temporary.writeAsStringSync(encoded, flush: true);
    if (file.existsSync()) {
      file.deleteSync();
    }
    temporary.renameSync(file.path);
  }

  PreviousExitReport _corruptReport() => PreviousExitReport(
        kind: PreviousExitKind.corrupt,
        runId: '',
        occurredAtUtc: null,
        errorCode: 'APP-BOOT-008',
        crashSignature: null,
        breadcrumbs: const <OperationalBreadcrumb>[],
      );

  OperationalBreadcrumb? _parseBreadcrumb(Object? value) {
    if (value is! Map) {
      return null;
    }
    final map = value.map((key, item) => MapEntry(key.toString(), item));
    const fields = <String>{
      'event_id',
      'occurred_at_utc',
      'name',
      'outcome',
      'error_code',
      'generation',
      'sequence',
    };
    if (map.keys.toSet().difference(fields).isNotEmpty ||
        map.keys.toSet().length != fields.length) {
      return null;
    }
    final eventId = map['event_id'];
    final occurredAt = map['occurred_at_utc'];
    final name = map['name'];
    final outcomeName = map['outcome'];
    final errorCode = map['error_code'];
    final generation = map['generation'];
    final sequence = map['sequence'];
    if (eventId is! String ||
        occurredAt is! String ||
        name is! String ||
        outcomeName is! String ||
        generation is! int ||
        sequence is! int) {
      return null;
    }
    _validateUuid(eventId, 'event_id');
    if (!RegExp(
          r'^[a-z][a-z0-9_]*(?:\.[a-z][a-z0-9_]*){2,5}$',
        ).hasMatch(name) ||
        generation < 0 ||
        sequence < 0 ||
        !occurredAt.endsWith('Z')) {
      return null;
    }
    final outcomes = <String, ObservabilityOutcome>{
      for (final outcome in ObservabilityOutcome.values)
        outcome.wireValue: outcome,
    };
    final outcome = outcomes[outcomeName];
    if (outcome == null ||
        (errorCode != null &&
            (errorCode is! String ||
                !KnownOperationalErrorCodes.contains(errorCode)))) {
      return null;
    }
    return OperationalBreadcrumb(
      eventId: eventId,
      occurredAtUtc: DateTime.parse(occurredAt).toUtc(),
      name: name,
      outcome: outcome,
      errorCode: errorCode as String?,
      generation: generation,
      sequence: sequence,
    );
  }

  Map<String, Object?> _breadcrumbJson(OperationalBreadcrumb item) =>
      <String, Object?>{
        'event_id': item.eventId,
        'occurred_at_utc': _formatUtc(item.occurredAtUtc),
        'name': item.name,
        'outcome': item.outcome.wireValue,
        'error_code': item.errorCode,
        'generation': item.generation,
        'sequence': item.sequence,
      };

  static void _validateUuid(String value, String field) {
    if (!RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    ).hasMatch(value)) {
      throw FormatException('invalid_$field');
    }
  }

  static String _formatUtc(DateTime value) {
    final formatted = value.toUtc().toIso8601String();
    return formatted.endsWith('Z') ? formatted : '${formatted}Z';
  }
}
