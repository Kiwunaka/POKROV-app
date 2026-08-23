enum OperationalOverheadTarget { android, windows }

final class OperationalOverheadBudget {
  const OperationalOverheadBudget({
    required this.idleBytesPerMinute,
    required this.connectBurstBytesPerMinute,
    required this.maxEventBytes,
    required this.queueBytes,
    required this.idleCpuPercentOfOneCore,
  });

  factory OperationalOverheadBudget.forTarget(
    OperationalOverheadTarget target,
  ) =>
      switch (target) {
        OperationalOverheadTarget.android => const OperationalOverheadBudget(
            idleBytesPerMinute: 50 * 1024,
            connectBurstBytesPerMinute: 1024 * 1024,
            maxEventBytes: 8 * 1024,
            queueBytes: 2 * 1024 * 1024,
            idleCpuPercentOfOneCore: 1,
          ),
        OperationalOverheadTarget.windows => const OperationalOverheadBudget(
            idleBytesPerMinute: 100 * 1024,
            connectBurstBytesPerMinute: 2 * 1024 * 1024,
            maxEventBytes: 8 * 1024,
            queueBytes: 4 * 1024 * 1024,
            idleCpuPercentOfOneCore: 0.5,
          ),
      };

  final int idleBytesPerMinute;
  final int connectBurstBytesPerMinute;
  final int maxEventBytes;
  final int queueBytes;
  final double idleCpuPercentOfOneCore;
}

final class OperationalOverheadObservation {
  const OperationalOverheadObservation({
    required this.idleBytesPerMinute,
    required this.connectBurstBytes,
    required this.maxEventBytes,
    required this.emitP95Microseconds,
    required this.eventsAttempted,
    required this.eventsAccepted,
    required this.eventsDropped,
    required this.peakQueueBytes,
    required this.rssDeltaBytes,
  });

  final int idleBytesPerMinute;
  final int connectBurstBytes;
  final int maxEventBytes;
  final int emitP95Microseconds;
  final int eventsAttempted;
  final int eventsAccepted;
  final int eventsDropped;
  final int peakQueueBytes;
  final int rssDeltaBytes;
}

final class OperationalOverheadAssessment {
  OperationalOverheadAssessment({
    required this.target,
    required this.observation,
  }) : budget = OperationalOverheadBudget.forTarget(target) {
    for (final value in <int>[
      observation.idleBytesPerMinute,
      observation.connectBurstBytes,
      observation.maxEventBytes,
      observation.emitP95Microseconds,
      observation.eventsAttempted,
      observation.eventsAccepted,
      observation.eventsDropped,
      observation.peakQueueBytes,
      observation.rssDeltaBytes,
    ]) {
      if (value < 0) {
        throw ArgumentError('Overhead observations must be non-negative');
      }
    }
    if (observation.eventsAccepted + observation.eventsDropped !=
        observation.eventsAttempted) {
      throw ArgumentError('Overhead event accounting is inconsistent');
    }
  }

  final OperationalOverheadTarget target;
  final OperationalOverheadObservation observation;
  final OperationalOverheadBudget budget;

  bool get idleVolumeWithinBudget =>
      observation.idleBytesPerMinute <= budget.idleBytesPerMinute;
  bool get connectVolumeWithinBudget =>
      observation.connectBurstBytes <= budget.connectBurstBytesPerMinute;
  bool get payloadWithinBudget =>
      observation.maxEventBytes <= budget.maxEventBytes;
  bool get queueWithinBudget => observation.peakQueueBytes <= budget.queueBytes;
  bool get lossless => observation.eventsDropped == 0;

  Map<String, Object?> toJson({
    required String os,
    required String runtimeVersion,
    required int processors,
  }) =>
      <String, Object?>{
        'schema': 'pokrov.observability-overhead.local.v1',
        'state': 'PARTIAL_LOCAL',
        'candidate_proven': false,
        'target': target.name,
        'environment': <String, Object?>{
          'os': os,
          'runtime_version': runtimeVersion,
          'processors': processors,
        },
        'observation': <String, Object?>{
          'idle_bytes_per_minute': observation.idleBytesPerMinute,
          'connect_burst_bytes': observation.connectBurstBytes,
          'max_event_bytes': observation.maxEventBytes,
          'emit_p95_microseconds': observation.emitP95Microseconds,
          'events_attempted': observation.eventsAttempted,
          'events_accepted': observation.eventsAccepted,
          'events_dropped': observation.eventsDropped,
          'peak_queue_bytes': observation.peakQueueBytes,
          'rss_delta_bytes': observation.rssDeltaBytes,
        },
        'budgets': <String, Object?>{
          'idle_bytes_per_minute': budget.idleBytesPerMinute,
          'connect_burst_bytes_per_minute': budget.connectBurstBytesPerMinute,
          'max_event_bytes': budget.maxEventBytes,
          'queue_bytes': budget.queueBytes,
          'idle_cpu_percent_of_one_core': budget.idleCpuPercentOfOneCore,
        },
        'results': <String, Object?>{
          'idle_volume': idleVolumeWithinBudget ? 'PASS' : 'FAIL',
          'connect_volume': connectVolumeWithinBudget ? 'PASS' : 'FAIL',
          'payload': payloadWithinBudget ? 'PASS' : 'FAIL',
          'queue_volume': queueWithinBudget ? 'PASS' : 'FAIL',
          'queue_loss': lossless ? 'PASS' : 'FAIL',
          'idle_cpu': 'NOT_MEASURED',
          'cold_start_delta': 'NOT_MEASURED',
          'connect_latency_delta': 'NOT_MEASURED',
          'idle_app_delta': 'NOT_MEASURED',
          'physical_battery': 'NOT_MEASURED',
        },
      };
}
