part of pokrov_app_shell;

class PokrovWifiNetworkStatus {
  const PokrovWifiNetworkStatus({
    required this.connected,
    required this.name,
    required this.permissionRequired,
    required this.reason,
  });

  const PokrovWifiNetworkStatus.unavailable({String? reason})
      : connected = false,
        name = null,
        permissionRequired = false,
        reason = reason ?? 'unavailable';

  final bool connected;
  final String? name;
  final bool permissionRequired;
  final String? reason;

  bool matches(Iterable<String> trustedNames) {
    final normalized = name?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) {
      return false;
    }
    return trustedNames.any(
      (candidate) => candidate.trim().toLowerCase() == normalized,
    );
  }
}

typedef PokrovWifiProbe = Future<PokrovWifiNetworkStatus> Function();
typedef PokrovWifiPermissionRequester = Future<bool> Function();
typedef PokrovVpnSettingsLauncher = Future<bool> Function();
typedef PokrovNodeLatencyProbe = Future<Map<String, int>> Function(
  HostPlatform hostPlatform,
  List<PokrovNodeLatencyTarget> targets,
);

enum PokrovLocationVariantProbeStatus {
  unknown,
  available,
  unavailable,
  stale,
}

class PokrovLocationVariantProbeResult {
  const PokrovLocationVariantProbeResult({
    required this.id,
    required this.status,
    required this.latencyMs,
    required this.measuredAt,
    required this.errorCategory,
  });

  final String id;
  final PokrovLocationVariantProbeStatus status;
  final int? latencyMs;
  final DateTime? measuredAt;
  final String errorCategory;
}

class PokrovLocationVariantProbeSnapshot {
  const PokrovLocationVariantProbeSnapshot({
    required this.results,
    required this.activeVariantId,
    required this.observedAt,
    required this.errorCategory,
  });

  const PokrovLocationVariantProbeSnapshot.unavailable({
    this.errorCategory = 'host_method_unavailable',
  })  : results = const <String, PokrovLocationVariantProbeResult>{},
        activeVariantId = '',
        observedAt = null;

  final Map<String, PokrovLocationVariantProbeResult> results;
  final String activeVariantId;
  final DateTime? observedAt;
  final String errorCategory;
}

class PokrovNodeLatencyTarget {
  const PokrovNodeLatencyTarget({
    required this.code,
    required this.host,
    required this.port,
  });

  final String code;
  final String host;
  final int port;

  Map<String, Object?> toJson() => <String, Object?>{
        'code': code,
        'host': host,
        'port': port,
      };
}

List<PokrovNodeLatencyTarget> pokrovLocationLatencyTargets(
  ClientLocationsCatalog catalog,
) {
  return <PokrovNodeLatencyTarget>[
    for (final country in catalog.countries)
      for (final city in country.cities)
        if (city.code.trim().isNotEmpty &&
            city.probeHost.trim().isNotEmpty &&
            city.probePort > 0 &&
            city.probePort <= 65535)
          PokrovNodeLatencyTarget(
            code: city.code.trim().toLowerCase(),
            host: city.probeHost.trim(),
            port: city.probePort,
          ),
  ];
}

ClientLocationsCatalog applyPokrovDeviceLatencies(
  ClientLocationsCatalog catalog,
  Map<String, int> measurements, {
  DateTime? measuredAt,
}) {
  final normalized = <String, int>{
    for (final entry in measurements.entries)
      if (entry.key.trim().isNotEmpty &&
          entry.value > 0 &&
          entry.value <= 60000)
        entry.key.trim().toLowerCase(): entry.value,
  };
  final timestamp = (measuredAt ?? DateTime.now()).toUtc().toIso8601String();
  return ClientLocationsCatalog(
    auto: catalog.auto,
    countries: <ClientLocationCountry>[
      for (final country in catalog.countries)
        ClientLocationCountry(
          code: country.code,
          country: country.country,
          cities: <ClientLocationCity>[
            for (final city in country.cities)
              ClientLocationCity(
                code: city.code,
                city: city.city,
                healthScore: city.healthScore,
                latencyMs: normalized[city.code.trim().toLowerCase()],
                premium: city.premium,
                load: city.load,
                measuredAt:
                    normalized.containsKey(city.code.trim().toLowerCase())
                        ? timestamp
                        : city.measuredAt,
                latencySource: normalized.containsKey(
                  city.code.trim().toLowerCase(),
                )
                    ? 'device'
                    : 'unavailable',
                probeHost: city.probeHost,
                probePort: city.probePort,
                variants: city.variants,
              ),
          ],
        ),
    ],
    freePoolCode: catalog.freePoolCode,
    profileRevision: catalog.profileRevision,
    transportProfile: catalog.transportProfile,
    query: catalog.query,
  );
}

class PokrovSystemSurfacePreferences {
  const PokrovSystemSurfacePreferences();

  bool get showCountry => false;
  bool get showSpeed => false;
  bool get showRouteMode => false;

  PokrovSystemSurfacePreferences copyWith({
    bool? showCountry,
    bool? showSpeed,
    bool? showRouteMode,
  }) {
    return const PokrovSystemSurfacePreferences();
  }

  factory PokrovSystemSurfacePreferences.fromMap(Map<String, Object?>? value) {
    return const PokrovSystemSurfacePreferences();
  }

  Map<String, Object?> toMap() => const <String, Object?>{
        'showCountry': false,
        'showSpeed': false,
        'showRouteMode': false,
      };

  String get summary => 'Приватный статус';
}

class PokrovWindowsShellPreferences {
  const PokrovWindowsShellPreferences({
    this.launchAtLogin = false,
    this.closeToTray = true,
  });

  final bool launchAtLogin;
  final bool closeToTray;

  PokrovWindowsShellPreferences copyWith({
    bool? launchAtLogin,
    bool? closeToTray,
  }) {
    return PokrovWindowsShellPreferences(
      launchAtLogin: launchAtLogin ?? this.launchAtLogin,
      closeToTray: closeToTray ?? this.closeToTray,
    );
  }

  factory PokrovWindowsShellPreferences.fromMap(
    Map<String, Object?>? value,
  ) {
    return PokrovWindowsShellPreferences(
      launchAtLogin: value?['launchAtLogin'] == true,
      closeToTray: value?['closeToTray'] != false,
    );
  }

  Map<String, Object?> toMap() => <String, Object?>{
        'launchAtLogin': launchAtLogin,
        'closeToTray': closeToTray,
      };

  String get summary => [
        launchAtLogin ? 'автозапуск' : 'без автозапуска',
        closeToTray ? 'крестик → трей' : 'крестик → выход',
      ].join(' · ');
}

enum PokrovWindowsTunnelAuthorization {
  allowed,
  denied,
  unavailable,
}

enum PokrovWindowsServiceState {
  unavailable,
  serverUntrusted,
  protocolIncompatible,
  serviceBootstrap,
  serviceReady,
}

class PokrovWindowsServiceStatus {
  const PokrovWindowsServiceStatus({
    required this.state,
    required this.available,
    required this.trusted,
    required this.compatible,
    required this.runtimeReady,
  });

  const PokrovWindowsServiceStatus.unavailable()
      : state = PokrovWindowsServiceState.unavailable,
        available = false,
        trusted = false,
        compatible = false,
        runtimeReady = false;

  final PokrovWindowsServiceState state;
  final bool available;
  final bool trusted;
  final bool compatible;
  final bool runtimeReady;

  factory PokrovWindowsServiceStatus.fromMap(Map<String, Object?>? value) {
    final available = value?['available'];
    final trusted = value?['trusted'];
    final compatible = value?['compatible'];
    final runtimeReady = value?['runtimeReady'];
    if (available is! bool ||
        trusted is! bool ||
        compatible is! bool ||
        runtimeReady is! bool) {
      return const PokrovWindowsServiceStatus.unavailable();
    }

    final state = switch (value?['state']) {
      'unavailable'
          when !available && !trusted && !compatible && !runtimeReady =>
        PokrovWindowsServiceState.unavailable,
      'server_untrusted'
          when available && !trusted && !compatible && !runtimeReady =>
        PokrovWindowsServiceState.serverUntrusted,
      'protocol_incompatible'
          when available && trusted && !compatible && !runtimeReady =>
        PokrovWindowsServiceState.protocolIncompatible,
      'service_bootstrap'
          when available && trusted && compatible && !runtimeReady =>
        PokrovWindowsServiceState.serviceBootstrap,
      'service_ready' when available && trusted && compatible && runtimeReady =>
        PokrovWindowsServiceState.serviceReady,
      _ => PokrovWindowsServiceState.unavailable,
    };
    if (state == PokrovWindowsServiceState.unavailable) {
      return const PokrovWindowsServiceStatus.unavailable();
    }
    return PokrovWindowsServiceStatus(
      state: state,
      available: available,
      trusted: trusted,
      compatible: compatible,
      runtimeReady: runtimeReady,
    );
  }
}

typedef PokrovWindowsTunnelAuthorizer = Future<PokrovWindowsTunnelAuthorization>
    Function();
typedef PokrovWindowsShellPreferencesReader
    = Future<PokrovWindowsShellPreferences> Function();
typedef PokrovWindowsShellPreferencesUpdater
    = Future<PokrovWindowsShellPreferences?> Function(
  PokrovWindowsShellPreferences preferences,
);

/// Host-facing control used by desktop tray integrations. It deliberately
/// delegates to the same shell action as the main button, so staging,
/// permission checks, trusted Wi-Fi and error handling cannot diverge.
class PokrovShellController extends ChangeNotifier {
  Future<void> Function()? _toggle;
  bool Function()? _isConnected;
  bool Function()? _isBusy;
  bool Function()? _canToggle;
  bool _externalActionBusy = false;

  bool get attached => _toggle != null;
  bool get isConnected => _isConnected?.call() ?? false;
  bool get isBusy => _externalActionBusy || (_isBusy?.call() ?? false);
  bool get canToggle => attached && !isBusy && (_canToggle?.call() ?? false);

  Future<void> toggleConnection() async {
    final action = _toggle;
    if (action == null || !canToggle) {
      return;
    }
    _externalActionBusy = true;
    notifyListeners();
    try {
      await action();
    } finally {
      _externalActionBusy = false;
      notifyListeners();
    }
  }

  void refresh() {
    notifyListeners();
  }

  void _attach({
    required Future<void> Function() toggle,
    required bool Function() isConnected,
    required bool Function() isBusy,
    required bool Function() canToggle,
  }) {
    _toggle = toggle;
    _isConnected = isConnected;
    _isBusy = isBusy;
    _canToggle = canToggle;
    notifyListeners();
  }

  void _detach() {
    _toggle = null;
    _isConnected = null;
    _isBusy = null;
    _canToggle = null;
    notifyListeners();
  }
}

const MethodChannel _pokrovRuntimeSystemChannel =
    MethodChannel('space.pokrov/runtime_engine');
const MethodChannel _pokrovWindowsShellChannel =
    MethodChannel('space.pokrov/windows-shell');

Future<PokrovWindowsServiceStatus> readPokrovWindowsServiceStatus(
  HostPlatform hostPlatform,
) async {
  if (hostPlatform != HostPlatform.windows) {
    return const PokrovWindowsServiceStatus.unavailable();
  }
  try {
    final value = await _pokrovWindowsShellChannel
        .invokeMapMethod<String, Object?>('readServiceStatus');
    return PokrovWindowsServiceStatus.fromMap(value);
  } on PlatformException {
    return const PokrovWindowsServiceStatus.unavailable();
  } on MissingPluginException {
    return const PokrovWindowsServiceStatus.unavailable();
  }
}

Future<PokrovWindowsTunnelAuthorization>
    requestPokrovWindowsTunnelAuthorization(HostPlatform hostPlatform) async {
  if (hostPlatform != HostPlatform.windows) {
    return PokrovWindowsTunnelAuthorization.allowed;
  }
  final status = await readPokrovWindowsServiceStatus(hostPlatform);
  return switch (status.state) {
    PokrovWindowsServiceState.serviceBootstrap ||
    PokrovWindowsServiceState.serviceReady =>
      PokrovWindowsTunnelAuthorization.allowed,
    PokrovWindowsServiceState.serverUntrusted ||
    PokrovWindowsServiceState.protocolIncompatible =>
      PokrovWindowsTunnelAuthorization.denied,
    PokrovWindowsServiceState.unavailable =>
      PokrovWindowsTunnelAuthorization.unavailable,
  };
}

Future<PokrovWindowsShellPreferences> readPokrovWindowsShellPreferences(
  HostPlatform hostPlatform,
) async {
  if (hostPlatform != HostPlatform.windows) {
    return const PokrovWindowsShellPreferences();
  }
  try {
    final value = await _pokrovWindowsShellChannel
        .invokeMapMethod<String, Object?>('readPreferences');
    return PokrovWindowsShellPreferences.fromMap(value);
  } on PlatformException {
    return const PokrovWindowsShellPreferences();
  } on MissingPluginException {
    return const PokrovWindowsShellPreferences();
  }
}

Future<PokrovWindowsShellPreferences?> updatePokrovWindowsShellPreferences(
  HostPlatform hostPlatform,
  PokrovWindowsShellPreferences preferences,
) async {
  if (hostPlatform != HostPlatform.windows) {
    return null;
  }
  try {
    final value =
        await _pokrovWindowsShellChannel.invokeMapMethod<String, Object?>(
      'updatePreferences',
      preferences.toMap(),
    );
    return PokrovWindowsShellPreferences.fromMap(value);
  } on PlatformException {
    return null;
  } on MissingPluginException {
    return null;
  }
}

Future<PokrovClientUpdateInstallStatus> installPokrovClientUpdate(
  HostPlatform hostPlatform,
  ClientAppUpdateInfo update,
) async {
  if (hostPlatform != HostPlatform.android ||
      update.trustedHandoffUri == null) {
    return PokrovClientUpdateInstallStatus.unsupported;
  }
  try {
    final value = await _pokrovRuntimeSystemChannel
        .invokeMapMethod<String, Object?>('runtimeEngine.installClientUpdate', {
      'url': update.url,
      'sha256': update.sha256.trim().toLowerCase(),
      'size': update.size,
      'channel': update.channel.trim().toLowerCase(),
      'version': update.latestVersion.trim(),
    });
    return switch ((value?['status'] as String? ?? '').trim()) {
      'installer_opened' => PokrovClientUpdateInstallStatus.installerOpened,
      'store_opened' => PokrovClientUpdateInstallStatus.storeOpened,
      'permission_required' =>
        PokrovClientUpdateInstallStatus.permissionRequired,
      'unsupported' => PokrovClientUpdateInstallStatus.unsupported,
      _ => PokrovClientUpdateInstallStatus.failed,
    };
  } on PlatformException {
    return PokrovClientUpdateInstallStatus.failed;
  } on MissingPluginException {
    return PokrovClientUpdateInstallStatus.unsupported;
  }
}

Future<PokrovClientUpdateProgress> readPokrovClientUpdateProgress(
  HostPlatform hostPlatform,
) async {
  if (hostPlatform != HostPlatform.android) {
    return const PokrovClientUpdateProgress.idle();
  }
  try {
    final value =
        await _pokrovRuntimeSystemChannel.invokeMapMethod<String, Object?>(
      'runtimeEngine.clientUpdateProgress',
    );
    final rawPhase = (value?['phase'] as String? ?? '').trim();
    final phase = PokrovClientUpdateProgressPhase.values.firstWhere(
      (candidate) => candidate.name == rawPhase,
      orElse: () => PokrovClientUpdateProgressPhase.idle,
    );
    final downloaded = (value?['downloaded_bytes'] as num?)?.toInt() ?? 0;
    final total = (value?['total_bytes'] as num?)?.toInt() ?? 0;
    return PokrovClientUpdateProgress(
      phase: phase,
      downloadedBytes: math.max(0, downloaded),
      totalBytes: math.max(0, total),
    );
  } on PlatformException {
    return const PokrovClientUpdateProgress.idle();
  } on MissingPluginException {
    return const PokrovClientUpdateProgress.idle();
  }
}

Future<bool> openPokrovInAppWebSurface(
  HostPlatform hostPlatform,
  Uri uri, {
  String title = 'POKROV',
}) async {
  if (hostPlatform != HostPlatform.android || uri.scheme != 'https') {
    return false;
  }
  try {
    return await _pokrovRuntimeSystemChannel.invokeMethod<bool>(
          'runtimeEngine.openInAppWebSurface',
          <String, Object?>{
            'url': uri.toString(),
            'title': title.trim(),
          },
        ) ??
        false;
  } on PlatformException {
    return false;
  } on MissingPluginException {
    return false;
  }
}

Future<String?> resolvePokrovDeviceName(HostPlatform hostPlatform) async {
  if (hostPlatform != HostPlatform.android) {
    return null;
  }
  try {
    final value = await _pokrovRuntimeSystemChannel.invokeMethod<String>(
      'runtimeEngine.deviceName',
    );
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  } on PlatformException {
    return null;
  } on MissingPluginException {
    return null;
  }
}

Future<Map<String, int>> measurePokrovNodeLatencies(
  HostPlatform hostPlatform,
  List<PokrovNodeLatencyTarget> targets,
) async {
  final boundedTargets = targets.take(16).toList(growable: false);
  if (boundedTargets.isEmpty) {
    return const <String, int>{};
  }
  if (hostPlatform == HostPlatform.android) {
    try {
      final value =
          await _pokrovRuntimeSystemChannel.invokeMapMethod<String, Object?>(
        'runtimeEngine.measureNodeLatencies',
        <String, Object?>{
          'targets': boundedTargets
              .map((target) => target.toJson())
              .toList(growable: false),
        },
      );
      return <String, int>{
        for (final entry in (value ?? const <String, Object?>{}).entries)
          if (entry.value is int &&
              (entry.value! as int) > 0 &&
              (entry.value! as int) <= 60000)
            entry.key.trim().toLowerCase(): entry.value! as int,
      };
    } on PlatformException {
      return const <String, int>{};
    } on MissingPluginException {
      return const <String, int>{};
    }
  }
  if (hostPlatform != HostPlatform.windows) {
    return const <String, int>{};
  }
  final results = await Future.wait<MapEntry<String, int>?>(
    boundedTargets.map((target) async {
      Socket? socket;
      final stopwatch = Stopwatch()..start();
      try {
        socket = await Socket.connect(
          target.host,
          target.port,
          timeout: const Duration(milliseconds: 1500),
        );
        stopwatch.stop();
        return MapEntry<String, int>(
          target.code.trim().toLowerCase(),
          stopwatch.elapsedMilliseconds.clamp(1, 60000),
        );
      } on Object {
        return null;
      } finally {
        stopwatch.stop();
        socket?.destroy();
      }
    }),
  );
  return <String, int>{
    for (final entry in results.whereType<MapEntry<String, int>>())
      entry.key: entry.value,
  };
}

Future<PokrovLocationVariantProbeSnapshot> measurePokrovLocationVariants(
  HostPlatform hostPlatform, {
  String variantId = '',
}) async {
  if (hostPlatform != HostPlatform.android) {
    return const PokrovLocationVariantProbeSnapshot.unavailable(
      errorCategory: 'unsupported_platform',
    );
  }
  try {
    final value =
        await _pokrovRuntimeSystemChannel.invokeMapMethod<String, Object?>(
      'runtimeEngine.measureLocationVariants',
      <String, Object?>{
        if (normalizeClientLocationVariantId(variantId) == variantId &&
            variantId.isNotEmpty)
          'variantId': variantId,
      },
    );
    final observedAtMs = value?['observedAtMs'];
    final observedAt = observedAtMs is int && observedAtMs > 0
        ? DateTime.fromMillisecondsSinceEpoch(observedAtMs, isUtc: true)
        : null;
    final now = DateTime.now().toUtc();
    final stale = observedAt != null &&
        now.difference(observedAt).abs() > const Duration(minutes: 2);
    final parsed = <String, PokrovLocationVariantProbeResult>{};
    final rawResults = value?['results'];
    if (rawResults is List) {
      for (final raw in rawResults) {
        if (raw is! Map) {
          continue;
        }
        final id = (raw['id'] as String?)?.trim().toLowerCase() ?? '';
        if (normalizeClientLocationVariantId(id) != id) {
          continue;
        }
        final latencyValue = raw['latencyMs'];
        final latency =
            latencyValue is int && latencyValue > 0 && latencyValue < 65535
                ? latencyValue
                : null;
        final measuredAtValue = raw['measuredAtMs'];
        final measuredAt = measuredAtValue is int && measuredAtValue > 0
            ? DateTime.fromMillisecondsSinceEpoch(
                measuredAtValue,
                isUtc: true,
              )
            : observedAt;
        final rawStatus = (raw['status'] as String?)?.trim().toLowerCase();
        final status = stale
            ? PokrovLocationVariantProbeStatus.stale
            : switch (rawStatus) {
                'available' => PokrovLocationVariantProbeStatus.available,
                'unavailable' => PokrovLocationVariantProbeStatus.unavailable,
                _ => PokrovLocationVariantProbeStatus.unknown,
              };
        parsed[id] = PokrovLocationVariantProbeResult(
          id: id,
          status: status,
          latencyMs: latency,
          measuredAt: measuredAt,
          errorCategory:
              (raw['errorCategory'] as String?)?.trim().toLowerCase() ?? '',
        );
      }
    }
    final activeVariantId =
        (value?['activeVariantId'] as String?)?.trim().toLowerCase() ?? '';
    return PokrovLocationVariantProbeSnapshot(
      results: Map<String, PokrovLocationVariantProbeResult>.unmodifiable(
        parsed,
      ),
      activeVariantId:
          normalizeClientLocationVariantId(activeVariantId) == activeVariantId
              ? activeVariantId
              : '',
      observedAt: observedAt,
      errorCategory:
          (value?['errorCategory'] as String?)?.trim().toLowerCase() ?? '',
    );
  } on PlatformException catch (error) {
    return PokrovLocationVariantProbeSnapshot.unavailable(
      errorCategory: error.code,
    );
  } on MissingPluginException {
    return const PokrovLocationVariantProbeSnapshot.unavailable();
  }
}

Future<PokrovWifiNetworkStatus> probePokrovCurrentWifi(
  HostPlatform hostPlatform,
) async {
  if (hostPlatform == HostPlatform.android) {
    try {
      final value = await _pokrovRuntimeSystemChannel
          .invokeMapMethod<String, Object?>('runtimeEngine.currentWifi');
      return PokrovWifiNetworkStatus(
        connected: value?['connected'] == true,
        name: (value?['name'] as String?)?.trim(),
        permissionRequired: value?['permissionRequired'] == true,
        reason: value?['reason'] as String?,
      );
    } on PlatformException catch (error) {
      return PokrovWifiNetworkStatus.unavailable(reason: error.code);
    } on MissingPluginException {
      return const PokrovWifiNetworkStatus.unavailable(
        reason: 'host_method_unavailable',
      );
    }
  }

  if (hostPlatform == HostPlatform.windows) {
    try {
      final result = await Process.run(
        'netsh',
        const ['wlan', 'show', 'interfaces'],
        runInShell: false,
      );
      if (result.exitCode != 0) {
        return const PokrovWifiNetworkStatus.unavailable(
          reason: 'netsh_failed',
        );
      }
      final output = result.stdout.toString();
      final match = RegExp(
        r'^\s*SSID\s*:\s*(.+?)\s*$',
        multiLine: true,
        caseSensitive: false,
      ).firstMatch(output);
      final name = match?.group(1)?.trim();
      return PokrovWifiNetworkStatus(
        connected: name != null && name.isNotEmpty,
        name: name,
        permissionRequired: false,
        reason: name == null || name.isEmpty ? 'not_connected' : null,
      );
    } on Object {
      return const PokrovWifiNetworkStatus.unavailable(
        reason: 'netsh_unavailable',
      );
    }
  }

  return const PokrovWifiNetworkStatus.unavailable(
    reason: 'unsupported_platform',
  );
}

Future<bool> requestPokrovWifiPermission(HostPlatform hostPlatform) async {
  if (hostPlatform != HostPlatform.android) {
    return false;
  }
  try {
    final value =
        await _pokrovRuntimeSystemChannel.invokeMapMethod<String, Object?>(
      'runtimeEngine.requestWifiPermission',
    );
    return value?['requested'] == true || value?['granted'] == true;
  } on PlatformException {
    return false;
  } on MissingPluginException {
    return false;
  }
}

Future<bool> openPokrovVpnSettings(HostPlatform hostPlatform) async {
  if (hostPlatform != HostPlatform.android) {
    return false;
  }
  try {
    return await _pokrovRuntimeSystemChannel.invokeMethod<bool>(
          'runtimeEngine.openVpnSettings',
        ) ??
        false;
  } on PlatformException {
    return false;
  } on MissingPluginException {
    return false;
  }
}

Future<PokrovSystemSurfacePreferences> readPokrovSystemSurfacePreferences(
  HostPlatform hostPlatform,
) async {
  if (hostPlatform != HostPlatform.android) {
    return const PokrovSystemSurfacePreferences();
  }
  try {
    final value =
        await _pokrovRuntimeSystemChannel.invokeMapMethod<String, Object?>(
      'runtimeEngine.systemSurfacePreferences',
    );
    return PokrovSystemSurfacePreferences.fromMap(value);
  } on PlatformException {
    return const PokrovSystemSurfacePreferences();
  } on MissingPluginException {
    return const PokrovSystemSurfacePreferences();
  }
}

Future<PokrovSystemSurfacePreferences?> updatePokrovSystemSurfacePreferences(
  HostPlatform hostPlatform,
  PokrovSystemSurfacePreferences preferences,
) async {
  if (hostPlatform != HostPlatform.android) {
    return null;
  }
  try {
    final value =
        await _pokrovRuntimeSystemChannel.invokeMapMethod<String, Object?>(
      'runtimeEngine.updateSystemSurfacePreferences',
      preferences.toMap(),
    );
    return PokrovSystemSurfacePreferences.fromMap(value);
  } on PlatformException {
    return null;
  } on MissingPluginException {
    return null;
  }
}

Future<bool> openPokrovNotificationSettings(HostPlatform hostPlatform) async {
  if (hostPlatform != HostPlatform.android) {
    return false;
  }
  try {
    return await _pokrovRuntimeSystemChannel.invokeMethod<bool>(
          'runtimeEngine.openNotificationSettings',
        ) ??
        false;
  } on PlatformException {
    return false;
  } on MissingPluginException {
    return false;
  }
}
