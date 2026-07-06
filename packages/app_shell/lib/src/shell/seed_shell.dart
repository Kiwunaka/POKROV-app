part of pokrov_app_shell;

class PokrovSeedApp extends StatefulWidget {
  const PokrovSeedApp({
    super.key,
    required this.appContext,
    this.bootstrapper,
    this.supportTicketService,
    this.handoffLauncher,
    this.firstLaunchStore,
    this.themeModeStore = const PokrovFileThemeModeStore(),
    this.runtimeActionTimeout = const Duration(seconds: 18),
  });

  final SeedAppContext appContext;
  final ManagedProfileBootstrapper? bootstrapper;
  final SupportTicketService? supportTicketService;
  final ExternalHandoffLauncher? handoffLauncher;
  final PokrovFirstLaunchStore? firstLaunchStore;
  final PokrovFileThemeModeStore themeModeStore;
  final Duration runtimeActionTimeout;

  @override
  State<PokrovSeedApp> createState() => _PokrovSeedAppState();
}

class _PokrovSeedAppState extends State<PokrovSeedApp> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    unawaited(_restoreThemeMode());
  }

  Future<void> _restoreThemeMode() async {
    final restored = await widget.themeModeStore.read();
    if (!mounted || restored == _themeMode) {
      return;
    }
    setState(() {
      _themeMode = restored;
    });
  }

  void _setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) {
      return;
    }
    HapticFeedback.selectionClick();
    unawaited(widget.themeModeStore.write(mode));
    setState(() {
      _themeMode = mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'POKROV',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const PokrovScrollBehavior(),
      themeMode: _themeMode,
      theme: _buildPokrovTheme(
        tokens: PokrovPalette.light,
        brightness: Brightness.light,
      ),
      darkTheme: _buildPokrovTheme(
        tokens: PokrovPalette.dark,
        brightness: Brightness.dark,
      ),
      home: PokrovSeedShell(
        appContext: widget.appContext,
        bootstrapper: widget.bootstrapper,
        supportTicketService: widget.supportTicketService,
        handoffLauncher: widget.handoffLauncher,
        firstLaunchStore: widget.firstLaunchStore,
        runtimeActionTimeout: widget.runtimeActionTimeout,
        themeMode: _themeMode,
        onThemeModeChanged: _setThemeMode,
      ),
    );
  }
}

/// Single source of truth for the POKROV Material theme so light and dark
/// stay in lockstep. Builds an Apple-grade type ramp plus restrained,
/// consistent component styling on top of the palette tokens.
ThemeData _buildPokrovTheme({
  required PokrovPaletteTokens tokens,
  required Brightness brightness,
}) {
  final isDark = brightness == Brightness.dark;
  // component.button text tokens: white on emerald, near-black on dark mint.
  final onAccent = isDark ? const Color(0xFF101713) : Colors.white;
  final colorScheme = ColorScheme.fromSeed(
    seedColor: tokens.accent,
    brightness: brightness,
  ).copyWith(
    primary: tokens.accent,
    onPrimary: onAccent,
    secondary: tokens.accentBright,
    onSecondary: onAccent,
    surface: tokens.surface,
    onSurface: tokens.ink,
    error: tokens.danger,
    outlineVariant: tokens.line,
  );
  final textTheme = _buildPokrovTextTheme(tokens);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    fontFamily: 'packages/pokrov_app_shell/Golos Text',
    fontFamilyFallback: const [
      'Segoe UI Variable Display',
      'Segoe UI Variable Text',
      'Segoe UI',
      'Roboto',
      'Inter',
    ],
    extensions: [isDark ? PokrovPalette.dark : PokrovPalette.light],
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: tokens.canvas,
    // iPhone feel: no Material ripple - press feedback comes from scale
    // (PokrovPressable) plus a quiet highlight, like UIKit cell presses.
    // iPhone feel: no visible Material ripple - press feedback comes from
    // scale (PokrovPressable) plus a quiet UIKit-style highlight. A transparent
    // splash (instead of NoSplash.splashFactory) keeps flutter_test happy:
    // NoSplash leaves a raw pending timer after drag-heavy interactions.
    splashColor: Colors.transparent,
    highlightColor: tokens.ink.withValues(alpha: 0.05),
    // Cupertino push (slide-from-right with parallax) on every platform.
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
      },
    ),
    // Cupertino push (slide-from-right with parallax) on every platform.
    textTheme: textTheme,
    iconTheme: IconThemeData(color: tokens.ink, size: 22),
    dividerTheme: DividerThemeData(
      color: tokens.line,
      thickness: 1,
      space: 1,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: tokens.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: textTheme.headlineSmall,
    ),
    cardTheme: CardThemeData(
      color: tokens.surface,
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: PokrovRadii.card),
      clipBehavior: Clip.antiAlias,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.transparent,
      elevation: 0,
      height: 64,
      indicatorColor: tokens.accent.withValues(alpha: isDark ? 0.18 : 0.12),
      indicatorShape: const StadiumBorder(),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 11.5,
          letterSpacing: 0.1,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w600
              : FontWeight.w500,
          color:
              states.contains(WidgetState.selected) ? tokens.ink : tokens.muted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 24,
          color: states.contains(WidgetState.selected)
              ? tokens.accent
              : tokens.muted,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: tokens.accent,
        foregroundColor: onAccent,
        disabledBackgroundColor: tokens.muted.withValues(alpha: 0.18),
        disabledForegroundColor: tokens.muted,
        minimumSize: const Size(0, 50),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        textStyle: textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        shape: const RoundedRectangleBorder(borderRadius: PokrovRadii.stadium),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: tokens.ink,
        side: BorderSide(color: tokens.line),
        minimumSize: const Size(0, 50),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        shape: const RoundedRectangleBorder(borderRadius: PokrovRadii.stadium),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: tokens.accent,
        textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        shape: const RoundedRectangleBorder(borderRadius: PokrovRadii.card),
      ),
    ),
    switchTheme: SwitchThemeData(
      // component.switch canon: iOS system-green on-track, translucent
      // neutral off-track, always-white thumb.
      thumbColor: WidgetStateProperty.all(Colors.white),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? tokens.connectedGreen
            : const Color(0x78787880).withValues(alpha: isDark ? 0.32 : 0.16),
      ),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: tokens.surfaceMuted,
      hintStyle: textTheme.bodyMedium?.copyWith(color: tokens.muted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: const OutlineInputBorder(
        borderRadius: PokrovRadii.cardSm,
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: PokrovRadii.cardSm,
        borderSide: BorderSide(color: tokens.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: PokrovRadii.cardSm,
        borderSide: BorderSide(color: tokens.accent, width: 1.6),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: tokens.surfaceElevated,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PokrovRadii.xl),
      ),
      titleTextStyle: textTheme.titleLarge,
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: tokens.muted),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: tokens.surfaceElevated,
      surfaceTintColor: Colors.transparent,
      modalBarrierColor: tokens.ink.withValues(alpha: isDark ? 0.6 : 0.32),
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: PokrovRadii.sheet),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: tokens.muted,
      textColor: tokens.ink,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 84),
      backgroundColor: isDark ? tokens.surfaceElevated : tokens.ink,
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: isDark ? tokens.ink : tokens.canvasAlt,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PokrovRadii.md),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: tokens.ink.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(PokrovRadii.xs),
      ),
      textStyle: textTheme.labelMedium?.copyWith(color: tokens.canvasAlt),
    ),
  );
}

TextTheme _buildPokrovTextTheme(PokrovPaletteTokens tokens) {
  final ink = tokens.ink;
  final muted = tokens.muted;
  return TextTheme(
    displayLarge: TextStyle(
      fontSize: 34,
      height: 1.1,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.8,
      color: ink,
    ),
    displayMedium: TextStyle(
      fontSize: 28,
      height: 1.12,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.6,
      color: ink,
    ),
    displaySmall: TextStyle(
      fontSize: 24,
      height: 1.16,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.4,
      color: ink,
    ),
    headlineLarge: TextStyle(
      fontSize: 26,
      height: 1.18,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
      color: ink,
    ),
    headlineMedium: TextStyle(
      fontSize: 22,
      height: 1.2,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.4,
      color: ink,
    ),
    headlineSmall: TextStyle(
      fontSize: 20,
      height: 1.22,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.3,
      color: ink,
    ),
    titleLarge: TextStyle(
      fontSize: 19,
      height: 1.25,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
      color: ink,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      height: 1.3,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.1,
      color: ink,
    ),
    titleSmall: TextStyle(
      fontSize: 14,
      height: 1.3,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      color: ink,
    ),
    bodyLarge: TextStyle(
      fontSize: 16,
      height: 1.38,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      color: ink,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      height: 1.4,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      color: ink,
    ),
    bodySmall: TextStyle(
      fontSize: 12,
      height: 1.36,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      color: muted,
    ),
    labelLarge: TextStyle(
      fontSize: 14,
      height: 1.2,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      color: ink,
      fontFeatures: [FontFeature.tabularFigures()],
    ),
    labelMedium: TextStyle(
      fontSize: 12,
      height: 1.2,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
      color: muted,
    ),
    labelSmall: TextStyle(
      fontSize: 11,
      height: 1.2,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.2,
      color: muted,
    ),
  );
}

class PokrovSeedShell extends StatefulWidget {
  const PokrovSeedShell({
    super.key,
    required this.appContext,
    this.bootstrapper,
    this.supportTicketService,
    this.handoffLauncher,
    this.firstLaunchStore,
    this.runtimeActionTimeout = const Duration(seconds: 18),
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  final SeedAppContext appContext;
  final ManagedProfileBootstrapper? bootstrapper;
  final SupportTicketService? supportTicketService;
  final ExternalHandoffLauncher? handoffLauncher;
  final PokrovFirstLaunchStore? firstLaunchStore;
  final Duration runtimeActionTimeout;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

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
  late final AppFirstWarpActionService? _warpActionService;
  late final AppFirstReleaseActionService? _releaseActionService;
  late final AppFirstNodePreferenceService? _nodePreferenceService;
  late final AppFirstClientDataService? _clientDataService;
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
  bool _bonusRewardBusy = false;
  final List<String> _selectedAppIds = <String>[];
  WarpRuntimePolicy _managedWarpPolicy = WarpRuntimePolicy.clientLocalDefault;
  bool _warpRuntimeConsent = false;
  bool _warpPolicyBusy = false;
  SmartConnectProfile? _smartConnectProfile;
  ClientLocationsCatalog? _locationsCatalog;
  String _preferredNodeCode = '';
  bool _nodePreferenceBusy = false;
  bool _locationsCatalogBusy = false;
  String? _locationsCatalogError;
  ClientSubscriptionInfo? _subscriptionInfo;
  ClientNotificationInbox? _notificationsInbox;
  bool _notificationsBusy = false;
  int _notificationsUnread = 0;
  bool _clientUpdateCheckBusy = false;
  bool _clientUpdatePromptVisible = false;
  String _lastPromptedUpdateKey = '';

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
    _warpActionService = bootstrapper is AppFirstWarpActionService
        ? bootstrapper as AppFirstWarpActionService
        : null;
    _releaseActionService = bootstrapper is AppFirstReleaseActionService
        ? bootstrapper as AppFirstReleaseActionService
        : null;
    _nodePreferenceService = bootstrapper is AppFirstNodePreferenceService
        ? bootstrapper as AppFirstNodePreferenceService
        : null;
    _clientDataService = bootstrapper is AppFirstClientDataService
        ? bootstrapper as AppFirstClientDataService
        : null;
    _supportTicketService = widget.supportTicketService ??
        AppFirstSupportTicketService(
          apiBaseUrl: widget.appContext.apiBaseUrl,
        );
    _firstLaunchStore =
        widget.firstLaunchStore ?? const PokrovFileFirstLaunchStore();
    unawaited(_loadFirstLaunchState());
    _refreshRuntimeSnapshot();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_checkForClientUpdate());
      unawaited(_loadBonusSummary());
      unawaited(_refreshNotifications());
    });
  }

  void _selectRouteMode(RouteMode mode) {
    setState(() {
      _selectedRouteMode = mode;
      _managedProfileDirty = true;
    });
  }

  Future<void> _setPreferredLocation(String nodeCode) async {
    final smartConnect = _smartConnectProfile;
    final normalized = nodeCode.trim().toLowerCase();
    if (smartConnect == null || normalized.isEmpty || _nodePreferenceBusy) {
      return;
    }

    HapticFeedback.selectionClick();
    setState(() {
      _nodePreferenceBusy = true;
      _preferredNodeCode = normalized;
      _managedProfileDirty = true;
      _runtimeHeadline =
          'Локация сохранена. Применим при следующем подключении.';
    });
    try {
      final service = _nodePreferenceService;
      if (service != null) {
        final result = await service.setPreferredSmartConnectNode(
          hostPlatform: widget.appContext.hostPlatform,
          smartConnect: smartConnect,
          nodeCode: normalized,
        );
        if (!mounted) {
          return;
        }
        if (result.preferredNodeCode.trim().isNotEmpty) {
          setState(() {
            _preferredNodeCode = result.preferredNodeCode.trim().toLowerCase();
          });
        }
      }
      if (!mounted) {
        return;
      }
      showPokrovSnack(
        context,
        'Локация сохранена. Переподключите POKROV.',
        tone: PokrovSnackTone.success,
      );
    } on BootstrapFailure catch (error) {
      if (!mounted) {
        return;
      }
      showPokrovSnack(context, error.message, tone: PokrovSnackTone.danger);
    } finally {
      if (mounted) {
        setState(() {
          _nodePreferenceBusy = false;
        });
      }
    }
  }

  void _addSelectedAppId(String value) {
    final normalized = _normalizeSelectedAppIdentifier(value);
    if (normalized == null || _selectedAppIds.contains(normalized)) {
      return;
    }
    setState(() {
      _selectedAppIds.add(normalized);
      if (widget.appContext.runtimeProfile.supportedRouteModes
          .contains(RouteMode.selectedApps)) {
        _selectedRouteMode = RouteMode.selectedApps;
      }
      _managedProfileDirty = true;
    });
  }

  void _removeSelectedAppId(String value) {
    setState(() {
      _selectedAppIds.remove(value);
      _managedProfileDirty = true;
    });
  }

  void _selectTab(SeedTab tab) {
    setState(() {
      _selectedIndex = tab.index;
    });
    if (tab == SeedTab.locations) {
      unawaited(_refreshLocationsCatalog());
    }
    if (tab == SeedTab.profile && widget.bootstrapper != null) {
      unawaited(_loadBonusSummary());
      unawaited(_refreshSubscriptionInfo());
      unawaited(_refreshNotifications());
    }
  }

  Future<void> _refreshLocationsCatalog() async {
    final service = _clientDataService;
    if (service == null || _locationsCatalogBusy) {
      return;
    }
    if (mounted) {
      setState(() {
        _locationsCatalogBusy = true;
        _locationsCatalogError = null;
      });
    }
    try {
      final catalog = await service.fetchLocationsCatalog(
        hostPlatform: widget.appContext.hostPlatform,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _locationsCatalog = catalog;
        _locationsCatalogError = null;
      });
    } on BootstrapFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _locationsCatalogError = error.message;
      });
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _locationsCatalogError = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _locationsCatalogBusy = false;
        });
      }
    }
  }

  Future<void> _refreshSubscriptionInfo() async {
    final service = _clientDataService;
    if (service == null) {
      return;
    }
    try {
      final info = await service.fetchClientSubscription(
        hostPlatform: widget.appContext.hostPlatform,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _subscriptionInfo = info;
      });
    } on Object {
      // Subscription detail is optional; the sheet falls back to access lane.
    }
  }

  Future<void> _refreshNotifications() async {
    final service = _clientDataService;
    if (service == null || _notificationsBusy) {
      return;
    }
    if (mounted) {
      setState(() {
        _notificationsBusy = true;
      });
    }
    try {
      final inbox = await service.fetchClientNotifications(
        hostPlatform: widget.appContext.hostPlatform,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _notificationsInbox = inbox;
        _notificationsUnread = inbox.unreadCount;
      });
    } on Object {
      // Notifications are best-effort; keep the last known inbox.
    } finally {
      if (mounted) {
        setState(() {
          _notificationsBusy = false;
        });
      }
    }
  }

  void _markNotificationsRead() {
    if (_notificationsUnread > 0) {
      setState(() {
        _notificationsUnread = 0;
      });
    }
    final service = _clientDataService;
    final inbox = _notificationsInbox;
    if (service == null || inbox == null) {
      return;
    }
    final unreadIds = inbox.items
        .where((item) => !item.read)
        .map((item) => item.id)
        .where((id) => id.trim().isNotEmpty)
        .toList(growable: false);
    if (unreadIds.isEmpty) {
      return;
    }
    unawaited(
      service
          .markClientNotificationsRead(
            hostPlatform: widget.appContext.hostPlatform,
            ids: unreadIds,
          )
          .catchError((Object _) => false),
    );
  }

  Future<ClientDeviceList> _fetchClientDevices() async {
    final service = _clientDataService;
    if (service == null) {
      return const ClientDeviceList(items: <ClientDeviceInfo>[]);
    }
    return service.fetchClientDevices(
      hostPlatform: widget.appContext.hostPlatform,
    );
  }

  Future<bool> _revokeClientDevice(String deviceId) async {
    final service = _clientDataService;
    if (service == null) {
      return false;
    }
    return service.revokeClientDevice(
      hostPlatform: widget.appContext.hostPlatform,
      deviceId: deviceId,
    );
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
      unawaited(_checkForClientUpdate());
      unawaited(_refreshNotifications());
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

  Future<void> _checkForClientUpdate() async {
    final releaseActions = _releaseActionService;
    if (releaseActions == null ||
        _clientUpdateCheckBusy ||
        _clientUpdatePromptVisible) {
      return;
    }
    _clientUpdateCheckBusy = true;
    try {
      final metadata = await releaseActions.fetchClientApps(
        hostPlatform: widget.appContext.hostPlatform,
        currentVersion: _pokrovAppVersion,
      );
      if (!mounted || metadata.silentUpdate) {
        return;
      }
      final update = metadata.updateFor(widget.appContext.hostPlatform);
      final promptKey =
          '${update.platform}:${update.latestVersion}:${update.updatePolicy}';
      if (!update.shouldPrompt || promptKey == _lastPromptedUpdateKey) {
        return;
      }
      _lastPromptedUpdateKey = promptKey;
      await _showClientUpdatePrompt(update);
    } catch (_) {
      // Update checks are advisory; never block the app on startup.
    } finally {
      _clientUpdateCheckBusy = false;
    }
  }

  Future<void> _showClientUpdatePrompt(ClientAppUpdateInfo update) async {
    if (!mounted || _clientUpdatePromptVisible) {
      return;
    }
    _clientUpdatePromptVisible = true;
    final title =
        update.isRequired ? 'Нужно обновить POKROV' : 'Доступно обновление';
    final version = update.latestVersion.trim();
    final notes = update.releaseNotes.trim();
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: !update.isRequired,
        builder: (dialogContext) {
          return AlertDialog(
            key: const ValueKey('client-update-prompt'),
            title: Text(title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  version.isEmpty
                      ? 'Установите свежую версию, чтобы получить исправления и актуальные правила.'
                      : 'Свежая версия: $version.',
                ),
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(notes),
                ],
              ],
            ),
            actions: [
              if (!update.isRequired)
                TextButton(
                  key: const ValueKey('client-update-later'),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Позже'),
                ),
              FilledButton(
                key: const ValueKey('client-update-download'),
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  unawaited(_openSafeHandoff('download', update.url));
                },
                child: const Text('Скачать'),
              ),
            ],
          );
        },
      );
    } finally {
      _clientUpdatePromptVisible = false;
    }
  }

  Future<void> _openSafeHandoff(String label, String value) async {
    final uri = _safeHandoffUri(
      label: label,
      value: value,
      cabinetUrl: widget.appContext.cabinetUrl,
    );
    if (uri == null) {
      showPokrovSnack(context, 'Сначала введите код активации.');
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
      debugPrint('POKROV handoff open failed: $uri');
      showPokrovSnack(
        context,
        'Не удалось открыть страницу. Попробуйте еще раз.',
        tone: PokrovSnackTone.danger,
      );
    }
  }

  Future<bool> _redeemCodeInApp(String value) async {
    final code = value.trim();
    if (code.isEmpty) {
      showPokrovSnack(context, 'Введите код активации.');
      return false;
    }
    if (_looksLikeSubscriptionOrProxyLink(code)) {
      showPokrovSnack(
        context,
        'Ссылка подключения не привязывает аккаунт. Введите одноразовый код или ключ активации.',
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
      final updatesAccess =
          result.kind == 'access_key' || result.kind == 'gift';
      setState(() {
        _managedProfileDirty = true;
        _runtimeHeadline = updatesAccess
            ? 'Код активирован. Доступ обновлен.'
            : 'Код обработан.';
      });
      final confirmationText = _runtimeHeadline ?? '';
      unawaited(_loadBonusSummary(force: true));
      showPokrovSnack(context, confirmationText, tone: PokrovSnackTone.success);
      return true;
    } catch (error) {
      debugPrint('POKROV redeem code failed: $error');
      if (!mounted) {
        return false;
      }
      showPokrovSnack(
        context,
        'Не удалось активировать код. Проверьте код и попробуйте еще раз.',
        tone: PokrovSnackTone.danger,
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
      debugPrint('POKROV cabinet handoff failed: $error');
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
      showPokrovSnack(
        context,
        'Не удалось открыть кабинет. Проверьте соединение и попробуйте еще раз.',
        tone: PokrovSnackTone.danger,
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
      debugPrint('POKROV telegram link failed: $error');
      if (!mounted) {
        return;
      }
      setState(() {
        _telegramBonusBusy = false;
        _telegramBonusError =
            'Не удалось получить код для Telegram. Проверьте соединение и попробуйте еще раз.';
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
      debugPrint('POKROV telegram bonus check failed: $error');
      if (!mounted) {
        return;
      }
      setState(() {
        _telegramBonusBusy = false;
        _telegramBonusError =
            'Не удалось проверить бонус. Попробуйте еще раз через минуту.';
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
            ? 'Бонус уже активирован: +${ruDays(result.premiumDays)}'
            : 'Бонус активирован: +${ruDays(result.premiumDays)}';
        _managedProfileDirty = true;
        _runtimeHeadline = 'Telegram-бонус активирован.';
      });
      unawaited(_loadBonusSummary(force: true));
      showPokrovSnack(
        context,
        'Доступ продлен на ${ruDays(result.premiumDays)}.',
        tone: PokrovSnackTone.success,
      );
    } catch (error) {
      debugPrint('POKROV telegram bonus claim failed: $error');
      if (!mounted) {
        return;
      }
      setState(() {
        _telegramBonusBusy = false;
        _telegramBonusError =
            'Не удалось активировать бонус. Попробуйте еще раз.';
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
      debugPrint('POKROV bonus summary refresh failed: $error');
      if (!mounted) {
        return;
      }
      setState(() {
        _bonusSummaryBusy = false;
        _bonusSummaryError =
            'Не удалось обновить бонусы. Проверьте соединение и попробуйте еще раз.';
      });
    }
  }

  Future<void> _spinBonusWheelInApp() async {
    await _runBonusRewardInApp(
      actionName: 'Рулетка',
      run: (service) => service.spinBonusWheel(
        hostPlatform: widget.appContext.hostPlatform,
      ),
    );
  }

  Future<void> _checkInBonusCalendarInApp() async {
    await _runBonusRewardInApp(
      actionName: 'Календарь',
      run: (service) => service.checkInBonusCalendar(
        hostPlatform: widget.appContext.hostPlatform,
      ),
    );
  }

  Future<void> _runBonusRewardInApp({
    required String actionName,
    required Future<AppFirstBonusRewardResult> Function(
      AppFirstBonusActionService service,
    ) run,
  }) async {
    if (_bonusRewardBusy) {
      return;
    }
    final bonusActions = _bonusActionService;
    if (bonusActions == null) {
      await _loadBonusSummary(force: true);
      return;
    }

    setState(() {
      _bonusRewardBusy = true;
      _bonusSummaryError = null;
    });
    try {
      HapticFeedback.selectionClick();
      final result = await run(bonusActions);
      if (!mounted) {
        return;
      }
      setState(() {
        _bonusRewardBusy = false;
        _bonusSummary = result.summary;
        _managedProfileDirty = true;
        _runtimeHeadline = '$actionName: награда активирована.';
      });
      final days = result.rewardDays;
      showPokrovSnack(
        context,
        days > 0
            ? '$actionName: +${ruDays(days)} к доступу.'
            : '$actionName: отметка сохранена.',
        tone: PokrovSnackTone.success,
      );
    } catch (error) {
      debugPrint('POKROV bonus reward failed ($actionName): $error');
      if (!mounted) {
        return;
      }
      setState(() {
        _bonusRewardBusy = false;
        _bonusSummaryError = 'Не удалось получить награду. Попробуйте еще раз.';
      });
      showPokrovSnack(
        context,
        'Не удалось получить награду. Попробуйте еще раз.',
        tone: PokrovSnackTone.danger,
      );
    }
  }

  String _telegramBonusStatusForStatus(ChannelBonusStatus status) {
    if (status.alreadyClaimed) {
      return 'Бонус активирован: +${ruDays(status.bonusDays)}';
    }
    if (status.claimRequired) {
      return 'Бонус готов: +${ruDays(status.bonusDays)}';
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

  Future<void> _toggleRuntimeFromHome() async {
    if (_firstLaunchStep != _FirstLaunchStep.ready) {
      _completeFirstLaunchAsNewUser();
    }
    await _toggleRuntime();
  }

  void _openFirstLaunchRestore() {
    HapticFeedback.selectionClick();
    setState(() {
      _firstLaunchStep = _FirstLaunchStep.restore;
    });
  }

  void _backToFirstLaunchChoice() {
    HapticFeedback.selectionClick();
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
            extraDiagnostics: _extendedProtectionDiagnostics(),
            supportTicketService: _supportTicketService,
            onOpenHandoff: _showSeedHandoff,
          );
        },
      ),
    );
  }

  Map<String, Object?> _extendedProtectionDiagnostics() {
    return PokrovWarpSupportDiagnostics.fromLifecycle(
      PokrovWarpLifecycle.resolve(
        policy: _managedWarpPolicy,
        consented: _warpRuntimeConsent,
        busy: _warpPolicyBusy,
        lastError: _runtimeSnapshot?.lastFailureKind ?? '',
      ),
    ).toJson();
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

  Future<T> _withRuntimeActionTimeout<T>(
    String operation,
    Future<T> Function() action,
  ) {
    return action().timeout(
      widget.runtimeActionTimeout,
      onTimeout: () => throw TimeoutException(
        'runtime action timed out: $operation',
        widget.runtimeActionTimeout,
      ),
    );
  }

  Future<ManagedProfilePayload> _resolveManagedProfile() async {
    final payload = await _bootstrapper.resolveManagedProfile(
      hostPlatform: widget.appContext.hostPlatform,
      routeMode: _selectedRouteMode,
      selectedApps: _selectedRouteMode == RouteMode.selectedApps
          ? _selectedAppIds
          : const <String>[],
      preferredNodeCode: _preferredNodeCode,
    );
    final baseWarpPolicy = payload.warpPolicy.withClientLocalDefaults();
    final warpStatus = await _fetchWarpStatusOrNull();
    final displayWarpPolicy =
        warpStatus?.applyTo(baseWarpPolicy) ?? baseWarpPolicy;
    final warpConsentStillValid = ((warpStatus?.consented ?? false) ||
            _warpRuntimeConsent ||
            baseWarpPolicy.userConsented) &&
        displayWarpPolicy.canOfferRuntime;
    final runtimePayload = payload.copyWith(
      warpPolicy: displayWarpPolicy.withUserConsent(warpConsentStillValid),
    );
    if (mounted) {
      setState(() {
        _managedProfileDirty = false;
        _managedWarpPolicy = displayWarpPolicy;
        _warpRuntimeConsent = warpConsentStillValid;
        _smartConnectProfile = payload.smartConnect;
        _preferredNodeCode =
            payload.smartConnect?.stickiness.preferredNodeCode.trim() ?? '';
        _runtimeHeadline = 'Настройки обновлены с '
            '${Uri.parse(widget.appContext.apiBaseUrl).host}.';
      });
    }
    return runtimePayload;
  }

  Future<WarpControlStatus?> _fetchWarpStatusOrNull() async {
    final service = _warpActionService;
    if (service == null) {
      return null;
    }
    try {
      return await service.fetchWarpStatus(
        hostPlatform: widget.appContext.hostPlatform,
      );
    } on BootstrapFailure catch (error) {
      if (mounted && error.statusCode != null) {
        setState(() {
          _runtimeHeadline = error.message;
        });
      }
      return null;
    }
  }

  Future<void> _openWarpControl() async {
    if (_warpPolicyBusy) {
      return;
    }

    var policy = _managedWarpPolicy;
    if (!policy.canOfferRuntime) {
      setState(() {
        _warpPolicyBusy = true;
      });
      try {
        await _resolveManagedProfile();
        policy = _managedWarpPolicy;
      } on BootstrapFailure catch (error) {
        if (!mounted) {
          return;
        }
        setState(() {
          _runtimeHeadline = error.message;
        });
        showPokrovSnack(context, error.message, tone: PokrovSnackTone.danger);
        return;
      } finally {
        if (mounted) {
          setState(() {
            _warpPolicyBusy = false;
          });
        }
      }
    }

    if (!mounted) {
      return;
    }

    if (!policy.canOfferRuntime) {
      _showInfoSheet(
        context,
        title: 'WARP',
        lines: const [
          'Дополнительный режим пока недоступен для этого устройства.',
          'POKROV оставит обычное подключение и не будет мешать работе VPN.',
        ],
      );
      return;
    }

    _showWarpConsentSheet(
      context,
      lifecycle: PokrovWarpLifecycle.resolve(
        policy: _managedWarpPolicy,
        consented: _warpRuntimeConsent,
        busy: _warpPolicyBusy,
      ),
      enabled: _warpRuntimeConsent,
      onChanged: _setWarpRuntimeConsent,
    );
  }

  Future<void> _setWarpRuntimeConsent(bool value) async {
    if (_warpPolicyBusy) {
      return;
    }
    final localPolicy = _managedWarpPolicy.withClientLocalDefaults();
    final requestedEnabled = value && localPolicy.canOfferRuntime;
    HapticFeedback.selectionClick();
    setState(() {
      _warpPolicyBusy = true;
      _managedWarpPolicy = localPolicy;
    });
    try {
      final service = _warpActionService;
      var status = WarpControlStatus.fromPolicy(localPolicy).copyWith(
        consented: requestedEnabled,
        canEnable: !requestedEnabled,
        state: requestedEnabled ? 'consented' : 'revoked',
        source: localPolicy.source,
      );
      if (service != null) {
        try {
          status = await service.setWarpConsent(
            hostPlatform: widget.appContext.hostPlatform,
            enabled: requestedEnabled,
            reasonCode: requestedEnabled ? 'user_consented' : 'user_disabled',
          );
        } on BootstrapFailure {
          status = status.copyWith(
            state: requestedEnabled ? 'consented_local' : 'revoked',
            source: 'client_local',
          );
        } on Object {
          status = status.copyWith(
            state: requestedEnabled ? 'consented_local' : 'revoked',
            source: 'client_local',
          );
        }
      }
      final servicePolicy = status.applyTo(localPolicy);
      final nextPolicy = requestedEnabled
          ? servicePolicy.copyWith(
              userConsented: true,
              state: 'consented',
              source: servicePolicy.hasServerManagedMaterial
                  ? servicePolicy.source
                  : 'client_local',
            )
          : localPolicy.copyWith(
              state: 'revoked',
              userConsented: false,
              mode: servicePolicy.mode,
              source: 'client_local',
            );
      final enabled = requestedEnabled && nextPolicy.canOfferRuntime;
      if (!mounted) {
        return;
      }
      setState(() {
        _managedWarpPolicy = nextPolicy;
        _warpRuntimeConsent = enabled;
        _managedProfileDirty = true;
        _runtimeHeadline = enabled
            ? 'WARP включится при следующем подключении.'
            : 'WARP выключен для следующих подключений.';
      });
      // WARP takes effect on the next connection, so respond to the toggle
      // instantly and push the runtime apply in the background instead of
      // blocking the UI on a platform round-trip.
      unawaited(_applyWarpRuntimeConsent(enabled: enabled));
    } on BootstrapFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _runtimeHeadline = error.message;
      });
      showPokrovSnack(context, error.message, tone: PokrovSnackTone.danger);
    } finally {
      if (mounted) {
        setState(() {
          _warpPolicyBusy = false;
        });
      }
    }
  }

  Future<WarpApplyResult> _applyWarpRuntimeConsent({
    required bool enabled,
  }) async {
    try {
      final result = await _withRuntimeActionTimeout(
        'applyWarp',
        () => _runtimeEngine.applyWarp(enabled: enabled),
      );
      unawaited(_reportWarpApplyResult(enabled: enabled, result: result));
      return result;
    } on Object catch (error) {
      final result = WarpApplyResult.notApplied(
        reason: _safeWarpApplyReason(error),
      );
      unawaited(
        _reportWarpApplyResult(
          enabled: enabled,
          result: result,
          message: error.toString(),
        ),
      );
      return result;
    }
  }

  Future<void> _reportWarpApplyResult({
    required bool enabled,
    required WarpApplyResult result,
    String message = '',
  }) async {
    final service = _warpActionService;
    if (service == null) {
      return;
    }
    try {
      await service.reportWarpRuntimeEvent(
        hostPlatform: widget.appContext.hostPlatform,
        eventName: 'runtime_apply_warp',
        state: result.applied
            ? (enabled ? 'active' : 'revoked')
            : (enabled ? 'deferred' : 'revoked_deferred'),
        reasonCode:
            result.applied ? 'applied' : (result.reason ?? 'not_applied'),
        message: message,
        meta: <String, Object?>{
          'enabled': enabled,
          'applied': result.applied,
          'effective_at': result.effectiveAt,
          'fallback_used': result.fallbackUsed,
          if (result.reason != null) 'reason': result.reason,
        },
      );
    } on BootstrapFailure {
      // Runtime-proof telemetry must never block the WARP switch.
    } on Object {
      // Same rule for transient platform or network failures.
    }
  }

  String _safeWarpApplyReason(Object error) {
    if (error is TimeoutException) {
      return 'timeout';
    }
    if (error is PlatformException) {
      final code = error.code.trim();
      return code.isEmpty ? 'platform_error' : code;
    }
    final text = error.toString().trim();
    if (text.isEmpty) {
      return 'runtime_error';
    }
    final normalized = text
        .toLowerCase()
        .replaceAll(RegExp('[^a-z0-9_]+'), '_')
        .replaceAll(RegExp('_+'), '_')
        .replaceAll(RegExp('^_|_\$'), '');
    if (normalized.isEmpty) {
      return 'runtime_error';
    }
    return normalized.length > 48 ? normalized.substring(0, 48) : normalized;
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
      final RuntimeSnapshot snapshot = _runtimeSnapshot ??
          await _withRuntimeActionTimeout(
            'snapshot',
            _runtimeEngine.snapshot,
          );
      if (!mounted) {
        return;
      }

      if (snapshot.phase == RuntimePhase.running) {
        var current = await _withRuntimeActionTimeout(
          'disconnect',
          _runtimeEngine.disconnect,
        );
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

      RuntimeSnapshot current = snapshot;

      if (current.canInitialize &&
          current.phase == RuntimePhase.artifactReady) {
        current = await _withRuntimeActionTimeout(
          'initialize',
          _runtimeEngine.initialize,
        );
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
        current = await _withRuntimeActionTimeout(
          'stageManagedProfile',
          () => _runtimeEngine.stageManagedProfile(managedProfile),
        );
        if (!mounted) {
          return;
        }
        setState(() {
          _runtimeSnapshot = current;
          _runtimeHeadline = null;
        });
      }

      if ((current.stagedConfigPath ?? '').isNotEmpty || current.canConnect) {
        current = await _withRuntimeActionTimeout(
          'connect',
          _runtimeEngine.connect,
        );
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
          unawaited(_reportWarpRuntimeFallback(current));
          showPokrovSnack(
            context,
            current.message,
            tone: PokrovSnackTone.danger,
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
      showPokrovSnack(context, error.message, tone: PokrovSnackTone.danger);
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      final message = _runtimeUnexpectedErrorMessage(error);
      setState(() {
        _runtimeHeadline = message;
      });
      showPokrovSnack(context, message, tone: PokrovSnackTone.danger);
    } finally {
      if (mounted) {
        setState(() {
          _runtimeBusy = false;
        });
      }
    }
  }

  String _runtimeUnexpectedErrorMessage(Object error) {
    final rawDetail = switch (error) {
      TimeoutException() =>
        'система не ответила вовремя. Попробуйте еще раз, а если не поможет — напишите в поддержку.',
      PlatformException(:final message, :final code) =>
        (message?.trim().isNotEmpty == true ? message!.trim() : code),
      _ => error.toString().trim(),
    };
    final normalizedDetail = rawDetail.replaceFirst('Bad state: ', '').trim();
    final detail = normalizedDetail.length > 180
        ? '${normalizedDetail.substring(0, 180)}...'
        : normalizedDetail;
    if (detail.isEmpty) {
      return 'POKROV не смог начать подключение. Попробуйте еще раз, а если не поможет — напишите в поддержку: диагностику можно приложить прямо в чате.';
    }
    return 'POKROV не смог начать подключение: $detail';
  }

  Future<void> _reportWarpRuntimeFallback(RuntimeSnapshot snapshot) async {
    final service = _warpActionService;
    if (service == null ||
        !_warpRuntimeConsent ||
        !_managedWarpPolicy.canOfferRuntime) {
      return;
    }
    try {
      final failureKind = snapshot.lastFailureKind?.trim() ?? '';
      final diagnosticsSummary = snapshot.hostDiagnosticsSummary?.trim() ?? '';
      final status = await service.reportWarpRuntimeEvent(
        hostPlatform: widget.appContext.hostPlatform,
        eventName: 'runtime_fallback',
        state: 'fallback',
        reasonCode:
            failureKind.isNotEmpty ? failureKind : 'connect_not_running',
        message: snapshot.message,
        meta: <String, Object?>{
          'phase': snapshot.phase.name,
          'lane': snapshot.lane.name,
          'host_health': snapshot.hostHealth.name,
          'dns_state': snapshot.dnsState.name,
          'uplink_state': snapshot.uplinkState.name,
          if (diagnosticsSummary.isNotEmpty)
            'host_diagnostics_summary': diagnosticsSummary,
        },
      );
      if (!mounted) {
        return;
      }
      final nextPolicy = status.applyTo(_managedWarpPolicy);
      setState(() {
        _managedWarpPolicy = nextPolicy;
        _warpRuntimeConsent = (status.consented || _warpRuntimeConsent) &&
            nextPolicy.canOfferRuntime;
      });
    } on BootstrapFailure {
      // Runtime fallback telemetry must never block the user's connect flow.
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
      current = await _withRuntimeActionTimeout(
        'settleSnapshot',
        _runtimeEngine.snapshot,
      );
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
      current = await _withRuntimeActionTimeout(
        'disconnectSnapshot',
        _runtimeEngine.snapshot,
      );
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

  Map<ShortcutActivator, Intent> _desktopNavigationShortcuts() {
    return const <ShortcutActivator, Intent>{
      SingleActivator(LogicalKeyboardKey.digit1, control: true):
          _SelectSeedTabIntent(SeedTab.protection),
      SingleActivator(LogicalKeyboardKey.digit2, control: true):
          _SelectSeedTabIntent(SeedTab.locations),
      SingleActivator(LogicalKeyboardKey.digit3, control: true):
          _SelectSeedTabIntent(SeedTab.rules),
      SingleActivator(LogicalKeyboardKey.digit4, control: true):
          _SelectSeedTabIntent(SeedTab.profile),
      SingleActivator(LogicalKeyboardKey.numpad1, control: true):
          _SelectSeedTabIntent(SeedTab.protection),
      SingleActivator(LogicalKeyboardKey.numpad2, control: true):
          _SelectSeedTabIntent(SeedTab.locations),
      SingleActivator(LogicalKeyboardKey.numpad3, control: true):
          _SelectSeedTabIntent(SeedTab.rules),
      SingleActivator(LogicalKeyboardKey.numpad4, control: true):
          _SelectSeedTabIntent(SeedTab.profile),
    };
  }

  @override
  Widget build(BuildContext context) {
    final hasProvisionedAccess = !_managedProfileDirty ||
        (_runtimeSnapshot?.phase == RuntimePhase.running) ||
        ((_runtimeSnapshot?.stagedConfigPath ?? '').isNotEmpty);
    final sectionBuilders = <WidgetBuilder>[
      (context) => _QuickConnectSection(
            appContext: widget.appContext,
            selectedRouteMode: _selectedRouteMode,
            runtimeSnapshot: _runtimeSnapshot,
            runtimeHeadline: _runtimeHeadline,
            runtimeBusy: _runtimeBusy,
            primaryConnectEnabled: _canPrimaryConnect(_runtimeSnapshot),
            bonusSummary: _bonusSummary,
            telegramBonusBusy: _telegramBonusBusy,
            warpPolicy: _managedWarpPolicy,
            warpRuntimeConsent: _warpRuntimeConsent,
            warpBusy: _warpPolicyBusy,
            onToggleRuntime: _toggleRuntimeFromHome,
            onTelegramBonus: _telegramBonusBusy
                ? null
                : () {
                    if (_telegramBonusCanClaim) {
                      unawaited(_claimTelegramBonusInApp());
                    } else {
                      unawaited(_createTelegramLinkInApp());
                    }
                  },
            onOpenLocations: () => _selectTab(SeedTab.locations),
            onOpenRules: () => _selectTab(SeedTab.rules),
            onOpenWarp: _openWarpControl,
            onWarpConsentChanged: _setWarpRuntimeConsent,
            onOpenPromoHandoff: _showSeedHandoff,
          ),
      (context) => _LocationsSection(
            appContext: widget.appContext,
            selectedRouteMode: _selectedRouteMode,
            hasProvisionedAccess: hasProvisionedAccess,
            smartConnectProfile: _smartConnectProfile,
            locationsCatalog: _locationsCatalog,
            locationsCatalogBusy: _locationsCatalogBusy,
            locationsCatalogError: _locationsCatalogError,
            onRefreshLocationsCatalog: _refreshLocationsCatalog,
            preferredNodeCode: _preferredNodeCode,
            nodePreferenceBusy: _nodePreferenceBusy,
            onPreferredNodeSelected: _setPreferredLocation,
          ),
      (context) => _RulesSection(
            appContext: widget.appContext,
            selectedRouteMode: _selectedRouteMode,
            selectedAppIds: _selectedAppIds,
            onRouteModeSelected: (mode) {
              _selectRouteMode(mode);
            },
            onSelectedAppAdded: _addSelectedAppId,
            onSelectedAppRemoved: _removeSelectedAppId,
          ),
      (context) => _ProfileSection(
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
            bonusSummary: () => _bonusSummary,
            bonusSummaryBusy: _bonusSummaryBusy,
            bonusSummaryError: _bonusSummaryError,
            bonusRewardBusy: () => _bonusRewardBusy,
            onRefreshBonusSummary: () => _loadBonusSummary(force: true),
            onSpinWheel: _spinBonusWheelInApp,
            onCheckInCalendar: _checkInBonusCalendarInApp,
            warpPolicy: _managedWarpPolicy,
            warpRuntimeConsent: _warpRuntimeConsent,
            warpBusy: _warpPolicyBusy,
            runtimeSnapshot: _runtimeSnapshot,
            runtimeHeadline: _runtimeHeadline,
            onOpenWarp: _openWarpControl,
            themeMode: widget.themeMode,
            onThemeModeChanged: widget.onThemeModeChanged,
            subscriptionInfo: _subscriptionInfo,
            notifications:
                _notificationsInbox?.items ?? const <ClientNotificationItem>[],
            notificationsUnread: _notificationsUnread,
            notificationsBusy: _notificationsBusy,
            onOpenNotifications: _markNotificationsRead,
            onRefreshNotifications: _refreshNotifications,
            onFetchDevices: _fetchClientDevices,
            onRevokeDevice: _revokeClientDevice,
          ),
    ];

    final isDesktopShell = switch (widget.appContext.hostPlatform) {
      HostPlatform.windows || HostPlatform.macos => true,
      HostPlatform.android || HostPlatform.ios => false,
    };

    final disableAnimations = MediaQuery.maybeOf(context)?.disableAnimations ??
        WidgetsBinding.instance.platformDispatcher.accessibilityFeatures
            .disableAnimations;
    final shell = isDesktopShell
        ? _DesktopShell(
            selectedIndex: _selectedIndex,
            sectionBuilders: sectionBuilders,
            onSelected: (index) {
              _selectTab(SeedTab.values[index]);
            },
          )
        : _MobileShell(
            selectedIndex: _selectedIndex,
            sectionBuilders: sectionBuilders,
            onSelected: (index) {
              _selectTab(SeedTab.values[index]);
            },
          );

    return _MotionScope(
      key: const ValueKey('motion-policy'),
      disableAnimations: disableAnimations,
      child: Shortcuts(
        key: const ValueKey('desktop-shell-shortcuts'),
        shortcuts: isDesktopShell && _firstLaunchStep == _FirstLaunchStep.ready
            ? _desktopNavigationShortcuts()
            : const <ShortcutActivator, Intent>{},
        child: Actions(
          actions: <Type, Action<Intent>>{
            _SelectSeedTabIntent: CallbackAction<_SelectSeedTabIntent>(
              onInvoke: (intent) {
                _selectTab(intent.tab);
                return null;
              },
            ),
          },
          child: Focus(
            key: const ValueKey('desktop-shell-focus-root'),
            autofocus: true,
            child: Scaffold(
              extendBody: !isDesktopShell,
              body: _SeedBackdrop(
                child: SafeArea(
                  child: Stack(
                    children: [
                      Positioned.fill(child: shell),
                      if (_firstLaunchStep != _FirstLaunchStep.ready)
                        _FirstLaunchGate(
                          appContext: widget.appContext,
                          step: _firstLaunchStep,
                          restoreCodeController:
                              _firstLaunchRestoreCodeController,
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
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
