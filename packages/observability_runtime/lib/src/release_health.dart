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
  final BoundedOperationalEventQueue _pending = BoundedOperationalEventQueue();
  // A dequeued batch stays here until ACK; replay never writes it locally again.
  ({Map<String, Object?> body, String correlationId})? _unacknowledgedBatch;
  Future<void> _delivery = Future<void>.value();
  int _projected = 0;
  int _acceptedBatches = 0;
  int _rejectedBatches = 0;

  @override
  Future<void> appendBatch(List<SerializedOperationalEvent> records) async {
    await localWriter.appendBatch(records);
    for (final record in records) {
      if (_isAggregateEligible(record.event)) {
        _pending.tryAdd(record);
      }
    }
    final delivery = _delivery.then((_) => _drainPending());
    _delivery = delivery;
    await delivery;
  }

  Future<void> _drainPending() async {
    while (true) {
      if (_unacknowledgedBatch == null) {
        final records = _pending.takeBatch(maximum: maximumBatchEvents);
        if (records.isEmpty) {
          return;
        }
        final events =
            records.map((record) => record.event).toList(growable: false);
        _projected += events.length;
        final correlationId = events.first.correlation.attemptId ??
            events.first.correlation.runId;
        if (correlationId == null) {
          _rejectedBatches += 1;
          continue;
        }
        _unacknowledgedBatch = (
          body: <String, Object?>{
            'schema_version': 1,
            'events': events.map(_project).toList(growable: false),
          },
          correlationId: correlationId,
        );
      }
      final batch = _unacknowledgedBatch!;
      try {
        final accepted = await transport(batch.body, batch.correlationId);
        if (accepted) {
          _acceptedBatches += 1;
          _unacknowledgedBatch = null;
        } else {
          _rejectedBatches += 1;
          return;
        }
      } on Object {
        // Aggregate release health is best-effort and cannot fail the durable
        // local evidence path or a user operation.
        _rejectedBatches += 1;
        return;
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
