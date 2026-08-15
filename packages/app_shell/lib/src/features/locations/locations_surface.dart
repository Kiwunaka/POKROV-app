part of pokrov_app_shell;

class _LocationsSection extends StatefulWidget {
  const _LocationsSection({
    required this.appContext,
    required this.selectedRouteMode,
    required this.hasProvisionedAccess,
    required this.smartConnectProfile,
    required this.locationsCatalog,
    required this.locationsCatalogBusy,
    required this.locationsCatalogError,
    required this.locationsUsingCache,
    required this.locationsCachedAt,
    required this.onRefreshLocationsCatalog,
    required this.preferredNodeCode,
    required this.preferredVariantId,
    required this.nodePreferenceBusy,
    required this.onAutomaticLocationSelected,
    required this.onPreferredNodeSelected,
    required this.favoriteNodeCodes,
    required this.recentNodeCodes,
    required this.onFavoriteNodeToggle,
    required this.onOpenEmergencyNetwork,
  });

  final SeedAppContext appContext;
  final RouteMode selectedRouteMode;
  final bool hasProvisionedAccess;
  final SmartConnectProfile? smartConnectProfile;
  final ClientLocationsCatalog? locationsCatalog;
  final bool locationsCatalogBusy;
  final String? locationsCatalogError;
  final bool locationsUsingCache;
  final String locationsCachedAt;
  final VoidCallback onRefreshLocationsCatalog;
  final String preferredNodeCode;
  final String preferredVariantId;
  final bool nodePreferenceBusy;
  final VoidCallback onAutomaticLocationSelected;
  final void Function(String nodeCode, String variantId)
      onPreferredNodeSelected;
  final List<String> favoriteNodeCodes;
  final List<String> recentNodeCodes;
  final ValueChanged<String> onFavoriteNodeToggle;
  final VoidCallback onOpenEmergencyNetwork;

  @override
  State<_LocationsSection> createState() => _LocationsSectionState();
}

class _LocationsSectionState extends State<_LocationsSection> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _canSelectLocation {
    if (widget.smartConnectProfile != null) {
      return true;
    }
    return widget.locationsCatalog?.countries.any(
          (country) => country.cities.isNotEmpty,
        ) ??
        false;
  }

  bool _matches(SmartConnectNode node) {
    if (_query.isEmpty) {
      return true;
    }
    final haystack =
        '${node.country} ${_smartConnectNodeCity(node)} ${node.code}'
            .toLowerCase();
    return haystack.contains(_query);
  }

  bool _matchesCatalog(_ClientLocationEntry entry) {
    if (_query.isEmpty) {
      return true;
    }
    final haystack =
        '${entry.country.country} ${entry.country.code} ${entry.city.city} ${entry.city.code}'
            .toLowerCase();
    return haystack.contains(_query);
  }

  List<_ClientLocationEntry> _catalogEntries(ClientLocationsCatalog? catalog) {
    if (catalog == null) {
      return const <_ClientLocationEntry>[];
    }
    final entries = <_ClientLocationEntry>[];
    for (final country in catalog.countries) {
      for (final city in country.cities) {
        if (city.code.trim().isEmpty) {
          continue;
        }
        entries.add(_ClientLocationEntry(country: country, city: city));
      }
    }
    return entries;
  }

  Future<void> _selectCatalogEntry(_ClientLocationEntry entry) async {
    final variants = entry.city.variants;
    final available =
        variants.where((variant) => variant.available).toList(growable: false);
    if (variants.isEmpty) {
      widget.onPreferredNodeSelected(entry.city.code, 'direct');
      return;
    }
    if (available.length == 1 && available.single.id == 'direct') {
      widget.onPreferredNodeSelected(entry.city.code, available.single.id);
      return;
    }
    if (available.isEmpty) {
      showPokrovSnack(
        context,
        'Для этой локации сейчас нет доступного варианта.',
        tone: PokrovSnackTone.danger,
      );
      return;
    }
    final selected = await showModalBottomSheet<ClientLocationVariant>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _LocationVariantSheet(
        cityName: _locationCityDisplayName(entry.city, entry.country),
        variants: variants,
        selectedVariantId: entry.city.code.trim().toLowerCase() ==
                widget.preferredNodeCode.trim().toLowerCase()
            ? widget.preferredVariantId
            : '',
        runtimeProbeEnabled:
            widget.appContext.hostPlatform == HostPlatform.android &&
                entry.city.code.trim().toLowerCase() ==
                    widget.preferredNodeCode.trim().toLowerCase(),
      ),
    );
    if (selected != null && mounted) {
      widget.onPreferredNodeSelected(entry.city.code, selected.id);
    }
  }

  Widget _catalogSection({
    required String title,
    required List<_ClientLocationEntry> entries,
    bool showEmpty = false,
  }) {
    final theme = Theme.of(context);
    final tokens = PokrovPalette.of(context);
    if (entries.isEmpty && !showEmpty) {
      return const SizedBox.shrink();
    }
    return _SectionCard(
      title: title,
      lines: const [],
      child: entries.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Ничего не найдено',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: tokens.muted,
                ),
              ),
            )
          : Column(
              children: entries
                  .map(
                    (entry) => _ClientLocationCityRow(
                      entry: entry,
                      selected: entry.city.code.trim().toLowerCase() ==
                          widget.preferredNodeCode.trim().toLowerCase(),
                      selectedVariantId: widget.preferredVariantId,
                      favorite: widget.favoriteNodeCodes.contains(
                        entry.city.code.trim().toLowerCase(),
                      ),
                      disabled: widget.nodePreferenceBusy,
                      selectionEnabled:
                          _canSelectLocation && !widget.nodePreferenceBusy,
                      onTap: () => unawaited(_selectCatalogEntry(entry)),
                      onFavoriteToggle: () =>
                          widget.onFavoriteNodeToggle(entry.city.code),
                    ),
                  )
                  .toList(growable: false),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = PokrovPalette.of(context);
    final smartConnect = widget.smartConnectProfile;
    final shortlist = smartConnect?.shortlist ?? const <SmartConnectNode>[];
    final catalogEntries = _catalogEntries(widget.locationsCatalog);
    final hasCatalog = catalogEntries.isNotEmpty;
    final hasShortlist = widget.hasProvisionedAccess && shortlist.isNotEmpty;
    final hasList = hasCatalog || hasShortlist;
    final showRefreshSpinner = widget.locationsCatalogBusy && hasList;
    final filteredCatalog = hasCatalog
        ? catalogEntries.where(_matchesCatalog).toList(growable: false)
        : const <_ClientLocationEntry>[];
    final favoriteCodes = widget.favoriteNodeCodes.toSet();
    final recentCodes = widget.recentNodeCodes.toSet();
    final favoriteEntries = filteredCatalog
        .where((entry) => favoriteCodes.contains(entry.city.code.toLowerCase()))
        .toList(growable: false);
    final recentEntries = filteredCatalog
        .where(
          (entry) =>
              !favoriteCodes.contains(entry.city.code.toLowerCase()) &&
              recentCodes.contains(entry.city.code.toLowerCase()),
        )
        .toList(growable: false);
    final remainingEntries = filteredCatalog
        .where(
          (entry) =>
              !favoriteCodes.contains(entry.city.code.toLowerCase()) &&
              !recentCodes.contains(entry.city.code.toLowerCase()),
        )
        .toList(growable: false);
    final filtered = hasShortlist
        ? shortlist.where(_matches).toList(growable: false)
        : const <SmartConnectNode>[];
    final locationCount = hasCatalog ? catalogEntries.length : shortlist.length;
    final hasManualPreference = widget.preferredNodeCode.trim().isNotEmpty;
    final autoStatus = hasManualPreference
        ? _AutoLocationStatus.manual
        : !widget.hasProvisionedAccess
            ? _AutoLocationStatus.unavailable
            : _AutoLocationStatus.active;

    return _SeedContentList(
      children: [
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      'Локации',
                      style: theme.textTheme.headlineSmall,
                    ),
                  ),
                  const SizedBox(width: 2),
                  IconButton(
                    key: const ValueKey('locations-metrics-help'),
                    tooltip: 'Как считаются замеры',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _showInfoSheet(
                      context,
                      title: 'Ping и нагрузка',
                      lines: const [
                        'Ping измеряется с этого устройства до каждой локации. Это не ping выбранного сервера.',
                        'Процент рядом — текущая нагрузка сервера. «Обновить» проверяет список заново.',
                        'Эмулятор может показывать нереально низкий ping. Для решения о локации ориентируйтесь на замер телефона.',
                      ],
                    ),
                    icon: const Icon(Icons.info_outline_rounded, size: 20),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Tooltip(
              message:
                  'Измерить ping с этого устройства и обновить нагрузку серверов',
              child: OutlinedButton.icon(
                key: const ValueKey('locations-refresh-measurements'),
                onPressed: widget.locationsCatalogBusy
                    ? null
                    : widget.onRefreshLocationsCatalog,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                icon: showRefreshSpinner
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CupertinoActivityIndicator(radius: 9),
                      )
                    : const Icon(Icons.refresh_rounded, size: 20),
                label: Text(
                  widget.locationsCatalogBusy ? 'Обновляем' : 'Обновить',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (hasList && locationCount > 4) ...[
          _LocationSearchField(
            controller: _searchController,
            onChanged: (value) => setState(() {
              _query = value.trim().toLowerCase();
            }),
            onClear: () => setState(() {
              _searchController.clear();
              _query = '';
            }),
          ),
          const SizedBox(height: 14),
        ],
        _AutoLocationCard(
          key: const ValueKey('locations-auto-section'),
          title: 'Автоматически',
          subtitle: switch (autoStatus) {
            _AutoLocationStatus.active =>
              'Быстрый маршрут · ${_routeModeShortLabel(widget.selectedRouteMode)}',
            _AutoLocationStatus.manual => 'Нажмите, чтобы вернуть авто',
            _AutoLocationStatus.unavailable => 'Сначала включите POKROV VPN',
          },
          value: switch (autoStatus) {
            _AutoLocationStatus.active => 'Авто',
            _AutoLocationStatus.manual => 'Вручную',
            _AutoLocationStatus.unavailable => 'Недоступно',
          },
          status: autoStatus,
          onTap: autoStatus == _AutoLocationStatus.manual &&
                  !widget.nodePreferenceBusy
              ? widget.onAutomaticLocationSelected
              : () => _showInfoSheet(
                    context,
                    title: 'Автоматически',
                    lines: [
                      'POKROV сам выбирает страну и старается держать быстрый маршрут.',
                      'Если выбрать страну ниже, она станет предпочтительной после переподключения.',
                    ],
                  ),
        ),
        const SizedBox(height: 14),
        _EmergencyNetworkLauncherCard(
          onTap: widget.onOpenEmergencyNetwork,
        ),
        if (hasList && !_canSelectLocation) ...[
          const SizedBox(height: 14),
          const _SectionCard(
            key: ValueKey('locations-selection-locked'),
            title: 'Выбор локации пока недоступен',
            tone: _SectionTone.muted,
            lines: [
              'Обновите список локаций или подготовьте доступ кнопкой «Подключить».',
            ],
          ),
        ],
        if (!widget.locationsCatalogBusy &&
            widget.hasProvisionedAccess &&
            (widget.locationsCatalogError ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 14),
          _SectionCard(
            key: const ValueKey('locations-catalog-error'),
            title: widget.locationsUsingCache
                ? 'Нет свежих данных'
                : 'Список стран не обновился',
            tone: _SectionTone.muted,
            lines: [
              widget.locationsUsingCache
                  ? 'Показываем сохранённый список. ${_locationCacheLabel(widget.locationsCachedAt)}'
                  : 'Не удалось загрузить данные. Проверьте подключение к интернету и повторите.',
            ],
            child: PokrovActionRow(
              key: const ValueKey('locations-catalog-retry'),
              icon: Icons.refresh_rounded,
              title: 'Повторить',
              onTap: widget.onRefreshLocationsCatalog,
            ),
          ),
        ],
        if (hasCatalog) ...[
          _catalogSection(title: 'Избранное', entries: favoriteEntries),
          if (favoriteEntries.isNotEmpty) const SizedBox(height: 14),
          _catalogSection(title: 'Недавние', entries: recentEntries),
          if (recentEntries.isNotEmpty) const SizedBox(height: 14),
          _catalogSection(
            title: 'Все локации',
            entries: remainingEntries,
            showEmpty: filteredCatalog.isEmpty,
          ),
        ] else if (hasList) ...[
          _SectionCard(
            title: 'Премиум-локации',
            lines: const [],
            child: filtered.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Ничего не найдено',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: tokens.muted,
                      ),
                    ),
                  )
                : Column(
                    children: filtered
                        .map(
                          (node) => _SmartConnectNodeRow(
                            node: node,
                            selected: node.code.trim().toLowerCase() ==
                                widget.preferredNodeCode.trim().toLowerCase(),
                            favorite: widget.favoriteNodeCodes.contains(
                              node.code.trim().toLowerCase(),
                            ),
                            disabled: widget.nodePreferenceBusy,
                            selectionEnabled: _canSelectLocation &&
                                !widget.nodePreferenceBusy,
                            onTap: () => widget.onPreferredNodeSelected(
                              node.code,
                              'direct',
                            ),
                            onFavoriteToggle: () =>
                                widget.onFavoriteNodeToggle(node.code),
                          ),
                        )
                        .toList(growable: false),
                  ),
          ),
        ] else if (widget.hasProvisionedAccess) ...[
          // First catalog load: skeleton rows instead of an indeterminate
          // Material bar — same loading language as the rest of the shell.
          if (widget.locationsCatalogBusy)
            const _MotionSkeletonList(
              key: ValueKey('locations-catalog-loading-skeleton'),
              rows: 3,
            )
          else
            _SectionCard(
              title: 'Выбор страны',
              tone: _SectionTone.muted,
              lines: const [
                'Пока доступен автоматический выбор. Список стран обновится вместе с доступом.',
              ],
            ),
        ] else ...[
          const _MotionSkeletonList(
            key: ValueKey('locations-skeleton-list'),
            rows: 4,
          ),
          _SectionCard(
            title: 'Список стран откроется после первого подключения',
            lines: ['Нажмите «Подключить» на главном экране.'],
          ),
        ],
      ],
    );
  }
}

class _LocationSearchField extends StatelessWidget {
  const _LocationSearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const ValueKey('locations-search-field'),
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Поиск по странам и городам',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) => value.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  tooltip: 'Очистить',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: onClear,
                ),
        ),
      ),
    );
  }
}

enum _AutoLocationStatus { active, manual, unavailable }

class _AutoLocationCard extends StatelessWidget {
  const _AutoLocationCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.status,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String value;
  final _AutoLocationStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = PokrovPalette.of(context);
    final isActive = status == _AutoLocationStatus.active;
    final isUnavailable = status == _AutoLocationStatus.unavailable;
    final statusTone = switch (status) {
      _AutoLocationStatus.active => _SectionTone.accent,
      _AutoLocationStatus.manual => _SectionTone.neutral,
      _AutoLocationStatus.unavailable => _SectionTone.muted,
    };
    final statusIcon = switch (status) {
      _AutoLocationStatus.active => Icons.check_circle_outline_rounded,
      _AutoLocationStatus.manual => Icons.location_on_outlined,
      _AutoLocationStatus.unavailable => Icons.lock_outline_rounded,
    };
    final content = Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isActive ? p.accent.withValues(alpha: 0.06) : p.surfaceMuted,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isActive ? p.accent.withValues(alpha: 0.16) : p.line,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 330;
          final statusPill = _StatusPill(
            label: value,
            icon: statusIcon,
            tone: statusTone,
          );
          final header = Row(
            children: [
              Container(
                width: compact ? 48 : 54,
                height: compact ? 48 : 54,
                decoration: BoxDecoration(
                  color:
                      isActive ? p.accent.withValues(alpha: 0.12) : p.surface,
                  borderRadius: BorderRadius.circular(compact ? 16 : 18),
                ),
                child: Icon(
                  isUnavailable
                      ? Icons.lock_outline_rounded
                      : Icons.travel_explore_rounded,
                  color: isActive ? p.accent : p.muted,
                  size: compact ? 24 : 27,
                ),
              ),
              SizedBox(width: compact ? 12 : 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: p.ink,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: p.muted,
                            height: 1.25,
                          ),
                    ),
                  ],
                ),
              ),
              if (!compact) ...[
                const SizedBox(width: 12),
                statusPill,
              ],
            ],
          );
          if (!compact) {
            return header;
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              header,
              const SizedBox(height: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [statusPill],
              ),
            ],
          );
        },
      ),
    );
    return KeyedSubtree(
      key: const ValueKey('locations-auto-help-action'),
      child: PokrovSettingsRowPressSurface(onTap: onTap, child: content),
    );
  }
}

class _LocationVariantSheet extends StatefulWidget {
  const _LocationVariantSheet({
    required this.cityName,
    required this.variants,
    required this.selectedVariantId,
    this.runtimeProbeEnabled = false,
  });

  final String cityName;
  final List<ClientLocationVariant> variants;
  final String selectedVariantId;
  final bool runtimeProbeEnabled;

  @override
  State<_LocationVariantSheet> createState() => _LocationVariantSheetState();
}

class _LocationVariantSheetState extends State<_LocationVariantSheet> {
  PokrovLocationVariantProbeSnapshot? _snapshot;
  String? _checkingVariantId;
  bool _hasSuccessfulFullProbe = false;

  bool get _checking => _checkingVariantId != null;

  bool _checkingFor(ClientLocationVariant variant) =>
      _checkingVariantId == '' || _checkingVariantId == variant.id;

  @override
  void initState() {
    super.initState();
    if (widget.runtimeProbeEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_refresh());
        }
      });
    }
  }

  Future<void> _refresh({String variantId = ''}) async {
    if (_checking || !widget.runtimeProbeEnabled) {
      return;
    }
    setState(() => _checkingVariantId = variantId);
    final snapshot = await measurePokrovLocationVariants(
      HostPlatform.android,
      variantId: variantId,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      if (variantId.isEmpty || _snapshot == null) {
        _snapshot = snapshot;
      } else {
        final previous = _snapshot!;
        _snapshot = PokrovLocationVariantProbeSnapshot(
          results: <String, PokrovLocationVariantProbeResult>{
            ...previous.results,
            ...snapshot.results,
          },
          activeVariantId: snapshot.activeVariantId.isEmpty
              ? previous.activeVariantId
              : snapshot.activeVariantId,
          observedAt: snapshot.observedAt ?? previous.observedAt,
          errorCategory: snapshot.errorCategory,
        );
      }
      if (variantId.isEmpty &&
          snapshot.errorCategory.isEmpty &&
          snapshot.results.isNotEmpty) {
        _hasSuccessfulFullProbe = true;
      }
      _checkingVariantId = null;
    });
  }

  PokrovLocationVariantProbeResult? _resultFor(ClientLocationVariant variant) =>
      _snapshot?.results[variant.id];

  bool _missingFromSuccessfulProbe(ClientLocationVariant variant) =>
      _hasSuccessfulFullProbe &&
      _snapshot != null &&
      _snapshot!.errorCategory.isEmpty &&
      _snapshot!.results.isNotEmpty &&
      !_snapshot!.results.containsKey(variant.id);

  int _sortRank(ClientLocationVariant variant) {
    if (!variant.available || _missingFromSuccessfulProbe(variant)) {
      return 4;
    }
    final status = _resultFor(variant)?.status;
    return switch (status) {
      PokrovLocationVariantProbeStatus.available => 0,
      PokrovLocationVariantProbeStatus.stale => 2,
      PokrovLocationVariantProbeStatus.unavailable => 4,
      _ => 1,
    };
  }

  List<ClientLocationVariant> get _sortedVariants {
    final indexed = widget.variants.indexed.toList(growable: false);
    indexed.sort((left, right) {
      final rank = _sortRank(left.$2).compareTo(_sortRank(right.$2));
      if (rank != 0) {
        return rank;
      }
      final leftLatency = _resultFor(left.$2)?.latencyMs ?? 1 << 30;
      final rightLatency = _resultFor(right.$2)?.latencyMs ?? 1 << 30;
      final latency = leftLatency.compareTo(rightLatency);
      return latency != 0 ? latency : left.$1.compareTo(right.$1);
    });
    return indexed.map((item) => item.$2).toList(growable: false);
  }

  String _statusText(ClientLocationVariant variant) {
    if (!variant.available || _missingFromSuccessfulProbe(variant)) {
      return 'Недоступно';
    }
    if (_checkingFor(variant)) {
      return 'Проверяем…';
    }
    final result = _resultFor(variant);
    return switch (result?.status) {
      PokrovLocationVariantProbeStatus.available =>
        '${result?.latencyMs ?? '—'} мс',
      PokrovLocationVariantProbeStatus.unavailable => 'Недоступно',
      PokrovLocationVariantProbeStatus.stale => 'Нужна проверка',
      _ => widget.runtimeProbeEnabled ? 'Не проверено' : 'После выбора',
    };
  }

  IconData _statusIcon(ClientLocationVariant variant) {
    if (_checkingFor(variant)) {
      return Icons.sync_rounded;
    }
    if (!variant.available ||
        _missingFromSuccessfulProbe(variant) ||
        _resultFor(variant)?.status ==
            PokrovLocationVariantProbeStatus.unavailable) {
      return Icons.cancel_rounded;
    }
    return switch (_resultFor(variant)?.status) {
      PokrovLocationVariantProbeStatus.available => Icons.check_circle_rounded,
      PokrovLocationVariantProbeStatus.stale => Icons.schedule_rounded,
      _ => Icons.help_outline_rounded,
    };
  }

  Color _statusColor(
    ClientLocationVariant variant,
    PokrovPaletteTokens p,
  ) {
    if (!variant.available ||
        _missingFromSuccessfulProbe(variant) ||
        _resultFor(variant)?.status ==
            PokrovLocationVariantProbeStatus.unavailable) {
      return p.danger;
    }
    return switch (_resultFor(variant)?.status) {
      PokrovLocationVariantProbeStatus.available => p.accent,
      PokrovLocationVariantProbeStatus.stale => p.warning,
      _ => p.muted,
    };
  }

  bool _selectable(ClientLocationVariant variant) =>
      variant.available &&
      !_missingFromSuccessfulProbe(variant) &&
      _resultFor(variant)?.status !=
          PokrovLocationVariantProbeStatus.unavailable;

  String _freshnessText(ClientLocationVariant variant) {
    final measuredAt = _resultFor(variant)?.measuredAt;
    if (measuredAt == null) {
      return '';
    }
    final age = DateTime.now().toUtc().difference(measuredAt.toUtc()).abs();
    if (age < const Duration(minutes: 1)) {
      return 'сейчас';
    }
    if (age < const Duration(hours: 1)) {
      return '${age.inMinutes} мин назад';
    }
    if (age < const Duration(days: 1)) {
      return '${age.inHours} ч назад';
    }
    return '${age.inDays} дн назад';
  }

  @override
  Widget build(BuildContext context) {
    final p = PokrovPalette.of(context);
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        key: const ValueKey('location-variant-sheet-scroll'),
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.cityName,
                    key: const ValueKey('location-variant-sheet-title'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: p.ink,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                IconButton(
                  key: const ValueKey('location-variant-refresh'),
                  tooltip: widget.runtimeProbeEnabled
                      ? 'Проверить все варианты'
                      : 'Сначала выберите эту локацию',
                  onPressed: widget.runtimeProbeEnabled && !_checking
                      ? () => unawaited(_refresh())
                      : null,
                  icon: _checking
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Как подключаться к этой локации',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: p.muted,
                  ),
            ),
            const SizedBox(height: 14),
            if (!widget.runtimeProbeEnabled) ...[
              Text(
                'Точный статус появится после выбора этой локации.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: p.muted,
                    ),
              ),
              const SizedBox(height: 4),
            ] else if ((_snapshot?.errorCategory ?? '').isNotEmpty) ...[
              Text(
                'Не удалось проверить через активный туннель. Подключите POKROV и повторите.',
                key: const ValueKey('location-variant-probe-error'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: p.muted,
                    ),
              ),
              const SizedBox(height: 4),
            ],
            ..._sortedVariants.map((variant) {
              final selected = variant.id == widget.selectedVariantId;
              final active = variant.id == _snapshot?.activeVariantId;
              final selectable = _selectable(variant);
              final statusText = _statusText(variant);
              final freshnessText = _freshnessText(variant);
              final statusColor = _statusColor(variant, p);
              final row = Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            variant.label,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: p.ink,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          if (variant.description.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              variant.description,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: p.muted),
                            ),
                          ],
                          const SizedBox(height: 5),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _statusIcon(variant),
                                    size: 16,
                                    color: statusColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    statusText,
                                    key: ValueKey(
                                      'location-variant-status-${variant.id}',
                                    ),
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(
                                          color: statusColor,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ],
                              ),
                              if (active)
                                Text(
                                  'Сейчас работает',
                                  key: ValueKey(
                                    'location-variant-active-${variant.id}',
                                  ),
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelMedium
                                      ?.copyWith(
                                        color: p.accent,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              if (selected && !active)
                                Text(
                                  'Выбрано',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelMedium
                                      ?.copyWith(color: p.muted),
                                ),
                              if (freshnessText.isNotEmpty)
                                Text(
                                  freshnessText,
                                  key: ValueKey(
                                    'location-variant-freshness-${variant.id}',
                                  ),
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelMedium
                                      ?.copyWith(color: p.muted),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.runtimeProbeEnabled)
                          IconButton(
                            key: ValueKey(
                              'location-variant-refresh-${variant.id}',
                            ),
                            tooltip: 'Повторить замер: ${variant.label}',
                            constraints: const BoxConstraints.tightFor(
                              width: 44,
                              height: 44,
                            ),
                            onPressed: _checking
                                ? null
                                : () => unawaited(
                                      _refresh(variantId: variant.id),
                                    ),
                            icon: _checkingFor(variant)
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.refresh_rounded, size: 19),
                          ),
                        Icon(
                          selected
                              ? Icons.check_circle_rounded
                              : selectable
                                  ? Icons.circle_outlined
                                  : Icons.cancel_outlined,
                          color: selected ? p.accent : statusColor,
                        ),
                      ],
                    ),
                  ],
                ),
              );
              return Semantics(
                key: ValueKey('location-variant-${variant.id}'),
                button: true,
                enabled: selectable,
                selected: selected,
                label: variant.label,
                value: [
                  statusText,
                  if (freshnessText.isNotEmpty) freshnessText,
                  if (selected) 'выбрано',
                  if (active) 'сейчас работает',
                ].join(', '),
                child: selectable
                    ? PokrovSettingsRowPressSurface(
                        onTap: () => Navigator.of(context).pop(variant),
                        child: row,
                      )
                    : Opacity(
                        opacity: PokrovListRow.disabledOpacity,
                        child: row,
                      ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _ClientLocationEntry {
  const _ClientLocationEntry({required this.country, required this.city});

  final ClientLocationCountry country;
  final ClientLocationCity city;
}

class _ClientLocationCityRow extends StatelessWidget {
  const _ClientLocationCityRow({
    required this.entry,
    required this.selected,
    required this.selectedVariantId,
    required this.favorite,
    required this.disabled,
    required this.selectionEnabled,
    required this.onTap,
    required this.onFavoriteToggle,
  });

  final _ClientLocationEntry entry;
  final bool selected;
  final String selectedVariantId;
  final bool favorite;
  final bool disabled;
  final bool selectionEnabled;
  final VoidCallback onTap;
  final VoidCallback onFavoriteToggle;

  @override
  Widget build(BuildContext context) {
    final p = PokrovPalette.of(context);
    final city = entry.city;
    final country = entry.country;
    final now = DateTime.now().toUtc();
    final freshness = _locationMetricFreshness(city.measuredAt, now: now);
    final quality = freshness == _LocationMetricFreshness.current
        ? _locationQualityLabel(
            city.healthScore,
            latencyMs: city.latencyMs,
          )
        : null;
    final metrics = _locationMetricsLabel(
      city,
      now: now,
      compact: true,
    );
    final countryTitle = _locationCountryDisplayName(
      country.code,
      country.country,
    );
    final cityTitle = _locationCityDisplayName(city, country);
    final availableVariantLabels = city.variants
        .where(
            (variant) => variant.available && variant.label.trim().isNotEmpty)
        .map((variant) => variant.label.trim())
        .toList(growable: false);
    final hasVariantChoice = availableVariantLabels.length > 1;
    final variantSummary = !hasVariantChoice
        ? ''
        : availableVariantLabels.length == 2
            ? availableVariantLabels.join(' / ')
            : '${availableVariantLabels.take(2).join(' / ')} +${availableVariantLabels.length - 2}';
    final subtitle = <String>[
      countryTitle,
      if (quality != null) quality,
      if (!city.premium) 'Базовый',
      if (selected)
        ...city.variants
            .where((variant) => variant.id == selectedVariantId)
            .map((variant) => variant.label)
            .take(1)
      else if (hasVariantChoice)
        variantSummary,
    ].where((item) => item.trim().isNotEmpty).join(' · ');
    final content = Padding(
      key: ValueKey('locations-catalog-city-${city.code}'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 330;
          final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.2;
          return Row(
            children: [
              _LocationFlagBadge(code: country.code, country: country.country),
              SizedBox(width: compact ? 10 : 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cityTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: p.ink,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      key: ValueKey(
                        'locations-catalog-subtitle-${city.code}',
                      ),
                      maxLines: largeText || hasVariantChoice ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: p.muted,
                            height: 1.25,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      metrics,
                      key: ValueKey('locations-catalog-metrics-${city.code}'),
                      maxLines: largeText ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: p.muted,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: compact ? 4 : 12),
              IconButton(
                key: ValueKey('locations-favorite-${city.code}'),
                tooltip:
                    favorite ? 'Убрать из избранного' : 'Добавить в избранное',
                onPressed: disabled ? null : onFavoriteToggle,
                icon: Icon(
                  favorite ? Icons.star_rounded : Icons.star_border_rounded,
                  color: favorite ? p.reward : p.muted,
                  size: 22,
                ),
              ),
              SizedBox(width: compact ? 4 : 8),
              if (selectionEnabled)
                AnimatedContainer(
                  duration:
                      _MotionScope.of(context).duration(_MotionTokens.short),
                  curve: _MotionTokens.ease,
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: selected ? p.accent : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color:
                          selected ? p.accent : p.ink.withValues(alpha: 0.22),
                    ),
                  ),
                  child: selected
                      ? Icon(
                          Icons.check_rounded,
                          color: Theme.of(context).colorScheme.onPrimary,
                          size: 18,
                        )
                      : null,
                )
              else
                Tooltip(
                  message: 'Список локаций ещё не готов',
                  child: SizedBox(
                    key: ValueKey('locations-selection-locked-${city.code}'),
                    width: 30,
                    height: 30,
                    child: Icon(
                      Icons.lock_outline_rounded,
                      color: p.muted,
                      size: 19,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
    final Widget row;
    if (disabled) {
      // Same "asleep" convention as PokrovListRow: dim, ignore taps, keep
      // the basic cursor while the preference write is in flight.
      row = IgnorePointer(
        child: Opacity(
          opacity: PokrovListRow.disabledOpacity,
          child: MouseRegion(cursor: SystemMouseCursors.basic, child: content),
        ),
      );
    } else if (!selectionEnabled) {
      row = content;
    } else {
      row = PokrovSettingsRowPressSurface(onTap: onTap, child: content);
    }
    final locationTitle = cityTitle;
    return Semantics(
      key: ValueKey('locations-semantics-${city.code}'),
      container: true,
      selected: selected,
      label: 'Локация $locationTitle',
      value: disabled
          ? 'Сохраняется'
          : selectionEnabled
              ? (selected ? 'Выбрано' : 'Не выбрано')
              : 'Выбор недоступен',
      child: row,
    );
  }
}

class _SmartConnectNodeRow extends StatelessWidget {
  const _SmartConnectNodeRow({
    required this.node,
    required this.selected,
    required this.favorite,
    required this.disabled,
    required this.selectionEnabled,
    required this.onTap,
    required this.onFavoriteToggle,
  });

  final SmartConnectNode node;
  final bool selected;
  final bool favorite;
  final bool disabled;
  final bool selectionEnabled;
  final VoidCallback onTap;
  final VoidCallback onFavoriteToggle;

  @override
  Widget build(BuildContext context) {
    final p = PokrovPalette.of(context);
    final city = _smartConnectNodeCity(node);
    final quality = _smartConnectQualityLabel(node);
    final latency = _locationLatencyLabel(node.rankHint.panelLatencyMs);
    final content = Padding(
      key: ValueKey('locations-smart-node-${node.code}'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 330;
          final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.2;
          return Row(
            children: [
              _LocationFlagBadge(
                code: _locationCountryCodeFromNode(node.code, node.country),
                country: node.country,
              ),
              SizedBox(width: compact ? 10 : 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      node.country.trim().isEmpty
                          ? _smartConnectNodeTitle(node)
                          : node.country,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: p.ink,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      city,
                      maxLines: largeText ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: p.muted,
                            height: 1.25,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$quality · $latency',
                      maxLines: largeText ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: selected ? p.accent : p.muted,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: compact ? 4 : 12),
              IconButton(
                key: ValueKey('locations-favorite-${node.code}'),
                tooltip:
                    favorite ? 'Убрать из избранного' : 'Добавить в избранное',
                onPressed: disabled ? null : onFavoriteToggle,
                icon: Icon(
                  favorite ? Icons.star_rounded : Icons.star_border_rounded,
                  color: favorite ? p.reward : p.muted,
                  size: 22,
                ),
              ),
              SizedBox(width: compact ? 4 : 8),
              if (selectionEnabled)
                AnimatedContainer(
                  duration:
                      _MotionScope.of(context).duration(_MotionTokens.short),
                  curve: _MotionTokens.ease,
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: selected ? p.accent : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color:
                          selected ? p.accent : p.ink.withValues(alpha: 0.22),
                    ),
                  ),
                  child: selected
                      ? Icon(
                          Icons.check_rounded,
                          color: Theme.of(context).colorScheme.onPrimary,
                          size: 18,
                        )
                      : null,
                )
              else
                Tooltip(
                  message: 'Список локаций ещё не готов',
                  child: SizedBox(
                    key: ValueKey('locations-selection-locked-${node.code}'),
                    width: 30,
                    height: 30,
                    child: Icon(
                      Icons.lock_outline_rounded,
                      color: p.muted,
                      size: 19,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
    final Widget row;
    if (disabled) {
      // Same "asleep" convention as PokrovListRow: dim, ignore taps, keep
      // the basic cursor while the preference write is in flight.
      row = IgnorePointer(
        child: Opacity(
          opacity: PokrovListRow.disabledOpacity,
          child: MouseRegion(cursor: SystemMouseCursors.basic, child: content),
        ),
      );
    } else if (!selectionEnabled) {
      row = content;
    } else {
      row = PokrovSettingsRowPressSurface(onTap: onTap, child: content);
    }
    return Semantics(
      key: ValueKey('locations-semantics-${node.code}'),
      container: true,
      selected: selected,
      label: 'Локация ${_smartConnectNodeTitle(node)}',
      value: disabled
          ? 'Сохраняется'
          : selectionEnabled
              ? (selected ? 'Выбрано' : 'Не выбрано')
              : 'Выбор недоступен',
      child: row,
    );
  }
}
