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
}

class RuntimeCandidateProbeResult {
  const RuntimeCandidateProbeResult({
    required this.success,
    required this.failureKind,
    required this.duration,
  });
  final bool success;
  final String failureKind;
  final Duration duration;

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
        networkAvailable: value['network_available'] is bool
            ? value['network_available'] as bool
            : null,
        captivePortal: value['captive_portal'] is bool
            ? value['captive_portal'] as bool
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
    var configContent = payload.warpPolicy.canEnableRuntime
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
      return RuntimeCandidateProbeResult.unavailable;
    } on PlatformException {
      return RuntimeCandidateProbeResult.unavailable;
    }
    if (value is String) {
      try {
        value = jsonDecode(value);
      } on FormatException {
        return RuntimeCandidateProbeResult.unavailable;
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
      'tls_failed',
      'unexpected_status',
      'timeout',
      'cancelled',
      'network_changed',
      'duplicate_probe'
    };
    if (value is! Map ||
        value['success'] is! bool ||
        value['duration_ms'] is! int ||
        (value['duration_ms'] as int) < 0 ||
        !failureKinds.contains(value['failure_kind']) ||
        (value['success'] == true) != (value['failure_kind'] == '')) {
      return RuntimeCandidateProbeResult.unavailable;
    }
    return RuntimeCandidateProbeResult(
        success: value['success'] as bool,
        failureKind: value['failure_kind'] as String,
        duration: Duration(milliseconds: value['duration_ms'] as int));
  }

  @override
  Future<void> cancelCandidateProbe(String probeId) async {
    await _channel.invokeMethod<void>(
        'runtimeEngine.cancelCandidateProbe', {'probeId': probeId});
  }
}
