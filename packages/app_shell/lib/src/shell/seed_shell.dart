part of pokrov_app_shell;

class PokrovSeedApp extends StatefulWidget {
  const PokrovSeedApp({
    super.key,
    required this.appContext,
    this.bootstrapper,
    this.supportTicketService,
    this.handoffLauncher,
    this.clientUpdateInstaller,
    this.clientUpdateProgressReader,
    this.firstLaunchStore,
    this.themeModeStore = const PokrovFileThemeModeStore(),
    this.connectHintStore = const PokrovFileConnectHintStore(),
    this.runtimeActionTimeout = const Duration(seconds: 18),
    this.protectionProbe,
    this.clientExperienceStore = const PokrovFileClientExperienceStore(),
    this.shellController,
    this.currentWifiProbe,
    this.wifiPermissionRequester,
    this.vpnSettingsLauncher,
    this.nodeLatencyProbe,
    this.initialAcquisitionUri,
    this.acquisitionUriStream,
  });

  final SeedAppContext appContext;
  final ManagedProfileBootstrapper? bootstrapper;
  final SupportTicketService? supportTicketService;
  final ExternalHandoffLauncher? handoffLauncher;
  final PokrovClientUpdateInstaller? clientUpdateInstaller;
  final PokrovClientUpdateProgressReader? clientUpdateProgressReader;
  final PokrovFirstLaunchStore? firstLaunchStore;
  final PokrovFileThemeModeStore themeModeStore;
  final PokrovFileConnectHintStore connectHintStore;
  final Duration runtimeActionTimeout;
  final PokrovProtectionProbe? protectionProbe;
  final PokrovClientExperienceStore clientExperienceStore;
  final PokrovShellController? shellController;
  final PokrovWifiProbe? currentWifiProbe;
  final PokrovWifiPermissionRequester? wifiPermissionRequester;
  final PokrovVpnSettingsLauncher? vpnSettingsLauncher;
  final PokrovNodeLatencyProbe? nodeLatencyProbe;
  final Uri? initialAcquisitionUri;
  final Stream<Uri>? acquisitionUriStream;

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
    PokrovHaptics.tap();
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
        clientUpdateInstaller: widget.clientUpdateInstaller,
        clientUpdateProgressReader: widget.clientUpdateProgressReader,
        firstLaunchStore: widget.firstLaunchStore,
        connectHintStore: widget.connectHintStore,
        runtimeActionTimeout: widget.runtimeActionTimeout,
        protectionProbe: widget.protectionProbe,
        clientExperienceStore: widget.clientExperienceStore,
        shellController: widget.shellController,
        currentWifiProbe: widget.currentWifiProbe,
        wifiPermissionRequester: widget.wifiPermissionRequester,
        vpnSettingsLauncher: widget.vpnSettingsLauncher,
        nodeLatencyProbe: widget.nodeLatencyProbe,
        initialAcquisitionUri: widget.initialAcquisitionUri,
        acquisitionUriStream: widget.acquisitionUriStream,
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
    dividerTheme: DividerThemeData(color: tokens.line, thickness: 1, space: 1),
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
      indicatorColor: Colors.transparent,
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
      // The palette step surface→surfaceElevated is nearly invisible in dark,
      // so the sheet lift comes from a real shadow, never a tint overlay.
      elevation: 20,
      shadowColor: Colors.black.withValues(alpha: isDark ? 0.55 : 0.16),
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
    this.clientUpdateInstaller,
    this.clientUpdateProgressReader,
    this.firstLaunchStore,
    this.connectHintStore = const PokrovFileConnectHintStore(),
    this.runtimeActionTimeout = const Duration(seconds: 18),
    this.protectionProbe,
    this.clientExperienceStore = const PokrovFileClientExperienceStore(),
    required this.themeMode,
    required this.onThemeModeChanged,
    this.shellController,
    this.currentWifiProbe,
    this.wifiPermissionRequester,
    this.vpnSettingsLauncher,
    this.nodeLatencyProbe,
    this.initialAcquisitionUri,
    this.acquisitionUriStream,
  });

  final SeedAppContext appContext;
  final ManagedProfileBootstrapper? bootstrapper;
  final SupportTicketService? supportTicketService;
  final ExternalHandoffLauncher? handoffLauncher;
  final PokrovClientUpdateInstaller? clientUpdateInstaller;
  final PokrovClientUpdateProgressReader? clientUpdateProgressReader;
  final PokrovFirstLaunchStore? firstLaunchStore;
  final PokrovFileConnectHintStore connectHintStore;
  final Duration runtimeActionTimeout;
  final PokrovProtectionProbe? protectionProbe;
  final PokrovClientExperienceStore clientExperienceStore;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final PokrovShellController? shellController;
  final PokrovWifiProbe? currentWifiProbe;
  final PokrovWifiPermissionRequester? wifiPermissionRequester;
  final PokrovVpnSettingsLauncher? vpnSettingsLauncher;
  final PokrovNodeLatencyProbe? nodeLatencyProbe;
  final Uri? initialAcquisitionUri;
  final Stream<Uri>? acquisitionUriStream;

  @override
  State<PokrovSeedShell> createState() => _PokrovSeedShellState();
}

class _ProtectionRepairBusy implements Exception {
  const _ProtectionRepairBusy();
}

class _ProtectionRepairFailed implements Exception {
  const _ProtectionRepairFailed(this.data);

  final _ProtectionCenterData data;
}

class _PokrovSeedShellState extends State<PokrovSeedShell>
    with WidgetsBindingObserver {
  static const _automaticNodeQuarantineTtl = Duration(minutes: 15);
  static const _maxAutomaticNodeQuarantineEntries = 8;
  static const _maxAutomaticFailoverAttempts = 2;

  int _selectedIndex = 0;
  late RouteMode _selectedRouteMode;
  late final PokrovRuntimeEngine _runtimeEngine;
  late final ManagedProfileBootstrapper _bootstrapper;
  late final AppFirstAccountActionService? _accountActionService;
  late final AppFirstBonusActionService? _bonusActionService;
  late final AppFirstWarpActionService? _warpActionService;
  late final AppFirstReleaseActionService? _releaseActionService;
  late final AppFirstExperienceService? _experienceService;
  late final AppFirstAcquisitionService? _acquisitionService;
  late final AppFirstQuestEventService? _questEventService;
  late final AppFirstPromoEventService? _promoEventService;
  late final AppFirstNodePreferenceService? _nodePreferenceService;
  late final AppFirstClientDataService? _clientDataService;
  late final AppFirstEmergencyNetworkService? _emergencyNetworkService;
  late final SupportTicketService _supportTicketService;
  late final PokrovFirstLaunchStore _firstLaunchStore;
  late final PokrovClientExperienceStore _clientExperienceStore;
  PokrovClientExperienceState _clientExperience =
      const PokrovClientExperienceState.empty();
  Future<void> _clientExperienceWriteQueue = Future<void>.value();
  int _clientExperienceRevision = 0;
  bool _locationsUsingCache = false;
  bool _notificationsUsingCache = false;
  final TextEditingController _firstLaunchRestoreCodeController =
      TextEditingController();
  RuntimeSnapshot? _runtimeSnapshot;
  bool _runtimeBusy = false;
  bool _runtimeResumeRefreshPending = false;
  Timer? _postConnectHealthTimer;
  int _postConnectHealthGeneration = 0;
  int? _postConnectHealthPollInFlight;
  // Direction of the current busy transition so the UI can honestly say
  // «Отключаем...» instead of pretending every busy state is a connect.
  bool _runtimeDisconnecting = false;
  bool _firstLaunchBusy = false;
  bool _managedProfileDirty = true;
  int _managedProfileRevision = 0;
  int _quickSettingsInvalidationRequestedRevision = 0;
  int _quickSettingsInvalidationCompletedRevision = 0;
  Future<bool>? _quickSettingsInvalidationInFlight;
  int _managedProfileInvalidationGeneration = 0;
  Timer? _managedProfileInvalidationTimer;
  Completer<bool>? _managedProfileInvalidationCompletion;
  bool _seedShellDisposed = false;
  final CachedProfileFallbackGate _cachedProfileFallbackGate =
      CachedProfileFallbackGate();
  // Hidden until the store confirms the hint was never dismissed, so the
  // one-time pulse never flashes for returning users while the read is
  // in flight.
  bool _connectHintDismissed = true;
  _FirstLaunchStep _firstLaunchStep = _FirstLaunchStep.choice;

  /// Welcome Handover plays only for user-driven gate exits; the silent
  /// boot resolve for returning users stays an instant removal so the gate
  /// never ghost-fades over their home screen.
  bool _firstLaunchExitAnimated = false;
  String? _runtimeHeadline;
  FreeProfileAccess? _freeProfileAccess;
  String _telegramBonusStatus = 'Получить код';
  bool _telegramBonusBusy = false;
  bool _telegramBonusCanClaim = false;
  String? _telegramBonusError;
  AppFirstBonusSummary? _bonusSummary;
  bool _bonusSummaryBusy = false;
  bool _bonusSummaryRequested = false;
  String? _bonusSummaryError;
  bool _bonusRewardBusy = false;
  bool _routingLessonReported = false;
  final List<String> _selectedAppIds = <String>[];
  WarpRuntimePolicy _managedWarpPolicy = WarpRuntimePolicy.clientLocalDefault;
  bool _warpRuntimeConsent = false;
  // Null means no local decision in this shell lifetime. Once a person opts
  // out, stale profile/status payloads must never re-enable WARP for them.
  bool? _explicitWarpRuntimeConsent;
  bool _warpRuntimeRetryPending = false;
  bool _warpPolicyBusy = false;
  bool _stagedProfileUsesWarp = false;
  bool _activeConnectUsedWarp = false;
  bool _warpFallbackInFlight = false;
  SmartConnectProfile? _smartConnectProfile;
  ClientLocationsCatalog? _locationsCatalog;
  String _preferredNodeCode = '';
  String _preferredVariantId = 'direct';
  String _resolvedProfileNodeCode = '';
  String _resolvedProfileVariantId = 'direct';
  String _stagedNodeCode = '';
  String _stagedVariantId = 'direct';
  String _activeNodeCode = '';
  String _activeVariantId = 'direct';
  final Map<String, DateTime> _automaticNodeQuarantineUntil =
      <String, DateTime>{};
  int _automaticFailoverAttempts = 0;
  int _automaticFailoverGeneration = 0;
  bool _automaticFailoverInFlight = false;
  bool _nodePreferenceBusy = false;
  bool _locationsCatalogBusy = false;
  String? _locationsCatalogError;
  ClientSubscriptionInfo? _subscriptionInfo;
  PokrovSystemSurfacePreferences _systemSurfacePreferences =
      const PokrovSystemSurfacePreferences();
  ClientNotificationInbox? _notificationsInbox;
  bool _notificationsBusy = false;
  int _notificationsUnread = 0;
  bool _clientUpdateCheckBusy = false;
  bool _clientUpdatePromptVisible = false;
  String _lastPromptedUpdateKey = '';
  StreamSubscription<Uri>? _acquisitionUriSubscription;
  final Set<String> _processedAcquisitionHandles = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _selectedRouteMode = widget.appContext.runtimeProfile.defaultRouteMode;
    _runtimeEngine = createRuntimeEngine(
      hostPlatform: widget.appContext.hostPlatform,
    );
    widget.shellController?._attach(
      toggle: _toggleRuntime,
      isConnected: () => _runtimeSnapshot?.phase == RuntimePhase.running,
      isBusy: () => _runtimeBusy,
      canToggle: () =>
          _runtimeSnapshot?.phase == RuntimePhase.running ||
          _canPrimaryConnect(_runtimeSnapshot),
    );
    final bootstrapper = widget.bootstrapper ??
        AppFirstRuntimeBootstrapper(
          apiBaseUrl: widget.appContext.apiBaseUrl,
          deviceNameResolver: resolvePokrovDeviceName,
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
    _experienceService = bootstrapper is AppFirstExperienceService
        ? bootstrapper as AppFirstExperienceService
        : null;
    _acquisitionService = bootstrapper is AppFirstAcquisitionService
        ? bootstrapper as AppFirstAcquisitionService
        : null;
    _questEventService = bootstrapper is AppFirstQuestEventService
        ? bootstrapper as AppFirstQuestEventService
        : null;
    _promoEventService = bootstrapper is AppFirstPromoEventService
        ? bootstrapper as AppFirstPromoEventService
        : null;
    _nodePreferenceService = bootstrapper is AppFirstNodePreferenceService
        ? bootstrapper as AppFirstNodePreferenceService
        : null;
    _clientDataService = bootstrapper is AppFirstClientDataService
        ? bootstrapper as AppFirstClientDataService
        : null;
    _emergencyNetworkService = bootstrapper is AppFirstEmergencyNetworkService
        ? bootstrapper as AppFirstEmergencyNetworkService
        : null;
    _supportTicketService = widget.supportTicketService ??
        AppFirstSupportTicketService(apiBaseUrl: widget.appContext.apiBaseUrl);
    _firstLaunchStore =
        widget.firstLaunchStore ?? const PokrovFileFirstLaunchStore();
    _clientExperienceStore = widget.clientExperienceStore;
    final acquisitionUriStream = widget.acquisitionUriStream;
    if (acquisitionUriStream != null) {
      _acquisitionUriSubscription = acquisitionUriStream.listen(
        (uri) => unawaited(_consumeAcquisitionUri(uri)),
        onError: (_) {},
      );
    }
    unawaited(_loadFirstLaunchState());
    unawaited(_loadConnectHintState());
    unawaited(_restoreClientExperience());
    _refreshRuntimeSnapshot();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final initialAcquisitionUri = widget.initialAcquisitionUri;
      if (initialAcquisitionUri != null) {
        unawaited(_consumeAcquisitionUri(initialAcquisitionUri));
      }
      unawaited(_checkForClientUpdate());
      unawaited(_refreshAccountSummary());
      unawaited(_loadSystemSurfacePreferences());
    });
  }

  Future<void> _consumeAcquisitionUri(Uri uri) async {
    final service = _acquisitionService;
    final handoff = PokrovAcquisitionHandoff.tryParse(
      uri,
      hostPlatform: widget.appContext.hostPlatform,
    );
    if (service == null ||
        handoff == null ||
        !_processedAcquisitionHandles.add(handoff.handle)) {
      return;
    }
    try {
      await service.consumeAcquisitionHandoff(
        hostPlatform: widget.appContext.hostPlatform,
        handle: handoff.handle,
        purpose: handoff.purpose,
      );
    } catch (_) {
      // Attribution is best-effort and must never block onboarding, access,
      // or normal app use. The server validates expiry, purpose and replay.
    }
  }

  Future<void> _refreshAccountSummary() async {
    // Both calls may refresh the same expired app session and reconcile the
    // same account projection. Keep them ordered so first launch cannot make
    // two competing account transactions and leave bonuses in an error state.
    await _refreshSubscriptionInfo();
    await _loadBonusSummary();
  }

  Future<void> _restoreClientExperience() async {
    final restoreRevision = _clientExperienceRevision;
    final restored = await _clientExperienceStore.read();
    if (!mounted || restoreRevision != _clientExperienceRevision) {
      return;
    }
    final preferredCode = restored.preferredNodeCode.trim().toLowerCase();
    final preferredVariantId = preferredCode.isEmpty
        ? 'direct'
        : normalizeClientLocationVariantId(restored.preferredVariantId) ??
            'direct';
    final now = DateTime.now().toUtc();
    final maximumTrustedExpiry = now.add(const Duration(hours: 1));
    final restoredQuarantine = <String, DateTime>{};
    for (final entry in restored.automaticNodeQuarantineUntil.entries) {
      final expiresAt = DateTime.tryParse(entry.value)?.toUtc();
      if (expiresAt == null ||
          !expiresAt.isAfter(now) ||
          expiresAt.isAfter(maximumTrustedExpiry)) {
        continue;
      }
      restoredQuarantine[entry.key.trim().toLowerCase()] = expiresAt;
    }
    if (preferredCode.isNotEmpty) {
      // A persisted manual choice is not proof that the staged profile still
      // selects it after a restart. Require a fresh manifest before using any
      // cached config, so the home label cannot outrun the runtime selector.
      _cachedProfileFallbackGate.markUserChange();
    }
    final restoredSelectedAppIds = restored.selectedAppIds
        .map(
          (identifier) => normalizePokrovSelectedAppIdentifier(
            identifier,
            hostPlatform: widget.appContext.hostPlatform,
          ),
        )
        .whereType<String>()
        .toSet()
        .take(128)
        .toList(growable: false);
    final effectiveState = restored.copyWith(
      preferredNodeCode: preferredCode,
      preferredVariantId: preferredVariantId,
      automaticNodeQuarantineUntil: <String, String>{
        for (final entry in restoredQuarantine.entries)
          entry.key: entry.value.toIso8601String(),
      },
      selectedAppIds: restoredSelectedAppIds,
    );
    setState(() {
      _clientExperience = effectiveState;
      _selectedAppIds
        ..clear()
        ..addAll(restoredSelectedAppIds);
      _preferredNodeCode = preferredCode;
      _preferredVariantId = preferredVariantId;
      _automaticNodeQuarantineUntil
        ..clear()
        ..addAll(restoredQuarantine);
      final restoredRouteMode = effectiveState.firstRouteScopeMode;
      if (effectiveState.firstRouteScopeConfirmed &&
          restoredRouteMode != null &&
          widget.appContext.runtimeProfile.supportedRouteModes.contains(
            restoredRouteMode,
          )) {
        _selectedRouteMode = restoredRouteMode;
      }
      if (_locationsCatalog == null && effectiveState.cachedLocations != null) {
        _locationsCatalog = effectiveState.cachedLocations;
        _locationsUsingCache = true;
      }
      if (_notificationsInbox == null &&
          effectiveState.cachedNotifications != null) {
        _notificationsInbox = effectiveState.cachedNotifications;
        _notificationsUnread = effectiveState.cachedNotifications!.unreadCount;
        _notificationsUsingCache = true;
      }
    });
    unawaited(_refreshNotifications());
  }

  void _queueClientExperienceWrite() {
    final snapshot = _clientExperience;
    // A local interaction can complete before the startup read does. Treat
    // that delayed snapshot as stale instead of replacing the user's choice.
    _clientExperienceRevision += 1;
    _clientExperienceWriteQueue = _clientExperienceWriteQueue
        .then((_) => _clientExperienceStore.write(snapshot))
        .catchError((Object _) {
      // Local convenience state must never block or crash the VPN shell.
    });
  }

  void _recordProtectionEvent({
    required String kind,
    required String title,
    required String detail,
    required PokrovProtectionEventTone tone,
  }) {
    if (!mounted) {
      return;
    }
    final now = DateTime.now().toUtc();
    final event = PokrovProtectionEvent(
      id: '${now.microsecondsSinceEpoch}-$kind',
      kind: kind,
      title: title,
      detail: detail,
      occurredAt: now.toIso8601String(),
      tone: tone,
    );
    setState(() {
      _clientExperience = _clientExperience.copyWith(
        protectionEvents: <PokrovProtectionEvent>[
          event,
          ..._clientExperience.protectionEvents,
        ].take(20).toList(growable: false),
      );
    });
    _queueClientExperienceWrite();
  }

  String? _addPostConnectShortcut(String label, String href) {
    if (_clientExperience.postConnectShortcuts.length >= 6) {
      return 'Можно сохранить не больше 6 ярлыков.';
    }
    final shortcut = PokrovPostConnectShortcut.tryCreate(
      label: label,
      href: href,
    );
    if (shortcut == null) {
      return 'Укажите короткое название и полный адрес https://…';
    }
    if (_clientExperience.postConnectShortcuts.any(
      (item) => item.href == shortcut.href,
    )) {
      return 'Такой адрес уже сохранён.';
    }
    setState(() {
      _clientExperience = _clientExperience.copyWith(
        postConnectShortcuts: <PokrovPostConnectShortcut>[
          ..._clientExperience.postConnectShortcuts,
          shortcut,
        ],
      );
    });
    _queueClientExperienceWrite();
    return null;
  }

  void _removePostConnectShortcut(String id) {
    setState(() {
      _clientExperience = _clientExperience.copyWith(
        postConnectShortcuts: _clientExperience.postConnectShortcuts
            .where((item) => item.id != id)
            .toList(growable: false),
      );
    });
    _queueClientExperienceWrite();
  }

  Future<bool> _openPostConnectShortcut(PokrovPostConnectShortcut shortcut) {
    final stillOwned = _clientExperience.postConnectShortcuts.any(
      (item) => item.id == shortcut.id && item.href == shortcut.href,
    );
    if (!stillOwned) {
      return Future<bool>.value(false);
    }
    return _launchExternalHandoff(shortcut.href);
  }

  void _selectRouteMode(RouteMode mode) {
    // Same selection tick as the theme and location picks — one class of
    // interaction, one haptic.
    HapticFeedback.selectionClick();
    final wasConnected = _runtimeSnapshot?.phase == RuntimePhase.running;
    setState(() {
      _selectedRouteMode = mode;
      _managedProfileDirty = true;
      _cachedProfileFallbackGate.markUserChange();
      _clientExperience = _clientExperience.copyWith(
        firstRouteScopeConfirmed: true,
        firstRouteScopeMode: mode,
      );
    });
    _invalidateQuickSettingsProfile();
    _queueClientExperienceWrite();
    if (wasConnected && !_selectedAppsRouteNeedsSelection) {
      unawaited(
        _reconnectAfterManagedProfileChange(
          progressMessage: 'Применяем новый режим маршрутизации…',
          successMessage: 'Режим маршрутизации применён.',
        ),
      );
    }
  }

  void _setRoutingPreferences(PokrovRoutingPreferences preferences) {
    HapticFeedback.selectionClick();
    setState(() {
      _clientExperience = _clientExperience.copyWith(
        routingPreferences: preferences,
      );
      _managedProfileDirty = true;
      _cachedProfileFallbackGate.markUserChange();
      _runtimeHeadline =
          'Правила сохранены. Применим при следующем подключении.';
    });
    _invalidateQuickSettingsProfile();
    _queueClientExperienceWrite();
    if (preferences.pauseOnTrustedWifi) {
      unawaited(_pauseRunningTunnelOnTrustedWifi());
    }
  }

  Future<void> _setPreferredLocation(
    String nodeCode,
    String variantId,
  ) async {
    final smartConnect = _smartConnectProfile;
    final normalized = nodeCode.trim().toLowerCase();
    final normalizedVariant = normalizeClientLocationVariantId(variantId);
    ClientLocationCity? catalogCity;
    for (final country
        in _locationsCatalog?.countries ?? const <ClientLocationCountry>[]) {
      for (final city in country.cities) {
        if (city.code.trim().toLowerCase() == normalized) {
          catalogCity = city;
          break;
        }
      }
      if (catalogCity != null) {
        break;
      }
    }
    final knownCatalogCode = catalogCity != null;
    final catalogConfirmsVariant = catalogCity == null
        ? normalizedVariant == 'direct'
        : catalogCity.variants.isEmpty
            ? normalizedVariant == 'direct'
            : catalogCity.variants.any(
                (variant) =>
                    variant.id == normalizedVariant && variant.available,
              );
    if (normalized.isEmpty ||
        normalizedVariant == null ||
        !catalogConfirmsVariant ||
        _nodePreferenceBusy ||
        (smartConnect == null && !knownCatalogCode)) {
      return;
    }
    if (normalizedVariant != 'direct' &&
        _warpRuntimeConsent &&
        _managedWarpPolicy.canOfferRuntime) {
      const message =
          'WARP пока нельзя использовать с вариантом «Белые списки». Выключите WARP или выберите «Обычный».';
      setState(() {
        _runtimeHeadline = message;
      });
      showPokrovSnack(context, message, tone: PokrovSnackTone.danger);
      return;
    }

    PokrovHaptics.tap();
    _cancelAutomaticFailover();
    final wasConnected = _runtimeSnapshot?.phase == RuntimePhase.running;
    final previousPreferredNodeCode = _preferredNodeCode;
    final previousPreferredVariantId = _preferredVariantId;
    final previousStagedNodeCode = _stagedNodeCode;
    final previousStagedVariantId = _stagedVariantId;
    final previousManagedProfileDirty = _managedProfileDirty;
    final previousHeadline = _runtimeHeadline;
    final experienceAtRequest = _clientExperience;
    setState(() {
      _nodePreferenceBusy = true;
    });
    try {
      var confirmed = normalized;
      final service = _nodePreferenceService;
      if (service != null && smartConnect != null) {
        final result = await service.setPreferredSmartConnectNode(
          hostPlatform: widget.appContext.hostPlatform,
          smartConnect: smartConnect,
          nodeCode: normalized,
        );
        if (!mounted) {
          return;
        }
        confirmed = result.preferredNodeCode.trim().toLowerCase();
        if (confirmed.isEmpty) {
          throw const BootstrapFailure('Не удалось подтвердить локацию.');
        }
      }
      if (!mounted) {
        return;
      }
      final confirmedVariant =
          confirmed == normalized ? normalizedVariant : 'direct';
      final recentCodes = <String>[
        confirmed,
        ..._clientExperience.recentNodeCodes.where((item) => item != confirmed),
      ].take(12).toList(growable: false);
      setState(() {
        _preferredNodeCode = confirmed;
        _preferredVariantId = confirmedVariant;
        _stagedNodeCode = '';
        _stagedVariantId = 'direct';
        _managedProfileDirty = true;
        _cachedProfileFallbackGate.markUserChange();
        _runtimeHeadline = wasConnected
            ? 'Локация сохранена. Переподключите POKROV, чтобы применить.'
            : 'Локация сохранена. Подключите POKROV, чтобы применить.';
        _clientExperience = _clientExperience.copyWith(
          recentNodeCodes: recentCodes,
          preferredNodeCode: confirmed,
          preferredVariantId: confirmedVariant,
        );
      });
      _invalidateQuickSettingsProfile();
      _queueClientExperienceWrite();
      if (wasConnected) {
        await _reconnectAfterManagedProfileChange(
          progressMessage: 'Переключаем локацию…',
          successMessage: 'Локация применена.',
        );
      } else {
        showPokrovSnack(
          context,
          'Локация сохранена. Подключите POKROV.',
          tone: PokrovSnackTone.success,
        );
      }
    } on BootstrapFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _preferredNodeCode = identical(_clientExperience, experienceAtRequest)
            ? previousPreferredNodeCode
            : _clientExperience.preferredNodeCode;
        _preferredVariantId = identical(_clientExperience, experienceAtRequest)
            ? previousPreferredVariantId
            : _clientExperience.preferredVariantId;
        _stagedNodeCode = previousStagedNodeCode;
        _stagedVariantId = previousStagedVariantId;
        _managedProfileDirty = previousManagedProfileDirty;
        _runtimeHeadline = previousHeadline;
      });
      showPokrovSnack(context, error.message, tone: PokrovSnackTone.danger);
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
        _preferredNodeCode = identical(_clientExperience, experienceAtRequest)
            ? previousPreferredNodeCode
            : _clientExperience.preferredNodeCode;
        _preferredVariantId = identical(_clientExperience, experienceAtRequest)
            ? previousPreferredVariantId
            : _clientExperience.preferredVariantId;
        _stagedNodeCode = previousStagedNodeCode;
        _stagedVariantId = previousStagedVariantId;
        _managedProfileDirty = previousManagedProfileDirty;
        _runtimeHeadline = previousHeadline;
      });
      showPokrovSnack(
        context,
        'Не удалось сохранить локацию. Проверьте подключение и попробуйте ещё раз.',
        tone: PokrovSnackTone.danger,
      );
    } finally {
      if (mounted) {
        setState(() {
          _nodePreferenceBusy = false;
        });
      }
    }
  }

  void _toggleFavoriteLocation(String nodeCode) {
    final normalized = nodeCode.trim().toLowerCase();
    if (normalized.isEmpty) {
      return;
    }
    PokrovHaptics.tap();
    final next = <String>[..._clientExperience.favoriteNodeCodes];
    if (next.contains(normalized)) {
      next.remove(normalized);
    } else {
      next.insert(0, normalized);
    }
    setState(() {
      _clientExperience = _clientExperience.copyWith(
        favoriteNodeCodes: next.take(50).toList(growable: false),
      );
    });
    _queueClientExperienceWrite();
  }

  void _saveEmergencyPreferences({
    required bool manualLimitedNetwork,
    required String disclosureRevision,
    required String reserveId,
    required EmergencyChainMode chainMode,
  }) {
    setState(() {
      _clientExperience = _clientExperience.copyWith(
        emergencyManualLimitedNetwork: manualLimitedNetwork,
        emergencyDisclosureRevision: disclosureRevision,
        emergencyReserveId: reserveId,
        emergencyChainMode: chainMode.wireValue,
      );
    });
    _queueClientExperienceWrite();
  }

  Future<void> _openEmergencyNetwork() async {
    final service = _emergencyNetworkService;
    if (service == null) {
      showPokrovSnack(
        context,
        'Экстренная сеть недоступна в этой версии приложения.',
        tone: PokrovSnackTone.danger,
      );
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => _EmergencyNetworkSurface(
          appContext: widget.appContext,
          service: service,
          initialManualLimitedNetwork:
              _clientExperience.emergencyManualLimitedNetwork,
          acceptedDisclosureRevision:
              _clientExperience.emergencyDisclosureRevision,
          initialReserveId: _clientExperience.emergencyReserveId,
          initialChainMode: EmergencyChainMode.tryParse(
                _clientExperience.emergencyChainMode,
              ) ??
              EmergencyChainMode.reserveDirect,
          onPreferencesChanged: _saveEmergencyPreferences,
          onConnect: _connectEmergencyProfile,
        ),
      ),
    );
  }

  Future<void> _connectEmergencyProfile({
    required EmergencyCatalog catalog,
    required EmergencyReserve reserve,
    required EmergencyChainMode chainMode,
    required bool manualLimitedNetwork,
  }) async {
    final service = _emergencyNetworkService;
    if (service == null) {
      throw const BootstrapFailure('Экстренная сеть недоступна.');
    }
    if (_runtimeBusy) {
      throw const BootstrapFailure(
          'POKROV уже меняет подключение. Подождите немного.');
    }
    setState(() {
      _runtimeBusy = true;
      _runtimeDisconnecting = _runtimeSnapshot?.phase == RuntimePhase.running;
      _runtimeHeadline = 'Готовим экстренный маршрут…';
    });
    try {
      RuntimeSnapshot current = _runtimeSnapshot ??
          await _withRuntimeActionTimeout('snapshot', _runtimeEngine.snapshot);
      if (current.phase == RuntimePhase.running) {
        current = await _withRuntimeActionTimeout(
          'disconnectEmergencyPrevious',
          _runtimeEngine.disconnect,
        );
        current = await _settleRuntimeDisconnectTransition(current);
      }
      if (current.canInitialize &&
          current.phase == RuntimePhase.artifactReady) {
        current = await _withRuntimeActionTimeout(
          'initializeEmergency',
          _runtimeEngine.initialize,
        );
      }
      final candidates = <EmergencyReserve>[
        reserve,
        ...catalog.items.where(
          (item) =>
              item.id != reserve.id &&
              item.available &&
              item.modes.contains(chainMode),
        ),
      ];
      AppFirstEmergencyProfileResult? connectedResult;
      EmergencyReserve? connectedReserve;
      for (var index = 0; index < candidates.length; index += 1) {
        final candidate = candidates[index];
        final result = await service.resolveEmergencyProfile(
          hostPlatform: widget.appContext.hostPlatform,
          catalogRevision: catalog.revision,
          reserveId: candidate.id,
          chainMode: chainMode,
          manualLimitedNetwork: manualLimitedNetwork,
        );
        current = await _withRuntimeActionTimeout(
          'stageEmergencyProfile',
          () => _runtimeEngine.stageManagedProfile(result.managedProfile),
        );
        current = await _withRuntimeActionTimeout(
          'connectEmergency',
          _runtimeEngine.connect,
        );
        current = await _settleRuntimeTransition(current);
        if (current.phase == RuntimePhase.running) {
          connectedResult = result;
          connectedReserve = candidate;
          break;
        }
        final emergencyEndpointUnavailable =
            widget.appContext.hostPlatform == HostPlatform.android &&
                current.lastFailureKind?.trim() ==
                    'emergency_endpoint_unreachable';
        if (!emergencyEndpointUnavailable) {
          throw BootstrapFailure(
            current.message.trim().isEmpty
                ? 'Экстренный маршрут не подключился.'
                : current.message,
          );
        }
        if (index + 1 >= candidates.length) {
          break;
        }
        current = await _withRuntimeActionTimeout(
          'disconnectUnavailableEmergencyReserve',
          _runtimeEngine.disconnect,
        );
        current = await _settleRuntimeDisconnectTransition(current);
      }
      if (connectedResult == null || connectedReserve == null) {
        throw const BootstrapFailure(
          'Ни один сохранённый резерв не доступен в текущей сети.',
          code: 'emergency_reserves_unreachable',
        );
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _runtimeSnapshot = current;
        _runtimeHeadline = connectedResult!.usingCache
            ? 'Экстренная сеть подключена по подписанной офлайн-копии.'
            : 'Экстренная сеть подключена.';
        _managedProfileDirty = true;
        _stagedProfileUsesWarp = false;
        _activeConnectUsedWarp = false;
        _stagedNodeCode = '';
        _stagedVariantId = 'direct';
        _activeNodeCode = '';
        _activeVariantId = 'direct';
      });
      if (connectedReserve.id != reserve.id) {
        _saveEmergencyPreferences(
          manualLimitedNetwork: manualLimitedNetwork,
          disclosureRevision: catalog.disclosureRevision,
          reserveId: connectedReserve.id,
          chainMode: chainMode,
        );
      }
      _cachedProfileFallbackGate.markUserChange();
      _recordProtectionEvent(
        kind: 'emergency_connected',
        title: 'Экстренная сеть подключена',
        detail: '${chainMode.label} · резерв ${connectedReserve.ordinal}',
        tone: PokrovProtectionEventTone.warning,
      );
    } finally {
      if (mounted) {
        setState(() {
          _runtimeBusy = false;
          _runtimeDisconnecting = false;
        });
      }
    }
  }

  void _addSelectedAppId(String value) {
    final normalized = normalizePokrovSelectedAppIdentifier(
      value,
      hostPlatform: widget.appContext.hostPlatform,
    );
    if (normalized == null || _selectedAppIds.contains(normalized)) {
      return;
    }
    if (_selectedAppIds.length >= 128) {
      setState(() {
        _runtimeHeadline =
            'Можно выбрать не больше 128 приложений. Удалите одно, чтобы добавить другое.';
      });
      showPokrovSnack(
        context,
        'Можно выбрать не больше 128 приложений. Удалите одно, чтобы добавить другое.',
        tone: PokrovSnackTone.danger,
      );
      return;
    }
    final wasConnected = _runtimeSnapshot?.phase == RuntimePhase.running;
    setState(() {
      _selectedAppIds.add(normalized);
      if (_selectedRouteMode != RouteMode.excludedApps &&
          widget.appContext.runtimeProfile.supportedRouteModes.contains(
            RouteMode.selectedApps,
          )) {
        _selectedRouteMode = RouteMode.selectedApps;
      }
      _managedProfileDirty = true;
      _cachedProfileFallbackGate.markUserChange();
      _clientExperience = _clientExperience.copyWith(
        selectedAppIds: List<String>.unmodifiable(_selectedAppIds),
      );
    });
    _invalidateQuickSettingsProfile();
    _queueClientExperienceWrite();
    if (wasConnected && !_selectedAppsRouteNeedsSelection) {
      unawaited(
        _reconnectAfterManagedProfileChange(
          progressMessage: 'Применяем список приложений…',
          successMessage: 'Список приложений применён.',
        ),
      );
    }
  }

  void _applyRuAppPreset(RouteMode mode, List<String> appIds) {
    if (mode != RouteMode.selectedApps && mode != RouteMode.excludedApps) {
      return;
    }
    if (!widget.appContext.runtimeProfile.supportedRouteModes.contains(mode)) {
      return;
    }
    final normalized = appIds
        .map(
          (value) => normalizePokrovSelectedAppIdentifier(
            value,
            hostPlatform: widget.appContext.hostPlatform,
          ),
        )
        .whereType<String>()
        .where((value) => pokrovRuAppCatalogEntry(value) != null)
        .toSet()
        .take(128)
        .toList(growable: false);
    if (normalized.isEmpty) {
      showPokrovSnack(
        context,
        'На устройстве не найдено приложений из RU-каталога.',
        tone: PokrovSnackTone.danger,
      );
      return;
    }
    final wasConnected = _runtimeSnapshot?.phase == RuntimePhase.running;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedRouteMode = mode;
      _selectedAppIds
        ..clear()
        ..addAll(normalized);
      _managedProfileDirty = true;
      _cachedProfileFallbackGate.markUserChange();
      _clientExperience = _clientExperience.copyWith(
        selectedAppIds: List<String>.unmodifiable(_selectedAppIds),
        firstRouteScopeConfirmed: true,
        firstRouteScopeMode: mode,
      );
      _runtimeHeadline = mode == RouteMode.excludedApps
          ? 'RU-приложения пойдут напрямую, остальные — через VPN.'
          : 'Только выбранные RU-приложения пойдут через VPN.';
    });
    _invalidateQuickSettingsProfile();
    _queueClientExperienceWrite();
    if (wasConnected) {
      unawaited(
        _reconnectAfterManagedProfileChange(
          progressMessage: 'Применяем RU-пресет…',
          successMessage: 'RU-пресет применён.',
        ),
      );
    } else {
      showPokrovSnack(
        context,
        'RU-пресет сохранён. Подключите POKROV.',
        tone: PokrovSnackTone.success,
      );
    }
  }

  Future<void> _setAutomaticLocation() async {
    if (_nodePreferenceBusy || _preferredNodeCode.trim().isEmpty) {
      return;
    }

    PokrovHaptics.tap();
    _cancelAutomaticFailover();
    final wasConnected = _runtimeSnapshot?.phase == RuntimePhase.running;
    setState(() {
      _preferredNodeCode = '';
      _preferredVariantId = 'direct';
      _stagedNodeCode = '';
      _stagedVariantId = 'direct';
      _managedProfileDirty = true;
      _cachedProfileFallbackGate.markUserChange();
      _runtimeHeadline = wasConnected
          ? 'Автоматический выбор включен. Переподключите POKROV, чтобы применить.'
          : 'Автоматический выбор включен. Подключите POKROV, чтобы применить.';
      _clientExperience = _clientExperience.copyWith(
        preferredNodeCode: '',
        preferredVariantId: 'direct',
      );
    });
    _invalidateQuickSettingsProfile();
    _queueClientExperienceWrite();
    if (wasConnected) {
      await _reconnectAfterManagedProfileChange(
        progressMessage: 'Включаем автоматический выбор…',
        successMessage: 'Автоматический выбор применён.',
      );
    } else {
      showPokrovSnack(
        context,
        'Автоматический выбор включен. Подключите POKROV.',
        tone: PokrovSnackTone.success,
      );
    }
  }

  void _removeSelectedAppId(String value) {
    final wasConnected = _runtimeSnapshot?.phase == RuntimePhase.running;
    setState(() {
      _selectedAppIds.remove(value);
      _managedProfileDirty = true;
      _cachedProfileFallbackGate.markUserChange();
      _clientExperience = _clientExperience.copyWith(
        selectedAppIds: List<String>.unmodifiable(_selectedAppIds),
      );
    });
    _invalidateQuickSettingsProfile();
    _queueClientExperienceWrite();
    if (wasConnected && !_selectedAppsRouteNeedsSelection) {
      unawaited(
        _reconnectAfterManagedProfileChange(
          progressMessage: 'Применяем список приложений…',
          successMessage: 'Список приложений применён.',
        ),
      );
    }
  }

  Future<bool> _reconnectAfterManagedProfileChange({
    required String progressMessage,
    required String successMessage,
  }) async {
    if (!mounted || _runtimeSnapshot?.phase != RuntimePhase.running) {
      return false;
    }
    if (_runtimeBusy) {
      setState(() {
        _runtimeHeadline =
            'Настройки сохранены. Применим после текущего действия.';
      });
      return false;
    }
    setState(() {
      _runtimeHeadline = progressMessage;
    });
    await _toggleRuntime(reconnectAfterDisconnect: true);
    if (!mounted) {
      return false;
    }
    final applied = _runtimeSnapshot?.phase == RuntimePhase.running;
    if (applied) {
      setState(() {
        _runtimeHeadline = successMessage;
      });
      showPokrovSnack(
        context,
        successMessage,
        tone: PokrovSnackTone.success,
      );
    } else {
      showPokrovSnack(
        context,
        'Настройки сохранены, но подключение не восстановлено. Нажмите «Подключить».',
        tone: PokrovSnackTone.danger,
      );
    }
    return applied;
  }

  bool get _selectedAppsRouteNeedsSelection =>
      (_selectedRouteMode == RouteMode.selectedApps ||
          _selectedRouteMode == RouteMode.excludedApps) &&
      _selectedAppIds.isEmpty;

  void _openRulesForSelectedApps() {
    setState(() {
      _selectedIndex = SeedTab.rules.index;
      _runtimeHeadline =
          'Выберите хотя бы одно приложение в разделе «Правила».';
    });
    showPokrovSnack(
      context,
      'Выберите хотя бы одно приложение в разделе «Правила».',
      tone: PokrovSnackTone.danger,
    );
  }

  void _selectTab(SeedTab tab) {
    setState(() {
      _selectedIndex = tab.index;
    });
    if (tab == SeedTab.locations) {
      unawaited(_refreshLocationsCatalog());
    }
    if (tab == SeedTab.profile && widget.bootstrapper != null) {
      unawaited(_refreshAccountSummary());
      unawaited(_refreshNotifications());
    }
  }

  Future<void> _refreshLocationsCatalog({bool measureDevice = false}) async {
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
      final serverCatalog = await service.fetchLocationsCatalog(
        hostPlatform: widget.appContext.hostPlatform,
      );
      final measurements = measureDevice
          ? await (widget.nodeLatencyProbe ?? measurePokrovNodeLatencies)(
              widget.appContext.hostPlatform,
              pokrovLocationLatencyTargets(serverCatalog),
            )
          : const <String, int>{};
      final catalog = applyPokrovDeviceLatencies(
        serverCatalog,
        measurements,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _locationsCatalog = catalog;
        _locationsCatalogError = null;
        _locationsUsingCache = false;
        _clientExperience = _clientExperience.copyWith(
          cachedLocations: catalog,
          locationsCachedAt: DateTime.now().toUtc().toIso8601String(),
        );
      });
      _queueClientExperienceWrite();
    } on BootstrapFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _locationsCatalogError = error.message;
        _locationsUsingCache = _locationsCatalog != null;
      });
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
        _locationsCatalogError =
            'Не удалось обновить список локаций. Проверьте соединение и попробуйте ещё раз.';
        _locationsUsingCache = _locationsCatalog != null;
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
      if (const {'trialPremium', 'paidUnlimited'}.contains(info.lane)) {
        final emergencyService = _emergencyNetworkService;
        if (emergencyService != null) {
          unawaited(
            emergencyService
                .prepareEmergencyOfflineCache(
                  hostPlatform: widget.appContext.hostPlatform,
                  manualLimitedNetwork:
                      _clientExperience.emergencyManualLimitedNetwork,
                )
                .catchError((Object _) {}),
          );
        }
      }
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
        _notificationsUsingCache = false;
        _clientExperience = _clientExperience.copyWith(
          cachedNotifications: inbox,
          notificationsCachedAt: DateTime.now().toUtc().toIso8601String(),
        );
      });
      _queueClientExperienceWrite();
    } on Object {
      // Notifications are best-effort; keep the last known inbox.
      if (mounted) {
        setState(() {
          _notificationsUsingCache = _notificationsInbox != null;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _notificationsBusy = false;
        });
      }
    }
  }

  void _markNotificationsRead() {
    final inbox = _notificationsInbox;
    final unreadIds = inbox?.items
            .where((item) => !item.read)
            .map((item) => item.id)
            .where((id) => id.trim().isNotEmpty)
            .toList(growable: false) ??
        const <String>[];
    if (_notificationsUnread > 0) {
      setState(() {
        _notificationsUnread = 0;
        if (inbox != null) {
          final updated = ClientNotificationInbox(
            items: inbox.items
                .map(
                  (item) => ClientNotificationItem(
                    id: item.id,
                    kind: item.kind,
                    title: item.title,
                    body: item.body,
                    createdAt: item.createdAt,
                    ctaLabel: item.ctaLabel,
                    ctaHref: item.ctaHref,
                    read: true,
                  ),
                )
                .toList(growable: false),
            nextCursor: inbox.nextCursor,
            unreadCount: 0,
          );
          _notificationsInbox = updated;
          _clientExperience = _clientExperience.copyWith(
            cachedNotifications: updated,
          );
        }
      });
      _queueClientExperienceWrite();
    }
    final service = _clientDataService;
    if (service == null || unreadIds.isEmpty) {
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

  void _openNotificationsInbox() {
    _markNotificationsRead();
    _showNotificationsSheet(
      context,
      notifications:
          _notificationsInbox?.items ?? const <ClientNotificationItem>[],
      usingCache: _notificationsUsingCache,
      cachedAt: _clientExperience.notificationsCachedAt,
      onRefresh: _refreshNotifications,
      onOpenHandoff: _showSeedHandoff,
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

  Future<ClientDevicePairingCode> _issueDevicePairingCode() async {
    final service = _clientDataService;
    if (service == null) {
      throw const BootstrapFailure(
        'Коды устройств недоступны в этой сборке.',
      );
    }
    return service.issueDevicePairingCode(
      hostPlatform: widget.appContext.hostPlatform,
    );
  }

  Future<bool> _cancelDevicePairingCode(String pairingId) async {
    final service = _clientDataService;
    if (service == null) {
      return false;
    }
    return service.cancelDevicePairingCode(
      hostPlatform: widget.appContext.hostPlatform,
      pairingId: pairingId,
    );
  }

  @override
  void dispose() {
    _seedShellDisposed = true;
    _managedProfileInvalidationGeneration += 1;
    _managedProfileInvalidationTimer?.cancel();
    _managedProfileInvalidationTimer = null;
    final pendingInvalidation = _managedProfileInvalidationCompletion;
    if (pendingInvalidation != null && !pendingInvalidation.isCompleted) {
      pendingInvalidation.complete(false);
    }
    _managedProfileInvalidationCompletion = null;
    unawaited(_acquisitionUriSubscription?.cancel());
    _acquisitionUriSubscription = null;
    WidgetsBinding.instance.removeObserver(this);
    _cancelPostConnectHostHealthPolling();
    widget.shellController?._detach();
    _firstLaunchRestoreCodeController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_resumeRuntimeAndTrustedWifiChecks());
      unawaited(_checkForClientUpdate());
      unawaited(_refreshNotifications());
    }
  }

  Future<void> _resumeRuntimeAndTrustedWifiChecks() async {
    if (_runtimeResumeRefreshPending) {
      return;
    }
    _runtimeResumeRefreshPending = true;
    try {
      // Android permission sheets can resume Flutter while the original connect
      // call is still settling. Wait for that call to finish, then read the
      // native state again instead of leaving the pre-permission snapshot on
      // screen. The wait is bounded so a stuck host action never blocks a
      // normal foreground resume.
      for (var attempt = 0;
          mounted && _runtimeBusy && attempt < 80;
          attempt += 1) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      if (!mounted || _runtimeBusy) {
        return;
      }

      var snapshot = await _runRuntimeAction(_runtimeEngine.snapshot);
      if (!mounted) {
        return;
      }
      if (snapshot.phase == RuntimePhase.configStaged &&
          snapshot.supportsLiveConnect &&
          !_isTerminalConnectMessage(snapshot.message)) {
        snapshot = await _settleRuntimeTransition(snapshot);
        if (!mounted) {
          return;
        }
        setState(() {
          _runtimeSnapshot = snapshot;
          _runtimeHeadline = null;
        });
        widget.shellController?.refresh();
      }
      await _pauseRunningTunnelOnTrustedWifi();
    } finally {
      _runtimeResumeRefreshPending = false;
    }
  }

  Future<PokrovWifiNetworkStatus> _readCurrentWifi() {
    final probe = widget.currentWifiProbe;
    if (probe != null) {
      return probe();
    }
    return probePokrovCurrentWifi(widget.appContext.hostPlatform);
  }

  Future<bool> _requestCurrentWifiPermission() {
    final requester = widget.wifiPermissionRequester;
    if (requester != null) {
      return requester();
    }
    return requestPokrovWifiPermission(widget.appContext.hostPlatform);
  }

  Future<bool> _openSystemVpnSettings() {
    final launcher = widget.vpnSettingsLauncher;
    if (launcher != null) {
      return launcher();
    }
    return openPokrovVpnSettings(widget.appContext.hostPlatform);
  }

  Future<void> _loadSystemSurfacePreferences() async {
    final preferences = await readPokrovSystemSurfacePreferences(
      widget.appContext.hostPlatform,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _systemSurfacePreferences = preferences;
    });
  }

  Future<bool> _updateSystemSurfacePreferences(
    PokrovSystemSurfacePreferences preferences,
  ) async {
    final saved = await updatePokrovSystemSurfacePreferences(
      widget.appContext.hostPlatform,
      preferences,
    );
    if (saved == null || !mounted) {
      return false;
    }
    setState(() {
      _systemSurfacePreferences = saved;
    });
    return true;
  }

  Future<PokrovWifiNetworkStatus?> _activeTrustedWifi() async {
    final preferences = _clientExperience.routingPreferences;
    if (!preferences.pauseOnTrustedWifi ||
        preferences.trustedWifiNames.isEmpty) {
      return null;
    }
    final status = await _readCurrentWifi();
    return status.matches(preferences.trustedWifiNames) ? status : null;
  }

  Future<bool> _blockConnectOnTrustedWifi() async {
    final trusted = await _activeTrustedWifi();
    if (trusted == null || !mounted) {
      return false;
    }
    final name = trusted.name?.trim();
    final message = name == null || name.isEmpty
        ? 'Подключение остановлено в доверенной Wi-Fi сети.'
        : 'Подключение остановлено в доверенной сети «$name».';
    setState(() {
      _runtimeHeadline =
          '$message Отключите паузу в правилах для ручного подключения.';
    });
    showPokrovSnack(context, message, tone: PokrovSnackTone.info);
    return true;
  }

  Future<void> _pauseRunningTunnelOnTrustedWifi() async {
    if (!mounted ||
        _runtimeBusy ||
        _runtimeSnapshot?.phase != RuntimePhase.running) {
      return;
    }
    final trusted = await _activeTrustedWifi();
    if (!mounted ||
        trusted == null ||
        _runtimeBusy ||
        _runtimeSnapshot?.phase != RuntimePhase.running) {
      return;
    }

    setState(() {
      _runtimeBusy = true;
      _runtimeDisconnecting = true;
    });
    widget.shellController?.refresh();
    try {
      var current = await _withRuntimeActionTimeout(
        'trustedWifiDisconnect',
        _runtimeEngine.disconnect,
      );
      current = await _settleRuntimeDisconnectTransition(current);
      if (!mounted) {
        return;
      }
      final name = trusted.name?.trim();
      setState(() {
        _runtimeSnapshot = current;
        _runtimeHeadline = name == null || name.isEmpty
            ? 'POKROV поставлен на паузу в доверенной Wi-Fi сети.'
            : 'POKROV поставлен на паузу в сети «$name».';
      });
      _recordProtectionEvent(
        kind: 'trusted_wifi_pause',
        title: 'Пауза в доверенной сети',
        detail: name == null || name.isEmpty
            ? 'Туннель остановлен правилом trusted Wi-Fi.'
            : 'Туннель остановлен правилом для сети «$name».',
        tone: PokrovProtectionEventTone.neutral,
      );
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _runtimeHeadline = _runtimeUnexpectedErrorMessage(error);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _runtimeBusy = false;
          _runtimeDisconnecting = false;
        });
      }
      widget.shellController?.refresh();
    }
  }

  Future<bool> _launchExternalHandoff(Uri uri) {
    final launcher = widget.handoffLauncher ??
        (Uri target) => launchUrl(target, mode: LaunchMode.externalApplication);
    return launcher(uri);
  }

  Future<bool> _launchWebHandoff(Uri uri, {String title = 'POKROV'}) async {
    final injected = widget.handoffLauncher;
    if (injected != null) {
      return injected(uri);
    }
    final isWeb = uri.scheme.toLowerCase() == 'https' ||
        uri.scheme.toLowerCase() == 'http';
    if (isWeb &&
        widget.appContext.hostPlatform == HostPlatform.android &&
        await openPokrovInAppWebSurface(
          widget.appContext.hostPlatform,
          uri,
          title: title,
        )) {
      return true;
    }
    final mode = isWeb &&
            (widget.appContext.hostPlatform == HostPlatform.android ||
                widget.appContext.hostPlatform == HostPlatform.ios)
        ? LaunchMode.inAppBrowserView
        : LaunchMode.externalApplication;
    return launchUrl(uri, mode: mode);
  }

  Future<void> _openDevicePairingBot() async {
    final configured = widget.appContext.mainBotUsername
        .trim()
        .replaceFirst(RegExp(r'^@+'), '');
    final username = RegExp(r'^[A-Za-z0-9_]{5,64}$').hasMatch(configured)
        ? configured
        : 'pokrov_vpnbot';
    final nativeUri = Uri(
      scheme: 'tg',
      host: 'resolve',
      queryParameters: <String, String>{
        'domain': username,
        'start': 'pair_device',
      },
    );
    if (await _launchExternalHandoff(nativeUri)) {
      return;
    }
    final webUri = Uri.https(
      't.me',
      '/$username',
      const <String, String>{'start': 'pair_device'},
    );
    final opened = await _launchExternalHandoff(webUri);
    if (!mounted || opened) {
      return;
    }
    showPokrovSnack(
      context,
      'Не удалось открыть бота. Найдите @$username в Telegram.',
      tone: PokrovSnackTone.danger,
    );
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
        currentVersion: pokrovClientVersion,
        channel: 'stable',
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
      // House sheet language instead of a stock Material dialog: drag
      // handle, rounded top, PokrovPressable primary action — the same
      // pattern as the WARP and profile sheets.
      await showModalBottomSheet<void>(
        context: context,
        // Honest affordances: a required update shows no drag handle and
        // cannot be swiped away.
        showDragHandle: !update.isRequired,
        isScrollControlled: true,
        isDismissible: !update.isRequired,
        enableDrag: !update.isRequired,
        sheetAnimationStyle: _pokrovSheetAnimationStyle(context),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (sheetContext) {
          final p = PokrovPalette.of(sheetContext);
          final theme = Theme.of(sheetContext);
          return SafeArea(
            top: false,
            child: Container(
              key: const ValueKey('client-update-prompt'),
              width: double.infinity,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.82,
              ),
              padding: EdgeInsets.fromLTRB(
                22,
                update.isRequired ? 22 : 6,
                22,
                26,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: p.accent.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.system_update_alt_rounded,
                            color: p.accent,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Text(
                            title,
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: p.ink,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      version.isEmpty
                          ? 'Установите свежую версию, чтобы получить исправления и актуальные правила.'
                          : 'Свежая версия: $version.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: p.muted,
                        height: 1.35,
                      ),
                    ),
                    if (notes.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        notes,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: p.muted,
                          height: 1.35,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: PokrovPressable(
                        child: FilledButton.icon(
                          key: const ValueKey('client-update-download'),
                          icon: const Icon(Icons.system_update_alt_rounded),
                          label: const Text('Обновить'),
                          onPressed: () {
                            Navigator.of(sheetContext).pop();
                            unawaited(_openClientUpdateDownload(update));
                          },
                        ),
                      ),
                    ),
                    if (!update.isRequired) ...[
                      const SizedBox(height: 10),
                      Center(
                        child: TextButton(
                          key: const ValueKey('client-update-later'),
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          child: const Text('Позже'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      );
    } finally {
      _clientUpdatePromptVisible = false;
    }
  }

  Future<void> _openClientUpdateDownload(ClientAppUpdateInfo update) async {
    final uri = update.trustedHandoffUri;
    if (uri == null) {
      if (mounted) {
        showPokrovSnack(
          context,
          'Ссылка обновления отклонена. Попробуйте позже.',
          tone: PokrovSnackTone.danger,
        );
      }
      return;
    }
    if (widget.appContext.hostPlatform == HostPlatform.android) {
      final installer = widget.clientUpdateInstaller ??
          (ClientAppUpdateInfo value) => installPokrovClientUpdate(
                widget.appContext.hostPlatform,
                value,
              );
      final progressReader = widget.clientUpdateProgressReader ??
          (widget.clientUpdateInstaller == null
              ? () => readPokrovClientUpdateProgress(
                    widget.appContext.hostPlatform,
                  )
              : null);
      final progress = ValueNotifier<PokrovClientUpdateProgress>(
        PokrovClientUpdateProgress(
          phase: PokrovClientUpdateProgressPhase.preparing,
          downloadedBytes: 0,
          totalBytes: update.size,
        ),
      );
      var progressReadInFlight = false;
      var progressDisposed = false;
      Future<void> refreshProgress() async {
        if (progressReader == null ||
            progressReadInFlight ||
            progressDisposed) {
          return;
        }
        progressReadInFlight = true;
        try {
          final next = await progressReader();
          if (!progressDisposed) {
            progress.value = next;
          }
        } on Object {
          // Download completion still owns the final success or failure.
        } finally {
          progressReadInFlight = false;
        }
      }

      BuildContext? progressContext;
      final progressClosed = showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          progressContext = dialogContext;
          return AlertDialog(
            key: const ValueKey('client-update-download-progress'),
            title: const Text('Обновление POKROV'),
            content: SizedBox(
              width: 320,
              child: ValueListenableBuilder<PokrovClientUpdateProgress>(
                valueListenable: progress,
                builder: (context, value, _) {
                  final percent = value.percent;
                  final label = switch (value.phase) {
                    PokrovClientUpdateProgressPhase.downloading =>
                      percent == null
                          ? 'Скачиваем обновление…'
                          : 'Скачано $percent%',
                    PokrovClientUpdateProgressPhase.verifying =>
                      'Проверяем размер и целостность файла…',
                    PokrovClientUpdateProgressPhase.installing =>
                      'Открываем установку…',
                    PokrovClientUpdateProgressPhase.failed =>
                      'Не удалось завершить загрузку.',
                    PokrovClientUpdateProgressPhase.idle ||
                    PokrovClientUpdateProgressPhase.preparing =>
                      'Подготавливаем защищённую загрузку…',
                  };
                  final barValue =
                      value.phase == PokrovClientUpdateProgressPhase.downloading
                          ? value.fraction
                          : value.phase ==
                                  PokrovClientUpdateProgressPhase.installing
                              ? 1.0
                              : null;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LinearProgressIndicator(
                        key: const ValueKey('client-update-progress-bar'),
                        value: barValue,
                        minHeight: 7,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        label,
                        key: const ValueKey('client-update-progress-label'),
                      ),
                    ],
                  );
                },
              ),
            ),
          );
        },
      );
      await Future<void>.delayed(Duration.zero);
      unawaited(refreshProgress());
      final progressTimer = progressReader == null
          ? null
          : Timer.periodic(
              const Duration(milliseconds: 250),
              (_) => unawaited(refreshProgress()),
            );
      PokrovClientUpdateInstallStatus status;
      try {
        status = await installer(update);
      } on Object {
        status = PokrovClientUpdateInstallStatus.failed;
      }
      progressTimer?.cancel();
      await refreshProgress();
      if (!mounted) {
        progressDisposed = true;
        progress.dispose();
        return;
      }
      final dialogContext = progressContext;
      if (dialogContext != null && dialogContext.mounted) {
        Navigator.of(dialogContext).pop();
      } else {
        Navigator.of(context, rootNavigator: true).pop();
      }
      await progressClosed;
      progressDisposed = true;
      progress.dispose();
      switch (status) {
        case PokrovClientUpdateInstallStatus.installerOpened:
          showPokrovSnack(
            context,
            'Обновление проверено. Подтвердите установку в системном окне.',
            tone: PokrovSnackTone.success,
          );
        case PokrovClientUpdateInstallStatus.permissionRequired:
          showPokrovSnack(
            context,
            'Разрешите POKROV устанавливать обновления. Скачанный APK уже проверен.',
          );
        case PokrovClientUpdateInstallStatus.unsupported:
        case PokrovClientUpdateInstallStatus.failed:
          showPokrovSnack(
            context,
            'Не удалось скачать или проверить обновление. Попробуйте еще раз.',
            tone: PokrovSnackTone.danger,
          );
      }
      return;
    }
    final opened = await _launchExternalHandoff(uri);
    if (!mounted || opened) {
      return;
    }
    showPokrovSnack(
      context,
      'Не удалось открыть загрузку обновления. Попробуйте еще раз.',
      tone: PokrovSnackTone.danger,
    );
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

    final opened = uri.scheme == 'http' || uri.scheme == 'https'
        ? await _launchWebHandoff(uri)
        : await _launchExternalHandoff(uri);
    if (!mounted) {
      return;
    }
    if (!opened) {
      final fallback = _safeHandoffFallbackUri(label: label, value: value);
      if (fallback != null && fallback != uri) {
        final fallbackOpened = await _launchExternalHandoff(fallback);
        if (!mounted) {
          return;
        }
        if (fallbackOpened) {
          return;
        }
      }
      debugPrint('POKROV handoff open failed');
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
      PokrovHaptics.tap();
      if (_looksLikeDevicePairingCode(code)) {
        final paired = await accountActions.claimDevicePairingCode(
          hostPlatform: widget.appContext.hostPlatform,
          code: code,
        );
        if (!mounted) {
          return paired.ok;
        }
        setState(() {
          _managedProfileDirty = true;
          _subscriptionInfo = null;
          _runtimeHeadline = 'Устройство привязано к вашему аккаунту.';
        });
        unawaited(_loadBonusSummary(force: true));
        unawaited(_refreshSubscriptionInfo());
        unawaited(_refreshNotifications());
        unawaited(_refreshLocationsCatalog());
        showPokrovSnack(
          context,
          'Устройство привязано. Код больше не действует.',
          tone: PokrovSnackTone.success,
        );
        return paired.ok;
      }
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
    } on BootstrapFailure catch (error) {
      debugPrint('POKROV code action failed: ${error.statusCode ?? 0}');
      if (!mounted) {
        return false;
      }
      showPokrovSnack(
        context,
        error.message,
        tone: PokrovSnackTone.danger,
      );
      return false;
    } catch (error) {
      debugPrint('POKROV redeem code failed (${error.runtimeType})');
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

  bool _looksLikeDevicePairingCode(String value) {
    final normalized =
        value.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    return RegExp(r'^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{8}$')
        .hasMatch(normalized);
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
      final opened = await _launchWebHandoff(
        handoff.handoffUrl,
        title: 'Кабинет POKROV',
      );
      if (!mounted || opened) {
        return;
      }
      await _openSafeHandoff('cabinet', value);
    } catch (error) {
      debugPrint('POKROV cabinet handoff failed (${error.runtimeType})');
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
      PokrovHaptics.tap();
      final result = await bonusActions.createTelegramLink(
        hostPlatform: widget.appContext.hostPlatform,
      );
      final opened =
          result.linked ? true : await _launchExternalHandoff(result.botUrl);
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
      if (result.linked) {
        unawaited(_refreshSubscriptionInfo());
      }
    } catch (error) {
      debugPrint('POKROV telegram link failed (${error.runtimeType})');
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
      PokrovHaptics.tap();
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
      debugPrint('POKROV telegram bonus check failed (${error.runtimeType})');
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
      PokrovHaptics.tap();
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
      debugPrint('POKROV telegram bonus claim failed (${error.runtimeType})');
      if (!mounted) {
        return;
      }
      setState(() {
        _telegramBonusBusy = false;
        _telegramBonusError = error is BootstrapFailure &&
                error.statusCode == HttpStatus.forbidden &&
                error.message.trim().isNotEmpty
            ? error.message.trim()
            : 'Не удалось активировать бонус. Попробуйте еще раз.';
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
        PokrovHaptics.tap();
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
      debugPrint('POKROV bonus summary refresh failed (${error.runtimeType})');
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

  Future<AppFirstBonusRewardResult?> _spinBonusWheelInApp() {
    return _runBonusRewardInApp(
      actionName: 'Рулетка',
      run: (service) =>
          service.spinBonusWheel(hostPlatform: widget.appContext.hostPlatform),
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

  Future<AppFirstBonusRewardResult?> _runBonusRewardInApp({
    required String actionName,
    required Future<AppFirstBonusRewardResult> Function(
      AppFirstBonusActionService service,
    ) run,
  }) async {
    if (_bonusRewardBusy) {
      return null;
    }
    final bonusActions = _bonusActionService;
    if (bonusActions == null) {
      await _loadBonusSummary(force: true);
      return null;
    }

    setState(() {
      _bonusRewardBusy = true;
      _bonusSummaryError = null;
    });
    try {
      PokrovHaptics.tap();
      final result = await run(bonusActions);
      if (!mounted) {
        return null;
      }
      setState(() {
        _bonusRewardBusy = false;
        _bonusSummary = result.summary;
        _managedProfileDirty = true;
        _runtimeHeadline = '$actionName: награда активирована.';
      });
      final days = result.rewardDays;
      final discountPct = result.discountPct;
      showPokrovSnack(
        context,
        result.rewardKind == 'discount' && discountPct > 0
            ? '$actionName: скидка −$discountPct% сохранена для одного продления.'
            : days > 0
                ? '$actionName: +${ruDays(days)} к доступу.'
                : '$actionName: отметка сохранена.',
        tone: PokrovSnackTone.success,
      );
      return result;
    } catch (error) {
      debugPrint(
          'POKROV bonus reward failed ($actionName; ${error.runtimeType})');
      if (!mounted) {
        return null;
      }
      setState(() {
        _bonusRewardBusy = false;
        _bonusSummaryError = error is BootstrapFailure &&
                error.statusCode == HttpStatus.forbidden &&
                error.message.trim().isNotEmpty
            ? error.message.trim()
            : 'Не удалось получить награду. Попробуйте еще раз.';
      });
      final failureMessage = _bonusSummaryError!;
      showPokrovSnack(
        context,
        failureMessage,
        tone: PokrovSnackTone.danger,
      );
      return null;
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
    if (status.reason == 'active_paid_required') {
      return 'Telegram +5 дней доступен без оплаты';
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
    PokrovHaptics.tap();
    unawaited(_markFirstLaunchCompleted());
    setState(() {
      _firstLaunchExitAnimated = true;
      _firstLaunchStep = _FirstLaunchStep.ready;
    });
  }

  Future<void> _loadConnectHintState() async {
    final completed = await widget.connectHintStore.isCompleted();
    if (!mounted || completed) {
      return;
    }
    setState(() {
      _connectHintDismissed = false;
    });
  }

  /// The hint is one-shot: only a confirmed running runtime hides it and
  /// persists the done marker. A failed first tap must leave recovery context.
  void _dismissConnectHint() {
    if (_connectHintDismissed) {
      return;
    }
    setState(() {
      _connectHintDismissed = true;
    });
    unawaited(widget.connectHintStore.markCompleted());
  }

  Future<void> _toggleRuntimeFromHome() async {
    if (_firstLaunchStep != _FirstLaunchStep.ready) {
      _completeFirstLaunchAsNewUser();
    }
    _automaticFailoverGeneration += 1;
    _automaticFailoverInFlight = false;
    if (_runtimeSnapshot?.phase != RuntimePhase.running) {
      _automaticFailoverAttempts = 0;
    }
    await _toggleRuntime();
  }

  void _openProtectionCenter() {
    PokrovHaptics.tap();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      sheetAnimationStyle: _pokrovSheetAnimationStyle(context),
      builder: (context) => _ProtectionCenterSheet(
        initialData: _ProtectionCenterData(
          snapshot: _runtimeSnapshot,
          liveStats: const RuntimeLiveStats.unavailable(),
          httpsProbe: const PokrovHttpsProbeResult.unknown(),
          history: _clientExperience.protectionEvents,
          shortcuts: _clientExperience.postConnectShortcuts,
        ),
        onRefresh: _collectProtectionCenterData,
        onRepair: _repairAndCollectProtectionCenterData,
        onAddShortcut: _addPostConnectShortcut,
        onRemoveShortcut: _removePostConnectShortcut,
        onOpenShortcut: _openPostConnectShortcut,
      ),
    );
  }

  Future<_ProtectionCenterData> _collectProtectionCenterData({
    RuntimeSnapshot? snapshotOverride,
  }) async {
    RuntimeSnapshot? snapshot = snapshotOverride ?? _runtimeSnapshot;
    if (snapshotOverride == null) {
      try {
        snapshot = await _withRuntimeActionTimeout(
          'protectionSnapshot',
          _runtimeEngine.snapshot,
        );
        if (mounted) {
          setState(() {
            _runtimeSnapshot = snapshot;
          });
        }
      } on Object {
        // Keep the last host snapshot. Each unknown row remains visibly unknown.
      }
    }

    RuntimeLiveStats liveStats = const RuntimeLiveStats.unavailable();
    if (snapshot?.phase == RuntimePhase.running) {
      try {
        liveStats = await _withRuntimeActionTimeout(
          'protectionLiveStats',
          _runtimeEngine.liveStats,
        );
      } on Object {
        // Live counters are optional host evidence, never a tunnel failure.
      }
    }

    PokrovHttpsProbeResult httpsProbe;
    try {
      final baseUri = Uri.parse(widget.appContext.apiBaseUrl);
      httpsProbe = await (widget.protectionProbe ?? _probePokrovHttps)(baseUri);
    } on Object {
      httpsProbe = const PokrovHttpsProbeResult.degraded(
        detail: 'HTTPS-проверка не ответила.',
      );
    }

    return _ProtectionCenterData(
      snapshot: snapshot,
      liveStats: liveStats,
      httpsProbe: httpsProbe,
      history: _clientExperience.protectionEvents,
      shortcuts: _clientExperience.postConnectShortcuts,
    );
  }

  Future<_ProtectionCenterData> _repairAndCollectProtectionCenterData() async {
    try {
      await _repairRuntime();
      return _collectProtectionCenterData();
    } on _ProtectionRepairBusy {
      rethrow;
    } on Object {
      final data = await _collectProtectionCenterData(
        snapshotOverride: _runtimeSnapshot,
      );
      throw _ProtectionRepairFailed(data);
    }
  }

  Future<void> _repairRuntime() async {
    if (_runtimeBusy) {
      if (mounted) {
        setState(() {
          _runtimeHeadline =
              'POKROV уже выполняет действие. Дождитесь завершения.';
        });
      }
      throw const _ProtectionRepairBusy();
    }
    _cancelPostConnectHostHealthPolling();

    setState(() {
      _runtimeBusy = true;
      _runtimeDisconnecting = _runtimeSnapshot?.phase == RuntimePhase.running;
      _runtimeHeadline = 'Проверяем и восстанавливаем подключение…';
    });

    try {
      final knownSnapshot = _runtimeSnapshot;
      RuntimeSnapshot current = knownSnapshot ??
          await _withRuntimeActionTimeout(
            'repairSnapshot',
            _runtimeEngine.snapshot,
          );
      if (current.phase == RuntimePhase.running) {
        current = await _withRuntimeActionTimeout(
          'repairDisconnect',
          _runtimeEngine.disconnect,
        );
        current = await _settleRuntimeDisconnectTransition(current);
        if (!mounted) {
          return;
        }
        // A later profile/stage failure must not leave Home or the sheet
        // displaying the pre-repair running snapshot as active protection.
        setState(() {
          _runtimeSnapshot = current;
          _runtimeHeadline = current.message;
        });
      }
      if (!_canPrimaryConnect(current)) {
        throw StateError('на этом устройстве не завершена подготовка runtime');
      }
      if (current.canInitialize &&
          current.phase == RuntimePhase.artifactReady) {
        current = await _withRuntimeActionTimeout(
          'repairInitialize',
          _runtimeEngine.initialize,
        );
      }

      // A repair always resolves the current account/node/routing contract.
      // Staging is idempotent on the host and the loop runs exactly once.
      _managedProfileDirty = true;
      final managedProfile = await _resolveManagedProfile();
      current = await _withRuntimeActionTimeout(
        'repairStageManagedProfile',
        () => _runtimeEngine.stageManagedProfile(managedProfile),
      );
      _managedProfileDirty = false;
      _stagedProfileUsesWarp = managedProfile.warpPolicy.canEnableRuntime;
      _stagedNodeCode = _resolvedProfileNodeCode;
      _stagedVariantId = _resolvedProfileVariantId;
      _cachedProfileFallbackGate.markFreshProfileStaged();
      current = await _withRuntimeActionTimeout(
        'repairConnect',
        _runtimeEngine.connect,
      );
      current = await _settleRuntimeTransition(current);
      if (!mounted) {
        return;
      }
      if (current.phase == RuntimePhase.running) {
        if (_isConnectionProven(current)) {
          _finalizeProvenConnection(current);
        }
        _schedulePostConnectHostHealthRefresh(current);
      }
      setState(() {
        _runtimeSnapshot = current;
        _runtimeHeadline = current.phase == RuntimePhase.running
            ? current.isCoreEgressValidationPending
                ? 'Проверяем выход через VPN…'
                : current.isCleanlyHealthy
                    ? 'Подключение восстановлено.'
                    : 'Подключение восстановлено с предупреждением.'
            : current.message;
      });
      if (current.phase != RuntimePhase.running) {
        throw StateError(
          current.message.trim().isEmpty
              ? 'runtime не подтвердил подключение'
              : current.message,
        );
      }
      _recordProtectionEvent(
        kind: current.isCoreEgressValidationPending
            ? 'repair_egress_checking'
            : current.hasCoreEgressValidationFailure
                ? 'repair_egress_failed'
                : 'repair_success',
        title: current.isCoreEgressValidationPending
            ? 'Проверяем выход через VPN'
            : current.hasCoreEgressValidationFailure
                ? 'Выход через VPN не подтверждён'
                : 'Подключение восстановлено',
        detail: current.isCoreEgressValidationPending
            ? 'Туннель запущен; POKROV Core проверяет выход через выбранную локацию.'
            : current.hasCoreEgressValidationFailure
                ? 'POKROV Core не подтвердил выход через выбранную локацию.'
                : current.isCleanlyHealthy
                    ? 'Профиль обновлён, туннель и host-health подтверждены.'
                    : 'Профиль обновлён, туннель запущен с предупреждением хоста.',
        tone: current.isCleanlyHealthy
            ? PokrovProtectionEventTone.success
            : PokrovProtectionEventTone.warning,
      );
    } on BootstrapFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _runtimeHeadline = error.message;
      });
      showPokrovSnack(context, error.message, tone: PokrovSnackTone.danger);
      _recordProtectionEvent(
        kind: 'repair_failed',
        title: 'Восстановление не завершено',
        detail: 'Ограниченный цикл остановлен. Можно повторить вручную.',
        tone: PokrovProtectionEventTone.error,
      );
      rethrow;
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      final message = _runtimeUnexpectedErrorMessage(error);
      setState(() {
        _runtimeHeadline = message;
      });
      showPokrovSnack(context, message, tone: PokrovSnackTone.danger);
      _recordProtectionEvent(
        kind: 'repair_failed',
        title: 'Восстановление не завершено',
        detail: 'Ограниченный цикл остановлен. Можно повторить вручную.',
        tone: PokrovProtectionEventTone.error,
      );
      rethrow;
    } finally {
      if (mounted) {
        setState(() {
          _runtimeBusy = false;
          _runtimeDisconnecting = false;
        });
      }
    }
  }

  void _openFirstLaunchRestore() {
    PokrovHaptics.tap();
    setState(() {
      _firstLaunchStep = _FirstLaunchStep.restore;
    });
  }

  void _backToFirstLaunchChoice() {
    PokrovHaptics.tap();
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
    final ok = await _redeemCodeInApp(_firstLaunchRestoreCodeController.text);
    if (!mounted) {
      return;
    }
    setState(() {
      _firstLaunchBusy = false;
      if (ok) {
        unawaited(_markFirstLaunchCompleted());
        // Restore success exits through the same handover as the new-user
        // path — one gate, one choreography.
        _firstLaunchExitAnimated = true;
        _firstLaunchStep = _FirstLaunchStep.ready;
      }
    });
  }

  Future<void> _showSupportHub() {
    PokrovHaptics.tap();
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (routeContext) {
          AppFirstPromoSlot? supportPromo;
          for (final slot
              in _bonusSummary?.promoSlots.visibleForPlacement('support') ??
                  const <AppFirstPromoSlot>[]) {
            if (_isRenderableHomePromoSlot(slot)) {
              supportPromo = slot;
              break;
            }
          }
          return _SupportChatScreen(
            appContext: widget.appContext,
            selectedRouteMode: _selectedRouteMode,
            statusLabel: _consumerProtectionStatusLabel(
              _runtimeSnapshot,
              busy: _runtimeBusy,
              disconnecting: _runtimeDisconnecting,
            ),
            extraDiagnostics: _extendedProtectionDiagnostics(),
            supportTicketService: _supportTicketService,
            askAssistant:
                _clientDataService == null ? null : _askSupportAssistant,
            onOpenHandoff: _showSeedHandoff,
            promoSlot: supportPromo,
            onPromoEvent: _reportPromoEvent,
          );
        },
      ),
    );
  }

  /// Knowledge-base question -> answer lane for the support AI sheet. Reuses
  /// the existing backend assistant endpoint with the same safe diagnostic
  /// keys the ticket flow sends; nothing raw ever leaves the device.
  Future<ClientSupportAssistantReply> _askSupportAssistant(
    String message,
    String? assistantSessionId,
  ) {
    final service = _clientDataService;
    if (service == null) {
      throw const BootstrapFailure('Помощник недоступен на этом устройстве.');
    }
    return service.askSupportAssistant(
      hostPlatform: widget.appContext.hostPlatform,
      message: message,
      assistantSessionId: assistantSessionId,
      safeDiagnostics: <String, Object?>{
        'app_version': pokrovClientVersion,
        'platform': widget.appContext.hostPlatform.name,
        'route_mode': _selectedRouteMode.name,
        'connection_status': _consumerProtectionStatusLabel(
          _runtimeSnapshot,
          busy: _runtimeBusy,
          disconnecting: _runtimeDisconnecting,
        ),
        'connection_active': _runtimeSnapshot?.phase == RuntimePhase.running,
        'current_location_label': _homeLocationLabel,
        ..._extendedProtectionDiagnostics(),
      },
    );
  }

  Map<String, Object?> _extendedProtectionDiagnostics() {
    return PokrovWarpSupportDiagnostics.fromLifecycle(
      PokrovWarpLifecycle.resolve(
        policy: _managedWarpPolicy,
        consented: _warpRuntimeConsent,
        busy: _warpPolicyBusy,
        runtimeActive: _warpRuntimeIsActive,
        lastError: _runtimeSnapshot?.lastFailureKind ?? '',
      ),
    ).toJson();
  }

  bool get _warpRuntimeIsActive =>
      _activeConnectUsedWarp &&
      _runtimeSnapshot?.phase == RuntimePhase.running &&
      _runtimeSnapshot?.coreEgressValidated == true;

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

  Uri? _safeHandoffFallbackUri({required String label, required String value}) {
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
      widget.shellController?.refresh();
      return snapshot;
    } finally {
      if (mounted) {
        setState(() {
          _runtimeBusy = false;
        });
      }
      widget.shellController?.refresh();
    }
  }

  Future<void> _refreshRuntimeSnapshot() async {
    final snapshot = await _runRuntimeAction(_runtimeEngine.snapshot);
    if (snapshot.phase == RuntimePhase.running) {
      if (_isConnectionProven(snapshot)) {
        _finalizeProvenConnection(snapshot);
      } else if (widget.appContext.hostPlatform == HostPlatform.android &&
          snapshot.coreEgressValidated == null) {
        _schedulePostConnectHostHealthRefresh(snapshot);
      }
    }
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

  Future<ManagedProfilePayload> _resolveManagedProfile({
    Duration? deadline,
    bool suppressWarpRuntime = false,
  }) async {
    final resolveFuture = _bootstrapper.resolveManagedProfile(
      hostPlatform: widget.appContext.hostPlatform,
      routeMode: _selectedRouteMode,
      selectedApps: _selectedRouteMode == RouteMode.selectedApps ||
              _selectedRouteMode == RouteMode.excludedApps
          ? _selectedAppIds
          : const <String>[],
      preferredNodeCode: _preferredNodeCode,
      preferredVariantId:
          _preferredNodeCode.trim().isEmpty ? 'direct' : _preferredVariantId,
      excludedNodeCodes: _preferredNodeCode.trim().isEmpty
          ? _activeAutomaticNodeExclusions()
          : const <String>{},
    );
    final payload = deadline == null
        ? await resolveFuture
        : await resolveFuture.timeout(deadline);
    final baseWarpPolicy = payload.warpPolicy.withClientLocalDefaults();
    final warpStatus = await _fetchWarpStatusOrNull();
    final serverDisplayWarpPolicy =
        warpStatus?.applyTo(baseWarpPolicy) ?? baseWarpPolicy;
    final explicitRetryRequested =
        _warpRuntimeRetryPending && _explicitWarpRuntimeConsent == true;
    final displayWarpPolicy = explicitRetryRequested
        ? serverDisplayWarpPolicy.copyWith(
            state: 'consented',
            userConsented: true,
          )
        : serverDisplayWarpPolicy;
    final reportedConsent = (warpStatus?.consented ?? false) ||
        _warpRuntimeConsent ||
        baseWarpPolicy.userConsented;
    final warpConsentStillValid =
        (_explicitWarpRuntimeConsent ?? reportedConsent) &&
            displayWarpPolicy.canOfferRuntime;
    final warpRuntimeAttemptEnabled = !suppressWarpRuntime &&
        warpConsentStillValid &&
        (explicitRetryRequested ||
            _warpRuntimeAttemptAllowed(displayWarpPolicy));
    final requestedPreferred = _preferredNodeCode.trim().toLowerCase();
    final requestedVariant = requestedPreferred.isEmpty
        ? 'direct'
        : normalizeClientLocationVariantId(_preferredVariantId) ?? 'direct';
    if (requestedPreferred.isNotEmpty &&
        requestedVariant != 'direct' &&
        warpRuntimeAttemptEnabled) {
      throw const BootstrapFailure(
        'WARP пока нельзя использовать с вариантом «Белые списки». Выключите WARP или выберите «Обычный».',
      );
    }
    final runtimePayload = payload.copyWith(
      // A server-reported fallback/error is a circuit breaker, not a cosmetic
      // status. Keep the person's consent visible, but stage the ordinary VPN
      // until they explicitly toggle WARP off and on to retry it.
      warpPolicy: displayWarpPolicy.withUserConsent(warpRuntimeAttemptEnabled),
      quickSettingsEligible:
          widget.appContext.hostPlatform == HostPlatform.android &&
              _clientExperience.firstRouteScopeConfirmed &&
              _clientExperience.firstRouteScopeMode == _selectedRouteMode,
    );
    final configuredPayload = applyPokrovRoutingPreferences(
      runtimePayload,
      _clientExperience.routingPreferences,
    );
    if (mounted) {
      final resolvedAutomatic = payload.resolvedNodeCode.trim().toLowerCase();
      // Server stickiness is an automatic routing hint, not proof of a manual
      // choice or of the profile actually staged on this device. Only the
      // authoritative resolved code may later identify a failed auto node.
      setState(() {
        _managedWarpPolicy = displayWarpPolicy.withUserConsent(
          warpConsentStillValid,
        );
        _warpRuntimeRetryPending = false;
        _freeProfileAccess = payload.freeProfileAccess;
        _warpRuntimeConsent = warpConsentStillValid;
        _smartConnectProfile = payload.smartConnect;
        _preferredNodeCode = requestedPreferred;
        _resolvedProfileNodeCode = requestedPreferred.isNotEmpty
            ? requestedPreferred
            : resolvedAutomatic;
        _resolvedProfileVariantId =
            requestedPreferred.isNotEmpty ? requestedVariant : 'direct';
        // Consumer copy: no infra hostnames on the first layer.
        _runtimeHeadline = 'Настройки обновлены.';
      });
    }
    return configuredPayload;
  }

  bool _warpRuntimeAttemptAllowed(WarpRuntimePolicy policy) {
    final state = policy.state.trim().toLowerCase();
    return !const <String>{
      'fallback',
      'baseline_fallback',
      'degraded',
      'error',
      'failed',
      'runtime_error',
    }.contains(state);
  }

  Duration get _cachedProfileRefreshDeadline {
    const maximum = Duration(seconds: 5);
    return widget.runtimeActionTimeout < maximum
        ? widget.runtimeActionTimeout
        : maximum;
  }

  bool _hasFreshCachedManagedProfile(String? path) {
    final normalizedPath = path?.trim() ?? '';
    if (normalizedPath.isEmpty) {
      return false;
    }
    try {
      final file = File(normalizedPath);
      if (!file.existsSync()) {
        return false;
      }
      final age = DateTime.now().difference(file.lastModifiedSync());
      if (age > const Duration(hours: 24)) {
        return false;
      }
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map) {
        return false;
      }
      return _runtimeConfigMap(decoded)['outbounds'] is List;
    } on Object {
      return false;
    }
  }

  Future<RuntimeSnapshot> _migrateCachedAndroidManagedProfile(
    RuntimeSnapshot snapshot,
  ) async {
    final path = snapshot.stagedConfigPath?.trim() ?? '';
    if (path.isEmpty) {
      return snapshot;
    }
    try {
      final raw = await File(path).readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return snapshot;
      }
      final config = _runtimeConfigMap(decoded);
      final dns = _runtimeConfigMap(config['dns']);
      final rawServers = dns['servers'];
      if (rawServers is! List) {
        return snapshot;
      }
      var changed = false;
      var localServerTag = '';
      final servers = rawServers.map((rawServer) {
        final server = _runtimeConfigMap(rawServer);
        final isLegacyLocal =
            (server['address'] ?? '').toString().trim().toLowerCase() ==
                'local';
        final isTypedLocal =
            (server['type'] ?? '').toString().trim().toLowerCase() == 'local';
        if (isLegacyLocal) {
          server['type'] = 'local';
          server.remove('address');
          server.remove('address_resolver');
          changed = true;
        }
        if (isLegacyLocal || isTypedLocal) {
          localServerTag = (server['tag'] ?? '').toString().trim();
        }
        return server;
      }).toList(growable: false);
      final rawOutbounds = config['outbounds'];
      if (localServerTag.isNotEmpty && rawOutbounds is List) {
        config['outbounds'] = rawOutbounds.map((rawOutbound) {
          final outbound = _runtimeConfigMap(rawOutbound);
          final server = (outbound['server'] ?? '').toString().trim();
          if (server.isNotEmpty &&
              InternetAddress.tryParse(server) == null &&
              outbound['domain_resolver'] != localServerTag) {
            outbound['domain_resolver'] = localServerTag;
            changed = true;
          }
          return outbound;
        }).toList(growable: false);
      }
      dns['servers'] = servers;
      config['dns'] = dns;
      final basePayload = ManagedProfilePayload(
        profileName: 'pokrov-cached-android',
        configPayload: jsonEncode(config),
        materializedForRuntime: true,
        routeMode: _selectedRouteMode,
      );
      if (!changed) {
        return snapshot;
      }
      return _withRuntimeActionTimeout(
        'migrateCachedAndroidProfile',
        () => _runtimeEngine.stageManagedProfile(
          basePayload,
        ),
      );
    } on Object {
      return snapshot;
    }
  }

  bool _isTransientProfileFailure(BootstrapFailure error) {
    final statusCode = error.statusCode;
    return statusCode == null ||
        statusCode == HttpStatus.requestTimeout ||
        statusCode == HttpStatus.tooManyRequests ||
        statusCode == HttpStatus.badGateway ||
        statusCode == HttpStatus.serviceUnavailable ||
        statusCode == HttpStatus.gatewayTimeout;
  }

  Map<String, dynamic> _runtimeConfigMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.from(value);
    }
    if (value is Map) {
      return value.map(
        (key, item) => MapEntry(key.toString(), item),
      );
    }
    return <String, dynamic>{};
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
        runtimeActive: _warpRuntimeIsActive,
      ),
      enabled: _warpRuntimeConsent,
      onChanged: _setWarpRuntimeConsent,
    );
  }

  Future<void> _setWarpRuntimeConsent(bool value) async {
    if (_warpPolicyBusy) {
      return;
    }
    final wasConnected = _runtimeSnapshot?.phase == RuntimePhase.running;
    final localPolicy = _managedWarpPolicy.withClientLocalDefaults();
    final requestedEnabled = value && localPolicy.canOfferRuntime;
    PokrovHaptics.tap();
    setState(() {
      _warpPolicyBusy = true;
      _managedWarpPolicy = localPolicy;
      // Apply the person's choice before awaiting the server. A stale status
      // or managed profile can arrive while that request is in flight.
      _explicitWarpRuntimeConsent = requestedEnabled;
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
        _warpRuntimeRetryPending = enabled;
        _managedProfileDirty = true;
        _cachedProfileFallbackGate.markUserChange();
        _runtimeHeadline = wasConnected
            ? enabled
                ? 'Включаем WARP…'
                : 'Выключаем WARP…'
            : enabled
                ? 'WARP включится при следующем подключении.'
                : 'WARP выключен для следующих подключений.';
      });
      _invalidateQuickSettingsProfile();
      if (wasConnected) {
        await _reconnectAfterManagedProfileChange(
          progressMessage: enabled ? 'Включаем WARP…' : 'Выключаем WARP…',
          successMessage: enabled ? 'WARP включён.' : 'WARP выключен.',
        );
      }
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

  void _invalidateQuickSettingsProfile() {
    _managedProfileRevision += 1;
    if (_seedShellDisposed ||
        widget.appContext.hostPlatform != HostPlatform.android) {
      return;
    }
    _quickSettingsInvalidationRequestedRevision = _managedProfileRevision;
    _quickSettingsInvalidationInFlight ??= _drainQuickSettingsInvalidations();
  }

  Future<bool> _waitForQuickSettingsInvalidation(int revision) async {
    if (_seedShellDisposed ||
        widget.appContext.hostPlatform != HostPlatform.android) {
      return true;
    }
    while (_quickSettingsInvalidationCompletedRevision < revision) {
      final pending = _quickSettingsInvalidationInFlight ??=
          _drainQuickSettingsInvalidations();
      if (!await pending) {
        return false;
      }
    }
    return true;
  }

  Future<bool> _drainQuickSettingsInvalidations() async {
    try {
      // Snapshot the desired revision for each host call. All edits that land
      // while it is running collapse into one follow-up call for the latest
      // revision instead of building an unbounded timeout queue.
      while (!_seedShellDisposed) {
        final targetRevision = _quickSettingsInvalidationRequestedRevision;
        final invalidated = await _runQuickSettingsProfileInvalidation();
        if (!invalidated) {
          return false;
        }
        _quickSettingsInvalidationCompletedRevision = targetRevision;
        if (_quickSettingsInvalidationRequestedRevision <= targetRevision) {
          return true;
        }
      }
      return false;
    } finally {
      _quickSettingsInvalidationInFlight = null;
    }
  }

  Future<bool> _runQuickSettingsProfileInvalidation() {
    if (_seedShellDisposed) {
      return Future<bool>.value(false);
    }
    final generation = ++_managedProfileInvalidationGeneration;
    final completion = Completer<bool>();
    _managedProfileInvalidationCompletion = completion;
    final timer = Timer(widget.runtimeActionTimeout, () {
      if (_seedShellDisposed ||
          generation != _managedProfileInvalidationGeneration ||
          completion.isCompleted) {
        return;
      }
      _managedProfileInvalidationTimer = null;
      completion.complete(false);
      if (identical(_managedProfileInvalidationCompletion, completion)) {
        _managedProfileInvalidationCompletion = null;
      }
    });
    _managedProfileInvalidationTimer = timer;

    void complete(bool invalidated, [RuntimeSnapshot? snapshot]) {
      if (_seedShellDisposed ||
          generation != _managedProfileInvalidationGeneration ||
          completion.isCompleted) {
        return;
      }
      timer.cancel();
      if (identical(_managedProfileInvalidationTimer, timer)) {
        _managedProfileInvalidationTimer = null;
      }
      if (identical(_managedProfileInvalidationCompletion, completion)) {
        _managedProfileInvalidationCompletion = null;
      }
      if (invalidated && mounted && snapshot != null) {
        setState(() {
          _runtimeSnapshot = snapshot;
        });
      }
      completion.complete(invalidated);
    }

    unawaited(
      _runtimeEngine
          .invalidateManagedProfile()
          .then((snapshot) => complete(true, snapshot))
          .catchError((Object _) => complete(false)),
    );
    return completion.future;
  }

  Future<void> _toggleRuntime({bool reconnectAfterDisconnect = false}) async {
    if (_runtimeBusy) {
      setState(() {
        _runtimeHeadline = 'POKROV уже обновляется. Подождите немного.';
      });
      return;
    }
    _cancelPostConnectHostHealthPolling();

    final confirmedRouteMode = _clientExperience.firstRouteScopeMode;
    if (_runtimeSnapshot?.phase != RuntimePhase.running &&
        (!_clientExperience.firstRouteScopeConfirmed ||
            confirmedRouteMode == null ||
            !widget.appContext.runtimeProfile.supportedRouteModes.contains(
              confirmedRouteMode,
            ))) {
      final routeMode = await _showFirstConnectRouteScopeSheet(
        context,
        canSelectApps: widget.appContext.runtimeProfile.supportedRouteModes
            .contains(RouteMode.selectedApps),
      );
      if (!mounted || routeMode == null) {
        return;
      }
      _selectRouteMode(routeMode);
    }

    if (_runtimeSnapshot?.phase != RuntimePhase.running &&
        _selectedAppsRouteNeedsSelection) {
      _openRulesForSelectedApps();
      return;
    }

    setState(() {
      _runtimeBusy = true;
      _runtimeDisconnecting = _runtimeSnapshot?.phase == RuntimePhase.running;
    });

    try {
      RuntimeSnapshot snapshot = _runtimeSnapshot ??
          await _withRuntimeActionTimeout('snapshot', _runtimeEngine.snapshot);
      if (!mounted) {
        return;
      }

      if (snapshot.phase == RuntimePhase.running) {
        if (!_runtimeDisconnecting) {
          // The pre-busy guess was made without a snapshot; fix the copy
          // before the disconnect actually starts.
          setState(() {
            _runtimeDisconnecting = true;
          });
        }
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
        if (!reconnectAfterDisconnect) {
          _recordProtectionEvent(
            kind: 'disconnected',
            title: 'Защита выключена',
            detail: 'Туннель остановлен по действию пользователя.',
            tone: PokrovProtectionEventTone.neutral,
          );
          _activeConnectUsedWarp = false;
          return;
        }
        snapshot = current;
      }

      if (await _blockConnectOnTrustedWifi()) {
        return;
      }

      if (!_canPrimaryConnect(snapshot)) {
        setState(() {
          _runtimeHeadline =
              'На этом устройстве еще нужно завершить подготовку.';
        });
        return;
      }

      // A user-owned route, location, app, or WARP change clears the host
      // reusable profile first. Do not let a fresh stage race that clear.
      final invalidated = await _waitForQuickSettingsInvalidation(
        _managedProfileRevision,
      );
      if (!mounted) {
        return;
      }
      if (!invalidated) {
        setState(() {
          _runtimeHeadline =
              'Не удалось обновить настройки для быстрого подключения. Попробуйте ещё раз.';
        });
        return;
      }
      final profileRevision = _managedProfileRevision;

      RuntimeSnapshot current = snapshot;
      var usedCachedProfile = false;

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

      final cachedProfileAvailable = _hasFreshCachedManagedProfile(
        current.stagedConfigPath,
      );
      final cachedProfileFallbackAllowed = _cachedProfileFallbackGate
          .canFallback(cachedProfileAvailable: cachedProfileAvailable);
      if (cachedProfileAvailable &&
          widget.appContext.hostPlatform == HostPlatform.android) {
        current = await _migrateCachedAndroidManagedProfile(current);
      }

      final shouldRefreshManagedProfile =
          _managedProfileDirty || (current.stagedConfigPath ?? '').isEmpty;
      if (shouldRefreshManagedProfile) {
        try {
          final managedProfile = await _resolveManagedProfile(
            deadline: cachedProfileFallbackAllowed
                ? _cachedProfileRefreshDeadline
                : widget.runtimeActionTimeout,
          );
          current = await _withRuntimeActionTimeout(
            'stageManagedProfile',
            () => _runtimeEngine.stageManagedProfile(managedProfile),
          );
          if (!mounted) {
            return;
          }
          if (profileRevision != _managedProfileRevision) {
            setState(() {
              _runtimeSnapshot = current;
              _managedProfileDirty = true;
              _runtimeHeadline =
                  'Настройки изменились. Подключитесь еще раз, чтобы обновить профиль.';
            });
            return;
          }
          setState(() {
            _runtimeSnapshot = current;
            _runtimeHeadline = null;
            _managedProfileDirty = false;
            _stagedProfileUsesWarp = managedProfile.warpPolicy.canEnableRuntime;
            _stagedNodeCode = _resolvedProfileNodeCode;
            _stagedVariantId = _resolvedProfileVariantId;
            _cachedProfileFallbackGate.markFreshProfileStaged();
          });
        } on TimeoutException {
          if (!cachedProfileFallbackAllowed) {
            rethrow;
          }
          usedCachedProfile = true;
        } on BootstrapFailure catch (error) {
          if (!cachedProfileFallbackAllowed ||
              !_isTransientProfileFailure(error)) {
            rethrow;
          }
          usedCachedProfile = true;
        }
      }

      if ((current.stagedConfigPath ?? '').isNotEmpty || current.canConnect) {
        final warpRuntimeAttempted =
            _warpRuntimeConsent && _stagedProfileUsesWarp;
        _activeConnectUsedWarp = warpRuntimeAttempted;
        current = await _withRuntimeActionTimeout(
          'connect',
          _runtimeEngine.connect,
        );
        current = await _settleRuntimeTransition(current);
        if (!mounted) {
          return;
        }
        var warpFallbackUsed = false;
        if (current.phase != RuntimePhase.running && warpRuntimeAttempted) {
          final fallback = await _withRuntimeActionTimeout(
            'applyWarpFallback',
            () => _runtimeEngine.applyWarp(enabled: false),
          );
          if (!mounted) {
            return;
          }
          if (fallback.applied) {
            _activeConnectUsedWarp = false;
            setState(() {
              _stagedProfileUsesWarp = false;
              _managedWarpPolicy = _managedWarpPolicy.copyWith(
                state: 'fallback',
                userConsented: true,
              );
              _runtimeHeadline =
                  'WARP временно недоступен. Подключаем обычный VPN…';
            });
            current = await _withRuntimeActionTimeout(
              'connectWithoutWarp',
              _runtimeEngine.connect,
            );
            current = await _settleRuntimeTransition(current);
            if (!mounted) {
              return;
            }
            warpFallbackUsed = current.phase == RuntimePhase.running;
            unawaited(_reportWarpRuntimeFallback(current));
          }
        }
        if (current.phase == RuntimePhase.running) {
          if (_isConnectionProven(current)) {
            _finalizeProvenConnection(current);
          }
          _schedulePostConnectHostHealthRefresh(current);
        }
        setState(() {
          _runtimeSnapshot = current;
          _runtimeHeadline = warpFallbackUsed
              ? 'POKROV подключен. WARP временно на паузе.'
              : current.phase == RuntimePhase.running && usedCachedProfile
                  ? current.isCoreEgressValidationPending
                      ? 'Проверяем выход через VPN…'
                      : current.hasCoreEgressValidationFailure
                          ? 'Выход через VPN не подтверждён.'
                          : 'POKROV подключен по сохраненным настройкам. Сервис обновим позже.'
                  : current.phase == RuntimePhase.running
                      ? current.isCoreEgressValidationPending
                          ? 'Проверяем выход через VPN…'
                          : current.isCleanlyHealthy
                              ? 'POKROV подключен.'
                              : current.hasCoreEgressValidationFailure
                                  ? 'Выход через VPN не подтверждён.'
                                  : 'POKROV подключен, но требует внимания.'
                      : current.message;
        });
        if (current.phase == RuntimePhase.running) {
          _recordProtectionEvent(
            kind: current.isCoreEgressValidationPending
                ? 'egress_checking'
                : current.hasCoreEgressValidationFailure
                    ? 'egress_failed'
                    : 'connected',
            title: warpFallbackUsed
                ? 'Обычная защита включена'
                : current.isCoreEgressValidationPending
                    ? 'Проверяем выход через VPN'
                    : current.hasCoreEgressValidationFailure
                        ? 'Выход через VPN не подтверждён'
                        : usedCachedProfile
                            ? 'Защита включена по сохраненным настройкам'
                            : current.isCleanlyHealthy
                                ? 'Защита включена'
                                : 'Защита включена с предупреждением',
            detail: warpFallbackUsed
                ? 'WARP не прошёл проверку, поэтому POKROV автоматически сохранил рабочий обычный VPN.'
                : current.isCoreEgressValidationPending
                    ? 'Туннель запущен; POKROV Core проверяет выход через выбранную локацию.'
                    : current.hasCoreEgressValidationFailure
                        ? 'POKROV Core не подтвердил выход через выбранную локацию.'
                        : usedCachedProfile
                            ? 'Control plane не ответил вовремя; использован последний валидный профиль.'
                            : current.isCleanlyHealthy
                                ? 'Туннель и host-health подтверждены.'
                                : 'Туннель запущен, одна из host-проверок требует внимания.',
            tone: warpFallbackUsed
                ? PokrovProtectionEventTone.warning
                : usedCachedProfile
                    ? PokrovProtectionEventTone.warning
                    : current.isCleanlyHealthy
                        ? PokrovProtectionEventTone.success
                        : PokrovProtectionEventTone.warning,
          );
        }
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
          _runtimeDisconnecting = false;
        });
      }
      widget.shellController?.refresh();
    }
  }

  Future<void> _syncSuccessfulConnectionExperience(
    RuntimeSnapshot snapshot,
  ) async {
    final service = _experienceService;
    if (service == null) {
      return;
    }
    try {
      await service.reportRuntimeStats(
        hostPlatform: widget.appContext.hostPlatform,
        runtimePhase: snapshot.phase.name,
        connected: snapshot.phase == RuntimePhase.running,
      );
    } catch (_) {
      // UX telemetry must never turn a working tunnel into a failed connect.
    }
    try {
      await service.completeAccountOnboarding(
        hostPlatform: widget.appContext.hostPlatform,
      );
    } catch (_) {
      // Account-scoped onboarding sync is best-effort and retried on connect.
    }
  }

  bool _isConnectionProven(RuntimeSnapshot snapshot) =>
      snapshot.phase == RuntimePhase.running &&
      (widget.appContext.hostPlatform != HostPlatform.android ||
          snapshot.coreEgressValidated == true);

  void _finalizeProvenConnection(RuntimeSnapshot snapshot) {
    _automaticFailoverAttempts = 0;
    _automaticFailoverInFlight = false;
    _promoteStagedLocationAfterFreshConnect();
    _dismissConnectHint();
    unawaited(_syncSuccessfulConnectionExperience(snapshot));
  }

  void _schedulePostConnectHostHealthRefresh(
    RuntimeSnapshot connectedSnapshot,
  ) {
    if (widget.appContext.hostPlatform != HostPlatform.android ||
        connectedSnapshot.coreEgressValidated == true) {
      return;
    }
    _cancelPostConnectHostHealthPolling();
    final generation = ++_postConnectHealthGeneration;
    var pollsRemaining = _activeConnectUsedWarp ? 76 : 28;
    // A normal group probe settles in about 19 seconds. WARP receives one
    // bounded host retry, so keep observing it through the 55-second host
    // watchdog. A fail-closed stop that lands after a single refresh must not
    // leave the Home CTA green with no TUN behind it.
    _postConnectHealthTimer = Timer.periodic(
      const Duration(milliseconds: 750),
      (timer) {
        if (!mounted || generation != _postConnectHealthGeneration) {
          timer.cancel();
          return;
        }
        pollsRemaining -= 1;
        if (pollsRemaining < 0) {
          timer.cancel();
          if (generation == _postConnectHealthGeneration) {
            _postConnectHealthTimer = null;
          }
          return;
        }
        unawaited(_refreshPostConnectHostHealth(connectedSnapshot, generation));
      },
    );
  }

  Future<void> _refreshPostConnectHostHealth(
    RuntimeSnapshot connectedSnapshot,
    int generation,
  ) async {
    if (!mounted ||
        generation != _postConnectHealthGeneration ||
        _runtimeSnapshot?.phase != RuntimePhase.running ||
        _postConnectHealthPollInFlight == generation) {
      return;
    }
    _postConnectHealthPollInFlight = generation;
    try {
      final refreshed = await _withRuntimeActionTimeout(
        'postConnectHealthSnapshot',
        _runtimeEngine.snapshot,
      );
      if (!mounted ||
          generation != _postConnectHealthGeneration ||
          _runtimeSnapshot?.phase != RuntimePhase.running) {
        return;
      }
      final connectedPath = connectedSnapshot.stagedConfigPath?.trim() ?? '';
      final refreshedPath = refreshed.stagedConfigPath?.trim() ?? '';
      if (connectedPath.isNotEmpty &&
          refreshedPath.isNotEmpty &&
          connectedPath != refreshedPath) {
        return;
      }
      if (refreshed.phase != RuntimePhase.running) {
        _cancelPostConnectHostHealthPolling();
        final shouldFallbackFromWarp = _activeConnectUsedWarp &&
            !_warpFallbackInFlight &&
            _mustRefreshProfileAfterRuntimeFailure(refreshed);
        if (shouldFallbackFromWarp) {
          _warpFallbackInFlight = true;
          setState(() {
            _runtimeSnapshot = refreshed;
            _managedWarpPolicy = _managedWarpPolicy.copyWith(
              state: 'fallback',
              userConsented: true,
            );
            _runtimeHeadline =
                'WARP временно недоступен. Подключаем обычный VPN…';
          });
          unawaited(_retryWithoutWarpAfterEgressFailure(refreshed));
          widget.shellController?.refresh();
          return;
        }
        final mustRefreshProfile = _mustRefreshProfileAfterRuntimeFailure(
          refreshed,
        );
        final failedNodeCode = _stagedNodeCode.trim().toLowerCase();
        final confirmedAutomaticNodeFailure =
            refreshed.lastFailureKind?.trim() == 'core_egress_probe_failed' &&
                _preferredNodeCode.trim().isEmpty &&
                failedNodeCode.isNotEmpty;
        final shouldRetryAutomatically = confirmedAutomaticNodeFailure &&
            !_automaticFailoverInFlight &&
            _automaticFailoverAttempts < _maxAutomaticFailoverAttempts;
        if (confirmedAutomaticNodeFailure) {
          _quarantineAutomaticNode(failedNodeCode);
        }
        setState(() {
          _runtimeSnapshot = refreshed;
          if (mustRefreshProfile) {
            _managedProfileDirty = true;
            _stagedNodeCode = '';
            _stagedVariantId = 'direct';
          }
          _runtimeHeadline = shouldRetryAutomatically
              ? 'Локация не ответила. Пробуем другую…'
              : refreshed.message.trim().isEmpty
                  ? 'Подключение остановлено. Попробуйте еще раз.'
                  : refreshed.message;
        });
        if (mustRefreshProfile) {
          // The last staged profile failed after its TUN was established. Do
          // not let a later offline fallback restart it under the same UI
          // choice; the next CTA must resolve and stage a fresh authorized
          // profile first.
          _cachedProfileFallbackGate.markRuntimeProfileInvalid();
          _invalidateQuickSettingsProfile();
        }
        if (shouldRetryAutomatically) {
          _automaticFailoverAttempts += 1;
          _automaticFailoverInFlight = true;
          final ownerGeneration = _automaticFailoverGeneration;
          unawaited(
            _retryAutomaticLocationAfterEgressFailure(ownerGeneration),
          );
        }
        widget.shellController?.refresh();
        return;
      }
      setState(() {
        _runtimeSnapshot = refreshed;
        if (refreshed.isCoreEgressValidationPending) {
          _runtimeHeadline = 'Проверяем выход через VPN…';
        } else if (refreshed.hasDegradedHostDiagnostics) {
          _runtimeHeadline =
              'Туннель запущен, но проверка соединения требует внимания.';
        } else if (refreshed.isCleanlyHealthy) {
          _runtimeHeadline = 'POKROV подключен.';
        }
      });
      widget.shellController?.refresh();
      if (refreshed.coreEgressValidated == true) {
        _finalizeProvenConnection(refreshed);
        _cancelPostConnectHostHealthPolling();
      }
    } on Object {
      // The host snapshot is advisory here; the normal refresh lane retries it.
    } finally {
      if (_postConnectHealthPollInFlight == generation) {
        _postConnectHealthPollInFlight = null;
      }
    }
  }

  void _cancelPostConnectHostHealthPolling() {
    _postConnectHealthGeneration += 1;
    _postConnectHealthTimer?.cancel();
    _postConnectHealthTimer = null;
  }

  Future<void> _retryWithoutWarpAfterEgressFailure(
    RuntimeSnapshot warpFailure,
  ) async {
    if (!mounted) {
      _warpFallbackInFlight = false;
      return;
    }
    setState(() {
      _runtimeBusy = true;
      _runtimeDisconnecting = false;
    });
    try {
      final fallback = await _withRuntimeActionTimeout(
        'applyWarpFallback',
        () => _runtimeEngine.applyWarp(enabled: false),
      );
      if (!mounted) {
        return;
      }
      var baselineReady = fallback.applied;
      var fallbackReported = false;
      if (baselineReady) {
        _stagedProfileUsesWarp = false;
      }
      if (!baselineReady) {
        // A process restart can preserve the host's reusable profile while the
        // Dart runtime no longer has the original staged payload. Re-resolve
        // and stage a fresh baseline profile instead of asking the person to
        // understand this internal cache boundary.
        await _reportWarpRuntimeFallback(warpFailure);
        fallbackReported = true;
        final baselineProfile = await _resolveManagedProfile(
          deadline: widget.runtimeActionTimeout,
          suppressWarpRuntime: true,
        );
        final staged = await _withRuntimeActionTimeout(
          'stageWarpFallbackProfile',
          () => _runtimeEngine.stageManagedProfile(baselineProfile),
        );
        if (!mounted) {
          return;
        }
        baselineReady = staged.canConnect ||
            (staged.stagedConfigPath?.trim().isNotEmpty ?? false);
        setState(() {
          _runtimeSnapshot = staged;
          _managedProfileDirty = !baselineReady;
          _stagedProfileUsesWarp = false;
          _stagedNodeCode = baselineReady ? _resolvedProfileNodeCode : '';
          _stagedVariantId =
              baselineReady ? _resolvedProfileVariantId : 'direct';
          _managedWarpPolicy = _managedWarpPolicy.copyWith(
            state: 'fallback',
            userConsented: true,
          );
        });
      }
      if (!baselineReady) {
        setState(() {
          _runtimeHeadline =
              'WARP не прошёл проверку. Выключите его и повторите подключение.';
        });
        if (!fallbackReported) {
          unawaited(_reportWarpRuntimeFallback(warpFailure));
        }
        return;
      }

      _activeConnectUsedWarp = false;
      if (!fallbackReported) {
        unawaited(_reportWarpRuntimeFallback(warpFailure));
      }
      var current = await _withRuntimeActionTimeout(
        'connectWithoutWarp',
        _runtimeEngine.connect,
      );
      current = await _settleRuntimeTransition(current);
      if (!mounted) {
        return;
      }
      setState(() {
        _runtimeSnapshot = current;
        _runtimeHeadline = current.phase == RuntimePhase.running
            ? 'POKROV подключен. WARP временно на паузе.'
            : current.message.trim().isEmpty
                ? 'Обычный VPN тоже не подключился. Попробуйте другую локацию.'
                : current.message;
      });
      if (current.phase == RuntimePhase.running) {
        if (_isConnectionProven(current)) {
          _finalizeProvenConnection(current);
        }
        _schedulePostConnectHostHealthRefresh(current);
        _recordProtectionEvent(
          kind: 'warp_fallback_connected',
          title: 'Обычная защита включена',
          detail:
              'WARP не прошёл проверку, поэтому POKROV автоматически сохранил рабочий обычный VPN.',
          tone: PokrovProtectionEventTone.warning,
        );
      } else if (_mustRefreshProfileAfterRuntimeFailure(current)) {
        _managedProfileDirty = true;
        _stagedNodeCode = '';
        _stagedVariantId = 'direct';
        _cachedProfileFallbackGate.markRuntimeProfileInvalid();
        _invalidateQuickSettingsProfile();
      }
      widget.shellController?.refresh();
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _runtimeHeadline = _runtimeUnexpectedErrorMessage(error);
      });
    } finally {
      _warpFallbackInFlight = false;
      if (mounted) {
        setState(() {
          _runtimeBusy = false;
          _runtimeDisconnecting = false;
        });
      }
    }
  }

  bool _mustRefreshProfileAfterRuntimeFailure(RuntimeSnapshot snapshot) {
    if (widget.appContext.hostPlatform != HostPlatform.android) {
      return false;
    }
    return const <String>{
      'core_egress_probe_failed',
      'core_egress_probe_unavailable',
    }.contains(snapshot.lastFailureKind?.trim());
  }

  Set<String> _activeAutomaticNodeExclusions() {
    final now = DateTime.now().toUtc();
    return <String>{
      for (final entry in _automaticNodeQuarantineUntil.entries)
        if (entry.value.isAfter(now)) entry.key,
    };
  }

  void _quarantineAutomaticNode(String nodeCode) {
    final normalized = nodeCode.trim().toLowerCase();
    if (normalized.isEmpty) {
      return;
    }
    final now = DateTime.now().toUtc();
    final retained = _automaticNodeQuarantineUntil.entries
        .where(
          (entry) => entry.key != normalized && entry.value.isAfter(now),
        )
        .toList(growable: false)
      ..sort((a, b) => b.value.compareTo(a.value));
    _automaticNodeQuarantineUntil
      ..clear()
      ..addEntries(
        retained.take(_maxAutomaticNodeQuarantineEntries - 1),
      )
      ..[normalized] = now.add(_automaticNodeQuarantineTtl);
    _clientExperience = _clientExperience.copyWith(
      automaticNodeQuarantineUntil: <String, String>{
        for (final entry in _automaticNodeQuarantineUntil.entries)
          entry.key: entry.value.toIso8601String(),
      },
    );
    _queueClientExperienceWrite();
  }

  void _cancelAutomaticFailover() {
    _automaticFailoverGeneration += 1;
    _automaticFailoverAttempts = 0;
    _automaticFailoverInFlight = false;
  }

  Future<void> _retryAutomaticLocationAfterEgressFailure(
    int ownerGeneration,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    try {
      if (!mounted ||
          ownerGeneration != _automaticFailoverGeneration ||
          _preferredNodeCode.trim().isNotEmpty) {
        return;
      }
      await _toggleRuntime();
    } finally {
      if (ownerGeneration == _automaticFailoverGeneration) {
        _automaticFailoverInFlight = false;
      }
    }
  }

  Future<void> _reportRoutingLessonCompleted() async {
    final service = _questEventService;
    if (service == null || _routingLessonReported) {
      return;
    }
    _routingLessonReported = true;
    try {
      await service.completeRoutingLesson(
        hostPlatform: widget.appContext.hostPlatform,
      );
    } catch (_) {
      _routingLessonReported = false;
      // Learning progress is best-effort and never blocks local route checks.
    }
  }

  void _reportPromoEvent(AppFirstPromoSlot slot, String eventName) {
    final service = _promoEventService;
    if (service == null) {
      return;
    }
    unawaited(
      service
          .reportPromoEvent(
            hostPlatform: widget.appContext.hostPlatform,
            eventName: eventName,
            slot: slot,
          )
          .catchError((_) {}),
    );
  }

  String _runtimeUnexpectedErrorMessage(Object error) {
    return switch (error) {
      TimeoutException() =>
        'POKROV не дождался ответа. Попробуйте еще раз, а если не поможет — напишите в поддержку.',
      _ =>
        'POKROV не смог начать подключение. Попробуйте еще раз, а если не поможет — напишите в поддержку: диагностику можно приложить прямо в чате.',
    };
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
      final nextPolicy = status.applyTo(_managedWarpPolicy).copyWith(
            // Telemetry is advisory: it may refresh runtime availability, but
            // it never owns a person's enable/revoke decision.
            userConsented: _warpRuntimeConsent,
          );
      setState(() {
        _managedWarpPolicy = nextPolicy;
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
    // Android returns from MethodChannel before its notification and VPN
    // consent sheets complete. Keep reading the host-owned pending state rather
    // than relying on a localized status message or a lifecycle resume.
    final maxAttempts = current.connectionPending ? 180 : 10;
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
      if (_isTerminalConnectMessage(current.message) ||
          !current.connectionPending) {
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

  void _promoteStagedLocationAfterFreshConnect() {
    final staged = _stagedNodeCode.trim().toLowerCase();
    final stagedVariant =
        normalizeClientLocationVariantId(_stagedVariantId) ?? 'direct';
    // A profile staged for a preceding failed connect is still fresh. Promote
    // it only once its later reconnect is confirmed running.
    if (staged.isEmpty ||
        (staged == _activeNodeCode && stagedVariant == _activeVariantId)) {
      return;
    }
    setState(() {
      _activeNodeCode = staged;
      _activeVariantId = stagedVariant;
    });
  }

  String get _homeLocationLabel {
    final preferredCode = (_preferredNodeCode.trim().isNotEmpty
            ? _preferredNodeCode
            : _clientExperience.preferredNodeCode)
        .trim()
        .toLowerCase();
    final activeCode = _activeNodeCode.trim().toLowerCase();
    final preferredVariant =
        normalizeClientLocationVariantId(_preferredVariantId) ?? 'direct';
    final activeVariant =
        normalizeClientLocationVariantId(_activeVariantId) ?? 'direct';
    if (_runtimeSnapshot?.phase == RuntimePhase.running) {
      if (widget.appContext.hostPlatform == HostPlatform.android &&
          _runtimeSnapshot?.coreEgressValidated != true) {
        return 'Локация проверяется';
      }
      if (activeCode.isEmpty) {
        return 'Локация проверяется';
      }
      final activeLabel = _locationLabelForNodeCode(
        activeCode,
        variantId: activeVariant,
      );
      return activeLabel;
    }
    // A confirmed running tunnel is the only event that promotes a pending
    // manual choice. If that reconnect fails, keep the last verified city
    // rather than implying that the newly staged location was ever active.
    if (activeCode.isNotEmpty &&
        (activeCode != preferredCode || activeVariant != preferredVariant)) {
      return _locationLabelForNodeCode(
        activeCode,
        variantId: activeVariant,
      );
    }
    if (preferredCode.isEmpty) {
      return 'Автоматически';
    }
    return _locationLabelForNodeCode(
      preferredCode,
      variantId: preferredVariant,
    );
  }

  String _locationLabelForNodeCode(
    String code, {
    String variantId = 'direct',
  }) {
    for (final country
        in _locationsCatalog?.countries ?? const <ClientLocationCountry>[]) {
      for (final city in country.cities) {
        if (city.code.trim().toLowerCase() != code) {
          continue;
        }
        final cityLabel = _locationCityDisplayName(city, country);
        if (variantId == 'direct') {
          return cityLabel;
        }
        final variantMatches = city.variants
            .where((variant) => variant.id == variantId)
            .toList(growable: false);
        return variantMatches.length == 1
            ? '$cityLabel · ${variantMatches.single.label}'
            : cityLabel;
      }
    }

    for (final node
        in _smartConnectProfile?.shortlist ?? const <SmartConnectNode>[]) {
      if (node.code.trim().toLowerCase() == code) {
        final countryCode = _locationCountryCodeFromNode(
          node.code,
          node.country,
        );
        final countryLabel = _locationCountryDisplayName(
          countryCode,
          node.country,
        );
        return countryLabel.isNotEmpty ? countryLabel : 'Выбранная локация';
      }
    }
    return 'Выбранная локация';
  }

  @override
  Widget build(BuildContext context) {
    final hasProvisionedAccess = !_managedProfileDirty ||
        (_runtimeSnapshot?.phase == RuntimePhase.running) ||
        ((_runtimeSnapshot?.stagedConfigPath ?? '').isNotEmpty);
    final sectionBuilders = <WidgetBuilder>[
      (context) => _QuickConnectSection(
            appContext: widget.appContext,
            freeProfileAccess: _freeProfileAccess,
            selectedRouteMode: _selectedRouteMode,
            locationLabel: _homeLocationLabel,
            runtimeSnapshot: _runtimeSnapshot,
            runtimeHeadline: _runtimeHeadline,
            runtimeBusy: _runtimeBusy,
            runtimeDisconnecting: _runtimeDisconnecting,
            primaryConnectEnabled: _canPrimaryConnect(_runtimeSnapshot),
            connectHintVisible: !_connectHintDismissed,
            revealHold: _firstLaunchStep != _FirstLaunchStep.ready,
            bonusSummary: _bonusSummary,
            subscriptionInfo: _subscriptionInfo,
            telegramBonusBusy: _telegramBonusBusy,
            warpPolicy: _managedWarpPolicy,
            warpRuntimeConsent: _warpRuntimeConsent,
            warpRuntimeActive: _warpRuntimeIsActive,
            warpBusy: _warpPolicyBusy,
            onToggleRuntime: _toggleRuntimeFromHome,
            onOpenConnectionDetails: _openProtectionCenter,
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
            notificationsUnread: _notificationsUnread,
            onOpenNotifications: _openNotificationsInbox,
            onOpenProfile: () => _selectTab(SeedTab.profile),
            onOpenPromoHandoff: _showSeedHandoff,
            onPromoEvent: _reportPromoEvent,
          ),
      (context) => _LocationsSection(
            appContext: widget.appContext,
            selectedRouteMode: _selectedRouteMode,
            hasProvisionedAccess: hasProvisionedAccess,
            smartConnectProfile: _smartConnectProfile,
            locationsCatalog: _locationsCatalog,
            locationsCatalogBusy: _locationsCatalogBusy,
            locationsCatalogError: _locationsCatalogError,
            locationsUsingCache: _locationsUsingCache,
            locationsCachedAt: _clientExperience.locationsCachedAt,
            onRefreshLocationsCatalog: () {
              unawaited(_refreshLocationsCatalog(measureDevice: true));
            },
            preferredNodeCode: _preferredNodeCode,
            preferredVariantId: _preferredVariantId,
            nodePreferenceBusy: _nodePreferenceBusy,
            onAutomaticLocationSelected: _setAutomaticLocation,
            onPreferredNodeSelected: _setPreferredLocation,
            favoriteNodeCodes: _clientExperience.favoriteNodeCodes,
            recentNodeCodes: _clientExperience.recentNodeCodes,
            onFavoriteNodeToggle: _toggleFavoriteLocation,
            onOpenEmergencyNetwork: () {
              unawaited(_openEmergencyNetwork());
            },
          ),
      (context) => _RulesSection(
            appContext: widget.appContext,
            selectedRouteMode: _selectedRouteMode,
            selectedAppIds: _selectedAppIds,
            routingPreferences: _clientExperience.routingPreferences,
            onRouteModeSelected: (mode) {
              _selectRouteMode(mode);
            },
            onSelectedAppAdded: _addSelectedAppId,
            onSelectedAppRemoved: _removeSelectedAppId,
            onRuAppPresetApplied: _applyRuAppPreset,
            onRoutingPreferencesChanged: _setRoutingPreferences,
            onReadCurrentWifi: _readCurrentWifi,
            onRequestWifiPermission: _requestCurrentWifiPermission,
            onOpenVpnSettings: _openSystemVpnSettings,
            onRoutingLessonCompleted: () {
              unawaited(_reportRoutingLessonCompleted());
            },
          ),
      (context) => _ProfileSection(
            appContext: widget.appContext,
            freeProfileAccess: _freeProfileAccess,
            selectedRouteMode: _selectedRouteMode,
            hasProvisionedAccess: hasProvisionedAccess,
            onOpenHandoff: _showSeedHandoff,
            onPromoEvent: _reportPromoEvent,
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
            systemSurfacePreferences: _systemSurfacePreferences,
            onSystemSurfacePreferencesChanged: _updateSystemSurfacePreferences,
            onOpenNotificationSettings: () => openPokrovNotificationSettings(
              widget.appContext.hostPlatform,
            ),
            notifications:
                _notificationsInbox?.items ?? const <ClientNotificationItem>[],
            notificationsUnread: _notificationsUnread,
            notificationsBusy: _notificationsBusy,
            notificationsUsingCache: _notificationsUsingCache,
            notificationsCachedAt: _clientExperience.notificationsCachedAt,
            onOpenNotifications: _markNotificationsRead,
            onRefreshNotifications: _refreshNotifications,
            onFetchDevices: _fetchClientDevices,
            onRevokeDevice: _revokeClientDevice,
            onIssuePairingCode: _issueDevicePairingCode,
            onCancelPairingCode: _cancelDevicePairingCode,
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

    // Edge-to-edge system chrome: transparent bars with icon brightness
    // following the active theme. Android reads this annotation; desktop
    // hosts ignore it.
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final overlayStyle =
        (isDarkTheme ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
            .copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
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
            child: AnnotatedRegion<SystemUiOverlayStyle>(
              value: overlayStyle,
              child: Scaffold(
                extendBody: !isDesktopShell,
                body: _SeedBackdrop(
                  child: SafeArea(
                    child: Stack(
                      children: [
                        Positioned.fill(child: shell),
                        // Welcome Handover: the gate leaves with a fade and a
                        // gentle 1.02 scale while the home reveal rises under
                        // it — onboarding hands over instead of hard-cutting.
                        Positioned.fill(
                          child: AnimatedSwitcher(
                            duration:
                                _firstLaunchExitAnimated && !disableAnimations
                                    ? _MotionTokens.standard
                                    : Duration.zero,
                            switchInCurve: _MotionTokens.emphasized,
                            switchOutCurve: _MotionTokens.emphasized,
                            transitionBuilder: (child, animation) =>
                                FadeTransition(
                              opacity: animation,
                              child: ScaleTransition(
                                scale: Tween<double>(
                                  begin: 1.02,
                                  end: 1,
                                ).animate(animation),
                                child: child,
                              ),
                            ),
                            child: _firstLaunchStep != _FirstLaunchStep.ready
                                ? _FirstLaunchGate(
                                    appContext: widget.appContext,
                                    step: _firstLaunchStep,
                                    restoreCodeController:
                                        _firstLaunchRestoreCodeController,
                                    busy: _firstLaunchBusy,
                                    onNewUser: _completeFirstLaunchAsNewUser,
                                    onReturningUser: _openFirstLaunchRestore,
                                    onBack: _backToFirstLaunchChoice,
                                    onRedeemCode: _redeemFirstLaunchRestoreCode,
                                    onOpenTelegram: _openDevicePairingBot,
                                    onOpenCabinet: () =>
                                        _openCabinetWithHandoff(
                                      widget.appContext.cabinetUrl,
                                    ),
                                  )
                                : const SizedBox.shrink(
                                    key: ValueKey('first-launch-gate-exited'),
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
        ),
      ),
    );
  }
}

/// The first live connection needs one consumer decision about device scope.
/// The selected [RouteMode] continues through the existing managed-profile
/// resolution path, which persists the device policy server-side.
Future<RouteMode?> _showFirstConnectRouteScopeSheet(
  BuildContext context, {
  required bool canSelectApps,
}) {
  return showModalBottomSheet<RouteMode>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    isScrollControlled: true,
    sheetAnimationStyle: _pokrovSheetAnimationStyle(context),
    builder: (sheetContext) {
      final p = PokrovPalette.of(sheetContext);
      return PopScope(
        canPop: false,
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            key: const ValueKey('first-connect-route-scope-sheet'),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Как должно работать устройство?',
                  style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                        color: p.ink,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Выберите один раз перед первым подключением. Изменить режим можно позже в разделе «Правила».',
                  style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                        color: p.muted,
                        height: 1.35,
                      ),
                ),
                const SizedBox(height: 18),
                Semantics(
                  button: true,
                  label: 'Всё устройство, рекомендуемый режим',
                  child: FilledButton.icon(
                    key: const ValueKey('first-connect-scope-whole-device'),
                    onPressed: () => Navigator.of(sheetContext).pop(
                      RouteMode.allExceptRu,
                    ),
                    icon: const Icon(Icons.public_rounded),
                    label: const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Всё устройство'),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Рекомендуем: POKROV работает для всего устройства, а российские сервисы остаются на обычном подключении.',
                  style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                        color: p.muted,
                        height: 1.3,
                      ),
                ),
                if (canSelectApps) ...[
                  const SizedBox(height: 16),
                  Semantics(
                    button: true,
                    label: 'Выбранные приложения',
                    child: OutlinedButton.icon(
                      key: const ValueKey('first-connect-scope-selected-apps'),
                      onPressed: () => Navigator.of(sheetContext).pop(
                        RouteMode.selectedApps,
                      ),
                      icon: const Icon(Icons.apps_rounded),
                      label: const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Выбранные приложения'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Настроить список приложений можно в разделе «Правила».',
                    style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                          color: p.muted,
                          height: 1.3,
                        ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}
