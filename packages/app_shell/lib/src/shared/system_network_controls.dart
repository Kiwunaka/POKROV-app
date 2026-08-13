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
  const PokrovSystemSurfacePreferences({
    this.showCountry = true,
    this.showSpeed = true,
    this.showRouteMode = true,
  });

  final bool showCountry;
  final bool showSpeed;
  final bool showRouteMode;

  PokrovSystemSurfacePreferences copyWith({
    bool? showCountry,
    bool? showSpeed,
    bool? showRouteMode,
  }) {
    return PokrovSystemSurfacePreferences(
      showCountry: showCountry ?? this.showCountry,
      showSpeed: showSpeed ?? this.showSpeed,
      showRouteMode: showRouteMode ?? this.showRouteMode,
    );
  }

  factory PokrovSystemSurfacePreferences.fromMap(Map<String, Object?>? value) {
    return PokrovSystemSurfacePreferences(
      showCountry: value?['showCountry'] != false,
      showSpeed: value?['showSpeed'] != false,
      showRouteMode: value?['showRouteMode'] != false,
    );
  }

  Map<String, Object?> toMap() => <String, Object?>{
        'showCountry': showCountry,
        'showSpeed': showSpeed,
        'showRouteMode': showRouteMode,
      };

  String get summary {
    final enabled = <String>[
      if (showCountry) 'страна',
      if (showSpeed) 'скорость',
      if (showRouteMode) 'режим',
    ];
    return enabled.isEmpty ? 'Только статус' : enabled.join(' · ');
  }
}

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
