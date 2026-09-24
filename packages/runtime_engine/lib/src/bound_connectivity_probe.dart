part of pokrov_runtime_engine;

enum RuntimeBoundProbeStage { transport, dns, payload, egress }
enum RuntimeBoundProbeOutcome { pass, fail, unavailable, unknown, cancelled }

/// A native adapter must fence the actual running owner/module/profile both
/// before IO and after settlement. Snapshot health and HTTPS 204 are not receipts.
/// Payload/egress pass requires a fresh authenticated session-bound verifier
/// exchange in the admitted probe set. Destinations never come from a caller URL.
/// Count all network bytes of each diagnostic probe, including DNS, transport
/// handshakes, packet headers and retransmissions. Reserve before IO and join
/// all native work before this Future completes, including cancellation. Core
/// application-byte counts alone cannot prove this bound. Current hosts do not
/// implement this interface; native wire accounting and verifier producers remain open.
abstract interface class RuntimeBoundConnectivityProbe {
  Future<RuntimeBoundProbeResult> probeBoundConnection(RuntimeBoundProbeRequest request, {
    required Future<void> cancelled,
    required Future<void> Function(int count) reserveDiagnosticBytes,
    RuntimePayloadProbeExchange? payloadExchange,
  });
}

/// A payload producer must send this material only through the exact owned Core
/// connection to endpoint, with authenticated HTTPS, redirects/retries disabled
/// and bounded IO. Never log/persist/return bearerToken or bodyJson in receipts.
class RuntimePayloadProbeRequest {
  const RuntimePayloadProbeRequest({required this.endpoint, required this.bearerToken, required this.bodyJson});
  final Uri endpoint;
  final String bearerToken, bodyJson;
  static const maximumResponseBytes = 2048;
  @override
  String toString() => 'RuntimePayloadProbeRequest(redacted)';
}

class RuntimePayloadProbeReceipt {
  const RuntimePayloadProbeReceipt(this.verifierRef, this.receiptRef, this.observedClientIp);
  final String verifierRef, receiptRef;
  final String observedClientIp;
}

/// Session-owned first-party material. takeRequest/acceptResponse are one-shot;
/// their completion is joined by the probe producer. Closing invalidates future
/// use and signals IO cancellation, but does not prove native IO settlement.
/// acceptResponse checks wire binding, not TLS, selected transport or egress.
/// The caller closes the exchange after the native Future settles. A successful
/// producer leaves its accepted receipt available for that caller's comparison.
abstract interface class RuntimePayloadProbeExchange {
  RuntimeBoundProbeRequest get request;
  Future<void> get whenClosed;
  RuntimePayloadProbeReceipt? get receipt;
  Future<RuntimePayloadProbeRequest> takeRequest();
  Future<RuntimePayloadProbeReceipt> acceptResponse({required Uri responseUrl,
    required int statusCode, required List<int> body});
  void close();
}

class RuntimeBoundProbeRequest {
  RuntimeBoundProbeRequest({required Map<String, Object?> binding, required this.stage,
      required this.nonce, required this.budgetStartedAt, required this.budget})
      : binding = Map.unmodifiable(binding) {
    const refs = {'candidate_ref', 'attempt_ref', 'network_context_ref', 'capability_ref', 'profile_ref',
      'core_capability_revision', 'route_policy_ref', 'dns_policy_ref', 'probe_set_ref', 'bootstrap_set_ref',
      'endpoint_ref', 'endpoint_lease_ref'};
    const digests = {'artifact_sha256', 'template_sha256', 'stage_sha256'};
    const other = {'connect_request_id', 'profile_revision', 'generation', 'mode', 'family'};
    if (binding.length != refs.length + digests.length + other.length ||
        !binding.keys.every({...refs, ...digests, ...other}.contains) ||
        refs.any((key) => binding[key] is! String ||
          !RegExp(r'^[a-z][a-z0-9_]{1,23}_[a-f0-9]{16,64}$').hasMatch(binding[key] as String)) ||
        digests.any((key) => binding[key] is! String || !RegExp(r'^[a-f0-9]{64}$').hasMatch(binding[key] as String)) ||
        binding['connect_request_id'] is! String ||
        !RegExp(r'^[a-f0-9]{32}$').hasMatch(binding['connect_request_id'] as String) ||
        binding['profile_revision'] is! int || (binding['profile_revision'] as int) < 1 ||
        (binding['profile_revision'] as int) > 9007199254740991 ||
        binding['generation'] is! int || (binding['generation'] as int) < 0 ||
        (binding['generation'] as int) > 9007199254740991 ||
        !RouteMode.values.any((mode) => mode.name == binding['mode']) ||
        !const {'ipv4', 'ipv6'}.contains(binding['family']) || !RegExp(r'^[a-f0-9]{32}$').hasMatch(nonce) ||
        budget.inMilliseconds <= 0 || budget.inMilliseconds > 86400000 || deadlineElapsedMs > 9007199254740991) {
      throw ArgumentError('bound_probe_request_invalid');
    }
  }

  final Map<String, Object?> binding;
  final RuntimeBoundProbeStage stage;
  final String nonce;
  final RuntimeBootClockSnapshot budgetStartedAt;
  final Duration budget;
  int get deadlineElapsedMs => budgetStartedAt.elapsedMilliseconds + budget.inMilliseconds;

  Map<String, Object?> toWire() => {
    'schema': 1, 'binding': binding, 'stage': stage.name, 'nonce': nonce,
    'boot_ref': budgetStartedAt.bootRef, 'started_elapsed_ms': budgetStartedAt.elapsedMilliseconds,
    'deadline_elapsed_ms': deadlineElapsedMs,
  };

  @override
  String toString() => 'RuntimeBoundProbeRequest(redacted)';
}

class RuntimeBoundProbeResult {
  const RuntimeBoundProbeResult._(this.request, this.outcome, this.observedElapsedMs,
    this.verifierRef, this.receiptRef);
  final RuntimeBoundProbeRequest request;
  final RuntimeBoundProbeOutcome outcome;
  final int observedElapsedMs;
  final String? verifierRef, receiptRef;

  factory RuntimeBoundProbeResult.fromWire(Object? value, {required RuntimeBoundProbeRequest request}) {
    const keys = {'schema', 'request', 'outcome', 'observed_elapsed_ms', 'verifier_ref', 'receipt_ref'};
    if (value is! Map || value.length != keys.length || !value.keys.every(keys.contains) ||
        value['schema'] is! int || value['schema'] != 1 || !_boundProbeEcho(request.toWire(), value['request']) ||
        value['outcome'] is! String || !RuntimeBoundProbeOutcome.values.any((item) => item.name == value['outcome']) ||
        value['observed_elapsed_ms'] is! int) throw StateError('bound_probe_receipt_invalid');
    final observed = value['observed_elapsed_ms'] as int;
    if (observed < request.budgetStartedAt.elapsedMilliseconds || observed >= request.deadlineElapsedMs) {
      throw StateError('bound_probe_receipt_expired');
    }
    for (final key in const ['verifier_ref', 'receipt_ref']) {
      final ref = value[key];
      if (ref != null && (ref is! String || !RegExp(r'^[a-z][a-z0-9_]{1,23}_[a-f0-9]{16,64}$').hasMatch(ref))) {
        throw StateError('bound_probe_receipt_invalid');
      }
    }
    final outcome = RuntimeBoundProbeOutcome.values.byName(value['outcome'] as String);
    if (outcome == RuntimeBoundProbeOutcome.pass &&
        const {RuntimeBoundProbeStage.payload, RuntimeBoundProbeStage.egress}.contains(request.stage) &&
        (value['verifier_ref'] == null || value['receipt_ref'] == null)) {
      throw StateError('bound_probe_verifier_unconfirmed');
    }
    return RuntimeBoundProbeResult._(request, outcome, observed,
      value['verifier_ref'] as String?, value['receipt_ref'] as String?);
  }

  @override
  String toString() => 'RuntimeBoundProbeResult(${outcome.name})';
}

bool _boundProbeEcho(Object? expected, Object? actual) {
  if (expected is Map) return actual is Map && expected.length == actual.length &&
    expected.keys.every((key) => actual.containsKey(key) && _boundProbeEcho(expected[key], actual[key]));
  if (expected is int) return actual is int && expected == actual;
  return expected == actual;
}
