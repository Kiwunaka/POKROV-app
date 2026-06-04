library pokrov_app_shell;

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pokrov_core_domain/core_domain.dart';
import 'package:pokrov_platform_contracts/platform_contracts.dart';
import 'package:pokrov_runtime_engine/runtime_engine.dart';
import 'package:pokrov_support_context/support_context.dart';
import 'package:url_launcher/url_launcher.dart';

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
  reward,
}

enum _FirstLaunchStep {
  choice,
  restore,
  ready,
}

typedef ExternalHandoffLauncher = Future<bool> Function(Uri uri);

abstract class PokrovFirstLaunchStore {
  Future<bool> isCompleted();
  Future<void> markCompleted();
}

class PokrovFileFirstLaunchStore implements PokrovFirstLaunchStore {
  const PokrovFileFirstLaunchStore();

  static const _fileName = 'pokrov-first-launch-state.txt';
  static const _completedMarker = 'completed';

  Future<File> _stateFile() async {
    final directory = await getApplicationSupportDirectory();
    await directory.create(recursive: true);
    return File('${directory.path}${Platform.pathSeparator}$_fileName');
  }

  @override
  Future<bool> isCompleted() async {
    final file = await _stateFile();
    if (!await file.exists()) {
      return false;
    }
    return (await file.readAsString()).trim() == _completedMarker;
  }

  @override
  Future<void> markCompleted() async {
    final file = await _stateFile();
    await file.writeAsString(_completedMarker, flush: true);
  }
}

abstract final class _SeedPalette {
  static const canvas = Color(0xFFF9FAFB);
  static const canvasAlt = Color(0xFFFFFFFF);
  static const ink = Color(0xFF10131A);
  static const accent = Color(0xFF0F725D);
  static const accentBright = Color(0xFF16A27B);
  static const success = Color(0xFF159A68);
  static const warning = Color(0xFFE29A1F);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF3F5F8);
  static const line = Color(0x1A10131A);
  static const muted = Color(0xFF697080);
}

const _pokrovBrandMarkAsset = 'assets/brand/pokrov_mark.png';
const _selectedAppsEnforcementReady = false;

abstract final class _MotionTokens {
  static const quick = Duration(milliseconds: 120);
  static const short = Duration(milliseconds: 180);
  static const standard = Duration(milliseconds: 240);
  static const homeReveal = Duration(milliseconds: 680);
  static const ease = Curves.easeOutCubic;
}

class _MotionScope extends InheritedWidget {
  const _MotionScope({
    required super.child,
    required this.disableAnimations,
    super.key,
  });

  final bool disableAnimations;

  static _MotionScope of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_MotionScope>() ??
        const _MotionScope(
          disableAnimations: false,
          child: SizedBox.shrink(),
        );
  }

  Duration duration(Duration value) {
    return disableAnimations ? Duration.zero : value;
  }

  @override
  bool updateShouldNotify(covariant _MotionScope oldWidget) {
    return oldWidget.disableAnimations != disableAnimations;
  }
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
        if (bootstrapContract.supportsSelectedAppsMode &&
            _selectedAppsEnforcementReady)
          RouteMode.selectedApps,
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
          'Поддержка видит только безопасный контекст: версию приложения, платформу, режим и статус подключения.',
      recommendedRouteMode: RouteMode.allExceptRu,
      channelBonusDays: 10,
    ),
    locations: const [
      LocationCluster(
        code: 'pokrov-managed',
        label: 'POKROV',
        city: 'Автоматический выбор',
        countryCode: 'PO',
        recommendedLane: 'Авто',
        variants: [
          LocationVariant(kind: TransportKind.vlessReality),
          LocationVariant(kind: TransportKind.vmess),
          LocationVariant(kind: TransportKind.trojan),
          LocationVariant(
            kind: TransportKind.xhttp,
            availability: VariantAvailability.gated,
            note: 'Откроется после подготовки публичного контура.',
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

class PokrovSeedApp extends StatelessWidget {
  const PokrovSeedApp({
    super.key,
    required this.appContext,
    this.bootstrapper,
    this.supportTicketService,
    this.handoffLauncher,
    this.firstLaunchStore,
  });

  final SeedAppContext appContext;
  final ManagedProfileBootstrapper? bootstrapper;
  final SupportTicketService? supportTicketService;
  final ExternalHandoffLauncher? handoffLauncher;
  final PokrovFirstLaunchStore? firstLaunchStore;

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
        cardTheme: CardThemeData(
          color: _SeedPalette.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.transparent,
          elevation: 0,
          indicatorColor: _SeedPalette.accent.withValues(alpha: 0.1),
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              fontSize: 12,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w500,
              color: states.contains(WidgetState.selected)
                  ? _SeedPalette.ink
                  : _SeedPalette.ink.withValues(alpha: 0.68),
            ),
          ),
          iconTheme: WidgetStateProperty.resolveWith(
            (states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? _SeedPalette.accent
                  : _SeedPalette.ink.withValues(alpha: 0.68),
            ),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: _SeedPalette.accent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: _SeedPalette.ink,
            side: BorderSide(color: _SeedPalette.ink.withValues(alpha: 0.16)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      home: PokrovSeedShell(
        appContext: appContext,
        bootstrapper: bootstrapper,
        supportTicketService: supportTicketService,
        handoffLauncher: handoffLauncher,
        firstLaunchStore: firstLaunchStore,
      ),
    );
  }
}

class PokrovSeedShell extends StatefulWidget {
  const PokrovSeedShell({
    super.key,
    required this.appContext,
    this.bootstrapper,
    this.supportTicketService,
    this.handoffLauncher,
    this.firstLaunchStore,
  });

  final SeedAppContext appContext;
  final ManagedProfileBootstrapper? bootstrapper;
  final SupportTicketService? supportTicketService;
  final ExternalHandoffLauncher? handoffLauncher;
  final PokrovFirstLaunchStore? firstLaunchStore;

  @override
  State<PokrovSeedShell> createState() => _PokrovSeedShellState();
}

class _PokrovSeedShellState extends State<PokrovSeedShell>
    with WidgetsBindingObserver {
  int _selectedIndex = 0;
  late RouteMode _selectedRouteMode;
  late final PokrovRuntimeEngine _runtimeEngine;
  late final ManagedProfileBootstrapper _bootstrapper;
  late final AppFirstAccountActionService? _accountActionService;
  late final AppFirstBonusActionService? _bonusActionService;
  late final SupportTicketService _supportTicketService;
  late final PokrovFirstLaunchStore _firstLaunchStore;
  final TextEditingController _firstLaunchRestoreCodeController =
      TextEditingController();
  RuntimeSnapshot? _runtimeSnapshot;
  bool _runtimeBusy = false;
  bool _firstLaunchBusy = false;
  bool _managedProfileDirty = true;
  _FirstLaunchStep _firstLaunchStep = _FirstLaunchStep.choice;
  String? _runtimeHeadline;
  String _telegramBonusStatus = 'Получить код';
  bool _telegramBonusBusy = false;
  bool _telegramBonusCanClaim = false;
  String? _telegramBonusError;
  AppFirstBonusSummary? _bonusSummary;
  bool _bonusSummaryBusy = false;
  bool _bonusSummaryRequested = false;
  String? _bonusSummaryError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _selectedRouteMode = widget.appContext.runtimeProfile.defaultRouteMode;
    _runtimeEngine = createRuntimeEngine(
      hostPlatform: widget.appContext.hostPlatform,
    );
    final bootstrapper = widget.bootstrapper ??
        AppFirstRuntimeBootstrapper(
          apiBaseUrl: widget.appContext.apiBaseUrl,
        );
    _bootstrapper = bootstrapper;
    _accountActionService = bootstrapper is AppFirstAccountActionService
        ? bootstrapper as AppFirstAccountActionService
        : null;
    _bonusActionService = bootstrapper is AppFirstBonusActionService
        ? bootstrapper as AppFirstBonusActionService
        : null;
    _supportTicketService = widget.supportTicketService ??
        AppFirstSupportTicketService(
          apiBaseUrl: widget.appContext.apiBaseUrl,
        );
    _firstLaunchStore =
        widget.firstLaunchStore ?? const PokrovFileFirstLaunchStore();
    unawaited(_loadFirstLaunchState());
    _refreshRuntimeSnapshot();
  }

  void _selectRouteMode(RouteMode mode) {
    setState(() {
      _selectedRouteMode = mode;
      _managedProfileDirty = true;
    });
  }

  void _selectTab(SeedTab tab) {
    setState(() {
      _selectedIndex = tab.index;
    });
    if (tab == SeedTab.profile && widget.bootstrapper != null) {
      unawaited(_loadBonusSummary());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _firstLaunchRestoreCodeController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_runtimeBusy) {
      unawaited(_refreshRuntimeSnapshot());
    }
  }

  Future<bool> _launchExternalHandoff(Uri uri) {
    final launcher = widget.handoffLauncher ??
        (Uri target) => launchUrl(
              target,
              mode: LaunchMode.externalApplication,
            );
    return launcher(uri);
  }

  Future<void> _openSafeHandoff(String label, String value) async {
    final uri = _safeHandoffUri(
      label: label,
      value: value,
      cabinetUrl: widget.appContext.cabinetUrl,
    );
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сначала введите код активации.')),
      );
      return;
    }

    final opened = await _launchExternalHandoff(uri);
    if (!mounted) {
      return;
    }
    if (!opened) {
      final fallback = _safeHandoffFallbackUri(
        label: label,
        value: value,
      );
      if (fallback != null && fallback != uri) {
        final fallbackOpened = await _launchExternalHandoff(fallback);
        if (!mounted) {
          return;
        }
        if (fallbackOpened) {
          return;
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось открыть: $uri')),
      );
    }
  }

  Future<bool> _redeemCodeInApp(String value) async {
    final code = value.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите код активации.')),
      );
      return false;
    }
    if (_looksLikeSubscriptionOrProxyLink(code)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ссылка подключения не привязывает аккаунт. Введите одноразовый код или ключ активации.',
          ),
        ),
      );
      return false;
    }

    final accountActions = _accountActionService;
    if (accountActions == null) {
      await _openSafeHandoff('redeem', code);
      return false;
    }

    try {
      HapticFeedback.selectionClick();
      final result = await accountActions.redeemCode(
        hostPlatform: widget.appContext.hostPlatform,
        code: code,
      );
      if (!mounted) {
        return true;
      }
      setState(() {
        _managedProfileDirty = true;
        _runtimeHeadline = result.kind == 'access_key'
            ? 'Код активирован. Доступ обновлен.'
            : 'Код обработан.';
      });
      unawaited(_loadBonusSummary(force: true));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.codePreview.isEmpty
                ? 'Код активирован. Доступ обновлен.'
                : 'Код ${result.codePreview} активирован.',
          ),
        ),
      );
      return true;
    } catch (error) {
      if (!mounted) {
        return false;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось активировать код: $error')),
      );
      return false;
    }
  }

  bool _looksLikeSubscriptionOrProxyLink(String value) {
    final text = value.trim().toLowerCase();
    if (text.isEmpty) {
      return false;
    }
    final parsed = Uri.tryParse(text);
    if (parsed != null && parsed.hasScheme) {
      final scheme = parsed.scheme.toLowerCase();
      if (scheme == 'http' || scheme == 'https') {
        final host = parsed.host.toLowerCase();
        final path = parsed.path.toLowerCase();
        return host == 'connect.pokrov.space' ||
            host.endsWith('.pokrov.space') && path.contains('s8kx2mp7qr4wt') ||
            path.contains('subscription') ||
            path.contains('/sub/') ||
            path.contains('/config/');
      }
      return const <String>{
        'vless',
        'vmess',
        'trojan',
        'ss',
        'socks',
        'wireguard',
        'hysteria2',
        'tuic',
      }.contains(scheme);
    }
    return text.contains('subscription_url=') ||
        text.contains('vless://') ||
        text.contains('vmess://') ||
        text.contains('trojan://');
  }

  Future<void> _openCabinetWithHandoff(String value) async {
    final accountActions = _accountActionService;
    if (accountActions == null) {
      await _openSafeHandoff('cabinet', value);
      return;
    }

    try {
      final handoff = await accountActions.createCabinetHandoff(
        hostPlatform: widget.appContext.hostPlatform,
        targetPath: _cabinetTargetPathFromValue(value),
      );
      final opened = await _launchExternalHandoff(handoff.handoffUrl);
      if (!mounted || opened) {
        return;
      }
      await _openSafeHandoff('cabinet', value);
    } catch (error) {
      if (!mounted) {
        return;
      }
      final fallback = _safeHandoffUri(
        label: 'cabinet',
        value: value,
        cabinetUrl: widget.appContext.cabinetUrl,
      );
      if (fallback != null && await _launchExternalHandoff(fallback)) {
        return;
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось открыть кабинет: $error')),
      );
    }
  }

  Future<void> _createTelegramLinkInApp() async {
    final bonusActions = _bonusActionService;
    if (bonusActions == null) {
      await _openSafeHandoff(
        'community',
        widget.appContext.supportSnapshot.publicChannel,
      );
      return;
    }

    setState(() {
      _telegramBonusBusy = true;
      _telegramBonusError = null;
    });
    try {
      HapticFeedback.selectionClick();
      final result = await bonusActions.createTelegramLink(
        hostPlatform: widget.appContext.hostPlatform,
      );
      final opened = await _launchExternalHandoff(result.botUrl);
      if (!mounted) {
        return;
      }
      setState(() {
        _telegramBonusBusy = false;
        _telegramBonusStatus =
            result.linked ? 'Telegram привязан' : 'Код открыт в Telegram';
        if (!opened) {
          _telegramBonusError = 'Не удалось открыть Telegram автоматически.';
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _telegramBonusBusy = false;
        _telegramBonusError = 'Не удалось получить код: $error';
      });
    }
  }

  Future<void> _checkTelegramBonusInApp() async {
    final bonusActions = _bonusActionService;
    if (bonusActions == null) {
      await _openSafeHandoff(
        'community',
        widget.appContext.supportSnapshot.publicChannel,
      );
      return;
    }

    setState(() {
      _telegramBonusBusy = true;
      _telegramBonusError = null;
    });
    try {
      HapticFeedback.selectionClick();
      final status = await bonusActions.checkChannelBonus(
        hostPlatform: widget.appContext.hostPlatform,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _telegramBonusBusy = false;
        _telegramBonusCanClaim = status.claimRequired;
        _telegramBonusStatus = _telegramBonusStatusForStatus(status);
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _telegramBonusBusy = false;
        _telegramBonusError = 'Не удалось проверить бонус: $error';
      });
    }
  }

  Future<void> _claimTelegramBonusInApp() async {
    final bonusActions = _bonusActionService;
    if (bonusActions == null || !_telegramBonusCanClaim) {
      await _checkTelegramBonusInApp();
      return;
    }

    setState(() {
      _telegramBonusBusy = true;
      _telegramBonusError = null;
    });
    try {
      HapticFeedback.selectionClick();
      final result = await bonusActions.claimChannelBonus(
        hostPlatform: widget.appContext.hostPlatform,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _telegramBonusBusy = false;
        _telegramBonusCanClaim = false;
        _telegramBonusStatus = result.alreadyClaimed
            ? '+${result.premiumDays} дней уже активированы'
            : '+${result.premiumDays} дней активированы';
        _managedProfileDirty = true;
        _runtimeHeadline = 'Telegram-бонус активирован.';
      });
      unawaited(_loadBonusSummary(force: true));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('+${result.premiumDays} дней добавлены к доступу.'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _telegramBonusBusy = false;
        _telegramBonusError = 'Не удалось активировать бонус: $error';
      });
    }
  }

  Future<void> _loadBonusSummary({bool force = false}) async {
    if (_bonusSummaryBusy) {
      return;
    }
    if (!force && _bonusSummaryRequested) {
      return;
    }

    final bonusActions = _bonusActionService;
    if (bonusActions == null) {
      setState(() {
        _bonusSummaryRequested = true;
        _bonusSummaryError = null;
      });
      return;
    }

    setState(() {
      _bonusSummaryBusy = true;
      _bonusSummaryRequested = true;
      _bonusSummaryError = null;
    });
    try {
      if (force) {
        HapticFeedback.selectionClick();
      }
      final summary = await bonusActions.fetchBonusSummary(
        hostPlatform: widget.appContext.hostPlatform,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _bonusSummary = summary;
        _bonusSummaryBusy = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _bonusSummaryBusy = false;
        _bonusSummaryError = 'Не удалось обновить сводку: $error';
      });
    }
  }

  String _telegramBonusStatusForStatus(ChannelBonusStatus status) {
    if (status.alreadyClaimed) {
      return '+${status.bonusDays} дней активированы';
    }
    if (status.claimRequired) {
      return '+${status.bonusDays} дней готовы';
    }
    if (status.linkRequired) {
      return 'Сначала привяжите Telegram';
    }
    if (!status.subscriber) {
      return 'Подпишитесь и проверьте';
    }
    return 'Проверено';
  }

  String _cabinetTargetPathFromValue(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '/';
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null) {
      return '/';
    }
    if (uri.path.isEmpty) {
      return '/';
    }
    if (uri.query.isEmpty) {
      return uri.path;
    }
    return '${uri.path}?${uri.query}';
  }

  void _showSeedHandoff(String label, String value) {
    switch (label) {
      case 'redeem':
        unawaited(_redeemCodeInApp(value));
        return;
      case 'cabinet':
        unawaited(_openCabinetWithHandoff(value));
        return;
      default:
        unawaited(_openSafeHandoff(label, value));
        return;
    }
  }

  Future<void> _loadFirstLaunchState() async {
    var completed = false;
    try {
      completed = await _firstLaunchStore.isCompleted();
    } catch (_) {
      completed = false;
    }
    if (!mounted || !completed) {
      return;
    }
    setState(() {
      _firstLaunchStep = _FirstLaunchStep.ready;
    });
  }

  Future<void> _markFirstLaunchCompleted() async {
    try {
      await _firstLaunchStore.markCompleted();
    } catch (_) {
      // Local persistence is best-effort; access must not be blocked by it.
    }
  }

  void _completeFirstLaunchAsNewUser() {
    HapticFeedback.selectionClick();
    unawaited(_markFirstLaunchCompleted());
    setState(() {
      _firstLaunchStep = _FirstLaunchStep.ready;
    });
  }

  void _openFirstLaunchRestore() {
    HapticFeedback.selectionClick();
    setState(() {
      _firstLaunchStep = _FirstLaunchStep.restore;
    });
  }

  void _backToFirstLaunchChoice() {
    setState(() {
      _firstLaunchStep = _FirstLaunchStep.choice;
    });
  }

  Future<void> _redeemFirstLaunchRestoreCode() async {
    if (_firstLaunchBusy) {
      return;
    }
    setState(() {
      _firstLaunchBusy = true;
    });
    final ok = await _redeemCodeInApp(
      _firstLaunchRestoreCodeController.text,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _firstLaunchBusy = false;
      if (ok) {
        unawaited(_markFirstLaunchCompleted());
        _firstLaunchStep = _FirstLaunchStep.ready;
      }
    });
  }

  Future<void> _showSupportHub() {
    HapticFeedback.selectionClick();
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (routeContext) {
          return _SupportChatScreen(
            appContext: widget.appContext,
            selectedRouteMode: _selectedRouteMode,
            statusLabel: _consumerProtectionStatusLabel(
              _runtimeSnapshot,
              busy: _runtimeBusy,
            ),
            supportTicketService: _supportTicketService,
            onOpenHandoff: _showSeedHandoff,
          );
        },
      ),
    );
  }

  Uri? _safeHandoffUri({
    required String label,
    required String value,
    required String cabinetUrl,
  }) {
    final trimmed = value.trim();
    switch (label) {
      case 'checkout':
      case 'cabinet':
      case 'download':
        return Uri.tryParse(trimmed);
      case 'redeem':
        if (trimmed.isEmpty) {
          return null;
        }
        return Uri.parse(cabinetUrl).replace(
          path: '/redeem',
          queryParameters: <String, String>{'code': trimmed},
        );
      case 'community':
      case 'support':
      case 'feedback':
        final handle = trimmed.replaceFirst('@', '');
        if (handle.isEmpty) {
          return null;
        }
        return Uri(
          scheme: 'tg',
          host: 'resolve',
          queryParameters: <String, String>{'domain': handle},
        );
      default:
        return Uri.tryParse(trimmed);
    }
  }

  Uri? _safeHandoffFallbackUri({
    required String label,
    required String value,
  }) {
    final trimmed = value.trim();
    switch (label) {
      case 'community':
      case 'support':
      case 'feedback':
        final handle = trimmed.replaceFirst('@', '');
        if (handle.isEmpty) {
          return null;
        }
        return Uri.https('t.me', '/$handle');
      default:
        return null;
    }
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
        _runtimeHeadline = 'Настройки обновлены с '
            '${Uri.parse(widget.appContext.apiBaseUrl).host}.';
      });
    }
    return payload;
  }

  Future<void> _toggleRuntime() async {
    if (_runtimeBusy) {
      setState(() {
        _runtimeHeadline = 'POKROV уже обновляется. Подождите немного.';
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
              'На этом устройстве еще нужно завершить подготовку.';
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
                  ? 'POKROV включен.'
                  : 'POKROV включен, но требует внимания.'
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
        normalized.contains('stopped') ||
        normalized.contains('не удалось') ||
        normalized.contains('отказ') ||
        normalized.contains('ошиб') ||
        normalized.contains('останов');
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
        onToggleRuntime: _toggleRuntime,
        onOpenLocations: () => _selectTab(SeedTab.locations),
        onOpenRules: () => _selectTab(SeedTab.rules),
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
          _selectRouteMode(mode);
        },
      ),
      _ProfileSection(
        appContext: widget.appContext,
        selectedRouteMode: _selectedRouteMode,
        hasProvisionedAccess: hasProvisionedAccess,
        onOpenHandoff: _showSeedHandoff,
        onOpenSupportHub: _showSupportHub,
        onCreateTelegramLink: _createTelegramLinkInApp,
        onCheckTelegramBonus: _checkTelegramBonusInApp,
        onClaimTelegramBonus: _claimTelegramBonusInApp,
        telegramBonusStatus: _telegramBonusStatus,
        telegramBonusBusy: _telegramBonusBusy,
        telegramBonusCanClaim: _telegramBonusCanClaim,
        telegramBonusError: _telegramBonusError,
        bonusSummary: _bonusSummary,
        bonusSummaryBusy: _bonusSummaryBusy,
        bonusSummaryError: _bonusSummaryError,
        onRefreshBonusSummary: () => _loadBonusSummary(force: true),
        runtimeSnapshot: _runtimeSnapshot,
        runtimeHeadline: _runtimeHeadline,
      ),
    ];

    final isDesktopShell = switch (widget.appContext.hostPlatform) {
      HostPlatform.windows || HostPlatform.macos => true,
      HostPlatform.android || HostPlatform.ios => false,
    };

    final disableAnimations = MediaQuery.maybeOf(context)?.disableAnimations ??
        WidgetsBinding.instance.platformDispatcher.accessibilityFeatures
            .disableAnimations;

    return _MotionScope(
      key: const ValueKey('motion-policy'),
      disableAnimations: disableAnimations,
      child: Scaffold(
        extendBody:
            _firstLaunchStep == _FirstLaunchStep.ready && !isDesktopShell,
        body: _SeedBackdrop(
          child: SafeArea(
            child: _firstLaunchStep == _FirstLaunchStep.ready
                ? isDesktopShell
                    ? _DesktopShell(
                        selectedIndex: _selectedIndex,
                        sections: sections,
                        onSelected: (index) {
                          _selectTab(SeedTab.values[index]);
                        },
                      )
                    : _MobileShell(
                        selectedIndex: _selectedIndex,
                        sections: sections,
                        onSelected: (index) {
                          _selectTab(SeedTab.values[index]);
                        },
                      )
                : _FirstLaunchGate(
                    appContext: widget.appContext,
                    step: _firstLaunchStep,
                    restoreCodeController: _firstLaunchRestoreCodeController,
                    busy: _firstLaunchBusy,
                    onNewUser: _completeFirstLaunchAsNewUser,
                    onReturningUser: _openFirstLaunchRestore,
                    onBack: _backToFirstLaunchChoice,
                    onRedeemCode: _redeemFirstLaunchRestoreCode,
                    onOpenTelegram: _createTelegramLinkInApp,
                    onOpenCabinet: () => _openCabinetWithHandoff(
                      widget.appContext.cabinetUrl,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _SeedContentList extends StatelessWidget {
  const _SeedContentList({
    required this.children,
    this.top = 12,
  });

  final List<Widget> children;
  final double top;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final sidePadding = constraints.maxWidth >= 980
            ? (constraints.maxWidth - 900) / 2
            : 24.0;
        return ListView(
          padding: EdgeInsets.fromLTRB(sidePadding, top, sidePadding, 160),
          children: children,
        );
      },
    );
  }
}

class _FirstLaunchGate extends StatelessWidget {
  const _FirstLaunchGate({
    required this.appContext,
    required this.step,
    required this.restoreCodeController,
    required this.busy,
    required this.onNewUser,
    required this.onReturningUser,
    required this.onBack,
    required this.onRedeemCode,
    required this.onOpenTelegram,
    required this.onOpenCabinet,
  });

  final SeedAppContext appContext;
  final _FirstLaunchStep step;
  final TextEditingController restoreCodeController;
  final bool busy;
  final VoidCallback onNewUser;
  final VoidCallback onReturningUser;
  final VoidCallback onBack;
  final VoidCallback onRedeemCode;
  final VoidCallback onOpenTelegram;
  final VoidCallback onOpenCabinet;

  @override
  Widget build(BuildContext context) {
    return _SeedContentList(
      top: 24,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: step == _FirstLaunchStep.restore
                ? _FirstLaunchRestoreScreen(
                    appContext: appContext,
                    codeController: restoreCodeController,
                    busy: busy,
                    onBack: onBack,
                    onRedeemCode: onRedeemCode,
                    onOpenTelegram: onOpenTelegram,
                    onOpenCabinet: onOpenCabinet,
                  )
                : _FirstLaunchChoiceScreen(
                    appContext: appContext,
                    onNewUser: onNewUser,
                    onReturningUser: onReturningUser,
                  ),
          ),
        ),
      ],
    );
  }
}

class _FirstLaunchChoiceScreen extends StatelessWidget {
  const _FirstLaunchChoiceScreen({
    required this.appContext,
    required this.onNewUser,
    required this.onReturningUser,
  });

  final SeedAppContext appContext;
  final VoidCallback onNewUser;
  final VoidCallback onReturningUser;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      key: const ValueKey('first-launch-choice-screen'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 18),
        const Center(child: _BrandLockup(markSize: 42, center: true)),
        const SizedBox(height: 28),
        Text(
          'Вы раньше пользовались POKROV?',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: _SeedPalette.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Выберите путь один раз. Доступ, бонусы и кабинет останутся в одном аккаунте.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: _SeedPalette.muted,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 22),
        _FirstLaunchOptionButton(
          key: const ValueKey('first-launch-new-user'),
          icon: Icons.auto_awesome_rounded,
          title: 'Я новый пользователь',
          subtitle:
              '${appContext.runtimeProfile.trialDays} дней доступа без карты',
          primary: true,
          onTap: onNewUser,
        ),
        const SizedBox(height: 12),
        _FirstLaunchOptionButton(
          key: const ValueKey('first-launch-returning-user'),
          icon: Icons.key_rounded,
          title: 'У меня уже есть доступ',
          subtitle: 'Код из Telegram, кабинета, письма или ключ активации',
          onTap: onReturningUser,
        ),
      ],
    );
  }
}

class _FirstLaunchRestoreScreen extends StatelessWidget {
  const _FirstLaunchRestoreScreen({
    required this.appContext,
    required this.codeController,
    required this.busy,
    required this.onBack,
    required this.onRedeemCode,
    required this.onOpenTelegram,
    required this.onOpenCabinet,
  });

  final SeedAppContext appContext;
  final TextEditingController codeController;
  final bool busy;
  final VoidCallback onBack;
  final VoidCallback onRedeemCode;
  final VoidCallback onOpenTelegram;
  final VoidCallback onOpenCabinet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      key: const ValueKey('first-launch-restore-screen'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            key: const ValueKey('first-launch-back-to-choice'),
            tooltip: 'Назад',
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: busy ? null : onBack,
          ),
        ),
        const Center(child: _BrandLockup(markSize: 36, center: true)),
        const SizedBox(height: 22),
        Text(
          'Восстановить доступ',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: _SeedPalette.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Введите одноразовый код из Telegram, кабинета, письма или ключ активации.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: _SeedPalette.muted,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          key: const ValueKey('first-launch-restore-code-field'),
          controller: codeController,
          enabled: !busy,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) {
            if (!busy) {
              onRedeemCode();
            }
          },
          decoration: InputDecoration(
            hintText: 'Код или ключ',
            prefixIcon: const Icon(Icons.key_rounded),
            filled: true,
            fillColor: _SeedPalette.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _SeedPalette.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _SeedPalette.line),
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          key: const ValueKey('first-launch-restore-redeem'),
          onPressed: busy ? null : onRedeemCode,
          icon: busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check_circle_outline_rounded),
          label: Text(busy ? 'Проверяем' : 'Восстановить'),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: [
            OutlinedButton.icon(
              key: const ValueKey('first-launch-open-telegram-code'),
              onPressed: busy ? null : onOpenTelegram,
              icon: const Icon(Icons.send_outlined),
              label: const Text('Код в Telegram'),
            ),
            OutlinedButton.icon(
              key: const ValueKey('first-launch-open-cabinet'),
              onPressed: busy ? null : onOpenCabinet,
              icon: const Icon(Icons.web_outlined),
              label: const Text('Открыть кабинет'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          key: const ValueKey('first-launch-manual-key-warning'),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _SeedPalette.warning.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _SeedPalette.warning.withValues(alpha: 0.24),
            ),
          ),
          child: Text(
            'Сырые ссылки подключения не доказывают аккаунт. Для привязки безопаснее одноразовый код; ручной ключ останется режимом восстановления.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: _SeedPalette.ink.withValues(alpha: 0.78),
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _FirstLaunchOptionButton extends StatelessWidget {
  const _FirstLaunchOptionButton({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: primary
          ? _SeedPalette.accent.withValues(alpha: 0.08)
          : _SeedPalette.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: primary
                  ? _SeedPalette.accent.withValues(alpha: 0.22)
                  : _SeedPalette.line,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _SeedPalette.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: _SeedPalette.accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: _SeedPalette.ink,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: _SeedPalette.muted,
                            height: 1.3,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.chevron_right_rounded,
                  color: _SeedPalette.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _DesktopShell extends StatelessWidget {
  const _DesktopShell({
    required this.selectedIndex,
    required this.sections,
    required this.onSelected,
  }) : super(key: const ValueKey('desktop-shell'));

  final int selectedIndex;
  final List<Widget> sections;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return _DesktopDrawerShell(
            selectedIndex: selectedIndex,
            sections: sections,
            onSelected: onSelected,
          );
        }
        final collapsed = constraints.maxWidth < 1180;
        return Row(
          children: [
            _DesktopSidebar(
              selectedIndex: selectedIndex,
              onSelected: onSelected,
              collapsed: collapsed,
            ),
            Expanded(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  border: Border(
                    left: BorderSide(color: _SeedPalette.line),
                  ),
                ),
                child: IndexedStack(
                  index: selectedIndex,
                  children: sections,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DesktopDrawerShell extends StatelessWidget {
  const _DesktopDrawerShell({
    required this.selectedIndex,
    required this.sections,
    required this.onSelected,
  }) : super(key: const ValueKey('desktop-drawer-shell'));

  final int selectedIndex;
  final List<Widget> sections;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      drawerScrimColor: _SeedPalette.ink.withValues(alpha: 0.18),
      drawer: Drawer(
        key: const ValueKey('desktop-sidebar-drawer'),
        backgroundColor: _SeedPalette.canvas,
        child: SafeArea(
          child: _DesktopSidebar(
            selectedIndex: selectedIndex,
            onSelected: (index) {
              Navigator.of(context).maybePop();
              onSelected(index);
            },
            collapsed: false,
            drawer: true,
          ),
        ),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 58,
            child: Row(
              children: [
                const SizedBox(width: 12),
                Builder(
                  builder: (buttonContext) {
                    return IconButton(
                      key: const ValueKey('desktop-sidebar-hamburger'),
                      tooltip: 'Меню',
                      icon: const Icon(Icons.menu_rounded),
                      onPressed: () => Scaffold.of(buttonContext).openDrawer(),
                    );
                  },
                ),
                const SizedBox(width: 8),
                const _BrandLockup(markSize: 28),
              ],
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: selectedIndex,
              children: sections,
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileShell extends StatelessWidget {
  const _MobileShell({
    required this.selectedIndex,
    required this.sections,
    required this.onSelected,
  }) : super(key: const ValueKey('mobile-shell'));

  final int selectedIndex;
  final List<Widget> sections;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: IndexedStack(
            index: selectedIndex,
            children: sections,
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _SeedPalette.surface.withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _SeedPalette.line),
              ),
              child: NavigationBar(
                height: 64,
                selectedIndex: selectedIndex,
                onDestinationSelected: onSelected,
                destinations: const [
                  NavigationDestination(
                    key: ValueKey('nav-protection'),
                    icon: Icon(Icons.flash_on_outlined),
                    selectedIcon: Icon(Icons.flash_on),
                    label: 'Защита',
                  ),
                  NavigationDestination(
                    key: ValueKey('nav-locations'),
                    icon: Icon(Icons.public_outlined),
                    selectedIcon: Icon(Icons.public),
                    label: 'Локации',
                  ),
                  NavigationDestination(
                    key: ValueKey('nav-rules'),
                    icon: Icon(Icons.rule_folder_outlined),
                    selectedIcon: Icon(Icons.rule_folder),
                    label: 'Правила',
                  ),
                  NavigationDestination(
                    key: ValueKey('nav-profile'),
                    icon: Icon(Icons.person_outline),
                    selectedIcon: Icon(Icons.person),
                    label: 'Аккаунт',
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DesktopSidebar extends StatelessWidget {
  _DesktopSidebar({
    required this.selectedIndex,
    required this.onSelected,
    required this.collapsed,
    this.drawer = false,
  }) : super(
          key: collapsed
              ? const ValueKey('desktop-icon-rail')
              : const ValueKey('desktop-sidebar-expanded'),
        );

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool collapsed;
  final bool drawer;

  @override
  Widget build(BuildContext context) {
    final width = collapsed ? 72.0 : 224.0;
    return AnimatedContainer(
      duration: _MotionScope.of(context).duration(_MotionTokens.standard),
      curve: _MotionTokens.ease,
      width: drawer ? 224 : width,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          collapsed ? 10 : 18,
          22,
          collapsed ? 10 : 18,
          18,
        ),
        child: Column(
          crossAxisAlignment:
              collapsed ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          children: [
            if (collapsed)
              const _BrandMark(size: 32)
            else ...[
              const _BrandLockup(markSize: 34),
              const SizedBox(height: 4),
              Text(
                '0.x beta',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: _SeedPalette.muted,
                    ),
              ),
            ],
            const SizedBox(height: 28),
            _SidebarItem(
              itemKey: const ValueKey('nav-protection'),
              index: 0,
              selectedIndex: selectedIndex,
              icon: Icons.flash_on_outlined,
              selectedIcon: Icons.flash_on,
              label: 'Защита',
              onSelected: onSelected,
              collapsed: collapsed,
            ),
            _SidebarItem(
              itemKey: const ValueKey('nav-locations'),
              index: 1,
              selectedIndex: selectedIndex,
              icon: Icons.public_outlined,
              selectedIcon: Icons.public,
              label: 'Локации',
              onSelected: onSelected,
              collapsed: collapsed,
            ),
            _SidebarItem(
              itemKey: const ValueKey('nav-rules'),
              index: 2,
              selectedIndex: selectedIndex,
              icon: Icons.rule_folder_outlined,
              selectedIcon: Icons.rule_folder,
              label: 'Правила',
              onSelected: onSelected,
              collapsed: collapsed,
            ),
            _SidebarItem(
              itemKey: const ValueKey('nav-profile'),
              index: 3,
              selectedIndex: selectedIndex,
              icon: Icons.person_outline,
              selectedIcon: Icons.person,
              label: 'Аккаунт',
              onSelected: onSelected,
              collapsed: collapsed,
            ),
            const Spacer(),
            if (collapsed)
              Icon(
                Icons.info_outline_rounded,
                color: _SeedPalette.muted,
                size: 20,
              )
            else
              _StatusPill(
                label: 'Beta',
                icon: Icons.info_outline_rounded,
                tone: _SectionTone.muted,
              ),
          ],
        ),
      ),
    );
  }
}

class _BrandLockup extends StatelessWidget {
  const _BrandLockup({
    this.markSize = 32,
    this.center = false,
  });

  final double markSize;
  final bool center;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      'POKROV',
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: _SeedPalette.ink,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
    );
    final children = [
      _BrandMark(size: markSize),
      const SizedBox(width: 10),
      label,
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment:
          center ? MainAxisAlignment.center : MainAxisAlignment.start,
      children: children,
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({
    required this.size,
    this.opacity = 1,
  });

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Image.asset(
        _pokrovBrandMarkAsset,
        key: const ValueKey('pokrov-brand-mark'),
        width: size,
        height: size,
        cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
        filterQuality: FilterQuality.medium,
        errorBuilder: (context, error, stackTrace) {
          return SizedBox(
            width: size,
            height: size,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _SeedPalette.accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  'P',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: _SeedPalette.accent,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.itemKey,
    required this.index,
    required this.selectedIndex,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.onSelected,
    this.collapsed = false,
  });

  final Key itemKey;
  final int index;
  final int selectedIndex;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final ValueChanged<int> onSelected;
  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    final selected = index == selectedIndex;
    final child = Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        key: itemKey,
        borderRadius: BorderRadius.circular(10),
        onTap: () => onSelected(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: EdgeInsets.symmetric(
            horizontal: collapsed ? 8 : 12,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: selected
                ? _SeedPalette.accent.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment:
                collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              if (!collapsed) ...[
                Container(
                  width: 2,
                  height: 20,
                  decoration: BoxDecoration(
                    color: selected ? _SeedPalette.accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(width: 9),
              ],
              Icon(
                selected ? selectedIcon : icon,
                size: 20,
                color: selected ? _SeedPalette.accent : _SeedPalette.muted,
              ),
              if (!collapsed) ...[
                const SizedBox(width: 10),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: selected ? _SeedPalette.ink : _SeedPalette.muted,
                        fontWeight:
                            selected ? FontWeight.w800 : FontWeight.w600,
                      ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    if (collapsed) {
      return Tooltip(message: label, child: child);
    }
    return child;
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
    required this.onToggleRuntime,
    required this.onOpenLocations,
    required this.onOpenRules,
  });

  final SeedAppContext appContext;
  final RouteMode selectedRouteMode;
  final RuntimeSnapshot? runtimeSnapshot;
  final String? runtimeHeadline;
  final bool runtimeBusy;
  final bool primaryConnectEnabled;
  final Future<void> Function() onToggleRuntime;
  final VoidCallback onOpenLocations;
  final VoidCallback onOpenRules;

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
    final isDesktop = switch (appContext.hostPlatform) {
      HostPlatform.windows || HostPlatform.macos => true,
      HostPlatform.android || HostPlatform.ios => false,
    };
    final statusColor = runtimeBusy
        ? _SeedPalette.warning
        : isRunning
            ? isHealthyRunning
                ? _SeedPalette.success
                : _SeedPalette.warning
            : _SeedPalette.muted;
    final actionLabel = runtimeBusy
        ? 'Готовим'
        : isRunning
            ? 'Отключить'
            : primaryActionEnabled
                ? 'Подключить'
                : 'Пока недоступно';
    final recoveryNotice = _motionRecoveryNotice(
      snapshot,
      headline: runtimeHeadline,
      busy: runtimeBusy,
    );

    return _SeedContentList(
      top: isDesktop ? 42 : 18,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isDesktop ? 560 : 460),
            child: _HomeStage(
              statusLabel: statusLabel,
              statusSummary: statusSummary,
              statusColor: statusColor,
              actionLabel: actionLabel,
              actionEnabled: primaryActionEnabled,
              running: isRunning,
              busy: runtimeBusy,
              degraded: isRunning && !isHealthyRunning,
              recoveryNotice: recoveryNotice,
              selectedRouteMode: selectedRouteMode,
              locationLabel: 'Авто',
              platformLabel: appContext.hostPlatform.label,
              onToggleRuntime: onToggleRuntime,
              onOpenLocations: onOpenLocations,
              onOpenRules: onOpenRules,
            ),
          ),
        ),
      ],
    );
  }
}

class _HomeStage extends StatefulWidget {
  const _HomeStage({
    required this.statusLabel,
    required this.statusSummary,
    required this.statusColor,
    required this.actionLabel,
    required this.actionEnabled,
    required this.running,
    required this.busy,
    required this.degraded,
    required this.recoveryNotice,
    required this.selectedRouteMode,
    required this.locationLabel,
    required this.platformLabel,
    required this.onToggleRuntime,
    required this.onOpenLocations,
    required this.onOpenRules,
  });

  final String statusLabel;
  final String statusSummary;
  final Color statusColor;
  final String actionLabel;
  final bool actionEnabled;
  final bool running;
  final bool busy;
  final bool degraded;
  final String? recoveryNotice;
  final RouteMode selectedRouteMode;
  final String locationLabel;
  final String platformLabel;
  final Future<void> Function() onToggleRuntime;
  final VoidCallback onOpenLocations;
  final VoidCallback onOpenRules;

  @override
  State<_HomeStage> createState() => _HomeStageState();
}

class _HomeStageState extends State<_HomeStage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _revealController;
  bool _revealStarted = false;

  @override
  void initState() {
    super.initState();
    _revealController = AnimationController(
      vsync: this,
      duration: _MotionTokens.homeReveal,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final motion = _MotionScope.of(context);
    if (motion.disableAnimations) {
      _revealController.value = 1;
      _revealStarted = true;
      return;
    }
    if (!_revealStarted) {
      _revealStarted = true;
      _revealController.forward();
    }
  }

  @override
  void dispose() {
    _revealController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      key: const ValueKey('home-boot-reveal'),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _HomeRevealSlice(
            controller: _revealController,
            begin: 0,
            end: 0.42,
            child: const _BrandLockup(markSize: 38, center: true),
          ),
          const SizedBox(height: 20),
          _HomeRevealSlice(
            controller: _revealController,
            begin: 0.18,
            end: 0.58,
            child: _StatusDotLabel(
              label: widget.statusLabel,
              color: widget.statusColor,
            ),
          ),
          if (widget.recoveryNotice != null) ...[
            const SizedBox(height: 12),
            _HomeRevealSlice(
              controller: _revealController,
              begin: 0.22,
              end: 0.62,
              child: _MotionRecoveryBanner(message: widget.recoveryNotice!),
            ),
          ],
          const SizedBox(height: 22),
          _HomeRevealSlice(
            controller: _revealController,
            begin: 0.28,
            end: 0.78,
            child: _ConnectOrbButton(
              actionLabel: widget.actionLabel,
              enabled: widget.actionEnabled,
              running: widget.running,
              degraded: widget.degraded,
              busy: widget.busy,
              onPressed: widget.actionEnabled ? widget.onToggleRuntime : null,
            ),
          ),
          const SizedBox(height: 22),
          _HomeRevealSlice(
            controller: _revealController,
            begin: 0.42,
            end: 1,
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                _HomeChip(
                  key: const ValueKey('home-location-chip'),
                  icon: Icons.public_rounded,
                  label: widget.locationLabel,
                  onTap: widget.onOpenLocations,
                ),
                _HomeChip(
                  key: const ValueKey('home-route-chip'),
                  icon: Icons.alt_route_rounded,
                  label: widget.selectedRouteMode.label,
                  onTap: widget.onOpenRules,
                ),
                _HomeChip(
                  icon: Icons.devices_rounded,
                  label: widget.platformLabel,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _HomeRevealSlice(
            controller: _revealController,
            begin: 0.46,
            end: 1,
            child: const _HomeWarpTile(),
          ),
          const SizedBox(height: 18),
          _HomeRevealSlice(
            controller: _revealController,
            begin: 0.48,
            end: 1,
            child: Text(
              widget.statusSummary,
              key: ValueKey(widget.statusSummary),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: _SeedPalette.muted,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeWarpTile extends StatelessWidget {
  const _HomeWarpTile();

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: const ValueKey('home-warp-tile'),
      borderRadius: BorderRadius.circular(14),
      onTap: () => _showInfoSheet(
        context,
        title: 'Расширенная приватность',
        lines: const [
          'WARP готовится и не активен в этой сборке.',
          'Когда режим будет проверен, POKROV покажет простой тумблер и честное предупреждение о скорости.',
        ],
      ),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 360),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _SeedPalette.surfaceMuted.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _SeedPalette.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _SeedPalette.accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.privacy_tip_outlined,
                size: 18,
                color: _SeedPalette.accent,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Расширенная приватность',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: _SeedPalette.ink,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'WARP · готовится',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: _SeedPalette.muted,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeRevealSlice extends StatelessWidget {
  const _HomeRevealSlice({
    required this.controller,
    required this.begin,
    required this.end,
    required this.child,
  });

  final AnimationController controller;
  final double begin;
  final double end;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (_MotionScope.of(context).disableAnimations) {
      return child;
    }
    return AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (context, child) {
        final progress = Curves.easeOutCubic.transform(
          ((controller.value - begin) / (end - begin)).clamp(0.0, 1.0),
        );
        return Opacity(
          opacity: progress,
          child: Transform.translate(
            offset: Offset(0, (1 - progress) * 12),
            child: child,
          ),
        );
      },
    );
  }
}

Widget _fadeSlideTransition(Widget child, Animation<double> animation) {
  final curved = CurvedAnimation(
    parent: animation,
    curve: _MotionTokens.ease,
  );
  return FadeTransition(
    opacity: curved,
    child: SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.12),
        end: Offset.zero,
      ).animate(curved),
      child: child,
    ),
  );
}

class _MotionRecoveryBanner extends StatelessWidget {
  const _MotionRecoveryBanner({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    final motion = _MotionScope.of(context);
    return AnimatedSwitcher(
      key: const ValueKey('motion-recovery-banner'),
      duration: motion.duration(_MotionTokens.standard),
      transitionBuilder: _fadeSlideTransition,
      child: Container(
        key: ValueKey(message),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: _SeedPalette.warning.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _SeedPalette.warning.withValues(alpha: 0.22),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 18,
              color: _SeedPalette.warning.withValues(alpha: 0.92),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _SeedPalette.ink.withValues(alpha: 0.78),
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusDotLabel extends StatelessWidget {
  const _StatusDotLabel({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final motion = _MotionScope.of(context);
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        AnimatedSwitcher(
          key: const ValueKey('home-status-switcher'),
          duration: motion.duration(_MotionTokens.short),
          transitionBuilder: _fadeSlideTransition,
          child: Text(
            label,
            key: ValueKey(label),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: _SeedPalette.ink,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
      ],
    );
  }
}

class _HomeChip extends StatefulWidget {
  const _HomeChip({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  State<_HomeChip> createState() => _HomeChipState();
}

class _HomeChipState extends State<_HomeChip> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final motion = _MotionScope.of(context);
    final interactive = widget.onTap != null;
    final scale = _pressed
        ? 0.97
        : _hovered && interactive
            ? 1.015
            : 1.0;
    return MouseRegion(
      cursor: interactive ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: interactive ? (_) => setState(() => _hovered = true) : null,
      onExit: interactive ? (_) => setState(() => _hovered = false) : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: interactive ? (_) => setState(() => _pressed = true) : null,
        onTapCancel:
            interactive ? () => setState(() => _pressed = false) : null,
        onTapUp: interactive ? (_) => setState(() => _pressed = false) : null,
        child: AnimatedScale(
          key: const ValueKey('home-chip-motion'),
          scale: scale,
          duration: motion.duration(_MotionTokens.quick),
          curve: _MotionTokens.ease,
          child: AnimatedContainer(
            duration: motion.duration(_MotionTokens.short),
            curve: _MotionTokens.ease,
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 13),
            decoration: BoxDecoration(
              color: _hovered && interactive
                  ? _SeedPalette.accent.withValues(alpha: 0.07)
                  : _SeedPalette.surface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: _hovered && interactive
                    ? _SeedPalette.accent.withValues(alpha: 0.20)
                    : _SeedPalette.line,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, size: 16, color: _SeedPalette.muted),
                const SizedBox(width: 8),
                AnimatedSwitcher(
                  duration: motion.duration(_MotionTokens.short),
                  child: Text(
                    widget.label,
                    key: ValueKey(widget.label),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: _SeedPalette.ink,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MotionSkeletonList extends StatelessWidget {
  const _MotionSkeletonList({
    super.key,
    this.rows = 4,
  });

  final int rows;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _SeedPalette.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _SeedPalette.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(rows, (index) {
            return Padding(
              padding: EdgeInsets.only(bottom: index == rows - 1 ? 0 : 14),
              child: Row(
                children: [
                  const _MotionSkeletonLine(width: 36, height: 36, radius: 18),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _MotionSkeletonLine(
                          width: index.isEven ? 168 : 132,
                          height: 12,
                        ),
                        const SizedBox(height: 8),
                        _MotionSkeletonLine(
                          width: index.isEven ? 232 : 188,
                          height: 10,
                          opacity: 0.08,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _AccountSkeletonSummary extends StatelessWidget {
  const _AccountSkeletonSummary();

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        key: const ValueKey('account-skeleton-summary'),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _SeedPalette.surface.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _SeedPalette.line),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _MotionSkeletonLine(width: 220, height: 12),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MotionSkeletonLine(height: 74, radius: 12),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _MotionSkeletonLine(height: 74, radius: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MotionSkeletonLine extends StatelessWidget {
  const _MotionSkeletonLine({
    this.width,
    required this.height,
    this.radius = 999,
    this.opacity = 0.12,
  });

  final double? width;
  final double height;
  final double radius;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('motion-skeleton-line'),
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: _SeedPalette.ink.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(radius),
      ),
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

    return _SeedContentList(
      children: [
        Text('Локации', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 12),
        _SectionCard(
          key: const ValueKey('locations-auto-section'),
          title: 'Автоматический выбор',
          tone:
              hasProvisionedAccess ? _SectionTone.neutral : _SectionTone.muted,
          lines: [
            hasProvisionedAccess
                ? 'Готово · ${selectedRouteMode.label}'
                : 'После подготовки',
          ],
          child: _SettingsRow(
            key: const ValueKey('locations-auto-help-action'),
            icon: Icons.info_outline_rounded,
            title: 'Как выбирается',
            value: 'Коротко',
            onTap: () => _showInfoSheet(
              context,
              title: 'Автоматический выбор',
              lines: [
                'POKROV выбирает доступный узел по вашему доступу.',
                'Базовый режим остается на ${appContext.runtimeProfile.freeTier.nodePoolLabel}.',
                'Технические детали остаются в диагностике поддержки.',
              ],
            ),
          ),
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
          const _MotionSkeletonList(
            key: ValueKey('locations-skeleton-list'),
            rows: 4,
          ),
          _SectionCard(
            title: 'Появится после подготовки',
            lines: [
              'Нажмите «Подключить» на главном экране.',
            ],
          ),
        ],
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
    required this.onOpenSupportHub,
    required this.onCreateTelegramLink,
    required this.onCheckTelegramBonus,
    required this.onClaimTelegramBonus,
    required this.telegramBonusStatus,
    required this.telegramBonusBusy,
    required this.telegramBonusCanClaim,
    required this.telegramBonusError,
    required this.bonusSummary,
    required this.bonusSummaryBusy,
    required this.bonusSummaryError,
    required this.onRefreshBonusSummary,
    required this.runtimeSnapshot,
    required this.runtimeHeadline,
  });

  final SeedAppContext appContext;
  final RouteMode selectedRouteMode;
  final bool hasProvisionedAccess;
  final void Function(String label, String value) onOpenHandoff;
  final VoidCallback onOpenSupportHub;
  final VoidCallback onCreateTelegramLink;
  final VoidCallback onCheckTelegramBonus;
  final VoidCallback onClaimTelegramBonus;
  final String telegramBonusStatus;
  final bool telegramBonusBusy;
  final bool telegramBonusCanClaim;
  final String? telegramBonusError;
  final AppFirstBonusSummary? bonusSummary;
  final bool bonusSummaryBusy;
  final String? bonusSummaryError;
  final VoidCallback onRefreshBonusSummary;
  final RuntimeSnapshot? runtimeSnapshot;
  final String? runtimeHeadline;

  List<String> _bonusSummaryLines() {
    final summary = bonusSummary;
    if (summary == null && bonusSummaryBusy) {
      return const ['Обновляем Telegram, рефералы и промокоды.'];
    }
    if (summary == null) {
      return const ['Telegram · рефералы · промокоды'];
    }
    final referralCode =
        summary.referralCode.isEmpty ? '' : ' · ${summary.referralCode}';
    return [
      'Telegram +${summary.channelBonusPremiumDays} дней · рефералы ${summary.referralCount}$referralCode',
    ];
  }

  String _referralSummaryValue(AppFirstBonusSummary summary) {
    if (summary.referralCode.isEmpty) {
      return '${summary.referralCount}';
    }
    return '${summary.referralCount} · ${summary.referralCode}';
  }

  IconData _bonusHistoryIcon(AppFirstBonusHistoryItem item) {
    switch (item.kind) {
      case 'telegram_channel':
        return Icons.send_outlined;
      case 'promo':
        return Icons.card_giftcard_outlined;
      case 'opening_bonus':
        return Icons.auto_awesome_outlined;
      default:
        return Icons.history_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusLabel = _consumerProtectionStatusLabel(runtimeSnapshot);
    final statusSummary = _consumerProtectionStatusSummary(
      runtimeSnapshot,
      headline: runtimeHeadline,
      hostPlatform: appContext.hostPlatform,
    );
    return _SeedContentList(
      top: 24,
      children: [
        Text('Аккаунт', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 12),
        KeyedSubtree(
          key: const ValueKey('profile-compact-account-layer'),
          child: Column(
            children: [
              _SectionCard(
                key: const ValueKey('profile-section-plan-access'),
                title: 'Доступ',
                tone: _SectionTone.accent,
                lines: [
                  '${appContext.accessLane.label} · $statusLabel',
                ],
                child: Column(
                  children: [
                    if (!hasProvisionedAccess)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: _AccountSkeletonSummary(),
                      ),
                    _SettingsRow(
                      icon: Icons.info_outline_rounded,
                      title: 'Статус',
                      value: statusLabel,
                      onTap: () => _showInfoSheet(
                        context,
                        title: 'Статус',
                        lines: [statusSummary],
                      ),
                    ),
                    _SettingsRow(
                      key: const ValueKey('profile-checkout-action'),
                      icon: Icons.shopping_bag_outlined,
                      title: 'Оплата',
                      value: 'Продлить',
                      onTap: () =>
                          onOpenHandoff('checkout', appContext.checkoutUrl),
                    ),
                    _SettingsRow(
                      key: const ValueKey('profile-open-cabinet-action'),
                      icon: Icons.web_outlined,
                      title: 'Кабинет',
                      value: 'Открыть',
                      onTap: () =>
                          onOpenHandoff('cabinet', appContext.cabinetUrl),
                    ),
                  ],
                ),
              ),
              _SectionCard(
                key: const ValueKey('profile-section-sync'),
                title: 'Код и бонус',
                tone: _SectionTone.reward,
                lines: [
                  'Код доступа или Telegram +${appContext.runtimeProfile.telegramBonusDays} дней.',
                ],
                child: Column(
                  children: [
                    _RedeemFields(
                      hintCode: appContext.redeemHint,
                      onRedeem: (code) => onOpenHandoff('redeem', code),
                    ),
                    const SizedBox(height: 10),
                    _SettingsRow(
                      key: const ValueKey('profile-telegram-link-action'),
                      icon: Icons.send_outlined,
                      title:
                          'Telegram +${appContext.runtimeProfile.telegramBonusDays} дней',
                      value:
                          telegramBonusBusy ? 'Проверяем' : telegramBonusStatus,
                      onTap: telegramBonusBusy ? null : onCreateTelegramLink,
                    ),
                    _SettingsRow(
                      key: const ValueKey('profile-telegram-check-action'),
                      icon: Icons.fact_check_outlined,
                      title: 'Проверить подписку',
                      value: 'Канал',
                      onTap: telegramBonusBusy ? null : onCheckTelegramBonus,
                    ),
                    _SettingsRow(
                      key: const ValueKey('profile-telegram-claim-action'),
                      icon: Icons.add_circle_outline_rounded,
                      title:
                          'Получить +${appContext.runtimeProfile.telegramBonusDays} дней',
                      value: telegramBonusCanClaim
                          ? 'Активировать'
                          : 'После проверки',
                      onTap: telegramBonusBusy ? null : onClaimTelegramBonus,
                    ),
                    if ((telegramBonusError ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          telegramBonusError!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                            height: 1.3,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              _SectionCard(
                key: const ValueKey('profile-section-bonus-summary'),
                title: 'Сводка',
                tone: _SectionTone.reward,
                lines: _bonusSummaryLines(),
                child: Column(
                  children: [
                    _SettingsRow(
                      key: const ValueKey('profile-bonus-summary-refresh'),
                      icon: Icons.refresh_rounded,
                      title: 'Обновить бонусы',
                      value: bonusSummaryBusy ? 'Секунду' : 'Сводка',
                      onTap: bonusSummaryBusy ? null : onRefreshBonusSummary,
                    ),
                    if (bonusSummary != null) ...[
                      _SettingsRow(
                        key: const ValueKey(
                          'profile-bonus-summary-telegram',
                        ),
                        icon: Icons.send_outlined,
                        title: 'Telegram',
                        value: bonusSummary!.channelBonusClaimed
                            ? '+${bonusSummary!.channelBonusPremiumDays} дней активированы'
                            : '+${bonusSummary!.channelBonusPremiumDays} дней доступны',
                      ),
                      _SettingsRow(
                        key: const ValueKey(
                          'profile-bonus-summary-referral',
                        ),
                        icon: Icons.group_add_outlined,
                        title: 'Рефералы',
                        value: _referralSummaryValue(bonusSummary!),
                      ),
                      _SettingsRow(
                        key: const ValueKey('profile-bonus-summary-promo'),
                        icon: Icons.card_giftcard_outlined,
                        title: 'Промокод',
                        value: 'Через код',
                      ),
                      for (final entry in bonusSummary!.historyItems.indexed)
                        _SettingsRow(
                          key: ValueKey(
                            'profile-bonus-history-item-${entry.$1}',
                          ),
                          icon: _bonusHistoryIcon(entry.$2),
                          title: entry.$2.title,
                          value: entry.$2.compactValue,
                        ),
                    ],
                    if ((bonusSummaryError ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          bonusSummaryError!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                            height: 1.3,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              _SectionCard(
                key: const ValueKey('profile-section-app'),
                title: 'Устройство и помощь',
                lines: [
                  '${appContext.hostPlatform.label} · ${selectedRouteMode.label}'
                ],
                child: Column(
                  children: [
                    _SettingsRow(
                      icon: Icons.devices_outlined,
                      title: 'Устройство',
                      value: appContext.hostPlatform.label,
                    ),
                    _SettingsRow(
                      icon: Icons.alt_route_rounded,
                      title: 'Режим',
                      value: selectedRouteMode.label,
                    ),
                    _SettingsRow(
                      icon: Icons.download_outlined,
                      title: 'Загрузки',
                      value: appContext.hostPlatform.label,
                      onTap: () => onOpenHandoff(
                        'download',
                        Uri.parse(appContext.cabinetUrl)
                            .replace(path: '/downloads')
                            .toString(),
                      ),
                    ),
                    _SettingsRow(
                      icon: Icons.alternate_email_rounded,
                      title: 'Email',
                      value: 'Кабинет',
                      onTap: () => onOpenHandoff(
                        'download',
                        Uri.parse(appContext.cabinetUrl)
                            .replace(path: '/account/email')
                            .toString(),
                      ),
                    ),
                    _SettingsRow(
                      key: const ValueKey('profile-section-support'),
                      icon: Icons.support_agent_rounded,
                      title: 'Написать',
                      value: 'Поддержка',
                      onTap: onOpenSupportHub,
                    ),
                    _SettingsRow(
                      key: const ValueKey('profile-section-advanced'),
                      icon: Icons.tune_rounded,
                      title: 'Расширенные',
                      value: 'Открыть',
                      onTap: () => _showAdvancedSettingsSheet(context),
                    ),
                  ],
                ),
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
    final selectedAppsActive = routeChoices.contains(RouteMode.selectedApps);
    final selectedAppsStaged =
        appContext.bootstrapContract.supportsSelectedAppsMode &&
            !selectedAppsActive;

    return _SeedContentList(
      top: 24,
      children: [
        Text('Правила', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Режим',
          tone: _SectionTone.accent,
          lines: ['Сейчас · ${selectedRouteMode.label}'],
          child: Column(
            children: <Widget>[
              ...routeChoices.map(
                (mode) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _RouteModeCard(
                    mode: mode,
                    selected: selectedRouteMode == mode,
                    onTap: () => onRouteModeSelected(mode),
                  ),
                ),
              ),
              _SettingsRow(
                key: const ValueKey('rules-mode-help-action'),
                icon: Icons.info_outline_rounded,
                title: 'Как выбрать',
                value: 'Коротко',
                onTap: () => _showInfoSheet(
                  context,
                  title: 'Режимы',
                  lines: [
                    '${RouteMode.allExceptRu.label}: ${RouteMode.allExceptRu.summary}',
                    '${RouteMode.fullTunnel.label}: ${RouteMode.fullTunnel.summary}',
                    selectedAppsActive
                        ? '${RouteMode.selectedApps.label}: ${RouteMode.selectedApps.summary}'
                        : selectedAppsStaged
                            ? '${RouteMode.selectedApps.label}: появится после системной проверки.'
                            : '${RouteMode.selectedApps.label}: недоступно на ${appContext.hostPlatform.label}.',
                  ],
                ),
              ),
            ],
          ),
        ),
        _SectionCard(
          title: 'Без POKROV',
          lines: const ['5 категорий'],
          child: const Column(
            children: [
              _PresetRow(
                icon: Icons.account_balance_outlined,
                title: 'Российские банки',
                subtitle: 'Карты, платежи и приложения банков идут напрямую.',
                enabled: true,
              ),
              _PresetRow(
                icon: Icons.verified_user_outlined,
                title: 'Госуслуги',
                subtitle: 'Государственные сервисы остаются без POKROV.',
                enabled: true,
              ),
              _PresetRow(
                icon: Icons.shopping_bag_outlined,
                title: 'Маркетплейсы',
                subtitle: 'Покупки и доставка работают привычным маршрутом.',
                enabled: true,
              ),
              _PresetRow(
                icon: Icons.forum_outlined,
                title: 'Мессенджеры',
                subtitle: 'Категория готовится к проверке правил.',
                enabled: false,
              ),
              _PresetRow(
                icon: Icons.add_box_outlined,
                title: 'Добавить приложение',
                subtitle: 'Выбор приложений появится после системной проверки.',
                enabled: false,
              ),
            ],
          ),
        ),
        if (selectedAppsActive || selectedAppsStaged)
          _SectionCard(
            key: const ValueKey('rules-section-selected-apps'),
            title: 'Приложения',
            lines: const ['Выбор готовится.'],
            child: _SettingsRow(
              icon: Icons.add_box_outlined,
              title: 'Добавить',
              value: 'Скоро',
              onTap: () => _showInfoSheet(
                context,
                title: 'Выбранные приложения',
                lines: const [
                  'Интерфейс выбора появится после системной проверки.',
                  'Текущий режим уже можно выбрать здесь.',
                ],
              ),
            ),
          ),
      ],
    );
  }
}

void _showAdvancedSettingsSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: _SeedPalette.surface,
    builder: (context) {
      return const SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(18, 0, 18, 24),
          child: _AdvancedSettingsCard(
            key: ValueKey('profile-advanced-settings-sheet'),
          ),
        ),
      );
    },
  );
}

class _RedeemFields extends StatefulWidget {
  const _RedeemFields({
    required this.hintCode,
    required this.onRedeem,
  });

  final String hintCode;
  final ValueChanged<String> onRedeem;

  @override
  State<_RedeemFields> createState() => _RedeemFieldsState();
}

class _RedeemFieldsState extends State<_RedeemFields> {
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const ValueKey('profile-redeem-code-field'),
          controller: _controller,
          decoration: const InputDecoration(
            labelText: 'Код активации',
            hintText: 'POKROV-XXXX-XXXX',
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          key: const ValueKey('profile-redeem-submit'),
          onPressed: () => widget.onRedeem(_controller.text.trim()),
          icon: const Icon(Icons.verified_outlined),
          label: const Text('Ввести код'),
        ),
      ],
    );
  }
}

class _AdvancedSettingsCard extends StatefulWidget {
  const _AdvancedSettingsCard({super.key});

  @override
  State<_AdvancedSettingsCard> createState() => _AdvancedSettingsCardState();
}

class _AdvancedSettingsCardState extends State<_AdvancedSettingsCard> {
  bool _accepted = false;
  bool _opened = false;

  @override
  Widget build(BuildContext context) {
    if (_opened) {
      return _SectionCard(
        title: 'Расширенные',
        lines: const [
          'Ручной режим открыт.',
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            _KeyValueLine(
              label: 'Свой ключ или подписка',
              value: 'Только для восстановления',
            ),
            _KeyValueLine(
              label: 'Совместимый режим',
              value: 'По просьбе поддержки',
            ),
            _KeyValueLine(
              label: 'Сброс',
              value: 'Всегда к рекомендованным настройкам',
            ),
          ],
        ),
      );
    }

    return _SectionCard(
      title: 'Расширенные',
      tone: _SectionTone.muted,
      lines: const [
        'Только для восстановления и поддержки.',
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _accepted,
            onChanged: (value) {
              setState(() {
                _accepted = value ?? false;
              });
            },
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text(
              'Я беру ответственность за ручные настройки.',
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _accepted = false;
                  });
                },
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: _accepted
                    ? () {
                        setState(() {
                          _opened = true;
                        });
                      }
                    : null,
                child: const Text('Да, открыть'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PresetRow extends StatelessWidget {
  const _PresetRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: enabled
                  ? _SeedPalette.accent.withValues(alpha: 0.1)
                  : _SeedPalette.ink.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: enabled
                  ? _SeedPalette.accent
                  : _SeedPalette.ink.withValues(alpha: 0.38),
              size: 20,
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
                        fontWeight: FontWeight.w800,
                        color: _SeedPalette.ink,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _SeedPalette.ink.withValues(alpha: 0.68),
                        height: 1.25,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Icon(
            enabled ? Icons.check_circle_rounded : Icons.lock_clock_outlined,
            color: enabled
                ? _SeedPalette.accent
                : _SeedPalette.ink.withValues(alpha: 0.34),
            size: 20,
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
      key: ValueKey('location-card-${location.code}'),
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _SeedPalette.line),
        boxShadow: [
          BoxShadow(
            color: _SeedPalette.ink.withValues(alpha: 0.05),
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
              color: _SeedPalette.accent.withValues(alpha: 0.1),
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
                              color: _SeedPalette.ink.withValues(alpha: 0.72),
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
                      label: appContext.runtimeProfile.freeTier.nodePoolLabel,
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

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
        final leading = Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: _SeedPalette.accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 18, color: _SeedPalette.accent),
        );
        final titleText = Text(
          title,
          maxLines: compact ? 2 : 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: _SeedPalette.ink,
                fontWeight: FontWeight.w700,
              ),
        );
        final valueText = Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: compact ? TextAlign.left : TextAlign.right,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: _SeedPalette.ink.withValues(alpha: 0.62),
                fontWeight: FontWeight.w700,
              ),
        );
        final chevron = onTap == null
            ? null
            : Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: _SeedPalette.ink.withValues(alpha: 0.38),
              );

        if (compact) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                leading,
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      titleText,
                      const SizedBox(height: 3),
                      valueText,
                    ],
                  ),
                ),
                if (chevron != null) ...[
                  const SizedBox(width: 8),
                  chevron,
                ],
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 12),
              Expanded(child: titleText),
              const SizedBox(width: 12),
              Flexible(child: valueText),
              if (chevron != null) ...[
                const SizedBox(width: 8),
                chevron,
              ],
            ],
          ),
        );
      },
    );

    if (onTap == null) {
      return row;
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: row,
    );
  }
}

void _showInfoSheet(
  BuildContext context, {
  required String title,
  required List<String> lines,
}) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: _SeedPalette.surface,
    builder: (context) => _InfoSheet(title: title, lines: lines),
  );
}

class _InfoSheet extends StatelessWidget {
  const _InfoSheet({
    required this.title,
    required this.lines,
  });

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: _SeedPalette.ink,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            ...lines.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  line,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: _SeedPalette.ink.withValues(alpha: 0.72),
                        height: 1.35,
                      ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportChatScreen extends StatefulWidget {
  const _SupportChatScreen({
    required this.appContext,
    required this.selectedRouteMode,
    required this.statusLabel,
    required this.supportTicketService,
    required this.onOpenHandoff,
  });

  final SeedAppContext appContext;
  final RouteMode selectedRouteMode;
  final String statusLabel;
  final SupportTicketService supportTicketService;
  final void Function(String label, String value) onOpenHandoff;

  @override
  State<_SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<_SupportChatScreen> {
  late final TextEditingController _composer;
  bool _sending = false;
  bool _loadingThread = true;
  int? _ticketId;
  String _threadStatus = 'AI помощник';
  String? _threadError;
  List<_SupportChatMessage> _messages = _supportGreetingMessages();

  @override
  void initState() {
    super.initState();
    _composer = TextEditingController();
    unawaited(_loadInitialThread());
  }

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  Future<void> _loadInitialThread() async {
    setState(() {
      _loadingThread = true;
      _threadError = null;
    });

    try {
      final tickets = await widget.supportTicketService.listTickets(
        hostPlatform: widget.appContext.hostPlatform,
        limit: 5,
      );
      SupportTicketThread? selected;
      for (final ticket in tickets) {
        if (!ticket.isClosed) {
          selected = ticket;
          break;
        }
      }
      selected ??= tickets.isEmpty ? null : tickets.first;

      if (selected == null) {
        if (!mounted) {
          return;
        }
        setState(() {
          _ticketId = null;
          _loadingThread = false;
          _messages = _supportGreetingMessages();
          _threadStatus = 'AI помощник';
        });
        return;
      }

      final thread = await widget.supportTicketService.getTicket(
        hostPlatform: widget.appContext.hostPlatform,
        ticketId: selected.id,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingThread = false;
        _applyThread(thread);
      });
    } on SupportTicketFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingThread = false;
        _threadError = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingThread = false;
        _threadError = 'Не удалось загрузить историю поддержки.';
      });
    }
  }

  void _applyThread(SupportTicketThread thread) {
    _ticketId = thread.id;
    _threadStatus =
        thread.statusTitle.isEmpty ? thread.status : thread.statusTitle;
    final nextMessages = _messagesFromThread(thread);
    _messages =
        nextMessages.isEmpty ? _supportGreetingMessages() : nextMessages;
  }

  Future<void> _sendMessage() async {
    final text = _composer.text.trim();
    if (text.isEmpty || _sending || _loadingThread) {
      return;
    }
    setState(() {
      _messages
          .add(_SupportChatMessage(role: _SupportChatRole.user, body: text));
      _composer.clear();
      _sending = true;
    });

    try {
      final activeTicketId = _ticketId;
      if (activeTicketId != null) {
        final thread = await widget.supportTicketService.sendMessage(
          hostPlatform: widget.appContext.hostPlatform,
          ticketId: activeTicketId,
          body: text,
        );
        if (!mounted) {
          return;
        }
        setState(() {
          _sending = false;
          _applyThread(thread);
        });
        return;
      }

      final receipt = await widget.supportTicketService.createTicket(
        hostPlatform: widget.appContext.hostPlatform,
        routeMode: widget.selectedRouteMode,
        statusLabel: widget.statusLabel,
        subject: 'Обращение из приложения POKROV',
        body: text,
        diagnostics: _supportDiagnostics(),
      );
      _ticketId = receipt.ticketId;
      if (!mounted) {
        return;
      }
      setState(() {
        _sending = false;
        _messages.add(
          _SupportChatMessage(
            role: _SupportChatRole.assistant,
            label: 'Поддержка',
            body:
                'Обращение #${receipt.ticketId} создано. Ответ появится здесь; Telegram остается запасным каналом.',
          ),
        );
      });
      try {
        final thread = await widget.supportTicketService.getTicket(
          hostPlatform: widget.appContext.hostPlatform,
          ticketId: receipt.ticketId,
        );
        if (!mounted || thread.messages.isEmpty) {
          return;
        }
        setState(() {
          _applyThread(thread);
        });
      } catch (_) {
        // Keep the local confirmation when the immediate refresh is unavailable.
      }
    } on SupportTicketFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _sending = false;
        _messages.add(
          _SupportChatMessage(
            role: _SupportChatRole.assistant,
            body:
                'Не удалось отправить обращение: ${error.message}. Откройте Telegram сверху или попробуйте еще раз.',
          ),
        );
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _sending = false;
        _messages.add(
          const _SupportChatMessage(
            role: _SupportChatRole.assistant,
            body:
                'Не удалось отправить обращение. Откройте Telegram сверху или попробуйте еще раз.',
          ),
        );
      });
    }
  }

  Map<String, Object?> _supportDiagnostics() {
    return <String, Object?>{
      'app_version': '0.2.0-beta.1',
      'platform': widget.appContext.hostPlatform.name,
      'route_mode': widget.selectedRouteMode.name,
      'connection_status': widget.statusLabel,
      'selected_region': 'POKROV auto',
    };
  }

  List<_SupportChatMessage> _messagesFromThread(SupportTicketThread thread) {
    final messages = <_SupportChatMessage>[];
    for (final message in thread.messages) {
      final body = message.body.trim();
      if (body.isEmpty) {
        continue;
      }
      final role = _supportRoleFromSender(message.senderRole);
      messages.add(
        _SupportChatMessage(
          role: role,
          label: _supportLabelForRole(role),
          body: body,
        ),
      );
    }
    return messages;
  }

  _SupportChatRole _supportRoleFromSender(String senderRole) {
    final role = senderRole.toLowerCase();
    if (role == 'user') {
      return _SupportChatRole.user;
    }
    if (role == 'admin' || role == 'operator' || role == 'support') {
      return _SupportChatRole.operator;
    }
    return _SupportChatRole.assistant;
  }

  String _supportLabelForRole(_SupportChatRole role) {
    return switch (role) {
      _SupportChatRole.user => '',
      _SupportChatRole.operator => 'Поддержка',
      _SupportChatRole.assistant => 'AI помощник',
    };
  }

  void _showDiagnosticsPreview() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: _SeedPalette.surface,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            key: const ValueKey('support-diagnostics-preview'),
            padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Диагностика',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: _SeedPalette.ink,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 12),
                _KeyValueLine(
                  label: 'Устройство',
                  value: widget.appContext.hostPlatform.label,
                ),
                _KeyValueLine(
                  label: 'Режим',
                  value: widget.selectedRouteMode.label,
                ),
                _KeyValueLine(
                  label: 'Статус',
                  value: widget.statusLabel,
                ),
                _KeyValueLine(
                  label: 'Версия',
                  value: '0.2.0-beta.1',
                ),
                const SizedBox(height: 10),
                Text(
                  'Сырые ключи, ссылки, адреса серверов и конфиги не отправляются.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _SeedPalette.muted,
                        height: 1.3,
                      ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    key: const ValueKey('support-diagnostics-close'),
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: const Text('Готово'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('support-chat-screen'),
      backgroundColor: _SeedPalette.canvas,
      appBar: AppBar(
        title: const Text('Поддержка'),
        actions: [
          TextButton(
            key: const ValueKey('support-chat-telegram-fallback'),
            onPressed: () => widget.onOpenHandoff(
              'support',
              widget.appContext.supportSnapshot.supportBot,
            ),
            child: Text(widget.appContext.supportSnapshot.supportBot),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
              child: _SupportChatHeader(
                status: _loadingThread
                    ? 'Загружаем'
                    : _sending
                        ? 'Отправляем'
                        : _threadStatus,
                details:
                    '${widget.appContext.hostPlatform.label} · ${widget.selectedRouteMode.label} · ${widget.statusLabel}',
              ),
            ),
            if (_threadError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                child: _SupportChatNotice(
                  body: _threadError!,
                  onRetry: () => unawaited(_loadInitialThread()),
                ),
              ),
            Expanded(
              child: _loadingThread
                  ? const Center(
                      child: CircularProgressIndicator(
                        key: ValueKey('support-chat-loading'),
                      ),
                    )
                  : ListView.builder(
                      key: const ValueKey('support-chat-message-list'),
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        return _SupportChatBubble(message: _messages[index]);
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _SeedPalette.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _SeedPalette.line),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      IconButton(
                        key: const ValueKey('support-attach-diagnostics'),
                        tooltip: 'Диагностика',
                        icon: const Icon(Icons.attach_file_rounded),
                        onPressed: _showDiagnosticsPreview,
                      ),
                      Expanded(
                        child: TextField(
                          key: const ValueKey('support-chat-composer'),
                          controller: _composer,
                          minLines: 1,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            hintText: 'Напишите сообщение',
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          onSubmitted: (_) => unawaited(_sendMessage()),
                        ),
                      ),
                      IconButton(
                        key: const ValueKey('support-chat-send'),
                        tooltip: 'Отправить',
                        icon: _sending
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send_rounded),
                        onPressed: (_sending || _loadingThread)
                            ? null
                            : () => unawaited(_sendMessage()),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _SupportChatRole {
  user,
  assistant,
  operator,
}

class _SupportChatMessage {
  const _SupportChatMessage({
    required this.role,
    required this.body,
    this.label = '',
  });

  final _SupportChatRole role;
  final String body;
  final String label;
}

List<_SupportChatMessage> _supportGreetingMessages() {
  return <_SupportChatMessage>[
    _SupportChatMessage(
      role: _SupportChatRole.assistant,
      label: 'AI помощник',
      body:
          'Напишите, что случилось. POKROV приложит безопасный контекст и покажет ответ в этом чате.',
    ),
  ];
}

class _SupportChatHeader extends StatelessWidget {
  const _SupportChatHeader({
    required this.status,
    required this.details,
  });

  final String status;
  final String details;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _SeedPalette.accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _SeedPalette.accent.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _SeedPalette.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.support_agent_rounded,
              color: _SeedPalette.accent,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: _SeedPalette.ink,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  details,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _SeedPalette.muted,
                        height: 1.25,
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

class _SupportChatNotice extends StatelessWidget {
  const _SupportChatNotice({
    required this.body,
    required this.onRetry,
  });

  final String body;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _SeedPalette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _SeedPalette.line),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Row(
          children: [
            const Icon(
              Icons.info_outline_rounded,
              color: _SeedPalette.muted,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                body,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _SeedPalette.muted,
                      height: 1.25,
                    ),
              ),
            ),
            TextButton(
              onPressed: onRetry,
              child: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportChatBubble extends StatelessWidget {
  const _SupportChatBubble({
    required this.message,
  });

  final _SupportChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == _SupportChatRole.user;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isUser ? _SeedPalette.accent : _SeedPalette.surface,
          borderRadius: BorderRadius.circular(16),
          border: isUser ? null : Border.all(color: _SeedPalette.line),
        ),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isUser && message.label.isNotEmpty) ...[
              Text(
                message.label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: _SeedPalette.muted,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 4),
            ],
            Text(
              message.body,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isUser ? Colors.white : _SeedPalette.ink,
                    height: 1.3,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

String _routeModeCompactSubtitle(RouteMode mode) {
  return switch (mode) {
    RouteMode.allExceptRu => 'РФ напрямую',
    RouteMode.fullTunnel => 'Все через POKROV',
    RouteMode.selectedApps => 'Только выбранные',
  };
}

String _consumerProtectionStatusLabel(
  RuntimeSnapshot? snapshot, {
  bool busy = false,
}) {
  if (busy) {
    return 'Готовим';
  }
  if (snapshot == null) {
    return 'Проверяем статус';
  }
  if (snapshot.phase == RuntimePhase.running) {
    return snapshot.isCleanlyHealthy ? 'Включено' : 'Нужно внимание';
  }
  if (snapshot.phase == RuntimePhase.artifactMissing) {
    return 'Недоступно';
  }
  if ((snapshot.stagedConfigPath ?? '').isNotEmpty) {
    return 'Готово к подключению';
  }
  return 'Готово';
}

String? _motionRecoveryNotice(
  RuntimeSnapshot? snapshot, {
  required String? headline,
  required bool busy,
}) {
  if (busy) {
    return null;
  }
  final text = (headline ?? '').trim();
  if (text.isEmpty) {
    return null;
  }
  final normalized = text.toLowerCase();
  final looksRecoverable = normalized.contains('не смог') ||
      normalized.contains('не удалось') ||
      normalized.contains('ошиб') ||
      normalized.contains('отказ') ||
      normalized.contains('failed') ||
      normalized.contains('denied') ||
      normalized.contains('error') ||
      normalized.contains('недоступ');
  if (looksRecoverable) {
    return text;
  }
  if (snapshot != null &&
      snapshot.phase != RuntimePhase.running &&
      normalized.contains('подготов')) {
    return text;
  }
  if (snapshot != null && snapshot.phase != RuntimePhase.running) {
    return text;
  }
  return null;
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
        ? 'POKROV работает на этом устройстве.'
        : 'POKROV включен, но заметил состояние, которое стоит проверить.';
  }
  if (snapshot.phase == RuntimePhase.artifactMissing) {
    return 'Устройство еще завершает подготовку перед подключением.';
  }
  if ((snapshot.stagedConfigPath ?? '').isNotEmpty) {
    return 'Все готово. Нажмите главную кнопку, чтобы подключиться.';
  }
  return 'POKROV готовит подключение в фоне, чтобы на первом экране осталась одна понятная кнопка.';
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    super.key,
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
          background: _SeedPalette.accent.withValues(alpha: 0.06),
          border: _SeedPalette.accent.withValues(alpha: 0.14),
        ),
      _SectionTone.muted => (
          background: _SeedPalette.surfaceMuted,
          border: _SeedPalette.line,
        ),
      _SectionTone.neutral => (
          background: _SeedPalette.surface,
          border: _SeedPalette.line,
        ),
      _SectionTone.reward => (
          background: const Color(0xFFFFF8E1),
          border: Color(0x33B99745),
        ),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            if (lines.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...lines.map(
                (line) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    line,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: _SeedPalette.ink.withValues(alpha: 0.76),
                          height: 1.32,
                        ),
                  ),
                ),
              ),
            ],
            if (child != null) ...[
              SizedBox(height: lines.isEmpty ? 12 : 14),
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
          child,
        ],
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
      _SectionTone.accent => _SeedPalette.accent.withValues(alpha: 0.12),
      _SectionTone.muted => _SeedPalette.surfaceMuted.withValues(alpha: 0.92),
      _SectionTone.neutral => Colors.white.withValues(alpha: 0.86),
      _SectionTone.reward => const Color(0xFFFFF3CF),
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

class _ConnectOrbButton extends StatefulWidget {
  const _ConnectOrbButton({
    required this.actionLabel,
    required this.enabled,
    required this.running,
    required this.degraded,
    required this.busy,
    required this.onPressed,
  });

  final String actionLabel;
  final bool enabled;
  final bool running;
  final bool degraded;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  State<_ConnectOrbButton> createState() => _ConnectOrbButtonState();
}

class _ConnectOrbButtonState extends State<_ConnectOrbButton>
    with TickerProviderStateMixin {
  late final AnimationController _breathController;
  late final AnimationController _sweepController;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _sweepController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1250),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncControllers();
  }

  @override
  void didUpdateWidget(covariant _ConnectOrbButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled ||
        oldWidget.running != widget.running ||
        oldWidget.degraded != widget.degraded ||
        oldWidget.busy != widget.busy) {
      _breathController.reset();
      _sweepController.reset();
    }
    _syncControllers();
  }

  @override
  void dispose() {
    _breathController.dispose();
    _sweepController.dispose();
    super.dispose();
  }

  void _syncControllers() {
    final disableAnimations = MediaQuery.maybeOf(context)?.disableAnimations ??
        WidgetsBinding.instance.platformDispatcher.accessibilityFeatures
            .disableAnimations;
    final canAnimate = widget.enabled && !disableAnimations;

    if (canAnimate && !widget.busy) {
      if (!_breathController.isAnimating &&
          _breathController.status != AnimationStatus.completed) {
        _breathController.forward();
      }
    } else {
      _breathController.stop();
      _breathController.value = 0;
    }

    if (canAnimate && widget.busy) {
      if (!_sweepController.isAnimating &&
          _sweepController.status != AnimationStatus.completed) {
        _sweepController.forward(from: 0);
      }
    } else {
      _sweepController.stop();
      _sweepController.value = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final motion = _MotionScope.of(context);
    final accent = widget.degraded
        ? const Color(0xFFB5673A)
        : widget.running
            ? _SeedPalette.accentBright
            : _SeedPalette.accent;
    final disableAnimations = MediaQuery.maybeOf(context)?.disableAnimations ??
        WidgetsBinding.instance.platformDispatcher.accessibilityFeatures
            .disableAnimations;
    final diameter = switch (MediaQuery.sizeOf(context).width) {
      >= 720 => 210.0,
      _ => 182.0,
    };
    final labelColor = widget.enabled ? _SeedPalette.ink : _SeedPalette.muted;
    final markOpacity = !widget.enabled
        ? 0.34
        : widget.degraded
            ? 0.62
            : widget.busy
                ? 0.72
                : 1.0;

    return Semantics(
      key: const ValueKey('primary-connect-action'),
      button: true,
      enabled: widget.enabled,
      label: widget.actionLabel,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MouseRegion(
            cursor: widget.onPressed == null
                ? SystemMouseCursors.basic
                : SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onPressed == null
                  ? null
                  : () {
                      Feedback.forTap(context);
                      widget.onPressed?.call();
                    },
              onTapDown: widget.onPressed == null
                  ? null
                  : (_) => setState(() => _pressed = true),
              onTapCancel: () => setState(() => _pressed = false),
              onTapUp: widget.onPressed == null
                  ? null
                  : (_) => setState(() => _pressed = false),
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  key: const ValueKey('connect-disc-motion'),
                  animation:
                      Listenable.merge([_breathController, _sweepController]),
                  builder: (context, child) {
                    final breath = disableAnimations
                        ? 0.0
                        : Curves.easeInOut.transform(_breathController.value);
                    final busyScale = widget.busy ? 0.985 : 1.0;
                    final breathScale =
                        widget.busy ? 1.0 : 1.0 + breath * 0.014;
                    return Transform.scale(
                      scale: (_pressed ? 0.97 : 1.0) * busyScale * breathScale,
                      child: child,
                    );
                  },
                  child: AnimatedContainer(
                    duration: motion.duration(_MotionTokens.standard),
                    curve: _MotionTokens.ease,
                    width: diameter,
                    height: diameter,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.running
                          ? _SeedPalette.accent.withValues(alpha: 0.11)
                          : _SeedPalette.surface,
                      boxShadow: [
                        BoxShadow(
                          color: (widget.running ? accent : _SeedPalette.ink)
                              .withValues(alpha: widget.running ? 0.14 : 0.07),
                          blurRadius: widget.running ? 26 : 18,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: Listenable.merge(
                              [_breathController, _sweepController]),
                          builder: (context, _) {
                            return CustomPaint(
                              size: Size.square(diameter),
                              painter: _ConnectDiscRimPainter(
                                accent: accent,
                                enabled: widget.enabled,
                                running: widget.running,
                                degraded: widget.degraded,
                                busy: widget.busy,
                                disableAnimations: disableAnimations,
                                breathValue: _breathController.value,
                                sweepValue: _sweepController.value,
                              ),
                            );
                          },
                        ),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: _SeedPalette.surface.withValues(alpha: 0.74),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: accent.withValues(
                                  alpha: widget.running ? 0.18 : 0.10),
                            ),
                          ),
                          child: SizedBox.square(
                            dimension: diameter * 0.58,
                            child: Center(
                              child: _BrandMark(
                                size: diameter * 0.42,
                                opacity: markOpacity,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            key: const ValueKey('connect-disc-label'),
            duration: motion.duration(_MotionTokens.short),
            transitionBuilder: _fadeSlideTransition,
            child: Text(
              widget.actionLabel,
              key: ValueKey(widget.actionLabel),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: labelColor,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectDiscRimPainter extends CustomPainter {
  const _ConnectDiscRimPainter({
    required this.accent,
    required this.enabled,
    required this.running,
    required this.degraded,
    required this.busy,
    required this.disableAnimations,
    required this.breathValue,
    required this.sweepValue,
  });

  final Color accent;
  final bool enabled;
  final bool running;
  final bool degraded;
  final bool busy;
  final bool disableAnimations;
  final double breathValue;
  final double sweepValue;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 5;
    final breath =
        disableAnimations ? 0.0 : Curves.easeInOut.transform(breathValue);
    final baseOpacity = enabled
        ? running
            ? 0.36
            : 0.16 + breath * 0.08
        : 0.08;
    final basePaint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = running ? 3.2 : 2.2
      ..color = accent.withValues(alpha: baseOpacity);

    canvas.drawCircle(center, radius, basePaint);

    if (busy && enabled) {
      final sweepPaint = Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 4
        ..color = accent.withValues(alpha: disableAnimations ? 0.42 : 0.74);
      final rect = Rect.fromCircle(center: center, radius: radius);
      final startAngle =
          disableAnimations ? -math.pi / 2 : sweepValue * math.pi * 2;
      canvas.drawArc(rect, startAngle, math.pi * 0.86, false, sweepPaint);
    } else if (degraded && enabled) {
      final warningPaint = Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = _SeedPalette.warning.withValues(alpha: 0.72);
      canvas.drawCircle(center, radius - 1.5, warningPaint);
    } else if (running && enabled) {
      final activePaint = Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 4
        ..color = accent.withValues(alpha: 0.56);
      final rect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawArc(rect, -math.pi * 0.62, math.pi * 1.24, false, activePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ConnectDiscRimPainter oldDelegate) {
    return oldDelegate.accent != accent ||
        oldDelegate.enabled != enabled ||
        oldDelegate.running != running ||
        oldDelegate.degraded != degraded ||
        oldDelegate.busy != busy ||
        oldDelegate.disableAnimations != disableAnimations ||
        oldDelegate.breathValue != breathValue ||
        oldDelegate.sweepValue != sweepValue;
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
              ? _SeedPalette.accent.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected
                ? _SeedPalette.accent.withValues(alpha: 0.28)
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
              _routeModeCompactSubtitle(mode),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _SeedPalette.ink.withValues(alpha: 0.7),
                    height: 1.3,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
