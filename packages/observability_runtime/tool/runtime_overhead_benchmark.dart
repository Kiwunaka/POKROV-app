import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:pokrov_observability_contracts/observability_contracts.dart';
import 'package:pokrov_observability_runtime/observability_runtime.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.length != 1 || !arguments.single.startsWith('--target=')) {
    stderr.writeln('usage: dart run tool/runtime_overhead_benchmark.dart '
        '--target=android|windows');
    exitCode = 64;
    return;
  }

  final targetName = arguments.single.substring('--target='.length);
  final target = switch (targetName) {
    'android' => OperationalOverheadTarget.android,
    'windows' => OperationalOverheadTarget.windows,
    _ => null,
  };
  if (target == null) {
    stderr.writeln('target must be android or windows');
    exitCode = 64;
    return;
  }

  final rssBefore = ProcessInfo.currentRss;
  final idle = await _runWorkload(
    target: target,
    phase: 'bootstrap',
    events: 10,
    seed: 120,
  );
  final connect = await _runWorkload(
    target: target,
    phase: 'egress',
    events: 256,
    seed: 121,
  );
  final rssAfter = ProcessInfo.currentRss;
  final latencies = <int>[...idle.emitMicroseconds, ...connect.emitMicroseconds]
    ..sort();
  final assessment = OperationalOverheadAssessment(
    target: target,
    observation: OperationalOverheadObservation(
      idleBytesPerMinute: idle.bytesWritten,
      connectBurstBytes: connect.bytesWritten,
      maxEventBytes: max(idle.maxEventBytes, connect.maxEventBytes),
      emitP95Microseconds: _percentile95(latencies),
      eventsAttempted: idle.attempted + connect.attempted,
      eventsAccepted: idle.accepted + connect.accepted,
      eventsDropped: idle.dropped + connect.dropped,
      peakQueueBytes: max(idle.peakQueueBytes, connect.peakQueueBytes),
      rssDeltaBytes: max(0, rssAfter - rssBefore),
    ),
  );

  stdout.writeln(
    const JsonEncoder.withIndent('  ').convert(
      assessment.toJson(
        os: Platform.operatingSystemVersion,
        runtimeVersion: Platform.version,
        processors: Platform.numberOfProcessors,
      ),
    ),
  );
}

Future<_WorkloadResult> _runWorkload({
  required OperationalOverheadTarget target,
  required String phase,
  required int events,
  required int seed,
}) async {
  final writer = _CountingWriter();
  final dispatcher = OperationalEventDispatcher(writer: writer);
  dispatcher.sequenceFence.activateGeneration(1);
  final ids = OperationalIdFactory(random: Random(seed));
  final runId = ids.uuidV4();
  final attemptId = ids.uuidV4();
  final latencies = <int>[];
  var accepted = 0;
  var peakQueueBytes = 0;

  for (var index = 0; index < events; index += 1) {
    final event = OperationalEvent(
      eventId: ids.uuidV4(),
      occurredAtUtc: DateTime.utc(2026, 8, 22, 12).add(
        Duration(milliseconds: index),
      ),
      component: 'app',
      subsystem: 'performance',
      stage: 'run',
      name: 'app.performance.pipeline.observed',
      severity: ObservabilitySeverity.debug,
      outcome: ObservabilityOutcome.succeeded,
      privacyClass: ObservabilityPrivacyClass.localOperational,
      correlation: OperationalCorrelation(
        traceId: ids.traceId(),
        spanId: ids.spanId(),
        parentSpanId: null,
        runId: runId,
        attemptId: attemptId,
        generation: 1,
        sequence: index + 1,
      ),
      build: _build(target),
      error: null,
      attributes: <String, Object?>{
        'phase': phase,
        'duration_ms': index + 1,
      },
    );
    final stopwatch = Stopwatch()..start();
    final result = dispatcher.emit(event);
    stopwatch.stop();
    latencies.add(stopwatch.elapsedMicroseconds);
    if (result == OperationalEmitResult.accepted) {
      accepted += 1;
    }
    peakQueueBytes = max(peakQueueBytes, dispatcher.snapshot().queue.bytes);
  }
  await dispatcher.flush();

  return _WorkloadResult(
    attempted: events,
    accepted: accepted,
    dropped: events - accepted,
    bytesWritten: writer.bytesWritten,
    maxEventBytes: writer.maxEventBytes,
    peakQueueBytes: peakQueueBytes,
    emitMicroseconds: latencies,
  );
}

OperationalBuildIdentity _build(OperationalOverheadTarget target) =>
    OperationalBuildIdentity(
      appVersion: '1.2.0',
      buildNumber: '30',
      channel: 'local',
      candidateLabel: 'pokrov-1.2.0-local',
      gitRevision: '0123456789abcdef0123456789abcdef01234567',
      coreVersion: '1.1.0',
      coreAbi: 2,
      platform: target.name,
      architecture:
          target == OperationalOverheadTarget.android ? 'arm64-v8a' : 'x86_64',
    );

int _percentile95(List<int> sortedValues) {
  if (sortedValues.isEmpty) {
    return 0;
  }
  return sortedValues[((sortedValues.length - 1) * 0.95).ceil()];
}

final class _CountingWriter implements OperationalEventWriter {
  int bytesWritten = 0;
  int maxEventBytes = 0;

  @override
  Future<void> appendBatch(List<SerializedOperationalEvent> records) async {
    for (final record in records) {
      bytesWritten += record.byteLength;
      maxEventBytes = max(maxEventBytes, record.byteLength);
    }
  }
}

final class _WorkloadResult {
  const _WorkloadResult({
    required this.attempted,
    required this.accepted,
    required this.dropped,
    required this.bytesWritten,
    required this.maxEventBytes,
    required this.peakQueueBytes,
    required this.emitMicroseconds,
  });

  final int attempted;
  final int accepted;
  final int dropped;
  final int bytesWritten;
  final int maxEventBytes;
  final int peakQueueBytes;
  final List<int> emitMicroseconds;
}
