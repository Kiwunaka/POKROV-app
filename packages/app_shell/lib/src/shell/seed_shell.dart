part of pokrov_app_shell;

class PokrovSeedApp extends StatelessWidget {
  const PokrovSeedApp({
    super.key,
    required this.appContext,
    this.bootstrapper,
    this.supportTicketService,
    this.handoffLauncher,
    this.firstLaunchStore,
    this.runtimeActionTimeout = const Duration(seconds: 18),
  });

  final SeedAppContext appContext;
  final ManagedProfileBootstrapper? bootstrapper;
  final SupportTicketService? supportTicketService;
  final ExternalHandoffLauncher? handoffLauncher;
  final PokrovFirstLaunchStore? firstLaunchStore;
  final Duration runtimeActionTimeout;

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
        fontFamily: 'SF Pro Display',
        fontFamilyFallback: const [
          'Segoe UI Variable Text',
          'Segoe UI',
          'SF Pro Text',
        ],
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
            minimumSize: const Size(0, 46),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: _SeedPalette.ink,
            side: BorderSide(color: _SeedPalette.ink.withValues(alpha: 0.16)),
            minimumSize: const Size(0, 46),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
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
        runtimeActionTimeout: runtimeActionTimeout,
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
    this.runtimeActionTimeout = const Duration(seconds: 18),
  });

  final SeedAppContext appContext;
  final ManagedProfileBootstrapper? bootstrapper;
  final SupportTicketService? supportTicketService;
  final ExternalHandoffLauncher? handoffLauncher;
  final PokrovFirstLaunchStore? firstLaunchStore;
  final Duration runtimeActionTimeout;

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
  String _preferredNodeCode = '';
  bool _nodePreferenceBusy = false;
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Локация сохранена. Переподключите POKROV.'),
        ),
      );
    } on BootstrapFailure catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
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
      unawaited(_checkForClientUpdate());
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(confirmationText),
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
      HapticFeedback.heavyImpact();
      final days = result.rewardDays;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            days > 0
                ? '$actionName: +$days дн. добавлены.'
                : '$actionName: отметка сохранена.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _bonusRewardBusy = false;
        _bonusSummaryError = 'Не удалось выполнить действие: $error';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось выполнить действие: $error')),
      );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
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
        title: 'Расширенная защита',
        lines: const [
          'Дополнительный режим пока недоступен для этого устройства.',
          'Когда он будет доступен, здесь появится отдельный переключатель.',
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
            ? 'Расширенная защита включится при следующем подключении.'
            : 'Расширенная защита выключена для следующих подключений.';
      });
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
          _warpPolicyBusy = false;
        });
      }
    }
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
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      final message = _runtimeUnexpectedErrorMessage(error);
      setState(() {
        _runtimeHeadline = message;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
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
        'системный модуль не ответил вовремя. Попробуйте еще раз или откройте поддержку.',
      PlatformException(:final message, :final code) =>
        (message?.trim().isNotEmpty == true ? message!.trim() : code),
      _ => error.toString().trim(),
    };
    final normalizedDetail = rawDetail.replaceFirst('Bad state: ', '').trim();
    final detail = normalizedDetail.length > 180
        ? '${normalizedDetail.substring(0, 180)}...'
        : normalizedDetail;
    if (detail.isEmpty) {
      return 'POKROV не смог начать подключение. Откройте поддержку и приложите диагностику.';
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
    final sections = <Widget>[
      _QuickConnectSection(
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
      ),
      _LocationsSection(
        appContext: widget.appContext,
        selectedRouteMode: _selectedRouteMode,
        hasProvisionedAccess: hasProvisionedAccess,
        smartConnectProfile: _smartConnectProfile,
        preferredNodeCode: _preferredNodeCode,
        nodePreferenceBusy: _nodePreferenceBusy,
        onPreferredNodeSelected: _setPreferredLocation,
      ),
      _RulesSection(
        appContext: widget.appContext,
        selectedRouteMode: _selectedRouteMode,
        selectedAppIds: _selectedAppIds,
        onRouteModeSelected: (mode) {
          _selectRouteMode(mode);
        },
        onSelectedAppAdded: _addSelectedAppId,
        onSelectedAppRemoved: _removeSelectedAppId,
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
        bonusRewardBusy: _bonusRewardBusy,
        onRefreshBonusSummary: () => _loadBonusSummary(force: true),
        onSpinWheel: _spinBonusWheelInApp,
        onCheckInCalendar: _checkInBonusCalendarInApp,
        warpPolicy: _managedWarpPolicy,
        warpRuntimeConsent: _warpRuntimeConsent,
        warpBusy: _warpPolicyBusy,
        runtimeSnapshot: _runtimeSnapshot,
        runtimeHeadline: _runtimeHeadline,
        onOpenWarp: _openWarpControl,
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
