import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:pokrov_observability_contracts/observability_contracts.dart';

import 'model.dart';

typedef LegacyEventIdFactory = String Function(int sequence);

final class LegacyTranslationContext {
  const LegacyTranslationContext({
    required this.build,
    required this.traceId,
    required this.runId,
    required this.attemptId,
    required this.generation,
    required this.firstSequence,
    required this.eventIdFactory,
  });

  final OperationalBuildIdentity build;
  final String traceId;
  final String? runId;
  final String? attemptId;
  final int generation;
  final int firstSequence;
  final LegacyEventIdFactory eventIdFactory;
}

final class LegacyTranslationResult {
  LegacyTranslationResult({
    required List<OperationalEvent> events,
    required this.skippedRecords,
    required this.malformedRecords,
    required this.truncatedTailIgnored,
  }) : events = List.unmodifiable(events);

  final List<OperationalEvent> events;
  final int skippedRecords;
  final int malformedRecords;
  final bool truncatedTailIgnored;
}

abstract final class LegacyOperationalJournalReader {
  static const _runtimeKeys = <String>{
    'at',
    'platform',
    'event',
    'outcome',
    'phase',
    'probe',
    'attempt',
    'failure_kind',
    'stop_reason',
  };

  static Future<LegacyTranslationResult> readRuntimeJsonl(
    File file,
    LegacyTranslationContext context,
  ) async {
    final lines = await _readCompleteLines(file);
    final events = <OperationalEvent>[];
    var skipped = 0;
    var malformed = 0;
    var sequence = context.firstSequence;
    for (final line in lines.lines) {
      Map<String, Object?> record;
      try {
        final decoded = jsonDecode(line);
        if (decoded is! Map<String, Object?>) {
          malformed += 1;
          continue;
        }
        record = decoded;
      } on FormatException {
        malformed += 1;
        continue;
      }
      if (!record.keys.toSet().difference(_runtimeKeys).isEmpty) {
        skipped += 1;
        continue;
      }
      final translated = _translateRuntimeRecord(record, context, sequence);
      if (translated == null) {
        skipped += 1;
        continue;
      }
      events.add(translated);
      sequence += 1;
    }
    return LegacyTranslationResult(
      events: events,
      skippedRecords: skipped,
      malformedRecords: malformed,
      truncatedTailIgnored: lines.truncatedTailIgnored,
    );
  }

  static Future<LegacyTranslationResult> readWindowsServiceJournal(
    File file,
    LegacyTranslationContext context,
  ) async {
    final lines = await _readCompleteLines(file);
    final events = <OperationalEvent>[];
    var skipped = 0;
    var malformed = 0;
    var nextSequence = context.firstSequence;
    for (final line in lines.lines) {
      final fields = line.split('|');
      if (fields.isNotEmpty && fields[0] == 'POKROV_CORE_EVENT_V1') {
        final translated = _translateCoreEventRecord(
          fields: fields,
          context: context,
          eventIdSequence: nextSequence,
        );
        if (translated == null) {
          skipped += 1;
          continue;
        }
        events.add(translated);
        nextSequence += 1;
        continue;
      }
      if (fields.length != 8 || fields[0] != 'POKROV_SERVICE_EVENT_V1') {
        malformed += 1;
        continue;
      }
      final ticks = int.tryParse(fields[1]);
      final sourceSequence = int.tryParse(fields[2]);
      if (ticks == null || sourceSequence == null || sourceSequence < 0) {
        malformed += 1;
        continue;
      }
      final translated = _translateWindowsServiceRecord(
        fields: fields,
        occurredAt: _fileTimeTicksToUtc(ticks),
        context: context,
        sequence: nextSequence,
        sourceSequence: sourceSequence,
      );
      if (translated == null) {
        skipped += 1;
        continue;
      }
      events.add(translated);
      nextSequence += 1;
    }
    return LegacyTranslationResult(
      events: events,
      skippedRecords: skipped,
      malformedRecords: malformed,
      truncatedTailIgnored: lines.truncatedTailIgnored,
    );
  }

  static OperationalEvent? _translateRuntimeRecord(
    Map<String, Object?> record,
    LegacyTranslationContext context,
    int sequence,
  ) {
    final event = record['event'];
    final rawOutcome = record['outcome'];
    final occurredAt = DateTime.tryParse(
      record['at']?.toString() ?? '',
    )?.toUtc();
    if (event is! String || rawOutcome is! String || occurredAt == null) {
      return null;
    }
    final mapping = _runtimeMappings[event];
    final outcome = _legacyOutcome(rawOutcome);
    if (mapping == null || outcome == null) {
      return null;
    }
    final failed = outcome == ObservabilityOutcome.failed;
    final attributes = <String, Object?>{'phase': mapping.phase};
    final attempt = record['attempt'];
    if (attempt is int && attempt >= 0 && attempt <= 100) {
      attributes['retry_count'] = attempt;
    }
    if (mapping.attributeKey != null) {
      attributes[mapping.attributeKey!] = !failed;
    }
    final errorCode = failed
        ? _legacyRuntimeError(
            event,
            record['failure_kind'] is String
                ? record['failure_kind']! as String
                : null,
          )
        : null;
    return OperationalEvent(
      eventId: context.eventIdFactory(sequence),
      occurredAtUtc: occurredAt,
      component: record['platform'] == 'windows' ? 'windows_host' : 'app',
      subsystem: mapping.subsystem,
      stage: mapping.stage,
      name: failed ? mapping.failedName : mapping.succeededName,
      severity:
          failed ? ObservabilitySeverity.error : ObservabilitySeverity.info,
      outcome: outcome,
      privacyClass: ObservabilityPrivacyClass.localOperational,
      correlation: OperationalCorrelation(
        traceId: context.traceId,
        spanId: _spanId('$event:$sequence'),
        parentSpanId: null,
        runId: context.runId,
        attemptId: context.attemptId,
        generation: context.generation,
        sequence: sequence,
      ),
      build: context.build,
      error: errorCode == null
          ? null
          : OperationalErrorIdentity(
              code: errorCode,
              origin: mapping.errorOrigin,
            ),
      attributes: attributes,
    );
  }

  static OperationalEvent? _translateWindowsServiceRecord({
    required List<String> fields,
    required DateTime occurredAt,
    required LegacyTranslationContext context,
    required int sequence,
    required int sourceSequence,
  }) {
    final event = fields[3];
    final outcome = _serviceOutcome(fields[4]);
    final mapping = _serviceMappings[event];
    if (outcome == null || mapping == null) {
      return null;
    }
    final failed = outcome == ObservabilityOutcome.failed;
    final status = fields[6];
    final correlation = RegExp(r'^[0-9a-f]{32}$').hasMatch(fields[7])
        ? fields[7]
        : context.traceId;
    final errorCode = failed ? _serviceError(event, status) : null;
    final attributes = <String, Object?>{
      'phase': mapping.phase,
      if (mapping.attributeKey != null) mapping.attributeKey!: !failed,
    };
    return OperationalEvent(
      eventId: context.eventIdFactory(sequence),
      occurredAtUtc: occurredAt,
      component: 'windows_service',
      subsystem: mapping.subsystem,
      stage: mapping.stage,
      name: failed ? mapping.failedName : mapping.succeededName,
      severity:
          failed ? ObservabilitySeverity.error : ObservabilitySeverity.info,
      outcome: outcome,
      privacyClass: ObservabilityPrivacyClass.localOperational,
      correlation: OperationalCorrelation(
        traceId: correlation,
        spanId: _spanId('$event:$sourceSequence'),
        parentSpanId: null,
        runId: context.runId,
        attemptId: context.attemptId,
        generation: context.generation,
        sequence: sequence,
      ),
      build: context.build,
      error: errorCode == null
          ? null
          : OperationalErrorIdentity(
              code: errorCode,
              origin: ObservabilityErrorOrigin.host,
            ),
      attributes: attributes,
    );
  }

  static OperationalEvent? _translateCoreEventRecord({
    required List<String> fields,
    required LegacyTranslationContext context,
    required int eventIdSequence,
  }) {
    if (fields.length != 15 || fields[1] != '1' || fields[2] != '1') {
      return null;
    }
    final occurredAt = DateTime.tryParse(fields[3])?.toUtc();
    final runId = fields[4];
    final attemptId = fields[5];
    final generation = int.tryParse(fields[6]);
    final sequence = int.tryParse(fields[7]);
    final name = fields[8];
    final definition = _coreEventMappings[name];
    final outcome = _legacyOutcome(fields[12]);
    final rawError = fields[13] == 'none' ? null : fields[13];
    if (occurredAt == null ||
        !_uuidPattern.hasMatch(runId) ||
        !_uuidPattern.hasMatch(attemptId) ||
        generation == null ||
        generation < 1 ||
        generation > 0x7fffffff ||
        sequence == null ||
        sequence < 1 ||
        definition == null ||
        fields[9] != definition.subsystem ||
        fields[10] != definition.stage ||
        fields[14] != definition.phase ||
        outcome == null ||
        (outcome == ObservabilityOutcome.failed) != (fields[11] == 'error') ||
        (outcome != ObservabilityOutcome.failed && fields[11] != 'info') ||
        (outcome == ObservabilityOutcome.failed &&
            !_coreEventErrorCodes.contains(rawError ?? '')) ||
        (outcome != ObservabilityOutcome.failed && rawError != null)) {
      return null;
    }
    final canonicalPhase = switch (definition.phase) {
      'initialization' => 'bootstrap',
      'core_start' => 'core',
      final value => value,
    };
    return OperationalEvent(
      eventId: context.eventIdFactory(eventIdSequence),
      occurredAtUtc: occurredAt,
      component: 'core',
      subsystem: definition.subsystem,
      stage: definition.stage,
      name: name,
      severity: fields[11] == 'error'
          ? ObservabilitySeverity.error
          : ObservabilitySeverity.info,
      outcome: outcome,
      privacyClass: ObservabilityPrivacyClass.localOperational,
      correlation: OperationalCorrelation(
        traceId: runId.replaceAll('-', ''),
        spanId: _spanId('$name:$generation:$sequence'),
        parentSpanId: null,
        runId: runId,
        attemptId: attemptId,
        generation: generation,
        sequence: sequence,
      ),
      build: context.build,
      error: rawError == null
          ? null
          : OperationalErrorIdentity(
              code: rawError,
              origin: ObservabilityErrorOrigin.core,
            ),
      attributes: <String, Object?>{'phase': canonicalPhase},
    );
  }

  static ObservabilityOutcome? _legacyOutcome(String value) => switch (value) {
        'started' => ObservabilityOutcome.started,
        'succeeded' || 'completed' => ObservabilityOutcome.succeeded,
        'failed' => ObservabilityOutcome.failed,
        'cancelled' => ObservabilityOutcome.cancelled,
        _ => null,
      };

  static ObservabilityOutcome? _serviceOutcome(String value) => switch (value) {
        'attempted' => ObservabilityOutcome.started,
        'succeeded' || 'accepted' => ObservabilityOutcome.succeeded,
        'failed' || 'rejected' => ObservabilityOutcome.failed,
        _ => null,
      };

  static String _legacyRuntimeError(String event, String? failureKind) {
    if (failureKind == 'desktop_tun_egress_probe_failed') {
      return 'EGRESS-001';
    }
    if (failureKind == 'runtime_stop_failed') {
      return 'CORE-008';
    }
    return switch (event) {
      'initialization' => 'APP-BOOT-008',
      'profile' => 'CONN-005',
      'core_start' => 'CORE-003',
      'tun' => 'TUN-001',
      'routes' => 'ROUTE-001',
      'dns' => 'DNS-001',
      'egress' => 'EGRESS-001',
      'recovery' => 'RECON-003',
      'stop' => 'CORE-008',
      _ => 'CORE-007',
    };
  }

  static String _serviceError(String event, String status) {
    if (status == 'unauthorized') {
      return 'WIN-SVC-002';
    }
    if (status == 'unsupported') {
      return 'WIN-SVC-004';
    }
    if (status == 'deadline_exceeded') {
      return 'WIN-SVC-003';
    }
    return switch (event) {
      'runtime_core_start' || 'runtime_core_stop' => 'CORE-003',
      'runtime_wintun_start' => 'WIN-TUN-002',
      'runtime_adapter_apply' || 'runtime_route_apply' => 'ROUTE-001',
      'runtime_dns_apply' => 'WIN-DNS-001',
      'runtime_egress_verify' => 'EGRESS-001',
      'runtime_rollback_begin' ||
      'runtime_network_restore' ||
      'runtime_rollback_complete' =>
        'ROUTE-002',
      'runtime_recovery_required' => 'RECON-003',
      _ => 'WIN-SVC-003',
    };
  }

  static DateTime _fileTimeTicksToUtc(int ticks) {
    const epochOffsetTicks = 116444736000000000;
    final unixMicroseconds = (ticks - epochOffsetTicks) ~/ 10;
    return DateTime.fromMicrosecondsSinceEpoch(unixMicroseconds, isUtc: true);
  }

  static String _spanId(String value) =>
      sha256.convert(utf8.encode(value)).toString().substring(0, 16);

  static final _uuidPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  static Future<_CompleteLines> _readCompleteLines(File file) async {
    if (!await file.exists()) {
      return const _CompleteLines(lines: [], truncatedTailIgnored: false);
    }
    final bytes = await file.readAsBytes();
    final completeEnd = bytes.lastIndexOf(10) + 1;
    final truncated = bytes.isNotEmpty && completeEnd != bytes.length;
    if (completeEnd == 0) {
      return _CompleteLines(lines: const [], truncatedTailIgnored: truncated);
    }
    try {
      final text = utf8.decode(
        bytes.sublist(0, completeEnd),
        allowMalformed: false,
      );
      return _CompleteLines(
        lines: const LineSplitter()
            .convert(text)
            .where((line) => line.isNotEmpty)
            .toList(growable: false),
        truncatedTailIgnored: truncated,
      );
    } on FormatException {
      return _CompleteLines(lines: const [], truncatedTailIgnored: truncated);
    }
  }
}

final class _CompleteLines {
  const _CompleteLines({
    required this.lines,
    required this.truncatedTailIgnored,
  });

  final List<String> lines;
  final bool truncatedTailIgnored;
}

final class _LegacyEventMapping {
  const _LegacyEventMapping({
    required this.subsystem,
    required this.phase,
    required this.stage,
    required this.succeededName,
    required this.failedName,
    required this.errorOrigin,
    this.attributeKey,
  });

  final String subsystem;
  final String phase;
  final String stage;
  final String succeededName;
  final String failedName;
  final ObservabilityErrorOrigin errorOrigin;
  final String? attributeKey;
}

const _runtimeMappings = <String, _LegacyEventMapping>{
  'initialization': _LegacyEventMapping(
    subsystem: 'bootstrap',
    phase: 'bootstrap',
    stage: 'initialize',
    succeededName: 'bootstrap.phase.completed',
    failedName: 'bootstrap.phase.failed',
    errorOrigin: ObservabilityErrorOrigin.client,
  ),
  'profile': _LegacyEventMapping(
    subsystem: 'connection',
    phase: 'profile',
    stage: 'prepare',
    succeededName: 'connection.profile.fetch.completed',
    failedName: 'connection.profile.fetch.failed',
    errorOrigin: ObservabilityErrorOrigin.client,
  ),
  'core_start': _LegacyEventMapping(
    subsystem: 'core',
    phase: 'core',
    stage: 'start',
    succeededName: 'connection.core.start.completed',
    failedName: 'connection.core.start.failed',
    errorOrigin: ObservabilityErrorOrigin.core,
  ),
  'tun': _LegacyEventMapping(
    subsystem: 'tun',
    phase: 'tun',
    stage: 'start',
    succeededName: 'connection.tun.create.completed',
    failedName: 'connection.tun.create.failed',
    errorOrigin: ObservabilityErrorOrigin.host,
    attributeKey: 'interface_ready',
  ),
  'routes': _LegacyEventMapping(
    subsystem: 'routing',
    phase: 'routes',
    stage: 'apply',
    succeededName: 'connection.routes.apply.completed',
    failedName: 'connection.routes.apply.failed',
    errorOrigin: ObservabilityErrorOrigin.host,
    attributeKey: 'routes_ready',
  ),
  'dns': _LegacyEventMapping(
    subsystem: 'dns',
    phase: 'dns',
    stage: 'verify',
    succeededName: 'connection.probe.dns.completed',
    failedName: 'connection.probe.dns.completed',
    errorOrigin: ObservabilityErrorOrigin.client,
    attributeKey: 'dns_ready',
  ),
  'egress': _LegacyEventMapping(
    subsystem: 'egress',
    phase: 'egress',
    stage: 'verify',
    succeededName: 'connection.probe.egress.completed',
    failedName: 'connection.probe.egress.completed',
    errorOrigin: ObservabilityErrorOrigin.client,
    attributeKey: 'egress_ready',
  ),
  'recovery': _LegacyEventMapping(
    subsystem: 'recovery',
    phase: 'recovery',
    stage: 'recover',
    succeededName: 'connection.rollback.completed',
    failedName: 'connection.rollback.failed',
    errorOrigin: ObservabilityErrorOrigin.host,
  ),
  'stop': _LegacyEventMapping(
    subsystem: 'connection',
    phase: 'stop',
    stage: 'stop',
    succeededName: 'connection.stopped',
    failedName: 'connection.rollback.failed',
    errorOrigin: ObservabilityErrorOrigin.core,
  ),
};

final _serviceMappings = <String, _LegacyEventMapping>{
  'runtime_core_start': _runtimeMappings['core_start']!,
  'runtime_core_stop': _runtimeMappings['stop']!,
  'runtime_wintun_start': _runtimeMappings['tun']!,
  'runtime_adapter_apply': _runtimeMappings['routes']!,
  'runtime_route_apply': _runtimeMappings['routes']!,
  'runtime_dns_apply': _runtimeMappings['dns']!,
  'runtime_egress_verify': _runtimeMappings['egress']!,
  'runtime_rollback_begin': _LegacyEventMapping(
    subsystem: 'recovery',
    phase: 'recovery',
    stage: 'rollback',
    succeededName: 'connection.rollback.started',
    failedName: 'connection.rollback.failed',
    errorOrigin: ObservabilityErrorOrigin.host,
  ),
  'runtime_network_restore': _runtimeMappings['recovery']!,
  'runtime_rollback_complete': _runtimeMappings['recovery']!,
  'runtime_recovery_required': _runtimeMappings['recovery']!,
};

const _coreEventMappings = <String, _LegacyEventMapping>{
  'core.runtime.initialize': _LegacyEventMapping(
    subsystem: 'core',
    phase: 'initialization',
    stage: 'initialize',
    succeededName: 'core.runtime.initialize',
    failedName: 'core.runtime.initialize',
    errorOrigin: ObservabilityErrorOrigin.core,
  ),
  'core.runtime.start': _LegacyEventMapping(
    subsystem: 'core',
    phase: 'core_start',
    stage: 'start',
    succeededName: 'core.runtime.start',
    failedName: 'core.runtime.start',
    errorOrigin: ObservabilityErrorOrigin.core,
  ),
  'core.runtime.stop': _LegacyEventMapping(
    subsystem: 'core',
    phase: 'stop',
    stage: 'stop',
    succeededName: 'core.runtime.stop',
    failedName: 'core.runtime.stop',
    errorOrigin: ObservabilityErrorOrigin.core,
  ),
  'core.egress.probe': _LegacyEventMapping(
    subsystem: 'egress',
    phase: 'egress',
    stage: 'verify',
    succeededName: 'core.egress.probe',
    failedName: 'core.egress.probe',
    errorOrigin: ObservabilityErrorOrigin.core,
  ),
};

const _coreEventErrorCodes = <String>{
  'CORE-003',
  'CORE-005',
  'CORE-006',
  'CORE-008',
  'TRANSPORT-001',
  'TRANSPORT-002',
  'TRANSPORT-003',
  'TRANSPORT-004',
  'EGRESS-001',
};
