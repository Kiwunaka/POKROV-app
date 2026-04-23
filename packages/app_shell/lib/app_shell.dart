library pokrov_app_shell;

import 'dart:async';

import 'package:flutter/material.dart';
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
  static const canvas = Color(0xFFF4F0E7);
  static const canvasAlt = Color(0xFFEAF1E9);
  static const ink = Color(0xFF12261B);
  static const accent = Color(0xFF216A4D);
  static const accentBright = Color(0xFF3F8B67);
  static const mint = Color(0xFFBDE6CF);
  static const sky = Color(0xFFD9ECE6);
  static const rose = Color(0xFFF4D6CC);
  static const surface = Color(0xFFF9FBF7);
  static const surfaceMuted = Color(0xFFF1F5EE);
  static const line = Color(0x1A163022);
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
          'The seed shell can now validate runtime artifacts and initialize libcore on supported desktop hosts.',
      recommendedRouteMode: RouteMode.allExceptRu,
      channelBonusDays: 10,
    ),
    locations: const [
      LocationCluster(
        code: 'pokrov-managed',
        label: 'POKROV',
        city: 'Single logical location',
        countryCode: 'PO',
        recommendedLane: 'Auto-managed',
        variants: [
          LocationVariant(kind: TransportKind.vlessReality),
          LocationVariant(kind: TransportKind.vmess),
          LocationVariant(kind: TransportKind.trojan),
          LocationVariant(
            kind: TransportKind.xhttp,
            availability: VariantAvailability.gated,
            note: 'Needs CDN/static front before public launch.',
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
    redeemHint: 'POKROV-START-2026',
    managedProfileSeed: _seedManagedProfilePayload,
  );
}

class PokrovSeedApp extends StatelessWidget {
  const PokrovSeedApp({
    super.key,
    required this.appContext,
    this.bootstrapper,
  });

  final SeedAppContext appContext;
  final ManagedProfileBootstrapper? bootstrapper;

  @override
  Widget build(BuildContext context) {
    const colorScheme = ColorScheme.light(
      primary: _SeedPalette.accent,
      onPrimary: Colors.white,
      secondary: _SeedPalette.accentBright,
      onSecondary: Colors.white,
      surface: _SeedPalette.surface,
      onSurface: _SeedPalette.ink,
      error: Color(0xFFB33B2E),
      onError: Colors.white,
    );

    return MaterialApp(
      title: 'POKROV',
      theme: ThemeData(
        colorScheme: colorScheme,
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
            borderRadius: BorderRadius.circular(28),
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
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: _SeedPalette.ink,
            side: BorderSide(color: _SeedPalette.ink.withOpacity(0.16)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      ),
      home: PokrovSeedShell(
        appContext: appContext,
        bootstrapper: bootstrapper,
      ),
    );
  }
}

class PokrovSeedShell extends StatefulWidget {
  const PokrovSeedShell({
    super.key,
    required this.appContext,
    this.bootstrapper,
  });

  final SeedAppContext appContext;
  final ManagedProfileBootstrapper? bootstrapper;

  @override
  State<PokrovSeedShell> createState() => _PokrovSeedShellState();
}

class _PokrovSeedShellState extends State<PokrovSeedShell>
    with WidgetsBindingObserver {
  int _selectedIndex = 0;
  late RouteMode _selectedRouteMode;
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

  void _showSeedHandoff(String label, String value) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Next step: $label -> $value'),
      ),
    );
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
        _runtimeHeadline = 'Protection refreshed from '
            '${Uri.parse(widget.appContext.apiBaseUrl).host}.';
      });
    }
    return payload;
  }

  Future<void> _toggleRuntime() async {
    if (_runtimeBusy) {
      setState(() {
        _runtimeHeadline = 'Protection is already updating. Give it a moment.';
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
          _runtimeHeadline = current.message;
        });
        return;
      }

      if (!_canPrimaryConnect(snapshot)) {
        setState(() {
          _runtimeHeadline =
              'This device still needs a little setup before protection can start.';
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
                  ? 'Protection is on.'
                  : 'Protection is on, but it needs attention.'
              : current.message;
        });
        if (current.phase != RuntimePhase.running &&
            current.message.trim().isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(current.message)),
          );
        }
      }
    } on BootstrapFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _runtimeHeadline = error.message;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
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
        runtimeSnapshot: _runtimeSnapshot,
        runtimeHeadline: _runtimeHeadline,
        runtimeBusy: _runtimeBusy,
        primaryConnectEnabled: _canPrimaryConnect(_runtimeSnapshot),
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
            _managedProfileDirty = true;
          });
        },
      ),
      _ProfileSection(
        appContext: widget.appContext,
        selectedRouteMode: _selectedRouteMode,
        hasProvisionedAccess: hasProvisionedAccess,
        onOpenHandoff: _showSeedHandoff,
        runtimeSnapshot: _runtimeSnapshot,
        runtimeHeadline: _runtimeHeadline,
      ),
    ];

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('POKROV'),
            Text(
              'Protection first. Everything else stays close.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _SeedPalette.ink.withOpacity(0.68),
                  ),
            ),
          ],
        ),
      ),
      body: _SeedBackdrop(
        child: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: KeyedSubtree(
              key: ValueKey<int>(_selectedIndex),
              child: sections[_selectedIndex],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.78),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: _SeedPalette.line),
              boxShadow: [
                BoxShadow(
                  color: _SeedPalette.ink.withOpacity(0.08),
                  blurRadius: 36,
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
                  icon: Icon(Icons.flash_on_outlined),
                  selectedIcon: Icon(Icons.flash_on),
                  label: 'Protection',
                ),
                NavigationDestination(
                  icon: Icon(Icons.public_outlined),
                  selectedIcon: Icon(Icons.public),
                  label: 'Locations',
                ),
                NavigationDestination(
                  icon: Icon(Icons.rule_folder_outlined),
                  selectedIcon: Icon(Icons.rule_folder),
                  label: 'Rules',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickConnectSection extends StatelessWidget {
  const _QuickConnectSection({
    required this.appContext,
    required this.selectedRouteMode,
    required this.runtimeSnapshot,
    required this.runtimeHeadline,
    required this.runtimeBusy,
    required this.primaryConnectEnabled,
    required this.onRefreshRuntime,
    required this.onToggleRuntime,
  });

  final SeedAppContext appContext;
  final RouteMode selectedRouteMode;
  final RuntimeSnapshot? runtimeSnapshot;
  final String? runtimeHeadline;
  final bool runtimeBusy;
  final bool primaryConnectEnabled;
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
        ? 'Checking protection'
        : isRunning
            ? isHealthyRunning
                ? 'Protected'
                : 'Protected, with a note'
            : primaryActionEnabled
                ? 'Ready when you are'
                : 'Finish setup first';

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 160),
      children: [
        Text('Protection', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        _SectionCard(
          title: heroTitle,
          tone: _SectionTone.accent,
          lines: [
            statusSummary,
            primaryActionEnabled
                ? 'One main control lives here. Rules adjusts behaviour. Profile keeps the rest together.'
                : 'This device still needs a little setup before protection can start.',
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _MetricTile(
                    label: 'Status',
                    value: statusLabel,
                    caption: isRunning
                        ? 'Daily use stays centered here.'
                        : 'Protection stays simple on purpose.',
                    icon: isRunning
                        ? Icons.shield_rounded
                        : Icons.play_circle_outline_rounded,
                  ),
                  _MetricTile(
                    label: 'Current rule',
                    value: selectedRouteMode.label,
                    caption: 'Change this in Rules',
                    icon: Icons.alt_route_rounded,
                  ),
                  _MetricTile(
                    label: 'This device',
                    value: appContext.hostPlatform.label,
                    caption: 'Subscription, support, and bonus live in Profile',
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
                        ? 'Preparing protection'
                        : isRunning
                            ? 'Turn protection off'
                            : primaryActionEnabled
                                ? 'Turn protection on'
                                : 'Protection unavailable',
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
                    ? 'Protection is on, but it may need attention. Profile is the next stop if you need help.'
                    : primaryActionEnabled
                        ? 'One clear action starts protection with your managed setup.'
                        : 'Use Check status again once this device finishes setup.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: _SeedPalette.ink.withOpacity(0.72),
                    ),
              ),
            ],
          ),
        ),
        _SectionCard(
          title: 'What stays simple',
          tone: _SectionTone.muted,
          lines: [
            appContext.accessLane.summary,
            'Trial: ${appContext.runtimeProfile.trialDays} days. Telegram bonus: +${appContext.runtimeProfile.telegramBonusDays} days.',
            'Free fallback stays on ${appContext.runtimeProfile.freeTier.nodePool} with ${appContext.runtimeProfile.freeTier.quotaSummary}.',
          ],
        ),
        _SectionCard(
          title: 'Connection status',
          tone: _SectionTone.neutral,
          lines: [
            'Now: $statusLabel',
            statusSummary,
            'Current rule: ${selectedRouteMode.label}',
            isRunning
                ? 'Protection is already active on this device.'
                : 'If setup is still finishing, check status again in a moment.',
          ],
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              OutlinedButton.icon(
                onPressed: runtimeBusy ? null : onRefreshRuntime,
                icon: const Icon(Icons.refresh),
                label: const Text('Check status again'),
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
                      ? 'Stop from here'
                      : 'Start from here',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
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
        Text('Locations', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Auto-managed',
          tone:
              hasProvisionedAccess ? _SectionTone.neutral : _SectionTone.muted,
          lines: [
            'POKROV keeps the location story calm: one managed location, not a wall of countries.',
            'Current rule: ${selectedRouteMode.label}.',
            hasProvisionedAccess
                ? 'This device already has a managed location ready.'
                : 'Finish setup from Protection first. Until then, Locations stays quiet instead of showing placeholders.',
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
            title: 'Available after setup',
            lines: [
              'Turn protection on once to create the app-first session for this device.',
              'After that, this screen will show the managed route without exposing raw network controls.',
            ],
          ),
        ],
        _SectionCard(
          title: 'How it chooses',
          lines: [
            'Premium access uses enabled non-free locations.',
            'Free fallback stays on ${appContext.runtimeProfile.freeTier.nodePool}.',
            'Transport details stay hidden behind auto and support diagnostics.',
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
  });

  final SeedAppContext appContext;
  final RouteMode selectedRouteMode;
  final bool hasProvisionedAccess;
  final void Function(String label, String value) onOpenHandoff;
  final RuntimeSnapshot? runtimeSnapshot;
  final String? runtimeHeadline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final readinessOnlySummary = appContext.scope.readinessOnlySummary;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Profile', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Everything for this account',
          tone: _SectionTone.accent,
          lines: [
            hasProvisionedAccess
                ? 'Subscription, devices, support, settings, and Telegram bonus all live here.'
                : 'This will be the hub for subscription, device setup, support, settings, and Telegram bonus once this device is ready.',
            'Current rule: ${selectedRouteMode.label}.',
            'Current status: ${_consumerProtectionStatusLabel(runtimeSnapshot)}.',
          ],
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _ProfileHubTile(
                title: 'Subscription',
                value: appContext.accessLane.label,
                caption: hasProvisionedAccess
                    ? 'Renew or upgrade from here when you need to.'
                    : 'The ${appContext.runtimeProfile.trialDays}-day start becomes real when this device finishes setup.',
                icon: Icons.workspace_premium_outlined,
                tone: _SectionTone.accent,
              ),
              _ProfileHubTile(
                title: 'Device',
                value: appContext.hostPlatform.label,
                caption:
                    'This device is currently using ${selectedRouteMode.label}.',
                icon: Icons.devices_outlined,
              ),
              _ProfileHubTile(
                title: 'Telegram bonus',
                value: '+${appContext.runtimeProfile.telegramBonusDays} days',
                caption:
                    'Optional for daily use. Helpful for bonus, recovery, and support.',
                icon: Icons.add_circle_outline_rounded,
              ),
              _ProfileHubTile(
                title: 'Support',
                value: 'App -> web -> Telegram',
                caption: 'The recovery order stays calm and predictable.',
                icon: Icons.support_agent_rounded,
              ),
            ],
          ),
        ),
        _SectionCard(
          title: 'Subscription',
          lines: [
            'Current plan: ${appContext.accessLane.label}.',
            appContext.accessLane.summary,
            'Checkout continues in the browser when you need renewal or paid access.',
          ],
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: () =>
                    onOpenHandoff('checkout', appContext.checkoutUrl),
                icon: const Icon(Icons.shopping_bag_outlined),
                label: const Text('Continue to checkout'),
              ),
              OutlinedButton.icon(
                onPressed: () =>
                    onOpenHandoff('cabinet', appContext.cabinetUrl),
                icon: const Icon(Icons.web),
                label: const Text('Open cabinet'),
              ),
            ],
          ),
        ),
        _SectionCard(
          title: 'Telegram bonus',
          lines: [
            'Join ${appContext.supportSnapshot.publicChannel} and claim one extra +${appContext.runtimeProfile.telegramBonusDays} day bonus.',
            'Telegram stays optional for normal daily use. Here it acts as bonus, recovery, and support continuation.',
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
                label: const Text('Open community channel'),
              ),
              OutlinedButton.icon(
                onPressed: () => onOpenHandoff(
                    'support', appContext.supportSnapshot.supportBot),
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Open support bot'),
              ),
            ],
          ),
        ),
        _SectionCard(
          title: 'Devices',
          lines: [
            'This device: ${appContext.hostPlatform.label}.',
            'Public platform promise: ${appContext.scope.publicReleaseSummary}.',
            if (readinessOnlySummary.isNotEmpty)
              'Readiness-only hosts: $readinessOnlySummary.',
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _KeyValueLine(
                label: 'Route on this device',
                value: selectedRouteMode.label,
              ),
              _KeyValueLine(
                label: 'Free fallback',
                value:
                    '${appContext.runtimeProfile.freeTier.nodePool} · ${appContext.runtimeProfile.freeTier.quotaSummary}',
              ),
              if (appContext.bootstrapContract.supportsSelectedAppsMode)
                const _KeyValueLine(
                  label: 'Selected apps',
                  value: 'Adjust this from Rules when needed',
                ),
            ],
          ),
        ),
        _SectionCard(
          title: 'Settings',
          lines: [
            'Connection status: ${_consumerProtectionStatusLabel(runtimeSnapshot)}.',
            _consumerProtectionStatusSummary(
              runtimeSnapshot,
              headline: runtimeHeadline,
              hostPlatform: appContext.hostPlatform,
            ),
            'Compatibility mode stays tucked away unless support asks for it.',
          ],
        ),
        _RedeemPanel(
          hintCode: appContext.redeemHint,
          onRedeem: (code) => onOpenHandoff('redeem', code),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Support',
          lines: [
            appContext.supportSnapshot.summary,
            'Recovery order: app, then web cabinet, then Telegram.',
            'Feedback stays available through ${appContext.supportSnapshot.feedbackBot}.',
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
                label: const Text('Contact support'),
              ),
              OutlinedButton.icon(
                onPressed: () => onOpenHandoff(
                    'feedback', appContext.supportSnapshot.feedbackBot),
                icon: const Icon(Icons.rate_review_outlined),
                label: const Text('Send feedback'),
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
    final routeChoices = appContext.runtimeProfile.supportedRouteModes;
    final selectedAppsAvailable =
        appContext.bootstrapContract.supportsSelectedAppsMode;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Rules', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Pick a route style',
          tone: _SectionTone.accent,
          lines: [
            'Choose how this device should behave. The labels stay human on purpose.',
            'Current choice: ${selectedRouteMode.label}.',
            'Recommended default: ${RouteMode.allExceptRu.label}.',
          ],
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: routeChoices
                .map(
                  (mode) => _RouteModeCard(
                    mode: mode,
                    selected: selectedRouteMode == mode,
                    onTap: () => onRouteModeSelected(mode),
                  ),
                )
                .toList(),
          ),
        ),
        _SectionCard(
          title: 'Route labels',
          lines: [
            '${RouteMode.allExceptRu.label}: ${RouteMode.allExceptRu.summary}',
            '${RouteMode.fullTunnel.label}: ${RouteMode.fullTunnel.summary}',
            selectedAppsAvailable
                ? '${RouteMode.selectedApps.label}: ${RouteMode.selectedApps.summary}'
                : '${RouteMode.selectedApps.label}: not available on ${appContext.hostPlatform.label} yet.',
          ],
        ),
        _SectionCard(
          title: 'What changes here',
          lines: [
            'Split tunnelling and bypass behaviour live here.',
            'Locations stays focused on one managed location story.',
            'Profile keeps support, subscription, devices, and settings together.',
          ],
        ),
        _SectionCard(
          title: 'Behind the scenes',
          lines: [
            'The user sees one managed location only.',
            'Transport variants and diagnostics stay out of the first layer.',
            'Advanced compatibility stays tucked away unless support needs it.',
          ],
        ),
      ],
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
      title: 'Redeem activation key',
      lines: const [
        'Bot, web, and checkout issue a single-use activation key instead of a raw personal link.',
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              labelText: 'Activation key',
              hintText: 'POKROV-XXXX-XXXX',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => widget.onRedeem(_controller.text.trim()),
            icon: const Icon(Icons.verified_outlined),
            label: const Text('Redeem key'),
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
        borderRadius: BorderRadius.circular(28),
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
                  'POKROV chooses the best enabled location for your current plan without asking you to manage raw network controls.',
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
                      label: appContext.runtimeProfile.freeTier.nodePool,
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
    return 'Preparing';
  }
  if (snapshot == null) {
    return 'Checking status';
  }
  if (snapshot.phase == RuntimePhase.running) {
    return snapshot.isCleanlyHealthy ? 'Protected' : 'Needs attention';
  }
  if (snapshot.phase == RuntimePhase.artifactMissing) {
    return 'Unavailable';
  }
  if ((snapshot.stagedConfigPath ?? '').isNotEmpty) {
    return 'Ready to protect';
  }
  return 'Ready';
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
    return 'Checking whether this ${hostPlatform.label} device is ready.';
  }
  if (snapshot.phase == RuntimePhase.running) {
    return snapshot.isCleanlyHealthy
        ? 'Your managed protection is active.'
        : 'Protection is on, but the app noticed something worth checking.';
  }
  if (snapshot.phase == RuntimePhase.artifactMissing) {
    return 'This device is still finishing setup before protection can start.';
  }
  if ((snapshot.stagedConfigPath ?? '').isNotEmpty) {
    return 'Everything is staged and ready when you tap the main action.';
  }
  return 'POKROV prepares the connection in the background so daily use stays simple.';
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
        borderRadius: BorderRadius.circular(32),
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
          colors: [_SeedPalette.canvas, _SeedPalette.canvasAlt],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -60,
            right: -10,
            child: _GlowBlob(
              size: 220,
              color: _SeedPalette.mint.withOpacity(0.62),
            ),
          ),
          Positioned(
            top: 150,
            left: -70,
            child: _GlowBlob(
              size: 260,
              color: _SeedPalette.sky.withOpacity(0.58),
            ),
          ),
          Positioned(
            bottom: 60,
            right: -40,
            child: _GlowBlob(
              size: 180,
              color: _SeedPalette.rose.withOpacity(0.46),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  const _GlowBlob({
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withOpacity(0)],
          ),
        ),
      ),
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
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: _SeedPalette.ink,
                  fontWeight: FontWeight.w700,
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
          borderRadius: BorderRadius.circular(22),
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
                          ? 'Preparing'
                          : degraded
                              ? 'Attention'
                              : running
                                  ? 'Protected'
                                  : 'One tap',
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
      borderRadius: BorderRadius.circular(22),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 210,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? _SeedPalette.accent.withOpacity(0.12)
              : Colors.white.withOpacity(0.78),
          borderRadius: BorderRadius.circular(22),
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
