part of '../runtime_engine.dart';

const String pokrovLinuxDaemonProtocol = 'pokrov-linuxd-v1';
const String pokrovLinuxDaemonSocketPath = '/run/pokrov/pokrov-linuxd.sock';

const Set<String> _linuxDaemonActions = <String>{
	'clock_snapshot',
  'read_network_context',
  'status',
  'initialize',
  'stage_profile',
  'stage_bound_profile',
  'invalidate_profile',
  'connect',
  'connect_with_identity',
  'cancel_connect',
  'promote_transport_lease',
  'revoke_transport_lease',
  'disconnect',
  'live_stats',
};

/// Bounded request transport for the privileged Linux service. The production
/// transport uses one authenticated Unix-socket connection per request; tests
/// inject an in-memory transport and never need a privileged process.
abstract interface class LinuxDaemonTransport {
  Future<Map<String, Object?>> invoke(Map<String, Object?> request, {Future<void>? cancelled});
}

// Produced only when the socket transport has not written any request bytes.
final class _LinuxConnectNotDispatched implements Exception {
  const _LinuxConnectNotDispatched();
}

final class LinuxUnixSocketTransport implements LinuxDaemonTransport {
  LinuxUnixSocketTransport({
    this.socketPath = pokrovLinuxDaemonSocketPath,
    // Allow the daemon's 60s polkit decision, 30s connect and 30s cleanup
    // budgets plus its host probe; a valid mutation must retain its response.
    this.timeout = const Duration(seconds: 130),
    this.maximumResponseBytes = 64 * 1024,
  });

  final String socketPath;
  final Duration timeout;
  final int maximumResponseBytes;

  @override
  Future<Map<String, Object?>> invoke(Map<String, Object?> request, {Future<void>? cancelled}) async {
    final action = request['action']?.toString() ?? '';
    if (!_linuxDaemonActions.contains(action)) {
      throw const FormatException('unsupported_linux_daemon_action');
    }
    if (request['protocol'] != pokrovLinuxDaemonProtocol) {
      throw const FormatException('invalid_linux_daemon_protocol');
    }

    final address = InternetAddress(socketPath, type: InternetAddressType.unix);
    Socket? socket;
    ConnectionTask<Socket>? pendingConnection;
    var cancellationRequested = false;
    var requestSent = false;
    var cancellationSent = false;
    var finished = false;
    void sendCancellation() {
      if (finished || !requestSent || cancellationSent || !cancellationRequested) return;
      cancellationSent = true;
      try {
        // The trailer belongs to this socket's connect, never another request.
        socket!.add(const [0x03]);
      } on Object {
        socket?.destroy();
      }
    }
    if (action == 'connect' || action == 'connect_with_identity') {
      cancelled?.then((_) {
        if (finished) return;
        cancellationRequested = true;
        if (!requestSent) pendingConnection?.cancel();
        sendCancellation();
      });
    }
    try {
      pendingConnection = await Socket.startConnect(address, 0);
      final connected = pendingConnection.socket.then((value) {
        if (finished || cancellationRequested) {
          value.destroy();
          throw StateError('linux_operation_cancelled');
        }
        return value;
      });
      if (cancellationRequested) pendingConnection.cancel();
      socket = await connected.timeout(timeout);
      if (cancellationRequested) throw StateError('linux_operation_cancelled');
      final encoded = utf8.encode('${jsonEncode(request)}\n');
      if (encoded.length > 768 * 1024) {
        throw const FormatException('linux_daemon_request_too_large');
      }
      requestSent = true;
      socket.add(encoded);
      sendCancellation();
      await socket.flush();
      final responseLine = await _readBoundedLine(socket).timeout(timeout);
      final decoded = jsonDecode(responseLine);
      if (decoded is! Map) {
        throw const FormatException('invalid_linux_daemon_response');
      }
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    } on Object {
      if (action == 'connect_with_identity' && !requestSent) {
        throw const _LinuxConnectNotDispatched();
      }
      rethrow;
    } finally {
      finished = true;
      pendingConnection?.cancel();
      socket?.destroy();
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

final class LinuxDaemonRuntimeEngine implements PokrovRuntimeEngine, RuntimeConnectCancellation, RuntimeConnectSettlement, RuntimeBootClock, RuntimeTransportNetworkContext, RuntimeCoreIdentityConnect, RuntimeCoreIdentityStage, RuntimeTransportLeaseHandoff, RuntimeTransportLeaseRevocation {
  LinuxDaemonRuntimeEngine({
    LinuxDaemonTransport? transport,
    DateTime Function()? clock,
  }) : _transport = transport ?? LinuxUnixSocketTransport(),
       _clock = clock ?? DateTime.now;

  final LinuxDaemonTransport _transport;
  final DateTime Function() _clock;
  int _requestSequence = 0;
  String? _activeConnectRequestId;
  Completer<void>? _connectCancellation;
  String? _boundConnectRequestId;
  Future<void>? _boundConnectOperationSettled;
  String? _lastStoppedConnectRequestId;
  final _connectSnapshots = Expando<String>('linux-connect-request');

  @override
  String? get activeConnectRequestId => _activeConnectRequestId;

  @override
  String? connectRequestForSnapshot(RuntimeSnapshot snapshot) => _connectSnapshots[snapshot];

  @override
  Future<RuntimeSnapshot> promoteBoundTransportLease({
    required String requestId,
    required String profileDigest,
    required String endpointLeaseRef,
    required DateTime issuedAt,
    required DateTime newFlowsUntil,
    required DateTime activeFlowsUntil,
  }) async {
    if (_boundConnectRequestId != requestId || _activeConnectRequestId != requestId ||
        _connectCancellation?.isCompleted != false ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(profileDigest) ||
        !RegExp(r'^lease_[a-f0-9]{32}$').hasMatch(endpointLeaseRef)) {
      throw StateError('linux_transport_lease_handoff_unavailable');
    }
    final response = await _invoke('promote_transport_lease', payload: {
      'connect_request_id': requestId, 'profile_digest': profileDigest,
      'endpoint_lease_ref': endpointLeaseRef, 'issued_at': _transportLeaseUtc(issuedAt),
      'new_flows_until': _transportLeaseUtc(newFlowsUntil),
      'active_flows_until': _transportLeaseUtc(activeFlowsUntil),
    });
    final receipt = response?['transport_lease_handoff'];
    if (_boundConnectRequestId != requestId || _activeConnectRequestId != requestId ||
        _connectCancellation?.isCompleted != false || response == null || response['ok'] != true ||
        response.length != 5 || receipt is! Map || receipt.length != 3 ||
        receipt['schema'] != 1 || receipt['connect_request_id'] != requestId ||
        receipt['endpoint_lease_ref'] != endpointLeaseRef) {
      throw StateError('linux_transport_lease_handoff_unconfirmed');
    }
    final native = _snapshotFromMap(response['snapshot']);
    if (native.phase != RuntimePhase.running || native.transportProofPending != false ||
        native.transportLeaseActive != true ||
        native.effectiveProfileDigest != profileDigest) {
      throw StateError('linux_transport_lease_handoff_unconfirmed');
    }
    _connectSnapshots[native] = requestId;
    return native;
  }

  @override
  Future<RuntimeSnapshot> revokeBoundTransportLease({
    required String requestId,
    required String profileDigest,
    required String endpointLeaseRef,
    required bool terminateActive,
  }) async {
    if (_boundConnectRequestId != requestId || _activeConnectRequestId != requestId ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(profileDigest) ||
        !RegExp(r'^lease_[a-f0-9]{32}$').hasMatch(endpointLeaseRef)) {
      throw StateError('linux_transport_lease_revocation_unavailable');
    }
    final response = await _invoke('revoke_transport_lease', payload: {
      'connect_request_id': requestId, 'profile_digest': profileDigest,
      'endpoint_lease_ref': endpointLeaseRef, 'terminate_active': terminateActive,
    });
    final receipt = response?['transport_lease_revocation'];
    if (_boundConnectRequestId != requestId || _activeConnectRequestId != requestId ||
        response == null || response['ok'] != true || response.length != 5 ||
        receipt is! Map || receipt.length != 4 || receipt['schema'] != 1 ||
        receipt['connect_request_id'] != requestId ||
        receipt['endpoint_lease_ref'] != endpointLeaseRef ||
        receipt['terminate_active'] != terminateActive) {
      throw StateError('linux_transport_lease_revocation_unconfirmed');
    }
    final native = _snapshotFromMap(response['snapshot']);
    if (native.phase != RuntimePhase.running || native.coreEgressValidated != false ||
        (terminateActive && (native.transportProofPending != true || native.transportLeaseActive != false)) ||
        native.effectiveProfileDigest != profileDigest) {
      throw StateError('linux_transport_lease_revocation_unconfirmed');
    }
    _connectSnapshots[native] = requestId;
    return native;
  }

  @override
  Future<void> cancelConnectRequest(String requestId) async {
    if (_activeConnectRequestId != requestId) return;
    final cancellation = _connectCancellation;
    if (cancellation != null && !cancellation.isCompleted) cancellation.complete();
    if (_boundConnectRequestId == requestId) {
      if (!await cancelAndConfirmConnectStopped(requestId)) {
        throw StateError('core_identity_connect_cancel_unconfirmed');
      }
    }
  }

  @override
  Future<bool> cancelAndConfirmConnectStopped(String requestId) async {
    if (_boundConnectRequestId != requestId) return _lastStoppedConnectRequestId == requestId;
    final cancellation = _connectCancellation;
    if (cancellation != null && !cancellation.isCompleted) cancellation.complete();
    // A raced cancellation Future must not release unfinished clock/socket work.
    await _boundConnectOperationSettled;
    if (_boundConnectRequestId != requestId) return _lastStoppedConnectRequestId == requestId;
    if (!await _cancelBoundConnect(requestId)) return false;
    _releaseBoundConnect(requestId);
    return true;
  }

  void _releaseBoundConnect(String requestId) {
    if (_boundConnectRequestId != requestId) return;
    _lastStoppedConnectRequestId = requestId;
    _boundConnectRequestId = null;
    _boundConnectOperationSettled = null;
    if (_activeConnectRequestId == requestId) {
      _activeConnectRequestId = null;
      _connectCancellation = null;
    }
  }

  Future<bool> _cancelBoundConnect(String requestId) async {
    final response = await _invoke('cancel_connect', payload: {
      'connect_request_id': requestId,
    });
    if (response == null || response['ok'] != true || response.length != 4) {
      throw StateError('core_identity_connect_cancel_unconfirmed');
    }
    final settled = _connectStoppedReceipt(response['connect_cancellation'], requestId);
    if (settled == null) throw StateError('core_identity_connect_cancel_unconfirmed');
    return settled;
  }

  bool? _connectStoppedReceipt(Object? receipt, String requestId) {
    if (receipt is! Map || receipt.length != 3 || receipt['schema'] is! int ||
        receipt['schema'] != 1 || receipt['connect_request_id'] != requestId ||
        receipt['settled'] is! bool) {
      return null;
    }
    return receipt['settled'] as bool;
  }

  @override
  Future<RuntimeSnapshot> snapshot() => _snapshotAction('status');

  @override
  Future<RuntimeSnapshot> initialize() => _snapshotAction('initialize');

  @override
  Future<RuntimeSnapshot> stageManagedProfile(
    ManagedProfilePayload payload,
  ) => _stageManagedProfile(payload);

  @override
  Future<RuntimeSnapshot> stageWithCoreIdentity(ManagedProfilePayload payload, {
    required String expectedCoreModuleSha256,
    required Future<String> Function(String identityInput, RuntimeSnapshot current) bindIdentity,
    required bool Function() operationIsCurrent,
    Future<String> Function(String identityInput, RuntimeSnapshot current)? persistRestrictions,
  }) {
    // Linux has no catalog/Smart Access restriction persistence protocol yet.
    if (persistRestrictions != null || !payload.materializedForRuntime) {
      throw StateError('core_identity_stage_unsupported');
    }
    return _stageManagedProfile(payload, expectedCoreModuleSha256: expectedCoreModuleSha256,
      bindIdentity: bindIdentity, operationIsCurrent: operationIsCurrent);
  }

  Future<RuntimeSnapshot> _stageManagedProfile(ManagedProfilePayload payload, {
    String? expectedCoreModuleSha256,
    Future<String> Function(String identityInput, RuntimeSnapshot current)? bindIdentity,
    bool Function()? operationIsCurrent,
  }) async {
    if (bindIdentity != null && operationIsCurrent?.call() != true) {
      throw StateError('core_identity_stage_superseded');
    }
    final name = payload.profileName.trim();
    var config = payload.configPayload.trim();
    if (!RegExp(r'^[a-zA-Z0-9_.-]{1,80}$').hasMatch(name) ||
        config.isEmpty ||
        utf8.encode(config).length > 512 * 1024) {
      if (bindIdentity != null) throw StateError('core_identity_stage_profile_invalid');
      return _failureSnapshot(
        failureKind: 'linux_profile_invalid',
        messageCode: 'profile_invalid',
      );
    }
    try {
      // Linux beta has no WARP runtime. Strip API metadata using the same
      // materializer as the other Core hosts before crossing the IPC boundary.
      config = _materializePokrovCoreConfig(config, WarpRuntimePolicy.disabled);
    } on FormatException {
      if (bindIdentity != null) throw StateError('core_identity_stage_profile_invalid');
      return _failureSnapshot(
        failureKind: 'linux_profile_invalid',
        messageCode: 'profile_invalid',
      );
    }
    String? expectedProfileDigest;
    if (bindIdentity != null) {
      if (_boundConnectRequestId != null || _profileRequiresRestrictions(jsonDecode(config) as Map)) {
        throw StateError('core_identity_stage_busy');
      }
      final current = await snapshot();
      _requireIdentityStageOwner(current, expectedCoreModuleSha256!, operationIsCurrent!);
      expectedProfileDigest = await bindIdentity(config, current);
      if (operationIsCurrent?.call() != true) throw StateError('core_identity_stage_superseded');
      if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(expectedProfileDigest)) {
        throw StateError('core_identity_stage_binding_invalid');
      }
    }
    final staged = await _snapshotAction(
      bindIdentity != null ? 'stage_bound_profile' : 'stage_profile',
      payload: <String, Object?>{
        'profile_name': name,
        'config_payload': config,
        'route_mode': payload.routeMode.name,
        'core_egress_probe_required': payload.coreEgressProbeRequired,
        'resolved_node_code': _publicRuntimeNodeCode(payload.resolvedNodeCode),
      },
    );
    if (bindIdentity != null) {
      _requireIdentityStageOwner(staged, expectedCoreModuleSha256!, operationIsCurrent!);
      if (staged.phase != RuntimePhase.configStaged || staged.stagedProfileDigest != expectedProfileDigest ||
          (staged.lastFailureKind?.isNotEmpty ?? false)) {
        throw StateError('core_identity_stage_unconfirmed');
      }
    }
    return staged;
  }

  @override
  Future<RuntimeSnapshot> invalidateManagedProfile() =>
      _snapshotAction('invalidate_profile');

  @override
  Future<RuntimeSnapshot> connect() async {
    if (_boundConnectRequestId != null) throw StateError('linux_runtime_busy');
    final random = math.Random.secure();
    final requestId = List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    final cancellation = Completer<void>();
    _activeConnectRequestId = requestId;
    _connectCancellation = cancellation;
    try {
      final snapshot = await _snapshotAction('connect',
        requestId: requestId, cancelled: cancellation.future);
      _connectSnapshots[snapshot] = requestId;
      return snapshot;
    } finally {
      if (_activeConnectRequestId == requestId) {
        _activeConnectRequestId = null;
        _connectCancellation = null;
      }
    }
  }

  @override
  Future<RuntimeSnapshot> connectWithCoreIdentity({
    required String expectedCoreModuleSha256,
    required String expectedProfileDigest,
    String? expectedNetworkContextRef,
    required RuntimeBootClockSnapshot budgetStartedAt,
    required Duration budget,
    required void Function(String requestId) onRequestCreated,
  }) async {
    if (expectedNetworkContextRef == null ||
        !RegExp(r'^network_[a-f0-9]{32}$').hasMatch(expectedNetworkContextRef)) {
      throw StateError('network_context_unavailable');
    }
    if (_activeConnectRequestId != null || _boundConnectRequestId != null) {
      throw StateError('linux_runtime_busy');
    }
    if (_coreModuleDigestFromWire(expectedCoreModuleSha256) == null ||
        _coreModuleDigestFromWire(expectedProfileDigest) == null) {
      throw ArgumentError('invalid_connect_identity');
    }
    final budgetMs = budget.inMilliseconds;
    final deadlineMs = budgetStartedAt.elapsedMilliseconds + budgetMs;
    if (budgetMs <= 0 || budgetMs > 86400000 || deadlineMs > 9007199254740991) {
      throw ArgumentError('invalid_connect_deadline');
    }
    void requireCurrentClock(RuntimeBootClockSnapshot now) {
      if (now.bootRef != budgetStartedAt.bootRef ||
          now.elapsedMilliseconds < budgetStartedAt.elapsedMilliseconds ||
          now.elapsedMilliseconds >= deadlineMs) throw StateError('connect_deadline');
    }
    final random = math.Random.secure();
    final requestId = List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    final cancellation = Completer<void>();
    _activeConnectRequestId = requestId;
    _boundConnectRequestId = requestId;
    _connectCancellation = cancellation;
    final operationSettled = Completer<void>();
    _boundConnectOperationSettled = operationSettled.future;
    final pending = <Future<void>>[];
    var dispatched = false;
    var deadlineElapsed = false;
    void expire() {
      deadlineElapsed = true;
      if (!cancellation.isCompleted) cancellation.complete();
    }
    final outerDeadline = Timer(budget, expire);
    Timer? nativeDeadline;
    Future<T> awaitAttempt<T>(Future<T> operation) {
      pending.add(operation.then<void>((_) {}, onError: (Object _, StackTrace __) {}));
      return Future.any<T>([
        operation,
        cancellation.future.then<T>((_) => throw StateError(
          deadlineElapsed ? 'connect_deadline' : 'linux_operation_cancelled')),
      ]);
    }
    try {
      onRequestCreated(requestId);
      final before = await awaitAttempt(readBootClock());
      requireCurrentClock(before);
      if (_activeConnectRequestId != requestId || cancellation.isCompleted) {
        throw StateError('linux_operation_cancelled');
      }
      // This timer covers both dispatch and final clock read; neither await
      // starts a fresh interval. Core independently enforces the absolute end.
      nativeDeadline = Timer(Duration(milliseconds: deadlineMs - before.elapsedMilliseconds), expire);
      dispatched = true;
      // Keep the original boot/start/end tuple. No ordinary snapshot fallback
      // can acknowledge this request when the daemon rejects the new action.
      final response = await awaitAttempt(_transport.invoke({
        'protocol': pokrovLinuxDaemonProtocol,
        'request_id': requestId,
        'action': 'connect_with_identity',
        'payload': {
          'expected_core_module_sha256': expectedCoreModuleSha256,
          'expected_profile_sha256': expectedProfileDigest,
          'expected_network_context_ref': expectedNetworkContextRef,
          'boot_ref': budgetStartedAt.bootRef,
          'started_elapsed_ms': budgetStartedAt.elapsedMilliseconds,
          'deadline_elapsed_ms': deadlineMs,
        },
      }, cancelled: cancellation.future).then((response) {
        // Inspect even a late reply that loses Future.any to cancellation.
        if (response['protocol'] == pokrovLinuxDaemonProtocol && response['request_id'] == requestId &&
            response['ok'] == false && response.length == 6 && response['error_code'] == 'linux_runtime_busy' &&
            _connectStoppedReceipt(response['connect_cancellation'], requestId) == true) {
          dispatched = false;
        }
        return response;
      }).catchError((Object error) {
        if (error is _LinuxConnectNotDispatched) dispatched = false;
        throw error;
      }));
      if (response['protocol'] != pokrovLinuxDaemonProtocol ||
          response['request_id'] != requestId || response['ok'] is! bool) {
        throw StateError('core_identity_connect_unacknowledged');
      }
      if (response['ok'] != true) {
        throw StateError(_linuxFailureKind(response['error_code']));
      }
      if (response.length != 4 || response['snapshot'] is! Map) {
        throw StateError('core_identity_connect_unacknowledged');
      }
      final result = _snapshotFromMap(response['snapshot']);
      requireCurrentClock(await awaitAttempt(readBootClock()));
      if (_activeConnectRequestId != requestId || cancellation.isCompleted) {
        throw StateError('linux_operation_cancelled');
      }
      if (result.phase != RuntimePhase.running || result.coreModuleSha256 != expectedCoreModuleSha256 ||
          result.effectiveProfileDigest != expectedProfileDigest) {
        throw StateError('core_identity_connect_mismatch');
      }
      _connectSnapshots[result] = requestId;
      // Retain this owner after the response so explicit cancellation can
      // address the started attempt. Native expiry stays armed independently.
      return result;
    } catch (_) {
      if (!cancellation.isCompleted) cancellation.complete();
      // The connect socket sends cancellation, then retains the daemon reply.
      // Joining it closes the cancel-before-authorization/admission race.
      await Future.wait(pending);
      if (dispatched) {
        try {
          if (!await _cancelBoundConnect(requestId)) {
            throw StateError('core_identity_connect_cancel_unconfirmed');
          }
        }
        catch (_) { throw StateError('core_identity_connect_cancel_unconfirmed'); }
      }
      _releaseBoundConnect(requestId);
      rethrow;
    } finally {
      outerDeadline.cancel();
      nativeDeadline?.cancel();
      await Future.wait(pending);
      operationSettled.complete();
    }
  }

  @override
  Future<RuntimeSnapshot> disconnect() async {
    final boundRequestId = _boundConnectRequestId;
    if (boundRequestId != null) {
      if (!await cancelAndConfirmConnectStopped(boundRequestId)) {
        return _failureSnapshot(failureKind: 'linux_runtime_error', messageCode: 'runtime_error');
      }
      return snapshot();
    }
    final cancellation = _connectCancellation;
    if (cancellation != null && !cancellation.isCompleted) cancellation.complete();
    final requestId = _boundConnectRequestId;
    final activeRequestId = _activeConnectRequestId;
    final result = await _snapshotAction('disconnect');
    if (result.phase != RuntimePhase.running && !result.connectionPending && result.lastFailureKind == null &&
        _boundConnectRequestId == requestId && _activeConnectRequestId == activeRequestId) {
      _boundConnectRequestId = null;
      _activeConnectRequestId = null;
      _connectCancellation = null;
    }
    return result;
  }

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
    String? requestId,
    Future<void>? cancelled,
  }) async {
    final response = await _invoke(action, payload: payload,
      requestId: requestId, cancelled: cancelled);
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

  @override
  Future<RuntimeBootClockSnapshot> readBootClock() async {
    final response = await _invoke('clock_snapshot');
    if (response == null || response['ok'] != true) throw StateError('runtime_clock_unavailable');
    return RuntimeBootClockSnapshot.fromWire(response['clock'], HostPlatform.linux);
  }

  @override
  Future<String> readTransportNetworkContext() async {
    final response = await _invoke('read_network_context');
    if (response == null || response['ok'] != true || response.length != 4) {
      throw StateError('network_context_unavailable');
    }
    final context = response['network_context'];
    if (context is! Map || context.length != 2 || context['schema'] != 1 ||
        context['network_context_ref'] is! String ||
        !RegExp(r'^network_[a-f0-9]{32}$').hasMatch(context['network_context_ref'] as String)) {
      throw StateError('network_context_unavailable');
    }
    return context['network_context_ref'] as String;
  }

  Future<Map<String, Object?>?> _invoke(
    String action, {
    Map<String, Object?> payload = const <String, Object?>{},
    String? requestId,
    Future<void>? cancelled,
  }) async {
    requestId ??= _nextRequestId();
    try {
      final response = await _transport.invoke(<String, Object?>{
        'protocol': pokrovLinuxDaemonProtocol,
        'request_id': requestId,
        'action': action,
        'payload': payload,
      }, cancelled: cancelled);
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
      transportCapabilities: const {RuntimePhase.initialized, RuntimePhase.configStaged, RuntimePhase.running}.contains(phase)
          ? RuntimeTransportCapabilities.fromWire(map['transport_capabilities_json']) : null,
      coreModuleSha256: const {RuntimePhase.initialized, RuntimePhase.configStaged, RuntimePhase.running}.contains(phase)
          ? _coreModuleDigestFromWire(map['core_module_sha256']) : null,
      artifactDirectory: null,
      coreBinaryPath: null,
      helperBinaryPath: null,
      stagedConfigPath: null,
      stagedProfileDigest: _coreModuleDigestFromWire(map['staged_profile_digest']),
      effectiveProfileDigest: _coreModuleDigestFromWire(map['effective_profile_digest']),
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
      transportProofPending: map.containsKey('transport_proof_pending')
          ? map['transport_proof_pending'] != false ||
              (map['transport_lease_active'] == true && _boundConnectRequestId == null)
          : null,
      transportLeaseActive: map['transport_lease_active'] is bool
          ? map['transport_lease_active'] as bool : null,
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
        'linux_operation_cancelled',
        'linux_runtime_busy',
        'core_identity_mismatch',
        'linux_network_context_changed',
        'linux_network_context_unavailable',
        'connect_deadline',
      }.contains(candidate)
      ? candidate
      : null;
}

String _linuxRuntimeMessage(Object? value) => switch (value?.toString()) {
  'ready' => 'Системная служба Linux готова.',
  'profile_staged' => 'Профиль подготовлен системной службой.',
  'connected' => 'Защищено. DNS и выход через VPN проверены.',
  'stopped' => 'Соединение остановлено, сеть восстановлена.',
  'operation_cancelled' => 'Попытка подключения отменена.',
  'runtime_busy' => 'Сначала дождитесь остановки текущего соединения.',
  'core_identity_mismatch' => 'Core или профиль изменился. Подготовьте подключение заново.',
  'network_context_changed' => 'Внешняя сеть изменилась. Подготовьте подключение заново.',
  'network_context_unavailable' => 'Контекст внешней сети Linux недоступен.',
  'connect_deadline' => 'Время попытки подключения истекло.',
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
