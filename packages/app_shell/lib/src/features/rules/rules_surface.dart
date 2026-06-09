part of pokrov_app_shell;

class _RulesSection extends StatelessWidget {
  const _RulesSection({
    required this.appContext,
    required this.selectedRouteMode,
    required this.selectedAppIds,
    required this.onRouteModeSelected,
    required this.onSelectedAppAdded,
    required this.onSelectedAppRemoved,
  });

  final SeedAppContext appContext;
  final RouteMode selectedRouteMode;
  final List<String> selectedAppIds;
  final ValueChanged<RouteMode> onRouteModeSelected;
  final ValueChanged<String> onSelectedAppAdded;
  final ValueChanged<String> onSelectedAppRemoved;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final routeChoices = appContext.runtimeProfile.supportedRouteModes;
    final selectedAppsActive = routeChoices.contains(RouteMode.selectedApps);
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
      top: 24,
      children: [
        Text('Правила подключения', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Что идет через POKROV?',
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
                    color: _SeedPalette.muted,
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
                            ? '${_routeModeShortLabel(RouteMode.selectedApps)}: появится после системной проверки.'
                            : '${_routeModeShortLabel(RouteMode.selectedApps)}: недоступно на ${appContext.hostPlatform.label}.',
                  ],
                ),
              ),
            ],
          ),
        ),
        if (directPresets.isNotEmpty)
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
        if (selectedAppsActive || selectedAppsStaged)
          _SectionCard(
            key: const ValueKey('rules-section-selected-apps'),
            title: 'Выбранные приложения',
            lines: [
              selectedAppIds.isEmpty
                  ? isWindows
                      ? 'Добавьте процессы, если хотите вести через POKROV только часть приложений.'
                      : 'Добавьте приложения, если хотите вести через POKROV только часть телефона.'
                  : 'Выбрано: ${selectedAppIds.length}',
            ],
            child: _SelectedAppsEditor(
              hostPlatform: appContext.hostPlatform,
              selectedAppIds: selectedAppIds,
              onAdd: onSelectedAppAdded,
              onRemove: onSelectedAppRemoved,
            ),
          ),
      ],
    );
  }
}

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
    return Container(
      key: const ValueKey('rules-route-mode-segmented-control'),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _SeedPalette.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _SeedPalette.line),
      ),
      child: Row(
        children: [
          for (final mode in choices)
            Expanded(
              child: _RouteModeSegment(
                mode: mode,
                selected: selectedRouteMode == mode,
                onTap: () => onRouteModeSelected(mode),
              ),
            ),
        ],
      ),
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
    final icon = switch (mode) {
      RouteMode.allExceptRu => Icons.public_rounded,
      RouteMode.fullTunnel => Icons.shield_outlined,
      RouteMode.selectedApps => Icons.apps_rounded,
    };
    final label = switch (mode) {
      RouteMode.allExceptRu => 'За рубеж',
      RouteMode.fullTunnel => 'Все',
      RouteMode.selectedApps => 'Приложения',
    };
    return Semantics(
      key: ValueKey('rules-mode-row-${mode.name}'),
      button: true,
      selected: selected,
      label: _routeModeRowTitle(mode),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: AnimatedContainer(
            duration: motion.duration(_MotionTokens.short),
            curve: _MotionTokens.ease,
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: selected
                  ? _SeedPalette.accent.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? _SeedPalette.accent.withValues(alpha: 0.18)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: selected ? _SeedPalette.accent : _SeedPalette.muted,
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: selected
                              ? _SeedPalette.accent
                              : _SeedPalette.ink.withValues(alpha: 0.68),
                          fontWeight:
                              selected ? FontWeight.w900 : FontWeight.w700,
                        ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: selected
                      ? _SeedPalette.accent
                      : _SeedPalette.ink.withValues(alpha: 0.32),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedAppsEditor extends StatefulWidget {
  const _SelectedAppsEditor({
    required this.hostPlatform,
    required this.selectedAppIds,
    required this.onAdd,
    required this.onRemove,
  });

  final HostPlatform hostPlatform;
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

  @override
  void didUpdateWidget(covariant _SelectedAppsEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hostPlatform != widget.hostPlatform) {
      _candidateFuture = null;
    }
  }

  void _submit() {
    final normalized = _normalizeSelectedAppIdentifier(_controller.text);
    if (normalized == null) {
      return;
    }
    widget.onAdd(normalized);
    _controller.clear();
  }

  Future<void> _openPicker() async {
    final candidateFuture =
        _candidateFuture ??= _loadSelectedAppCandidates(widget.hostPlatform);
    final candidate = await showModalBottomSheet<_SelectedAppCandidate>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: _SeedPalette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _SelectedAppsPickerSheet(
        hostPlatform: widget.hostPlatform,
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
    final hint = switch (widget.hostPlatform) {
      HostPlatform.windows => 'telegram.exe',
      HostPlatform.android => 'org.telegram.messenger',
      HostPlatform.ios || HostPlatform.macos => 'app.identifier',
    };
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
                  ? 'Выбрать процесс'
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
            _manualEntryVisible ? 'Скрыть ручной ввод' : 'Добавить вручную',
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
                          decoration: InputDecoration(
                            labelText: 'Название приложения',
                            hintText: hint,
                          ),
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
              : Align(
                  key: const ValueKey('rules-selected-app-manual-hint'),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Если приложения нет в списке, добавьте его вручную.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: _SeedPalette.muted,
                          height: 1.35,
                        ),
                  ),
                ),
        ),
        const SizedBox(height: 10),
        if (widget.selectedAppIds.isEmpty)
          Container(
            key: const ValueKey('rules-selected-app-empty-state'),
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _SeedPalette.surfaceMuted.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _SeedPalette.line),
            ),
            child: Text(
              'Добавьте приложения, и POKROV будет работать только для них.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _SeedPalette.muted,
                    height: 1.35,
                  ),
            ),
          )
        else ...[
          Text(
            'Выбрано (${widget.selectedAppIds.length})',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: _SeedPalette.muted,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Container(
            key: const ValueKey('rules-selected-app-list'),
            decoration: BoxDecoration(
              color: _SeedPalette.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _SeedPalette.line),
            ),
            child: Column(
              children: widget.selectedAppIds
                  .map(
                    (appId) => _SelectedAppIdRow(
                      key: ValueKey('rules-selected-app-$appId'),
                      appId: appId,
                      onRemove: () => widget.onRemove(appId),
                    ),
                  )
                  .toList(growable: false),
            ),
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
    required this.onRemove,
  });

  final String appId;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _SeedPalette.accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.apps_rounded,
              color: _SeedPalette.accent,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              appId,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: _SeedPalette.ink,
                    fontWeight: FontWeight.w800,
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
    final label = _shortLocationCode(code, country);
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: _SeedPalette.surfaceMuted,
        shape: BoxShape.circle,
        border: Border.all(color: _SeedPalette.line),
      ),
      child: Center(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: _SeedPalette.accent,
                fontWeight: FontWeight.w900,
              ),
        ),
      ),
    );
  }
}

class _SignalBars extends StatelessWidget {
  const _SignalBars({
    required this.score,
  });

  final double score;

  @override
  Widget build(BuildContext context) {
    final normalized = score <= 0 ? 0.78 : score.clamp(0.18, 1.0);
    final activeCount = (normalized * 4).ceil().clamp(1, 4);
    return SizedBox(
      width: 28,
      height: 22,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var index = 0; index < 4; index += 1)
            AnimatedContainer(
              duration: _MotionScope.of(context).duration(_MotionTokens.short),
              curve: _MotionTokens.ease,
              width: 4,
              height: 7.0 + index * 4,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                color: index < activeCount
                    ? _SeedPalette.accent
                    : _SeedPalette.ink.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
        ],
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

String _smartConnectNodeCity(SmartConnectNode node) {
  final code = node.code.trim().toUpperCase();
  if (code.contains('NL')) {
    return 'Амстердам';
  }
  if (code.contains('DE')) {
    return 'Франкфурт';
  }
  if (code.contains('FI')) {
    return 'Хельсинки';
  }
  if (code.contains('UK') || code.contains('GB')) {
    return 'Лондон';
  }
  final host = node.probeHost.trim();
  if (host.isNotEmpty) {
    return host;
  }
  return node.code.trim().isEmpty ? 'POKROV' : node.code.trim().toUpperCase();
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
  });

  final String label;
  final String identifier;
  final String subtitle;
  final _SelectedAppCandidateSource source;
  final IconData icon;

  String get searchText => '$label $identifier $subtitle'.toLowerCase().trim();

  String get sourceLabel {
    switch (source) {
      case _SelectedAppCandidateSource.installed:
        return 'Установлено';
      case _SelectedAppCandidateSource.installedExecutable:
        return 'Файл';
      case _SelectedAppCandidateSource.runningProcess:
        return 'Запущено';
      case _SelectedAppCandidateSource.suggested:
        return 'Подсказка';
    }
  }
}

class _SelectedAppsPickerSheet extends StatefulWidget {
  const _SelectedAppsPickerSheet({
    required this.hostPlatform,
    required this.candidatesFuture,
    required this.selectedAppIds,
  });

  final HostPlatform hostPlatform;
  final Future<List<_SelectedAppCandidate>> candidatesFuture;
  final List<String> selectedAppIds;

  @override
  State<_SelectedAppsPickerSheet> createState() =>
      _SelectedAppsPickerSheetState();
}

class _SelectedAppsPickerSheetState extends State<_SelectedAppsPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final motion = _MotionScope.of(context);
    final title = widget.hostPlatform == HostPlatform.windows
        ? 'Процессы Windows'
        : 'Приложения';
    return SizedBox(
      key: const ValueKey('rules-selected-app-picker-sheet'),
      height: MediaQuery.sizeOf(context).height * 0.82,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: _SeedPalette.accent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      widget.hostPlatform == HostPlatform.windows
                          ? Icons.desktop_windows_outlined
                          : Icons.apps_rounded,
                      color: _SeedPalette.accent,
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
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: _SeedPalette.ink,
                                    fontWeight: FontWeight.w900,
                                  ),
                        ),
                        Text(
                          widget.hostPlatform == HostPlatform.windows
                              ? 'Выберите .exe или запущенный процесс.'
                              : 'Выберите приложения для режима «только выбранные».',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: _SeedPalette.muted,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Закрыть',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                key: const ValueKey('rules-selected-app-search'),
                controller: _searchController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  labelText: 'Поиск',
                  filled: true,
                  fillColor: _SeedPalette.surfaceMuted.withValues(alpha: 0.70),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: _SeedPalette.line),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: _SeedPalette.line),
                  ),
                ),
                onChanged: (value) => setState(() {
                  _query = value.trim().toLowerCase();
                }),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: FutureBuilder<List<_SelectedAppCandidate>>(
                  future: widget.candidatesFuture,
                  builder: (context, snapshot) {
                    final fallbackCandidates = _suggestedSelectedAppCandidates(
                      widget.hostPlatform,
                    );
                    if (snapshot.connectionState != ConnectionState.done &&
                        fallbackCandidates.isEmpty) {
                      return const _MotionSkeletonList(
                        rows: 5,
                      );
                    }
                    final rawCandidates =
                        snapshot.connectionState == ConnectionState.done &&
                                snapshot.data != null
                            ? snapshot.data!
                            : fallbackCandidates;
                    final candidates = rawCandidates
                        .where(
                          (candidate) =>
                              _query.isEmpty ||
                              candidate.searchText.contains(_query),
                        )
                        .toList(growable: false);
                    if (candidates.isEmpty) {
                      return Center(
                        child: Text(
                          'Ничего не найдено. Добавьте приложение вручную ниже.',
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: _SeedPalette.muted,
                                  ),
                        ),
                      );
                    }
                    return ListView.separated(
                      itemCount: candidates.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
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
                            selected: selected,
                            onTap: selected
                                ? null
                                : () => Navigator.of(context).pop(candidate),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
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
    required this.selected,
    required this.onTap,
  });

  final _SelectedAppCandidate candidate;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        color: selected
            ? _SeedPalette.accent.withValues(alpha: 0.08)
            : _SeedPalette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected
              ? _SeedPalette.accent.withValues(alpha: 0.18)
              : _SeedPalette.line,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _SeedPalette.accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              candidate.icon,
              color: _SeedPalette.accent,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  candidate.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: _SeedPalette.ink,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      key: ValueKey(
                        'rules-selected-app-source-${candidate.identifier}',
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _SeedPalette.accent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        candidate.sourceLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: _SeedPalette.accent,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        candidate.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: _SeedPalette.muted,
                              height: 1.2,
                            ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Icon(
            selected
                ? Icons.check_circle_rounded
                : Icons.add_circle_outline_rounded,
            color: selected ? _SeedPalette.success : _SeedPalette.accent,
          ),
        ],
      ),
    );
    if (onTap == null) {
      return content;
    }
    return PokrovSettingsRowPressSurface(onTap: onTap!, child: content);
  }
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
        .invokeListMethod<Object?>('runtimeEngine.listInstalledApps')
        .timeout(const Duration(seconds: 2));
    return _candidatesFromHostMaps(
      response,
      source: _SelectedAppCandidateSource.installed,
      icon: Icons.android_rounded,
    );
  } on TimeoutException {
    return const <_SelectedAppCandidate>[];
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
            label: identifier,
            identifier: identifier,
            subtitle: identifier,
            source: _SelectedAppCandidateSource.runningProcess,
            icon: Icons.memory_rounded,
          );
        })
        .where((candidate) =>
            _normalizeSelectedAppIdentifier(candidate.identifier) != null)
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
      source: _SelectedAppCandidateSource.installedExecutable,
      icon: Icons.folder_open_rounded,
    ).take(160).toList(growable: false);
  } on Object {
    return const <_SelectedAppCandidate>[];
  }
}

List<_SelectedAppCandidate> _candidatesFromHostMaps(
  List<Object?>? response, {
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
    final identifier = _normalizeSelectedAppIdentifier(
      item['identifier']?.toString() ?? '',
    );
    if (identifier == null) {
      continue;
    }
    final label = item['label']?.toString().trim();
    final subtitle = item['subtitle']?.toString().trim();
    candidates.add(
      _SelectedAppCandidate(
        label: label == null || label.isEmpty ? identifier : label,
        identifier: identifier,
        subtitle: subtitle == null || subtitle.isEmpty ? identifier : subtitle,
        source: source,
        icon: icon,
      ),
    );
  }
  return candidates;
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
          subtitle: 'org.telegram.messenger',
          source: _SelectedAppCandidateSource.suggested,
          icon: Icons.send_rounded,
        ),
        _SelectedAppCandidate(
          label: 'YouTube',
          identifier: 'com.google.android.youtube',
          subtitle: 'com.google.android.youtube',
          source: _SelectedAppCandidateSource.suggested,
          icon: Icons.play_circle_fill_rounded,
        ),
        _SelectedAppCandidate(
          label: 'Chrome',
          identifier: 'com.android.chrome',
          subtitle: 'com.android.chrome',
          source: _SelectedAppCandidateSource.suggested,
          icon: Icons.public_rounded,
        ),
        _SelectedAppCandidate(
          label: 'Discord',
          identifier: 'com.discord',
          subtitle: 'com.discord',
          source: _SelectedAppCandidateSource.suggested,
          icon: Icons.forum_rounded,
        ),
      ];
    case HostPlatform.windows:
      return const <_SelectedAppCandidate>[
        _SelectedAppCandidate(
          label: 'Telegram',
          identifier: 'telegram.exe',
          subtitle: 'telegram.exe',
          source: _SelectedAppCandidateSource.suggested,
          icon: Icons.send_rounded,
        ),
        _SelectedAppCandidate(
          label: 'Chrome',
          identifier: 'chrome.exe',
          subtitle: 'chrome.exe',
          source: _SelectedAppCandidateSource.suggested,
          icon: Icons.public_rounded,
        ),
        _SelectedAppCandidate(
          label: 'Edge',
          identifier: 'msedge.exe',
          subtitle: 'msedge.exe',
          source: _SelectedAppCandidateSource.suggested,
          icon: Icons.public_rounded,
        ),
        _SelectedAppCandidate(
          label: 'Discord',
          identifier: 'discord.exe',
          subtitle: 'discord.exe',
          source: _SelectedAppCandidateSource.suggested,
          icon: Icons.forum_rounded,
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
  return merged;
}

String? _normalizeSelectedAppIdentifier(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty || normalized.length > 96) {
    return null;
  }
  final safe = RegExp(r'^[a-zA-Z0-9._:-]+$');
  if (!safe.hasMatch(normalized)) {
    return null;
  }
  return normalized;
}
