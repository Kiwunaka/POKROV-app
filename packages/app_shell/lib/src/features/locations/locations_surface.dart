part of pokrov_app_shell;

class _LocationsSection extends StatelessWidget {
  const _LocationsSection({
    required this.appContext,
    required this.selectedRouteMode,
    required this.hasProvisionedAccess,
    required this.smartConnectProfile,
    required this.preferredNodeCode,
    required this.nodePreferenceBusy,
    required this.onPreferredNodeSelected,
  });

  final SeedAppContext appContext;
  final RouteMode selectedRouteMode;
  final bool hasProvisionedAccess;
  final SmartConnectProfile? smartConnectProfile;
  final String preferredNodeCode;
  final bool nodePreferenceBusy;
  final ValueChanged<String> onPreferredNodeSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final smartConnect = smartConnectProfile;
    final shortlist = smartConnect?.shortlist ?? const <SmartConnectNode>[];
    final premiumPool = _accessPoolLabel(appContext.accessLane);

    return _SeedContentList(
      children: [
        Text('Локации', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 14),
        const _LocationSearchField(),
        const SizedBox(height: 14),
        _AutoLocationCard(
          key: const ValueKey('locations-auto-section'),
          enabled: hasProvisionedAccess,
          title: 'Автоматический выбор',
          subtitle: hasProvisionedAccess
              ? '$premiumPool · ${_routeModeShortLabel(selectedRouteMode)}'
              : 'Появится после подготовки доступа',
          value: preferredNodeCode.trim().isEmpty
              ? 'Авто'
              : preferredNodeCode.trim().toUpperCase(),
          busy: nodePreferenceBusy,
          onTap: () => _showInfoSheet(
            context,
            title: 'Автоматически',
            lines: [
              'POKROV сам выбирает доступный сервер и старается держать быстрый маршрут.',
              'Если выбрать страну ниже, она станет предпочтительной после переподключения.',
            ],
          ),
        ),
        if (hasProvisionedAccess && shortlist.isNotEmpty) ...[
          _SectionCard(
            title: 'Премиум-локации',
            lines: const [],
            child: Column(
              children: shortlist
                  .map(
                    (node) => _SmartConnectNodeRow(
                      node: node,
                      selected: node.code.trim().toLowerCase() ==
                          preferredNodeCode.trim().toLowerCase(),
                      disabled: nodePreferenceBusy,
                      onTap: () => onPreferredNodeSelected(node.code),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        ] else if (hasProvisionedAccess) ...[
          _SectionCard(
            title: 'Выбор сервера',
            tone: _SectionTone.muted,
            lines: const [
              'Пока доступен автоматический выбор. Список стран появится после обновления профиля.',
            ],
          ),
        ] else ...[
          const _MotionSkeletonList(
            key: ValueKey('locations-skeleton-list'),
            rows: 4,
          ),
          _SectionCard(
            title: 'Появится после подготовки',
            lines: [
              'Нажмите «Подключить» на главном экране.',
            ],
          ),
        ],
      ],
    );
  }
}

class _LocationSearchField extends StatelessWidget {
  const _LocationSearchField();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _SeedPalette.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _SeedPalette.line),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: _SeedPalette.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Поиск по странам и городам',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: _SeedPalette.muted.withValues(alpha: 0.78),
                  ),
            ),
          ),
        ],
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
    final content = Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: enabled
            ? _SeedPalette.accent.withValues(alpha: 0.06)
            : _SeedPalette.surfaceMuted,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: enabled
              ? _SeedPalette.accent.withValues(alpha: 0.16)
              : _SeedPalette.line,
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
                  color: _SeedPalette.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(
                  Icons.travel_explore_rounded,
                  color: _SeedPalette.accent,
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
                            color: _SeedPalette.ink,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: _SeedPalette.muted,
                            height: 1.25,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _StatusPill(
                label: value,
                icon: enabled
                    ? Icons.check_circle_outline_rounded
                    : Icons.hourglass_empty_rounded,
                tone: enabled ? _SectionTone.accent : _SectionTone.muted,
              ),
            ],
          ),
          if (busy) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(minHeight: 3),
          ],
        ],
      ),
    );
    return KeyedSubtree(
      key: const ValueKey('locations-auto-help-action'),
      child: PokrovSettingsRowPressSurface(onTap: onTap, child: content),
    );
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
    final latency = node.rankHint.panelLatencyMs;
    final city = _smartConnectNodeCity(node);
    final subtitle = latency == null || latency <= 0
        ? 'Хорошее соединение'
        : latency < 100
            ? 'Отличное соединение'
            : 'Стабильное соединение';
    final content = Padding(
      key: ValueKey('locations-smart-node-${node.code}'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          _LocationFlagBadge(code: node.code, country: node.country),
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
                        color: _SeedPalette.ink,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  city,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _SeedPalette.muted,
                        height: 1.25,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color:
                            selected ? _SeedPalette.accent : _SeedPalette.muted,
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
              color: selected ? _SeedPalette.accent : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected
                    ? _SeedPalette.accent
                    : _SeedPalette.ink.withValues(alpha: 0.22),
              ),
            ),
            child: selected
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                : null,
          ),
        ],
      ),
    );
    if (disabled) {
      return content;
    }
    return PokrovSettingsRowPressSurface(
      onTap: onTap,
      child: content,
    );
  }
}
