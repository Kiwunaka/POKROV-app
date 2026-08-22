import 'dart:async';

import 'model.dart';
import 'queue.dart';
import 'store.dart';

enum OperationalEmitResult {
  accepted,
  droppedByPressure,
  rejectedByPrivacy,
  rejectedAsStale,
}

final class OperationalSequenceFence {
  int _activeGeneration = 0;
  int _lastSequence = -1;

  int get activeGeneration => _activeGeneration;
  int get lastSequence => _lastSequence;

  void activateGeneration(int generation) {
    if (generation < _activeGeneration || generation < 0) {
      throw ArgumentError.value(generation, 'generation');
    }
    if (generation > _activeGeneration) {
      _activeGeneration = generation;
      _lastSequence = -1;
    }
  }

  bool accept(OperationalCorrelation correlation) {
    if (correlation.generation != _activeGeneration ||
        correlation.sequence <= _lastSequence) {
      return false;
    }
    _lastSequence = correlation.sequence;
    return true;
  }
}

final class OperationalPipelineSnapshot {
  const OperationalPipelineSnapshot({
    required this.queue,
    required this.rejectedByPrivacy,
    required this.rejectedAsStale,
    required this.writerErrors,
    required this.flushes,
    required this.rotations,
    required this.truncatedTailRecoveries,
  });

  final OperationalQueueSnapshot queue;
  final int rejectedByPrivacy;
  final int rejectedAsStale;
  final int writerErrors;
  final int flushes;
  final int rotations;
  final int truncatedTailRecoveries;
}

final class OperationalEventDispatcher {
  OperationalEventDispatcher({
    required this.writer,
    BoundedOperationalEventQueue? queue,
    OperationalEventSerializer serializer = const OperationalEventSerializer(),
    OperationalBreadcrumbRing? breadcrumbs,
    OperationalSecurityRing? securityEvents,
    OperationalSequenceFence? sequenceFence,
    this.batchSize = 64,
  })  : queue = queue ?? BoundedOperationalEventQueue(),
        serializer = serializer,
        breadcrumbs = breadcrumbs ?? OperationalBreadcrumbRing(),
        securityEvents = securityEvents ?? OperationalSecurityRing(),
        sequenceFence = sequenceFence ?? OperationalSequenceFence() {
    if (batchSize < 1 || batchSize > 512) {
      throw ArgumentError.value(batchSize, 'batchSize');
    }
  }

  final OperationalEventWriter writer;
  final BoundedOperationalEventQueue queue;
  final OperationalEventSerializer serializer;
  final OperationalBreadcrumbRing breadcrumbs;
  final OperationalSecurityRing securityEvents;
  final OperationalSequenceFence sequenceFence;
  final int batchSize;
  Future<void>? _drainFuture;
  int _rejectedByPrivacy = 0;
  int _rejectedAsStale = 0;
  int _writerErrors = 0;
  int _flushes = 0;

  OperationalEmitResult emit(OperationalEvent event) {
    if (!sequenceFence.accept(event.correlation)) {
      _rejectedAsStale += 1;
      return OperationalEmitResult.rejectedAsStale;
    }
    late final SerializedOperationalEvent record;
    try {
      record = serializer.serialize(event);
    } on FormatException {
      _rejectedByPrivacy += 1;
      return OperationalEmitResult.rejectedByPrivacy;
    }
    breadcrumbs.add(event);
    securityEvents.add(event);
    if (!queue.tryAdd(record)) {
      return OperationalEmitResult.droppedByPressure;
    }
    _scheduleDrain();
    return OperationalEmitResult.accepted;
  }

  Future<void> flush() async {
    while (_drainFuture != null || !queue.isEmpty) {
      _scheduleDrain();
      final pending = _drainFuture;
      if (pending != null) {
        await pending;
      }
    }
  }

  OperationalPipelineSnapshot snapshot() {
    final rotating = writer is RotatingOperationalJsonlStore
        ? writer as RotatingOperationalJsonlStore
        : null;
    return OperationalPipelineSnapshot(
      queue: queue.snapshot(),
      rejectedByPrivacy: _rejectedByPrivacy,
      rejectedAsStale: _rejectedAsStale,
      writerErrors: _writerErrors,
      flushes: rotating?.flushes ?? _flushes,
      rotations: rotating?.rotations ?? 0,
      truncatedTailRecoveries: rotating?.truncatedTailRecoveries ?? 0,
    );
  }

  void _scheduleDrain() {
    if (_drainFuture != null || queue.isEmpty) {
      return;
    }
    late final Future<void> future;
    future = Future<void>(_drain).whenComplete(() {
      if (identical(_drainFuture, future)) {
        _drainFuture = null;
      }
      if (!queue.isEmpty) {
        _scheduleDrain();
      }
    });
    _drainFuture = future;
  }

  Future<void> _drain() async {
    while (!queue.isEmpty) {
      final batch = queue.takeBatch(maximum: batchSize);
      try {
        await writer.appendBatch(batch);
        _flushes += 1;
      } on Object {
        _writerErrors += 1;
        return;
      }
    }
  }
}
