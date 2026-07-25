library pokrov_runtime_engine;

import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pokrov_core_domain/core_domain.dart';

enum RuntimeLane {
  desktopFfi,
  mobileArtifact,
}

enum RuntimePhase {
  artifactMissing,
  artifactReady,
  initialized,
  configStaged,
  running,
}

enum RuntimeHostHealth {
  unknown,
  healthy,
  degraded,
}

enum RuntimeDiagnosticState {
  unknown,
  healthy,
  degraded,
}

class RuntimeSnapshot {
  const RuntimeSnapshot({
    required this.hostPlatform,
    required this.lane,
    required this.phase,
    required this.artifactDirectory,
    required this.coreBinaryPath,
    required this.helperBinaryPath,
    required this.stagedConfigPath,
    required this.supportsLiveConnect,
    required this.canInitialize,
    required this.canConnect,
    required this.message,
    this.hostHealth = RuntimeHostHealth.unknown,
    this.dnsState = RuntimeDiagnosticState.unknown,
    this.uplinkState = RuntimeDiagnosticState.unknown,
    this.hostDiagnosticsSummary,
    this.defaultNetworkInterface,
    this.defaultNetworkIndex,
    this.dnsReady,
    this.lastFailureKind,
    this.lastStopReason,
    this.ipv4RouteCount,
    this.ipv6RouteCount,
    this.includePackageCount,
    this.excludePackageCount,
  });

  final HostPlatform hostPlatform;
  final RuntimeLane lane;
  final RuntimePhase phase;
  final String? artifactDirectory;
  final String? coreBinaryPath;
  final String? helperBinaryPath;
  final String? stagedConfigPath;
  final bool supportsLiveConnect;
  final bool canInitialize;
  final bool canConnect;
  final String message;
  final RuntimeHostHealth hostHealth;
  final RuntimeDiagnosticState dnsState;
  final RuntimeDiagnosticState uplinkState;
  final String? hostDiagnosticsSummary;
  final String? defaultNetworkInterface;
  final int? defaultNetworkIndex;
  final bool? dnsReady;
  final String? lastFailureKind;
  final String? lastStopReason;
  final int? ipv4RouteCount;
  final int? ipv6RouteCount;
  final int? includePackageCount;
  final int? excludePackageCount;

  bool get hasDegradedHostDiagnostics =>
      hostHealth == RuntimeHostHealth.degraded ||
      dnsState == RuntimeDiagnosticState.degraded ||
      uplinkState == RuntimeDiagnosticState.degraded;

  bool get isCleanlyHealthy =>
      phase == RuntimePhase.running && !hasDegradedHostDiagnostics;

  String get laneLabel {
    switch (lane) {
      case RuntimeLane.desktopFfi:
        return 'Локальный runtime';
      case RuntimeLane.mobileArtifact:
        return 'Системный runtime';
    }
  }

  String get phaseLabel {
    switch (phase) {
      case RuntimePhase.artifactMissing:
        return 'Нужна подготовка';
      case RuntimePhase.artifactReady:
        return 'Файлы готовы';
      case RuntimePhase.initialized:
        return 'Runtime готов';
      case RuntimePhase.configStaged:
        return 'Настройки готовы';
      case RuntimePhase.running:
        return hasDegradedHostDiagnostics
            ? 'Подключено с предупреждением'
            : 'Подключено';
    }
  }

  String? get diagnosticsLabel {
    final summary = hostDiagnosticsSummary?.trim() ?? '';
    if (summary.isNotEmpty) {
      return summary;
    }
    final labels = <String>[
      if (dnsState != RuntimeDiagnosticState.unknown)
        'DNS ${_diagnosticStateLabel(dnsState)}',
      if (uplinkState != RuntimeDiagnosticState.unknown)
        'Сеть ${_diagnosticStateLabel(uplinkState)}',
    ];
    if (labels.isEmpty) {
      return null;
    }
    return labels.join(' | ');
  }

  static String _diagnosticStateLabel(RuntimeDiagnosticState state) {
    return switch (state) {
      RuntimeDiagnosticState.healthy => 'в порядке',
      RuntimeDiagnosticState.degraded => 'требует проверки',
      RuntimeDiagnosticState.unknown => 'проверяется',
    };
  }
}

class RuntimeLiveStats {
  const RuntimeLiveStats({
    required this.available,
    this.uplinkBps,
    this.downlinkBps,
    this.latencyMs,
    this.since,
    this.serverCode = '',
    this.serverCountry = '',
    this.protocol = '',
  });

  const RuntimeLiveStats.unavailable()
      : available = false,
        uplinkBps = null,
        downlinkBps = null,
        latencyMs = null,
        since = null,
        serverCode = '',
        serverCountry = '',
        protocol = '';

  final bool available;
  final int? uplinkBps;
  final int? downlinkBps;
  final int? latencyMs;
  final DateTime? since;
  final String serverCode;
  final String serverCountry;
  final String protocol;

  static RuntimeLiveStats fromMap(Object? value) {
    final map = _runtimeObjectMap(value);
    if (map.isEmpty) {
      return const RuntimeLiveStats.unavailable();
    }
    return RuntimeLiveStats(
      available: _runtimeBool(map['available']),
      uplinkBps: _runtimeNullableInt(map['uplinkBps'] ?? map['uplink_bps']),
      downlinkBps:
          _runtimeNullableInt(map['downlinkBps'] ?? map['downlink_bps']),
      latencyMs: _runtimeNullableInt(map['latencyMs'] ?? map['latency_ms']),
      since: _runtimeDateTime(map['since']),
      serverCode: _runtimeText(map['serverCode'] ?? map['server_code']),
      serverCountry:
          _runtimeText(map['serverCountry'] ?? map['server_country']),
      protocol: _runtimeText(map['protocol']),
    );
  }
}

class WarpApplyResult {
  const WarpApplyResult({
    required this.applied,
    required this.effectiveAt,
    required this.fallbackUsed,
    this.reason,
  });

  const WarpApplyResult.notApplied({
    required String this.reason,
    this.effectiveAt = 'none',
    this.fallbackUsed = false,
  }) : applied = false;

  final bool applied;
  final String effectiveAt;
  final bool fallbackUsed;
  final String? reason;

  static WarpApplyResult fromMap(Object? value) {
    final map = _runtimeObjectMap(value);
    if (map.isEmpty) {
      return const WarpApplyResult.notApplied(reason: 'empty_host_response');
    }
    return WarpApplyResult(
      applied: _runtimeBool(map['applied']),
      effectiveAt: _runtimeText(map['effectiveAt'] ?? map['effective_at'],
          fallback: 'none'),
      fallbackUsed: _runtimeBool(map['fallbackUsed'] ?? map['fallback_used']),
      reason: _runtimeNullableText(map['reason']),
    );
  }
}

class RuntimePushToken {
  const RuntimePushToken({
    required this.token,
    required this.provider,
  });

  const RuntimePushToken.unavailable()
      : token = '',
        provider = 'poll';

  final String token;
  final String provider;

  bool get available => token.trim().isNotEmpty;

  static RuntimePushToken fromMap(Object? value) {
    final map = _runtimeObjectMap(value);
    if (map.isEmpty) {
      return const RuntimePushToken.unavailable();
    }
    return RuntimePushToken(
      token: _runtimeText(map['token']),
      provider: _runtimeText(map['provider'], fallback: 'poll'),
    );
  }
}

Map<String, Object?> _runtimeObjectMap(Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return const <String, Object?>{};
}

String _runtimeText(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

String? _runtimeNullableText(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

bool _runtimeBool(Object? value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  switch (value?.toString().trim().toLowerCase()) {
    case '1':
    case 'true':
    case 'yes':
    case 'ready':
      return true;
    default:
      return false;
  }
}

int? _runtimeNullableInt(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value.toString().trim());
}

DateTime? _runtimeDateTime(Object? value) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) {
    return null;
  }
  return DateTime.tryParse(text);
}

class WarpRuntimePolicy {
  const WarpRuntimePolicy({
    required this.enabled,
    required this.runtimeReady,
    required this.state,
    this.mode = 'proxy_over_warp',
    this.source = 'backend_managed',
    this.userConsented = false,
    this.id = '',
    this.licenseKey = '',
    this.wireguardConfigJson = '',
    this.accountId = '',
    this.accessToken = '',
    this.cleanIp = 'auto',
    this.cleanPort = 0,
    this.noise = '',
    this.noiseSize = '',
    this.noiseDelay = '',
    this.noiseMode = 'm4',
  });

  static const disabled = WarpRuntimePolicy(
    enabled: false,
    runtimeReady: false,
    state: 'disabled_until_runtime_proof',
  );

  static const clientLocalDefault = WarpRuntimePolicy(
    enabled: true,
    runtimeReady: true,
    state: 'ready_to_consent',
    source: 'client_local',
    id: 'p1',
    cleanIp: 'auto',
    cleanPort: 0,
    noise: '',
    noiseSize: '',
    noiseDelay: '',
    noiseMode: 'm4',
  );

  final bool enabled;
  final bool runtimeReady;
  final String state;
  final String mode;
  final String source;
  final bool userConsented;
  final String id;
  final String licenseKey;
  final String wireguardConfigJson;
  final String accountId;
  final String accessToken;
  final String cleanIp;
  final int cleanPort;
  final String noise;
  final String noiseSize;
  final String noiseDelay;
  final String noiseMode;

  bool get canOfferRuntime => enabled && runtimeReady;

  bool get canEnableRuntime => canOfferRuntime && userConsented;

  bool get isClientLocal => source.trim() == 'client_local';

  bool get hasServerManagedMaterial =>
      wireguardConfigJson.trim().isNotEmpty ||
      accountId.trim().isNotEmpty ||
      accessToken.trim().isNotEmpty;

  WarpRuntimePolicy withClientLocalDefaults() {
    if (canOfferRuntime && id.trim().isNotEmpty) {
      return this;
    }
    final fallback = clientLocalDefault;
    final normalizedState = state.trim();
    final nextState = normalizedState.isEmpty ||
            normalizedState == 'disabled_until_runtime_proof' ||
            normalizedState == 'waiting_for_backend_provisioning' ||
            normalizedState == 'not_ready'
        ? fallback.state
        : normalizedState;
    return copyWith(
      enabled: true,
      runtimeReady: true,
      state: nextState,
      source: hasServerManagedMaterial ? source : fallback.source,
      id: id.trim().isNotEmpty ? id : fallback.id,
      cleanIp: cleanIp.trim().isNotEmpty ? cleanIp : fallback.cleanIp,
      cleanPort: cleanPort,
      noise: noise,
      noiseSize: noiseSize,
      noiseDelay: noiseDelay,
      noiseMode: noiseMode.trim().isNotEmpty ? noiseMode : fallback.noiseMode,
    );
  }

  WarpRuntimePolicy withUserConsent(bool value) => copyWith(
        userConsented: value,
      );

  WarpRuntimePolicy copyWith({
    bool? enabled,
    bool? runtimeReady,
    String? state,
    String? mode,
    String? source,
    bool? userConsented,
    String? id,
    String? licenseKey,
    String? wireguardConfigJson,
    String? accountId,
    String? accessToken,
    String? cleanIp,
    int? cleanPort,
    String? noise,
    String? noiseSize,
    String? noiseDelay,
    String? noiseMode,
  }) {
    return WarpRuntimePolicy(
      enabled: enabled ?? this.enabled,
      runtimeReady: runtimeReady ?? this.runtimeReady,
      state: state ?? this.state,
      mode: mode ?? this.mode,
      source: source ?? this.source,
      userConsented: userConsented ?? this.userConsented,
      id: id ?? this.id,
      licenseKey: licenseKey ?? this.licenseKey,
      wireguardConfigJson: wireguardConfigJson ?? this.wireguardConfigJson,
      accountId: accountId ?? this.accountId,
      accessToken: accessToken ?? this.accessToken,
      cleanIp: cleanIp ?? this.cleanIp,
      cleanPort: cleanPort ?? this.cleanPort,
      noise: noise ?? this.noise,
      noiseSize: noiseSize ?? this.noiseSize,
      noiseDelay: noiseDelay ?? this.noiseDelay,
      noiseMode: noiseMode ?? this.noiseMode,
    );
  }

  Map<String, Object?>? get wireguardConfigObject {
    final text = wireguardConfigJson.trim();
    if (text.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  static WarpRuntimePolicy tryParse(Object? value) {
    final map = _readObjectMap(value);
    if (map.isEmpty) {
      return disabled;
    }
    final wireguardConfig = _readWireguardConfig(
      map['wireguard_config'] ??
          map['wireguardConfig'] ??
          map['wireguard-config'],
    );
    final account = _readObjectMap(map['account']);
    final enabled = _readBool(map['enabled']);
    final runtimeReady = _readBool(map['runtime_ready'] ?? map['runtimeReady']);
    return WarpRuntimePolicy(
      enabled: enabled,
      runtimeReady: runtimeReady,
      state: _readState(
        map['state'],
        enabled: enabled,
        runtimeReady: runtimeReady,
      ),
      mode: _readMode(map['mode']),
      source: _readText(map['source'], fallback: 'backend_managed'),
      userConsented: _readBool(map['user_consented'] ?? map['userConsented']),
      id: _readText(map['id']),
      licenseKey: _readText(
        map['license_key'] ?? map['license-key'] ?? map['licenseKey'],
      ),
      wireguardConfigJson: wireguardConfig,
      accountId: _readText(
        account['account-id'] ?? account['account_id'] ?? account['accountId'],
      ),
      accessToken: _readText(
        account['access-token'] ??
            account['access_token'] ??
            account['accessToken'],
      ),
      cleanIp: _readText(map['clean_ip'] ?? map['clean-ip'], fallback: 'auto'),
      cleanPort: _readInt(map['clean_port'] ?? map['clean-port']),
      noise: _readText(map['noise']),
      noiseSize: _readText(map['noise_size'] ?? map['noise-size']),
      noiseDelay: _readText(map['noise_delay'] ?? map['noise-delay']),
      noiseMode:
          _readText(map['noise_mode'] ?? map['noise-mode'], fallback: 'm4'),
    );
  }

  static String _readWireguardConfig(Object? value) {
    if (value is String) {
      return value.trim();
    }
    if (value is Map) {
      return jsonEncode(
        value.map((key, item) => MapEntry(key.toString(), item)),
      );
    }
    return '';
  }

  static Map<String, Object?> _readObjectMap(Object? value) {
    if (value is Map<String, Object?>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    return const <String, Object?>{};
  }

  static String _readText(Object? value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  static String _readMode(Object? value) {
    final text = _readText(value, fallback: 'proxy_over_warp');
    return text == 'warp_over_proxy' ? text : 'proxy_over_warp';
  }

  static String _readState(
    Object? value, {
    required bool enabled,
    required bool runtimeReady,
  }) {
    final text = _readText(value);
    if (runtimeReady) {
      return text.isEmpty ? 'ready' : text;
    }
    if (enabled) {
      return text.isEmpty || text == 'ready'
          ? 'waiting_for_backend_provisioning'
          : text;
    }
    return text.isEmpty || text == 'ready'
        ? 'disabled_until_runtime_proof'
        : text;
  }

  static bool _readBool(Object? value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    switch (value?.toString().trim().toLowerCase()) {
      case '1':
      case 'true':
      case 'yes':
      case 'ready':
        return true;
      default:
        return false;
    }
  }

  static int _readInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString().trim() ?? '') ?? 0;
  }
}

class ManagedProfilePayload {
  const ManagedProfilePayload({
    required this.profileName,
    required this.configPayload,
    this.disableMemoryLimit = false,
    this.materializedForRuntime = false,
    this.routeMode = RouteMode.fullTunnel,
    this.smartConnect,
    this.warpPolicy = WarpRuntimePolicy.disabled,
  });

  final String profileName;
  final String configPayload;
  final bool disableMemoryLimit;
  final bool materializedForRuntime;
  final RouteMode routeMode;
  final SmartConnectProfile? smartConnect;
  final WarpRuntimePolicy warpPolicy;

  ManagedProfilePayload copyWith({
    String? profileName,
    String? configPayload,
    bool? disableMemoryLimit,
    bool? materializedForRuntime,
    RouteMode? routeMode,
    SmartConnectProfile? smartConnect,
    WarpRuntimePolicy? warpPolicy,
  }) {
    return ManagedProfilePayload(
      profileName: profileName ?? this.profileName,
      configPayload: configPayload ?? this.configPayload,
      disableMemoryLimit: disableMemoryLimit ?? this.disableMemoryLimit,
      materializedForRuntime:
          materializedForRuntime ?? this.materializedForRuntime,
      routeMode: routeMode ?? this.routeMode,
      smartConnect: smartConnect ?? this.smartConnect,
      warpPolicy: warpPolicy ?? this.warpPolicy,
    );
  }
}

abstract interface class PokrovRuntimeEngine {
  Future<RuntimeSnapshot> snapshot();

  Future<RuntimeSnapshot> initialize();

  Future<RuntimeSnapshot> stageManagedProfile(
    ManagedProfilePayload payload,
  );

  Future<RuntimeSnapshot> connect();

  Future<RuntimeSnapshot> disconnect();

  Future<WarpApplyResult> applyWarp({required bool enabled});

  Future<RuntimeLiveStats> liveStats();

  Future<RuntimePushToken> pushToken();
}

PokrovRuntimeEngine createRuntimeEngine({
  required HostPlatform hostPlatform,
  String? assetRootOverride,
}) {
  switch (hostPlatform) {
    case HostPlatform.windows:
    case HostPlatform.macos:
      return DesktopRuntimeEngine(
        hostPlatform: hostPlatform,
        assetRootOverride: assetRootOverride,
      );
    case HostPlatform.android:
    case HostPlatform.ios:
      return MobileArtifactRuntimeEngine(
        hostPlatform: hostPlatform,
        assetRootOverride: assetRootOverride,
      );
  }
}

class DesktopRuntimeEngine implements PokrovRuntimeEngine {
  DesktopRuntimeEngine({
    required this.hostPlatform,
    this.assetRootOverride,
    Future<String?> Function()? connectivityProbe,
    DesktopRuntimeBindings Function(String libraryPath)? bindingsLoader,
  })  : _connectivityProbe = connectivityProbe,
        _bindingsLoader = bindingsLoader ?? _PokrovCoreBindingsLoader.load;

  final HostPlatform hostPlatform;
  final String? assetRootOverride;
  final Future<String?> Function()? _connectivityProbe;
  final DesktopRuntimeBindings Function(String libraryPath) _bindingsLoader;

  _RuntimeDirectories? _directories;
  DesktopRuntimeBindings? _bindings;
  ReceivePort? _statusPort;
  _ResolvedArtifacts? _artifacts;
  ManagedProfilePayload? _stagedPayload;
  String? _stagedConfigPath;
  DateTime? _runningSince;
  RuntimePhase _phase = RuntimePhase.artifactMissing;
  String _message = _missingArtifactMessage;
  static const defaultCoreTag = 'v1.0.1';
  static const _missingArtifactMessage =
      'Модуль подключения не найден в этой сборке. Обновите приложение или проверьте сборку.';

  @override
  Future<RuntimeSnapshot> snapshot() async {
    final artifacts = _artifacts ?? await _resolveArtifacts();
    _artifacts = artifacts;

    if (artifacts.coreBinary == null) {
      _phase = RuntimePhase.artifactMissing;
      _message = _missingArtifactMessage;
      return _buildSnapshot(
        artifacts: artifacts,
        phase: RuntimePhase.artifactMissing,
        canInitialize: false,
        canConnect: false,
      );
    }

    final phase = _phase == RuntimePhase.artifactMissing
        ? RuntimePhase.artifactReady
        : _phase;
    _phase = phase;
    _message = switch (phase) {
      RuntimePhase.artifactReady =>
        'Ядро готово. Подключение запустится, когда приложение запросит старт.',
      RuntimePhase.initialized =>
        'Подготовка завершена. Осталось получить профиль доступа.',
      RuntimePhase.configStaged => 'Профиль доступа готов. Можно подключаться.',
      RuntimePhase.running => 'POKROV подключен с текущим профилем доступа.',
      RuntimePhase.artifactMissing => _missingArtifactMessage,
    };

    return _buildSnapshot(
      artifacts: artifacts,
      phase: phase,
      canInitialize: true,
      canConnect: phase.index >= RuntimePhase.configStaged.index,
    );
  }

  @override
  Future<RuntimeSnapshot> initialize() async {
    final artifacts = _artifacts ?? await _resolveArtifacts();
    _artifacts = artifacts;
    if (artifacts.coreBinary == null) {
      _phase = RuntimePhase.artifactMissing;
      _message = _missingArtifactMessage;
      return _buildSnapshot(
        artifacts: artifacts,
        phase: RuntimePhase.artifactMissing,
        canInitialize: false,
        canConnect: false,
      );
    }

    try {
      final directories = _directories ?? await _resolveDirectories();
      _directories = directories;
      _statusPort ??= ReceivePort('pokrov runtime status');
      _bindings ??= _bindingsLoader(artifacts.coreBinary!.path);
      final error = _bindings!.setup(
        baseDir: directories.baseDir.path,
        workingDir: directories.workingDir.path,
        tempDir: directories.tempDir.path,
        statusPort: _statusPort!.sendPort.nativePort,
        debug: false,
      );
      if (error.isNotEmpty) {
        _phase = RuntimePhase.artifactReady;
        _message = 'Не удалось подготовить подключение: $error';
        return _snapshotPreservingCurrentMessage(
          phase: _phase,
          canInitialize: true,
          canConnect: false,
        );
      } else {
        _phase = RuntimePhase.initialized;
        _message = 'Подготовка подключения завершена.';
      }
    } catch (error) {
      _phase = RuntimePhase.artifactReady;
      _message = 'Не удалось загрузить модуль подключения: $error';
      return _snapshotPreservingCurrentMessage(
        phase: _phase,
        canInitialize: true,
        canConnect: false,
      );
    }

    return snapshot();
  }

  @override
  Future<RuntimeSnapshot> stageManagedProfile(
    ManagedProfilePayload payload,
  ) async {
    final before = await initialize();
    if (!before.canInitialize || _bindings == null || _directories == null) {
      return before;
    }

    if (!payload.materializedForRuntime) {
      _phase = RuntimePhase.initialized;
      _message =
          'POKROV Core нужен уже собранный sing-box профиль. Обновите приложение или профиль доступа.';
      return _snapshotPreservingCurrentMessage(
        phase: _phase,
        canInitialize: true,
        canConnect: false,
      );
    }

    final finalPath = p.join(
      _directories!.configDir.path,
      'managed-profile.json',
    );
    try {
      final configPayload = _materializePokrovCoreConfig(
        payload.configPayload,
        payload.warpPolicy,
      );
      await File(finalPath).writeAsString(configPayload, flush: true);
    } on Object catch (error) {
      _phase = RuntimePhase.initialized;
      _message = 'Профиль доступа не прошел проверку: $error';
      return _snapshotPreservingCurrentMessage(
        phase: _phase,
        canInitialize: true,
        canConnect: false,
      );
    }

    final secureError = _bindings!.secureFile(finalPath);
    if (secureError.isNotEmpty) {
      _phase = RuntimePhase.initialized;
      _message = 'POKROV не смог защитить файл профиля: $secureError';
      return _snapshotPreservingCurrentMessage(
        phase: _phase,
        canInitialize: true,
        canConnect: false,
      );
    }

    _stagedPayload = payload;
    _stagedConfigPath = finalPath;
    _phase = RuntimePhase.configStaged;
    _message = 'Настройки POKROV готовы.';
    return snapshot();
  }

  @override
  Future<RuntimeSnapshot> connect() async {
    final before = await snapshot();
    if (!before.canConnect || _bindings == null || _stagedPayload == null) {
      _message = 'POKROV ждет подготовленные настройки и готовый runtime.';
      return _snapshotPreservingCurrentMessage(
        phase: _phase,
        canInitialize: before.canInitialize,
        canConnect: before.canConnect,
      );
    }

    final error = _bindings!.start(
      configPath: _stagedConfigPath!,
      disableMemoryLimit: _stagedPayload!.disableMemoryLimit,
    );
    if (error.isNotEmpty) {
      _phase = RuntimePhase.configStaged;
      _message = 'POKROV не смог подключиться: $error';
      return _snapshotPreservingCurrentMessage(
        phase: _phase,
        canInitialize: true,
        canConnect: true,
      );
    }

    final probeError = await _verifyStartedRuntime();
    if (probeError != null) {
      final stopError = _bindings!.stop();
      _phase = RuntimePhase.configStaged;
      _message = stopError.isEmpty
          ? 'POKROV запустил модуль, но трафик не проходит: $probeError'
          : 'POKROV запустил модуль, но трафик не проходит: $probeError; остановка тоже не удалась: $stopError';
      return _snapshotPreservingCurrentMessage(
        phase: _phase,
        canInitialize: true,
        canConnect: true,
      );
    }

    _phase = RuntimePhase.running;
    _runningSince ??= DateTime.now().toUtc();
    _message = 'POKROV включен.';
    return snapshot();
  }

  Future<String?> _verifyStartedRuntime() async {
    final injectedProbe = _connectivityProbe;
    if (injectedProbe != null) {
      return injectedProbe();
    }
    final mixedProxyPort = await _stagedMixedProxyPort();
    final attempts =
        _stagedPayload?.warpPolicy.canEnableRuntime == true ? 3 : 1;
    String? lastError;
    for (var attempt = 0; attempt < attempts; attempt += 1) {
      await Future<void>.delayed(
        Duration(milliseconds: attempt == 0 ? 900 : 1500),
      );
      lastError = await _probeHttp(
        proxyPort: mixedProxyPort,
        timeout: const Duration(seconds: 6),
      );
      if (lastError == null) {
        return null;
      }
    }
    return lastError;
  }

  Future<String?> _probeHttp({
    required int? proxyPort,
    required Duration timeout,
  }) async {
    final client = HttpClient();
    client.connectionTimeout = timeout;
    if (proxyPort != null) {
      client.findProxy = (uri) => 'PROXY 127.0.0.1:$proxyPort';
    }
    try {
      final request = await client
          .getUrl(Uri.parse('http://cp.cloudflare.com'))
          .timeout(timeout);
      request.followRedirects = false;
      final response = await request.close().timeout(timeout);
      await response.drain<void>().timeout(timeout);
      if (response.statusCode >= 200 && response.statusCode < 500) {
        return null;
      }
      return 'проверка соединения вернула HTTP ${response.statusCode}';
    } on Object catch (error) {
      return 'проверка соединения не прошла (${error.toString()})';
    } finally {
      client.close(force: true);
    }
  }

  Future<int?> _stagedMixedProxyPort() async {
    final configPath = _stagedConfigPath;
    if (configPath == null) {
      return null;
    }
    try {
      final decoded = jsonDecode(await File(configPath).readAsString());
      if (decoded is! Map || decoded['inbounds'] is! List) {
        return null;
      }
      for (final inbound in decoded['inbounds'] as List<dynamic>) {
        if (inbound is! Map || inbound['type'] != 'mixed') {
          continue;
        }
        final listen = inbound['listen']?.toString().trim().toLowerCase();
        if (listen != '127.0.0.1' && listen != 'localhost' && listen != '::1') {
          continue;
        }
        final port = inbound['listen_port'];
        if (port is int && port > 0 && port <= 65535) {
          return port;
        }
      }
    } on Object {
      return null;
    }
    return null;
  }

  @override
  Future<RuntimeSnapshot> disconnect() async {
    final artifacts = _artifacts ?? await _resolveArtifacts();
    _artifacts = artifacts;
    if (_bindings == null) {
      return snapshot();
    }

    final error = _bindings!.stop();
    if (error.isNotEmpty) {
      _message = 'POKROV не смог отключиться: $error';
      return _snapshotPreservingCurrentMessage(
        phase: _phase,
        canInitialize: artifacts.coreBinary != null,
        canConnect: _phase.index >= RuntimePhase.configStaged.index,
      );
    }

    _phase = _stagedConfigPath == null
        ? RuntimePhase.initialized
        : RuntimePhase.configStaged;
    _runningSince = null;
    _message = 'POKROV отключен.';
    return _snapshotPreservingCurrentMessage(
      phase: _phase,
      canInitialize: artifacts.coreBinary != null,
      canConnect: _stagedConfigPath != null,
    );
  }

  @override
  Future<WarpApplyResult> applyWarp({required bool enabled}) async {
    final staged = _stagedPayload;
    if (staged == null || _bindings == null) {
      return const WarpApplyResult.notApplied(reason: 'no_staged_profile');
    }
    final basePolicy = staged.warpPolicy.canOfferRuntime
        ? staged.warpPolicy
        : WarpRuntimePolicy.clientLocalDefault;
    final nextPolicy = basePolicy
        .withClientLocalDefaults()
        .withUserConsent(enabled)
        .copyWith(state: enabled ? 'consented' : 'revoked');
    final nextPayload = staged.copyWith(warpPolicy: nextPolicy);
    final configPath = _stagedConfigPath;
    if (configPath == null) {
      return const WarpApplyResult.notApplied(reason: 'no_staged_profile');
    }
    try {
      final config = _materializePokrovCoreConfig(
        staged.configPayload,
        nextPolicy,
      );
      await File(configPath).writeAsString(config, flush: true);
      final secureError = _bindings!.secureFile(configPath);
      if (secureError.isNotEmpty) {
        return WarpApplyResult.notApplied(reason: secureError);
      }
    } on Object catch (error) {
      return WarpApplyResult.notApplied(reason: error.toString());
    }
    _stagedPayload = nextPayload;
    return const WarpApplyResult(
      applied: true,
      effectiveAt: 'next_connect',
      fallbackUsed: false,
    );
  }

  @override
  Future<RuntimeLiveStats> liveStats() async {
    final running = _phase == RuntimePhase.running;
    final shortlist = _stagedPayload?.smartConnect?.shortlist;
    final smartNode =
        shortlist != null && shortlist.isNotEmpty ? shortlist.first : null;
    return RuntimeLiveStats(
      available: running,
      since: running ? _runningSince : null,
      serverCode: smartNode?.code ?? '',
      serverCountry: smartNode?.country ?? '',
      protocol: _stagedPayload == null ? '' : 'sing-box',
    );
  }

  @override
  Future<RuntimePushToken> pushToken() async {
    return const RuntimePushToken.unavailable();
  }

  Future<RuntimeSnapshot> _snapshotPreservingCurrentMessage({
    required RuntimePhase phase,
    required bool canInitialize,
    required bool canConnect,
  }) async {
    final artifacts = _artifacts ?? await _resolveArtifacts();
    _artifacts = artifacts;
    return _buildSnapshot(
      artifacts: artifacts,
      phase: phase,
      canInitialize: canInitialize,
      canConnect: canConnect,
    );
  }

  Future<_ResolvedArtifacts> _resolveArtifacts() async {
    final executableDirectory = File(Platform.resolvedExecutable).parent;
    final candidateDirectories = <Directory>{
      if (assetRootOverride != null) Directory(assetRootOverride!),
      if (Platform.environment.containsKey('POKROV_CORE_ROOT'))
        Directory(Platform.environment['POKROV_CORE_ROOT']!),
      executableDirectory,
      Directory(p.join(executableDirectory.path, 'runtime')),
      Directory(p.join(executableDirectory.path, 'resources', 'runtime')),
      Directory.current,
    };

    for (final base in candidateDirectories.toList()) {
      candidateDirectories.addAll(
        _expandVersionedDirectories(base, hostPlatform),
      );
    }

    final coreFileNames = switch (hostPlatform) {
      HostPlatform.windows => const ['pokrov-core.dll'],
      HostPlatform.macos => const ['pokrov-core.dylib'],
      HostPlatform.android || HostPlatform.ios => const <String>[],
    };

    for (final directory in candidateDirectories) {
      for (final coreFileName in coreFileNames) {
        final coreBinary = File(p.join(directory.path, coreFileName));
        if (!coreBinary.existsSync()) {
          continue;
        }

        return _ResolvedArtifacts(
          artifactDirectory: directory,
          coreBinary: coreBinary,
          helperBinary: null,
        );
      }
    }

    return const _ResolvedArtifacts(
      artifactDirectory: null,
      coreBinary: null,
      helperBinary: null,
    );
  }

  Iterable<Directory> _expandVersionedDirectories(
    Directory base,
    HostPlatform platform,
  ) sync* {
    final platformSegment = switch (platform) {
      HostPlatform.windows => 'windows',
      HostPlatform.macos => 'macos',
      HostPlatform.android => 'android',
      HostPlatform.ios => 'ios',
    };

    for (final candidate in [
      p.join(base.path, platformSegment),
      p.join(base.path, 'pokrov-core', platformSegment),
      p.join(base.path, 'artifacts', 'pokrov-core', platformSegment),
      p.join(base.path, 'artifacts', 'pokrov-core', defaultCoreTag,
          platformSegment),
      if (platform == HostPlatform.macos) p.join(base.path, '..', 'Frameworks'),
      if (platform == HostPlatform.macos)
        p.join(base.path, '..', 'Frameworks', 'Runtime'),
      if (platform == HostPlatform.macos)
        p.join(base.path, '..', 'Resources', 'runtime'),
    ]) {
      yield Directory(candidate);
    }
  }

  Future<_RuntimeDirectories> _resolveDirectories() async {
    final supportDirectory = await _supportDirectory();
    final baseDir = Directory(p.join(supportDirectory.path, 'pokrov-runtime'));
    final workingDir = Directory(p.join(baseDir.path, 'working'));
    final tempDir = Directory(p.join(baseDir.path, 'temp'));
    final configDir = Directory(p.join(workingDir.path, 'configs'));
    final baseDataDir = Directory(p.join(baseDir.path, 'data'));
    final workingDataDir = Directory(p.join(workingDir.path, 'data'));

    for (final directory in [
      baseDir,
      workingDir,
      tempDir,
      configDir,
      baseDataDir,
      workingDataDir,
    ]) {
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
    }

    return (
      baseDir: baseDir,
      workingDir: workingDir,
      tempDir: tempDir,
      configDir: configDir,
    );
  }

  Future<Directory> _supportDirectory() async {
    try {
      return await getApplicationSupportDirectory();
    } catch (_) {
      return Directory(p.join(Directory.systemTemp.path, 'pokrov-next-client'));
    }
  }

  RuntimeSnapshot _buildSnapshot({
    required _ResolvedArtifacts artifacts,
    required RuntimePhase phase,
    required bool canInitialize,
    required bool canConnect,
  }) {
    return RuntimeSnapshot(
      hostPlatform: hostPlatform,
      lane: RuntimeLane.desktopFfi,
      phase: phase,
      artifactDirectory: artifacts.artifactDirectory?.path,
      coreBinaryPath: artifacts.coreBinary?.path,
      helperBinaryPath: artifacts.helperBinary?.path,
      stagedConfigPath: _stagedConfigPath,
      supportsLiveConnect: true,
      canInitialize: canInitialize,
      canConnect: canConnect,
      message: _message,
    );
  }
}

const _pokrovWarpEndpointTag = 'pokrov-warp';

String _materializePokrovCoreConfig(
  String configPayload,
  WarpRuntimePolicy policy,
) {
  final decoded = jsonDecode(configPayload);
  if (decoded is! Map) {
    throw const FormatException('sing-box config must be a JSON object');
  }
  final config = decoded.map<String, Object?>(
    (key, value) => MapEntry(key.toString(), value),
  );
  if (!policy.canEnableRuntime) {
    return const JsonEncoder.withIndent('  ').convert(config);
  }

  final outbounds = _runtimeMapList(config['outbounds']);
  final route = Map<String, Object?>.from(_runtimeObjectMap(config['route']));
  if (outbounds.isEmpty || route.isEmpty) {
    throw const FormatException(
      'WARP requires a materialized sing-box route and outbounds',
    );
  }

  final directTag = _firstOutboundTagByType(outbounds, const {'direct'});
  final proxyTag = _primaryProxyTag(outbounds, route);
  final warpOverProxy = policy.mode == 'warp_over_proxy';
  if (warpOverProxy && proxyTag == null) {
    throw const FormatException('WARP-over-proxy requires a proxy outbound');
  }

  final profile = <String, Object?>{
    if (policy.accountId.trim().isNotEmpty &&
        policy.accessToken.trim().isNotEmpty) ...{
      'id': policy.accountId.trim(),
      'auth_token': policy.accessToken.trim(),
    },
    if (policy.licenseKey.trim().isNotEmpty)
      'license': policy.licenseKey.trim(),
    if (warpOverProxy && proxyTag != null)
      'detour': proxyTag
    else if (directTag != null)
      'detour': directTag,
  };
  final wireguardConfig = policy.wireguardConfigObject;
  final legacyPrivateKey = _runtimeText(
    wireguardConfig?['private_key'] ?? wireguardConfig?['private-key'],
  );
  if (legacyPrivateKey.isNotEmpty) {
    profile['private_key'] = legacyPrivateKey;
  }

  final endpoint = <String, Object?>{
    'type': 'warp',
    'tag': _pokrovWarpEndpointTag,
    'unique_identifier': policy.id.trim().isEmpty ? 'p1' : policy.id.trim(),
    'profile': profile,
    'mtu': 1280,
    if (warpOverProxy && proxyTag != null)
      'detour': proxyTag
    else if (directTag != null)
      'detour': directTag,
  };
  _mergeNativeWarpConfig(endpoint, wireguardConfig);

  final cleanIp = policy.cleanIp.trim();
  if (cleanIp.isNotEmpty &&
      !const {'auto', 'auto4', 'auto6', 'default', 'random'}
          .contains(cleanIp.toLowerCase())) {
    endpoint['server'] = cleanIp;
    if (policy.cleanPort > 0 && policy.cleanPort <= 65535) {
      endpoint['server_port'] = policy.cleanPort;
    }
  }
  final noiseCount = policy.noise.trim();
  if (noiseCount.isNotEmpty) {
    endpoint['noise'] = <String, Object?>{
      'fake_packet': <String, Object?>{
        'enabled': true,
        'count': noiseCount,
        'size':
            policy.noiseSize.trim().isEmpty ? '10-30' : policy.noiseSize.trim(),
        'delay': policy.noiseDelay.trim().isEmpty
            ? '10-30'
            : policy.noiseDelay.trim(),
        'mode':
            policy.noiseMode.trim().isEmpty ? 'm4' : policy.noiseMode.trim(),
      },
    };
  }

  final endpoints = _runtimeMapList(config['endpoints'])
    ..removeWhere(
      (item) => _runtimeText(item['tag']) == _pokrovWarpEndpointTag,
    )
    ..add(endpoint);
  config['endpoints'] = endpoints;

  if (warpOverProxy) {
    _replaceOutboundReference(route, proxyTag!, _pokrovWarpEndpointTag);
    final dns = Map<String, Object?>.from(_runtimeObjectMap(config['dns']));
    _replaceDetourReference(dns, proxyTag, _pokrovWarpEndpointTag);
    if (dns.isNotEmpty) {
      config['dns'] = dns;
    }
  } else {
    for (final outbound in outbounds) {
      if (_isProxyTransportForWarp(outbound)) {
        outbound['detour'] = _pokrovWarpEndpointTag;
      }
    }
  }
  config['outbounds'] = outbounds;
  config['route'] = route;

  final experimental =
      Map<String, Object?>.from(_runtimeObjectMap(config['experimental']));
  final cacheFile =
      Map<String, Object?>.from(_runtimeObjectMap(experimental['cache_file']));
  cacheFile
    ..['enabled'] = true
    ..['store_warp_config'] = true;
  if (_runtimeText(cacheFile['path']).isEmpty) {
    cacheFile['path'] = 'data/clash.db';
  }
  experimental['cache_file'] = cacheFile;
  config['experimental'] = experimental;

  return const JsonEncoder.withIndent('  ').convert(config);
}

List<Map<String, Object?>> _runtimeMapList(Object? value) {
  if (value is! List) {
    return <Map<String, Object?>>[];
  }
  return value
      .whereType<Map>()
      .map(
        (item) => item.map<String, Object?>(
          (key, entryValue) => MapEntry(key.toString(), entryValue),
        ),
      )
      .toList(growable: true);
}

String? _firstOutboundTagByType(
  List<Map<String, Object?>> outbounds,
  Set<String> types,
) {
  for (final outbound in outbounds) {
    if (types.contains(_runtimeText(outbound['type']).toLowerCase())) {
      final tag = _runtimeText(outbound['tag']);
      if (tag.isNotEmpty) {
        return tag;
      }
    }
  }
  return null;
}

String? _primaryProxyTag(
  List<Map<String, Object?>> outbounds,
  Map<String, Object?> route,
) {
  final byTag = <String, Map<String, Object?>>{
    for (final outbound in outbounds)
      if (_runtimeText(outbound['tag']).isNotEmpty)
        _runtimeText(outbound['tag']): outbound,
  };
  final routeFinal = _runtimeText(route['final']);
  final finalOutbound = byTag[routeFinal];
  if (finalOutbound != null && !_isAuxiliaryOutboundForWarp(finalOutbound)) {
    return routeFinal;
  }
  final groupTag = _firstOutboundTagByType(
    outbounds,
    const {'selector', 'urltest', 'url-test', 'balancer'},
  );
  if (groupTag != null) {
    return groupTag;
  }
  for (final outbound in outbounds) {
    if (_isProxyTransportForWarp(outbound)) {
      final tag = _runtimeText(outbound['tag']);
      if (tag.isNotEmpty) {
        return tag;
      }
    }
  }
  return null;
}

bool _isAuxiliaryOutboundForWarp(Map<String, Object?> outbound) {
  final type = _runtimeText(outbound['type']).toLowerCase();
  return const {'direct', 'block', 'dns', 'warp'}.contains(type);
}

bool _isProxyTransportForWarp(Map<String, Object?> outbound) {
  final type = _runtimeText(outbound['type']).toLowerCase();
  return !const {
    'direct',
    'block',
    'dns',
    'selector',
    'urltest',
    'url-test',
    'balancer',
    'warp',
  }.contains(type);
}

void _replaceOutboundReference(
  Object? value,
  String from,
  String to,
) {
  if (value is Map) {
    for (final key in value.keys.toList(growable: false)) {
      if (key.toString() == 'outbound' && value[key] == from) {
        value[key] = to;
      } else {
        _replaceOutboundReference(value[key], from, to);
      }
    }
  } else if (value is List) {
    for (final item in value) {
      _replaceOutboundReference(item, from, to);
    }
  }
}

void _replaceDetourReference(Object? value, String from, String to) {
  if (value is Map) {
    for (final key in value.keys.toList(growable: false)) {
      if (key.toString() == 'detour' && value[key] == from) {
        value[key] = to;
      } else {
        _replaceDetourReference(value[key], from, to);
      }
    }
  } else if (value is List) {
    for (final item in value) {
      _replaceDetourReference(item, from, to);
    }
  }
}

void _mergeNativeWarpConfig(
  Map<String, Object?> endpoint,
  Map<String, Object?>? rawConfig,
) {
  if (rawConfig == null || rawConfig.isEmpty) {
    return;
  }
  final nested = _runtimeObjectMap(rawConfig['config']);
  final config = nested.isEmpty ? rawConfig : nested;
  final privateKey = _runtimeText(config['private_key']);
  final interface = _runtimeObjectMap(config['interface']);
  final peers = config['peers'];
  if (privateKey.isEmpty ||
      interface.isEmpty ||
      peers is! List ||
      peers.isEmpty) {
    return;
  }
  endpoint
    ..['private_key'] = privateKey
    ..['interface'] = interface
    ..['peers'] = peers;
}

class MobileArtifactRuntimeEngine implements PokrovRuntimeEngine {
  MobileArtifactRuntimeEngine({
    required this.hostPlatform,
    this.assetRootOverride,
  });

  final HostPlatform hostPlatform;
  final String? assetRootOverride;
  ManagedProfilePayload? _stagedPayload;

  static const defaultCoreTag = DesktopRuntimeEngine.defaultCoreTag;
  static const _runtimeChannel = MethodChannel('space.pokrov/runtime_engine');

  @override
  Future<RuntimeSnapshot> snapshot() async {
    final hostSnapshot = await _invokeHostSnapshot('runtimeEngine.snapshot');
    if (hostSnapshot != null) {
      return hostSnapshot;
    }

    final artifacts = await _resolveArtifacts();
    return RuntimeSnapshot(
      hostPlatform: hostPlatform,
      lane: RuntimeLane.mobileArtifact,
      phase: artifacts.coreArtifact != null
          ? RuntimePhase.artifactReady
          : RuntimePhase.artifactMissing,
      artifactDirectory: artifacts.artifactDirectory?.path,
      coreBinaryPath: artifacts.coreArtifact?.path,
      helperBinaryPath: null,
      stagedConfigPath: null,
      supportsLiveConnect: false,
      canInitialize: false,
      canConnect: false,
      message: artifacts.coreArtifact != null
          ? 'Модуль подключения найден. Запустите POKROV на устройстве, чтобы подключиться.'
          : 'Модуль подключения не найден в этой сборке. Обновите приложение или проверьте сборку.',
    );
  }

  @override
  Future<RuntimeSnapshot> initialize() async {
    final hostSnapshot = await _invokeHostSnapshot('runtimeEngine.initialize');
    return hostSnapshot ?? await snapshot();
  }

  @override
  Future<RuntimeSnapshot> stageManagedProfile(
    ManagedProfilePayload payload,
  ) async {
    if (!payload.materializedForRuntime) {
      return await snapshot();
    }
    final configPayload = _materializePokrovCoreConfig(
      payload.configPayload,
      payload.warpPolicy,
    );
    _stagedPayload = payload;
    final hostSnapshot = await _invokeHostSnapshot(
      'runtimeEngine.stageManagedProfile',
      arguments: <String, Object?>{
        'profileName': payload.profileName,
        'configPayload': configPayload,
        'disableMemoryLimit': payload.disableMemoryLimit,
        'materializedForRuntime': true,
      },
    );
    return hostSnapshot ?? await snapshot();
  }

  @override
  Future<RuntimeSnapshot> connect() async {
    final hostSnapshot = await _invokeHostSnapshot('runtimeEngine.connect');
    return hostSnapshot ?? await snapshot();
  }

  @override
  Future<RuntimeSnapshot> disconnect() async {
    final hostSnapshot = await _invokeHostSnapshot('runtimeEngine.disconnect');
    return hostSnapshot ?? await snapshot();
  }

  @override
  Future<WarpApplyResult> applyWarp({required bool enabled}) async {
    final staged = _stagedPayload;
    if (staged == null) {
      return const WarpApplyResult.notApplied(reason: 'no_staged_profile');
    }
    final basePolicy = staged.warpPolicy.canOfferRuntime
        ? staged.warpPolicy
        : WarpRuntimePolicy.clientLocalDefault;
    final nextPolicy = basePolicy
        .withClientLocalDefaults()
        .withUserConsent(enabled)
        .copyWith(state: enabled ? 'consented' : 'revoked');
    final nextPayload = staged.copyWith(warpPolicy: nextPolicy);
    final configPayload = _materializePokrovCoreConfig(
      staged.configPayload,
      nextPolicy,
    );
    final response = await _invokeHostMap(
      'runtimeEngine.applyWarp',
      arguments: <String, Object?>{
        'enabled': enabled,
        'configPayload': configPayload,
      },
    );
    final result = response == null
        ? const WarpApplyResult.notApplied(reason: 'host_bridge_unavailable')
        : WarpApplyResult.fromMap(response);
    if (result.applied) {
      _stagedPayload = nextPayload;
    }
    return result;
  }

  @override
  Future<RuntimeLiveStats> liveStats() async {
    final response = await _invokeHostMap('runtimeEngine.liveStats');
    return response == null
        ? const RuntimeLiveStats.unavailable()
        : RuntimeLiveStats.fromMap(response);
  }

  @override
  Future<RuntimePushToken> pushToken() async {
    final response = await _invokeHostMap('runtimeEngine.pushToken');
    return response == null
        ? const RuntimePushToken.unavailable()
        : RuntimePushToken.fromMap(response);
  }

  Future<Map<String, Object?>?> _invokeHostMap(
    String method, {
    Map<String, Object?>? arguments,
  }) async {
    if (!hostPlatform.isMobileRuntimeBridgeTarget) {
      return null;
    }

    try {
      return await _runtimeChannel.invokeMapMethod<String, Object?>(
        method,
        arguments,
      );
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  Future<RuntimeSnapshot?> _invokeHostSnapshot(
    String method, {
    Map<String, Object?>? arguments,
  }) async {
    if (!hostPlatform.isMobileRuntimeBridgeTarget) {
      return null;
    }

    try {
      final response = await _runtimeChannel.invokeMapMethod<String, Object?>(
        method,
        arguments,
      );
      if (response == null) {
        return null;
      }

      return _snapshotFromHostMap(response);
    } on MissingPluginException {
      return null;
    } on PlatformException catch (error) {
      if (method != 'runtimeEngine.snapshot') {
        final fallback = await _trySnapshotAfterPlatformError(error);
        if (fallback != null) {
          return fallback;
        }
      }
      return RuntimeSnapshot(
        hostPlatform: hostPlatform,
        lane: RuntimeLane.mobileArtifact,
        phase: RuntimePhase.artifactMissing,
        artifactDirectory: null,
        coreBinaryPath: null,
        helperBinaryPath: null,
        stagedConfigPath: null,
        supportsLiveConnect: true,
        canInitialize: true,
        canConnect: false,
        message: error.message?.trim().isNotEmpty == true
            ? error.message!.trim()
            : 'Не удалось связаться с системным модулем: ${error.code}',
      );
    }
  }

  Future<RuntimeSnapshot?> _trySnapshotAfterPlatformError(
    PlatformException error,
  ) async {
    try {
      final fallback = await _runtimeChannel.invokeMapMethod<String, Object?>(
        'runtimeEngine.snapshot',
      );
      if (fallback == null) {
        return null;
      }
      final snapshot = _snapshotFromHostMap(fallback);
      final detail = error.message?.trim();
      return RuntimeSnapshot(
        hostPlatform: snapshot.hostPlatform,
        lane: snapshot.lane,
        phase: snapshot.phase,
        artifactDirectory: snapshot.artifactDirectory,
        coreBinaryPath: snapshot.coreBinaryPath,
        helperBinaryPath: snapshot.helperBinaryPath,
        stagedConfigPath: snapshot.stagedConfigPath,
        supportsLiveConnect: snapshot.supportsLiveConnect,
        canInitialize: snapshot.canInitialize,
        canConnect: snapshot.canConnect,
        message: detail == null || detail.isEmpty
            ? snapshot.message
            : '${snapshot.message} ($detail)',
        hostHealth: snapshot.hostHealth,
        dnsState: snapshot.dnsState,
        uplinkState: snapshot.uplinkState,
        hostDiagnosticsSummary: snapshot.hostDiagnosticsSummary,
        defaultNetworkInterface: snapshot.defaultNetworkInterface,
        defaultNetworkIndex: snapshot.defaultNetworkIndex,
        dnsReady: snapshot.dnsReady,
        lastFailureKind: snapshot.lastFailureKind,
        lastStopReason: snapshot.lastStopReason,
        ipv4RouteCount: snapshot.ipv4RouteCount,
        ipv6RouteCount: snapshot.ipv6RouteCount,
        includePackageCount: snapshot.includePackageCount,
        excludePackageCount: snapshot.excludePackageCount,
      );
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  RuntimeSnapshot _snapshotFromHostMap(Map<String, Object?> response) {
    final hostDiagnostics = _readObjectMap(response['hostDiagnostics']);
    final phase = _runtimePhaseFromWireValue(response['phase']);
    final defaultNetworkInterface = _firstNonEmptyString(
      response,
      hostDiagnostics,
      const [
        'defaultNetworkInterface',
        'default_network_interface',
        'defaultInterface',
        'default_interface',
      ],
    );
    final defaultNetworkIndex = _firstIntValue(
      response,
      hostDiagnostics,
      const [
        'defaultNetworkIndex',
        'default_network_index',
      ],
    );
    final dnsReady = _firstBoolValue(
      response,
      hostDiagnostics,
      const [
        'dnsReady',
        'dns_ready',
      ],
    );
    final lastFailureKind = _firstNonEmptyString(
      response,
      hostDiagnostics,
      const [
        'lastFailureKind',
        'last_failure_kind',
        'failureKind',
        'failure_kind',
      ],
    );
    final lastStopReason = _firstNonEmptyString(
      response,
      hostDiagnostics,
      const [
        'lastStopReason',
        'last_stop_reason',
        'stopReason',
        'stop_reason',
      ],
    );
    final ipv4RouteCount = _firstIntValue(
      response,
      hostDiagnostics,
      const [
        'ipv4RouteCount',
        'ipv4_route_count',
      ],
    );
    final ipv6RouteCount = _firstIntValue(
      response,
      hostDiagnostics,
      const [
        'ipv6RouteCount',
        'ipv6_route_count',
      ],
    );
    final includePackageCount = _firstIntValue(
      response,
      hostDiagnostics,
      const [
        'includePackageCount',
        'include_package_count',
      ],
    );
    final excludePackageCount = _firstIntValue(
      response,
      hostDiagnostics,
      const [
        'excludePackageCount',
        'exclude_package_count',
      ],
    );
    final hostHealth = _runtimeHostHealthFromWireValue(
      _firstDefinedValue(
        response,
        hostDiagnostics,
        const ['hostHealth', 'host_health', 'health'],
      ),
    );
    final dnsState = _runtimeDiagnosticStateFromWireValue(
      _firstDefinedValue(
        response,
        hostDiagnostics,
        const ['dnsState', 'dns_state', 'dnsStatus', 'dns_status', 'dns'],
      ),
    );
    final uplinkState = _runtimeDiagnosticStateFromWireValue(
      _firstDefinedValue(
        response,
        hostDiagnostics,
        const [
          'uplinkState',
          'uplink_state',
          'uplinkStatus',
          'uplink_status',
          'uplink',
        ],
      ),
    );
    final resolvedDnsState = dnsState == RuntimeDiagnosticState.unknown
        ? _deriveDnsState(
            phase: phase,
            dnsReady: dnsReady,
            lastFailureKind: lastFailureKind,
          )
        : dnsState;
    final resolvedUplinkState = uplinkState == RuntimeDiagnosticState.unknown
        ? _deriveUplinkState(
            phase: phase,
            defaultNetworkInterface: defaultNetworkInterface,
            defaultNetworkIndex: defaultNetworkIndex,
            lastFailureKind: lastFailureKind,
          )
        : uplinkState;
    final resolvedHostHealth = hostHealth == RuntimeHostHealth.unknown
        ? _deriveHostHealth(
            phase: phase,
            dnsState: resolvedDnsState,
            uplinkState: resolvedUplinkState,
            lastFailureKind: lastFailureKind,
          )
        : hostHealth;
    final hostDiagnosticsSummary = _firstNonEmptyString(
          response,
          hostDiagnostics,
          const [
            'hostDiagnosticsSummary',
            'host_diagnostics_summary',
            'diagnosticsSummary',
            'diagnostics_summary',
            'summary',
          ],
        ) ??
        _deriveDiagnosticsSummary(
          phase: phase,
          hostHealth: resolvedHostHealth,
          dnsState: resolvedDnsState,
          uplinkState: resolvedUplinkState,
          defaultNetworkInterface: defaultNetworkInterface,
          defaultNetworkIndex: defaultNetworkIndex,
          dnsReady: dnsReady,
          lastFailureKind: lastFailureKind,
          ipv4RouteCount: ipv4RouteCount,
          ipv6RouteCount: ipv6RouteCount,
          includePackageCount: includePackageCount,
          excludePackageCount: excludePackageCount,
        );
    return RuntimeSnapshot(
      hostPlatform: hostPlatform,
      lane: RuntimeLane.mobileArtifact,
      phase: phase,
      artifactDirectory: response['artifactDirectory'] as String?,
      coreBinaryPath: response['coreBinaryPath'] as String?,
      helperBinaryPath: response['helperBinaryPath'] as String?,
      stagedConfigPath: response['stagedConfigPath'] as String?,
      supportsLiveConnect: response['supportsLiveConnect'] as bool? ?? false,
      canInitialize: response['canInitialize'] as bool? ?? false,
      canConnect: response['canConnect'] as bool? ?? false,
      message: response['message'] as String? ??
          'Runtime не вернул статус подключения.',
      hostHealth: resolvedHostHealth,
      dnsState: resolvedDnsState,
      uplinkState: resolvedUplinkState,
      hostDiagnosticsSummary: hostDiagnosticsSummary,
      defaultNetworkInterface: defaultNetworkInterface,
      defaultNetworkIndex: defaultNetworkIndex,
      dnsReady: dnsReady,
      lastFailureKind: lastFailureKind,
      lastStopReason: lastStopReason,
      ipv4RouteCount: ipv4RouteCount,
      ipv6RouteCount: ipv6RouteCount,
      includePackageCount: includePackageCount,
      excludePackageCount: excludePackageCount,
    );
  }

  RuntimePhase _runtimePhaseFromWireValue(Object? value) {
    switch (value) {
      case 'artifactReady':
        return RuntimePhase.artifactReady;
      case 'initialized':
        return RuntimePhase.initialized;
      case 'configStaged':
        return RuntimePhase.configStaged;
      case 'running':
        return RuntimePhase.running;
      case 'artifactMissing':
      default:
        return RuntimePhase.artifactMissing;
    }
  }

  RuntimeHostHealth _runtimeHostHealthFromWireValue(Object? value) {
    switch (value) {
      case 'healthy':
      case 'ok':
      case 'clean':
        return RuntimeHostHealth.healthy;
      case 'degraded':
      case 'warning':
      case 'warnings':
        return RuntimeHostHealth.degraded;
      default:
        return RuntimeHostHealth.unknown;
    }
  }

  RuntimeDiagnosticState _runtimeDiagnosticStateFromWireValue(Object? value) {
    switch (value) {
      case 'healthy':
      case 'ok':
      case 'clean':
        return RuntimeDiagnosticState.healthy;
      case 'degraded':
      case 'warning':
      case 'warnings':
        return RuntimeDiagnosticState.degraded;
      default:
        return RuntimeDiagnosticState.unknown;
    }
  }

  Map<String, Object?> _readObjectMap(Object? value) {
    if (value is Map<String, Object?>) {
      return value;
    }
    if (value is Map) {
      return value.map(
        (key, item) => MapEntry(key.toString(), item),
      );
    }
    return const <String, Object?>{};
  }

  Object? _firstDefinedValue(
    Map<String, Object?> topLevel,
    Map<String, Object?> nested,
    List<String> keys,
  ) {
    for (final key in keys) {
      if (topLevel.containsKey(key) && topLevel[key] != null) {
        return topLevel[key];
      }
      if (nested.containsKey(key) && nested[key] != null) {
        return nested[key];
      }
    }
    return null;
  }

  String? _firstNonEmptyString(
    Map<String, Object?> topLevel,
    Map<String, Object?> nested,
    List<String> keys,
  ) {
    for (final key in keys) {
      final topValue = topLevel[key]?.toString().trim() ?? '';
      if (topValue.isNotEmpty) {
        return topValue;
      }
      final nestedValue = nested[key]?.toString().trim() ?? '';
      if (nestedValue.isNotEmpty) {
        return nestedValue;
      }
    }
    return null;
  }

  int? _firstIntValue(
    Map<String, Object?> topLevel,
    Map<String, Object?> nested,
    List<String> keys,
  ) {
    for (final key in keys) {
      final topValue = _coerceInt(topLevel[key]);
      if (topValue != null) {
        return topValue;
      }
      final nestedValue = _coerceInt(nested[key]);
      if (nestedValue != null) {
        return nestedValue;
      }
    }
    return null;
  }

  bool? _firstBoolValue(
    Map<String, Object?> topLevel,
    Map<String, Object?> nested,
    List<String> keys,
  ) {
    for (final key in keys) {
      final topValue = _coerceBool(topLevel[key]);
      if (topValue != null) {
        return topValue;
      }
      final nestedValue = _coerceBool(nested[key]);
      if (nestedValue != null) {
        return nestedValue;
      }
    }
    return null;
  }

  int? _coerceInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '');
  }

  bool? _coerceBool(Object? value) {
    if (value is bool) {
      return value;
    }
    switch (value?.toString().trim().toLowerCase()) {
      case 'true':
      case '1':
      case 'yes':
      case 'ready':
      case 'healthy':
        return true;
      case 'false':
      case '0':
      case 'no':
      case 'waiting':
      case 'degraded':
        return false;
      default:
        return null;
    }
  }

  RuntimeHostHealth _deriveHostHealth({
    required RuntimePhase phase,
    required RuntimeDiagnosticState dnsState,
    required RuntimeDiagnosticState uplinkState,
    required String? lastFailureKind,
  }) {
    if (phase != RuntimePhase.running) {
      return RuntimeHostHealth.unknown;
    }
    if (dnsState == RuntimeDiagnosticState.degraded ||
        uplinkState == RuntimeDiagnosticState.degraded ||
        (lastFailureKind?.trim().isNotEmpty ?? false)) {
      return RuntimeHostHealth.degraded;
    }
    if (dnsState == RuntimeDiagnosticState.healthy &&
        uplinkState == RuntimeDiagnosticState.healthy) {
      return RuntimeHostHealth.healthy;
    }
    return RuntimeHostHealth.unknown;
  }

  RuntimeDiagnosticState _deriveDnsState({
    required RuntimePhase phase,
    required bool? dnsReady,
    required String? lastFailureKind,
  }) {
    if (phase != RuntimePhase.running) {
      return RuntimeDiagnosticState.unknown;
    }
    if (_isDnsFailureKind(lastFailureKind)) {
      return RuntimeDiagnosticState.degraded;
    }
    if (dnsReady == true) {
      return RuntimeDiagnosticState.healthy;
    }
    if (dnsReady == false) {
      return RuntimeDiagnosticState.degraded;
    }
    return RuntimeDiagnosticState.unknown;
  }

  RuntimeDiagnosticState _deriveUplinkState({
    required RuntimePhase phase,
    required String? defaultNetworkInterface,
    required int? defaultNetworkIndex,
    required String? lastFailureKind,
  }) {
    if (phase != RuntimePhase.running) {
      return RuntimeDiagnosticState.unknown;
    }
    if (_isUplinkFailureKind(lastFailureKind)) {
      return RuntimeDiagnosticState.degraded;
    }
    if ((defaultNetworkInterface?.trim().isNotEmpty ?? false) &&
        defaultNetworkIndex != null &&
        defaultNetworkIndex >= 0) {
      return RuntimeDiagnosticState.healthy;
    }
    if ((defaultNetworkInterface?.trim().isNotEmpty ?? false) ||
        defaultNetworkIndex != null) {
      return RuntimeDiagnosticState.degraded;
    }
    return RuntimeDiagnosticState.degraded;
  }

  bool _isDnsFailureKind(String? value) {
    final normalized = value?.trim().toLowerCase() ?? '';
    return normalized.startsWith('resolver_') ||
        normalized.startsWith('dns_') ||
        normalized.startsWith('default_network_');
  }

  bool _isUplinkFailureKind(String? value) {
    final normalized = value?.trim().toLowerCase() ?? '';
    return normalized.startsWith('default_network_');
  }

  String? _deriveDiagnosticsSummary({
    required RuntimePhase phase,
    required RuntimeHostHealth hostHealth,
    required RuntimeDiagnosticState dnsState,
    required RuntimeDiagnosticState uplinkState,
    required String? defaultNetworkInterface,
    required int? defaultNetworkIndex,
    required bool? dnsReady,
    required String? lastFailureKind,
    required int? ipv4RouteCount,
    required int? ipv6RouteCount,
    required int? includePackageCount,
    required int? excludePackageCount,
  }) {
    if (phase != RuntimePhase.running) {
      return null;
    }

    final details = <String>[
      if ((defaultNetworkInterface?.trim().isNotEmpty ?? false))
        defaultNetworkIndex != null
            ? 'Сеть $defaultNetworkInterface (#$defaultNetworkIndex)'
            : 'Сеть $defaultNetworkInterface'
      else if (uplinkState == RuntimeDiagnosticState.degraded)
        'Сеть не определена',
      if (dnsReady != null)
        'DNS ${dnsReady ? 'готов' : 'ждет'}'
      else if (dnsState != RuntimeDiagnosticState.unknown)
        'DNS ${RuntimeSnapshot._diagnosticStateLabel(dnsState)}',
      if (ipv4RouteCount != null || ipv6RouteCount != null)
        'Правила v4=${ipv4RouteCount ?? 0} v6=${ipv6RouteCount ?? 0}',
      if ((includePackageCount ?? 0) > 0 || (excludePackageCount ?? 0) > 0)
        'Приложения include=${includePackageCount ?? 0} exclude=${excludePackageCount ?? 0}',
      if ((lastFailureKind?.trim().isNotEmpty ?? false))
        'Последняя ошибка $lastFailureKind',
    ];

    if (details.isEmpty) {
      return switch (hostHealth) {
        RuntimeHostHealth.healthy => 'Диагностика Android без замечаний.',
        RuntimeHostHealth.degraded =>
          'Диагностика Android сообщает предупреждение.',
        RuntimeHostHealth.unknown => null,
      };
    }
    return details.join(' | ');
  }

  Future<_ResolvedMobileArtifacts> _resolveArtifacts() async {
    final platformSegment = switch (hostPlatform) {
      HostPlatform.android => 'android',
      HostPlatform.ios => 'ios',
      HostPlatform.windows || HostPlatform.macos => '',
    };
    final artifactName = switch (hostPlatform) {
      HostPlatform.android => 'pokrov-core.aar',
      HostPlatform.ios => 'PokrovCore.xcframework',
      HostPlatform.windows || HostPlatform.macos => '',
    };

    final candidateDirectories = <Directory>{
      if (assetRootOverride != null) Directory(assetRootOverride!),
      if (Platform.environment.containsKey('POKROV_CORE_ROOT'))
        Directory(Platform.environment['POKROV_CORE_ROOT']!),
      Directory.current,
    };

    for (final base in candidateDirectories.toList()) {
      candidateDirectories.addAll([
        Directory(p.join(base.path, platformSegment)),
        Directory(p.join(base.path, 'pokrov-core', platformSegment)),
        Directory(p.join(base.path, 'artifacts', 'pokrov-core', platformSegment)),
        Directory(
          p.join(base.path, 'artifacts', 'pokrov-core', defaultCoreTag,
              platformSegment),
        ),
      ]);
    }

    for (final directory in candidateDirectories) {
      final fileSystemEntity = FileSystemEntity.typeSync(
        p.join(directory.path, artifactName),
      );
      if (fileSystemEntity == FileSystemEntityType.notFound) {
        continue;
      }

      return _ResolvedMobileArtifacts(
        artifactDirectory: directory,
        coreArtifact: FileSystemEntity.isDirectorySync(
          p.join(directory.path, artifactName),
        )
            ? Directory(p.join(directory.path, artifactName))
            : File(p.join(directory.path, artifactName)),
      );
    }

    return const _ResolvedMobileArtifacts(
      artifactDirectory: null,
      coreArtifact: null,
    );
  }
}

extension on HostPlatform {
  bool get isMobileRuntimeBridgeTarget =>
      this == HostPlatform.android || this == HostPlatform.ios;
}

typedef _RuntimeDirectories = ({
  Directory baseDir,
  Directory workingDir,
  Directory tempDir,
  Directory configDir,
});

class _ResolvedArtifacts {
  const _ResolvedArtifacts({
    required this.artifactDirectory,
    required this.coreBinary,
    required this.helperBinary,
  });

  final Directory? artifactDirectory;
  final File? coreBinary;
  final File? helperBinary;
}

class _ResolvedMobileArtifacts {
  const _ResolvedMobileArtifacts({
    required this.artifactDirectory,
    required this.coreArtifact,
  });

  final Directory? artifactDirectory;
  final FileSystemEntity? coreArtifact;
}

abstract interface class DesktopRuntimeBindings {
  String secureFile(String path);

  String setup({
    required String baseDir,
    required String workingDir,
    required String tempDir,
    required int statusPort,
    required bool debug,
  });

  String start({
    required String configPath,
    required bool disableMemoryLimit,
  });

  String stop();
}

class _PokrovCoreBindingsLoader {
  static DesktopRuntimeBindings load(String libraryPath) {
    final dynamicLibrary = DynamicLibrary.open(libraryPath);
    final pokrovCoreAbi = _pokrovCoreAbiVersion(dynamicLibrary);
    if (pokrovCoreAbi == null) {
      throw UnsupportedError(
        'Unrecognized runtime binary. '
        'The POKROV Core ABI marker is missing.',
      );
    }
    if (pokrovCoreAbi != _PokrovCoreBindings.supportedAbiVersion) {
      throw UnsupportedError(
        'Unsupported POKROV Core desktop ABI: $pokrovCoreAbi',
      );
    }
    return _PokrovCoreBindings.load(dynamicLibrary);
  }

  static int? _pokrovCoreAbiVersion(DynamicLibrary dynamicLibrary) {
    try {
      final version =
          dynamicLibrary.lookupFunction<Int32 Function(), int Function()>(
              'pokrovCoreAbiVersion');
      return version();
    } on ArgumentError {
      return null;
    }
  }
}

class _PokrovCoreBindings implements DesktopRuntimeBindings {
  _PokrovCoreBindings._({
    required Pointer<Char> Function(
      Pointer<Char>,
      Pointer<Char>,
      Pointer<Char>,
      int,
      Pointer<Char>,
      Pointer<Char>,
      int,
      bool,
    ) setup,
    required Pointer<Char> Function(Pointer<Char>, bool) start,
    required Pointer<Char> Function() stop,
    required Pointer<Char> Function(Pointer<Char>) secureFile,
    required void Function(Pointer<Char>) freeString,
  })  : _setup = setup,
        _start = start,
        _stop = stop,
        _secureFile = secureFile,
        _freeString = freeString;

  static const supportedAbiVersion = 2;

  final Pointer<Char> Function(
    Pointer<Char>,
    Pointer<Char>,
    Pointer<Char>,
    int,
    Pointer<Char>,
    Pointer<Char>,
    int,
    bool,
  ) _setup;
  final Pointer<Char> Function(Pointer<Char>, bool) _start;
  final Pointer<Char> Function() _stop;
  final Pointer<Char> Function(Pointer<Char>) _secureFile;
  final void Function(Pointer<Char>) _freeString;

  static DesktopRuntimeBindings load(DynamicLibrary dynamicLibrary) {
    final setup = dynamicLibrary.lookupFunction<
        Pointer<Char> Function(
          Pointer<Char>,
          Pointer<Char>,
          Pointer<Char>,
          Int32,
          Pointer<Char>,
          Pointer<Char>,
          Int64,
          Bool,
        ),
        Pointer<Char> Function(
          Pointer<Char>,
          Pointer<Char>,
          Pointer<Char>,
          int,
          Pointer<Char>,
          Pointer<Char>,
          int,
          bool,
        )>('setup');
    final start = dynamicLibrary.lookupFunction<
        Pointer<Char> Function(Pointer<Char>, Bool),
        Pointer<Char> Function(Pointer<Char>, bool)>('start');
    final stop = dynamicLibrary.lookupFunction<Pointer<Char> Function(),
        Pointer<Char> Function()>('stop');
    final freeString = dynamicLibrary.lookupFunction<
        Void Function(Pointer<Char>),
        void Function(Pointer<Char>)>('freeString');
    final secureFile = dynamicLibrary.lookupFunction<
        Pointer<Char> Function(Pointer<Char>),
        Pointer<Char> Function(Pointer<Char>)>('pokrovSecureFile');

    return _PokrovCoreBindings._(
      setup: setup,
      start: start,
      stop: stop,
      secureFile: secureFile,
      freeString: freeString,
    );
  }

  @override
  String setup({
    required String baseDir,
    required String workingDir,
    required String tempDir,
    required int statusPort,
    required bool debug,
  }) {
    final base = baseDir.toNativeUtf8();
    final working = workingDir.toNativeUtf8();
    final temp = tempDir.toNativeUtf8();
    final listen = ''.toNativeUtf8();
    final secret = ''.toNativeUtf8();
    try {
      return _stringResult(
        _setup(
          base.cast<Char>(),
          working.cast<Char>(),
          temp.cast<Char>(),
          0,
          listen.cast<Char>(),
          secret.cast<Char>(),
          statusPort,
          debug,
        ),
      );
    } finally {
      calloc.free(base);
      calloc.free(working);
      calloc.free(temp);
      calloc.free(listen);
      calloc.free(secret);
    }
  }

  @override
  String secureFile(String path) {
    final nativePath = path.toNativeUtf8();
    try {
      return _stringResult(_secureFile(nativePath.cast<Char>()));
    } finally {
      calloc.free(nativePath);
    }
  }

  @override
  String start({
    required String configPath,
    required bool disableMemoryLimit,
  }) {
    final config = configPath.toNativeUtf8();
    try {
      return _stringResult(
        _start(config.cast<Char>(), disableMemoryLimit),
      );
    } finally {
      calloc.free(config);
    }
  }

  @override
  String stop() => _stringResult(_stop());

  String _stringResult(Pointer<Char> pointer) {
    if (pointer.address == 0) {
      return '';
    }
    try {
      return pointer.cast<Utf8>().toDartString();
    } finally {
      _freeString(pointer);
    }
  }
}
