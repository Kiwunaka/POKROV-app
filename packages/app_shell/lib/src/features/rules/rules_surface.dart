part of pokrov_app_shell;

class _RulesSection extends StatelessWidget {
  const _RulesSection({
    required this.appContext,
    required this.selectedRouteMode,
    required this.selectedAppIds,
    required this.routingPreferences,
    required this.onRouteModeSelected,
    required this.onSelectedAppAdded,
    required this.onSelectedAppRemoved,
    required this.onRuAppPresetApplied,
    required this.onRoutingPreferencesChanged,
    required this.onRoutingPreferencesApply,
    required this.connectionActive,
    required this.onReadCurrentWifi,
    required this.onRequestWifiPermission,
    required this.onOpenVpnSettings,
    required this.onRoutingLessonCompleted,
  });

  final SeedAppContext appContext;
  final RouteMode selectedRouteMode;
  final List<String> selectedAppIds;
  final PokrovRoutingPreferences routingPreferences;
  final ValueChanged<RouteMode> onRouteModeSelected;
  final ValueChanged<String> onSelectedAppAdded;
  final ValueChanged<String> onSelectedAppRemoved;
  final void Function(RouteMode mode, List<String> appIds) onRuAppPresetApplied;
  final ValueChanged<PokrovRoutingPreferences> onRoutingPreferencesChanged;
  final ValueChanged<PokrovRoutingPreferences> onRoutingPreferencesApply;
  final bool connectionActive;
  final PokrovWifiProbe onReadCurrentWifi;
  final PokrovWifiPermissionRequester onRequestWifiPermission;
  final PokrovVpnSettingsLauncher onOpenVpnSettings;
  final VoidCallback onRoutingLessonCompleted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = PokrovPalette.of(context);
    final routeChoices = appContext.runtimeProfile.supportedRouteModes;
    final selectedAppsActive = routeChoices.contains(RouteMode.selectedApps);
    final excludedAppsActive = routeChoices.contains(RouteMode.excludedApps);
    final selectedAppsStaged =
        appContext.bootstrapContract.supportsSelectedAppsMode &&
            !selectedAppsActive;
    final rulesContract = appContext.rulesPresetContract;
    final isWindows = appContext.hostPlatform == HostPlatform.windows;
    final directPresetIds = isWindows
        ? const <String>{
            'ru-region',
            'local-network',
          }
        : const <String>{
            'ru-region',
            'local-network',
            'ru-banks',
            'gosuslugi',
            'marketplaces',
          };
    final directPresets = rulesContract.presets
        .where(
          (preset) => directPresetIds.contains(preset.id),
        )
        .toList(growable: false);

    return _SeedContentList(
      children: [
        Text('Правила подключения', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Режим работы',
          tone: _SectionTone.accent,
          lines: ['Сейчас: ${_routeModeShortLabel(selectedRouteMode)}'],
          child: Column(
            children: <Widget>[
              _RouteModeSegmentedControl(
                choices: routeChoices,
                selectedRouteMode: selectedRouteMode,
                onRouteModeSelected: onRouteModeSelected,
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _routeModeRowSummary(selectedRouteMode),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: p.muted,
                    height: 1.32,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _SettingsRow(
                key: const ValueKey('rules-mode-help-action'),
                icon: Icons.info_outline_rounded,
                title: 'Как выбрать',
                value: 'Коротко',
                onTap: () => _showInfoSheet(
                  context,
                  title: 'Режим работы',
                  lines: [
                    '${_routeModeShortLabel(RouteMode.allExceptRu)}: ${_routeModeRowSummary(RouteMode.allExceptRu)}',
                    '${_routeModeShortLabel(RouteMode.fullTunnel)}: ${_routeModeRowSummary(RouteMode.fullTunnel)}',
                    selectedAppsActive
                        ? '${_routeModeShortLabel(RouteMode.selectedApps)}: ${_routeModeRowSummary(RouteMode.selectedApps)}'
                        : selectedAppsStaged
                            ? '${_routeModeShortLabel(RouteMode.selectedApps)}: недоступно на этом устройстве.'
                            : '${_routeModeShortLabel(RouteMode.selectedApps)}: недоступно на ${appContext.hostPlatform.label}.',
                    if (excludedAppsActive)
                      '${_routeModeShortLabel(RouteMode.excludedApps)}: ${_routeModeRowSummary(RouteMode.excludedApps)}',
                  ],
                ),
              ),
            ],
          ),
        ),
        if (selectedRouteMode == RouteMode.allExceptRu &&
            directPresets.isNotEmpty)
          _SectionCard(
            title: 'Напрямую без POKROV',
            lines: const [
              'Российские и локальные сервисы остаются на обычном подключении.'
            ],
            child: Column(
              children: [
                ...directPresets.map(
                  (preset) => _PresetRow(
                    key: ValueKey('rules-preset-${preset.id}'),
                    icon: _rulesPresetIcon(preset.id),
                    title: preset.title,
                    subtitle: preset.subtitle,
                    enabled: preset.enabled,
                    statusLabel: _rulesPresetStatusLabel(preset.state),
                  ),
                ),
              ],
            ),
          ),
        if (appContext.hostPlatform == HostPlatform.android &&
            selectedAppsActive &&
            excludedAppsActive)
          _RuAppsPresetCard(
            selectedRouteMode: selectedRouteMode,
            selectedAppIds: selectedAppIds,
            onApply: onRuAppPresetApplied,
          ),
        if (selectedAppsActive || excludedAppsActive || selectedAppsStaged)
          _SectionCard(
            key: const ValueKey('rules-section-selected-apps'),
            title: selectedRouteMode == RouteMode.excludedApps
                ? 'Напрямую без POKROV'
                : 'Только выбранные',
            lines: [
              selectedAppIds.isEmpty
                  ? 'Выберите хотя бы одно приложение перед подключением.'
                  : selectedRouteMode == RouteMode.excludedApps
                      ? 'Напрямую: ${selectedAppIds.length} · остальное через VPN'
                      : 'Через VPN: ${selectedAppIds.length}',
            ],
            child: _SelectedAppsEditor(
              hostPlatform: appContext.hostPlatform,
              routeMode: selectedRouteMode,
              selectedAppIds: selectedAppIds,
              onAdd: onSelectedAppAdded,
              onRemove: onSelectedAppRemoved,
            ),
          ),
        _RulesAdvancedSection(
          hostPlatform: appContext.hostPlatform,
          preferences: routingPreferences,
          fallbackMode: selectedRouteMode,
          onChanged: onRoutingPreferencesChanged,
          onApply: onRoutingPreferencesApply,
          connectionActive: connectionActive,
          onReadCurrentWifi: onReadCurrentWifi,
          onRequestWifiPermission: onRequestWifiPermission,
          onOpenVpnSettings: onOpenVpnSettings,
          onRoutingLessonCompleted: onRoutingLessonCompleted,
        ),
      ],
    );
  }
}

class _RulesAdvancedSection extends StatefulWidget {
  const _RulesAdvancedSection({
    required this.hostPlatform,
    required this.preferences,
    required this.fallbackMode,
    required this.onChanged,
    required this.onApply,
    required this.connectionActive,
    required this.onReadCurrentWifi,
    required this.onRequestWifiPermission,
    required this.onOpenVpnSettings,
    required this.onRoutingLessonCompleted,
  });

  final HostPlatform hostPlatform;
  final PokrovRoutingPreferences preferences;
  final RouteMode fallbackMode;
  final ValueChanged<PokrovRoutingPreferences> onChanged;
  final ValueChanged<PokrovRoutingPreferences> onApply;
  final bool connectionActive;
  final PokrovWifiProbe onReadCurrentWifi;
  final PokrovWifiPermissionRequester onRequestWifiPermission;
  final PokrovVpnSettingsLauncher onOpenVpnSettings;
  final VoidCallback onRoutingLessonCompleted;

  @override
  State<_RulesAdvancedSection> createState() => _RulesAdvancedSectionState();
}

class _RulesAdvancedSectionState extends State<_RulesAdvancedSection> {
  bool _expanded = false;
  late PokrovRoutingPreferences _appliedPreferences;
  late PokrovRoutingPreferences _draftPreferences;

  @override
  void initState() {
    super.initState();
    _appliedPreferences = widget.preferences;
    _draftPreferences = widget.preferences;
  }

  @override
  void didUpdateWidget(covariant _RulesAdvancedSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_sameRoutingPreferences(widget.preferences, _draftPreferences)) {
      return;
    }
    if (_sameRoutingPreferences(_draftPreferences, _appliedPreferences)) {
      _appliedPreferences = widget.preferences;
      _draftPreferences = widget.preferences;
    }
  }

  void _stage(PokrovRoutingPreferences next) {
    setState(() {
      _draftPreferences = next;
    });
    widget.onChanged(next);
  }

  void _apply() {
    if (_sameRoutingPreferences(_draftPreferences, _appliedPreferences)) {
      return;
    }
    PokrovHaptics.tap();
    final next = _draftPreferences;
    setState(() {
      _appliedPreferences = next;
    });
    widget.onApply(next);
  }

  @override
  Widget build(BuildContext context) {
    final changes = _routingPreferenceChangeLabels(
      _appliedPreferences,
      _draftPreferences,
    );
    final configuredCount = _draftPreferences.purposeRoutes.length +
        _draftPreferences.overrides.length +
        _draftPreferences.trustedWifiNames.length +
        (_draftPreferences.dnsPreset == PokrovDnsPreset.automatic ? 0 : 1) +
        (_draftPreferences.allowLan ? 0 : 1) +
        (widget.hostPlatform == HostPlatform.windows &&
                _draftPreferences.tunStack != PokrovTunStack.system
            ? 1
            : 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionCard(
          key: const ValueKey('rules-advanced-disclosure'),
          title: 'Дополнительно',
          lines: const ['Подключение, DNS, свои маршруты и Wi-Fi.'],
          child: _SettingsRow(
            key: const ValueKey('rules-advanced-toggle'),
            icon: Icons.tune_rounded,
            title: 'Редкие настройки',
            value: _expanded
                ? 'Скрыть'
                : configuredCount > 0
                    ? 'Настроено: $configuredCount'
                    : 'Открыть',
            valueIsAction: true,
            onTap: () => setState(() => _expanded = !_expanded),
          ),
        ),
        AnimatedSwitcher(
          duration: _MotionScope.of(context).duration(_MotionTokens.short),
          transitionBuilder: _fadeSlideTransition,
          child: !_expanded
              ? const SizedBox.shrink(key: ValueKey('rules-advanced-closed'))
              : Column(
                  key: const ValueKey('rules-advanced-open'),
                  children: [
                    if (widget.hostPlatform == HostPlatform.windows)
                      _WindowsConnectionCard(
                        preferences: _draftPreferences,
                        onChanged: _stage,
                      ),
                    _DnsAndLanCard(
                      preferences: _draftPreferences,
                      onChanged: _stage,
                    ),
                    _PurposeRoutingCard(
                      preferences: _draftPreferences,
                      onChanged: _stage,
                    ),
                    _CustomRoutingCard(
                      preferences: _draftPreferences,
                      fallbackMode: widget.fallbackMode,
                      onChanged: _stage,
                      onRoutingLessonCompleted: widget.onRoutingLessonCompleted,
                    ),
                    _TrustedWifiCard(
                      hostPlatform: widget.hostPlatform,
                      preferences: _draftPreferences,
                      onChanged: _stage,
                      onReadCurrentWifi: widget.onReadCurrentWifi,
                      onRequestWifiPermission: widget.onRequestWifiPermission,
                    ),
                    _AlwaysOnGuideCard(
                      hostPlatform: widget.hostPlatform,
                      onOpenVpnSettings: widget.onOpenVpnSettings,
                    ),
                  ],
                ),
        ),
        if (changes.isNotEmpty)
          _SectionCard(
            key: const ValueKey('rules-change-summary'),
            title: 'Изменения готовы',
            tone: _SectionTone.accent,
            lines: [
              changes.join(' · '),
              widget.connectionActive
                  ? 'Одно применение переподключит VPN.'
                  : 'Изменения вступят в силу при следующем подключении.',
            ],
            child: FilledButton.icon(
              key: const ValueKey('rules-apply-changes'),
              onPressed: _apply,
              icon: Icon(
                widget.connectionActive
                    ? Icons.sync_rounded
                    : Icons.check_rounded,
              ),
              label: Text(
                widget.connectionActive
                    ? 'Применить и переподключить'
                    : 'Сохранить изменения',
              ),
            ),
          ),
      ],
    );
  }
}

bool _sameRoutingPreferences(
  PokrovRoutingPreferences left,
  PokrovRoutingPreferences right,
) =>
    setEquals(left.purposeRoutes, right.purposeRoutes) &&
    listEquals(
      left.overrides.map((item) => item.id).toList(growable: false),
      right.overrides.map((item) => item.id).toList(growable: false),
    ) &&
    left.dnsPreset == right.dnsPreset &&
    left.customDnsUrl == right.customDnsUrl &&
    left.allowLan == right.allowLan &&
    listEquals(left.trustedWifiNames, right.trustedWifiNames) &&
    left.pauseOnTrustedWifi == right.pauseOnTrustedWifi &&
    left.windowsConnectionMode == right.windowsConnectionMode &&
    left.tunStack == right.tunStack;

List<String> _routingPreferenceChangeLabels(
  PokrovRoutingPreferences applied,
  PokrovRoutingPreferences draft,
) =>
    <String>[
      if (applied.dnsPreset != draft.dnsPreset ||
          applied.customDnsUrl != draft.customDnsUrl ||
          applied.allowLan != draft.allowLan)
        'DNS и локальная сеть',
      if (!setEquals(applied.purposeRoutes, draft.purposeRoutes))
        'готовые маршруты',
      if (!listEquals(
        applied.overrides.map((item) => item.id).toList(growable: false),
        draft.overrides.map((item) => item.id).toList(growable: false),
      ))
        'свои правила',
      if (!listEquals(applied.trustedWifiNames, draft.trustedWifiNames) ||
          applied.pauseOnTrustedWifi != draft.pauseOnTrustedWifi)
        'доверенный Wi-Fi',
      if (applied.windowsConnectionMode != draft.windowsConnectionMode ||
          applied.tunStack != draft.tunStack)
        'подключение Windows',
    ];

class _RouteModeSegmentedControl extends StatelessWidget {
  const _RouteModeSegmentedControl({
    required this.choices,
    required this.selectedRouteMode,
    required this.onRouteModeSelected,
  });

  final List<RouteMode> choices;
  final RouteMode selectedRouteMode;
  final ValueChanged<RouteMode> onRouteModeSelected;

  @override
  Widget build(BuildContext context) {
    final p = PokrovPalette.of(context);
    return Column(
      key: const ValueKey('rules-route-mode-segmented-control'),
      children: [
        for (var i = 0; i < choices.length; i += 1) ...[
          if (i > 0) Divider(height: 1, thickness: 1, color: p.line),
          _RouteModeSegment(
            mode: choices[i],
            selected: selectedRouteMode == choices[i],
            onTap: () => onRouteModeSelected(choices[i]),
          ),
        ],
      ],
    );
  }
}

class _RouteModeSegment extends StatelessWidget {
  const _RouteModeSegment({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final RouteMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final motion = _MotionScope.of(context);
    final p = PokrovPalette.of(context);
    final icon = switch (mode) {
      RouteMode.allExceptRu => Icons.public_rounded,
      RouteMode.fullTunnel => Icons.shield_outlined,
      RouteMode.selectedApps => Icons.apps_rounded,
      RouteMode.excludedApps => Icons.mobile_off_rounded,
    };
    final label = _routeModeShortLabel(mode);
    return Semantics(
      key: ValueKey('rules-mode-row-${mode.name}'),
      button: true,
      selected: selected,
      label: _routeModeRowTitle(mode),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: AnimatedContainer(
            duration: motion.duration(_MotionTokens.short),
            curve: _MotionTokens.ease,
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
            decoration: BoxDecoration(
              color: selected
                  ? p.accent.withValues(alpha: 0.10)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: selected
                        ? p.accent.withValues(alpha: 0.16)
                        : p.surfaceMuted,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    icon,
                    size: 19,
                    color: selected ? p.accent : p.muted,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: p.ink,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w600,
                        ),
                  ),
                ),
                const SizedBox(width: 8),
                // Radio-style choice: a checkmark states the selection; a
                // chevron would promise navigation. Same morph recipe as
                // PokrovCheckRow, 22px reserved so rows never reflow.
                AnimatedScale(
                  scale: selected ? 1 : 0.4,
                  duration: motion.duration(PokrovMotionTokens.short),
                  curve: PokrovMotionTokens.spring,
                  child: AnimatedOpacity(
                    opacity: selected ? 1 : 0,
                    duration: motion.duration(PokrovMotionTokens.quick),
                    curve: Curves.easeOut,
                    child: Icon(
                      Icons.check_rounded,
                      size: 22,
                      color: p.accent,
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

class _RuAppsPresetCard extends StatefulWidget {
  const _RuAppsPresetCard({
    required this.selectedRouteMode,
    required this.selectedAppIds,
    required this.onApply,
  });

  final RouteMode selectedRouteMode;
  final List<String> selectedAppIds;
  final void Function(RouteMode mode, List<String> appIds) onApply;

  @override
  State<_RuAppsPresetCard> createState() => _RuAppsPresetCardState();
}

class _RuAppsPresetCardState extends State<_RuAppsPresetCard> {
  late Future<List<_SelectedAppCandidate>> _installedFuture;

  @override
  void initState() {
    super.initState();
    _installedFuture = _loadAndroidInstalledAppCandidates();
  }

  void _refresh() {
    setState(() {
      _installedFuture = _loadAndroidInstalledAppCandidates();
    });
  }

  Future<void> _previewAndApply(
    RouteMode mode,
    List<_SelectedAppCandidate> candidates,
  ) async {
    final appIds = pokrovInstalledRuAppIds(
      candidates.map((candidate) => candidate.identifier),
    );
    if (appIds.isEmpty) {
      showPokrovSnack(
        context,
        'RU-приложения не найдены. Обновите список или настройте вручную.',
        tone: PokrovSnackTone.danger,
      );
      return;
    }
    final direct = mode == RouteMode.excludedApps;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final p = PokrovPalette.of(sheetContext);
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              0,
              20,
              20 + MediaQuery.viewInsetsOf(sheetContext).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  direct
                      ? 'RU-приложения напрямую'
                      : 'Только RU-приложения через VPN',
                  style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                        color: p.ink,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  direct
                      ? '${appIds.length} найдено · остальные приложения останутся через VPN.'
                      : '${appIds.length} найдено · остальные приложения пойдут напрямую.',
                  style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                        color: p.muted,
                      ),
                ),
                const SizedBox(height: 14),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: ListView.separated(
                    key: const ValueKey('rules-ru-preset-preview-list'),
                    shrinkWrap: true,
                    itemCount: appIds.length,
                    separatorBuilder: (_, __) => Divider(color: p.line),
                    itemBuilder: (context, index) {
                      final id = appIds[index];
                      final entry = pokrovRuAppCatalogEntry(id)!;
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.apps_rounded),
                        title: Text(entry.label),
                        subtitle: Text(
                          pokrovRuAppCategoryLabel(entry.category),
                        ),
                        trailing: Icon(
                          direct
                              ? Icons.public_off_outlined
                              : Icons.shield_outlined,
                          color: p.accent,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(sheetContext).pop(false),
                        child: const Text('Отмена'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        key: const ValueKey('rules-ru-preset-confirm'),
                        onPressed: () => Navigator.of(sheetContext).pop(true),
                        child: const Text('Применить'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    if (confirmed == true && mounted) {
      widget.onApply(mode, appIds);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      key: const ValueKey('rules-ru-app-presets'),
      title: 'RU-приложения',
      lines: const [
        'POKROV найдёт известные приложения на устройстве. Список остаётся локально.'
      ],
      child: FutureBuilder<List<_SelectedAppCandidate>>(
        future: _installedFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _MotionSkeletonList(rows: 2);
          }
          final candidates = (snapshot.data ?? const <_SelectedAppCandidate>[])
              .where((candidate) => candidate.ruCatalogEntry != null)
              .toList(growable: false);
          if (candidates.isEmpty) {
            return _SettingsRow(
              key: const ValueKey('rules-ru-app-presets-empty'),
              icon: Icons.refresh_rounded,
              title: 'Не нашли RU-приложения',
              value: 'Обновить',
              onTap: _refresh,
            );
          }
          final directSelected =
              widget.selectedRouteMode == RouteMode.excludedApps &&
                  widget.selectedAppIds.toSet().containsAll(
                        candidates.map((candidate) => candidate.identifier),
                      );
          final vpnSelected =
              widget.selectedRouteMode == RouteMode.selectedApps &&
                  widget.selectedAppIds.toSet().containsAll(
                        candidates.map((candidate) => candidate.identifier),
                      );
          return Column(
            children: [
              _SettingsRow(
                key: const ValueKey('rules-ru-apps-direct-preset'),
                icon: Icons.public_off_outlined,
                title: 'RU напрямую',
                value: directSelected ? 'Включено' : '${candidates.length}',
                onTap: () => unawaited(
                  _previewAndApply(RouteMode.excludedApps, candidates),
                ),
              ),
              _SettingsRow(
                key: const ValueKey('rules-ru-apps-vpn-preset'),
                icon: Icons.shield_outlined,
                title: 'Только RU через VPN',
                value: vpnSelected ? 'Включено' : '${candidates.length}',
                onTap: () => unawaited(
                  _previewAndApply(RouteMode.selectedApps, candidates),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SelectedAppsEditor extends StatefulWidget {
  const _SelectedAppsEditor({
    required this.hostPlatform,
    required this.routeMode,
    required this.selectedAppIds,
    required this.onAdd,
    required this.onRemove,
  });

  final HostPlatform hostPlatform;
  final RouteMode routeMode;
  final List<String> selectedAppIds;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onRemove;

  @override
  State<_SelectedAppsEditor> createState() => _SelectedAppsEditorState();
}

class _SelectedAppsEditorState extends State<_SelectedAppsEditor> {
  late final TextEditingController _controller;
  Future<List<_SelectedAppCandidate>>? _candidateFuture;
  bool _manualEntryVisible = false;
  String? _manualError;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final normalized = normalizePokrovSelectedAppIdentifier(
      _controller.text,
      hostPlatform: widget.hostPlatform,
    );
    if (normalized == null) {
      // Inline validation instead of a silent no-op.
      setState(() {
        _manualError = _controller.text.trim().isEmpty
            ? 'Введите название приложения.'
            : 'Не получилось добавить: используйте латинские буквы, цифры, точки или дефисы.';
      });
      return;
    }
    widget.onAdd(normalized);
    _controller.clear();
    setState(() {
      _manualError = null;
    });
  }

  Future<void> _openPicker() async {
    final candidateFuture = _loadSelectedAppCandidates(widget.hostPlatform);
    setState(() {
      _candidateFuture = candidateFuture;
    });
    final candidate = await showModalBottomSheet<_SelectedAppCandidate>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      sheetAnimationStyle: _pokrovSheetAnimationStyle(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _SelectedAppsPickerSheet(
        hostPlatform: widget.hostPlatform,
        routeMode: widget.routeMode,
        candidatesFuture: candidateFuture,
        selectedAppIds: widget.selectedAppIds,
      ),
    );
    if (candidate == null) {
      return;
    }
    Feedback.forTap(context);
    widget.onAdd(candidate.identifier);
  }

  @override
  Widget build(BuildContext context) {
    final p = PokrovPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            key: const ValueKey('rules-selected-app-pick'),
            onPressed: _openPicker,
            icon: const Icon(Icons.add_rounded),
            label: Text(
              widget.hostPlatform == HostPlatform.windows
                  ? 'Выбрать приложение'
                  : 'Добавить приложение',
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextButton.icon(
          key: const ValueKey('rules-selected-app-manual-toggle'),
          onPressed: () {
            setState(() {
              _manualEntryVisible = !_manualEntryVisible;
            });
          },
          icon: Icon(
            _manualEntryVisible
                ? Icons.expand_less_rounded
                : Icons.edit_outlined,
          ),
          label: Text(
            _manualEntryVisible ? 'Скрыть' : 'Не нашли приложение?',
          ),
        ),
        AnimatedSwitcher(
          duration: _MotionScope.of(context).duration(_MotionTokens.short),
          transitionBuilder: _fadeSlideTransition,
          child: _manualEntryVisible
              ? Padding(
                  key: const ValueKey('rules-selected-app-manual-fields'),
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          key: const ValueKey('rules-selected-app-input'),
                          controller: _controller,
                          // Revealing the manual field means the user is
                          // about to type: focus it right away.
                          autofocus: true,
                          decoration: InputDecoration(
                            labelText: 'Название для поддержки',
                            hintText:
                                'Если поддержка попросила добавить вручную',
                            helperText:
                                'Обычный способ - выбрать приложение из списка.',
                            errorText: _manualError,
                            errorMaxLines: 3,
                          ),
                          onChanged: (_) {
                            if (_manualError != null) {
                              setState(() {
                                _manualError = null;
                              });
                            }
                          },
                          onSubmitted: (_) => _submit(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        key: const ValueKey('rules-selected-app-add'),
                        tooltip: 'Добавить приложение',
                        onPressed: _submit,
                        icon: const Icon(Icons.add_rounded),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(
                  key: ValueKey('rules-selected-app-manual-hint'),
                ),
        ),
        const SizedBox(height: 10),
        if (widget.selectedAppIds.isEmpty)
          Container(
            key: const ValueKey('rules-selected-app-empty-state'),
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: p.surfaceMuted.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: p.line),
            ),
            child: Text(
              'Добавьте приложения из списка. Ручной ввод нужен только для восстановления или поддержки.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: p.muted,
                    height: 1.35,
                  ),
            ),
          )
        else ...[
          Text(
            'Выбрано (${widget.selectedAppIds.length})',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: p.muted,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<_SelectedAppCandidate>>(
            future: _candidateFuture,
            builder: (context, snapshot) {
              final candidatesById = <String, _SelectedAppCandidate>{
                for (final candidate
                    in snapshot.data ?? const <_SelectedAppCandidate>[])
                  candidate.identifier: candidate,
              };
              return Container(
                key: const ValueKey('rules-selected-app-list'),
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: p.line),
                ),
                // Row inserts and removals settle smoothly instead of jumping.
                child: AnimatedSize(
                  duration:
                      _MotionScope.of(context).duration(_MotionTokens.short),
                  curve: _MotionTokens.ease,
                  alignment: Alignment.topCenter,
                  child: Column(
                    children: widget.selectedAppIds
                        .map(
                          (appId) => _SelectedAppIdRow(
                            key: ValueKey('rules-selected-app-$appId'),
                            appId: appId,
                            candidate: candidatesById[appId],
                            onRemove: () {
                              PokrovHaptics.tap();
                              widget.onRemove(appId);
                            },
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}

class _SelectedAppIdRow extends StatelessWidget {
  const _SelectedAppIdRow({
    super.key,
    required this.appId,
    required this.candidate,
    required this.onRemove,
  });

  final String appId;
  final _SelectedAppCandidate? candidate;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final p = PokrovPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: p.accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: candidate?.iconBytes == null
                ? Icon(
                    candidate?.icon ?? Icons.apps_rounded,
                    color: p.accent,
                    size: 18,
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(
                      candidate!.iconBytes!,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.medium,
                      errorBuilder: (_, __, ___) => Icon(
                        candidate?.icon ?? Icons.apps_rounded,
                        color: p.accent,
                        size: 18,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _friendlySelectedAppName(appId),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: p.ink,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          IconButton(
            tooltip: 'Убрать',
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

class _LocationFlagBadge extends StatelessWidget {
  const _LocationFlagBadge({
    required this.code,
    required this.country,
  });

  final String code;
  final String country;

  @override
  Widget build(BuildContext context) {
    final normalizedCode = code.trim().toUpperCase();
    final hasIsoCountryCode = RegExp(r'^[A-Z]{2}$').hasMatch(normalizedCode);
    final p = PokrovPalette.of(context);
    final fallback = Center(
      child: Text(
        _shortLocationCode(code, country),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: p.accent,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
    return Semantics(
      label: country.trim().isEmpty ? normalizedCode : 'Флаг: $country',
      image: true,
      child: Container(
        width: 46,
        height: 46,
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: p.surfaceMuted,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: p.line),
        ),
        child: hasIsoCountryCode
            ? CountryFlag.fromCountryCode(
                normalizedCode,
                key: ValueKey('location-flag-$normalizedCode'),
                theme: const ImageTheme(
                  width: 36,
                  height: 26,
                  shape: RoundedRectangle(7),
                ),
              )
            : fallback,
      ),
    );
  }
}

String _shortLocationCode(String code, String country) {
  final raw = code.trim().isNotEmpty ? code.trim() : country.trim();
  if (raw.isEmpty) {
    return 'PO';
  }
  final letters = raw
      .replaceAll(RegExp('[^A-Za-zА-Яа-я]'), '')
      .toUpperCase()
      .characters
      .take(2)
      .toList()
      .join();
  return letters.isEmpty
      ? raw.toUpperCase().characters.take(2).join()
      : letters;
}

enum _SelectedAppCandidateSource {
  installed,
  installedExecutable,
  runningProcess,
  suggested,
}

class _SelectedAppCandidate {
  const _SelectedAppCandidate({
    required this.label,
    required this.identifier,
    required this.subtitle,
    required this.source,
    required this.icon,
    this.iconBytes,
    this.ruCatalogEntry,
  });

  final String label;
  final String identifier;
  final String subtitle;
  final _SelectedAppCandidateSource source;
  final IconData icon;
  final Uint8List? iconBytes;
  final PokrovRuAppCatalogEntry? ruCatalogEntry;

  String get searchText => '$label $identifier $subtitle'.toLowerCase().trim();
}

class _SelectedAppsPickerSheet extends StatefulWidget {
  const _SelectedAppsPickerSheet({
    required this.hostPlatform,
    required this.routeMode,
    required this.candidatesFuture,
    required this.selectedAppIds,
  });

  final HostPlatform hostPlatform;
  final RouteMode routeMode;
  final Future<List<_SelectedAppCandidate>> candidatesFuture;
  final List<String> selectedAppIds;

  @override
  State<_SelectedAppsPickerSheet> createState() =>
      _SelectedAppsPickerSheetState();
}

class _SelectedAppsPickerSheetState extends State<_SelectedAppsPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  late Future<List<_SelectedAppCandidate>> _candidatesFuture;
  String _query = '';
  bool _ruOnly = false;

  @override
  void initState() {
    super.initState();
    _candidatesFuture = widget.candidatesFuture;
  }

  void _refreshCandidates() {
    setState(() {
      _candidatesFuture = _loadSelectedAppCandidates(widget.hostPlatform);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final motion = _MotionScope.of(context);
    final p = PokrovPalette.of(context);
    final title = 'Выбор приложений';
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;
    final availableHeight = math.max(0.0, mediaQuery.size.height - bottomInset);
    final sheetHeight =
        math.min(mediaQuery.size.height * 0.82, availableHeight);
    final searchField = TextField(
      key: const ValueKey('rules-selected-app-search'),
      controller: _searchController,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search_rounded),
        labelText: 'Поиск по названию',
        filled: true,
        fillColor: p.surfaceMuted.withValues(alpha: 0.70),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: _searchController,
          builder: (context, value, _) => value.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  key: const ValueKey(
                    'rules-selected-app-search-clear',
                  ),
                  tooltip: 'Очистить',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => setState(() {
                    _searchController.clear();
                    _query = '';
                  }),
                ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: p.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: p.line),
        ),
      ),
      onChanged: (value) => setState(() {
        _query = value.trim().toLowerCase();
      }),
    );
    return AnimatedPadding(
      key: const ValueKey('rules-selected-app-picker-inset'),
      duration: motion.duration(_MotionTokens.short),
      curve: _MotionTokens.ease,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        key: const ValueKey('rules-selected-app-picker-sheet'),
        height: sheetHeight,
        child: SafeArea(
          top: false,
          bottom: bottomInset == 0,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxHeight < 240;
              return Padding(
                padding: compact
                    ? const EdgeInsets.fromLTRB(12, 0, 12, 8)
                    : const EdgeInsets.fromLTRB(20, 2, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!compact)
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: p.accent.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Icon(
                              widget.hostPlatform == HostPlatform.windows
                                  ? Icons.desktop_windows_outlined
                                  : Icons.apps_rounded,
                              color: p.accent,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                        color: p.ink,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                Text(
                                  widget.routeMode == RouteMode.excludedApps
                                      ? 'Выбранные приложения будут работать напрямую.'
                                      : widget.hostPlatform ==
                                              HostPlatform.windows
                                          ? 'Выберите приложение, которое пойдёт через VPN.'
                                          : 'Выберите приложения, которые пойдут через VPN.',
                                  maxLines: 2,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: p.muted,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            key: const ValueKey(
                              'rules-selected-app-refresh',
                            ),
                            tooltip: 'Обновить список',
                            onPressed: _refreshCandidates,
                            icon: const Icon(Icons.refresh_rounded),
                          ),
                          IconButton(
                            tooltip: 'Закрыть',
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    SizedBox(height: compact ? 0 : 16),
                    if (compact)
                      Row(
                        children: [
                          Expanded(child: searchField),
                          const SizedBox(width: 8),
                          IconButton(
                            key: const ValueKey(
                              'rules-selected-app-refresh-compact',
                            ),
                            tooltip: 'Обновить список',
                            onPressed: _refreshCandidates,
                            icon: const Icon(Icons.refresh_rounded),
                          ),
                          IconButton(
                            tooltip: 'Закрыть',
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      )
                    else
                      searchField,
                    SizedBox(height: compact ? 8 : 14),
                    if (!compact &&
                        widget.hostPlatform == HostPlatform.android) ...[
                      FilterChip(
                        key: const ValueKey('rules-selected-app-filter-ru'),
                        selected: _ruOnly,
                        avatar: const Icon(Icons.flag_outlined, size: 17),
                        label: const Text('Российские'),
                        onSelected: (selected) => setState(() {
                          _ruOnly = selected;
                        }),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Expanded(
                      child: FutureBuilder<List<_SelectedAppCandidate>>(
                        future: _candidatesFuture,
                        builder: (context, snapshot) {
                          final fallbackCandidates =
                              _suggestedSelectedAppCandidates(
                            widget.hostPlatform,
                          );
                          if (snapshot.connectionState !=
                                  ConnectionState.done &&
                              fallbackCandidates.isEmpty) {
                            return const _MotionSkeletonList(
                              rows: 5,
                            );
                          }
                          final rawCandidates = snapshot.connectionState ==
                                      ConnectionState.done &&
                                  snapshot.data != null
                              ? snapshot.data!
                              : fallbackCandidates;
                          final displayLabels =
                              _selectedAppDisplayLabels(rawCandidates);
                          final candidates = rawCandidates
                              .where(
                                (candidate) =>
                                    (!_ruOnly ||
                                        candidate.ruCatalogEntry != null) &&
                                    (_query.isEmpty ||
                                        candidate.searchText.contains(_query)),
                              )
                              .toList(growable: false);
                          if (candidates.isEmpty) {
                            return Center(
                              child: Text(
                                'Ничего не найдено. Проверьте название или добавьте приложение вручную.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: p.muted,
                                    ),
                              ),
                            );
                          }
                          return ListView.separated(
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            itemCount: candidates.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final candidate = candidates[index];
                              final selected = widget.selectedAppIds
                                  .contains(candidate.identifier);
                              return AnimatedOpacity(
                                duration: motion.duration(_MotionTokens.short),
                                opacity: selected ? 0.62 : 1,
                                child: _SelectedAppCandidateRow(
                                  key: ValueKey(
                                    'rules-selected-app-option-${candidate.identifier}',
                                  ),
                                  candidate: candidate,
                                  displayLabel:
                                      displayLabels[candidate.identifier] ??
                                          candidate.label,
                                  compact: compact,
                                  selected: selected,
                                  onTap: selected
                                      ? null
                                      : () =>
                                          Navigator.of(context).pop(candidate),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SelectedAppCandidateRow extends StatelessWidget {
  const _SelectedAppCandidateRow({
    super.key,
    required this.candidate,
    required this.displayLabel,
    required this.compact,
    required this.selected,
    required this.onTap,
  });

  final _SelectedAppCandidate candidate;
  final String displayLabel;
  final bool compact;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = PokrovPalette.of(context);
    final content = Container(
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 10, vertical: 4)
          : const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        color: selected ? p.accent.withValues(alpha: 0.08) : p.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected ? p.accent.withValues(alpha: 0.18) : p.line,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: compact ? 36 : 42,
            height: compact ? 36 : 42,
            decoration: BoxDecoration(
              color: p.accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(15),
            ),
            child: candidate.iconBytes == null
                ? Icon(candidate.icon, color: p.accent, size: 21)
                : ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      candidate.iconBytes!,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.medium,
                      errorBuilder: (_, __, ___) => Icon(
                        candidate.icon,
                        color: p.accent,
                        size: 21,
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
                  displayLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: p.ink,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                if (!compact) ...[
                  const SizedBox(height: 3),
                  Text(
                    _visibleSelectedAppSubtitle(candidate),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: p.muted,
                          height: 1.2,
                        ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Icon(
            selected
                ? Icons.check_circle_rounded
                : Icons.add_circle_outline_rounded,
            color: selected ? p.success : p.accent,
          ),
        ],
      ),
    );
    final row = onTap == null
        ? content
        : PokrovSettingsRowPressSurface(onTap: onTap!, child: content);
    return Semantics(
      container: true,
      button: true,
      enabled: onTap != null,
      selected: selected,
      label: displayLabel,
      value: selected ? 'Уже выбрано' : 'Не выбрано',
      hint: selected ? null : 'Добавить приложение',
      child: ExcludeSemantics(child: row),
    );
  }
}

String _visibleSelectedAppSubtitle(_SelectedAppCandidate candidate) {
  final subtitle = candidate.subtitle.trim();
  final ruEntry = candidate.ruCatalogEntry;
  if (ruEntry != null) {
    return 'Российское · ${pokrovRuAppCategoryLabel(ruEntry.category)}';
  }
  if (candidate.source == _SelectedAppCandidateSource.suggested &&
      subtitle.isNotEmpty &&
      !_looksLikeSelectedAppIdentifier(subtitle)) {
    return subtitle;
  }
  return switch (candidate.source) {
    _SelectedAppCandidateSource.installed => 'Установлено на устройстве',
    _SelectedAppCandidateSource.installedExecutable =>
      'Можно выбрать для POKROV',
    _SelectedAppCandidateSource.runningProcess => 'Открыто сейчас',
    _SelectedAppCandidateSource.suggested => 'Рекомендуем',
  };
}

String _friendlySelectedAppName(String identifier) {
  final value = identifier.trim();
  final lower = value.toLowerCase();
  const known = <String, String>{
    'org.telegram.messenger': 'Telegram',
    'telegram.exe': 'Telegram',
    'com.android.chrome': 'Chrome',
    'chrome.exe': 'Chrome',
    'com.yandex.browser': 'Яндекс Браузер',
    'com.google.android.youtube': 'YouTube',
    'youtube.exe': 'YouTube',
    'com.discord': 'Discord',
    'discord.exe': 'Discord',
    'steam.exe': 'Steam',
    'msedge.exe': 'Edge',
  };
  final knownName = known[lower];
  if (knownName != null) {
    return knownName;
  }
  final parts =
      value.split(RegExp(r'[._:-]+')).where((part) => part.isNotEmpty).toList();
  final base = lower.endsWith('.exe')
      ? value.substring(0, value.length - 4)
      : parts.isEmpty
          ? value
          : parts.last;
  final words = base
      .replaceAll(RegExp(r'[_:-]+'), ' ')
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .map((word) => word[0].toUpperCase() + word.substring(1))
      .join(' ');
  return words.isEmpty ? 'Приложение' : words;
}

bool _looksLikeSelectedAppIdentifier(String value) {
  final lower = value.trim().toLowerCase();
  return lower.endsWith('.exe') ||
      RegExp(r'^[a-z0-9_]+(?:\.[a-z0-9_]+){2,}$').hasMatch(lower);
}

const _selectedAppsRuntimeChannel =
    MethodChannel('space.pokrov/runtime_engine');

Future<List<_SelectedAppCandidate>> _loadSelectedAppCandidates(
  HostPlatform hostPlatform,
) async {
  final nativeCandidates = switch (hostPlatform) {
    HostPlatform.android => await _loadAndroidInstalledAppCandidates(),
    HostPlatform.windows => <_SelectedAppCandidate>[
        ...await _loadWindowsProcessCandidates(),
        ...await _loadWindowsExecutableCandidates(),
      ],
    HostPlatform.ios || HostPlatform.macos => const <_SelectedAppCandidate>[],
  };
  return _mergeSelectedAppCandidates(
    <_SelectedAppCandidate>[
      ...nativeCandidates,
      ..._suggestedSelectedAppCandidates(hostPlatform),
    ],
  );
}

Future<List<_SelectedAppCandidate>> _loadAndroidInstalledAppCandidates() async {
  try {
    final response = await _selectedAppsRuntimeChannel
        .invokeListMethod<Object?>('runtimeEngine.listInstalledApps');
    return _candidatesFromHostMaps(
      response,
      hostPlatform: HostPlatform.android,
      source: _SelectedAppCandidateSource.installed,
      icon: Icons.android_rounded,
    );
  } on MissingPluginException {
    return const <_SelectedAppCandidate>[];
  } on PlatformException {
    return const <_SelectedAppCandidate>[];
  }
}

Future<List<_SelectedAppCandidate>> _loadWindowsProcessCandidates() async {
  if (!Platform.isWindows) {
    return const <_SelectedAppCandidate>[];
  }
  try {
    final result = await Process.run(
      'powershell',
      <String>[
        '-NoProfile',
        '-Command',
        r'[Console]::OutputEncoding=[System.Text.Encoding]::UTF8; Get-Process | Select-Object -ExpandProperty ProcessName | Sort-Object -Unique | ConvertTo-Json -Compress',
      ],
    ).timeout(const Duration(seconds: 3));
    if (result.exitCode != 0) {
      return const <_SelectedAppCandidate>[];
    }
    final decoded = jsonDecode(result.stdout.toString());
    final names = switch (decoded) {
      final List<Object?> list => list.whereType<String>(),
      final String single => <String>[single],
      _ => const <String>[],
    };
    return names
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .map((name) {
          final identifier = name.toLowerCase().endsWith('.exe')
              ? name.toLowerCase()
              : '${name.toLowerCase()}.exe';
          return _SelectedAppCandidate(
            label: _friendlySelectedAppName(identifier),
            identifier: identifier,
            subtitle: identifier,
            source: _SelectedAppCandidateSource.runningProcess,
            icon: Icons.memory_rounded,
          );
        })
        .where((candidate) =>
            normalizePokrovSelectedAppIdentifier(
              candidate.identifier,
              hostPlatform: HostPlatform.windows,
            ) !=
            null)
        .take(120)
        .toList(growable: false);
  } on Object {
    return const <_SelectedAppCandidate>[];
  }
}

Future<List<_SelectedAppCandidate>> _loadWindowsExecutableCandidates() async {
  if (!Platform.isWindows) {
    return const <_SelectedAppCandidate>[];
  }
  try {
    final result = await Process.run(
      'powershell',
      <String>[
        '-NoProfile',
        '-Command',
        r'''
[Console]::OutputEncoding=[System.Text.Encoding]::UTF8;
$roots = @(
  $env:ProgramFiles,
  ${env:ProgramFiles(x86)},
  (Join-Path $env:LOCALAPPDATA 'Programs')
) | Where-Object { $_ -and (Test-Path -LiteralPath $_) };
if (-not $roots) { @() | ConvertTo-Json -Compress; exit 0 }
Get-ChildItem -LiteralPath $roots -Filter *.exe -File -Recurse -Depth 3 -ErrorAction SilentlyContinue |
  Sort-Object Name -Unique |
  Select-Object -First 160 `
    @{Name='label';Expression={ if ($_.VersionInfo.FileDescription) { $_.VersionInfo.FileDescription } else { $_.BaseName } }},
    @{Name='identifier';Expression={ $_.Name.ToLowerInvariant() }},
    @{Name='subtitle';Expression={ $_.FullName }} |
  ConvertTo-Json -Compress
''',
      ],
    ).timeout(const Duration(seconds: 3));
    if (result.exitCode != 0) {
      return const <_SelectedAppCandidate>[];
    }
    final decoded = jsonDecode(result.stdout.toString());
    return _candidatesFromHostMaps(
      switch (decoded) {
        final List<Object?> list => list,
        final Map<String, Object?> single => <Object?>[single],
        _ => const <Object?>[],
      },
      hostPlatform: HostPlatform.windows,
      source: _SelectedAppCandidateSource.installedExecutable,
      icon: Icons.folder_open_rounded,
    ).take(160).toList(growable: false);
  } on Object {
    return const <_SelectedAppCandidate>[];
  }
}

List<_SelectedAppCandidate> _candidatesFromHostMaps(
  List<Object?>? response, {
  required HostPlatform hostPlatform,
  required _SelectedAppCandidateSource source,
  required IconData icon,
}) {
  if (response == null) {
    return const <_SelectedAppCandidate>[];
  }
  final candidates = <_SelectedAppCandidate>[];
  for (final item in response) {
    if (item is! Map) {
      continue;
    }
    final identifier = normalizePokrovSelectedAppIdentifier(
      item['identifier']?.toString() ?? '',
      hostPlatform: hostPlatform,
    );
    if (identifier == null) {
      continue;
    }
    final label = item['label']?.toString().trim();
    final subtitle = item['subtitle']?.toString().trim();
    final iconBytes = _decodeSelectedAppIcon(item['iconPngBase64']);
    final ruCatalogEntry = hostPlatform == HostPlatform.android
        ? pokrovRuAppCatalogEntry(identifier)
        : null;
    final safeLabel =
        label == null || label.isEmpty || _looksLikeSelectedAppIdentifier(label)
            ? _friendlySelectedAppName(identifier)
            : label;
    candidates.add(
      _SelectedAppCandidate(
        label: safeLabel,
        identifier: identifier,
        subtitle: subtitle == null || subtitle.isEmpty ? identifier : subtitle,
        source: source,
        icon: icon,
        iconBytes: iconBytes,
        ruCatalogEntry: ruCatalogEntry,
      ),
    );
  }
  return candidates;
}

Uint8List? _decodeSelectedAppIcon(Object? value) {
  final encoded = value?.toString().trim() ?? '';
  if (encoded.isEmpty || encoded.length > 196000) {
    return null;
  }
  try {
    final bytes = base64Decode(encoded);
    return bytes.isEmpty || bytes.length > 128000 ? null : bytes;
  } on FormatException {
    return null;
  }
}

List<_SelectedAppCandidate> _suggestedSelectedAppCandidates(
  HostPlatform hostPlatform,
) {
  switch (hostPlatform) {
    case HostPlatform.android:
      return const <_SelectedAppCandidate>[
        _SelectedAppCandidate(
          label: 'Telegram',
          identifier: 'org.telegram.messenger',
          subtitle: 'Мессенджер',
          source: _SelectedAppCandidateSource.suggested,
          icon: Icons.send_rounded,
        ),
        _SelectedAppCandidate(
          label: 'YouTube',
          identifier: 'com.google.android.youtube',
          subtitle: 'Видео',
          source: _SelectedAppCandidateSource.suggested,
          icon: Icons.play_circle_fill_rounded,
        ),
        _SelectedAppCandidate(
          label: 'Chrome',
          identifier: 'com.android.chrome',
          subtitle: 'Браузер',
          source: _SelectedAppCandidateSource.suggested,
          icon: Icons.public_rounded,
        ),
        _SelectedAppCandidate(
          label: 'Discord',
          identifier: 'com.discord',
          subtitle: 'Голос и чат',
          source: _SelectedAppCandidateSource.suggested,
          icon: Icons.forum_rounded,
        ),
      ];
    case HostPlatform.windows:
      return const <_SelectedAppCandidate>[
        _SelectedAppCandidate(
          label: 'Telegram',
          identifier: 'telegram.exe',
          subtitle: 'Мессенджер',
          source: _SelectedAppCandidateSource.suggested,
          icon: Icons.send_rounded,
        ),
        _SelectedAppCandidate(
          label: 'Chrome',
          identifier: 'chrome.exe',
          subtitle: 'Браузер',
          source: _SelectedAppCandidateSource.suggested,
          icon: Icons.public_rounded,
        ),
        _SelectedAppCandidate(
          label: 'Edge',
          identifier: 'msedge.exe',
          subtitle: 'Браузер',
          source: _SelectedAppCandidateSource.suggested,
          icon: Icons.public_rounded,
        ),
        _SelectedAppCandidate(
          label: 'Discord',
          identifier: 'discord.exe',
          subtitle: 'Голос и чат',
          source: _SelectedAppCandidateSource.suggested,
          icon: Icons.forum_rounded,
        ),
        _SelectedAppCandidate(
          label: 'Steam',
          identifier: 'steam.exe',
          subtitle: 'Игры',
          source: _SelectedAppCandidateSource.suggested,
          icon: Icons.sports_esports_rounded,
        ),
      ];
    case HostPlatform.ios:
    case HostPlatform.macos:
      return const <_SelectedAppCandidate>[];
  }
}

List<_SelectedAppCandidate> _mergeSelectedAppCandidates(
  List<_SelectedAppCandidate> candidates,
) {
  final seen = <String>{};
  final merged = <_SelectedAppCandidate>[];
  for (final candidate in candidates) {
    final key = candidate.identifier.toLowerCase();
    if (!seen.add(key)) {
      continue;
    }
    merged.add(candidate);
  }
  merged.sort((left, right) {
    final ruRank = (right.ruCatalogEntry != null ? 1 : 0)
        .compareTo(left.ruCatalogEntry != null ? 1 : 0);
    if (ruRank != 0) {
      return ruRank;
    }
    final installedRank = left.source.index.compareTo(right.source.index);
    if (installedRank != 0) {
      return installedRank;
    }
    return left.label.toLowerCase().compareTo(right.label.toLowerCase());
  });
  return merged;
}

Map<String, String> _selectedAppDisplayLabels(
  List<_SelectedAppCandidate> candidates,
) {
  final groups = <String, List<_SelectedAppCandidate>>{};
  for (final candidate in candidates) {
    groups
        .putIfAbsent(candidate.label.trim().toLowerCase(), () => [])
        .add(candidate);
  }

  final labels = <String, String>{};
  for (final group in groups.values) {
    if (group.length == 1) {
      labels[group.single.identifier] = group.single.label;
      continue;
    }
    final ordered = [...group]..sort(
        (left, right) => left.identifier
            .toLowerCase()
            .compareTo(right.identifier.toLowerCase()),
      );
    for (var index = 0; index < ordered.length; index += 1) {
      final candidate = ordered[index];
      labels[candidate.identifier] = '${candidate.label} · ${index + 1}';
    }
  }
  return labels;
}
