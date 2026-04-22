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
        return 'Desktop libcore lane';
      case RuntimeLane.mobileArtifact:
        return 'Mobile runtime bridge';
    }
  }

  String get phaseLabel {
    switch (phase) {
      case RuntimePhase.artifactMissing:
        return 'Artifacts missing';
      case RuntimePhase.artifactReady:
        return 'Artifacts synced';
      case RuntimePhase.initialized:
        return 'Bridge ready';
      case RuntimePhase.configStaged:
        return 'Managed profile staged';
      case RuntimePhase.running:
        return hasDegradedHostDiagnostics
            ? 'Connected with warnings'
            : 'Connected';
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
        'Uplink ${_diagnosticStateLabel(uplinkState)}',
    ];
    if (labels.isEmpty) {
      return null;
    }
    return labels.join(' | ');
  }

  static String _diagnosticStateLabel(RuntimeDiagnosticState state) {
    return switch (state) {
      RuntimeDiagnosticState.healthy => 'healthy',
      RuntimeDiagnosticState.degraded => 'degraded',
      RuntimeDiagnosticState.unknown => 'unknown',
    };
  }
}

class ManagedProfilePayload {
  const ManagedProfilePayload({
    required this.profileName,
    required this.configPayload,
    this.disableMemoryLimit = false,
    this.materializedForRuntime = false,
    this.routeMode = RouteMode.fullTunnel,
  });

  final String profileName;
  final String configPayload;
  final bool disableMemoryLimit;
  final bool materializedForRuntime;
  final RouteMode routeMode;
}

abstract interface class PokrovRuntimeEngine {
  Future<RuntimeSnapshot> snapshot();

  Future<RuntimeSnapshot> initialize();

  Future<RuntimeSnapshot> stageManagedProfile(
    ManagedProfilePayload payload,
  );

  Future<RuntimeSnapshot> connect();

  Future<RuntimeSnapshot> disconnect();
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
    DesktopRuntimeBindings Function(String libraryPath)? bindingsLoader,
  }) : _bindingsLoader = bindingsLoader ?? _LibcoreBindings.load;

  final HostPlatform hostPlatform;
  final String? assetRootOverride;
  final DesktopRuntimeBindings Function(String libraryPath) _bindingsLoader;

  _RuntimeDirectories? _directories;
  DesktopRuntimeBindings? _bindings;
  ReceivePort? _statusPort;
  _ResolvedArtifacts? _artifacts;
  ManagedProfilePayload? _stagedPayload;
  String? _stagedConfigPath;
  RuntimePhase _phase = RuntimePhase.artifactMissing;
  String _message = _missingArtifactMessage;

  static const defaultLibcoreTag = 'v3.1.8';
  static const _missingArtifactMessage =
      'Run scripts/fetch-libcore-assets.ps1 and sync the host artifacts first.';

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
        'Desktop runtime can initialize once the shell requests it.',
      RuntimePhase.initialized =>
        'Runtime bootstrap succeeded. Stage a managed profile to continue.',
      RuntimePhase.configStaged =>
        'A managed profile is staged and ready for a live connect attempt.',
      RuntimePhase.running => 'libcore is running with the staged profile.',
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
        _message = 'Runtime setup failed: $error';
      } else {
        _phase = RuntimePhase.initialized;
        _message = 'Runtime bootstrap completed with libcore.';
      }
    } catch (error) {
      _phase = RuntimePhase.artifactReady;
      _message = 'Runtime load failed: $error';
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

    final tempPath = p.join(
      _directories!.tempDir.path,
      '${payload.profileName}.seed.json',
    );
    final finalPath = p.join(
      _directories!.configDir.path,
      '${payload.profileName}.json',
    );

    if (payload.materializedForRuntime) {
      await File(finalPath).writeAsString(payload.configPayload);
    } else {
      await File(tempPath).writeAsString(payload.configPayload);
      final parseError = _bindings!.parse(
        outputPath: finalPath,
        tempPath: tempPath,
        debug: false,
      );
      if (parseError.isNotEmpty) {
        _phase = RuntimePhase.initialized;
        _message = 'Managed profile validation failed: $parseError';
        return snapshot();
      }
    }

    _stagedPayload = payload;
    _stagedConfigPath = finalPath;
    _phase = RuntimePhase.configStaged;
    _message = 'Managed profile staged at $finalPath.';
    return snapshot();
  }

  @override
  Future<RuntimeSnapshot> connect() async {
    final before = await snapshot();
    if (!before.canConnect || _bindings == null || _stagedPayload == null) {
      _message =
          'Connect is waiting for a staged managed profile and initialized libcore.';
      return snapshot();
    }

    final optionsError = _bindings!.changeOptions(
      configJson: _buildRuntimeOptionsJson(_stagedPayload!),
    );
    if (optionsError.isNotEmpty) {
      _phase = RuntimePhase.configStaged;
      _message = 'Runtime option sync failed: $optionsError';
      return snapshot();
    }

    final error = _bindings!.start(
      configPath: _stagedConfigPath!,
      disableMemoryLimit: _stagedPayload!.disableMemoryLimit,
    );
    if (error.isNotEmpty) {
      _phase = RuntimePhase.configStaged;
      _message = 'Runtime start failed: $error';
      return snapshot();
    }

    _phase = RuntimePhase.running;
    _message = 'libcore started with the staged managed profile.';
    return snapshot();
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
      _message = 'Runtime stop failed: $error';
      return snapshot();
    }

    _phase = _stagedConfigPath == null
        ? RuntimePhase.initialized
        : RuntimePhase.configStaged;
    _message = 'libcore stopped cleanly.';
    return snapshot();
  }

  Future<_ResolvedArtifacts> _resolveArtifacts() async {
    final executableDirectory = File(Platform.resolvedExecutable).parent;
    final candidateDirectories = <Directory>{
      if (assetRootOverride != null) Directory(assetRootOverride!),
      if (Platform.environment.containsKey('POKROV_LIBCORE_ROOT'))
        Directory(Platform.environment['POKROV_LIBCORE_ROOT']!),
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

    final coreFileName = switch (hostPlatform) {
      HostPlatform.windows => 'libcore.dll',
      HostPlatform.macos => 'libcore.dylib',
      HostPlatform.android || HostPlatform.ios => '',
    };
    final helperFileName = switch (hostPlatform) {
      HostPlatform.windows => null,
      HostPlatform.macos => 'HiddifyCli',
      HostPlatform.android || HostPlatform.ios => null,
    };

    for (final directory in candidateDirectories) {
      final coreBinary = File(p.join(directory.path, coreFileName));
      if (!coreBinary.existsSync()) {
        continue;
      }

      final helperBinary = helperFileName == null
          ? null
          : File(p.join(directory.path, helperFileName));
      return _ResolvedArtifacts(
        artifactDirectory: directory,
        coreBinary: coreBinary,
        helperBinary: helperBinary != null && helperBinary.existsSync()
            ? helperBinary
            : null,
      );
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
      p.join(base.path, 'libcore', platformSegment),
      p.join(base.path, 'artifacts', 'libcore', platformSegment),
      p.join(base.path, 'artifacts', 'libcore', defaultLibcoreTag,
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

  String _buildRuntimeOptionsJson(ManagedProfilePayload payload) {
    final routingMode = switch (payload.routeMode) {
      RouteMode.allExceptRu => 'allExceptRu',
      RouteMode.selectedApps => 'global',
      RouteMode.fullTunnel => 'global',
    };
    final systemProxyMode = hostPlatform == HostPlatform.windows;
    final directDnsAddress =
        payload.routeMode == RouteMode.allExceptRu ? 'local' : 'udp://1.1.1.1';

    return jsonEncode(
      <String, Object?>{
        'region': 'other',
        'routing-mode': routingMode,
        'block-ads': false,
        'use-xray-core-when-possible': false,
        'execute-config-as-is': true,
        'log-level': 'info',
        'resolve-destination': false,
        'ipv6-mode': 'ipv4_only',
        'remote-dns-address': 'https://1.1.1.1/dns-query',
        'remote-dns-domain-strategy': '',
        'direct-dns-address': directDnsAddress,
        'direct-dns-domain-strategy': '',
        'mixed-port': 22341,
        'tproxy-port': 22342,
        'local-dns-port': 22441,
        'tun-implementation': 'gvisor',
        'mtu': 9000,
        'strict-route': true,
        'connection-test-url': 'http://cp.cloudflare.com',
        'url-test-interval': 600,
        'enable-clash-api': false,
        'clash-api-port': 26756,
        'enable-tun': !systemProxyMode,
        'enable-tun-service': false,
        'set-system-proxy': systemProxyMode,
        'bypass-lan': false,
        'allow-connection-from-lan': false,
        'enable-fake-dns': false,
        'enable-dns-routing': true,
        'independent-dns-cache': true,
        'rules': const <Object?>[],
        'mux': <String, Object?>{
          'enable': false,
          'padding': false,
          'max-streams': 8,
          'protocol': 'h2mux',
        },
        'tls-tricks': <String, Object?>{
          'enable-fragment': false,
          'fragment-size': '10-30',
          'fragment-sleep': '2-8',
          'mixed-sni-case': false,
          'enable-padding': false,
          'padding-size': '1-1500',
        },
        'warp': _defaultWarpOptions(),
        'warp2': _defaultWarpOptions(),
      },
    );
  }

  Map<String, Object?> _defaultWarpOptions() {
    return <String, Object?>{
      'enable': false,
      'mode': 'proxy_over_warp',
      'wireguard-config': '',
      'license-key': '',
      'account-id': '',
      'access-token': '',
      'clean-ip': 'auto',
      'clean-port': 0,
      'noise': '',
      'noise-size': '',
      'noise-delay': '',
      'noise-mode': 'm4',
    };
  }
}

class MobileArtifactRuntimeEngine implements PokrovRuntimeEngine {
  const MobileArtifactRuntimeEngine({
    required this.hostPlatform,
    this.assetRootOverride,
  });

  final HostPlatform hostPlatform;
  final String? assetRootOverride;

  static const defaultLibcoreTag = DesktopRuntimeEngine.defaultLibcoreTag;
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
          ? 'Native mobile artifact is present. Finish the host bridge lane to enable live connect.'
          : 'Run scripts/fetch-libcore-assets.ps1 -Platforms ${hostPlatform.name} -SyncToHosts to stage the mobile core artifact.',
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
    final hostSnapshot = await _invokeHostSnapshot(
      'runtimeEngine.stageManagedProfile',
      arguments: <String, Object?>{
        'profileName': payload.profileName,
        'configPayload': payload.configPayload,
        'disableMemoryLimit': payload.disableMemoryLimit,
        'materializedForRuntime': payload.materializedForRuntime,
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
            : 'Runtime host bridge call failed: ${error.code}',
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
          'Runtime host bridge returned an empty snapshot.',
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
            ? 'Uplink $defaultNetworkInterface (#$defaultNetworkIndex)'
            : 'Uplink $defaultNetworkInterface'
      else if (uplinkState == RuntimeDiagnosticState.degraded)
        'Uplink unresolved',
      if (dnsReady != null)
        'DNS ${dnsReady ? 'ready' : 'waiting'}'
      else if (dnsState != RuntimeDiagnosticState.unknown)
        'DNS ${RuntimeSnapshot._diagnosticStateLabel(dnsState)}',
      if (ipv4RouteCount != null || ipv6RouteCount != null)
        'Routes v4=${ipv4RouteCount ?? 0} v6=${ipv6RouteCount ?? 0}',
      if ((includePackageCount ?? 0) > 0 || (excludePackageCount ?? 0) > 0)
        'Packages include=${includePackageCount ?? 0} exclude=${excludePackageCount ?? 0}',
      if ((lastFailureKind?.trim().isNotEmpty ?? false))
        'Last failure $lastFailureKind',
    ];

    if (details.isEmpty) {
      return switch (hostHealth) {
        RuntimeHostHealth.healthy => 'Android host diagnostics are healthy.',
        RuntimeHostHealth.degraded =>
          'Android host diagnostics report warnings.',
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
      HostPlatform.android => 'libcore.aar',
      HostPlatform.ios => 'Libcore.xcframework',
      HostPlatform.windows || HostPlatform.macos => '',
    };

    final candidateDirectories = <Directory>{
      if (assetRootOverride != null) Directory(assetRootOverride!),
      if (Platform.environment.containsKey('POKROV_LIBCORE_ROOT'))
        Directory(Platform.environment['POKROV_LIBCORE_ROOT']!),
      Directory.current,
    };

    for (final base in candidateDirectories.toList()) {
      candidateDirectories.addAll([
        Directory(p.join(base.path, platformSegment)),
        Directory(p.join(base.path, 'libcore', platformSegment)),
        Directory(p.join(base.path, 'artifacts', 'libcore', platformSegment)),
        Directory(
          p.join(base.path, 'artifacts', 'libcore', defaultLibcoreTag,
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
  String setup({
    required String baseDir,
    required String workingDir,
    required String tempDir,
    required int statusPort,
    required bool debug,
  });

  String parse({
    required String outputPath,
    required String tempPath,
    required bool debug,
  });

  String changeOptions({
    required String configJson,
  });

  String start({
    required String configPath,
    required bool disableMemoryLimit,
  });

  String stop();
}

class _LibcoreBindings implements DesktopRuntimeBindings {
  _LibcoreBindings._({
    required Pointer<Char> Function(
      Pointer<Char>,
      Pointer<Char>,
      Pointer<Char>,
      int,
      int,
    ) setup,
    required Pointer<Char> Function(Pointer<Char>, Pointer<Char>, int) parse,
    required Pointer<Char> Function(Pointer<Char>) changeOptions,
    required Pointer<Char> Function(Pointer<Char>, int) start,
    required Pointer<Char> Function() stop,
  })  : _setup = setup,
        _parse = parse,
        _changeOptions = changeOptions,
        _start = start,
        _stop = stop;

  final Pointer<Char> Function(
    Pointer<Char>,
    Pointer<Char>,
    Pointer<Char>,
    int,
    int,
  ) _setup;
  final Pointer<Char> Function(Pointer<Char>, Pointer<Char>, int) _parse;
  final Pointer<Char> Function(Pointer<Char>) _changeOptions;
  final Pointer<Char> Function(Pointer<Char>, int) _start;
  final Pointer<Char> Function() _stop;

  static DesktopRuntimeBindings load(String libraryPath) {
    final dynamicLibrary = DynamicLibrary.open(libraryPath);
    final setupOnce = dynamicLibrary.lookupFunction<
        Void Function(Pointer<Void>), void Function(Pointer<Void>)>(
      'setupOnce',
    );
    final setup = dynamicLibrary.lookupFunction<
        Pointer<Char> Function(
          Pointer<Char>,
          Pointer<Char>,
          Pointer<Char>,
          Int64,
          Uint8,
        ),
        Pointer<Char> Function(
          Pointer<Char>,
          Pointer<Char>,
          Pointer<Char>,
          int,
          int,
        )>('setup');
    final parse = dynamicLibrary.lookupFunction<
        Pointer<Char> Function(Pointer<Char>, Pointer<Char>, Uint8),
        Pointer<Char> Function(Pointer<Char>, Pointer<Char>, int)>('parse');
    final changeOptions = dynamicLibrary.lookupFunction<
        Pointer<Char> Function(Pointer<Char>),
        Pointer<Char> Function(Pointer<Char>)>('changeHiddifyOptions');
    final start = dynamicLibrary.lookupFunction<
        Pointer<Char> Function(Pointer<Char>, Uint8),
        Pointer<Char> Function(Pointer<Char>, int)>('start');
    final stop = dynamicLibrary.lookupFunction<Pointer<Char> Function(),
        Pointer<Char> Function()>('stop');

    setupOnce(NativeApi.initializeApiDLData);
    return _LibcoreBindings._(
      setup: setup,
      parse: parse,
      changeOptions: changeOptions,
      start: start,
      stop: stop,
    );
  }

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
    try {
      return _stringResult(
        _setup(
          base.cast<Char>(),
          working.cast<Char>(),
          temp.cast<Char>(),
          statusPort,
          debug ? 1 : 0,
        ),
      );
    } finally {
      calloc.free(base);
      calloc.free(working);
      calloc.free(temp);
    }
  }

  String parse({
    required String outputPath,
    required String tempPath,
    required bool debug,
  }) {
    final output = outputPath.toNativeUtf8();
    final temp = tempPath.toNativeUtf8();
    try {
      return _stringResult(
        _parse(
          output.cast<Char>(),
          temp.cast<Char>(),
          debug ? 1 : 0,
        ),
      );
    } finally {
      calloc.free(output);
      calloc.free(temp);
    }
  }

  String changeOptions({
    required String configJson,
  }) {
    final options = configJson.toNativeUtf8();
    try {
      return _stringResult(
        _changeOptions(
          options.cast<Char>(),
        ),
      );
    } finally {
      calloc.free(options);
    }
  }

  String start({
    required String configPath,
    required bool disableMemoryLimit,
  }) {
    final config = configPath.toNativeUtf8();
    try {
      return _stringResult(
        _start(
          config.cast<Char>(),
          disableMemoryLimit ? 1 : 0,
        ),
      );
    } finally {
      calloc.free(config);
    }
  }

  String stop() => _stringResult(_stop());

  String _stringResult(Pointer<Char> pointer) {
    if (pointer.address == 0) {
      return '';
    }
    return pointer.cast<Utf8>().toDartString();
  }
}
