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
    required this.onRefreshLocationsCatalog,
    required this.preferredNodeCode,
    required this.nodePreferenceBusy,
    required this.onPreferredNodeSelected,
  });

  final SeedAppContext appContext;
  final RouteMode selectedRouteMode;
  final bool hasProvisionedAccess;
  final SmartConnectProfile? smartConnectProfile;
  final ClientLocationsCatalog? locationsCatalog;
  final bool locationsCatalogBusy;
  final String? locationsCatalogError;
  final VoidCallback onRefreshLocationsCatalog;
  final String preferredNodeCode;
  final bool nodePreferenceBusy;
  final ValueChanged<String> onPreferredNodeSelected;

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
    final filtered = hasShortlist
        ? shortlist.where(_matches).toList(growable: false)
        : const <SmartConnectNode>[];
    final locationCount = hasCatalog ? catalogEntries.length : shortlist.length;

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
          enabled: widget.hasProvisionedAccess,
          title: 'Автоматически',
          subtitle: widget.hasProvisionedAccess
              ? 'POKROV выберет быстрый маршрут. $premiumPool · ${_routeModeShortLabel(widget.selectedRouteMode)}'
              : 'Сначала включите POKROV VPN',
          value: widget.preferredNodeCode.trim().isEmpty ? 'Авто' : 'Выбрано',
          busy:
              widget.nodePreferenceBusy ||
              (widget.locationsCatalogBusy && hasList),
          onTap: () => _showInfoSheet(
            context,
            title: 'Автоматически',
            lines: [
              'POKROV сам выбирает страну и старается держать быстрый маршрут.',
              'Если выбрать страну ниже, она станет предпочтительной после переподключения.',
            ],
          ),
        ),
        if (!widget.locationsCatalogBusy &&
            widget.hasProvisionedAccess &&
            (widget.locationsCatalogError ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 14),
          _SectionCard(
            key: const ValueKey('locations-catalog-error'),
            title: 'Список стран не обновился',
            tone: _SectionTone.muted,
            lines: const [
              'Не удалось загрузить свежие данные. Проверьте подключение к интернету и повторите.',
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
          _SectionCard(
            title: 'Премиум-локации',
            lines: const [],
            child: filteredCatalog.isEmpty
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
                    children: filteredCatalog
                        .map(
                          (entry) => _ClientLocationCityRow(
                            entry: entry,
                            selected:
                                entry.city.code.trim().toLowerCase() ==
                                widget.preferredNodeCode.trim().toLowerCase(),
                            disabled: widget.nodePreferenceBusy,
                            onTap: () =>
                                widget.onPreferredNodeSelected(entry.city.code),
                          ),
                        )
                        .toList(growable: false),
                  ),
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
                            selected:
                                node.code.trim().toLowerCase() ==
                                widget.preferredNodeCode.trim().toLowerCase(),
                            disabled: widget.nodePreferenceBusy,
                            onTap: () =>
                                widget.onPreferredNodeSelected(node.code),
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

class _AutoLocationCard extends StatelessWidget {
  const _AutoLocationCard({
    super.key,
    required this.enabled,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.busy,
    required this.onTap,
  });

  final bool enabled;
  final String title;
  final String subtitle;
  final String value;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = PokrovPalette.of(context);
    final content = Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: enabled ? p.accent.withValues(alpha: 0.06) : p.surfaceMuted,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: enabled ? p.accent.withValues(alpha: 0.16) : p.line,
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
                  color: p.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  Icons.travel_explore_rounded,
                  color: p.accent,
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
                icon: enabled
                    ? Icons.check_circle_outline_rounded
                    : Icons.hourglass_empty_rounded,
                tone: enabled ? _SectionTone.accent : _SectionTone.muted,
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
    required this.disabled,
    required this.onTap,
  });

  final _ClientLocationEntry entry;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = PokrovPalette.of(context);
    final city = entry.city;
    final country = entry.country;
    final quality = _locationQualityLabel(city.healthScore);
    final subtitle = <String>[
      country.country,
      quality,
      city.premium ? 'Premium' : 'Free',
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
              ],
            ),
          ),
          const SizedBox(width: 12),
          _SignalBars(score: city.healthScore),
          const SizedBox(width: 14),
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
          ),
        ],
      ),
    );
    if (disabled) {
      // Same "asleep" convention as PokrovListRow: dim, ignore taps, keep
      // the basic cursor while the preference write is in flight.
      return IgnorePointer(
        child: Opacity(
          opacity: PokrovListRow.disabledOpacity,
          child: MouseRegion(cursor: SystemMouseCursors.basic, child: content),
        ),
      );
    }
    return PokrovSettingsRowPressSurface(onTap: onTap, child: content);
  }
}

class _SmartConnectNodeRow extends StatelessWidget {
  const _SmartConnectNodeRow({
    required this.node,
    required this.selected,
    required this.disabled,
    required this.onTap,
  });

  final SmartConnectNode node;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = PokrovPalette.of(context);
    final city = _smartConnectNodeCity(node);
    final quality = _smartConnectQualityLabel(node);
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
                  quality,
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
          _SignalBars(score: node.rankHint.healthScore),
          const SizedBox(width: 14),
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
          ),
        ],
      ),
    );
    if (disabled) {
      // Same "asleep" convention as PokrovListRow: dim, ignore taps, keep
      // the basic cursor while the preference write is in flight.
      return IgnorePointer(
        child: Opacity(
          opacity: PokrovListRow.disabledOpacity,
          child: MouseRegion(cursor: SystemMouseCursors.basic, child: content),
        ),
      );
    }
    return PokrovSettingsRowPressSurface(onTap: onTap, child: content);
  }
}
