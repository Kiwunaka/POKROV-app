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
