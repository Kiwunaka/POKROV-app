import 'dart:convert';
import 'dart:collection';

import 'package:pokrov_observability_contracts/observability_contracts.dart';

import 'model.dart';
import 'privacy.dart';

final class SerializedOperationalEvent {
  const SerializedOperationalEvent({
    required this.event,
    required this.json,
    required this.byteLength,
  });

  final OperationalEvent event;
  final String json;
  final int byteLength;
}

final class OperationalEventSerializer {
  const OperationalEventSerializer({this.maxEventBytes = 8192});

  final int maxEventBytes;

  SerializedOperationalEvent serialize(OperationalEvent event) {
    final encoded = jsonEncode(event.toJson());
    OperationalPrivacyGuard.validateSerialized(encoded);
    final byteLength = utf8.encode(encoded).length + 1;
    if (byteLength > maxEventBytes) {
      throw const FormatException('operational_event_too_large');
    }
    return SerializedOperationalEvent(
      event: event,
      json: encoded,
      byteLength: byteLength,
    );
  }
}

final class OperationalQueueSnapshot {
  OperationalQueueSnapshot({
    required this.depth,
    required this.bytes,
    required this.accepted,
    required this.dropped,
    required Map<ObservabilitySeverity, int> droppedBySeverity,
  }) : droppedBySeverity = Map<ObservabilitySeverity, int>.unmodifiable(
          droppedBySeverity,
        );

  final int depth;
  final int bytes;
  final int accepted;
  final int dropped;
  final Map<ObservabilitySeverity, int> droppedBySeverity;
}

final class BoundedOperationalEventQueue {
  BoundedOperationalEventQueue({
    this.maxEvents = 4096,
    this.maxBytes = 4 * 1024 * 1024,
  }) {
    if (maxEvents < 1 || maxBytes < 1024) {
      throw ArgumentError('Queue bounds are invalid');
    }
  }

  final int maxEvents;
  final int maxBytes;
  final ListQueue<SerializedOperationalEvent> _records = ListQueue();
  final Map<ObservabilitySeverity, int> _droppedBySeverity = {
    for (final severity in ObservabilitySeverity.values) severity: 0,
  };
  int _bytes = 0;
  int _accepted = 0;
  int _dropped = 0;

  bool get isEmpty => _records.isEmpty;
  int get depth => _records.length;

  bool tryAdd(SerializedOperationalEvent incoming) {
    if (incoming.byteLength > maxBytes) {
      _recordDrop(incoming);
      return false;
    }
    while (_records.length >= maxEvents ||
        _bytes + incoming.byteLength > maxBytes) {
      final evictionIndex = _findEvictionIndex(incoming);
      if (evictionIndex < 0) {
        _recordDrop(incoming);
        return false;
      }
      final removed = _removeAt(evictionIndex);
      _recordDrop(removed);
    }
    _records.addLast(incoming);
    _bytes += incoming.byteLength;
    _accepted += 1;
    return true;
  }

  List<SerializedOperationalEvent> takeBatch({int maximum = 64}) {
    if (maximum < 1) {
      throw ArgumentError.value(maximum, 'maximum');
    }
    final batch = <SerializedOperationalEvent>[];
    while (batch.length < maximum && _records.isNotEmpty) {
      final record = _records.removeFirst();
      _bytes -= record.byteLength;
      batch.add(record);
    }
    return batch;
  }

  OperationalQueueSnapshot snapshot() => OperationalQueueSnapshot(
        depth: _records.length,
        bytes: _bytes,
        accepted: _accepted,
        dropped: _dropped,
        droppedBySeverity: _droppedBySeverity,
      );

  int _findEvictionIndex(SerializedOperationalEvent incoming) {
    var lowestPriority = 1 << 30;
    var candidate = -1;
    var index = 0;
    for (final record in _records) {
      if (record.event.priority < lowestPriority) {
        lowestPriority = record.event.priority;
        candidate = index;
      }
      index += 1;
    }
    if (candidate < 0 || lowestPriority > incoming.event.priority) {
      return -1;
    }
    if (lowestPriority == incoming.event.priority &&
        incoming.event.priority < 4) {
      return -1;
    }
    return candidate;
  }

  SerializedOperationalEvent _removeAt(int target) {
    final retained = ListQueue<SerializedOperationalEvent>();
    SerializedOperationalEvent? removed;
    var index = 0;
    while (_records.isNotEmpty) {
      final record = _records.removeFirst();
      if (index == target) {
        removed = record;
        _bytes -= record.byteLength;
      } else {
        retained.addLast(record);
      }
      index += 1;
    }
    _records.addAll(retained);
    return removed!;
  }

  void _recordDrop(SerializedOperationalEvent record) {
    _dropped += 1;
    final severity = record.event.severity;
    _droppedBySeverity[severity] = _droppedBySeverity[severity]! + 1;
  }
}

final class OperationalBreadcrumb {
  const OperationalBreadcrumb({
    required this.eventId,
    required this.occurredAtUtc,
    required this.name,
    required this.outcome,
    required this.errorCode,
    required this.generation,
    required this.sequence,
  });

  factory OperationalBreadcrumb.fromEvent(OperationalEvent event) =>
      OperationalBreadcrumb(
        eventId: event.eventId,
        occurredAtUtc: event.occurredAtUtc,
        name: event.name,
        outcome: event.outcome,
        errorCode: event.error?.code,
        generation: event.correlation.generation,
        sequence: event.correlation.sequence,
      );

  final String eventId;
  final DateTime occurredAtUtc;
  final String name;
  final ObservabilityOutcome outcome;
  final String? errorCode;
  final int generation;
  final int sequence;
}

final class OperationalBreadcrumbRing {
  OperationalBreadcrumbRing({this.capacity = 128}) {
    if (capacity < 1 || capacity > 4096) {
      throw ArgumentError.value(capacity, 'capacity');
    }
  }

  final int capacity;
  final ListQueue<OperationalBreadcrumb> _items = ListQueue();

  void add(OperationalEvent event) {
    if (_items.length == capacity) {
      _items.removeFirst();
    }
    _items.addLast(OperationalBreadcrumb.fromEvent(event));
  }

  List<OperationalBreadcrumb> snapshot() => List.unmodifiable(_items);
}

final class OperationalSecurityRing {
  OperationalSecurityRing({int capacity = 64})
      : _ring = OperationalBreadcrumbRing(capacity: capacity);

  final OperationalBreadcrumbRing _ring;

  void add(OperationalEvent event) {
    if (event.isSecurity || event.severity == ObservabilitySeverity.fatal) {
      _ring.add(event);
    }
  }

  List<OperationalBreadcrumb> snapshot() => _ring.snapshot();
}
