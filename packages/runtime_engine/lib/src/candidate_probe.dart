part of '../runtime_engine.dart';

/// An isolated outbound probe. Neither probing nor cancellation owns the TUN.
abstract interface class RuntimeCandidateProbing {
  Future<RuntimeCandidateNetwork> readCandidateNetwork();
  Future<RuntimeCandidateProbeResult> probeCandidate({
    required String probeId,
    required ManagedProfilePayload payload,
    required Duration timeout,
    required String expectedNetworkContext,
  });

  /// Completes after the native worker and its sockets have settled.
  Future<void> cancelCandidateProbe(String probeId);
}

abstract interface class RuntimeNetworkAvailability {
  Future<RuntimeNetworkStatusObservation> readNetworkAvailability();
}

class RuntimeNetworkStatusObservation {
  const RuntimeNetworkStatusObservation(
      {this.networkAvailable, this.captivePortal});
  final bool? networkAvailable;
  final bool? captivePortal;
}

class RuntimeCandidateNetwork extends RuntimeNetworkStatusObservation {
  const RuntimeCandidateNetwork({
    this.selectionKey,
    this.contextRef,
    this.networkClass,
    this.mccMnc,
    this.carrierName,
    this.ipv6Available,
    super.networkAvailable,
    super.captivePortal,
  });

  /// Opaque identity of the current physical uplink, stable across DNS changes.
  final String? selectionKey;

  /// Changes when network state relevant to an in-flight probe changes.
  final String? contextRef;

  /// Physical uplink class reported by the host, if known.
  final String? networkClass;

  /// Cellular MCC-MNC reported by Android; absent on other uplinks.
  final String? mccMnc;

  /// Cellular operator name reported by Android, when available.
  final String? carrierName;

  /// Usable IPv6 source and default route on the captured physical uplink.
  /// Null means the host could not determine that capability.
  final bool? ipv6Available;
}

class RuntimeCandidateProbeResult {
  const RuntimeCandidateProbeResult({
    required this.success,
    required this.failureKind,
    required this.duration,
    this.probeStage,
    this.http64kFailure,
    this.http64kObservation,
    this.probeError,
  });
  final bool success;
  final String failureKind;
  final Duration duration;
  final String? probeStage;
  final String? http64kFailure;
  final Map<String, Object>? http64kObservation;
  final Map<String, Object>? probeError;

  static Map<String, Object>? awgFromWire(Object? value) {
    const counters = {'handshake_initiations', 'handshake_errors', 'handshake_responses', 'handshake_retries'};
    if (value is! Map || value.length != 5 ||
        !const {'not_started', 'lookup', 'resolved', 'failed', 'not_needed'}.contains(value['destination_dns']) ||
        counters.any((key) => value[key] is! int || (value[key] as int) < 0 || (value[key] as int) > 4)) return null;
    return Map<String, Object>.unmodifiable(value.cast<String, Object>());
  }

  static Map<String, Object>? probeErrorFromWire(Object? value, {bool allowPrimary = true}) {
    const required = {'operation', 'cause', 'cancel_state', 'target', 'request',
      'elapsed_ms', 'stage_started_ms', 'duration_ms'};
    if (value is! Map || !value.keys.toSet().containsAll(required) ||
        value.keys.any((key) => !required.contains(key) && key != 'status' && key != 'os_error_code' && !(allowPrimary && (key == 'primary_error' || key == 'awg'))) ||
        !const {'dial', 'tls', 'write', 'read_headers', 'read_body', 'validate_response'}.contains(value['operation']) ||
        !const {'io', 'timeout', 'cancelled', 'eof', 'unexpected_eof', 'closed', 'dns', 'tls_certificate', 'invalid_response'}.contains(value['cause']) ||
        !const {'active', 'deadline', 'cancelled'}.contains(value['cancel_state']) ||
        !const {'owned_api', 'owned_reserve'}.contains(value['target']) ||
        !const {'egress_204', 'egress_64k'}.contains(value['request']) ||
        const ['elapsed_ms', 'stage_started_ms', 'duration_ms'].any((key) =>
          value[key] is! int || (value[key] as int) < 0 || (value[key] as int) > 86400000) ||
        (value['stage_started_ms'] as int) > (value['duration_ms'] as int) ||
        (value['elapsed_ms'] as int) > (value['duration_ms'] as int) ||
        value.containsKey('status') && (value['status'] is! int || (value['status'] as int) < 100 || (value['status'] as int) > 599) ||
        value.containsKey('os_error_code') && (value['os_error_code'] is! int || (value['os_error_code'] as int) < 1 || (value['os_error_code'] as int) > 2147483647)) return null;
    final primary = value.containsKey('primary_error')
        ? probeErrorFromWire(value['primary_error'], allowPrimary: false) : null;
    if (value.containsKey('primary_error') && (primary == null || value['target'] != 'owned_reserve' ||
        primary['target'] != 'owned_api' || (primary['duration_ms'] as int) > (value['duration_ms'] as int))) return null;
    final awg = value.containsKey('awg') ? awgFromWire(value['awg']) : null;
    if (value.containsKey('awg') && awg == null) return null;
    return Map<String, Object>.unmodifiable({...value.cast<String, Object>(),
      if (primary != null) 'primary_error': primary, if (awg != null) 'awg': awg});
  }

  static Map<String, Object>? http64kObservationFromWire(Object? value) {
    if (value is! Map || value.length != 4 ||
        !const {'owned_api', 'owned_reserve'}.contains(value['target']) || value['status'] != 200 ||
        value['status'] is! int || value['received_bytes'] is! int ||
        (value['received_bytes'] as int) < 0 || (value['received_bytes'] as int) >= 65536 ||
        value['expected_bytes'] is! int || value['expected_bytes'] != 65536) return null;
    return Map<String, Object>.unmodifiable({'target': value['target'] as String,
      'status': value['status'] as int, 'received_bytes': value['received_bytes'] as int, 'expected_bytes': 65536});
  }

  static const http64kFailures = {
    'write_error', 'header_error', 'body_short', 'body_read_error',
  };

  static const probeStages = {
    'parse_profile', 'create_instance', 'start_instance', 'select_outbound',
    'proxy_dial', 'egress_check', 'tls_handshake', 'tls_read', 'tls_write',
    'tls_processing', 'tls_certificate_verified', 'tls_complete', 'http_204',
    'http_64k',
  };

  // These receipts identify a local boundary, even if cancellation was requested
  // while it settled. They must not become a claimed Core probe timeout.
  static const localFailureKinds = {
    'cancelled_before_dispatch', 'probe_adapter_failed',
    'probe_channel_rejected', 'probe_reply_invalid',
  };

  static const adapterFailed = RuntimeCandidateProbeResult(
    success: false, failureKind: 'probe_adapter_failed', duration: Duration.zero);
  static const channelRejected = RuntimeCandidateProbeResult(
    success: false, failureKind: 'probe_channel_rejected', duration: Duration.zero);
  static const replyInvalid = RuntimeCandidateProbeResult(
    success: false, failureKind: 'probe_reply_invalid', duration: Duration.zero);

  static const unavailable = RuntimeCandidateProbeResult(
    success: false,
    failureKind: 'unavailable',
    duration: Duration.zero,
  );
}

mixin _CandidateProbeChannel
    implements RuntimeCandidateProbing, RuntimeNetworkAvailability {
  static const _channel = MethodChannel('space.pokrov/runtime_engine');
  HostPlatform get hostPlatform;

  @override
  Future<RuntimeCandidateNetwork> readCandidateNetwork() async {
    try {
      final value = await _channel
          .invokeMethod<Object?>('runtimeEngine.candidateNetwork');
      if (value is! Map) return const RuntimeCandidateNetwork();
      final carrier = value['carrier'];
      return RuntimeCandidateNetwork(
        selectionKey: value['selection_key'] is String
            ? value['selection_key'] as String
            : null,
        contextRef: value['context_ref'] is String
            ? value['context_ref'] as String
            : null,
        networkClass: const {'cellular', 'wifi', 'ethernet', 'other'}
                .contains(value['network_class'])
            ? value['network_class'] as String
            : null,
        mccMnc: value['mcc_mnc'] is String &&
                RegExp(r'^\d{5,6}$').hasMatch(value['mcc_mnc'] as String)
            ? value['mcc_mnc'] as String
            : null,
        carrierName: value['network_class'] == 'cellular' && carrier is String &&
                carrier.trim().isNotEmpty && carrier.trim().length <= 80 &&
                !RegExp(r'[\x00-\x1f\x7f]').hasMatch(carrier)
            ? carrier.trim()
            : null,
        networkAvailable: value['network_available'] is bool
            ? value['network_available'] as bool
            : null,
        captivePortal: value['captive_portal'] is bool
            ? value['captive_portal'] as bool
            : null,
        ipv6Available: value['ipv6_available'] is bool
            ? value['ipv6_available'] as bool
            : null,
      );
    } on MissingPluginException {
      return const RuntimeCandidateNetwork();
    } on PlatformException {
      return const RuntimeCandidateNetwork();
    }
  }

  @override
  Future<RuntimeNetworkStatusObservation> readNetworkAvailability() =>
      readCandidateNetwork();

  @override
  Future<RuntimeCandidateProbeResult> probeCandidate({
    required String probeId,
    required ManagedProfilePayload payload,
    required Duration timeout,
    required String expectedNetworkContext,
  }) async {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(probeId) ||
        timeout.inMilliseconds < 1 ||
        timeout.inMilliseconds > 30000 ||
        expectedNetworkContext.isEmpty) {
      throw ArgumentError('invalid_candidate_probe_request');
    }
    String configContent;
    try {
      configContent = payload.warpPolicy.canEnableRuntime
          ? _materializePokrovCoreConfig(
              payload.configPayload, payload.warpPolicy)
          : payload.configPayload;
      if (hostPlatform == HostPlatform.windows &&
          payload.routeMode == RouteMode.selectedApps) {
        final config = jsonDecode(configContent) as Map<String, dynamic>;
        final route = config['route'] as Map<String, dynamic>;
        for (final rule in (route['rules'] as List).whereType<Map>()) {
          final processNames = rule['process_name'];
          final outbound = rule['outbound'];
          if (processNames is List &&
              processNames.isNotEmpty &&
              outbound is String &&
              outbound.isNotEmpty) {
            route['final'] = outbound;
            break;
          }
        }
        configContent = jsonEncode(config);
      }
    } on Object {
      return RuntimeCandidateProbeResult.adapterFailed;
    }
    Object? value;
    try {
      value =
          await _channel.invokeMethod<Object?>('runtimeEngine.probeCandidate', {
        'configContent': configContent,
        'probeId': probeId,
        'timeoutMs': timeout.inMilliseconds,
        'expectedNetworkContext': expectedNetworkContext,
      });
    } on MissingPluginException {
      return RuntimeCandidateProbeResult.channelRejected;
    } on PlatformException {
      return RuntimeCandidateProbeResult.channelRejected;
    } on Object {
      return RuntimeCandidateProbeResult.adapterFailed;
    }
    if (value is String) {
      try {
        value = jsonDecode(value);
      } on FormatException {
        return RuntimeCandidateProbeResult.replyInvalid;
      }
    }
    const failureKinds = {
      '',
      'invalid_request',
      'invalid_profile',
      'unavailable',
      'start_failed',
      'probe_failed',
      'connect_failed',
      'data_stalled',
      'tls_failed',
      'unexpected_status',
      'timeout',
      'cancelled',
      'cancelled_before_dispatch',
      'network_changed',
      'duplicate_probe'
    };
    if (value is! Map ||
        value['success'] is! bool ||
        value['duration_ms'] is! int ||
        (value['duration_ms'] as int) < 0 ||
        !failureKinds.contains(value['failure_kind']) ||
        (value['success'] == true) != (value['failure_kind'] == '')) {
      return RuntimeCandidateProbeResult.replyInvalid;
    }
    return RuntimeCandidateProbeResult(
        success: value['success'] as bool,
        failureKind: value['failure_kind'] as String,
        duration: Duration(milliseconds: value['duration_ms'] as int),
        probeError: value['success'] == false ? RuntimeCandidateProbeResult.probeErrorFromWire(value['probe_error']) : null,
        probeStage: RuntimeCandidateProbeResult.probeStages.contains(value['stage'])
            ? value['stage'] as String : null,
        http64kFailure: value['failure_kind'] == 'probe_failed' && value['stage'] == 'http_64k' &&
                RuntimeCandidateProbeResult.http64kFailures.contains(value['http_64k_failure'])
            ? value['http_64k_failure'] as String : null,
        http64kObservation: value['failure_kind'] == 'probe_failed' && value['stage'] == 'http_64k' &&
                const {'body_short', 'body_read_error'}.contains(value['http_64k_failure'])
            ? RuntimeCandidateProbeResult.http64kObservationFromWire(value['http_64k_observation']) : null);
  }

  @override
  Future<void> cancelCandidateProbe(String probeId) async {
    await _channel.invokeMethod<void>(
        'runtimeEngine.cancelCandidateProbe', {'probeId': probeId});
  }
}
