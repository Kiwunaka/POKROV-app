part of pokrov_app_shell;

typedef _EmergencyPreferencesChanged = void Function({
  required bool manualLimitedNetwork,
  required String disclosureRevision,
  required String reserveId,
  required EmergencyChainMode chainMode,
  required bool automaticRoute,
});

typedef _EmergencyConnect = Future<void> Function({
  required EmergencyCatalog catalog,
  required EmergencyReserve reserve,
  required EmergencyChainMode chainMode,
  required bool automaticRoute,
  required bool manualLimitedNetwork,
  required _EmergencyConnectProgress onProgress,
});

typedef _EmergencyConnectProgress = void Function({
  required String reserveId,
  required int current,
  required int total,
  required bool? working,
});

class _EmergencyNetworkLauncherCard extends StatelessWidget {
  const _EmergencyNetworkLauncherCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = PokrovPalette.of(context);
    return Semantics(
      button: true,
      label: 'Восстановить связь через резервный режим',
      child: Material(
        color: p.reward.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: PokrovRadii.cardLg,
          side: BorderSide(color: p.reward.withValues(alpha: 0.24)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const ValueKey('emergency-network-launcher'),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: p.reward.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.emergency_share_rounded, color: p.reward),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Восстановить связь',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: p.ink,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Резервный режим, если открываются только отдельные сайты',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: p.muted,
                            ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: p.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmergencyNetworkSurface extends StatefulWidget {
  const _EmergencyNetworkSurface({
    required this.appContext,
    required this.service,
    required this.initialManualLimitedNetwork,
    required this.acceptedDisclosureRevision,
    required this.initialReserveId,
    required this.initialChainMode,
    required this.initialAutomaticRoute,
    required this.onPreferencesChanged,
    required this.onConnect,
  });

  final SeedAppContext appContext;
  final AppFirstEmergencyNetworkService service;
  final bool initialManualLimitedNetwork;
  final String acceptedDisclosureRevision;
  final String initialReserveId;
  final EmergencyChainMode initialChainMode;
  final bool initialAutomaticRoute;
  final _EmergencyPreferencesChanged onPreferencesChanged;
  final _EmergencyConnect onConnect;

  @override
  State<_EmergencyNetworkSurface> createState() =>
      _EmergencyNetworkSurfaceState();
}

class _EmergencyNetworkSurfaceState extends State<_EmergencyNetworkSurface> {
  late bool _manualLimitedNetwork;
  late String _acceptedDisclosureRevision;
  late String _selectedReserveId;
  late EmergencyChainMode _selectedMode;
  late bool _automaticRoute;
  AppFirstEmergencyCatalogResult? _result;
  bool _busy = true;
  bool _connecting = false;
  int _connectProgressCurrent = 0;
  int _connectProgressTotal = 0;
  String _checkingReserveId = '';
  final Set<String> _deviceFailedReserveIds = <String>{};
  String _error = '';
  String _connectError = '';

  String _safeRefreshFailure(BootstrapFailure error) {
    return switch (error.statusCode) {
      401 =>
        'Сессия истекла. Восстановите доступ в Профиле и повторите проверку.',
      403 =>
        'Резерв доступен с пробным или платным доступом. Если сеть РФ не определилась, включите «Ограниченная сеть».',
      404 => 'Экстренная сеть ещё не включена на сервере.',
      409 =>
        'Сервер пока не подготовил полный набор резервов. Попробуйте позже.',
      _ =>
        'Автономная копия ещё не подготовлена. Один раз откройте POKROV при обычном интернете — после этого экстренная сеть сможет запуститься без наших серверов.',
    };
  }

  String _safeConnectFailure(BootstrapFailure error) {
    if (error.code == 'emergency_reserves_unreachable') {
      return 'Ни один сохранённый резерв не доступен в этой сети. Попробуйте другую сеть или обновите список позже.';
    }
    return switch (error.statusCode) {
      401 ||
      403 =>
        'Экстренный маршрут недоступен для этого аккаунта или сети.',
      409 => 'Список резервов изменился. Обновите его и повторите.',
      _ => 'Не удалось подключить экстренный маршрут.',
    };
  }

  @override
  void initState() {
    super.initState();
    _manualLimitedNetwork = true;
    _acceptedDisclosureRevision = widget.acceptedDisclosureRevision;
    _selectedReserveId = widget.initialReserveId;
    _selectedMode = widget.initialChainMode;
    _automaticRoute = widget.initialAutomaticRoute;
    unawaited(_refresh());
  }

  Future<void> _refresh({bool forceRefresh = false}) async {
    if (_busy && _result != null) {
      return;
    }
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final result = await widget.service.fetchEmergencyCatalog(
        hostPlatform: widget.appContext.hostPlatform,
        manualLimitedNetwork: _manualLimitedNetwork,
        forceRefresh: forceRefresh,
      );
      final catalog = result.catalog;
      if (!mounted) {
        return;
      }
      setState(() {
        _result = result;
        if (catalog != null) {
          _selectRoute(catalog);
        }
      });
      _persistPreferences();
      if (forceRefresh) {
        showPokrovSnack(
          context,
          'Каналы проверены и обновлены.',
          tone: PokrovSnackTone.success,
        );
      }
    } on BootstrapFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = _safeRefreshFailure(error);
      });
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Не удалось проверить экстренную сеть. Попробуйте ещё раз.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  void _selectAutomaticRoute(EmergencyCatalog catalog) {
    const preference = <EmergencyChainMode>[
      EmergencyChainMode.reserveForeign,
      EmergencyChainMode.reserveDirect,
      EmergencyChainMode.reserveRuForeign,
    ];
    for (final mode in preference) {
      for (final reserve in catalog.items) {
        if (reserve.available && reserve.modes.contains(mode)) {
          _selectedReserveId = reserve.id;
          _selectedMode = mode;
          return;
        }
      }
    }
    for (final reserve in catalog.items) {
      if (reserve.modes.isNotEmpty) {
        _selectedReserveId = reserve.id;
        _selectedMode = reserve.modes.first;
        return;
      }
    }
    _selectedReserveId = '';
  }

  void _selectRoute(EmergencyCatalog catalog) {
    if (_automaticRoute) {
      _selectAutomaticRoute(catalog);
      return;
    }
    final selectedMatches = catalog.items.where(
      (item) =>
          item.available &&
          item.id == _selectedReserveId &&
          item.modes.contains(_selectedMode),
    );
    if (selectedMatches.isNotEmpty) {
      return;
    }
    final compatible = catalog.items.where(
      (item) => item.available && item.modes.contains(_selectedMode),
    );
    _selectedReserveId = compatible.isEmpty ? '' : compatible.first.id;
  }

  void _setAutomaticRoute(EmergencyCatalog catalog) {
    setState(() {
      _automaticRoute = true;
      _selectAutomaticRoute(catalog);
    });
    _persistPreferences();
  }

  void _setChainMode(EmergencyCatalog catalog, EmergencyChainMode mode) {
    final compatible = catalog.items.where(
      (item) => item.available && item.modes.contains(mode),
    );
    if (compatible.isEmpty) {
      return;
    }
    setState(() {
      _automaticRoute = false;
      _selectedMode = mode;
      _selectedReserveId = compatible.first.id;
    });
    _persistPreferences();
  }

  void _persistPreferences() {
    widget.onPreferencesChanged(
      manualLimitedNetwork: _manualLimitedNetwork,
      disclosureRevision: _acceptedDisclosureRevision,
      reserveId: _selectedReserveId,
      chainMode: _selectedMode,
      automaticRoute: _automaticRoute,
    );
  }

  Future<bool?> _showModeExplanation({required bool confirmation}) =>
      showModalBottomSheet<bool>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Как работает режим белых списков',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                const Text(
                  'POKROV автоматически перебирает заранее проверенные каналы, доступные при ограничениях мобильной сети. Сначала приложение старается сохранить выход через инфраструктуру POKROV.',
                ),
                const SizedBox(height: 10),
                const Text(
                  'Если основной вариант не проходит, приложение пробует совместимый резерв. Обычные DNS-настройки, WARP и правила отдельных приложений здесь временно не используются.',
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: confirmation
                        ? const ValueKey('emergency-disclosure-accept')
                        : const ValueKey('emergency-explanation-close'),
                    onPressed: () => Navigator.of(context).pop(confirmation),
                    child: Text(
                      confirmation ? 'Понятно, продолжить' : 'Закрыть',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Future<bool> _confirmDisclosure(EmergencyCatalog catalog) async {
    if (_acceptedDisclosureRevision == catalog.disclosureRevision) {
      return true;
    }
    final accepted = await _showModeExplanation(confirmation: true);
    if (accepted == true) {
      _acceptedDisclosureRevision = catalog.disclosureRevision;
      _persistPreferences();
      return true;
    }
    return false;
  }

  Future<void> _connect() async {
    final catalog = _result?.catalog;
    if (catalog == null || _connecting) {
      return;
    }
    final reserve = catalog.items.firstWhere(
      (item) => item.id == _selectedReserveId,
      orElse: () => catalog.items.first,
    );
    if (!reserve.available || !reserve.modes.contains(_selectedMode)) {
      showPokrovSnack(
        context,
        'Выбранный резерв сейчас недоступен. Обновите список.',
        tone: PokrovSnackTone.danger,
      );
      return;
    }
    if (!await _confirmDisclosure(catalog) || !mounted) {
      return;
    }
    setState(() {
      _connecting = true;
      _connectProgressCurrent = 0;
      _connectProgressTotal = 0;
      _checkingReserveId = '';
      _deviceFailedReserveIds.clear();
      _connectError = '';
    });
    try {
      await widget.onConnect(
        catalog: catalog,
        reserve: reserve,
        chainMode: _selectedMode,
        automaticRoute: _automaticRoute,
        manualLimitedNetwork: _manualLimitedNetwork,
        onProgress: ({
          required reserveId,
          required current,
          required total,
          required working,
        }) {
          if (!mounted) {
            return;
          }
          setState(() {
            _connectProgressCurrent = current;
            _connectProgressTotal = total;
            if (working == null) {
              _checkingReserveId = reserveId;
            } else {
              _checkingReserveId = '';
              if (working) {
                _deviceFailedReserveIds.remove(reserveId);
              } else {
                _deviceFailedReserveIds.add(reserveId);
              }
            }
          });
        },
      );
      if (!mounted) {
        return;
      }
      showPokrovSnack(
        context,
        'Режим белых списков подключён.',
        tone: PokrovSnackTone.success,
      );
      Navigator.of(context).pop();
    } on BootstrapFailure catch (error) {
      if (mounted) {
        setState(() {
          _connectError = _safeConnectFailure(error);
        });
      }
    } on Object {
      if (mounted) {
        setState(() {
          _connectError = 'Не удалось подключить экстренный маршрут.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _connecting = false;
        });
      }
    }
  }

  String _unavailableMessage(AppFirstEmergencyCatalogResult result) =>
      switch (result.eligibilitySource) {
        'access_denied' =>
          'Режим белых списков доступен во время пробного периода и с активной подпиской.',
        'country_unknown' ||
        'install_unknown' =>
          'Мы не смогли подтвердить сеть РФ. Если обычный интернет ограничен, включите режим ниже.',
        _ when result.reason == 'insufficient_working_reserves' =>
          'Сейчас недостаточно проверенных резервов. Мы не предлагаем сомнительный маршрут.',
        _ => 'Режим белых списков временно недоступен.',
      };

  @override
  Widget build(BuildContext context) {
    final p = PokrovPalette.of(context);
    final catalog = _result?.catalog;
    final selectedMatches = catalog?.items
            .where((item) => item.id == _selectedReserveId)
            .toList(growable: false) ??
        const <EmergencyReserve>[];
    final selected = selectedMatches.isEmpty ? null : selectedMatches.first;
    final availableCount =
        catalog?.items.where((item) => item.available).length ?? 0;
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Режим белых списков'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            Material(
              color: p.surface,
              shape: RoundedRectangleBorder(
                borderRadius: PokrovRadii.cardLg,
                side: BorderSide(color: p.line),
              ),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                key: const ValueKey('emergency-how-it-works'),
                leading: Icon(Icons.info_outline_rounded, color: p.accent),
                title: const Text('Когда нужен этот режим'),
                subtitle: const Text('Если открываются только отдельные сайты'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => unawaited(
                  _showModeExplanation(confirmation: false),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_busy && catalog == null)
              const _MotionSkeletonList(
                key: ValueKey('emergency-loading'),
                rows: 2,
              )
            else if (_error.isNotEmpty && catalog == null)
              _SectionCard(
                title: 'Не удалось обновить',
                tone: _SectionTone.muted,
                lines: [_error],
                child: OutlinedButton.icon(
                  onPressed: () => unawaited(_refresh(forceRefresh: true)),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Повторить'),
                ),
              )
            else if (catalog == null && _result != null)
              _SectionCard(
                title: 'Пока недоступно',
                tone: _SectionTone.muted,
                lines: [_unavailableMessage(_result!)],
              )
            else if (catalog != null) ...[
              if (_connectError.isNotEmpty) ...[
                _SectionCard(
                  title: 'Не удалось подключиться',
                  tone: _SectionTone.muted,
                  lines: [_connectError],
                ),
                const SizedBox(height: 10),
              ],
              if (_error.isNotEmpty) ...[
                _SectionCard(
                  title: 'Используем сохранённый список',
                  tone: _SectionTone.muted,
                  lines: const [
                    'Свежая проверка сейчас недоступна, но подписанные каналы сохранены на устройстве.',
                  ],
                ),
                const SizedBox(height: 10),
              ],
              _SectionCard(
                title: availableCount > 0
                    ? '${catalog.items.length} каналов сохранено'
                    : 'Проверенных каналов сейчас нет',
                tone: availableCount > 0
                    ? _SectionTone.accent
                    : _SectionTone.muted,
                lines: [
                  availableCount > 0
                      ? '$availableCount проверено POKROV. Приложение выберет рабочий именно в этой сети.'
                      : 'Проверьте список позже или попробуйте другую сеть.',
                  if (_result?.usingCache == true)
                    'Список сохранён на устройстве и доступен без связи с POKROV.',
                ],
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const ValueKey('emergency-connect'),
                    onPressed: _connecting || selected?.available != true
                        ? null
                        : _connect,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    icon: _connecting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.shield_rounded),
                    label: Text(
                      _connecting
                          ? _connectProgressCurrent > 0 &&
                                  _connectProgressTotal > 0
                              ? 'Канал $_connectProgressCurrent из $_connectProgressTotal…'
                              : 'Ищем рабочий канал…'
                          : 'Подключить белый режим',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Material(
                color: p.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: PokrovRadii.cardLg,
                  side: BorderSide(color: p.line),
                ),
                clipBehavior: Clip.antiAlias,
                child: ExpansionTile(
                  key: const ValueKey('emergency-route-mode'),
                  leading: Icon(Icons.alt_route_rounded, color: p.accent),
                  title: const Text('Маршрут подключения'),
                  subtitle: Text(
                    _automaticRoute
                        ? 'Автоматически · ${_emergencyChainModeTitle(_selectedMode)}'
                        : _emergencyChainModeTitle(_selectedMode),
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  children: [
                    _EmergencyRouteChoice(
                      key: const ValueKey('emergency-route-auto'),
                      title: 'Автоматически',
                      description:
                          'Сначала через POKROV, затем прямой резерв и усиленная цепочка.',
                      selected: _automaticRoute,
                      enabled: availableCount > 0,
                      onTap: () => _setAutomaticRoute(catalog),
                    ),
                    for (final mode in const <EmergencyChainMode>[
                      EmergencyChainMode.reserveForeign,
                      EmergencyChainMode.reserveDirect,
                      EmergencyChainMode.reserveRuForeign,
                    ])
                      _EmergencyRouteChoice(
                        key: ValueKey('emergency-route-${mode.wireValue}'),
                        title: _emergencyChainModeTitle(mode),
                        description: _emergencyChainModeDescription(mode),
                        selected: !_automaticRoute && _selectedMode == mode,
                        enabled: catalog.items.any(
                          (item) => item.available && item.modes.contains(mode),
                        ),
                        onTap: () => _setChainMode(catalog, mode),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Material(
                color: p.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: PokrovRadii.cardLg,
                  side: BorderSide(color: p.line),
                ),
                clipBehavior: Clip.antiAlias,
                child: ExpansionTile(
                  key: const ValueKey('emergency-diagnostics'),
                  title: const Text('Диагностика каналов'),
                  subtitle: Text(
                    'Проверено POKROV: $availableCount из ${catalog.items.length}',
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
                      child: Text(
                        'Статус и задержка — последняя проверка POKROV, а не замер с этого устройства.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: p.muted,
                            ),
                      ),
                    ),
                    ...catalog.items.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _EmergencyReserveRow(
                          reserve: item,
                          deviceChecking: _checkingReserveId == item.id,
                          deviceFailed:
                              _deviceFailedReserveIds.contains(item.id),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        key: const ValueKey('emergency-refresh'),
                        onPressed: _busy
                            ? null
                            : () => unawaited(
                                  _refresh(forceRefresh: true),
                                ),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Проверить каналы снова'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      backgroundColor: p.canvas,
    );
  }
}

class _EmergencyReserveRow extends StatelessWidget {
  const _EmergencyReserveRow({
    required this.reserve,
    required this.deviceChecking,
    required this.deviceFailed,
  });

  final EmergencyReserve reserve;
  final bool deviceChecking;
  final bool deviceFailed;

  @override
  Widget build(BuildContext context) {
    final p = PokrovPalette.of(context);
    final statusColor = deviceFailed
        ? p.danger
        : deviceChecking
            ? p.reward
            : switch (reserve.status) {
                EmergencyReserveStatus.working => p.success,
                EmergencyReserveStatus.checking => p.reward,
                EmergencyReserveStatus.unavailable => p.danger,
                EmergencyReserveStatus.stale => p.muted,
              };
    return Material(
      color: p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: PokrovRadii.card,
        side: BorderSide(color: p.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: p.surfaceMuted,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(Icons.route_rounded, color: p.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Канал ${reserve.ordinal}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          deviceFailed
                              ? 'Не сработал в этой сети'
                              : deviceChecking
                                  ? 'Проверяем на устройстве'
                                  : _emergencyStatusLabel(reserve.status),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: p.muted,
                                  ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _emergencyVerificationLabel(reserve.verification),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: p.muted,
                        ),
                  ),
                ],
              ),
            ),
            if (reserve.latencyMs != null)
              Text(
                '${reserve.latencyMs} мс',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            const SizedBox(width: 8),
            Icon(
              deviceFailed
                  ? Icons.cancel_rounded
                  : deviceChecking
                      ? Icons.sync_rounded
                      : reserve.available
                          ? Icons.check_circle_rounded
                          : Icons.cancel_outlined,
              color: deviceFailed
                  ? p.danger
                  : deviceChecking
                      ? p.reward
                      : reserve.available
                          ? p.success
                          : p.muted,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmergencyRouteChoice extends StatelessWidget {
  const _EmergencyRouteChoice({
    super.key,
    required this.title,
    required this.description,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String title;
  final String description;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = PokrovPalette.of(context);
    return ListTile(
      enabled: enabled,
      selected: selected,
      onTap: enabled ? onTap : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text(title),
      subtitle: Text(description),
      trailing: Icon(
        selected ? Icons.check_circle_rounded : Icons.circle_outlined,
        color: selected
            ? p.accent
            : enabled
                ? p.muted
                : p.line,
      ),
    );
  }
}

String _emergencyChainModeTitle(EmergencyChainMode mode) => switch (mode) {
      EmergencyChainMode.reserveForeign => 'Через POKROV',
      EmergencyChainMode.reserveDirect => 'Через белый канал',
      EmergencyChainMode.reserveRuForeign => 'Усиленная цепочка',
    };

String _emergencyChainModeDescription(EmergencyChainMode mode) =>
    switch (mode) {
      EmergencyChainMode.reserveForeign =>
        'Белый канал → зарубежный узел POKROV.',
      EmergencyChainMode.reserveDirect =>
        'Белый канал → интернет без дополнительного узла POKROV.',
      EmergencyChainMode.reserveRuForeign =>
        'Белый канал → узел POKROV в РФ → зарубежный узел POKROV.',
    };

String _emergencyStatusLabel(EmergencyReserveStatus status) => switch (status) {
      EmergencyReserveStatus.working => 'Готов к проверке в этой сети',
      EmergencyReserveStatus.checking => 'Проверяется POKROV',
      EmergencyReserveStatus.unavailable => 'Не прошёл проверку POKROV',
      EmergencyReserveStatus.stale => 'Нужна свежая проверка',
    };

String _emergencyVerificationLabel(EmergencyVerificationLevel level) =>
    switch (level) {
      EmergencyVerificationLevel.ordinary => 'Проверен POKROV',
      EmergencyVerificationLevel.syntheticBs =>
        'Проверен в тестовой ограниченной сети',
      EmergencyVerificationLevel.realBs =>
        'Проверен в реальной ограниченной сети',
    };
