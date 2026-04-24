library pokrov_app_shell;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pokrov_core_domain/core_domain.dart';
import 'package:pokrov_platform_contracts/platform_contracts.dart';
import 'package:pokrov_runtime_engine/runtime_engine.dart';
import 'package:pokrov_support_context/support_context.dart';

import 'app_first_runtime_bootstrap.dart';
export 'app_first_runtime_bootstrap.dart';
part 'app_shell_ui_helpers.dart';

enum SeedTab {
  protection,
  locations,
  rules,
  profile,
}

enum _SectionTone {
  accent,
  muted,
  neutral,
}

abstract final class _SeedPalette {
  static const canvas = Color(0xFFF8FAF7);
  static const canvasAlt = Color(0xFFEAF6EF);
  static const ink = Color(0xFF20292D);
  static const muted = Color(0xFF778187);
  static const accent = Color(0xFF176D4D);
  static const accentBright = Color(0xFF0F5F43);
  static const mint = Color(0xFFDFF2E8);
  static const sky = Color(0xFFEFF7F2);
  static const surface = Color(0xFFF9FBF7);
  static const surfaceMuted = Color(0xFFEAF6EF);
  static const line = Color(0xFFD9E5DD);
}

abstract final class _AppShellCopy {
  static const brand = 'POKROV';
  static const connectionTab = 'Подключение';
  static const locationsTab = 'Локации';
  static const rulesTab = 'Правила';
  static const profileTab = 'Профиль';
  static const desktopSubtitle = 'Спокойное подключение для Android и Windows';
  static const onboardingTitle = 'Начало в 3 шага';
  static const onboardingSteps = [
    (
      '1',
      'Запустите пробный период',
      'Приложение подготовит доступ для этого устройства.'
    ),
    ('2', 'Выберите правило', 'Обычно подходит «Все, кроме РФ».'),
    (
      '3',
      'Нажмите подключение',
      'Локация и профиль применятся без ручной настройки.'
    ),
  ];
  static const routeModeQuestion = 'Как должно работать это устройство?';
  static const routeModeDeviceWide = 'Оптимизировать все устройство';
  static const routeModeSelectedApps = 'Только выбранные приложения';
}

const _apiBaseUrlOverride = String.fromEnvironment(
  'POKROV_API_BASE_URL',
  defaultValue: 'https://api.pokrov.space/',
);
const _checkoutUrlOverride = String.fromEnvironment(
  'POKROV_CHECKOUT_URL',
  defaultValue: 'https://pay.pokrov.space/checkout/?plan=1_month',
);
const _cabinetUrlOverride = String.fromEnvironment(
  'POKROV_CABINET_URL',
  defaultValue: 'https://app.pokrov.space/',
);

abstract interface class ExternalLinkLauncher {
  Future<bool> openExternal(String target);
}

class PlatformExternalLinkLauncher implements ExternalLinkLauncher {
  const PlatformExternalLinkLauncher();

  static const _channel = MethodChannel('space.pokrov/external_link');

  @override
  Future<bool> openExternal(String target) async {
    final normalized = target.trim();
    if (normalized.isEmpty) {
      return false;
    }

    try {
      final launched = await _channel.invokeMethod<bool>(
        'openExternal',
        <String, Object?>{'target': normalized},
      );
      return launched ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}

String _normalizeSeedUrl(String value, String fallback) {
  final candidate = value.trim();
  if (candidate.isEmpty) {
    return fallback;
  }
  return candidate.endsWith('/') ? candidate : '$candidate/';
}

class SeedAppContext {
  const SeedAppContext({
    required this.hostPlatform,
    required this.accessLane,
    required this.scope,
    required this.runtimeProfile,
    required this.bootstrapContract,
    required this.supportSnapshot,
    required this.locations,
    required this.apiBaseUrl,
    required this.checkoutUrl,
    required this.cabinetUrl,
    required this.redeemHint,
    required this.managedProfileSeed,
  });

  final HostPlatform hostPlatform;
  final AccessLane accessLane;
  final ProgramScope scope;
  final RuntimeProfile runtimeProfile;
  final PlatformBootstrapContract bootstrapContract;
  final SupportSnapshot supportSnapshot;
  final List<LocationCluster> locations;
  final String apiBaseUrl;
  final String checkoutUrl;
  final String cabinetUrl;
  final String redeemHint;
  final ManagedProfilePayload managedProfileSeed;

  List<SeedTab> get defaultTabs => const [
        SeedTab.protection,
        SeedTab.locations,
        SeedTab.rules,
        SeedTab.profile,
      ];
}

const _seedManagedProfilePayload = ManagedProfilePayload(
  profileName: 'pokrov-seed-runtime',
  configPayload: '''
{
  "log": {
    "disabled": false,
    "level": "info"
  },
  "dns": {
    "servers": [
      {
        "tag": "local",
        "address": "local"
      }
    ]
  },
  "inbounds": [],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    },
    {
      "type": "block",
      "tag": "block"
    }
  ],
  "route": {
    "final": "direct"
  }
}
''',
  materializedForRuntime: true,
);

SeedAppContext buildSeedAppContext({
  required HostPlatform hostPlatform,
}) {
  final bootstrapContract = switch (hostPlatform) {
    HostPlatform.android => const PlatformBootstrapContract(
        hostPlatform: HostPlatform.android,
        requiredPermissions: [
          PermissionRequirement.notifications,
          PermissionRequirement.vpnProfile,
          PermissionRequirement.backgroundStart,
        ],
        defaultCore: RuntimeCore.singBox,
        advancedFallbackCore: RuntimeCore.xray,
        supportsSelectedAppsMode: true,
      ),
    HostPlatform.ios => const PlatformBootstrapContract(
        hostPlatform: HostPlatform.ios,
        requiredPermissions: [
          PermissionRequirement.notifications,
          PermissionRequirement.vpnProfile,
        ],
        defaultCore: RuntimeCore.singBox,
        advancedFallbackCore: RuntimeCore.xray,
        supportsSelectedAppsMode: false,
      ),
    HostPlatform.macos => const PlatformBootstrapContract(
        hostPlatform: HostPlatform.macos,
        requiredPermissions: [
          PermissionRequirement.notifications,
          PermissionRequirement.vpnProfile,
        ],
        defaultCore: RuntimeCore.singBox,
        advancedFallbackCore: RuntimeCore.xray,
        supportsSelectedAppsMode: false,
      ),
    HostPlatform.windows => const PlatformBootstrapContract(
        hostPlatform: HostPlatform.windows,
        requiredPermissions: [
          PermissionRequirement.notifications,
          PermissionRequirement.elevatedSession,
        ],
        defaultCore: RuntimeCore.singBox,
        advancedFallbackCore: RuntimeCore.xray,
        supportsSelectedAppsMode: true,
      ),
  };

  return SeedAppContext(
    hostPlatform: hostPlatform,
    accessLane: AccessLane.trialPremium,
    scope: const ProgramScope(
      publicReleaseTargets: [
        ClientPlatform.android,
        ClientPlatform.windows,
      ],
      readinessOnlyTargets: [
        ClientPlatform.ios,
        ClientPlatform.macos,
      ],
    ),
    runtimeProfile: RuntimeProfile(
      defaultCore: RuntimeCore.singBox,
      advancedFallbackCore: RuntimeCore.xray,
      defaultRouteMode: RouteMode.allExceptRu,
      supportedRouteModes: [
        RouteMode.allExceptRu,
        RouteMode.fullTunnel,
        if (bootstrapContract.supportsSelectedAppsMode) RouteMode.selectedApps,
      ],
      trialDays: 5,
      telegramBonusDays: 10,
      freeTier: const FreeTierPolicy(
        trafficGb: 5,
        periodDays: 30,
        speedMbps: 50,
        deviceLimit: 1,
        nodePool: 'NL-free',
      ),
      allowsExternalCheckoutOnly: true,
      firstPartyPromosOnly: true,
    ),
    bootstrapContract: bootstrapContract,
    supportSnapshot: const SupportSnapshot(
      supportBot: '@pokrov_supportbot',
      feedbackBot: '@pokrov_feedbackbot',
      publicChannel: '@pokrov_vpn',
      supportEmail: 'support@pokrov.space',
      safeNotes:
          'Приложение передает в поддержку только безопасный контекст: устройство, правило и состояние подключения.',
      recommendedRouteMode: RouteMode.allExceptRu,
      channelBonusDays: 10,
    ),
    locations: const [
      LocationCluster(
        code: 'pokrov-managed',
        label: 'POKROV',
        city: 'Умный выбор',
        countryCode: 'PO',
        recommendedLane: 'Автовыбор',
        variants: [
          LocationVariant(kind: TransportKind.vlessReality),
          LocationVariant(kind: TransportKind.vmess),
          LocationVariant(kind: TransportKind.trojan),
          LocationVariant(
            kind: TransportKind.xhttp,
            availability: VariantAvailability.gated,
            note: 'Готовится для резервного контура.',
          ),
        ],
      ),
    ],
    apiBaseUrl: _normalizeSeedUrl(
      _apiBaseUrlOverride,
      'https://api.pokrov.space/',
    ),
    checkoutUrl: _checkoutUrlOverride.trim().isEmpty
        ? 'https://pay.pokrov.space/checkout/?plan=1_month'
        : _checkoutUrlOverride.trim(),
    cabinetUrl: _normalizeSeedUrl(
      _cabinetUrlOverride,
      'https://app.pokrov.space/',
    ),
    redeemHint: '',
    managedProfileSeed: _seedManagedProfilePayload,
  );
}

class PokrovSeedApp extends StatefulWidget {
  const PokrovSeedApp({
    super.key,
    required this.appContext,
    this.bootstrapper,
    this.linkLauncher = const PlatformExternalLinkLauncher(),
  });

  final SeedAppContext appContext;
  final ManagedProfileBootstrapper? bootstrapper;
  final ExternalLinkLauncher linkLauncher;

  @override
  State<PokrovSeedApp> createState() => _PokrovSeedAppState();
}

class _PokrovSeedAppState extends State<PokrovSeedApp> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'POKROV',
      theme: _buildSeedTheme(Brightness.light),
      darkTheme: _buildSeedTheme(Brightness.dark),
      themeMode: _themeMode,
      home: PokrovSeedShell(
        appContext: widget.appContext,
        bootstrapper: widget.bootstrapper,
        linkLauncher: widget.linkLauncher,
        themeMode: _themeMode,
        onThemeModeChanged: (mode) {
          setState(() {
            _themeMode = mode;
          });
        },
      ),
    );
  }
}

ThemeData _buildSeedTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final colorScheme = isDark
      ? const ColorScheme.dark(
          primary: Color(0xFF8AD9B3),
          onPrimary: Color(0xFF102019),
          secondary: Color(0xFFB4DDC8),
          onSecondary: Color(0xFF102019),
          surface: Color(0xFF17201D),
          onSurface: Color(0xFFEAF5EF),
          error: Color(0xFFFFB4A8),
          onError: Color(0xFF2B0B06),
        )
      : const ColorScheme.light(
          primary: _SeedPalette.accent,
          onPrimary: Colors.white,
          secondary: _SeedPalette.accentBright,
          onSecondary: Colors.white,
          surface: _SeedPalette.surface,
          onSurface: _SeedPalette.ink,
          error: Color(0xFFB33B2E),
          onError: Colors.white,
        );

  return ThemeData(
    colorScheme: colorScheme,
    brightness: brightness,
    useMaterial3: true,
    scaffoldBackgroundColor: Colors.transparent,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: _SeedPalette.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
    ),
    cardTheme: CardTheme(
      color: _SeedPalette.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.transparent,
      elevation: 0,
      indicatorColor: _SeedPalette.accent.withOpacity(0.1),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? _SeedPalette.ink
              : _SeedPalette.ink.withOpacity(0.68),
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? _SeedPalette.accent
              : _SeedPalette.ink.withOpacity(0.68),
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: _SeedPalette.accent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: _SeedPalette.ink,
        side: BorderSide(color: _SeedPalette.ink.withOpacity(0.16)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
  );
}

class PokrovSeedShell extends StatefulWidget {
  const PokrovSeedShell({
    super.key,
    required this.appContext,
    this.bootstrapper,
    required this.linkLauncher,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  final SeedAppContext appContext;
  final ManagedProfileBootstrapper? bootstrapper;
  final ExternalLinkLauncher linkLauncher;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<PokrovSeedShell> createState() => _PokrovSeedShellState();
}

class _PokrovSeedShellState extends State<PokrovSeedShell>
    with WidgetsBindingObserver {
  int _selectedIndex = 0;
  late RouteMode _selectedRouteMode;
  bool _deviceRouteConfirmed = false;
  late final PokrovRuntimeEngine _runtimeEngine;
  late final ManagedProfileBootstrapper _bootstrapper;
  RuntimeSnapshot? _runtimeSnapshot;
  bool _runtimeBusy = false;
  bool _managedProfileDirty = true;
  String? _runtimeHeadline;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _selectedRouteMode = widget.appContext.runtimeProfile.defaultRouteMode;
    _runtimeEngine = createRuntimeEngine(
      hostPlatform: widget.appContext.hostPlatform,
    );
    _bootstrapper = widget.bootstrapper ??
        AppFirstRuntimeBootstrapper(
          apiBaseUrl: widget.appContext.apiBaseUrl,
        );
    _refreshRuntimeSnapshot();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_runtimeBusy) {
      unawaited(_refreshRuntimeSnapshot());
    }
  }

  Future<void> _openExternalHandoff(String label, String value) async {
    final target = _handoffTarget(label, value);
    final opened = await widget.linkLauncher.openExternal(target);
    if (!mounted || opened) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Не получилось открыть: $target')),
    );
  }

  String _handoffTarget(String label, String value) {
    final target = value.trim();
    if (target.startsWith('http://') || target.startsWith('https://')) {
      return target;
    }
    if (target.startsWith('@')) {
      return 'https://t.me/${target.substring(1)}';
    }
    if (label == 'redeem') {
      return '${widget.appContext.cabinetUrl}redeem?code=$target';
    }
    return target;
  }

  Future<RuntimeSnapshot> _runRuntimeAction(
    Future<RuntimeSnapshot> Function() action,
  ) async {
    setState(() {
      _runtimeBusy = true;
    });

    try {
      final snapshot = await action();
      if (!mounted) {
        return snapshot;
      }

      setState(() {
        _runtimeSnapshot = snapshot;
        _runtimeHeadline = null;
      });
      return snapshot;
    } finally {
      if (mounted) {
        setState(() {
          _runtimeBusy = false;
        });
      }
    }
  }

  Future<void> _refreshRuntimeSnapshot() async {
    await _runRuntimeAction(_runtimeEngine.snapshot);
  }

  Future<ManagedProfilePayload> _resolveManagedProfile() async {
    final payload = await _bootstrapper.resolveManagedProfile(
      hostPlatform: widget.appContext.hostPlatform,
      routeMode: _selectedRouteMode,
    );
    if (mounted) {
      setState(() {
        _managedProfileDirty = false;
        _runtimeHeadline = 'Профиль подключения обновлен.';
      });
    }
    return payload;
  }

  Future<void> _toggleRuntime() async {
    if (_runtimeBusy) {
      setState(() {
        _runtimeHeadline = 'Подключение уже обновляется. Подождите немного.';
      });
      return;
    }

    setState(() {
      _runtimeBusy = true;
    });

    try {
      final snapshot = _runtimeSnapshot ?? await _runtimeEngine.snapshot();
      if (!mounted) {
        return;
      }

      if (snapshot.phase == RuntimePhase.running) {
        var current = await _runtimeEngine.disconnect();
        current = await _settleRuntimeDisconnectTransition(current);
        if (!mounted) {
          return;
        }
        setState(() {
          _runtimeSnapshot = current;
          _runtimeHeadline = _consumerRuntimeMessage(current.message);
        });
        return;
      }

      if (!_canPrimaryConnect(snapshot)) {
        setState(() {
          _runtimeHeadline =
              'Устройству нужно завершить подготовку перед подключением.';
        });
        return;
      }

      var current = snapshot;

      if (current.canInitialize &&
          current.phase == RuntimePhase.artifactReady) {
        current = await _runtimeEngine.initialize();
        if (!mounted) {
          return;
        }
        setState(() {
          _runtimeSnapshot = current;
          _runtimeHeadline = null;
        });
      }

      final shouldRefreshManagedProfile =
          _managedProfileDirty || (current.stagedConfigPath ?? '').isEmpty;
      if (shouldRefreshManagedProfile) {
        final managedProfile = await _resolveManagedProfile();
        current = await _runtimeEngine.stageManagedProfile(managedProfile);
        if (!mounted) {
          return;
        }
        setState(() {
          _runtimeSnapshot = current;
          _runtimeHeadline = null;
        });
      }

      if ((current.stagedConfigPath ?? '').isNotEmpty || current.canConnect) {
        current = await _runtimeEngine.connect();
        current = await _settleRuntimeTransition(current);
        if (!mounted) {
          return;
        }
        setState(() {
          _runtimeSnapshot = current;
          _runtimeHeadline = current.phase == RuntimePhase.running
              ? current.isCleanlyHealthy
                  ? 'Подключение активно.'
                  : 'Подключение активно, но есть замечание.'
              : _consumerRuntimeMessage(current.message);
        });
        if (current.phase != RuntimePhase.running &&
            current.message.trim().isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_consumerRuntimeMessage(current.message))),
          );
        }
      }
    } on BootstrapFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _runtimeHeadline = _consumerRuntimeMessage(error.message);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_consumerRuntimeMessage(error.message))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _runtimeBusy = false;
        });
      }
    }
  }

  Future<RuntimeSnapshot> _settleRuntimeTransition(
    RuntimeSnapshot snapshot,
  ) async {
    if (snapshot.phase == RuntimePhase.running ||
        !snapshot.supportsLiveConnect ||
        _isTerminalConnectMessage(snapshot.message)) {
      return snapshot;
    }

    var current = snapshot;
    final maxAttempts = current.message.toLowerCase().contains(
              'permission requested',
            )
        ? 40
        : 10;
    for (var attempt = 0; attempt < maxAttempts; attempt += 1) {
      await Future<void>.delayed(const Duration(milliseconds: 450));
      current = await _runtimeEngine.snapshot();
      if (!mounted) {
        return current;
      }
      setState(() {
        _runtimeSnapshot = current;
        _runtimeHeadline = null;
      });
      if (current.phase == RuntimePhase.running) {
        return current;
      }
      if (_isTerminalConnectMessage(current.message)) {
        return current;
      }
    }
    return current;
  }

  Future<RuntimeSnapshot> _settleRuntimeDisconnectTransition(
    RuntimeSnapshot snapshot,
  ) async {
    if (snapshot.phase != RuntimePhase.running) {
      return snapshot;
    }

    var current = snapshot;
    for (var attempt = 0; attempt < 15; attempt += 1) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      current = await _runtimeEngine.snapshot();
      if (!mounted) {
        return current;
      }
      setState(() {
        _runtimeSnapshot = current;
        _runtimeHeadline = null;
      });
      if (current.phase != RuntimePhase.running) {
        return current;
      }
    }
    return current;
  }

  bool _isTerminalConnectMessage(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains('failed') ||
        normalized.contains('denied') ||
        normalized.contains('error') ||
        normalized.contains('stopped');
  }

  bool _canPrimaryConnect(RuntimeSnapshot? snapshot) {
    if (snapshot == null) {
      return false;
    }
    if (snapshot.phase == RuntimePhase.running) {
      return true;
    }
    if (!snapshot.supportsLiveConnect) {
      return false;
    }
    return snapshot.phase != RuntimePhase.artifactMissing;
  }

  @override
  Widget build(BuildContext context) {
    final hasProvisionedAccess = !_managedProfileDirty ||
        (_runtimeSnapshot?.phase == RuntimePhase.running) ||
        ((_runtimeSnapshot?.stagedConfigPath ?? '').isNotEmpty);
    final sections = <Widget>[
      _QuickConnectSection(
        appContext: widget.appContext,
        selectedRouteMode: _selectedRouteMode,
        deviceRouteConfirmed: _deviceRouteConfirmed,
        runtimeSnapshot: _runtimeSnapshot,
        runtimeHeadline: _runtimeHeadline,
        runtimeBusy: _runtimeBusy,
        primaryConnectEnabled:
            _deviceRouteConfirmed && _canPrimaryConnect(_runtimeSnapshot),
        onRouteModeSelected: (mode) {
          setState(() {
            _selectedRouteMode = mode;
            _deviceRouteConfirmed = true;
            _managedProfileDirty = true;
          });
        },
        onRefreshRuntime: _refreshRuntimeSnapshot,
        onToggleRuntime: _toggleRuntime,
      ),
      _LocationsSection(
        appContext: widget.appContext,
        selectedRouteMode: _selectedRouteMode,
        hasProvisionedAccess: hasProvisionedAccess,
      ),
      _RulesSection(
        appContext: widget.appContext,
        selectedRouteMode: _selectedRouteMode,
        onRouteModeSelected: (mode) {
          setState(() {
            _selectedRouteMode = mode;
            _deviceRouteConfirmed = true;
            _managedProfileDirty = true;
          });
        },
      ),
      _ProfileSection(
        appContext: widget.appContext,
        selectedRouteMode: _selectedRouteMode,
        hasProvisionedAccess: hasProvisionedAccess,
        onOpenHandoff: _openExternalHandoff,
        runtimeSnapshot: _runtimeSnapshot,
        runtimeHeadline: _runtimeHeadline,
        themeMode: widget.themeMode,
        onThemeModeChanged: widget.onThemeModeChanged,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final useDesktopShell = constraints.maxWidth >= 900 &&
            widget.appContext.hostPlatform == HostPlatform.windows;

        return Scaffold(
          extendBody: true,
          appBar: useDesktopShell
              ? null
              : AppBar(
                  leading: const Padding(
                    padding: EdgeInsets.only(left: 16),
                    child: Center(child: _PokrovBrandMark(size: 36)),
                  ),
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(_AppShellCopy.brand),
                      Text(
                        _AppShellCopy.desktopSubtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: _SeedPalette.muted,
                            ),
                      ),
                    ],
                  ),
                ),
          body: _SeedBackdrop(
            child: SafeArea(
              child: useDesktopShell
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _DesktopSidebar(
                          selectedIndex: _selectedIndex,
                          onSelected: (index) {
                            setState(() {
                              _selectedIndex = index;
                            });
                          },
                        ),
                        Expanded(
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1180),
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 220),
                                child: KeyedSubtree(
                                  key: ValueKey<int>(_selectedIndex),
                                  child: sections[_selectedIndex],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: KeyedSubtree(
                        key: ValueKey<int>(_selectedIndex),
                        child: sections[_selectedIndex],
                      ),
                    ),
            ),
          ),
          bottomNavigationBar: useDesktopShell
              ? null
              : SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.86),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _SeedPalette.line),
                        boxShadow: [
                          BoxShadow(
                            color: _SeedPalette.ink.withOpacity(0.08),
                            blurRadius: 30,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: NavigationBar(
                        selectedIndex: _selectedIndex,
                        onDestinationSelected: (index) {
                          setState(() {
                            _selectedIndex = index;
                          });
                        },
                        destinations: const [
                          NavigationDestination(
                            icon: Icon(Icons.power_settings_new_outlined),
                            selectedIcon: Icon(Icons.power_settings_new),
                            label: _AppShellCopy.connectionTab,
                          ),
                          NavigationDestination(
                            icon: Icon(Icons.public_outlined),
                            selectedIcon: Icon(Icons.public),
                            label: _AppShellCopy.locationsTab,
                          ),
                          NavigationDestination(
                            icon: Icon(Icons.rule_folder_outlined),
                            selectedIcon: Icon(Icons.rule_folder),
                            label: _AppShellCopy.rulesTab,
                          ),
                          NavigationDestination(
                            icon: Icon(Icons.person_outline),
                            selectedIcon: Icon(Icons.person),
                            label: _AppShellCopy.profileTab,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }
}

class _PokrovBrandMark extends StatelessWidget {
  const _PokrovBrandMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.asset(
        'assets/branding/pokrov-mark.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        semanticLabel: 'POKROV',
        errorBuilder: (context, error, stackTrace) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: _SeedPalette.mint,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.shield_rounded,
            color: _SeedPalette.accent,
          ),
        ),
      ),
    );
  }
}

class _DesktopSidebar extends StatelessWidget {
  const _DesktopSidebar({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final items = const [
      (Icons.power_settings_new_rounded, _AppShellCopy.connectionTab),
      (Icons.public_rounded, _AppShellCopy.locationsTab),
      (Icons.rule_folder_rounded, _AppShellCopy.rulesTab),
      (Icons.person_rounded, _AppShellCopy.profileTab),
    ];

    return Container(
      width: 260,
      margin: const EdgeInsets.fromLTRB(18, 18, 8, 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.88),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _SeedPalette.line),
        boxShadow: [
          BoxShadow(
            color: _SeedPalette.ink.withOpacity(0.07),
            blurRadius: 34,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            padding: const EdgeInsets.all(4),
            child: const _PokrovBrandMark(size: 44),
          ),
          const SizedBox(height: 14),
          Text(
            _AppShellCopy.brand,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: _SeedPalette.ink,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            _AppShellCopy.desktopSubtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _SeedPalette.muted,
                  height: 1.25,
                ),
          ),
          const SizedBox(height: 28),
          for (var index = 0; index < items.length; index += 1) ...[
            _DesktopNavItem(
              icon: items[index].$1,
              label: items[index].$2,
              selected: selectedIndex == index,
              onTap: () => onSelected(index),
            ),
            const SizedBox(height: 8),
          ],
          const Spacer(),
          const _StatusPill(
            label: 'Android + Windows',
            icon: Icons.devices_rounded,
            tone: _SectionTone.muted,
          ),
        ],
      ),
    );
  }
}

class _DesktopNavItem extends StatelessWidget {
  const _DesktopNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: selected ? _SeedPalette.mint : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? _SeedPalette.line : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 21,
              color: selected ? _SeedPalette.accent : _SeedPalette.muted,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: selected ? _SeedPalette.ink : _SeedPalette.muted,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickConnectSection extends StatelessWidget {
  const _QuickConnectSection({
    required this.appContext,
    required this.selectedRouteMode,
    required this.deviceRouteConfirmed,
    required this.runtimeSnapshot,
    required this.runtimeHeadline,
    required this.runtimeBusy,
    required this.primaryConnectEnabled,
    required this.onRouteModeSelected,
    required this.onRefreshRuntime,
    required this.onToggleRuntime,
  });

  final SeedAppContext appContext;
  final RouteMode selectedRouteMode;
  final bool deviceRouteConfirmed;
  final RuntimeSnapshot? runtimeSnapshot;
  final String? runtimeHeadline;
  final bool runtimeBusy;
  final bool primaryConnectEnabled;
  final ValueChanged<RouteMode> onRouteModeSelected;
  final Future<void> Function() onRefreshRuntime;
  final Future<void> Function() onToggleRuntime;

  @override
  Widget build(BuildContext context) {
    final snapshot = runtimeSnapshot;
    final isRunning = snapshot?.phase == RuntimePhase.running;
    final isHealthyRunning = snapshot?.isCleanlyHealthy ?? false;
    final statusLabel = _consumerProtectionStatusLabel(
      snapshot,
      busy: runtimeBusy,
    );
    final statusSummary = _consumerProtectionStatusSummary(
      snapshot,
      headline: runtimeHeadline,
      hostPlatform: appContext.hostPlatform,
    );
    final primaryActionEnabled = !runtimeBusy && primaryConnectEnabled;
    final heroTitle = runtimeBusy
        ? 'Проверяем подключение'
        : isRunning
            ? isHealthyRunning
                ? 'Подключено'
                : 'Подключено, есть замечание'
            : primaryActionEnabled
                ? 'Готово к подключению'
                : 'Сначала завершите подготовку';

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 160),
      children: [
        Text(
          _AppShellCopy.connectionTab,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        _DeviceRouteChoiceSection(
          appContext: appContext,
          selectedRouteMode: selectedRouteMode,
          confirmed: deviceRouteConfirmed,
          onRouteModeSelected: onRouteModeSelected,
        ),
        const _OnboardingStepsCard(),
        _SectionCard(
          title: heroTitle,
          tone: _SectionTone.accent,
          lines: [
            statusSummary,
            primaryActionEnabled
                ? 'Главное действие здесь. Правила меняются отдельно, а профиль хранит поддержку и подписку.'
                : deviceRouteConfirmed
                    ? 'Устройству нужно немного подготовки перед первым подключением.'
                    : 'Сначала выберите, как это устройство должно работать.',
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _MetricTile(
                    label: 'Статус',
                    value: statusLabel,
                    caption: isRunning
                        ? 'Ежедневное управление остается здесь.'
                        : 'Подключение намеренно остается простым.',
                    icon: isRunning
                        ? Icons.shield_rounded
                        : Icons.play_circle_outline_rounded,
                  ),
                  _MetricTile(
                    label: 'Правило',
                    value: selectedRouteMode.label,
                    caption: 'Меняется во вкладке «Правила»',
                    icon: Icons.alt_route_rounded,
                  ),
                  _MetricTile(
                    label: 'Устройство',
                    value: appContext.hostPlatform.label,
                    caption: 'Подписка и помощь находятся в профиле',
                    icon: Icons.devices_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Center(
                child: _ConnectOrbButton(
                  running: isRunning,
                  degraded: isRunning && !isHealthyRunning,
                  busy: runtimeBusy,
                  onPressed: primaryActionEnabled ? onToggleRuntime : null,
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: FilledButton.icon(
                  onPressed: primaryActionEnabled ? onToggleRuntime : null,
                  icon: Icon(
                    isRunning
                        ? Icons.stop_circle_outlined
                        : Icons.play_circle_fill_rounded,
                  ),
                  label: Text(
                    runtimeBusy
                        ? 'Готовим подключение'
                        : isRunning
                            ? 'Отключить'
                            : primaryActionEnabled
                                ? 'Подключить'
                                : 'Недоступно',
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _StatusPill(
                    label: statusLabel,
                    icon: isRunning
                        ? Icons.shield_rounded
                        : Icons.flash_on_rounded,
                    tone: _SectionTone.accent,
                  ),
                  _StatusPill(
                    label: selectedRouteMode.label,
                    icon: Icons.alt_route_rounded,
                  ),
                  _StatusPill(
                    label: appContext.hostPlatform.label,
                    icon: Icons.devices_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                isRunning && !isHealthyRunning
                    ? 'Подключение активно, но может требовать внимания. Если нужна помощь, откройте профиль.'
                    : primaryActionEnabled
                        ? 'Одна кнопка запускает подключение с подготовленным доступом.'
                        : deviceRouteConfirmed
                            ? 'Повторите проверку, когда подготовка устройства завершится.'
                            : 'После выбора сценария кнопка подключит устройство.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: _SeedPalette.ink.withOpacity(0.72),
                    ),
              ),
            ],
          ),
        ),
        _SectionCard(
          title: 'Что уже понятно',
          tone: _SectionTone.muted,
          lines: [
            appContext.accessLane.summary,
            'Пробный период: ${appContext.runtimeProfile.trialDays} дней. Бонус Telegram: +${appContext.runtimeProfile.telegramBonusDays} дней.',
            'Базовый доступ остается на отдельной бесплатной локации с квотой ${appContext.runtimeProfile.freeTier.quotaSummary}.',
          ],
        ),
        _SectionCard(
          title: 'Состояние подключения',
          tone: _SectionTone.neutral,
          lines: [
            'Сейчас: $statusLabel',
            statusSummary,
            'Текущее правило: ${selectedRouteMode.label}',
            isRunning
                ? 'Подключение уже активно на этом устройстве.'
                : 'Если подготовка еще идет, проверьте состояние через минуту.',
          ],
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              OutlinedButton.icon(
                onPressed: runtimeBusy ? null : onRefreshRuntime,
                icon: const Icon(Icons.refresh),
                label: const Text('Проверить еще раз'),
              ),
              FilledButton.icon(
                onPressed: primaryActionEnabled ? onToggleRuntime : null,
                icon: Icon(
                  snapshot?.phase == RuntimePhase.running
                      ? Icons.stop_circle_outlined
                      : Icons.play_circle_outline,
                ),
                label: Text(
                  snapshot?.phase == RuntimePhase.running
                      ? 'Остановить здесь'
                      : 'Запустить здесь',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OnboardingStepsCard extends StatelessWidget {
  const _OnboardingStepsCard();

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: _AppShellCopy.onboardingTitle,
      tone: _SectionTone.muted,
      lines: const [
        'Короткий путь без ключей, ручного импорта и лишних экранов.',
      ],
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 720;
          final steps = _AppShellCopy.onboardingSteps
              .map(
                (step) => _OnboardingStepTile(
                  number: step.$1,
                  title: step.$2,
                  caption: step.$3,
                ),
              )
              .toList();

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var index = 0; index < steps.length; index += 1) ...[
                  if (index > 0) const SizedBox(width: 12),
                  Expanded(child: steps[index]),
                ],
              ],
            );
          }

          return Column(
            children: [
              for (var index = 0; index < steps.length; index += 1) ...[
                if (index > 0) const SizedBox(height: 10),
                steps[index],
              ],
            ],
          );
        },
      ),
    );
  }
}

class _OnboardingStepTile extends StatelessWidget {
  const _OnboardingStepTile({
    required this.number,
    required this.title,
    required this.caption,
  });

  final String number;
  final String title;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.76),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _SeedPalette.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: _SeedPalette.mint,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: _SeedPalette.accent,
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: _SeedPalette.ink,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  caption,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _SeedPalette.muted,
                        height: 1.28,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceRouteChoiceSection extends StatelessWidget {
  const _DeviceRouteChoiceSection({
    required this.appContext,
    required this.selectedRouteMode,
    required this.confirmed,
    required this.onRouteModeSelected,
  });

  final SeedAppContext appContext;
  final RouteMode selectedRouteMode;
  final bool confirmed;
  final ValueChanged<RouteMode> onRouteModeSelected;

  @override
  Widget build(BuildContext context) {
    final canSelectApps = appContext.bootstrapContract.supportsSelectedAppsMode;

    return _SectionCard(
      title: _AppShellCopy.routeModeQuestion,
      tone: confirmed ? _SectionTone.neutral : _SectionTone.accent,
      lines: [
        'Перед первым подключением выберите сценарий для этого устройства.',
        confirmed
            ? 'Выбрано: ${_deviceScopeLabel(selectedRouteMode)}.'
            : 'Это обязательный первый выбор, без сетевых терминов и ручных ссылок.',
      ],
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _DeviceScopeCard(
            title: _AppShellCopy.routeModeDeviceWide,
            caption:
                'Рекомендуемый путь: POKROV оптимизирует устройство целиком, а российские и локальные сервисы остаются напрямую.',
            icon: Icons.devices_rounded,
            selected: confirmed && selectedRouteMode != RouteMode.selectedApps,
            onTap: () => onRouteModeSelected(RouteMode.allExceptRu),
          ),
          _DeviceScopeCard(
            title: _AppShellCopy.routeModeSelectedApps,
            caption: canSelectApps
                ? 'Выберите приложения или процессы, которые должны идти через POKROV.'
                : 'На этой платформе сценарий готовится отдельно.',
            icon: Icons.apps_rounded,
            selected: confirmed && selectedRouteMode == RouteMode.selectedApps,
            onTap: canSelectApps
                ? () => onRouteModeSelected(RouteMode.selectedApps)
                : null,
          ),
        ],
      ),
    );
  }
}

class _DeviceScopeCard extends StatelessWidget {
  const _DeviceScopeCard({
    required this.title,
    required this.caption,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String caption;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 360),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected
                ? _SeedPalette.accent.withOpacity(0.12)
                : Colors.white.withOpacity(onTap == null ? 0.48 : 0.82),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? _SeedPalette.accent.withOpacity(0.32)
                  : _SeedPalette.line,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    selected ? Icons.check_circle_rounded : icon,
                    color: _SeedPalette.accent,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: _SeedPalette.ink,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                caption,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _SeedPalette.muted,
                      height: 1.3,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _deviceScopeLabel(RouteMode mode) {
  return mode == RouteMode.selectedApps
      ? _AppShellCopy.routeModeSelectedApps
      : _AppShellCopy.routeModeDeviceWide;
}

class _LocationsSection extends StatelessWidget {
  const _LocationsSection({
    required this.appContext,
    required this.selectedRouteMode,
    required this.hasProvisionedAccess,
  });

  final SeedAppContext appContext;
  final RouteMode selectedRouteMode;
  final bool hasProvisionedAccess;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 160),
      children: [
        Text(_AppShellCopy.locationsTab, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Автовыбор',
          tone:
              hasProvisionedAccess ? _SectionTone.neutral : _SectionTone.muted,
          lines: [
            'POKROV показывает одну понятную локацию и сам выбирает подходящий путь.',
            'Текущее правило: ${selectedRouteMode.label}.',
            hasProvisionedAccess
                ? 'Для этого устройства уже готова локация.'
                : 'Сначала завершите подготовку во вкладке «Подключение». До этого локации не показывают демо-страны.',
          ],
        ),
        if (hasProvisionedAccess) ...[
          ...appContext.locations.map(
            (location) => _LocationCard(
              location: location,
              appContext: appContext,
              selectedRouteMode: selectedRouteMode,
            ),
          ),
        ] else ...[
          _SectionCard(
            title: 'Откроется после подготовки',
            lines: [
              'Запустите подключение один раз, чтобы создать сессию для устройства.',
              'После этого экран покажет управляемую локацию без сетевых деталей.',
            ],
          ),
        ],
        _SectionCard(
          title: 'Как выбирается путь',
          lines: [
            'Премиум использует доступные платные локации.',
            'Базовый доступ остается на отдельной бесплатной локации.',
            'Детали подключения скрыты за автовыбором и безопасной диагностикой.',
          ],
        ),
      ],
    );
  }
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({
    required this.appContext,
    required this.selectedRouteMode,
    required this.hasProvisionedAccess,
    required this.onOpenHandoff,
    required this.runtimeSnapshot,
    required this.runtimeHeadline,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  final SeedAppContext appContext;
  final RouteMode selectedRouteMode;
  final bool hasProvisionedAccess;
  final Future<void> Function(String label, String value) onOpenHandoff;
  final RuntimeSnapshot? runtimeSnapshot;
  final String? runtimeHeadline;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final readinessOnlySummary = appContext.scope.readinessOnlySummary;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(_AppShellCopy.profileTab, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Все для аккаунта',
          tone: _SectionTone.accent,
          lines: [
            hasProvisionedAccess
                ? 'Подписка, устройства, поддержка, настройки и бонус Telegram находятся здесь.'
                : 'Когда устройство будет готово, здесь появятся подписка, устройства, поддержка, настройки и бонус Telegram.',
            'Текущее правило: ${selectedRouteMode.label}.',
            'Состояние: ${_consumerProtectionStatusLabel(runtimeSnapshot)}.',
          ],
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _ProfileHubTile(
                title: 'Подписка',
                value: appContext.accessLane.label,
                caption: hasProvisionedAccess
                    ? 'Продление и премиум начинаются отсюда.'
                    : 'Пробные ${appContext.runtimeProfile.trialDays} дней станут активны после подготовки устройства.',
                icon: Icons.workspace_premium_outlined,
                tone: _SectionTone.accent,
              ),
              _ProfileHubTile(
                title: 'Устройство',
                value: appContext.hostPlatform.label,
                caption:
                    'Сейчас используется правило «${selectedRouteMode.label}».',
                icon: Icons.devices_outlined,
              ),
              _ProfileHubTile(
                title: 'Бонус Telegram',
                value: '+${appContext.runtimeProfile.telegramBonusDays} дней',
                caption:
                    'Не обязателен каждый день, но помогает с бонусом, восстановлением и поддержкой.',
                icon: Icons.add_circle_outline_rounded,
              ),
              _ProfileHubTile(
                title: 'Поддержка',
                value: 'Приложение → кабинет → Telegram',
                caption: 'Порядок восстановления простой и предсказуемый.',
                icon: Icons.support_agent_rounded,
              ),
            ],
          ),
        ),
        _SectionCard(
          title: 'Подписка',
          lines: [
            'Текущий доступ: ${appContext.accessLane.label}.',
            appContext.accessLane.summary,
            'Продление открывается во внешнем браузере.',
          ],
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: () =>
                    onOpenHandoff('checkout', appContext.checkoutUrl),
                icon: const Icon(Icons.shopping_bag_outlined),
                label: const Text('Перейти к оплате'),
              ),
              OutlinedButton.icon(
                onPressed: () =>
                    onOpenHandoff('cabinet', appContext.cabinetUrl),
                icon: const Icon(Icons.web),
                label: const Text('Открыть кабинет'),
              ),
            ],
          ),
        ),
        _SectionCard(
          title: 'Бонус Telegram',
          lines: [
            'Подпишитесь на ${appContext.supportSnapshot.publicChannel} и заберите +${appContext.runtimeProfile.telegramBonusDays} дней.',
            'Telegram остается необязательным для ежедневного подключения: это бонус, восстановление и запасной канал поддержки.',
          ],
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              OutlinedButton.icon(
                onPressed: () => onOpenHandoff(
                  'community',
                  appContext.supportSnapshot.publicChannel,
                ),
                icon: const Icon(Icons.campaign_outlined),
                label: const Text('Открыть канал'),
              ),
              OutlinedButton.icon(
                onPressed: () => onOpenHandoff(
                    'support', appContext.supportSnapshot.supportBot),
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Открыть поддержку'),
              ),
            ],
          ),
        ),
        _SectionCard(
          title: 'Устройства',
          lines: [
            'Это устройство: ${appContext.hostPlatform.label}.',
            'Основные публичные платформы: ${appContext.scope.publicReleaseSummary}.',
            if (readinessOnlySummary.isNotEmpty)
              'Apple готовится отдельно: $readinessOnlySummary.',
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _KeyValueLine(
                label: 'Правило на устройстве',
                value: selectedRouteMode.label,
              ),
              _KeyValueLine(
                label: 'Базовый доступ',
                value:
                    'Отдельная бесплатная локация · ${appContext.runtimeProfile.freeTier.quotaSummary}',
              ),
              if (appContext.bootstrapContract.supportsSelectedAppsMode)
                const _KeyValueLine(
                  label: 'Выбранные приложения',
                  value: 'Меняются во вкладке «Правила»',
                ),
            ],
          ),
        ),
        _SectionCard(
          title: 'Настройки',
          lines: [
            'Состояние подключения: ${_consumerProtectionStatusLabel(runtimeSnapshot)}.',
            _consumerProtectionStatusSummary(
              runtimeSnapshot,
              headline: runtimeHeadline,
              hostPlatform: appContext.hostPlatform,
            ),
            'Режим совместимости скрыт, пока поддержка не попросит его открыть.',
          ],
          child: _ThemeModeSelector(
            selectedThemeMode: themeMode,
            onThemeModeChanged: onThemeModeChanged,
          ),
        ),
        _RedeemPanel(
          hintCode: appContext.redeemHint,
          onRedeem: (code) => onOpenHandoff('redeem', code),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Поддержка',
          lines: [
            appContext.supportSnapshot.summary,
            'Порядок восстановления: приложение, затем кабинет, затем Telegram.',
            'Отзыв можно отправить через ${appContext.supportSnapshot.feedbackBot}.',
            appContext.supportSnapshot.safeNotes,
          ],
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              OutlinedButton.icon(
                onPressed: () => onOpenHandoff(
                    'support', appContext.supportSnapshot.supportBot),
                icon: const Icon(Icons.support_agent),
                label: const Text('Написать в поддержку'),
              ),
              OutlinedButton.icon(
                onPressed: () => onOpenHandoff(
                    'feedback', appContext.supportSnapshot.feedbackBot),
                icon: const Icon(Icons.rate_review_outlined),
                label: const Text('Оставить отзыв'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RulesSection extends StatelessWidget {
  const _RulesSection({
    required this.appContext,
    required this.selectedRouteMode,
    required this.onRouteModeSelected,
  });

  final SeedAppContext appContext;
  final RouteMode selectedRouteMode;
  final ValueChanged<RouteMode> onRouteModeSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedAppsAvailable =
        appContext.bootstrapContract.supportsSelectedAppsMode;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(_AppShellCopy.rulesTab, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 12),
        _SectionCard(
          title: _AppShellCopy.routeModeQuestion,
          tone: _SectionTone.accent,
          lines: [
            'Выберите спокойный сценарий для устройства.',
            'Первый выбор: «${_AppShellCopy.routeModeDeviceWide}» или «${_AppShellCopy.routeModeSelectedApps}».',
            'Текущий сценарий: ${_deviceScopeLabel(selectedRouteMode)}.',
          ],
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _DeviceScopeCard(
                title: _AppShellCopy.routeModeDeviceWide,
                caption:
                    'Рекомендуемый сценарий для телефона или компьютера целиком.',
                icon: Icons.devices_rounded,
                selected: selectedRouteMode != RouteMode.selectedApps,
                onTap: () => onRouteModeSelected(RouteMode.allExceptRu),
              ),
              _DeviceScopeCard(
                title: _AppShellCopy.routeModeSelectedApps,
                caption: selectedAppsAvailable
                    ? 'Для выбранных приложений или процессов.'
                    : 'На этой платформе готовится отдельно.',
                icon: Icons.apps_rounded,
                selected: selectedRouteMode == RouteMode.selectedApps,
                onTap: selectedAppsAvailable
                    ? () => onRouteModeSelected(RouteMode.selectedApps)
                    : null,
              ),
            ],
          ),
        ),
        if (selectedRouteMode != RouteMode.selectedApps)
          _SectionCard(
            title: 'Правило для устройства целиком',
            lines: [
              'Обычно подходит «${RouteMode.allExceptRu.label}».',
              'Если нужно направить через POKROV вообще все соединения, выберите «${RouteMode.fullTunnel.label}».',
            ],
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _RouteModeCard(
                  mode: RouteMode.allExceptRu,
                  selected: selectedRouteMode == RouteMode.allExceptRu,
                  onTap: () => onRouteModeSelected(RouteMode.allExceptRu),
                ),
                _RouteModeCard(
                  mode: RouteMode.fullTunnel,
                  selected: selectedRouteMode == RouteMode.fullTunnel,
                  onTap: () => onRouteModeSelected(RouteMode.fullTunnel),
                ),
              ],
            ),
          ),
        _SectionCard(
          title: 'Доступные правила',
          lines: [
            '${RouteMode.allExceptRu.label}: ${RouteMode.allExceptRu.summary}',
            '${RouteMode.fullTunnel.label}: ${RouteMode.fullTunnel.summary}',
            selectedAppsAvailable
                ? '${RouteMode.selectedApps.label}: ${RouteMode.selectedApps.summary}'
                : '${RouteMode.selectedApps.label}: пока недоступно на ${appContext.hostPlatform.label}.',
          ],
        ),
        _SectionCard(
          title: 'Что меняется здесь',
          lines: [
            'Выбор приложений и обходы живут в этой вкладке.',
            'Локации остаются простым управляемым выбором.',
            'Профиль хранит поддержку, подписку, устройства и настройки.',
          ],
        ),
        _SectionCard(
          title: 'Что скрыто',
          lines: [
            'Пользователь видит одну управляемую локацию.',
            'Детали подключения и диагностика не попадают на первый слой.',
            'Расширенная совместимость открывается только при необходимости.',
          ],
        ),
      ],
    );
  }
}

class _ThemeModeSelector extends StatelessWidget {
  const _ThemeModeSelector({
    required this.selectedThemeMode,
    required this.onThemeModeChanged,
  });

  final ThemeMode selectedThemeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<ThemeMode>(
      segments: const [
        ButtonSegment(
          value: ThemeMode.system,
          icon: Icon(Icons.brightness_auto_outlined),
          label: Text('Система'),
        ),
        ButtonSegment(
          value: ThemeMode.light,
          icon: Icon(Icons.light_mode_outlined),
          label: Text('Светлая'),
        ),
        ButtonSegment(
          value: ThemeMode.dark,
          icon: Icon(Icons.dark_mode_outlined),
          label: Text('Темная'),
        ),
      ],
      selected: {selectedThemeMode},
      showSelectedIcon: false,
      onSelectionChanged: (selection) {
        onThemeModeChanged(selection.single);
      },
    );
  }
}

class _RedeemPanel extends StatefulWidget {
  const _RedeemPanel({
    required this.hintCode,
    required this.onRedeem,
  });

  final String hintCode;
  final ValueChanged<String> onRedeem;

  @override
  State<_RedeemPanel> createState() => _RedeemPanelState();
}

class _RedeemPanelState extends State<_RedeemPanel> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.hintCode);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Активировать ключ доступа',
      lines: const [
        'Бот, кабинет и оплата выдают одноразовый ключ без ручных ссылок.',
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              labelText: 'Ключ доступа',
              hintText: 'POKROV-XXXX-XXXX',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => widget.onRedeem(_controller.text.trim()),
            icon: const Icon(Icons.verified_outlined),
            label: const Text('Активировать'),
          ),
        ],
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.location,
    required this.appContext,
    required this.selectedRouteMode,
  });

  final LocationCluster location;
  final SeedAppContext appContext;
  final RouteMode selectedRouteMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.82),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _SeedPalette.line),
        boxShadow: [
          BoxShadow(
            color: _SeedPalette.ink.withOpacity(0.05),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _SeedPalette.accent.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.public_rounded,
              color: _SeedPalette.accent,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            location.label,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: _SeedPalette.ink,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            location.city,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: _SeedPalette.ink.withOpacity(0.72),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      location.recommendedLane,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: _SeedPalette.accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'POKROV выбирает подходящую включенную локацию для вашего доступа без ручных сетевых настроек.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _SeedPalette.ink.withOpacity(0.7),
                    height: 1.32,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _StatusPill(
                      label: selectedRouteMode.label,
                      icon: Icons.alt_route_rounded,
                    ),
                    _StatusPill(
                      label: appContext.accessLane.label,
                      icon: Icons.workspace_premium_outlined,
                    ),
                    _StatusPill(
                      label: 'Бесплатная локация',
                      icon: Icons.hub_outlined,
                      tone: _SectionTone.muted,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _consumerProtectionStatusLabel(
  RuntimeSnapshot? snapshot, {
  bool busy = false,
}) {
  if (busy) {
    return 'Готовим';
  }
  if (snapshot == null) {
    return 'Проверяем';
  }
  if (snapshot.phase == RuntimePhase.running) {
    return snapshot.isCleanlyHealthy ? 'Подключено' : 'Нужно внимание';
  }
  if (snapshot.phase == RuntimePhase.artifactMissing) {
    return 'Недоступно';
  }
  if ((snapshot.stagedConfigPath ?? '').isNotEmpty) {
    return 'Готово';
  }
  return 'Готово';
}

String _consumerRuntimeMessage(String message) {
  final normalized = message.trim().toLowerCase();
  if (normalized.isEmpty) {
    return 'Состояние обновлено.';
  }
  if (normalized.contains('permission')) {
    return 'Подтвердите системное разрешение, чтобы продолжить подключение.';
  }
  if (normalized.contains('denied')) {
    return 'Системное разрешение не выдано. Попробуйте еще раз.';
  }
  if (normalized.contains('failed') || normalized.contains('error')) {
    return 'Не удалось завершить действие. Откройте поддержку, если проблема повторится.';
  }
  if (normalized.contains('running')) {
    return 'Подключение активно.';
  }
  if (normalized.contains('staged')) {
    return 'Профиль готов к подключению.';
  }
  if (normalized.contains('ready')) {
    return 'Устройство готово к подключению.';
  }
  return 'Состояние обновлено.';
}

String _consumerProtectionStatusSummary(
  RuntimeSnapshot? snapshot, {
  required String? headline,
  required HostPlatform hostPlatform,
}) {
  if ((headline ?? '').trim().isNotEmpty) {
    return headline!.trim();
  }
  if (snapshot == null) {
    return 'Проверяем, готово ли устройство ${hostPlatform.label}.';
  }
  if (snapshot.phase == RuntimePhase.running) {
    return snapshot.isCleanlyHealthy
        ? 'Управляемое подключение активно.'
        : 'Подключение активно, но приложение заметило пункт для проверки.';
  }
  if (snapshot.phase == RuntimePhase.artifactMissing) {
    return 'Устройство еще завершает подготовку перед подключением.';
  }
  if ((snapshot.stagedConfigPath ?? '').isNotEmpty) {
    return 'Профиль готов. Нажмите главную кнопку, когда будете готовы.';
  }
  return 'POKROV готовит подключение в фоне, чтобы ежедневный запуск был простым.';
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.lines,
    this.child,
    this.tone = _SectionTone.neutral,
  });

  final String title;
  final List<String> lines;
  final Widget? child;
  final _SectionTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = switch (tone) {
      _SectionTone.accent => (
          background: const LinearGradient(
            colors: [_SeedPalette.sky, _SeedPalette.mint],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: _SeedPalette.accent.withOpacity(0.12),
        ),
      _SectionTone.muted => (
          background: const LinearGradient(
            colors: [_SeedPalette.surfaceMuted, Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: _SeedPalette.line,
        ),
      _SectionTone.neutral => (
          background: const LinearGradient(
            colors: [_SeedPalette.surface, Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: _SeedPalette.line,
        ),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: colors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: _SeedPalette.ink.withOpacity(0.06),
            blurRadius: 32,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 10),
            ...lines.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  line,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: _SeedPalette.ink.withOpacity(0.76),
                        height: 1.32,
                      ),
                ),
              ),
            ),
            if (child != null) ...[
              const SizedBox(height: 14),
              child!,
            ],
          ],
        ),
      ),
    );
  }
}

class _SeedBackdrop extends StatelessWidget {
  const _SeedBackdrop({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _SeedPalette.canvas,
            _SeedPalette.canvasAlt,
            _SeedPalette.canvas,
          ],
          stops: [0, 0.42, 1],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: child,
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.icon,
    this.tone = _SectionTone.neutral,
  });

  final String label;
  final IconData icon;
  final _SectionTone tone;

  @override
  Widget build(BuildContext context) {
    final background = switch (tone) {
      _SectionTone.accent => _SeedPalette.accent.withOpacity(0.12),
      _SectionTone.muted => _SeedPalette.surfaceMuted.withOpacity(0.92),
      _SectionTone.neutral => Colors.white.withOpacity(0.86),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _SeedPalette.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: _SeedPalette.accent),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: _SeedPalette.ink,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.caption,
    required this.icon,
  });

  final String label;
  final String value;
  final String caption;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 156, maxWidth: 210),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.62),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _SeedPalette.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _SeedPalette.accent.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: _SeedPalette.accent),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: _SeedPalette.ink.withOpacity(0.72),
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: _SeedPalette.ink,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              caption,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _SeedPalette.ink.withOpacity(0.66),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectOrbButton extends StatelessWidget {
  const _ConnectOrbButton({
    required this.running,
    required this.degraded,
    required this.busy,
    required this.onPressed,
  });

  final bool running;
  final bool degraded;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final accent = degraded
        ? const Color(0xFFB5673A)
        : running
            ? _SeedPalette.accentBright
            : _SeedPalette.accent;
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        width: 208,
        height: 208,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              accent.withOpacity(0.2),
              accent.withOpacity(0.08),
              accent.withOpacity(0.01),
            ],
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              width: 182,
              height: 182,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: accent.withOpacity(running ? 0.16 : 0.09),
                  width: 1.4,
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              width: 156,
              height: 156,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: accent.withOpacity(running ? 0.22 : 0.12),
                  width: 8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accent.withOpacity(0.14),
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 260),
              top: 34,
              right: running ? 48 : 56,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 260),
                opacity: busy ? 0.4 : 0.9,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: accent.withOpacity(0.35),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            AnimatedScale(
              duration: const Duration(milliseconds: 260),
              scale: busy
                  ? 0.98
                  : running
                      ? 1.02
                      : 1,
              child: Container(
                width: 126,
                height: 126,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.94),
                  border: Border.all(
                    color: accent.withOpacity(0.28),
                    width: 9,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      busy
                          ? Icons.sync_rounded
                          : degraded
                              ? Icons.warning_amber_rounded
                              : running
                                  ? Icons.shield_rounded
                                  : Icons.flash_on_rounded,
                      size: 34,
                      color: accent,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      busy
                          ? 'Готовим'
                          : degraded
                              ? 'Внимание'
                              : running
                                  ? 'Включено'
                                  : 'Один тап',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: _SeedPalette.ink,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteModeCard extends StatelessWidget {
  const _RouteModeCard({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final RouteMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 210,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? _SeedPalette.accent.withOpacity(0.12)
              : Colors.white.withOpacity(0.78),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? _SeedPalette.accent.withOpacity(0.28)
                : _SeedPalette.line,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  selected ? Icons.check_circle_rounded : Icons.tune_rounded,
                  size: 18,
                  color: _SeedPalette.accent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    mode.label,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: _SeedPalette.ink,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              mode.summary,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _SeedPalette.ink.withOpacity(0.7),
                    height: 1.3,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
