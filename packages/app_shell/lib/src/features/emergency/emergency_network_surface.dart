part of pokrov_app_shell;

typedef _EmergencyPreferencesChanged = void Function({
  required bool manualLimitedNetwork,
  required String disclosureRevision,
  required String reserveId,
  required EmergencyChainMode chainMode,
});

typedef _EmergencyConnect = Future<void> Function({
  required EmergencyCatalog catalog,
  required EmergencyReserve reserve,
  required EmergencyChainMode chainMode,
  required bool manualLimitedNetwork,
});

class _EmergencyNetworkLauncherCard extends StatelessWidget {
  const _EmergencyNetworkLauncherCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = PokrovPalette.of(context);
    return Semantics(
      button: true,
      label: 'Открыть экстренную сеть POKROV',
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
                        'Экстренная сеть POKROV',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: p.ink,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Резерв при ограниченной сети',
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
    required this.onPreferencesChanged,
    required this.onConnect,
  });

  final SeedAppContext appContext;
  final AppFirstEmergencyNetworkService service;
  final bool initialManualLimitedNetwork;
  final String acceptedDisclosureRevision;
  final String initialReserveId;
  final EmergencyChainMode initialChainMode;
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
  AppFirstEmergencyCatalogResult? _result;
  bool _busy = true;
  bool _connecting = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _manualLimitedNetwork = widget.initialManualLimitedNetwork;
    _acceptedDisclosureRevision = widget.acceptedDisclosureRevision;
    _selectedReserveId = widget.initialReserveId;
    _selectedMode = widget.initialChainMode;
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
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
      );
      final catalog = result.catalog;
      if (!mounted) {
        return;
      }
      setState(() {
        _result = result;
        if (catalog != null) {
          final selectedMatches = catalog.items.where(
            (item) => item.id == _selectedReserveId && item.available,
          );
          if (selectedMatches.isEmpty) {
            _selectedReserveId = catalog.items
                .firstWhere(
                  (item) => item.available,
                  orElse: () => catalog.items.first,
                )
                .id;
          }
          final selected = catalog.items.firstWhere(
            (item) => item.id == _selectedReserveId,
          );
          if (!selected.modes.contains(_selectedMode)) {
            _selectedMode = selected.modes.first;
          }
        }
      });
      _persistPreferences();
    } on BootstrapFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.message;
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

  void _persistPreferences() {
    widget.onPreferencesChanged(
      manualLimitedNetwork: _manualLimitedNetwork,
      disclosureRevision: _acceptedDisclosureRevision,
      reserveId: _selectedReserveId,
      chainMode: _selectedMode,
    );
  }

  Future<bool> _confirmDisclosure(EmergencyCatalog catalog) async {
    if (_acceptedDisclosureRevision == catalog.disclosureRevision) {
      return true;
    }
    final accepted = await showModalBottomSheet<bool>(
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
                'Как работает экстренная сеть',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              const Text(
                'В режиме «Быстрый выход» первая точка берётся из согласованного резервного пула и не управляется POKROV. В режимах «Через POKROV» и «Усиленная цепочка» конечный выход остаётся на инфраструктуре POKROV.',
              ),
              const SizedBox(height: 10),
              const Text(
                'Резервы регулярно перепроверяются. WARP и маршруты по отдельным приложениям в экстренном режиме не используются.',
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const ValueKey('emergency-disclosure-accept'),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Понятно, продолжить'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
      _error = '';
    });
    try {
      await widget.onConnect(
        catalog: catalog,
        reserve: reserve,
        chainMode: _selectedMode,
        manualLimitedNetwork: _manualLimitedNetwork,
      );
      if (!mounted) {
        return;
      }
      showPokrovSnack(
        context,
        'Экстренная сеть подключена.',
        tone: PokrovSnackTone.success,
      );
      Navigator.of(context).pop();
    } on BootstrapFailure catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
        });
      }
    } on Object {
      if (mounted) {
        setState(() {
          _error = 'Не удалось подключить экстренный маршрут.';
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
          'Экстренная сеть доступна во время пробного периода и с активной подпиской.',
        'country_unknown' ||
        'install_unknown' =>
          'Мы не смогли подтвердить сеть РФ. Если обычный интернет ограничен, включите режим ниже.',
        _ when result.reason == 'insufficient_working_reserves' =>
          'Сейчас недостаточно проверенных резервов. Мы не предлагаем сомнительный маршрут.',
        _ => 'Экстренная сеть временно недоступна.',
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
    final modes = selected?.modes ?? const <EmergencyChainMode>[];
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Экстренная сеть'),
        actions: [
          IconButton(
            key: const ValueKey('emergency-refresh'),
            tooltip: 'Обновить резервы',
            onPressed: _busy ? null : _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            _SectionCard(
              title: 'Если обычное подключение недоступно',
              tone: _SectionTone.reward,
              lines: const [
                'POKROV проверит резервный вход и соберёт безопасную цепочку без WARP.',
              ],
              child: SwitchListTile.adaptive(
                key: const ValueKey('emergency-manual-limited-network'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Ограниченная сеть'),
                subtitle: const Text(
                    'Включите вручную, если сеть РФ не определилась'),
                value: _manualLimitedNetwork,
                onChanged: _busy
                    ? null
                    : (value) {
                        setState(() {
                          _manualLimitedNetwork = value;
                        });
                        _persistPreferences();
                        unawaited(_refresh());
                      },
              ),
            ),
            if (_busy && catalog == null)
              const _MotionSkeletonList(
                key: ValueKey('emergency-loading'),
                rows: 4,
              )
            else if (_error.isNotEmpty)
              _SectionCard(
                title: 'Не удалось обновить',
                tone: _SectionTone.muted,
                lines: [_error],
                child: OutlinedButton.icon(
                  onPressed: _refresh,
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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Проверенные резервы',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  if (_result?.usingCache == true)
                    const Chip(label: Text('Офлайн-копия')),
                ],
              ),
              const SizedBox(height: 10),
              ...catalog.items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _EmergencyReserveRow(
                    reserve: item,
                    selected: item.id == _selectedReserveId,
                    onTap: !item.available || _connecting
                        ? null
                        : () {
                            setState(() {
                              _selectedReserveId = item.id;
                              if (!item.modes.contains(_selectedMode)) {
                                _selectedMode = item.modes.first;
                              }
                            });
                            _persistPreferences();
                          },
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text('Маршрут', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              RadioGroup<EmergencyChainMode>(
                groupValue: _selectedMode,
                onChanged: (value) {
                  if (_connecting || value == null) {
                    return;
                  }
                  setState(() {
                    _selectedMode = value;
                  });
                  _persistPreferences();
                },
                child: Column(
                  children: modes
                      .map(
                        (mode) => RadioListTile<EmergencyChainMode>(
                          key: ValueKey(
                            'emergency-mode-${mode.wireValue}',
                          ),
                          value: mode,
                          enabled: !_connecting,
                          title: Text(mode.label),
                          subtitle: Text(_emergencyModeDescription(mode)),
                          contentPadding: EdgeInsets.zero,
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () => unawaited(_confirmDisclosure(catalog)),
                icon: const Icon(Icons.info_outline_rounded),
                label: const Text('Как это работает'),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: catalog == null
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
                label: Text(_connecting ? 'Подключаем…' : 'Подключить'),
              ),
            ),
      backgroundColor: p.canvas,
    );
  }
}

class _EmergencyReserveRow extends StatelessWidget {
  const _EmergencyReserveRow({
    required this.reserve,
    required this.selected,
    required this.onTap,
  });

  final EmergencyReserve reserve;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = PokrovPalette.of(context);
    final statusColor = switch (reserve.status) {
      EmergencyReserveStatus.working => p.success,
      EmergencyReserveStatus.checking => p.reward,
      EmergencyReserveStatus.unavailable => p.danger,
      EmergencyReserveStatus.stale => p.muted,
    };
    return Material(
      color: selected ? p.accent.withValues(alpha: 0.08) : p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: PokrovRadii.card,
        side: BorderSide(color: selected ? p.accent : p.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
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
                child: CountryFlag.fromCountryCode(
                  reserve.countryCode,
                  theme: const ImageTheme(
                    width: 30,
                    height: 22,
                    shape: RoundedRectangle(6),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Резерв ${reserve.ordinal}',
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
                            _emergencyStatusLabel(reserve.status),
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
                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: selected ? p.accent : p.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _emergencyStatusLabel(EmergencyReserveStatus status) => switch (status) {
      EmergencyReserveStatus.working => 'Работает',
      EmergencyReserveStatus.checking => 'Проверяется',
      EmergencyReserveStatus.unavailable => 'Недоступен',
      EmergencyReserveStatus.stale => 'Данные устарели',
    };

String _emergencyVerificationLabel(EmergencyVerificationLevel level) =>
    switch (level) {
      EmergencyVerificationLevel.ordinary => 'Обычная проверка',
      EmergencyVerificationLevel.syntheticBs => 'Проверено в лаборатории БС',
      EmergencyVerificationLevel.realBs => 'Проверено при реальном БС',
    };

String _emergencyModeDescription(EmergencyChainMode mode) => switch (mode) {
      EmergencyChainMode.reserveDirect =>
        'Резерв → интернет. Быстрее и короче.',
      EmergencyChainMode.reserveForeign =>
        'Резерв → иностранная нода POKROV. Выход через POKROV.',
      EmergencyChainMode.reserveRuForeign =>
        'Резерв → RU-хоп POKROV → иностранная нода. Надёжнее, но медленнее.',
    };
