part of pokrov_app_shell;

class _CatalogServiceSelectionData {
  const _CatalogServiceSelectionData({required this.catalog, required this.platform,
    required this.accessState, required this.profileRevision, required this.nativeWindowVersion,
    this.runtime, this.runtimeObservedAt, this.runtimeIsCurrent, this.runtimeInvalidated,
    this.smartAccessEnabled = false, this.providerPolicy, this.providerPolicyObservedAt,
    this.metadataIsCurrent});
  final RoutingCatalogPolicy catalog;
  final String platform;
  final String accessState;
  final int profileRevision;
  final int nativeWindowVersion;
  final RuntimeSmartAccessLeaseState? runtime;
  final DateTime? runtimeObservedAt;
  final bool Function()? runtimeIsCurrent;
  final Future<void>? runtimeInvalidated;
  final bool smartAccessEnabled;
  final VerifiedSmartAccessProviderPolicy? providerPolicy;
  final DateTime? providerPolicyObservedAt;
  final bool Function()? metadataIsCurrent;

  bool get providerMetadataCurrent {
    final policy = providerPolicy;
    final now = DateTime.now().toUtc();
    return policy != null && metadataIsCurrent?.call() == true &&
      !now.isBefore(policy.issuedAt) && now.isBefore(policy.expiresAt) &&
      !now.isBefore(catalog.catalog.issuedAt) && now.isBefore(catalog.catalog.expiresAt);
  }

  List<Map<String, Object?>> capabilitiesFor(CatalogServicePolicy service) =>
    ((providerPolicy?.payload['capabilities'] as List?) ?? const [])
      .cast<Map<String, Object?>>()
      .where((row) => row['service_id'] == service.id && service.providerCapabilityRefs.contains(row['capability_id']))
      .toList();

  // One existing view timer covers expiry and not-yet-valid assertions. No probe
  // or automatic fetch is started when a metadata boundary is crossed.
  DateTime? nextMetadataBoundary(DateTime now) {
    final dates = <DateTime>[catalog.catalog.issuedAt, catalog.catalog.expiresAt];
    final policy = providerPolicy;
    if (policy != null) {
      dates.addAll([policy.issuedAt, policy.expiresAt]);
      for (final collection in ['permissions', 'capabilities']) {
        for (final row in (policy.payload[collection]! as List).cast<Map<String, Object?>>()) {
          dates.add(DateTime.parse(row[collection == 'permissions' ? 'issued_at' : 'observed_at']! as String));
          dates.add(DateTime.parse(row['expires_at']! as String));
        }
      }
    }
    final pending = dates.where((date) => date.isAfter(now)).toList()..sort();
    return pending.isEmpty ? null : pending.first;
  }

  String runtimeDescription(String serviceId) {
    if (runtimeIsCurrent?.call() != true) return 'Текущий маршрут не подтверждён.';
    final selection = runtime?.selections[serviceId];
    if (selection == null) return 'Данных о выборе шлюза Smart Access нет.';
    if (selection.state == 'pending') return 'Шлюз ещё не выбирался для трафика сервиса.';
    if (selection.state == 'unavailable') return 'При последнем выборе шлюз был недоступен; резервный путь задают правила.';
    if (!selection.available) return 'Выбранный шлюз сейчас не принимает новые соединения.';
    return selection.selectionIndex == 0 ? 'Выбран основной шлюз Smart Access.' : 'Выбран резервный шлюз Smart Access.';
  }

  String? unavailableReason(CatalogServicePolicy service) {
    if (!service.enabled || !service.verified) return 'Нет действующих подтверждённых правил';
    if (!service.platforms.contains(platform)) return 'Не поддерживается на этой платформе';
    if (!service.accessStates.contains(accessState)) return 'Недоступен при текущем доступе';
    if (service.domains.isEmpty || service.domains.any((domain) => domain.shared)) {
      return 'Нет отдельного поддерживаемого доменного маршрута';
    }
    final action = service.intents[CatalogRoutingMode.selective];
    if (action == null || action == CatalogRouteAction.direct) return 'Не поддерживает этот режим';
    return null;
  }

  CatalogDomainPolicy compile(Set<String> selected) => compileCatalogDomainPolicy(
    policy: catalog, mode: CatalogRoutingMode.selective, platform: platform,
    accessState: accessState, vpnAvailable: true, selectedServiceIds: selected,
    now: DateTime.now().toUtc());
}

class _CatalogServiceSelectionSheet extends StatefulWidget {
  const _CatalogServiceSelectionSheet({required this.initialSelection,
    required this.load, required this.onSave, required this.runtimeChanges});
  final Set<String> initialSelection;
  final Future<_CatalogServiceSelectionData> Function({required bool Function() isCurrent,
    required Future<void> cancelled}) load;
  final bool Function(_CatalogServiceSelectionData, Set<String>) onSave;
  final Listenable runtimeChanges;

  @override
  State<_CatalogServiceSelectionSheet> createState() => _CatalogServiceSelectionSheetState();
}

class _CatalogServiceSelectionSheetState extends State<_CatalogServiceSelectionSheet>
    with WidgetsBindingObserver {
  late final Set<String> _selected = {...widget.initialSelection};
  _CatalogServiceSelectionData? _data;
  String? _error;
  bool _saving = false;
  int _generation = 0;
  Timer? _expiry;
  Completer<void> _cancelled = Completer<void>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    ++_generation;
    if (!_cancelled.isCompleted) _cancelled.complete();
    _expiry?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  void _refresh() {
    final generation = ++_generation;
    if (!_cancelled.isCompleted) _cancelled.complete();
    _cancelled = Completer<void>();
    _expiry?.cancel();
    setState(() { _data = null; _error = null; _saving = false; });
    unawaited(_load(generation));
  }

  Future<void> _load(int generation) async {
    try {
      final data = await widget.load(isCurrent: () => mounted && generation == _generation,
        cancelled: _cancelled.future);
      if (!mounted || generation != _generation) return;
      setState(() => _data = data);
      final invalidated = data.runtimeInvalidated;
      if (invalidated != null) {
        unawaited(invalidated.then((_) {
          if (mounted && generation == _generation) setState(() {});
        }));
      }
      _scheduleMetadataBoundary(data, generation);
    } on Object {
      if (mounted && generation == _generation) {
        setState(() => _error = 'Не удалось обновить каталог. Повторите попытку.');
      }
    }
  }

  void _scheduleMetadataBoundary(_CatalogServiceSelectionData data, int generation) {
    _expiry?.cancel();
    final now = DateTime.now().toUtc();
    final next = data.nextMetadataBoundary(now);
    if (next == null) return;
    _expiry = Timer(next.difference(now), () {
      if (!mounted || generation != _generation) return;
      setState(() {});
      _scheduleMetadataBoundary(data, generation);
    });
  }

  Future<void> _save() async {
    final viewed = _data;
    if (viewed == null || _saving) return;
    final generation = ++_generation;
    if (!_cancelled.isCompleted) _cancelled.complete();
    _cancelled = Completer<void>();
    _scheduleMetadataBoundary(viewed, generation);
    final selected = Set<String>.unmodifiable(_selected);
    setState(() { _saving = true; _error = null; });
    try {
      // Re-read through the authenticated catalog owner before accepting the
      // draft. Closing/resuming the sheet invalidates this in-flight save.
      final current = await widget.load(isCurrent: () => mounted && generation == _generation,
        cancelled: _cancelled.future);
      if (!mounted || generation != _generation) return;
      if (current.catalog.catalog.payloadSha256 != viewed.catalog.catalog.payloadSha256 ||
          current.profileRevision != viewed.profileRevision ||
          current.accessState != viewed.accessState) {
        setState(() => _error = 'Правила или настройки изменились. Обновите список и проверьте выбор.');
        return;
      }
      current.compile(selected);
      if (!widget.onSave(current, selected)) {
        setState(() => _error = 'Сохранение недоступно. Обновите список и проверьте поддержку режима.');
        return;
      }
      Navigator.of(context).pop();
    } on Object {
      if (mounted && generation == _generation) {
        setState(() => _error = 'Выбор не сохранён. Проверьте доступность сервисов и обновите каталог.');
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: widget.runtimeChanges,
    builder: (context, _) => _buildContents(context));

  Widget _buildContents(BuildContext context) {
    final data = _data;
    CatalogDomainPolicy? compiled;
    if (data != null && _selected.isNotEmpty) {
      try { compiled = data.compile(_selected); } on RoutingCatalogFailure { /* Shown below. */ }
    }
    final services = data?.catalog.services ?? const <CatalogServicePolicy>[];
    final known = services.map((service) => service.id).toSet();
    final missing = _selected.where((id) => !known.contains(id)).toList()..sort();
    final preview = compiled == null || data == null ? null : _RoutingCatalogPreview(
      catalog: data.catalog, policy: compiled, usingCache: false,
      checkedAt: DateTime.now().toUtc(), limitations: const []);
    final descriptions = {for (final row in preview?.rows ?? const <_RoutingCatalogPreviewRow>[]) row.id: row.description};
    final validNow = data != null && !DateTime.now().toUtc().isBefore(data.catalog.catalog.issuedAt) &&
        DateTime.now().toUtc().isBefore(data.catalog.catalog.expiresAt);
    return PopScope<void>(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          ++_generation; _expiry?.cancel();
          if (!_cancelled.isCompleted) _cancelled.complete();
        }
      },
      child: SafeArea(top: false, child: Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(height: MediaQuery.sizeOf(context).height * 0.78, child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: CustomScrollView(slivers: [
            SliverToBoxAdapter(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Выбранные сервисы', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text('Защищённый маршрут только для выбранных сервисов. Остальной трафик идёт напрямую — это не защита всего устройства.'),
          const SizedBox(height: 8),
          const Text('Шлюз выбранного сервиса может видеть IP-адрес, домен, время и объём соединения. Содержимое корректного HTTPS он не расшифровывает.'),
          const SizedBox(height: 8),
          const Text('Выбор сохранится для следующего подключения. Текущее соединение останется без изменений. Ручные правила имеют приоритет.'),
          if (data?.runtimeObservedAt != null) ...[
            const SizedBox(height: 8),
            Text('Выбор шлюза на ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(data!.runtimeObservedAt!.toLocal()))}. Обновите список, чтобы прочитать состояние снова.'),
            const Text('Доступность сайта здесь не проверяется. При переключении старые соединения сохраняют прежний шлюз.'),
          ],
          if (_error != null) Text(_error!),
          if (data != null && !validNow) const Text('Срок действия каталога истёк. Обновите список.'),
          if (data != null && data.nativeWindowVersion != 1)
            const Text('Поддержка каталога модулем подключения пока не подтверждена. Без неё подключение недоступно.'),
          if (data != null && _selected.isNotEmpty && compiled == null && validNow)
            const Text('В выборе есть недоступные или конфликтующие правила. Уберите их перед сохранением.'),
          Row(children: [
            Expanded(child: Text('Выбрано: ${_selected.length}')),
            TextButton(onPressed: _saving ? null : _refresh, child: const Text('Обновить')),
          ]),
            ])),
          if (data == null)
            SliverFillRemaining(hasScrollBody: false, child:
              Center(child: _error == null ? const CircularProgressIndicator() : const Text('Каталог недоступен')))
          else
            SliverList(delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final service = index < services.length ? services[index] : null;
                  final id = service?.id ?? missing[index - services.length];
                  final unavailable = service == null ? 'Сервис удалён из каталога' : data.unavailableReason(service);
                  final chosen = _selected.contains(id);
                  return Column(children: [CheckboxListTile(
                    key: ValueKey('selective-service-$id'), contentPadding: EdgeInsets.zero,
                    title: Text(service?.displayName ?? 'Недоступный сервис'),
                    subtitle: Text('${unavailable ?? descriptions[id] ?? 'Можно выбрать для защищённого маршрута'}\n${data.runtimeDescription(id)}'),
                    value: chosen,
                    onChanged: _saving || (!chosen && unavailable != null) ? null : (value) {
                      setState(() { if (value == true) { _selected.add(id); } else { _selected.remove(id); } _error = null; });
                    },
                  ),
                    if (service != null && data.smartAccessEnabled && service.providerCapabilityRefs.isNotEmpty)
                      _CatalogServiceEvidence(data: data, service: service),
                  ]);
                }, childCount: services.length + missing.length,
              )),
          ])),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: FilledButton(
            key: const ValueKey('selective-save'),
            onPressed: !_saving && validNow && compiled != null ? _save : null,
            child: Text(_saving ? 'Сохраняем…' : 'Сохранить режим и сервисы'),
          )),
        ],
      )),
    )));
  }
}

class _CatalogServiceEvidence extends StatelessWidget {
  const _CatalogServiceEvidence({required this.data, required this.service});
  final _CatalogServiceSelectionData data;
  final CatalogServicePolicy service;

  static const _features = {
    'web_request': 'Web-запрос', 'login': 'Вход в аккаунт', 'streaming': 'Потоковое видео и аудио',
    'websocket': 'WebSocket', 'store': 'Магазин', 'gameplay': 'Игровая сессия', 'cloud_gaming': 'Облачная игра',
  };
  static const _checks = {'resolver_transport': 'Соединение с DNS-сервисом', 'dns_answer': 'Ответ DNS',
    'tls_certificate': 'TLS-сертификат', 'feature_request': 'Запрос указанной функции'};
  static const _results = {'PASS': 'подтверждено в записи', 'FAIL': 'ошибка', 'NOT_VERIFIED': 'не проверено',
    'MANUAL_OWNER_TEST': 'нужна ручная проверка', 'OPERATOR_ATTESTED': 'заявлено оператором',
    'SKIPPED_BY_OWNER': 'пропущено владельцем', 'SKIPPED_BY_OPERATOR': 'пропущено оператором',
    'BLOCKED_BY_ACCESS': 'нет доступа для проверки', 'NOT_REQUESTED': 'не запрашивалось'};

  String _date(BuildContext context, DateTime value) {
    final local = value.toLocal();
    final labels = MaterialLocalizations.of(context);
    return '${labels.formatCompactDate(local)} ${labels.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
  }

  String _conditions(Map<String, Object?> row) {
    final policy = data.providerPolicy!;
    final provider = (policy.payload['providers']! as List).cast<Map<String, Object?>>()
      .singleWhere((item) => item['provider_id'] == row['provider_id']);
    final permission = (policy.payload['permissions']! as List).cast<Map<String, Object?>>()
      .singleWhere((item) => item['permission_id'] == provider['permission_id']);
    final now = DateTime.now().toUtc();
    bool current(Object? start, Object? end) => !now.isBefore(DateTime.parse(start! as String)) &&
      now.isBefore(DateTime.parse(end! as String));
    final reasons = <String>[
      if (!data.providerMetadataCurrent) 'Обновите сведения о подтверждении.',
      if (row['platform'] != data.platform) 'Подтверждение для другой платформы.',
      if (row['verification'] != 'verified') 'Есть только данные источника.',
      if (row['enabled'] != true || provider['enabled'] != true) 'Использование отключено.',
      if (permission['status'] != 'approved' || permission['embedded_use_allowed'] != true ||
          !current(permission['issued_at'], permission['expires_at'])) 'Нет действующего разрешения провайдера.',
      if (!current(row['observed_at'], row['expires_at'])) 'Подтверждение вне срока действия.',
    ];
    return reasons.isEmpty ? 'В политике есть действующее подтверждение для указанных условий.' : reasons.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final policy = data.providerPolicy;
    final rows = data.capabilitiesFor(service);
    return ExpansionTile(
      key: PageStorageKey('service-evidence-${service.id}'), tilePadding: EdgeInsets.zero,
      title: const Text('Подтверждения Smart Access'),
      subtitle: Text(policy == null ? 'Сведения недоступны. Обновите список.'
        : !data.providerMetadataCurrent ? 'Сведения устарели. Обновите список.'
        : rows.isEmpty ? 'Для этого сервиса нет подтверждений в политике.' : 'Что указано в подписанной политике'),
      children: [
        if (policy != null) ...[
          if (data.providerPolicyObservedAt != null) Padding(padding: const EdgeInsets.only(bottom: 8),
            child: Text('Политика получена ${_date(context, data.providerPolicyObservedAt!)}. Это не время проверки сервиса.')),
          const Text('Одна проверка относится только к указанной функции и условиям. Неуказанные функции не подтверждены. Работа сервиса на этом устройстве сейчас не проверялась.'),
          for (final row in rows) ListTile(key: ValueKey(row['capability_id']), contentPadding: EdgeInsets.zero,
            title: Text(_features[row['feature']]!),
            subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_conditions(row)),
              for (final check in (row['checks']! as Map<String, Object?>).entries)
                Text('${_checks[check.key]}: ${_results[check.value]}.'),
              Text('Наблюдение: ${_date(context, DateTime.parse(row['observed_at']! as String))}. '
                'Срок: до ${_date(context, DateTime.parse(row['expires_at']! as String))}.'),
              Text('${row['platform']} · ${row['origin']} · ${row['family']} · ${(row['domains']! as List).length} доменных правил.'),
              Text(row['feature'] == 'web_request' && row['origin'] == 'current-origin'
                ? 'Для этой функции предусмотрен автовыбор шлюза. Подключение зависит от правил, доступа и разрешения на соединение.'
                : 'Автовыбор шлюза для этой функции или условий пока не реализован.'),
              ExpansionTile(tilePadding: EdgeInsets.zero, title: const Text('Технические сведения'), children: [
                SelectableText('Провайдер: ${row['provider_id']} · версия ${row['provider_revision']}\n'
                  'Возможность: ${row['capability_id']}\n'
                  'Подтверждение: ${row['proof_ref']}\nSHA-256: ${row['proof_sha256']}\n'
                  'Политика: ${policy.revision} · безопасность ${policy.securityRevision}\n'
                  'Транспорт: TLS/TCP 443 с видимым SNI'),
              ]),
            ])),
        ],
      ],
    );
  }
}
