part of pokrov_app_shell;

class PokrovSeedApp extends StatefulWidget {
  const PokrovSeedApp({
    super.key,
    required this.appContext,
    this.bootstrapper,
    this.observability,
    this.supportTicketService,
    this.supportModeController,
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
    this.windowsTunnelAuthorizer,
    this.windowsShellPreferencesReader,
    this.windowsShellPreferencesUpdater,
    this.initialAcquisitionUri,
    this.acquisitionUriStream,
  });

  final SeedAppContext appContext;
  final ManagedProfileBootstrapper? bootstrapper;
  final PokrovClientObservability? observability;
  final SupportTicketService? supportTicketService;
  final PokrovSupportModeController? supportModeController;
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
  final PokrovWindowsTunnelAuthorizer? windowsTunnelAuthorizer;
  final PokrovWindowsShellPreferencesReader? windowsShellPreferencesReader;
  final PokrovWindowsShellPreferencesUpdater? windowsShellPreferencesUpdater;
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
      builder: (context, child) => PokrovAppMotionGate(
        child: child ?? const SizedBox.shrink(),
      ),
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
        observability: widget.observability,
        supportTicketService: widget.supportTicketService,
        supportModeController: widget.supportModeController,
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
        windowsTunnelAuthorizer: widget.windowsTunnelAuthorizer,
        windowsShellPreferencesReader: widget.windowsShellPreferencesReader,
        windowsShellPreferencesUpdater: widget.windowsShellPreferencesUpdater,
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
    // The shared press surface keeps brand feedback quiet. Native scroll,
    // route, switch, pointer and keyboard behavior remain platform-adaptive.
    splashColor: Colors.transparent,
    highlightColor: tokens.ink.withValues(alpha: 0.05),
    pageTransitionsTheme: pokrovAdaptivePageTransitionsTheme(),
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
    this.observability,
    this.supportTicketService,
    this.supportModeController,
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
    this.windowsTunnelAuthorizer,
    this.windowsShellPreferencesReader,
    this.windowsShellPreferencesUpdater,
    this.initialAcquisitionUri,
    this.acquisitionUriStream,
  });

  final SeedAppContext appContext;
  final ManagedProfileBootstrapper? bootstrapper;
  final PokrovClientObservability? observability;
  final SupportTicketService? supportTicketService;
  final PokrovSupportModeController? supportModeController;
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
  final PokrovWindowsTunnelAuthorizer? windowsTunnelAuthorizer;
  final PokrovWindowsShellPreferencesReader? windowsShellPreferencesReader;
  final PokrovWindowsShellPreferencesUpdater? windowsShellPreferencesUpdater;
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
  late final ConnectionManager _connectionManager;
  void _onConnectionChanged() {
    if (!mounted) return;
    setState(() {});
    widget.shellController?.refresh();
  }
  RuntimeSnapshot? get _runtimeSnapshot => _connectionManager.snapshot;
  bool get _runtimeBusy => _connectionManager.busy;
  ConnectionExperienceState get _connectionExperience => _connectionManager.experience;
  ConnectionPresentation get _connectionPresentation => _connectionManager.presentation;
  bool get _managedProfileDirty => _connectionManager._managedProfileDirty;
  int get _managedProfileRevision => _connectionManager._managedProfileRevision;
  ValueNotifier<RuntimeSnapshot?> get _protectionRuntimeSnapshot => _connectionManager._protectionRuntimeSnapshot;
  RouteMode get _selectedRouteMode => _connectionManager._selectedRouteMode;
  PokrovClientExperienceState get _clientExperience => _connectionManager._clientExperience;
  set _clientExperience(PokrovClientExperienceState value) => _connectionManager.updateExperience(value);
  bool get _clientExperienceLoaded => _connectionManager._clientExperienceLoaded;
  int get _clientExperienceRevision => _connectionManager._clientExperienceRevision;
  bool get _connectHintDismissed => _connectionManager._connectHintDismissed;
  set _connectHintDismissed(bool value) => _connectionManager.setConnectHintDismissed(value);
  String? get _runtimeHeadline => _connectionManager._runtimeHeadline;
  set _runtimeHeadline(String? value) => _connectionManager.setNotice(value);
  List<String> get _selectedAppIds => List.unmodifiable(_connectionManager._selectedAppIds);
  WarpRuntimePolicy get _managedWarpPolicy => _connectionManager._managedWarpPolicy;
  bool get _warpRuntimeConsent => _connectionManager._warpRuntimeConsent;
  bool get _warpPolicyBusy => _connectionManager._warpPolicyBusy;
  bool get _activeConnectUsedWarp => _connectionManager._activeConnectUsedWarp;
  SmartConnectProfile? get _smartConnectProfile => _connectionManager._smartConnectProfile;
  String get _preferredNodeCode => _connectionManager._preferredNodeCode;
  String get _preferredVariantId => _connectionManager._preferredVariantId;
  String get _activeNodeCode => _connectionManager._activeNodeCode;
  String get _activeVariantId => _connectionManager._activeVariantId;

  void _queueClientExperienceWrite() => _connectionManager._queueClientExperienceWrite();
  bool get _selectedAppsRouteNeedsSelection => _connectionManager._selectedAppsRouteNeedsSelection;
  Future<void> _reportClientLifecycle(String phase, {bool connected = false, String errorCode = '', bool? retryable}) => _connectionManager._reportClientLifecycle(phase, connected: connected, errorCode: errorCode, retryable: retryable);
  Future<void> _reportClientRuntimeError(String code) => _connectionManager._reportClientRuntimeError(code);
  Future<void> _resumeRuntimeAndTrustedWifiChecks() => _connectionManager.resume();
  Future<PokrovWifiNetworkStatus> _readCurrentWifi() => _connectionManager._readCurrentWifi();
  Future<void> _repairRuntime({ValueChanged<_ProtectionRepairStep>? onStep, ValueChanged<Future<void> Function()?>? onCancelAvailable}) => _connectionManager.repair(onStep: onStep, onCancelAvailable: onCancelAvailable);
  Future<void> _reportFirstSessionEvent(String eventName, {required String stage, required String result, String errorCode = '', bool? retryable}) => _connectionManager._reportFirstSessionEvent(eventName, stage: stage, result: result, errorCode: errorCode, retryable: retryable);
  Future<void> _refreshRuntimeSnapshot() => _connectionManager.refresh();
  bool get _routingCatalogEnabled => _connectionManager._routingCatalogEnabled;
  bool get _selectiveServicesAvailable => _connectionManager._selectiveServicesAvailable;
  Future<_CatalogServiceSelectionData> _loadCatalogServiceSelection({required bool Function() isCurrent, required Future<void> cancelled}) => _connectionManager._loadCatalogServiceSelection(isCurrent: isCurrent, cancelled: cancelled);
  Future<_RoutingCatalogPreview?> _loadRoutingCatalogPreview() => _connectionManager._loadRoutingCatalogPreview();
  Future<Set<String>> _loadVerifiedCatalogDirectApps(bool fresh) => _connectionManager._loadVerifiedCatalogDirectApps(fresh);
  Future<void> _setWarpRuntimeConsent(bool value) { PokrovHaptics.tap(); return _connectionManager._setWarpRuntimeConsent(value); }
  bool _canPrimaryConnect(RuntimeSnapshot? snapshot) => _connectionManager._canPrimaryConnect(snapshot);


  void _selectRouteMode(RouteMode mode) { PokrovHaptics.tap(); _connectionManager.selectRouteMode(mode); }
  void _setRoutingPreferences(PokrovRoutingPreferences value) { PokrovHaptics.tap(); _connectionManager.setRoutingPreferences(value); }
  void _applyRoutingPreferences(PokrovRoutingPreferences value) => _connectionManager.applyRoutingPreferences(value);
  Future<void> _setPreferredLocation(String node, String variant) { PokrovHaptics.tap(); return _connectionManager.setPreferredLocation(node, variant); }
  void _addSelectedAppId(String value) => _connectionManager.addSelectedAppId(value);
  void _applyRuAppPreset(RouteMode mode, List<String> apps, bool verified) { PokrovHaptics.tap(); _connectionManager.applyRuAppPreset(mode, apps, verified); }
  Future<void> _setAutomaticLocation() { PokrovHaptics.tap(); return _connectionManager.setAutomaticLocation(); }
  void _removeSelectedAppId(String value) => _connectionManager.removeSelectedAppId(value);
  void _recordAndroidSelectedAppCount() => _connectionManager._recordAndroidSelectedAppCount();
  void _reconcilePreferredVariantAfterCatalogRefresh(ClientLocationsCatalog catalog) => _connectionManager.reconcilePreferredVariantAfterCatalogRefresh(catalog);

  Future<void> _toggleRuntime({bool reconnectAfterDisconnect = false}) async {
    if (_runtimeBusy) return _connectionManager.toggle(reconnectAfterDisconnect: reconnectAfterDisconnect);
    if (_connectionManager.retainsProtection && !reconnectAfterDisconnect) {
      return _connectionManager.disconnect();
    }
    final startingGeneration = _connectionManager.attemptId;
    final willConnect = _runtimeSnapshot?.phase != RuntimePhase.running || reconnectAfterDisconnect;
    if (willConnect && !_clientExperienceLoaded) {
      await _clientExperienceRestore;
      if (!mounted || startingGeneration != _connectionManager.attemptId) return;
    }
    if (willConnect && _selectedRouteMode == RouteMode.selectiveServices &&
        (!_selectiveServicesAvailable || _clientExperience.routingPreferences.selectedCatalogServiceIds.isEmpty)) {
      await _connectionManager.setInterfaceMode(PokrovInterfaceMode.advanced);
      if (!mounted) return;
      setState(() {
        _selectedIndex = SeedTab.rules.index;
        _runtimeHeadline = _selectiveServicesAvailable
            ? 'Выберите хотя бы один поддерживаемый сервис в разделе «Правила».'
            : 'Режим выбранных сервисов недоступен. Выберите другой режим в разделе «Правила».';
      });
      return;
    }

    final confirmedRouteMode = _clientExperience.firstRouteScopeMode;
    if (_runtimeSnapshot?.phase != RuntimePhase.running &&
        (!_clientExperience.firstRouteScopeConfirmed ||
            confirmedRouteMode == null ||
            !(confirmedRouteMode == RouteMode.selectiveServices && _selectiveServicesAvailable) &&
              !widget.appContext.runtimeProfile.supportedRouteModes.contains(confirmedRouteMode))) {
      final routeMode = _clientExperience.interfaceMode == PokrovInterfaceMode.simple
          ? _selectedRouteMode
          : await _showFirstConnectRouteScopeSheet(
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

    if (!mounted || startingGeneration != _connectionManager.attemptId) return;
    return _connectionManager.toggle(reconnectAfterDisconnect: reconnectAfterDisconnect);
  }

  int _selectedIndex = 0;
  late final ManagedProfileBootstrapper _bootstrapper;
  late final AccountSessionCoordinator _accountSessionCoordinator;
  late final Future<void> _clientExperienceRestore;
  late final AppFirstBonusActionService? _bonusActionService;
  late final AppFirstReleaseActionService? _releaseActionService;
  late final AppFirstAcquisitionService? _acquisitionService;
  late final AppFirstQuestEventService? _questEventService;
  late final AppFirstPromoEventService? _promoEventService;
  late final AppFirstClientDataService? _clientDataService;
  late final AppFirstReleaseHealthService? _releaseHealthService;
  late final SupportTicketService _supportTicketService;
  late final PokrovSupportModeController _supportModeController;
  late final bool _ownsSupportModeController;
  late final FirstSessionCoordinator _firstSessionCoordinator;
  late final Future<void> _firstSessionLoadFuture;
  late final PokrovClientExperienceStore _clientExperienceStore;
  bool _locationsUsingCache = false;
  bool _notificationsUsingCache = false;
  final TextEditingController _firstLaunchRestoreCodeController =
      TextEditingController();
  // Hidden until the store confirms the hint was never dismissed, so the
  // one-time pulse never flashes for returning users while the read is
  // in flight.
  String _telegramBonusStatus = 'Получить код';
  bool _telegramBonusBusy = false;
  bool _telegramLinkVerificationPending = false;
  bool _telegramBonusCanClaim = false;
  String? _telegramBonusError;
  AppFirstBonusSummary? _bonusSummary;
  bool _bonusSummaryBusy = false;
  bool _bonusSummaryRequested = false;
  String? _bonusSummaryError;
  bool _bonusRewardBusy = false;
  bool _routingLessonReported = false;
  // Null means no local decision in this shell lifetime. Once a person opts
  // out, stale profile/status payloads must never re-enable WARP for them.
  ClientLocationsCatalog? get _locationsCatalog => _connectionManager.locationsCatalog;
  set _locationsCatalog(ClientLocationsCatalog? value) => _connectionManager.updateLocationsCatalog(value);
  bool get _nodePreferenceBusy => _connectionManager.nodePreferenceBusy;
  bool _locationsCatalogBusy = false;
  String? _locationsCatalogError;
  PokrovSystemSurfacePreferences _systemSurfacePreferences =
      const PokrovSystemSurfacePreferences();
  PokrovWindowsShellPreferences _windowsShellPreferences =
      const PokrovWindowsShellPreferences();
  ClientNotificationInbox? _notificationsInbox;
  bool _notificationsBusy = false;
  int _notificationsUnread = 0;
  final ClientUpdateCoordinator _clientUpdateCoordinator =
      ClientUpdateCoordinator();
  bool _clientLifecycleOpenReported = false;
  StreamSubscription<Uri>? _acquisitionUriSubscription;

  _FirstLaunchStep get _firstLaunchStep =>
      _firstSessionCoordinator._stepForView;
  bool get _firstLaunchBusy => _firstSessionCoordinator.busy;
  bool get _firstLaunchExitAnimated => _firstSessionCoordinator.exitAnimated;

  AppFirstAccountActionService? get _accountActionService =>
      _accountSessionCoordinator.accountActions;
  FreeProfileAccess? get _freeProfileAccess =>
      _accountSessionCoordinator.freeProfileAccess;
  ClientSubscriptionInfo? get _subscriptionInfo =>
      _accountSessionCoordinator.subscriptionInfo;
  set _subscriptionInfo(ClientSubscriptionInfo? value) =>
      _accountSessionCoordinator.updateSubscriptionInfo(value);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final runtimeEngine = createRuntimeEngine(hostPlatform: widget.appContext.hostPlatform);
    widget.shellController?._attach(
      toggle: _toggleRuntime,
      isConnected: () => _connectionPresentation.isVerified,
      retainsProtection: () => _connectionManager.retainsProtection,
      isBusy: () => _runtimeBusy,
      canToggle: () =>
          _connectionManager.retainsProtection ||
          _clientExperienceLoaded &&
          _firstLaunchStep == _FirstLaunchStep.ready &&
          (_runtimeSnapshot?.phase == RuntimePhase.running ||
              _canPrimaryConnect(_runtimeSnapshot)),
    );
    final transportEnabled = const bool.fromEnvironment('POKROV_TRANSPORT_ENABLED');
    final transportStore = transportEnabled && runtimeEngine is RuntimeBootClock &&
        const {HostPlatform.android, HostPlatform.windows, HostPlatform.linux}
            .contains(widget.appContext.hostPlatform)
        ? TransportManifestStore(
            verifier: TransportManifestVerifier.pinned(clientRelease: pokrovClientVersion,
              coreRelease: const String.fromEnvironment('POKROV_TRANSPORT_CORE_RELEASE',
                defaultValue: '1.0.0')),
            enabled: true, clock: runtimeEngine as RuntimeBootClock,
            onCommitted: (admission) async {
              await _connectionManager.applyTransportAdmission(admission);

            })
        : null;
    final bootstrapper = widget.bootstrapper ??
        AppFirstRuntimeBootstrapper(
          apiBaseUrl: widget.appContext.apiBaseUrl,
          deviceNameResolver: resolvePokrovDeviceName,
          transportManifestStore: transportStore,
        );
    _bootstrapper = bootstrapper;
    _accountSessionCoordinator = AccountSessionCoordinator(
      accountActions: bootstrapper is AppFirstAccountActionService
          ? bootstrapper as AppFirstAccountActionService
          : null,
    );
    _bonusActionService = bootstrapper is AppFirstBonusActionService
        ? bootstrapper as AppFirstBonusActionService
        : null;
    _releaseActionService = bootstrapper is AppFirstReleaseActionService
        ? bootstrapper as AppFirstReleaseActionService
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
    _clientDataService = bootstrapper is AppFirstClientDataService
        ? bootstrapper as AppFirstClientDataService
        : null;
    _releaseHealthService = bootstrapper is AppFirstReleaseHealthService
        ? bootstrapper as AppFirstReleaseHealthService
        : null;
    _supportTicketService = widget.supportTicketService ??
        AppFirstSupportTicketService(apiBaseUrl: widget.appContext.apiBaseUrl);
    _ownsSupportModeController = widget.supportModeController == null;
    _supportModeController = widget.supportModeController ??
        PokrovSupportModeController(
          signingPublicKeysById: pokrovSupportSigningKeyId.isNotEmpty &&
                  pokrovSupportSigningPublicKeyB64.isNotEmpty
              ? <String, String>{
                  pokrovSupportSigningKeyId: pokrovSupportSigningPublicKeyB64,
                }
              : const <String, String>{},
          platform: widget.appContext.hostPlatform.name,
          appVersion: pokrovClientVersion,
          buildNumber: pokrovClientBuildNumber,
        );
    _supportModeController.addListener(_onSupportModeChanged);
    unawaited(_supportModeController.initialize());
    _firstSessionCoordinator = FirstSessionCoordinator(
      store: widget.firstLaunchStore ?? const PokrovFileFirstLaunchStore(),
    );
    _clientExperienceStore = widget.clientExperienceStore;
    _connectionManager = ConnectionManager(
      appContext: widget.appContext,
      runtimeEngine: runtimeEngine,
      bootstrapper: _bootstrapper,
      accountSessionCoordinator: _accountSessionCoordinator,
      firstSessionCoordinator: _firstSessionCoordinator,
      clientExperienceStore: _clientExperienceStore,
      connectHintStore: widget.connectHintStore,
      observability: widget.observability,
      actionTimeout: widget.runtimeActionTimeout,
      currentWifiProbe: widget.currentWifiProbe,
      windowsTunnelAuthorizer: widget.windowsTunnelAuthorizer,
      authorizeAndroidConnect: _authorizeAndroidVpnConnect,
      refreshSubscription: _refreshSubscriptionInfo,
      onNotice: (message, tone) {
        if (mounted) showPokrovSnack(context, message, tone: tone);
      },
    );
    _connectionManager.addListener(_onConnectionChanged);
    final acquisitionUriStream = widget.acquisitionUriStream;
    if (acquisitionUriStream != null) {
      _acquisitionUriSubscription = acquisitionUriStream.listen(
        (uri) => unawaited(_consumeAcquisitionUri(uri)),
        onError: (_) {},
      );
    }
    _firstSessionLoadFuture = _loadFirstLaunchState();
    unawaited(_loadConnectHintState());
    _clientExperienceRestore = _restoreClientExperience();
    unawaited(_clientExperienceRestore);
    _refreshRuntimeSnapshot();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.observability?.markUiReady();
      final initialAcquisitionUri = widget.initialAcquisitionUri;
      if (initialAcquisitionUri != null) {
        unawaited(_consumeAcquisitionUri(initialAcquisitionUri));
      }
      unawaited(_checkForClientUpdate());
      unawaited(_refreshAccountSummaryAfterFirstSessionLoad());
      unawaited(_loadSystemSurfacePreferences());
      unawaited(_loadWindowsShellPreferences());
    });
  }

  void _onSupportModeChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _consumeAcquisitionUri(Uri uri) async {
    final service = _acquisitionService;
    final handoff = PokrovAcquisitionHandoff.tryParse(
      uri,
      hostPlatform: widget.appContext.hostPlatform,
    );
    if (service == null || handoff == null) {
      if (mounted && _firstSessionCoordinator.rejectInvalidAcquisition()) {
        setState(() {});
      }
      return;
    }
    if (!_firstSessionCoordinator.beginAcquisition(handoff.handle)) {
      return;
    }
    if (mounted) {
      setState(() {});
    }
    var succeeded = false;
    try {
      await service.consumeAcquisitionHandoff(
        hostPlatform: widget.appContext.hostPlatform,
        handle: handoff.handle,
        purpose: handoff.purpose,
      );
      succeeded = true;
    } catch (_) {
      // Attribution is best-effort and must never block onboarding, access,
      // or normal app use. The server validates expiry, purpose and replay.
    } finally {
      _firstSessionCoordinator.finishAcquisition(succeeded: succeeded);
      if (mounted) {
        setState(() {});
      }
      unawaited(
        _reportEstablishedFirstSession(
          eventName: succeeded
              ? 'acquisition_handoff_received'
              : 'acquisition_handoff_failed',
          stage: 'acquisition_handoff',
          result: succeeded ? 'received' : 'failure',
          errorCode: succeeded ? '' : 'acquisition_handoff_failed',
          retryable: !succeeded,
          includeHome: false,
        ),
      );
    }
  }

  Future<void> _refreshAccountSummaryAfterFirstSessionLoad() async {
    await _firstSessionLoadFuture;
    if (!mounted || !_firstSessionCoordinator.isReady) {
      return;
    }
    await _reportClientOpenOnce();
    await _reportEstablishedFirstSession(includeHome: true);
    await _refreshAccountSummary();
  }

  Future<void> _refreshAccountSummary() async {
    await _clientExperienceRestore;
    if (!mounted) return;
    await _accountSessionCoordinator.refreshSummary(
        refreshSubscription: _refreshSubscriptionInfo,
        refreshBonus: _loadBonusSummary,
        refreshInbox: _refreshNotifications,
        isActive: () => mounted,
      );
    await _connectionManager._refreshSmartAccessLeases();
  }

  Future<void> _restoreClientExperience() async {
    final restoreRevision = _clientExperienceRevision;
    try {
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
        _connectionManager.restoreConnectionPreferences(effectiveState, restoredQuarantine);
        if (_locationsCatalog == null &&
            effectiveState.cachedLocations != null) {
          _locationsCatalog = effectiveState.cachedLocations;
          _locationsUsingCache = true;
        }
        if (_notificationsInbox == null &&
            effectiveState.cachedNotifications != null) {
          _notificationsInbox = effectiveState.cachedNotifications;
          _notificationsUnread =
              effectiveState.cachedNotifications!.unreadCount;
          _notificationsUsingCache = true;
        }
      });
      _recordAndroidSelectedAppCount();
      unawaited(_refreshNotifications());
    } catch (_) {
      // Local convenience state may be missing or unreadable after an update.
      // Keep the safe defaults and let the user choose again in the UI.
    } finally {
      if (mounted) {
        setState(() {
          _connectionManager.markExperienceLoaded();
        });
        widget.shellController?.refresh();
      }
    }
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

  void _openRulesForSelectedApps() {
    unawaited(_connectionManager.setInterfaceMode(PokrovInterfaceMode.advanced));
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
    if (tab == SeedTab.rules &&
        _clientExperience.interfaceMode == PokrovInterfaceMode.simple) {
      tab = SeedTab.profile;
    }
    setState(() {
      _selectedIndex = tab.index;
    });
    if (tab == SeedTab.locations) {
      unawaited(_refreshLocationsCatalog());
    }
    if (tab == SeedTab.profile && widget.bootstrapper != null) {
      unawaited(_refreshAccountSummary());
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
      // City probe targets are direct Node addresses. A selected or running
      // bridge must keep those targets unopened, including an explicit refresh.
      final bridgeSelected =
          (normalizeClientLocationVariantId(_preferredVariantId) ?? 'direct') !=
              'direct' ||
          (_runtimeSnapshot?.phase == RuntimePhase.running &&
              (normalizeClientLocationVariantId(_activeVariantId) ?? 'direct') !=
                  'direct') ||
          serverCatalog.transportProfile == 'ru_bridge_relay';
      final measurements = measureDevice && !bridgeSelected
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
      _reconcilePreferredVariantAfterCatalogRefresh(catalog);
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

  Future<bool> _refreshSubscriptionInfo({bool showFailure = false}) async {
    final service = _clientDataService;
    if (service == null) {
      return false;
    }
    final observability = widget.observability;
    observability?.recordAuthRequestStarted();
    observability?.recordEntitlementRefreshStarted();
    try {
      final info = await service.fetchClientSubscription(
        hostPlatform: widget.appContext.hostPlatform,
      );
      observability?.recordAuthRequestFinished();
      observability?.recordEntitlementRefreshFinished();
      if (!mounted) {
        return false;
      }
      setState(() {
        _subscriptionInfo = info;
        if (info.telegramLinked) {
          _telegramLinkVerificationPending = false;
          _telegramBonusStatus = info.telegramUsername.trim().isEmpty
              ? 'Telegram привязан'
              : '@${info.telegramUsername.trim()}';
          _telegramBonusError = null;
        }
      });
      if (info.lane == 'expiredOrBlocked') {
        await _connectionManager.denyAccess();
      }
      return true;
    } on Object catch (error) {
      final authCode = switch (error) {
        BootstrapFailure failure
            when failure.operationalErrorCode == 'API-004' =>
          'AUTH-002',
        BootstrapFailure failure
            when failure.operationalErrorCode == 'API-005' =>
          'AUTH-005',
        BootstrapFailure failure => failure.operationalErrorCode,
        _ => 'API-002',
      };
      observability?.recordAuthRequestFinished(errorCode: authCode);
      observability?.recordEntitlementRefreshFinished(
        errorCode: authCode,
      );
      unawaited(_reportClientRuntimeError('subscription_refresh_failed'));
      if (mounted && showFailure) {
        showPokrovSnack(
          context,
          'Аккаунт привязан, но профиль не обновился. Проверьте соединение и повторите.',
          tone: PokrovSnackTone.danger,
        );
      }
      return false;
    }
  }

  Future<void> _refreshNotifications() async {
    final service = _clientDataService;
    if (service == null ||
        _notificationsBusy ||
        !_firstSessionCoordinator.isReady) {
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
      onDismiss: _dismissNotifications,
      onOpenHandoff: _showSeedHandoff,
    );
  }

  Future<bool> _dismissNotifications(List<String> ids) async {
    final normalizedIds = ids
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (normalizedIds.isEmpty) {
      return true;
    }
    final service = _clientDataService;
    if (service == null) {
      return false;
    }
    try {
      final ok = await service.dismissClientNotifications(
        hostPlatform: widget.appContext.hostPlatform,
        ids: normalizedIds,
      );
      if (!ok || !mounted) {
        return ok;
      }
      final inbox = _notificationsInbox;
      final remaining = inbox?.items
              .where((item) => !normalizedIds.contains(item.id))
              .toList(growable: false) ??
          const <ClientNotificationItem>[];
      final updated = ClientNotificationInbox(
        items: remaining,
        nextCursor: inbox?.nextCursor ?? '',
        unreadCount: remaining.where((item) => !item.read).length,
      );
      setState(() {
        _notificationsInbox = updated;
        _notificationsUnread = updated.unreadCount;
        _notificationsUsingCache = false;
        _clientExperience = _clientExperience.copyWith(
          cachedNotifications: updated,
          notificationsCachedAt: DateTime.now().toUtc().toIso8601String(),
        );
      });
      _queueClientExperienceWrite();
      return true;
    } on Object {
      return false;
    }
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
    _connectionManager.removeListener(_onConnectionChanged);
    _connectionManager.dispose();
    unawaited(_acquisitionUriSubscription?.cancel());
    _acquisitionUriSubscription = null;
    WidgetsBinding.instance.removeObserver(this);
    _supportModeController.removeListener(_onSupportModeChanged);
    if (_ownsSupportModeController) {
      _supportModeController.dispose();
    }
    widget.shellController?._detach();
    _firstLaunchRestoreCodeController.dispose();
    final observability = widget.observability;
    if (observability != null) {
      unawaited(observability.markCleanExit());
      unawaited(observability.flush());
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      final observability = widget.observability;
      if (observability != null) {
        unawaited(observability.markCleanExit());
        unawaited(observability.flush());
      }
      return;
    }
    if (state == AppLifecycleState.resumed) {
      unawaited(_resumeRuntimeAndTrustedWifiChecks());
      unawaited(_checkForClientUpdate());
      if (_telegramLinkVerificationPending) {
        unawaited(_verifyTelegramLinkAfterHandoff());
        unawaited(_refreshNotifications());
      } else if (_firstSessionCoordinator.isReady) {
        // A browser/cabinet visit may change access on the server. Refresh the
        // existing account on return without changing the selected tab or
        // treating the browser return itself as payment confirmation.
        unawaited(_refreshAccountSummary());
      }
    }
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

  Future<void> _loadWindowsShellPreferences() async {
    if (widget.appContext.hostPlatform != HostPlatform.windows) {
      return;
    }
    final reader = widget.windowsShellPreferencesReader;
    final preferences = reader != null
        ? await reader()
        : await readPokrovWindowsShellPreferences(
            widget.appContext.hostPlatform,
          );
    if (!mounted) {
      return;
    }
    setState(() {
      _windowsShellPreferences = preferences;
    });
  }

  Future<bool> _updateWindowsShellPreferences(
    PokrovWindowsShellPreferences preferences,
  ) async {
    final updater = widget.windowsShellPreferencesUpdater;
    final saved = updater != null
        ? await updater(preferences)
        : await updatePokrovWindowsShellPreferences(
            widget.appContext.hostPlatform,
            preferences,
          );
    if (saved == null || !mounted) {
      return false;
    }
    setState(() {
      _windowsShellPreferences = saved;
    });
    return true;
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
    if (releaseActions == null) {
      return;
    }
    await _clientUpdateCoordinator.checkAndPresent(
      loadMetadata: () => releaseActions.fetchClientApps(
        hostPlatform: widget.appContext.hostPlatform,
        currentVersion: pokrovClientVersion,
        channel: 'stable',
      ),
      hostPlatform: widget.appContext.hostPlatform,
      isActive: () => mounted,
      onUpdateAvailable: () {
        unawaited(_reportClientLifecycle('update_available'));
      },
      presentUpdate: (update) {
        if (!mounted) {
          return Future<void>.value();
        }
        return showPokrovClientUpdatePrompt(
          context: context,
          update: update,
          sheetAnimationStyle: _pokrovSheetAnimationStyle(context),
          onUpdate: () => unawaited(_openClientUpdateDownload(update)),
        );
      },
      onFailure: (_, __) {
        widget.observability?.recordUpdateCheckFailed();
        unawaited(
          _reportClientLifecycle(
            'failed',
            errorCode: 'update_check_failed',
            retryable: true,
          ),
        );
        // Update checks are advisory; never block the app on startup.
      },
    );
  }

  Future<void> _openClientUpdateDownload(ClientAppUpdateInfo update) async {
    final uri = update.trustedHandoffUri;
    if (uri == null) {
      widget.observability?.recordUpdateCheckFailed();
      if (mounted) {
        showPokrovSnack(
          context,
          'Ссылка обновления отклонена. Попробуйте позже.',
          tone: PokrovSnackTone.danger,
        );
      }
      return;
    }
    final updateChannel = widget.appContext.hostPlatform == HostPlatform.windows
        ? PokrovOperationalUpdateChannel.windows
        : PokrovOperationalUpdateChannel.direct;
    widget.observability?.recordUpdateInstallStarted(
      channel: updateChannel,
    );
    if (widget.appContext.hostPlatform == HostPlatform.android) {
      unawaited(_reportClientLifecycle('update_download_started'));
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
          return PokrovClientUpdateProgressDialog(
            progress: progress,
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
          widget.observability?.recordUpdateInstallFinished(
            channel: updateChannel,
          );
          unawaited(_reportClientLifecycle('update_installer_opened'));
          showPokrovSnack(
            context,
            'Обновление проверено. Подтвердите установку в системном окне.',
            tone: PokrovSnackTone.success,
          );
        case PokrovClientUpdateInstallStatus.storeOpened:
          widget.observability?.recordUpdateInstallFinished(
            channel: PokrovOperationalUpdateChannel.store,
          );
          unawaited(_reportClientLifecycle('update_store_opened'));
          showPokrovSnack(
            context,
            'Открыли страницу POKROV в магазине. Обновление установит магазин.',
            tone: PokrovSnackTone.success,
          );
        case PokrovClientUpdateInstallStatus.permissionRequired:
          widget.observability?.recordUpdateInstallFinished(
            channel: updateChannel,
            failure: ClientUpdateFailure.androidPermission,
          );
          unawaited(
            _reportClientLifecycle(
              'failed',
              errorCode: 'update_permission_required',
              retryable: true,
            ),
          );
          showPokrovSnack(
            context,
            'Разрешите POKROV устанавливать обновления. Скачанный APK уже проверен.',
          );
        case PokrovClientUpdateInstallStatus.unsupported:
        case PokrovClientUpdateInstallStatus.failed:
          widget.observability?.recordUpdateInstallFinished(
            channel: updateChannel,
            failure: ClientUpdateFailure.installer,
          );
          unawaited(
            _reportClientLifecycle(
              'failed',
              errorCode: 'update_download_failed',
              retryable: true,
            ),
          );
          showPokrovSnack(
            context,
            'Не удалось скачать или проверить обновление. Попробуйте еще раз.',
            tone: PokrovSnackTone.danger,
          );
      }
      return;
    }
    final opened = await _launchExternalHandoff(uri);
    widget.observability?.recordUpdateInstallFinished(
      channel: updateChannel,
      failure: opened ? null : ClientUpdateFailure.installer,
    );
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
    final isPairingCode = _looksLikeDevicePairingCode(code);

    final accountActions = _accountActionService;
    if (accountActions == null) {
      await _openSafeHandoff('redeem', code);
      return false;
    }

    try {
      PokrovHaptics.tap();
      if (isPairingCode) {
        final paired = await accountActions.claimDevicePairingCode(
          hostPlatform: widget.appContext.hostPlatform,
          code: code,
        );
        if (!mounted) {
          return paired.ok;
        }
        setState(() {
          _connectionManager.markProfileDirty();
          _subscriptionInfo = null;
          _runtimeHeadline = 'Устройство привязано к вашему аккаунту.';
        });
        unawaited(_loadBonusSummary(force: true));
        final profileUpdated = await _refreshSubscriptionInfo(
          showFailure: true,
        );
        unawaited(_refreshNotifications());
        unawaited(_refreshLocationsCatalog());
        if (!mounted) {
          return paired.ok;
        }
        showPokrovSnack(
          context,
          profileUpdated
              ? 'Устройство и профиль привязаны. Код больше не действует.'
              : 'Устройство привязано. Обновите профиль, когда сеть восстановится.',
          tone: profileUpdated ? PokrovSnackTone.success : PokrovSnackTone.info,
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
        _connectionManager.markProfileDirty();
        _runtimeHeadline = updatesAccess
            ? 'Код активирован. Доступ обновлен.'
            : 'Код обработан.';
      });
      final confirmationText = _runtimeHeadline ?? '';
      unawaited(_loadBonusSummary(force: true));
      showPokrovSnack(context, confirmationText, tone: PokrovSnackTone.success);
      return true;
    } on BootstrapFailure catch (error) {
      unawaited(
        _reportClientRuntimeError(
          isPairingCode ? 'pairing_claim_failed' : 'redeem_failed',
        ),
      );
      if (!mounted) {
        return false;
      }
      showPokrovSnack(
        context,
        error.message,
        tone: PokrovSnackTone.danger,
      );
      return false;
    } on Object {
      unawaited(
        _reportClientRuntimeError(
          isPairingCode ? 'pairing_claim_failed' : 'redeem_failed',
        ),
      );
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
    } on Object {
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
    if (_telegramLinkVerificationPending) {
      await _verifyTelegramLinkAfterHandoff();
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
      unawaited(
        bonusActions.reportTelegramLinkEvent(
          hostPlatform: widget.appContext.hostPlatform,
          eventName: opened ? 'handoff_opened' : 'handoff_open_failed',
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _telegramBonusBusy = false;
        _telegramBonusStatus = result.linked
            ? 'Telegram привязан'
            : 'Вернитесь и нажмите «Проверить»';
        _telegramLinkVerificationPending = !result.linked && opened;
        if (!opened) {
          _telegramBonusError = 'Не удалось открыть Telegram автоматически.';
        }
      });
      if (result.linked) {
        await _refreshSubscriptionInfo(showFailure: true);
      }
    } on Object {
      unawaited(_reportClientRuntimeError('telegram_link_failed'));
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

  Future<void> _verifyTelegramLinkAfterHandoff() async {
    if (_telegramBonusBusy || !_telegramLinkVerificationPending) {
      return;
    }
    final bonusActions = _bonusActionService;
    if (bonusActions == null) {
      return;
    }
    setState(() {
      _telegramBonusBusy = true;
      _telegramBonusError = null;
      _telegramBonusStatus = 'Проверяем Telegram…';
    });
    try {
      unawaited(
        bonusActions.reportTelegramLinkEvent(
          hostPlatform: widget.appContext.hostPlatform,
          eventName: 'verify_requested',
        ),
      );
      final updated = await _refreshSubscriptionInfo();
      if (!mounted) {
        return;
      }
      final linked = updated && (_subscriptionInfo?.telegramLinked ?? false);
      setState(() {
        _telegramBonusBusy = false;
        _telegramLinkVerificationPending = !linked;
        if (!linked) {
          _telegramBonusStatus = 'Проверить';
          _telegramBonusError = updated
              ? 'Telegram ещё не привязан. В боте нажмите «Старт», затем проверьте снова.'
              : 'Не удалось проверить привязку. Проверьте соединение.';
        }
      });
    } on Object {
      unawaited(_reportClientRuntimeError('telegram_verify_failed'));
      if (mounted) {
        setState(() {
          _telegramBonusBusy = false;
          _telegramBonusStatus = 'Проверить';
          _telegramBonusError = 'Не удалось проверить привязку Telegram.';
        });
      }
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
    } on Object {
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
        _connectionManager.markProfileDirty();
        _runtimeHeadline = 'Telegram-бонус активирован.';
      });
      unawaited(_loadBonusSummary(force: true));
      showPokrovSnack(
        context,
        'Доступ продлен на ${ruDays(result.premiumDays)}.',
        tone: PokrovSnackTone.success,
      );
    } catch (error) {
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
    } on Object {
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
        _connectionManager.markProfileDirty();
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
      return _PlatformProductCopy.telegramRewardAvailableBeforePayment;
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
    final completed = await _firstSessionCoordinator.loadPersistedCompletion();
    if (!mounted || !completed) {
      return;
    }
    setState(() {});
    widget.shellController?.refresh();
  }

  void _completeFirstLaunchAsNewUser() {
    PokrovHaptics.tap();
    if (!_firstSessionCoordinator.selectTrial()) {
      return;
    }
    unawaited(_firstSessionCoordinator.persistCompletion());
    setState(() {});
    widget.shellController?.refresh();
    unawaited(
      _reportEstablishedFirstSession(
        eventName: 'trial_start_selected',
        stage: 'trial',
        result: 'selected',
        includeHome: true,
        refreshAccount: true,
      ),
    );
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
  Future<void> _toggleRuntimeFromHome() async {
    if (_firstLaunchStep != _FirstLaunchStep.ready) {
      _completeFirstLaunchAsNewUser();
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
        runtimeSnapshot: _protectionRuntimeSnapshot,
        retainsProtection: () => _connectionManager.retainsProtection,
        confirmedLocationLabel: () =>
            _runtimeSnapshot?.isCleanlyHealthy == true && _activeNodeCode.isNotEmpty
                ? _locationLabelForNodeCode(
                    _activeNodeCode,
                    variantId: _activeVariantId,
                  )
                : '',
        onDisconnect: _connectionManager.disconnect,
        initialData: _ProtectionCenterData(
          snapshot: _runtimeSnapshot,
          liveStats: const RuntimeLiveStats.unavailable(),
          httpsProbe: const PokrovHttpsProbeResult.unknown(),
          history: _clientExperience.protectionEvents,
          shortcuts: _clientExperience.postConnectShortcuts,
          checkedAt: null,
        ),
        onRefresh: _collectProtectionCenterData,
        onRepair: _repairAndCollectProtectionCenterData,
        onAddShortcut: _addPostConnectShortcut,
        onRemoveShortcut: _removePostConnectShortcut,
        onOpenShortcut: _openPostConnectShortcut,
        onOpenSupport: () {
          Navigator.of(context).pop();
          unawaited(_showSupportHub());
        },
      ),
    );
  }

  PokrovDiagnosticsReport _buildDiagnosticsReport({
    RuntimeSnapshot? snapshot,
    List<DiagnosticCrashRecord>? nativeCrashes,
    DateTime? checkedAtUtc,
    ClientReleaseHealthBaseline releaseHealthBaseline =
        const ClientReleaseHealthBaseline.unavailable(),
  }) {
    final diagnostics = _extendedProtectionDiagnostics();
    final transferService = _supportBundleTransferService;
    return PokrovDiagnosticsPresenter.fromRuntime(
      hostPlatform: widget.appContext.hostPlatform,
      routeMode: _selectedRouteMode,
      snapshot: snapshot ?? _runtimeSnapshot,
      statusLabel: _connectionPresentation.title,
      warpState: _diagnosticWarpState(diagnostics),
      now: DateTime.now().toUtc(),
      appVersion: pokrovClientVersion,
      buildNumber: pokrovClientBuildNumber,
      releaseChannel: appFlavor ?? pokrovClientReleaseChannel,
      candidateLabel: pokrovClientCandidateLabel,
      encryptedDeliveryAvailable:
          transferService?.supportBundleEncryptionConfigured ?? false,
      timelineBreadcrumbs:
          widget.observability?.connectionTimelineBreadcrumbs ?? const [],
      crashes: [
        ...?widget.observability?.crashDiagnostics,
        ...?nativeCrashes,
      ],
      crashDiagnosticsReady: nativeCrashes != null ||
          !pokrovWindowsCrashCollectionAllowed(
            hostPlatform: widget.appContext.hostPlatform,
            policy: _supportModeController.activePolicy,
            now: DateTime.now().toUtc(),
          ),
      checkedAtUtc: checkedAtUtc,
      releaseHealthBaseline: releaseHealthBaseline,
      supportModePolicy: _supportModeController.activePolicy,
      systemSummary: _supportModeController.activePolicy == null
          ? null
          : _diagnosticSystemSummary(),
    );
  }

  DiagnosticSystemSummary _diagnosticSystemSummary() {
    // Keep only the numeric OS version, never the platform's free-form build
    // string (Android may include a device/build fingerprint).
    final osVersion = RegExp(r'\b(?:Windows|Android)\s+(\d+(?:\.\d+){0,2})\b')
            .firstMatch(Platform.operatingSystemVersion)
            ?.group(1) ??
        'unknown';
    final architecture = switch (Abi.current()) {
      Abi.androidArm => 'arm',
      Abi.androidArm64 || Abi.windowsArm64 => 'arm64',
      Abi.androidIA32 || Abi.windowsIA32 => 'x86',
      Abi.androidX64 || Abi.windowsX64 => 'x64',
      _ => throw UnsupportedError('Unsupported diagnostic host ABI'),
    };
    return DiagnosticSystemSummary(
      osFamily: Platform.operatingSystem,
      osVersion: osVersion,
      architecture: architecture,
      locale: Localizations.localeOf(context).toLanguageTag(),
    );
  }

  SupportBundleTransferService? get _supportBundleTransferService {
    final service = _supportTicketService;
    return service is SupportBundleTransferService
        ? service as SupportBundleTransferService
        : null;
  }

  String _diagnosticWarpState(Map<String, Object?> diagnostics) {
    if (diagnostics['enhanced_protection_consent'] == true) {
      return diagnostics['enhanced_protection_state'] == 'fallback'
          ? 'fallback'
          : 'enabled';
    }
    return diagnostics['enhanced_protection_available'] == true
        ? 'disabled'
        : 'unavailable';
  }

  Future<PokrovDiagnosticsReport> _refreshDiagnosticsReport() async {
    final data = await _collectProtectionCenterData();
    final policy = _supportModeController.activePolicy;
    List<DiagnosticCrashRecord>? nativeCrashes;
    try {
      nativeCrashes = await collectPokrovWindowsCrashDiagnostics(
        hostPlatform: widget.appContext.hostPlatform,
        policy: policy,
        now: DateTime.now().toUtc(),
      );
    } on Object {
      // Preserve a usable safe summary; incomplete crash collection cannot be
      // delivered as a complete extended report.
    }
    if (!identical(policy, _supportModeController.activePolicy)) {
      nativeCrashes = null;
    }
    return _buildDiagnosticsReport(
      snapshot: data.snapshot,
      nativeCrashes: nativeCrashes,
      checkedAtUtc: data.checkedAt?.toUtc(),
    );
  }

  Future<ClientReleaseHealthBaseline> _fetchReleaseHealthBaseline() async {
    final service = _releaseHealthService;
    if (service == null) {
      return const ClientReleaseHealthBaseline.unavailable();
    }
    return service.fetchReleaseHealthBaseline(
      hostPlatform: widget.appContext.hostPlatform,
      build: pokrovCurrentBuildIdentity(widget.appContext.hostPlatform),
    );
  }

  void _openDiagnostics() {
    PokrovHaptics.tap();
    final transferService = _supportBundleTransferService;
    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (routeContext) {
            void closeThen(VoidCallback action) {
              Navigator.of(routeContext).pop();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  action();
                }
              });
            }

            return ListenableBuilder(
              listenable: _supportModeController,
              builder: (context, child) => PokrovDiagnosticsScreen(
                initialReport: _buildDiagnosticsReport(),
                onRefresh: _refreshDiagnosticsReport,
                onReleaseHealthRefresh: _releaseHealthService == null
                    ? null
                    : _fetchReleaseHealthBaseline,
                onOpenProtection: () => closeThen(_openProtectionCenter),
                onOpenSupport: () => closeThen(() {
                  unawaited(_showSupportHub());
                }),
                onCreateCaseWithBundle: transferService == null ||
                        !transferService.supportBundleEncryptionConfigured
                    ? null
                    : (prepared) => _deliverSupportBundleWithObservability(
                          transferService,
                          prepared,
                          ticketId: null,
                        ),
                onLoadPendingBundles: transferService == null ||
                        !transferService.supportBundleEncryptionConfigured
                    ? null
                    : transferService.listPendingSupportBundles,
                onRetryPendingBundle: transferService == null ||
                        !transferService.supportBundleEncryptionConfigured
                    ? null
                    : (diagnosticId) => transferService.retrySupportBundle(
                          hostPlatform: widget.appContext.hostPlatform,
                          diagnosticId: diagnosticId,
                        ),
                onExportBundle: transferService == null ||
                        !transferService.supportBundleEncryptionConfigured
                    ? null
                    : (prepared) => _exportSupportBundle(
                          transferService,
                          prepared,
                        ),
                initialSupportMode: _supportModeController.view,
                onActivateSupportMode: transferService == null ||
                        !transferService.supportBundleEncryptionConfigured
                    ? null
                    : () => _activateTemporarySupportMode(transferService),
                onDisableSupportMode: _supportModeController.disable,
              ),
            );
          },
        ),
      ),
    );
  }

  Future<PokrovSupportModeView> _activateTemporarySupportMode(
    SupportBundleTransferService service,
  ) async {
    final codeController = TextEditingController();
    final activationCode = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Код режима поддержки'),
        content: TextField(
          key: const ValueKey('support-mode-code-field'),
          controller: codeController,
          autofocus: true,
          autocorrect: false,
          textCapitalization: TextCapitalization.characters,
          maxLength: 14,
          decoration: const InputDecoration(
            hintText: 'PSM1-XXXX-XXXX',
            helperText: 'Одноразовый код из обращения в поддержку',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Отмена'),
          ),
          FilledButton(
            key: const ValueKey('support-mode-code-continue'),
            onPressed: () {
              final value = codeController.text.trim();
              if (value.isNotEmpty) {
                Navigator.of(dialogContext).pop(value);
              }
            },
            child: const Text('Проверить'),
          ),
        ],
      ),
    );
    codeController.dispose();
    if (activationCode == null) {
      return _supportModeController.view;
    }
    final activation = await service.redeemSupportMode(
      hostPlatform: widget.appContext.hostPlatform,
      activationCode: activationCode,
      appVersion: pokrovClientVersion,
      buildNumber: pokrovClientBuildNumber,
    );
    if (!mounted) {
      return _supportModeController.view;
    }
    final policy = activation.policy;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Разрешить временную диагностику?',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(
                'До ${policy.expiresAt.toLocal().toString().substring(11, 16)} · не больше ${policy.maximumBundles} пакетов · общий лимит ${policy.maximumTotalBytes} байт.',
              ),
              const SizedBox(height: 8),
              Text(
                'Категории: ${policy.allowedCategories.map((value) => value.name).join(', ')}.',
              ),
              const SizedBox(height: 8),
              const Text(
                'Режим не запускает команды, не меняет VPN, маршруты или DNS, не читает пользовательские файлы и не скрывает индикатор. Каждый пакет всё равно проходит предпросмотр, очистку и шифрование.',
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(sheetContext).pop(false),
                    child: const Text('Не включать'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    key: const ValueKey('support-mode-confirm'),
                    onPressed: () => Navigator.of(sheetContext).pop(true),
                    child: const Text('Включить'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true) {
      return _supportModeController.view;
    }
    await _supportModeController.activate(
      activation,
      userConfirmed: true,
    );
    return _supportModeController.view;
  }

  Future<SupportBundleDeliveryResult> _deliverSupportBundleWithObservability(
    SupportBundleTransferService service,
    PreparedSupportBundle prepared, {
    int? ticketId,
  }) async {
    final observability = widget.observability;
    if (prepared.preview.profile == SupportDiagnosticProfile.extended) {
      await _supportModeController.registerBundle(prepared);
    }
    observability?.recordSupportBundleStarted();
    try {
      final result = await service.deliverSupportBundle(
        hostPlatform: widget.appContext.hostPlatform,
        prepared: prepared,
        caseSummary:
            'Диагностика POKROV $pokrovClientVersion; ${widget.appContext.hostPlatform.name}; режим ${_selectedRouteMode.name}.',
        ticketId: ticketId,
      );
      observability?.recordSupportBundleFinished(prepared: prepared);
      return result;
    } on Object catch (error) {
      observability?.recordSupportBundleFinished(
        prepared: prepared,
        errorCode: _supportBundleOperationalErrorCode(error),
      );
      rethrow;
    }
  }

  Future<SupportBundleExportResult> _exportSupportBundle(
    SupportBundleTransferService service,
    PreparedSupportBundle prepared,
  ) async {
    if (prepared.preview.profile == SupportDiagnosticProfile.extended) {
      await _supportModeController.registerBundle(prepared);
    }
    return service.exportSupportBundle(
      hostPlatform: widget.appContext.hostPlatform,
      prepared: prepared,
    );
  }

  Future<_ProtectionCenterData> _collectProtectionCenterData({
    RuntimeSnapshot? snapshotOverride,
  }) async {
    RuntimeSnapshot? snapshot = snapshotOverride ?? _runtimeSnapshot;
    if (snapshotOverride == null) {
      try {
        snapshot = await _connectionManager.readSnapshot();
      } on Object {
        // Keep the last host snapshot. Each unknown row remains visibly unknown.
      }
    }

    RuntimeLiveStats liveStats = const RuntimeLiveStats.unavailable();
    if (snapshot?.phase == RuntimePhase.running) {
      widget.observability?.recordPerformanceSampleStarted();
      try {
        liveStats = await _connectionManager.readLiveStats();
        widget.observability?.recordPerformanceSampleFinished(
          stats: liveStats,
        );
      } on Object {
        widget.observability?.recordPerformanceSampleFinished();
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
      checkedAt: DateTime.now(),
    );
  }

  Future<_ProtectionCenterData> _repairAndCollectProtectionCenterData(
    ValueChanged<_ProtectionRepairStep> onStep,
    ValueChanged<Future<void> Function()?> onCancelAvailable,
  ) async {
    try {
      await _repairRuntime(onStep: onStep, onCancelAvailable: onCancelAvailable);
      return _collectProtectionCenterData();
    } on _ProtectionRepairBusy {
      rethrow;
    } on ConnectionOperationSuperseded {
      rethrow;
    } on Object {
      final data = await _collectProtectionCenterData(
        snapshotOverride: _runtimeSnapshot,
      );
      throw _ProtectionRepairFailed(data);
    }
  }

  void _openFirstLaunchRestore() {
    PokrovHaptics.tap();
    setState(() {
      _firstSessionCoordinator.selectExistingAccess();
    });
  }

  void _backToFirstLaunchChoice() {
    PokrovHaptics.tap();
    setState(() {
      _firstSessionCoordinator.backToChoice();
    });
  }

  Future<void> _redeemFirstLaunchRestoreCode() async {
    if (!_firstSessionCoordinator.beginRestore()) {
      return;
    }
    setState(() {});
    final ok = await _redeemCodeInApp(_firstLaunchRestoreCodeController.text);
    if (!mounted) {
      return;
    }
    setState(() {
      _firstSessionCoordinator.finishRestore(succeeded: ok);
      if (ok) {
        unawaited(_firstSessionCoordinator.persistCompletion());
      }
    });
    if (ok) {
      unawaited(
        _reportEstablishedFirstSession(
          eventName: 'existing_access_selected',
          stage: 'restore',
          result: 'selected',
          includeHome: true,
          refreshAccount: true,
        ),
      );
    }
  }

  Future<void> _reportEstablishedFirstSession({
    String? eventName,
    String stage = 'app_open',
    String result = 'seen',
    String errorCode = '',
    bool? retryable,
    required bool includeHome,
    bool refreshAccount = false,
  }) async {
    await _reportClientOpenOnce();
    if (_firstSessionCoordinator.markAuthenticatedAppOpenSeen()) {
      await _reportFirstSessionEvent(
        'app_first_open',
        stage: 'app_open',
        result: 'shown',
      );
    }
    if (eventName != null) {
      await _reportFirstSessionEvent(
        eventName,
        stage: stage,
        result: result,
        errorCode: errorCode,
        retryable: retryable,
      );
    }
    if (includeHome && _firstSessionCoordinator.markFirstHomeSeen()) {
      await _reportFirstSessionEvent(
        'first_home_seen',
        stage: 'home',
        result: 'seen',
      );
    }
    if (refreshAccount) {
      await _refreshAccountSummary();
    }
  }

  Future<void> _reportClientOpenOnce() async {
    if (_clientLifecycleOpenReported) {
      return;
    }
    _clientLifecycleOpenReported = true;
    await _reportClientLifecycle('app_opened');
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
            statusLabel: _connectionPresentation.title,
            runtimeSnapshot: _runtimeSnapshot,
            extraDiagnostics: _extendedProtectionDiagnostics(),
            supportTicketService: _supportTicketService,
            observability: widget.observability,
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
        'connection_status': _connectionPresentation.title,
        'connection_active': _connectionPresentation.showsTunnelActive,
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

  Future<void> _editCatalogServices() async {
    if (!_selectiveServicesAvailable || _runtimeBusy) return;
    await showModalBottomSheet<void>(context: context, isScrollControlled: true,
      showDragHandle: true, builder: (_) => _CatalogServiceSelectionSheet(
        runtimeChanges: _protectionRuntimeSnapshot,
        initialSelection: _clientExperience.routingPreferences.selectedCatalogServiceIds,
        load: _loadCatalogServiceSelection,
        onSave: (data, selection) {
          if (!mounted || _runtimeBusy || !_selectiveServicesAvailable ||
              data.profileRevision != _managedProfileRevision ||
              data.accessState != _freeProfileAccess?.accessState) return false;
          PokrovHaptics.tap();
          _connectionManager.selectCatalogServices(selection);
          return true;
        },
      ));
  }

  Future<void> _openWarpControl() async {
    if (_warpPolicyBusy) {
      return;
    }

    final policy = await _connectionManager.loadWarpPolicy();
    if (policy == null) return;

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

  Future<bool> _authorizeAndroidVpnConnect() async {
    if (widget.appContext.hostPlatform != HostPlatform.android ||
        (_connectHintDismissed &&
            !_firstSessionCoordinator.vpnPermissionDenied)) {
      return true;
    }
    final recovery = _firstSessionCoordinator.vpnPermissionDenied;
    if (!_firstSessionCoordinator.beginVpnPermissionExplanation()) {
      return false;
    }
    setState(() {});
    unawaited(
      _reportFirstSessionEvent(
        'vpn_permission_explainer_shown',
        stage: 'vpn_permission',
        result: 'shown',
      ),
    );
    final approved = await _showVpnPermissionExplainer(
      context,
      recovery: recovery,
    );
    if (!mounted) {
      return false;
    }
    if (!approved) {
      setState(() {
        _firstSessionCoordinator.dismissVpnPermissionExplanation();
      });
      unawaited(
        _reportFirstSessionEvent(
          'vpn_permission_result',
          stage: 'vpn_permission',
          result: 'dismissed',
          retryable: true,
        ),
      );
      return false;
    }
    setState(() {
      _firstSessionCoordinator.beginVpnPermissionRequest();
    });
    return true;
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
      if (!_connectionPresentation.isVerified) {
        return 'Локация проверяется';
      }
      if (_connectionManager.materialCandidate?.warpMode ==
          'warp_over_proxy') {
        return 'WARP · страна выхода неизвестна';
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
            ? '$cityLabel · ${_safeLocationLabel(variantMatches.single.label, fallback: 'Белые списки')}'
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
    final connectionPresentation = _connectionPresentation;
    final observability = widget.observability;
    if (observability != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          observability.observeConnection(_connectionExperience);
        }
      });
    }
    final protectionState = ProtectionViewState(
      connection: connectionPresentation,
      routeMode: _selectedRouteMode,
      routeChangesPending: _runtimeSnapshot?.phase == RuntimePhase.running && _managedProfileDirty,
      locationLabel: _homeLocationLabel,
      connectHintVisible: !_connectHintDismissed,
      slowConnectionVisible: _connectionManager._connectionCoordinator.slowStageVisible,
      vpnPermissionRecoveryVisible:
          _firstSessionCoordinator.vpnPermissionDenied,
      runtimeNotice: _runtimeHeadline,
    );
    final protectionIntents = ProtectionIntents(
      toggleConnection: _toggleRuntimeFromHome,
      openConnectionDetails: _openProtectionCenter,
      openLocations: () => _selectTab(SeedTab.locations),
      openRules: () => _selectTab(SeedTab.rules),
    );
    final sectionBuilders = <WidgetBuilder>[
      (context) => _QuickConnectSection(
            advanced: _clientExperience.interfaceMode == PokrovInterfaceMode.advanced,
            appContext: widget.appContext,
            freeProfileAccess: _freeProfileAccess,
            protectionState: protectionState,
            protectionIntents: protectionIntents,
            revealHold: _firstLaunchStep != _FirstLaunchStep.ready,
            bonusSummary: _bonusSummary,
            subscriptionInfo: _subscriptionInfo,
            telegramBonusBusy: _telegramBonusBusy,
            warpPolicy: _managedWarpPolicy,
            warpRuntimeConsent: _warpRuntimeConsent,
            warpRuntimeActive: _warpRuntimeIsActive,
            warpBusy: _warpPolicyBusy,
            onTelegramBonus: _telegramBonusBusy
                ? null
                : () {
                    if (_telegramBonusCanClaim) {
                      unawaited(_claimTelegramBonusInApp());
                    } else {
                      unawaited(_createTelegramLinkInApp());
                    }
                  },
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
            interfaceMode: _clientExperience.interfaceMode,
            preferredCountryCode: _clientExperience.preferredCountryCode,
            preferredCandidateRef: _clientExperience.preferredCandidateRef,
            transportCatalog: _connectionManager.transportCatalog,
            onPreferredCountrySelected: _connectionManager.setPreferredCountry,
            onPreferredCandidateSelected: _connectionManager.setPreferredCandidate,
            selectedRouteMode: _selectedRouteMode,
            hasProvisionedAccess: hasProvisionedAccess,
            smartConnectProfile: _smartConnectProfile,
            hasOrdinaryTransportCatalog:
                _connectionManager.transportCatalog != null,
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
            loadVerifiedCatalogApps: _routingCatalogEnabled && widget.appContext.hostPlatform == HostPlatform.android
                ? _loadVerifiedCatalogDirectApps : null,
            loadCatalogPreview: _routingCatalogEnabled ? _loadRoutingCatalogPreview : null,
            catalogPreviewIdentity: (
              _selectedRouteMode, _managedProfileRevision, _freeProfileAccess?.accessState,
              _runtimeSnapshot?.routingCatalogWindowVersion, identityHashCode(_bootstrapper),
              _clientExperience.routingPreferences.externalSmartDnsEnabled,
            ),
            onEditCatalogServices: _selectiveServicesAvailable ? _editCatalogServices : null,
            catalogServicesBusy: _runtimeBusy,
            smartDnsActive: _selectedRouteMode == RouteMode.selectiveServices &&
                !_managedProfileDirty && _runtimeSnapshot?.phase == RuntimePhase.running &&
                (_connectionManager._connectionCoordinator.activeSmartAccessLeases?.leases.isNotEmpty ?? false),
            onRoutingPreferencesChanged: _setRoutingPreferences,
            onRoutingPreferencesApply: _applyRoutingPreferences,
            connectionActive: _runtimeSnapshot?.phase == RuntimePhase.running,
            windowsLocalDpiReady: _runtimeSnapshot?.windowsLocalDpiAdmissionVersion == 1,
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
            onOpenDiagnostics: _openDiagnostics,
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
            connectionPresentation: connectionPresentation,
            runtimeHeadline: _runtimeHeadline,
            onOpenWarp: _openWarpControl,
            themeMode: widget.themeMode,
            onThemeModeChanged: widget.onThemeModeChanged,
            interfaceMode: _clientExperience.interfaceMode,
            onInterfaceModeChanged: _connectionManager.setInterfaceMode,
            subscriptionInfo: _subscriptionInfo,
            systemSurfacePreferences: _systemSurfacePreferences,
            onSystemSurfacePreferencesChanged: _updateSystemSurfacePreferences,
            windowsShellPreferences: _windowsShellPreferences,
            onWindowsShellPreferencesChanged: _updateWindowsShellPreferences,
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
            onDismissNotifications: _dismissNotifications,
            onFetchDevices: _fetchClientDevices,
            onRevokeDevice: _revokeClientDevice,
            onIssuePairingCode: _issueDevicePairingCode,
            onCancelPairingCode: _cancelDevicePairingCode,
          ),
    ];

    final isDesktopShell = switch (widget.appContext.hostPlatform) {
      HostPlatform.windows || HostPlatform.linux || HostPlatform.macos => true,
      HostPlatform.android || HostPlatform.ios => false,
    };

    final disableAnimations = MediaQuery.maybeOf(context)?.disableAnimations ??
        WidgetsBinding.instance.platformDispatcher.accessibilityFeatures
            .disableAnimations;
    final shell = isDesktopShell
        ? _DesktopShell(
            advanced: _clientExperience.interfaceMode == PokrovInterfaceMode.advanced,
            selectedIndex: _selectedIndex,
            sectionBuilders: sectionBuilders,
            onSelected: (index) {
              _selectTab(SeedTab.values[index]);
            },
          )
        : _MobileShell(
            advanced: _clientExperience.interfaceMode == PokrovInterfaceMode.advanced,
            selectedIndex: _selectedIndex,
            sectionBuilders: sectionBuilders,
            onSelected: (index) {
              _selectTab(SeedTab.values[index]);
            },
          );
    final supportModeView = _supportModeController.view;
    final shellWithSupportMode = supportModeView.active
        ? Column(
            children: [
              PokrovPersistentSupportModeBanner(
                view: supportModeView,
                onOpenDiagnostics: _openDiagnostics,
                onDisable: () => unawaited(_supportModeController.disable()),
              ),
              Expanded(child: shell),
            ],
          )
        : shell;

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
                        Positioned.fill(child: shellWithSupportMode),
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
                                    acquisitionState: _firstSessionCoordinator
                                        .acquisitionState,
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

/// Advanced mode asks about device scope before the first live connection.
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
