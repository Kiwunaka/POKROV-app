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
  domain.TransportCandidate? get _preferredCandidate => widget.transportCatalog?.candidates
      .where((candidate) => candidate.candidateRef == widget.preferredCandidateRef).firstOrNull;

  String get _selectedCountryCode => _preferredCandidate?.nodeCountryCode(widget.transportCatalog!.candidates)
      ?? widget.preferredCountryCode;

  String _candidateLocation(domain.TransportCandidate candidate) {
    for (final country in widget.locationsCatalog?.countries ?? const <ClientLocationCountry>[]) {
      for (final city in country.cities) {
        if (city.code == candidate.nodeCode) return _locationCityDisplayName(city, country);
      }
    }
    return _locationCountryDisplayName(candidate.countryCode, candidate.countryCode);
  }

  Future<void> _selectConnection() async {
    if (widget.nodePreferenceBusy) return;
    final catalog = widget.transportCatalog!;
    final countryCode = _selectedCountryCode;
    final countries = <String, List<domain.TransportCandidate>>{};
    for (final candidate in catalog.candidates) {
      final code = candidate.nodeCountryCode(catalog.candidates);
      if (countryCode.isEmpty || code == countryCode) {
        (countries[code] ??= []).add(candidate);
      }
    }
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Выбрать соединение', style: Theme.of(context).textTheme.titleLarge),
                ListTile(
                  key: const ValueKey('location-candidate-auto'),
                  leading: const Icon(Icons.bolt_rounded),
                  title: const Text('Авто'),
                  subtitle: const Text('POKROV подберёт рабочее соединение'),
                  onTap: () => Navigator.of(context).pop(''),
                ),
                for (final country in countries.entries) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 4),
                    child: Text(_locationCountryDisplayName(country.key, country.key),
                      style: Theme.of(context).textTheme.titleMedium),
                  ),
                  for (final candidate in country.value) ListTile(
                    key: ValueKey('location-candidate-${candidate.candidateRef}'),
                    title: Text(_locationCandidateLabel(candidate)),
                    subtitle: candidate.displayName == null ? Text(_candidateLocation(candidate)) : null,
                    trailing: candidate.candidateRef == widget.preferredCandidateRef
                        ? const Icon(Icons.check_rounded) : null,
                    onTap: () => Navigator.of(context).pop(candidate.candidateRef),
                  ),
                ],
                if (countries.isEmpty) const Text('Для этой страны пока нет доступных соединений в каталоге.'),
              ],
            ),
          ),
        ),
      ),
    );
    if (selected == null || !mounted) return;
    if (selected.isEmpty) {
      widget.onAutomaticLocationSelected();
    } else {
      widget.onPreferredCandidateSelected(selected);
    }
  }

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
    return ui.LocationsScreen(
      data: ui.LocationsViewData(
        mode: widget.interfaceMode == PokrovInterfaceMode.advanced
            ? ui.InterfaceMode.advanced : ui.InterfaceMode.simple,
        selectedCode: automatic ? null : _selectedCountryCode,
        countries: [for (final country in countries.entries) ui.CountryOption(
          code: country.key, name: country.value.$1,
          available: !widget.nodePreferenceBusy && country.value.$2,
        )],
        notice: widget.locationsCatalogBusy ? 'Загружаем страны…'
            : (widget.locationsCatalogError ?? '').isNotEmpty
                ? 'Список не обновился. Показываем сохранённые страны.'
                : countries.isEmpty ? 'Пока доступен автоматический выбор.' : null,
      ),
      onAuto: widget.nodePreferenceBusy ? null : widget.onAutomaticLocationSelected,
      onSelect: widget.onPreferredCountrySelected,
      onRefresh: widget.locationsCatalogBusy ? null : widget.onRefreshLocationsCatalog,
      onSelectConnection: widget.interfaceMode == PokrovInterfaceMode.advanced &&
              (widget.transportCatalog?.candidates.isNotEmpty ?? false) ? _selectConnection : null,
      selectedConnectionLabel: _preferredCandidate == null ? null : _locationCandidateLabel(_preferredCandidate!),
    );
  }
}
