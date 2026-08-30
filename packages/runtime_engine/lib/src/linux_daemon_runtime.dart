part of '../runtime_engine.dart';

const String pokrovLinuxDaemonProtocol = 'pokrov-linuxd-v1';
const String pokrovLinuxDaemonSocketPath = '/run/pokrov/pokrov-linuxd.sock';

const Set<String> _linuxDaemonActions = <String>{
  'status',
  'initialize',
  'stage_profile',
  'invalidate_profile',
  'connect',
  'disconnect',
  'live_stats',
};

/// Bounded request transport for the privileged Linux service. The production
/// transport uses one authenticated Unix-socket connection per request; tests
/// inject an in-memory transport and never need a privileged process.
abstract interface class LinuxDaemonTransport {
  Future<Map<String, Object?>> invoke(Map<String, Object?> request);
}

final class LinuxUnixSocketTransport implements LinuxDaemonTransport {
  LinuxUnixSocketTransport({
    this.socketPath = pokrovLinuxDaemonSocketPath,
    this.timeout = const Duration(seconds: 8),
    this.maximumResponseBytes = 64 * 1024,
  });

  final String socketPath;
  final Duration timeout;
  final int maximumResponseBytes;

  @override
  Future<Map<String, Object?>> invoke(Map<String, Object?> request) async {
    final action = request['action']?.toString() ?? '';
    if (!_linuxDaemonActions.contains(action)) {
      throw const FormatException('unsupported_linux_daemon_action');
    }
    if (request['protocol'] != pokrovLinuxDaemonProtocol) {
      throw const FormatException('invalid_linux_daemon_protocol');
    }

    final address = InternetAddress(socketPath, type: InternetAddressType.unix);
    Socket? socket;
    try {
      socket = await Socket.connect(address, 0, timeout: timeout);
      final encoded = utf8.encode('${jsonEncode(request)}\n');
      if (encoded.length > 768 * 1024) {
        throw const FormatException('linux_daemon_request_too_large');
      }
      socket.add(encoded);
      await socket.flush();
      final responseLine = await _readBoundedLine(socket).timeout(timeout);
      final decoded = jsonDecode(responseLine);
      if (decoded is! Map) {
        throw const FormatException('invalid_linux_daemon_response');
      }
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    } finally {
      await socket?.close();
    }
  }

  Future<String> _readBoundedLine(Socket socket) {
    final completer = Completer<String>();
    final bytes = <int>[];
    StreamSubscription<List<int>>? subscription;

    void completeError(Object error, [StackTrace? stackTrace]) {
      if (completer.isCompleted) {
        return;
      }
      completer.completeError(error, stackTrace);
      unawaited(subscription?.cancel());
    }

    subscription = socket.listen(
      (chunk) {
        for (final byte in chunk) {
          if (byte == 0x0a) {
            if (!completer.isCompleted) {
              try {
                completer.complete(utf8.decode(bytes, allowMalformed: false));
              } on FormatException catch (error, stackTrace) {
                completer.completeError(error, stackTrace);
              }
              unawaited(subscription?.cancel());
            }
            return;
          }
          bytes.add(byte);
          if (bytes.length > maximumResponseBytes) {
            completeError(
              const FormatException('linux_daemon_response_too_large'),
            );
            return;
          }
        }
      },
      onError: completeError,
      onDone: () {
        if (!completer.isCompleted) {
          completeError(
            const FormatException('linux_daemon_response_incomplete'),
          );
        }
      },
      cancelOnError: true,
    );
    return completer.future;
  }
}

final class LinuxDaemonRuntimeEngine implements PokrovRuntimeEngine {
  LinuxDaemonRuntimeEngine({
    LinuxDaemonTransport? transport,
    DateTime Function()? clock,
  }) : _transport = transport ?? LinuxUnixSocketTransport(),
       _clock = clock ?? DateTime.now;

  final LinuxDaemonTransport _transport;
  final DateTime Function() _clock;
  int _requestSequence = 0;

  @override
  Future<RuntimeSnapshot> snapshot() => _snapshotAction('status');

  @override
  Future<RuntimeSnapshot> initialize() => _snapshotAction('initialize');

  @override
  Future<RuntimeSnapshot> stageManagedProfile(
    ManagedProfilePayload payload,
  ) async {
    final name = payload.profileName.trim();
    final config = payload.configPayload.trim();
    if (!RegExp(r'^[a-zA-Z0-9_.-]{1,80}$').hasMatch(name) ||
        config.isEmpty ||
        utf8.encode(config).length > 512 * 1024) {
      return _failureSnapshot(
        failureKind: 'linux_profile_invalid',
        messageCode: 'profile_invalid',
      );
    }
    return _snapshotAction(
      'stage_profile',
      payload: <String, Object?>{
        'profile_name': name,
        'config_payload': config,
        'route_mode': payload.routeMode.name,
        'core_egress_probe_required': payload.coreEgressProbeRequired,
        'resolved_node_code': _publicRuntimeNodeCode(payload.resolvedNodeCode),
      },
    );
  }

  @override
  Future<RuntimeSnapshot> invalidateManagedProfile() =>
      _snapshotAction('invalidate_profile');

  @override
  Future<RuntimeSnapshot> connect() => _snapshotAction('connect');

  @override
  Future<RuntimeSnapshot> disconnect() => _snapshotAction('disconnect');

  @override
  Future<WarpApplyResult> applyWarp({required bool enabled}) async {
    return const WarpApplyResult.notApplied(
      reason: 'linux_beta_warp_not_available',
    );
  }

  @override
  Future<RuntimeLiveStats> liveStats() async {
    final response = await _invoke('live_stats');
    if (response == null || response['ok'] != true) {
      return const RuntimeLiveStats.unavailable();
    }
    return RuntimeLiveStats.fromMap(response['stats']);
  }

  @override
  Future<RuntimePushToken> pushToken() async {
    return const RuntimePushToken.unavailable();
  }

  Future<RuntimeSnapshot> _snapshotAction(
    String action, {
    Map<String, Object?> payload = const <String, Object?>{},
  }) async {
    final response = await _invoke(action, payload: payload);
    if (response == null) {
      return _failureSnapshot(
        failureKind: 'linux_daemon_unavailable',
        messageCode: 'daemon_unavailable',
      );
    }
    if (response['ok'] != true) {
      return _failureSnapshot(
        failureKind: _linuxFailureKind(response['error_code']),
        messageCode: response['message_code']?.toString() ?? 'runtime_error',
      );
    }
    return _snapshotFromMap(response['snapshot']);
  }

  Future<Map<String, Object?>?> _invoke(
    String action, {
    Map<String, Object?> payload = const <String, Object?>{},
  }) async {
    final requestId = _nextRequestId();
    try {
      final response = await _transport.invoke(<String, Object?>{
        'protocol': pokrovLinuxDaemonProtocol,
        'request_id': requestId,
        'action': action,
        'payload': payload,
      });
      if (response['protocol'] != pokrovLinuxDaemonProtocol ||
          response['request_id'] != requestId ||
          response['ok'] is! bool) {
        return null;
      }
      return response;
    } on Object {
      return null;
    }
  }

  String _nextRequestId() {
    _requestSequence = (_requestSequence + 1) & 0x7fffffff;
    return 'linux-${_clock().toUtc().microsecondsSinceEpoch}-$_requestSequence';
  }

  RuntimeSnapshot _snapshotFromMap(Object? value) {
    final map = _runtimeObjectMap(value);
    if (map.isEmpty) {
      return _failureSnapshot(
        failureKind: 'linux_protocol_invalid',
        messageCode: 'runtime_error',
      );
    }
    final phase = switch (map['phase']?.toString()) {
      'artifact_ready' => RuntimePhase.artifactReady,
      'initialized' => RuntimePhase.initialized,
      'config_staged' => RuntimePhase.configStaged,
      'running' => RuntimePhase.running,
      _ => RuntimePhase.artifactMissing,
    };
    final hostHealth = _linuxHostHealth(map['host_health']);
    final dnsState = _linuxDiagnosticState(map['dns_state']);
    final uplinkState = _linuxDiagnosticState(map['uplink_state']);
    final coreEgressValidated = map['core_egress_validated'] is bool
        ? map['core_egress_validated'] as bool
        : null;
    return RuntimeSnapshot(
      hostPlatform: HostPlatform.linux,
      lane: RuntimeLane.linuxDaemon,
      phase: phase,
      artifactDirectory: null,
      coreBinaryPath: null,
      helperBinaryPath: null,
      stagedConfigPath: null,
      supportsLiveConnect: _runtimeBool(map['supports_live_connect']),
      canInitialize: _runtimeBool(map['can_initialize']),
      canConnect: _runtimeBool(map['can_connect']),
      message: _linuxRuntimeMessage(map['message_code']),
      hostHealth: hostHealth,
      dnsState: dnsState,
      uplinkState: uplinkState,
      hostDiagnosticsSummary: _linuxHostSummary(map['host_stack']),
      dnsReady: map['dns_ready'] is bool ? map['dns_ready'] as bool : null,
      coreEgressValidated: coreEgressValidated,
      coreEgressValidationRequired: true,
      lastFailureKind: _linuxNullableFailureKind(map['last_failure_kind']),
      lastStopReason: _publicRuntimeStopReason(map['last_stop_reason']),
      ipv4RouteCount: _runtimeNullableInt(map['ipv4_route_count']),
      ipv6RouteCount: _runtimeNullableInt(map['ipv6_route_count']),
      connectionPending: _runtimeBool(map['connection_pending']),
    );
  }

  RuntimeSnapshot _failureSnapshot({
    required String failureKind,
    required String messageCode,
  }) {
    return RuntimeSnapshot(
      hostPlatform: HostPlatform.linux,
      lane: RuntimeLane.linuxDaemon,
      phase: RuntimePhase.artifactMissing,
      artifactDirectory: null,
      coreBinaryPath: null,
      helperBinaryPath: null,
      stagedConfigPath: null,
      supportsLiveConnect: false,
      canInitialize: false,
      canConnect: false,
      message: _linuxRuntimeMessage(messageCode),
      hostHealth: RuntimeHostHealth.degraded,
      dnsState: RuntimeDiagnosticState.unknown,
      uplinkState: RuntimeDiagnosticState.unknown,
      coreEgressValidationRequired: true,
      lastFailureKind: failureKind,
    );
  }
}

RuntimeHostHealth _linuxHostHealth(Object? value) =>
    switch (value?.toString()) {
      'healthy' => RuntimeHostHealth.healthy,
      'degraded' => RuntimeHostHealth.degraded,
      _ => RuntimeHostHealth.unknown,
    };

RuntimeDiagnosticState _linuxDiagnosticState(Object? value) =>
    switch (value?.toString()) {
      'healthy' => RuntimeDiagnosticState.healthy,
      'degraded' => RuntimeDiagnosticState.degraded,
      _ => RuntimeDiagnosticState.unknown,
    };

String _linuxFailureKind(Object? value) =>
    _linuxNullableFailureKind(value) ?? 'linux_runtime_error';

String? _linuxNullableFailureKind(Object? value) {
  final candidate = value?.toString().trim().toLowerCase() ?? '';
  return const <String>{
        'linux_authorization_denied',
        'linux_daemon_unavailable',
        'linux_host_unsupported',
        'linux_live_connect_unavailable',
        'linux_profile_invalid',
        'linux_protocol_invalid',
        'linux_runtime_error',
      }.contains(candidate)
      ? candidate
      : null;
}

String _linuxRuntimeMessage(Object? value) => switch (value?.toString()) {
  'ready' => 'Системная служба Linux готова.',
  'profile_staged' => 'Профиль подготовлен системной службой.',
  'connected' => 'Защищено. DNS и выход через VPN проверены.',
  'stopped' => 'Соединение остановлено, сеть восстановлена.',
  'authorization_required' => 'Подтвердите системное действие Linux.',
  'authorization_denied' => 'Система не разрешила управление VPN.',
  'host_unsupported' => 'Эта Linux-среда не входит в проверенную beta-матрицу.',
  'profile_invalid' => 'Профиль Linux отклонен до запуска.',
  'live_connect_unavailable' =>
    'В этой beta-сборке нет проверенного Linux runtime; подключение заблокировано.',
  'daemon_unavailable' => 'Системная служба POKROV Linux не отвечает.',
  _ => 'Системная служба Linux вернула безопасный отказ.',
};

String? _linuxHostSummary(Object? value) {
  final stack = _runtimeObjectMap(value);
  if (stack.isEmpty) {
    return null;
  }
  final labels = <String>[
    'systemd ${_runtimeBool(stack['systemd']) ? 'готов' : 'нет'}',
    'NetworkManager ${_runtimeBool(stack['network_manager']) ? 'готов' : 'нет'}',
    'resolved ${_runtimeBool(stack['resolved']) ? 'готов' : 'нет'}',
    'nftables ${_runtimeBool(stack['nftables']) ? 'готов' : 'нет'}',
    'Core ${_runtimeBool(stack['core_artifact']) ? 'готов' : 'нет'}',
  ];
  return labels.join(' | ');
}
