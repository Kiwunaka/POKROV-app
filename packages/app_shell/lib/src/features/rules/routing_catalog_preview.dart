part of pokrov_app_shell;

/// Prospective curated layer only. This is neither the effective native policy
/// nor a data-plane health observation; manual/safety/OS scope has precedence.
class _RoutingCatalogPreview {
  _RoutingCatalogPreview({
    required this.catalog,
    required this.policy,
    required this.usingCache,
    required this.checkedAt,
    required List<String> limitations,
  }) : limitations = List.unmodifiable(limitations);

  final RoutingCatalogPolicy catalog;
  final CatalogDomainPolicy policy;
  final bool usingCache;
  final DateTime checkedAt;
  final List<String> limitations;
  late final List<_RoutingCatalogPreviewRow> rows = _rows();

  List<_RoutingCatalogPreviewRow> _rows() {
    // The compiler deduplicates identical domains shared by service entries.
    // Match those entries to its decision instead of inventing another action.
    final decisions = {
      for (final rule in policy.rules) '${rule.domain.suffix}:${rule.domain.name}': rule,
    };
    final selectedNames = <String>{};
    final selectedSuffixes = <String>{};
    final selectedParents = <String>{};
    if (policy.mode == CatalogRoutingMode.selective) {
      for (final rule in policy.rules) {
        selectedNames.add(rule.domain.name);
        if (rule.domain.suffix) selectedSuffixes.add(rule.domain.name);
        selectedParents.addAll(_catalogDomainSuffixes(rule.domain.name));
      }
    }
    return List.unmodifiable(catalog.services.map((service) {
      if (policy.mode == CatalogRoutingMode.selective &&
          !policy.selectedServiceIds.contains(service.id)) {
        final affected = service.domains.any((domain) =>
            selectedNames.contains(domain.name) ||
            _catalogDomainSuffixes(domain.name).any(selectedSuffixes.contains) ||
            (domain.suffix && selectedParents.contains(domain.name)));
        return _RoutingCatalogPreviewRow(service.id, service.displayName,
            affected
                ? 'Не выбран; часть доменов пересекается с выбранными сервисами. Маршрут определяется доменными правилами.'
                : 'Не выбран; по умолчанию напрямую, без защиты VPN.');
      }
      String? unavailable;
      if (!service.enabled) {
        unavailable = 'Правила отключены';
      } else if (!service.verified) {
        unavailable = 'Нет подтверждённых правил';
      } else if (!service.platforms.contains(policy.platform)) {
        unavailable = 'Не поддерживается на этой платформе';
      } else if (!service.accessStates.contains(policy.accessState)) {
        unavailable = 'Недоступен при текущем доступе';
      } else if (service.domains.isEmpty) {
        unavailable = 'Нет доменных правил; приложения выбираются вручную';
      } else if (!service.intents.containsKey(policy.mode) &&
          !(policy.mode == CatalogRoutingMode.smartSafe && service.classification == 'blocked_inside_ru')) {
        unavailable = 'Нет отдельных правил в этом режиме';
      }
      if (unavailable != null) {
        return _RoutingCatalogPreviewRow(service.id, service.displayName, unavailable);
      }
      final rules = service.domains
          .map((domain) => decisions['${domain.suffix}:${domain.name}'])
          .whereType<CatalogDomainDecision>().toList();
      if (rules.isEmpty) {
        return _RoutingCatalogPreviewRow(service.id, service.displayName,
            'Нет отдельных правил в этом режиме');
      }
      final counts = <CatalogRouteAction, int>{};
      for (final rule in rules) {
        counts.update(rule.action, (count) => count + 1, ifAbsent: () => 1);
      }
      const labels = {
        CatalogRouteAction.direct: 'Напрямую',
        CatalogRouteAction.vpn: 'Через VPN при подключении',
        CatalogRouteAction.block: 'Блокировка',
        CatalogRouteAction.approvedGateway: 'Через шлюз сервиса',
      };
      final routes = [
        for (final action in CatalogRouteAction.values)
          if (counts.containsKey(action))
            '${labels[action]}: ${counts[action]}',
      ];
      final fallbacks = rules.map((rule) => rule.fallbackReason).whereType<String>().toSet();
      final fallbackText = [
        if (fallbacks.contains('gateway_unavailable_using_vpn'))
          'Шлюз не подготовлен; выбран запасной маршрут через VPN.',
        if (fallbacks.contains('gateway_unavailable_blocked'))
          'Шлюз и VPN недоступны; прямой обход запрещён.',
        if (fallbacks.contains('vpn_unavailable_blocked'))
          'VPN недоступен; прямой обход запрещён.',
      ].map((message) => '\n$message').join();
      return _RoutingCatalogPreviewRow(service.id, service.displayName,
          '${routes.join(' · ')} · доменных правил: ${rules.length}$fallbackText');
    }));
  }
}

Iterable<String> _catalogDomainSuffixes(String name) sync* {
  var start = 0;
  while (true) {
    yield name.substring(start);
    final dot = name.indexOf('.', start);
    if (dot < 0) return;
    start = dot + 1;
  }
}

class _RoutingCatalogPreviewRow {
  const _RoutingCatalogPreviewRow(this.id, this.name, this.description);
  final String id;
  final String name;
  final String description;
}

class _RoutingCatalogPreviewCard extends StatefulWidget {
  const _RoutingCatalogPreviewCard({super.key, required this.load, required this.routeMode});
  final Future<_RoutingCatalogPreview?> Function() load;
  final RouteMode routeMode;

  @override
  State<_RoutingCatalogPreviewCard> createState() => _RoutingCatalogPreviewCardState();
}

class _RoutingCatalogPreviewCardState extends State<_RoutingCatalogPreviewCard>
    with WidgetsBindingObserver {
  _RoutingCatalogPreview? _preview;
  Timer? _expiryTimer;
  int _generation = 0;
  bool _loading = true;
  bool _expired = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    ++_generation;
    _expiryTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  void _refresh() {
    final generation = ++_generation;
    _expiryTimer?.cancel();
    setState(() {
      _loading = true;
      _preview = null;
      _error = null;
      _expired = false;
    });
    unawaited(_load(generation));
  }

  Future<void> _load(int generation) async {
    try {
      final preview = await widget.load();
      if (!mounted || generation != _generation) return;
      setState(() {
        _preview = preview;
        _loading = false;
      });
      if (preview != null) {
        final remaining = preview.policy.expiresAt.difference(DateTime.now().toUtc());
        _expiryTimer = Timer(remaining.isNegative ? Duration.zero : remaining, () {
          if (mounted && generation == _generation) setState(() => _expired = true);
        });
      }
    } on Object catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        _error = error is RoutingCatalogFailure && error.code == 'catalog_profile_access_invalid'
            ? 'Сначала обновите данные о доступе в профиле.'
            : 'Не удалось получить актуальные правила. Повторите попытку.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    if (!_loading && _error == null && preview == null) return const SizedBox.shrink();
    final now = DateTime.now().toUtc();
    final expired = _expired || (preview != null &&
        (now.isBefore(preview.policy.issuedAt) || !now.isBefore(preview.policy.expiresAt)));
    final current = preview != null && !expired && !_loading && _error == null;
    return _SectionCard(
      key: const ValueKey('rules-catalog-preview'),
      title: 'Правила сервисов',
      lines: [
        if (_loading) 'Загружаем предпросмотр…'
        else if (_error != null) _error!
        else if (expired) 'Срок действия правил истёк. Обновите каталог перед подключением.'
        else if (preview != null) ...[
          'Предпросмотр: ${_routeModeShortLabel(widget.routeMode)}.',
          'Маршруты рассчитаны для рабочего VPN. Этот список не подтверждает текущее подключение.',
          if (preview.usingCache) 'Используется сохранённый каталог с действующей подписью.',
          'Действует до ${_catalogPreviewTime(preview.policy.expiresAt)}.',
          ...preview.limitations,
          'Ручные правила и выбор приложений имеют приоритет. Применение — при следующем подключении.',
        ],
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (current && preview != null) ...[
            Text('Правил каталога: напрямую ${preview.policy.rules.where((rule) => rule.action == CatalogRouteAction.direct).length} · '
                'через VPN ${preview.policy.rules.where((rule) => rule.action == CatalogRouteAction.vpn).length} · '
                'через шлюз ${preview.policy.rules.where((rule) => rule.action == CatalogRouteAction.approvedGateway).length} · '
                'блокировка ${preview.policy.rules.where((rule) => rule.action == CatalogRouteAction.block).length}'),
            ExpansionTile(
              key: const ValueKey('rules-catalog-services'),
              tilePadding: EdgeInsets.zero,
              title: Text('Сервисы каталога (${preview.rows.length})'),
              children: [
                SizedBox(
                  height: math.min(360.0, MediaQuery.sizeOf(context).height * 0.5),
                  child: ListView.separated(
                    key: const ValueKey('rules-catalog-service-list'),
                    itemCount: preview.rows.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final row = preview.rows[index];
                      return ListTile(
                        key: ValueKey('catalog-service-${row.id}'),
                        contentPadding: EdgeInsets.zero,
                        title: Text(row.name),
                        subtitle: Text(row.description),
                      );
                    },
                  ),
                ),
                Text('Версия каталога ${preview.policy.revision}. '
                    'Подпись проверена ${_catalogPreviewTime(preview.checkedAt)}. '
                    'Доступность сервисов здесь не проверяется.',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ],
          TextButton.icon(
            onPressed: _loading ? null : _refresh,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Обновить правила'),
          ),
        ],
      ),
    );
  }
}

String _catalogPreviewTime(DateTime value) {
  final local = value.toLocal();
  String two(int part) => part.toString().padLeft(2, '0');
  return '${two(local.day)}.${two(local.month)}.${local.year} ${two(local.hour)}:${two(local.minute)}';
}
