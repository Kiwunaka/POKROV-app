import 'model.dart';
import 'queue.dart';
import 'store.dart';
import 'package:pokrov_observability_contracts/observability_contracts.dart';

typedef ReleaseHealthBatchTransport = Future<bool> Function(
  Map<String, Object?> batch,
  String correlationId,
);

final class ReleaseHealthMirrorSnapshot {
  const ReleaseHealthMirrorSnapshot({
    required this.projected,
    required this.acceptedBatches,
    required this.rejectedBatches,
  });

  final int projected;
  final int acceptedBatches;
  final int rejectedBatches;
}

final class ReleaseHealthMirrorWriter implements OperationalEventWriter {
  ReleaseHealthMirrorWriter({
    required this.localWriter,
    required this.transport,
    this.maximumBatchEvents = 100,
  }) {
    if (maximumBatchEvents < 1 || maximumBatchEvents > 100) {
      throw ArgumentError.value(maximumBatchEvents, 'maximumBatchEvents');
    }
  }

  final OperationalEventWriter localWriter;
  final ReleaseHealthBatchTransport transport;
  final int maximumBatchEvents;
  int _projected = 0;
  int _acceptedBatches = 0;
  int _rejectedBatches = 0;

  @override
  Future<void> appendBatch(List<SerializedOperationalEvent> records) async {
    await localWriter.appendBatch(records);
    final eligible = records
        .map((record) => record.event)
        .where(_isAggregateEligible)
        .toList(growable: false);
    for (var offset = 0;
        offset < eligible.length;
        offset += maximumBatchEvents) {
      final end =
          (offset + maximumBatchEvents).clamp(0, eligible.length).toInt();
      final events =
          eligible.sublist(offset, end).map(_project).toList(growable: false);
      if (events.isEmpty) {
        continue;
      }
      _projected += events.length;
      final correlationId = eligible[offset].correlation.attemptId ??
          eligible[offset].correlation.runId;
      if (correlationId == null) {
        _rejectedBatches += 1;
        continue;
      }
      try {
        final accepted = await transport(
          <String, Object?>{'schema_version': 1, 'events': events},
          correlationId,
        );
        if (accepted) {
          _acceptedBatches += 1;
        } else {
          _rejectedBatches += 1;
        }
      } on Object {
        // Aggregate release health is best-effort and cannot fail the durable
        // local evidence path or a user operation.
        _rejectedBatches += 1;
      }
    }
  }

  ReleaseHealthMirrorSnapshot snapshot() => ReleaseHealthMirrorSnapshot(
        projected: _projected,
        acceptedBatches: _acceptedBatches,
        rejectedBatches: _rejectedBatches,
      );

  static bool _isAggregateEligible(OperationalEvent event) =>
      event.outcome != ObservabilityOutcome.started &&
      !event.isSecurity &&
      event.build.platform != 'server';

  static Map<String, Object?> _project(OperationalEvent event) {
    final routingAppCount = _routingAppCount(event);
    return <String, Object?>{
      'schema_version': 1,
      'event_id': event.eventId,
      'occurred_at_utc': _formatUtc(event.occurredAtUtc),
      'component': event.component,
      'subsystem': event.subsystem,
      'stage': event.stage,
      'name': event.name,
      'severity': event.severity.name,
      'outcome': event.outcome.wireValue,
      'privacy_class': 'release_health',
      'build': event.build.toJson(),
      'error': event.error?.toJson(),
      if (routingAppCount != null)
        'attributes': <String, Object?>{
          'selected_app_count': routingAppCount,
        },
    };
  }

  static int? _routingAppCount(OperationalEvent event) {
    if (event.component != 'app' ||
        event.subsystem != 'routing' ||
        event.stage != 'complete' ||
        event.name != 'app.routing.selection.finished' ||
        event.outcome != ObservabilityOutcome.observed ||
        event.build.platform != 'android') {
      return null;
    }
    final value = event.attributes['selected_app_count'];
    return value is int && value >= 0 && value <= 128 ? value : null;
  }

  static String _formatUtc(DateTime value) {
    final formatted = value.toUtc().toIso8601String();
    return formatted.endsWith('Z') ? formatted : '${formatted}Z';
  }
}
