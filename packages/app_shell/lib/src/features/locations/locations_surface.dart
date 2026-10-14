part of pokrov_app_shell;

class _LocationsSection extends StatefulWidget {
  const _LocationsSection({
    required this.appContext,
    required this.interfaceMode,
    required this.preferredCountryCode,
    required this.preferredCandidateRef,
    required this.transportCatalog,
    required this.onPreferredCountrySelected,
    required this.onPreferredCandidateSelected,
    required this.selectedRouteMode,
    required this.hasProvisionedAccess,
    required this.smartConnectProfile,
    required this.hasOrdinaryTransportCatalog,
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
  });

  final SeedAppContext appContext;
  final PokrovInterfaceMode interfaceMode;
  final String preferredCountryCode;
  final String preferredCandidateRef;
  final TransportCandidateCatalog? transportCatalog;
  final ValueChanged<String> onPreferredCountrySelected;
  final ValueChanged<String> onPreferredCandidateSelected;
  final RouteMode selectedRouteMode;
  final bool hasProvisionedAccess;
  final SmartConnectProfile? smartConnectProfile;
  final bool hasOrdinaryTransportCatalog;
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

  @override
  State<_LocationsSection> createState() => _LocationsSectionState();
}

class _LocationsSectionState extends State<_LocationsSection> {
  @override
  Widget build(BuildContext context) {
    final countries = <String, (String, bool)>{};
    for (final country in widget.locationsCatalog?.countries ??
        const <ClientLocationCountry>[]) {
      countries[country.code.toUpperCase()] = (
        _locationCountryDisplayName(country.code, country.country),
        country.cities.any((city) =>
            city.variants.isEmpty ||
            city.variants.any((variant) => variant.available)),
      );
    }
    if (countries.isEmpty) {
      for (final node in widget.smartConnectProfile?.shortlist ??
          const <SmartConnectNode>[]) {
        final code = _locationCountryCodeFromNode(node.code, node.country);
        if (code.isNotEmpty) {
          countries[code] =
              (_locationCountryDisplayName(code, node.country), true);
        }
      }
    }
    final automatic = widget.preferredCountryCode.isEmpty &&
        widget.preferredNodeCode.isEmpty && widget.preferredCandidateRef.isEmpty;
    return _SeedContentList(
      children: [
        Text('Страна', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 14),
        _AutoLocationCard(
          key: const ValueKey('locations-auto-section'),
          title: 'Автоматически',
          subtitle: 'POKROV подберёт рабочее соединение.',
          value: automatic ? 'Авто' : 'Выбрать',
          status: !widget.hasProvisionedAccess
              ? _AutoLocationStatus.unavailable
              : automatic
                  ? _AutoLocationStatus.active
                  : _AutoLocationStatus.manual,
          onTap: widget.nodePreferenceBusy
              ? () {}
              : widget.onAutomaticLocationSelected,
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: 'Выбор страны',
          lines: const [
            'Выберите страну выхода в интернет. Способ подключения POKROV выберет сам.',
          ],
          child: Column(
            children: [
              for (final country in countries.entries)
                ListTile(
                  key: ValueKey('locations-country-${country.key}'),
                  leading: _LocationFlagBadge(
                      code: country.key, country: country.value.$1),
                  title: Text(country.value.$1),
                  trailing: country.key == widget.preferredCountryCode
                      ? const Icon(Icons.check_rounded)
                      : null,
                  enabled: !widget.nodePreferenceBusy && country.value.$2,
                  onTap: () => widget.onPreferredCountrySelected(country.key),
                ),
              if (countries.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(widget.locationsCatalogBusy
                      ? 'Загружаем страны…'
                      : 'Пока доступен автоматический выбор.'),
                ),
              if ((widget.locationsCatalogError ?? '').isNotEmpty)
                const Text(
                    'Список стран не обновился. Показываем сохранённые данные.'),
              TextButton.icon(
                key: const ValueKey('locations-refresh-measurements'),
                onPressed: widget.locationsCatalogBusy
                    ? null
                    : widget.onRefreshLocationsCatalog,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Обновить страны'),
              ),
            ],
          ),
        ),
      ],
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
