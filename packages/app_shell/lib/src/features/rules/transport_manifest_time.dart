import 'package:pokrov_runtime_engine/runtime_engine.dart';

import '../../../routing_catalog_contract.dart';

/// Server-time interval, accounting for response transit and millisecond sample
/// quantization. Native elapsed time must include suspend on the same OS boot.
class TransportTimeWindow {
  const TransportTimeWindow(this.earliest, this.latest, this.sample);
  final DateTime earliest;
  final DateTime latest;
  final RuntimeBootClockSnapshot sample;
}

class TransportClockDeadline {
  TransportClockDeadline(RuntimeBootClockSnapshot start, Duration remaining)
      : bootRef = start.bootRef,
        startedElapsedMs = start.elapsedMilliseconds,
        expiresElapsedMs = start.elapsedMilliseconds + remaining.inMilliseconds - 1 {
    if (remaining.inMilliseconds <= 1) {
      throw const TransportManifestFailure('transport_budget_exhausted');
    }
  }
  final String bootRef;
  final int startedElapsedMs;
  final int expiresElapsedMs;

  void requireCurrent(RuntimeBootClockSnapshot sample) {
    if (sample.bootRef != bootRef || sample.elapsedMilliseconds < startedElapsedMs ||
        sample.elapsedMilliseconds >= expiresElapsedMs) {
      throw const TransportManifestFailure('transport_budget_exhausted');
    }
  }
}

class TransportTimeAnchor {
  const TransportTimeAnchor._(this.bootRef, this.receivedElapsedMs,
      this.earliestAtReceipt, this.latestAtReceipt);
  final String bootRef;
  final int receivedElapsedMs;
  final DateTime earliestAtReceipt;
  final DateTime latestAtReceipt;

  factory TransportTimeAnchor.fromOnline({required DateTime observedAt,
      required RuntimeBootClockSnapshot sent, required RuntimeBootClockSnapshot received}) {
    if (!observedAt.isUtc || sent.bootRef != received.bootRef ||
        received.elapsedMilliseconds < sent.elapsedMilliseconds) {
      throw const TransportManifestFailure('transport_clock_context_changed');
    }
    // observed_at is truncated to seconds. The full elapsed round trip is a
    // conservative transit bound; do not treat its midpoint as trusted UTC.
    final transit = received.elapsedMilliseconds - sent.elapsedMilliseconds;
    return TransportTimeAnchor._(received.bootRef, received.elapsedMilliseconds,
      observedAt, observedAt.add(Duration(milliseconds: 1000 + transit + 2)));
  }

  factory TransportTimeAnchor.fromRecord(Object? input) {
    if (input is! Map || input.length != 4 || input['boot_ref'] is! String ||
        input['received_elapsed_ms'] is! int || input['earliest_at_receipt'] is! String ||
        input['latest_at_receipt'] is! String) {
      throw const TransportManifestFailure('transport_clock_record_invalid');
    }
    final elapsed = input['received_elapsed_ms'] as int;
    final earliest = DateTime.tryParse(input['earliest_at_receipt'] as String);
    final latest = DateTime.tryParse(input['latest_at_receipt'] as String);
    final boot = input['boot_ref'] as String;
    if (elapsed < 0 || elapsed > 9007199254740991 || boot.length > 64 ||
        !RegExp(r'^(android:[0-9]{1,10}|windows:[a-f0-9]{32}|(?:linux|ios|macos):[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})$').hasMatch(boot) ||
        earliest == null || latest == null || !earliest.isUtc || !latest.isUtc ||
        earliest.toIso8601String() != input['earliest_at_receipt'] ||
        latest.toIso8601String() != input['latest_at_receipt'] || latest.isBefore(earliest)) {
      throw const TransportManifestFailure('transport_clock_record_invalid');
    }
    return TransportTimeAnchor._(boot, elapsed, earliest, latest);
  }

  TransportTimeWindow at(RuntimeBootClockSnapshot sample) {
    if (sample.bootRef != bootRef || sample.elapsedMilliseconds < receivedElapsedMs) {
      throw const TransportManifestFailure('transport_clock_context_changed');
    }
    final elapsed = sample.elapsedMilliseconds - receivedElapsedMs;
    return TransportTimeWindow(
      earliestAtReceipt.add(Duration(milliseconds: elapsed > 0 ? elapsed - 1 : 0)),
      latestAtReceipt.add(Duration(milliseconds: elapsed + 1)), sample);
  }

  Map<String, Object?> toRecord() => {
    'boot_ref': bootRef, 'received_elapsed_ms': receivedElapsedMs,
    'earliest_at_receipt': earliestAtReceipt.toIso8601String(),
    'latest_at_receipt': latestAtReceipt.toIso8601String(),
  };
}
