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
    return ui.LocationsScreen(
      data: ui.LocationsViewData(
        mode: widget.interfaceMode == PokrovInterfaceMode.advanced
            ? ui.InterfaceMode.advanced : ui.InterfaceMode.simple,
        selectedCode: automatic ? null : widget.preferredCountryCode,
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
    );
  }
}
