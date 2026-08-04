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
    required this.nodePreferenceBusy,
    required this.onAutomaticLocationSelected,
    required this.onPreferredNodeSelected,
    required this.favoriteNodeCodes,
    required this.recentNodeCodes,
    required this.onFavoriteNodeToggle,
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
  final bool nodePreferenceBusy;
  final VoidCallback onAutomaticLocationSelected;
  final ValueChanged<String> onPreferredNodeSelected;
  final List<String> favoriteNodeCodes;
  final List<String> recentNodeCodes;
  final ValueChanged<String> onFavoriteNodeToggle;

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
                      favorite: widget.favoriteNodeCodes.contains(
                        entry.city.code.trim().toLowerCase(),
                      ),
                      disabled: widget.nodePreferenceBusy,
                      selectionEnabled:
                          _canSelectLocation && !widget.nodePreferenceBusy,
                      onTap: () =>
                          widget.onPreferredNodeSelected(entry.city.code),
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
    final premiumPool = _accessPoolLabel(widget.appContext.accessLane);
    final hasCatalog = catalogEntries.isNotEmpty;
    final hasShortlist = widget.hasProvisionedAccess && shortlist.isNotEmpty;
    final hasList = hasCatalog || hasShortlist;
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
        Text('Локации', style: theme.textTheme.headlineSmall),
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
              'POKROV выберет быстрый маршрут. $premiumPool · ${_routeModeShortLabel(widget.selectedRouteMode)}',
            _AutoLocationStatus.manual =>
              'Выбрана локация вручную. Нажмите, чтобы вернуть автоматический выбор.',
            _AutoLocationStatus.unavailable => 'Сначала включите POKROV VPN',
          },
          value: switch (autoStatus) {
            _AutoLocationStatus.active => 'Авто',
            _AutoLocationStatus.manual => 'Вручную',
            _AutoLocationStatus.unavailable => 'Недоступно',
          },
          status: autoStatus,
          busy: widget.nodePreferenceBusy ||
              (widget.locationsCatalogBusy && hasList),
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
                            onTap: () =>
                                widget.onPreferredNodeSelected(node.code),
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
    required this.busy,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String value;
  final _AutoLocationStatus status;
  final bool busy;
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
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color:
                      isActive ? p.accent.withValues(alpha: 0.12) : p.surface,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  isUnavailable
                      ? Icons.lock_outline_rounded
                      : Icons.travel_explore_rounded,
                  color: isActive ? p.accent : p.muted,
                  size: 27,
                ),
              ),
              const SizedBox(width: 14),
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
              const SizedBox(width: 12),
              if (busy) ...[
                // Quiet refresh signal beside the status pill — indeterminate
                // Material bars read as foreign in this shell.
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CupertinoActivityIndicator(radius: 8),
                ),
                const SizedBox(width: 10),
              ],
              _StatusPill(
                label: value,
                icon: statusIcon,
                tone: statusTone,
              ),
            ],
          ),
        ],
      ),
    );
    return KeyedSubtree(
      key: const ValueKey('locations-auto-help-action'),
      child: PokrovSettingsRowPressSurface(onTap: onTap, child: content),
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
    required this.favorite,
    required this.disabled,
    required this.selectionEnabled,
    required this.onTap,
    required this.onFavoriteToggle,
  });

  final _ClientLocationEntry entry;
  final bool selected;
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
      freshness: freshness,
    );
    final subtitle = <String>[
      country.country,
      if (quality != null) quality,
      city.premium ? 'Премиум' : 'Базовый',
    ].where((item) => item.trim().isNotEmpty).join(' · ');
    final content = Padding(
      key: ValueKey('locations-catalog-city-${city.code}'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          _LocationFlagBadge(code: country.code, country: country.country),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  city.city.trim().isEmpty ? country.country : city.city,
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: p.muted, height: 1.25),
                ),
                const SizedBox(height: 2),
                Text(
                  metrics,
                  key: ValueKey('locations-catalog-metrics-${city.code}'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: p.muted,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            key: ValueKey('locations-favorite-${city.code}'),
            tooltip: favorite ? 'Убрать из избранного' : 'Добавить в избранное',
            onPressed: disabled ? null : onFavoriteToggle,
            icon: Icon(
              favorite ? Icons.star_rounded : Icons.star_border_rounded,
              color: favorite ? p.reward : p.muted,
              size: 22,
            ),
          ),
          _SignalBars(
            key: ValueKey('locations-signal-${city.code}'),
            score: city.healthScore,
            verified: freshness == _LocationMetricFreshness.current,
          ),
          const SizedBox(width: 14),
          if (selectionEnabled)
            AnimatedContainer(
              duration: _MotionScope.of(context).duration(_MotionTokens.short),
              curve: _MotionTokens.ease,
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: selected ? p.accent : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? p.accent : p.ink.withValues(alpha: 0.22),
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
    final locationTitle =
        city.city.trim().isEmpty ? country.country : city.city;
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
      child: Row(
        children: [
          _LocationFlagBadge(code: node.country, country: node.country),
          const SizedBox(width: 14),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: p.muted, height: 1.25),
                ),
                const SizedBox(height: 2),
                Text(
                  '$quality · $latency',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: selected ? p.accent : p.muted,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            key: ValueKey('locations-favorite-${node.code}'),
            tooltip: favorite ? 'Убрать из избранного' : 'Добавить в избранное',
            onPressed: disabled ? null : onFavoriteToggle,
            icon: Icon(
              favorite ? Icons.star_rounded : Icons.star_border_rounded,
              color: favorite ? p.reward : p.muted,
              size: 22,
            ),
          ),
          _SignalBars(
            key: ValueKey('locations-signal-${node.code}'),
            score: node.rankHint.healthScore,
          ),
          const SizedBox(width: 14),
          if (selectionEnabled)
            AnimatedContainer(
              duration: _MotionScope.of(context).duration(_MotionTokens.short),
              curve: _MotionTokens.ease,
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: selected ? p.accent : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? p.accent : p.ink.withValues(alpha: 0.22),
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
