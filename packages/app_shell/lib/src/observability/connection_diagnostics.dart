part of '../../app_first_runtime_bootstrap.dart';

enum ConnectionDiagnosticStage {
  profile,
  permission,
  core,
  egress,
  routeSwitch
}

String _diagnosticStageName(ConnectionDiagnosticStage stage) =>
    stage == ConnectionDiagnosticStage.routeSwitch
        ? 'route_switch'
        : stage.name;

final class ConnectionDiagnosticAttempt {
  ConnectionDiagnosticAttempt._(
      this._owner, this._platform, this._binding, this.number);

  final AppFirstConnectionDiagnostics _owner;
  final HostPlatform _platform;
  final _RuntimeStatsBinding _binding;
  final int number;
  final _steps = <Map<String, Object?>>[];
  final _clock = Stopwatch();
  ConnectionDiagnosticStage? _stage;
  ConnectionDiagnosticStage? _lastStage;
  bool _finished = false;

  bool get finished => _finished;
  ConnectionDiagnosticStage? get stage => _stage;

  void enter(ConnectionDiagnosticStage stage) {
    if (_finished || _stage == stage) return;
    complete('succeeded');
    _stage = stage;
    _lastStage = stage;
    _clock
      ..reset()
      ..start();
    unawaited(_owner._rememberStage(_platform, _binding, number, stage));
  }

  void complete(String outcome, {String? errorCode, int? durationMs}) {
    final stage = _stage;
    if (_finished || stage == null) return;
    _clock.stop();
    if (_steps.length == 16) _steps.removeAt(0);
    _steps.add({
      'stage': _diagnosticStageName(stage),
      'outcome': outcome,
      'duration_ms':
          (durationMs ?? _clock.elapsedMilliseconds).clamp(0, 3600000),
      if (errorCode != null && KnownOperationalErrorCodes.contains(errorCode))
        'error_code': errorCode,
    });
    _stage = null;
  }

  void confirmPermission() {
    final index = _steps.lastIndexWhere((step) =>
        step['stage'] == 'permission' && step['outcome'] == 'unknown');
    if (index != -1) _steps[index]['outcome'] = 'succeeded';
  }

  Future<void> finish(
    String outcome, {
    String? errorCode,
    int? egressDurationMs,
    String? network,
    String? transport,
    String? node,
  }) async {
    if (_finished) return;
    if (outcome == 'verified') enter(ConnectionDiagnosticStage.egress);
    final incompleteSwitch = outcome == 'failed' &&
        _stage == ConnectionDiagnosticStage.routeSwitch &&
        _steps.any((step) => step['outcome'] == 'failed');
    complete(
        outcome == 'verified'
            ? 'succeeded'
            : incompleteSwitch
                ? 'unknown'
                : outcome,
        errorCode: errorCode,
        durationMs: _stage == ConnectionDiagnosticStage.egress ? egressDurationMs : null);
    _finished = true;
    unawaited(_owner._rememberStage(_platform, _binding, number, _lastStage,
        finished: true));
    await _owner._queue(
      _platform,
      _binding,
      phase: 'connect_diagnostic',
      detail: {
        'connection_diagnostic': {'outcome': outcome, 'steps': _steps}
      },
      attempt: number,
      network: network,
      transport: transport,
      node: node,
    );
  }
}

final class AppFirstConnectionDiagnostics {
  AppFirstConnectionDiagnostics._(this._owner);

  final AppFirstRuntimeBootstrapper _owner;
  static const _native = MethodChannel('space.pokrov/runtime_engine');
  bool? _enabled;
  int _preferenceRevision = 0;
  int _checkpointRevision = 0;
  Future<void>? _starting;
  _RuntimeStatsBinding? _runBinding;
  Map<String, Object?>? _run;
  Timer? _retry;

  static bool supports(HostPlatform platform) =>
      platform == HostPlatform.android || platform == HostPlatform.windows;

  Future<File> _file(HostPlatform platform, String name) async => File(
      '${(await _owner._supportDirectoryResolver()).path}${Platform.pathSeparator}'
      'connection-diagnostics-$name-${platform.name}.json');

  Future<bool> enabled(HostPlatform platform) async {
    if (!supports(platform)) return false;
    if (_enabled case final value?) return value;
    try {
      final file = await _file(platform, 'setting');
      final value = await _withAppFirstStateFileLock(file, () async {
        final backup = File('${file.path}.bak');
        if (!await file.exists() && await backup.exists())
          await backup.rename(file.path);
        if (!await file.exists()) return true;
        final stored = jsonDecode(await file.readAsString());
        return stored is Map && stored['enabled'] == true;
      });
      return _enabled ??= value;
    } on Object {
      return _enabled ??= false;
    }
  }

  Future<void> setEnabled(HostPlatform platform, bool enabled) async {
    _preferenceRevision++;
    if (!enabled) {
      _enabled = false;
      _retry?.cancel();
      _retry = null;
      _run = null;
      _runBinding = null;
    }
    final setting = await _file(platform, 'setting');
    await _withAppFirstStateFileLock(
        setting,
        () =>
            _owner._stateFileWriter(setting, jsonEncode({'enabled': enabled})));
    _enabled = enabled;
    if (!enabled) {
      final file = await _file(platform, 'run');
      await _withAppFirstStateFileLock(
          file, () => _owner._stateFileWriter(file, '{}'));
      await _owner._runtimeStatsOutbox.clearDiagnostics(platform);
    }
  }

  ConnectionDiagnosticAttempt? beginAttempt(HostPlatform platform, int number) {
    final binding = _owner._runtimeStatsBindings[platform];
    if (_enabled != true || binding == null || !supports(platform)) return null;
    return ConnectionDiagnosticAttempt._(this, platform, binding, number);
  }

  Future<void> start(
      HostPlatform platform, PreviousExitReport? dartExit) async {
    if (!supports(platform) || !await enabled(platform)) return;
    if (_starting != null) return _starting;
    final pending = _start(platform, dartExit);
    _starting = pending;
    try {
      await pending;
    } finally {
      _starting = null;
    }
  }

  Future<void> _start(
      HostPlatform platform, PreviousExitReport? dartExit) async {
    try {
      final revision = _preferenceRevision;
      final state = await _owner._loadState(platform);
      final binding = _owner._runtimeStatsBindings[platform];
      if (binding == null ||
          !binding.matches(state) ||
          _enabled != true ||
          revision != _preferenceRevision) return;
      final existing = _runBinding;
      if (existing?.accountId == binding.accountId &&
          existing?.installId == binding.installId) {
        if (await _owner._runtimeStatsOutbox.nextDiagnosticKey(platform, binding) != null)
          _deliver(platform);
        return;
      }
      final file = await _file(platform, 'run');
      final previous = await _withAppFirstStateFileLock(file, () async {
        final backup = File('${file.path}.bak');
        if (!await file.exists() && await backup.exists())
          await backup.rename(file.path);
        if (!await file.exists() || await file.length() > 4096) return null;
        try {
          final value = jsonDecode(await file.readAsString());
          return value is Map<String, Object?> ? value : null;
        } on FormatException {
          return null;
        }
      });
      if (previous != null &&
          previous['account'] == binding.accountId &&
          previous['installation'] == binding.installId &&
          previous['run'] != _owner._runtimeReportRunId) {
        await _queuePreviousExit(platform, binding, previous, dartExit);
      }
      await _withAppFirstStateFileLock(file, () async {
        if (_enabled != true || revision != _preferenceRevision) return;
        final exitSequence = ++_owner._runtimeReportSequence;
        _owner._runtimeReportSequence++;
        final run = <String, Object?>{
          'account': binding.accountId,
          'installation': binding.installId,
          'run': _owner._runtimeReportRunId,
          'exit_sequence': exitSequence,
          'started_ms': DateTime.now().toUtc().millisecondsSinceEpoch,
          'version': pokrovClientVersion,
          'build': pokrovClientBuildNumber,
        };
        await _owner._stateFileWriter(file, jsonEncode(run));
        _run = run;
        _runBinding = binding;
      });
      if (await _owner._runtimeStatsOutbox.nextDiagnosticKey(platform, binding) != null)
        _deliver(platform);
    } on Object {
      // Diagnostics can be unavailable while the app and tunnel keep working.
    }
  }

  Future<void> _rememberStage(
      HostPlatform platform,
      _RuntimeStatsBinding binding,
      int number,
      ConnectionDiagnosticStage? stage,
      {bool finished = false}) async {
    final revision = ++_checkpointRevision;
    try {
      final file = await _file(platform, 'run');
      await _withAppFirstStateFileLock(file, () async {
        final run = _run;
        if (_enabled != true ||
            run == null ||
            revision != _checkpointRevision ||
            _runBinding?.accountId != binding.accountId ||
            _runBinding?.installId != binding.installId ||
            ((run['attempt'] as int?) ?? 0) > number) return;
        run['attempt'] = number;
        run['attempt_active'] = !finished;
        if (stage != null) run['stage'] = _diagnosticStageName(stage);
        await _owner._stateFileWriter(file, jsonEncode(run));
      });
    } on Object {
      // Saving the latest stage must not hold up the connection.
    }
  }

  Future<void> _queuePreviousExit(
      HostPlatform platform,
      _RuntimeStatsBinding binding,
      Map<String, Object?> previous,
      PreviousExitReport? dartExit) async {
    final start = previous['started_ms'];
    final run = previous['run'];
    final sequence = previous['exit_sequence'];
    if (start is! int ||
        run is! String ||
        sequence is! int ||
        start <
            DateTime.now()
                .subtract(_RuntimeStatsOutbox.maximumAge)
                .millisecondsSinceEpoch) return;
    final native = <String, ({int at, String kind, String? signature})>{};
    try {
      final records = await _native
          .invokeListMethod<Object?>(
            platform == HostPlatform.windows
                ? 'runtimeEngine.crashDiagnostics'
                : 'runtimeEngine.previousExits',
          )
          .timeout(const Duration(seconds: 2));
      for (final record in records ?? const []) {
        if (record is! Map || record['occurred_at_unix_ms'] is! int) continue;
        final at = record['occurred_at_unix_ms'] as int;
        if (at < start || at > DateTime.now().millisecondsSinceEpoch) continue;
        final component =
            record['error_code'] == 'CRASH-003' ? 'vpn_service' : 'app';
        final kind =
            platform == HostPlatform.windows ? 'native_crash' : record['kind'];
        if (kind is! String ||
            !const {'native_crash', 'anr', 'system_stop'}.contains(kind))
          continue;
        final signature = record['signature'];
        if ((native[component]?.at ?? 0) < at) {
          native[component] = (
            at: at,
            kind: kind,
            signature: signature is String ? signature : null
          );
        }
      }
    } on MissingPluginException {
      // Older runners can still provide the Dart exit marker.
    } on PlatformException {
      // A native exit may be unavailable after the service stopped.
    } on TimeoutException {
      // A slow native process must not block diagnostics for the current run.
    }
    final dartAt = dartExit?.occurredAtUtc?.millisecondsSinceEpoch;
    if (dartExit?.kind == PreviousExitKind.crash &&
        dartAt != null &&
        dartAt >= start &&
        native['app'] == null) {
      native['app'] =
          (at: dartAt, kind: 'dart_crash', signature: dartExit?.crashSignature);
    }
    final stage = previous['stage'];
    if (native.isEmpty &&
        dartExit?.kind == PreviousExitKind.unclean &&
        previous['attempt_active'] == true) {
      native['app'] = (
        at: DateTime.now().millisecondsSinceEpoch,
        kind: 'unknown',
        signature: null
      );
    }
    final signaturePattern = RegExp(r'^[0-9a-f]{16,32}$');
    for (final item in native.entries) {
      final signature = item.value.signature;
      await _queue(
        platform,
        binding,
        phase: 'exit_diagnostic',
        run: run,
        sequence: item.key == 'app' ? sequence : sequence + 1,
        when: DateTime.fromMillisecondsSinceEpoch(item.value.at, isUtc: true),
        version: previous['version'] as String?,
        build: previous['build'] as String?,
        attempt: previous['attempt_active'] == true
            ? previous['attempt'] as int?
            : null,
        detail: {
          'exit_diagnostic': {
            'component': item.key,
            'kind': item.value.kind,
            if (signature != null && signaturePattern.hasMatch(signature))
              'signature': signature,
            if (stage is String) 'last_stage': stage,
          }
        },
      );
    }
  }

  Future<void> _queue(
    HostPlatform platform,
    _RuntimeStatsBinding binding, {
    required String phase,
    required Map<String, Object?> detail,
    String? run,
    int? sequence,
    DateTime? when,
    String? version,
    String? build,
    int? attempt,
    String? network,
    String? transport,
    String? node,
  }) async {
    final revision = _preferenceRevision;
    try {
      if (_enabled != true ||
          !binding.matches(await _owner._loadState(platform)) ||
          revision != _preferenceRevision) return;
      final record = _RuntimeStatsRecord(
          binding,
          jsonEncode({
            'runtime_phase': phase,
            'client_application': 'pokrov',
            'platform': platform.name,
            'app_version': version ?? pokrovClientVersion,
            'build_number': build ?? pokrovClientBuildNumber,
            'report_run_id': run ?? _owner._runtimeReportRunId,
            'report_sequence': sequence ?? ++_owner._runtimeReportSequence,
            'occurred_at': (when ?? DateTime.now().toUtc()).toIso8601String(),
            if (attempt != null) 'attempt_number': attempt,
            if (const {'cellular', 'wifi', 'ethernet', 'other'}
                .contains(network))
              'network_class': network,
            if (transport != null && transport.isNotEmpty)
              'candidate_transport': transport,
            if (node != null && RegExp(r'^[a-z0-9_.-]{1,32}$').hasMatch(node))
              'selected_node_code': node,
            ...detail,
          }));
      if (await _owner._runtimeStatsOutbox.enqueue(platform, record))
        _deliver(platform);
    } on Object {
      // The user-facing connection and crash handling are independent of upload.
    }
  }

  void _deliver(HostPlatform platform) {
    if (_enabled != true || _retry?.isActive == true) return;
    _retry =
        Timer(const Duration(seconds: 2), () => unawaited(_flush(platform)));
  }

  Future<void> _flush(HostPlatform platform) async {
    try {
      final outbox = _owner._runtimeStatsOutbox;
      final packet = await outbox.nextDiagnosticKey(platform, _runBinding);
      if (packet == null || _enabled != true) return;
      await outbox.flush(platform, priorityPacketKey: packet);
      if (_enabled == true &&
          await outbox.nextDiagnosticKey(platform, _runBinding) != null) {
        _retry = Timer(
            const Duration(minutes: 1), () => unawaited(_flush(platform)));
      }
    } on Object {
      // Resume and the next event will retry the same persisted queue.
    }
  }
}
