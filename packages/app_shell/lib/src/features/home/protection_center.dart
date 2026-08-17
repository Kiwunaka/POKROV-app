part of pokrov_app_shell;

typedef PokrovProtectionProbe = Future<PokrovHttpsProbeResult> Function(
  Uri apiBaseUri,
);

enum PokrovHttpsProbeState { unknown, healthy, degraded }

class PokrovHttpsProbeResult {
  const PokrovHttpsProbeResult.unknown({
    this.detail = 'Проверка ещё не выполнялась.',
  }) : state = PokrovHttpsProbeState.unknown;

  const PokrovHttpsProbeResult.healthy({
    this.detail = 'HTTPS-соединение с POKROV отвечает.',
  }) : state = PokrovHttpsProbeState.healthy;

  const PokrovHttpsProbeResult.degraded({required this.detail})
      : state = PokrovHttpsProbeState.degraded;

  final PokrovHttpsProbeState state;
  final String detail;
}

Future<PokrovHttpsProbeResult> _probePokrovHttps(Uri apiBaseUri) async {
  if (apiBaseUri.scheme.toLowerCase() != 'https') {
    return const PokrovHttpsProbeResult.unknown(
      detail: 'HTTPS-проверка недоступна для локального HTTP-окружения.',
    );
  }
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
  try {
    final target = apiBaseUri.resolve('/api/health');
    final request =
        await client.getUrl(target).timeout(const Duration(seconds: 5));
    request.followRedirects = false;
    final response = await request.close().timeout(const Duration(seconds: 5));
    await response.drain<void>();
    if (response.statusCode >= 200 && response.statusCode < 400) {
      return const PokrovHttpsProbeResult.healthy();
    }
    return PokrovHttpsProbeResult.degraded(
      detail: 'HTTPS-сервис ответил кодом ${response.statusCode}.',
    );
  } on Object {
    return const PokrovHttpsProbeResult.degraded(
      detail: 'Не удалось подтвердить HTTPS-соединение с POKROV.',
    );
  } finally {
    client.close(force: true);
  }
}

class _ProtectionCenterData {
  const _ProtectionCenterData({
    required this.snapshot,
    required this.liveStats,
    required this.httpsProbe,
    required this.history,
    required this.shortcuts,
  });

  final RuntimeSnapshot? snapshot;
  final RuntimeLiveStats liveStats;
  final PokrovHttpsProbeResult httpsProbe;
  final List<PokrovProtectionEvent> history;
  final List<PokrovPostConnectShortcut> shortcuts;
}

enum _ProtectionCheckTone { success, warning, danger, unknown }

class _ProtectionCheck {
  const _ProtectionCheck({
    required this.title,
    required this.value,
    required this.detail,
    required this.icon,
    required this.tone,
  });

  final String title;
  final String value;
  final String detail;
  final IconData icon;
  final _ProtectionCheckTone tone;
}

class _ProtectionCenterSheet extends StatefulWidget {
  const _ProtectionCenterSheet({
    required this.initialData,
    required this.onRefresh,
    required this.onRepair,
    required this.onAddShortcut,
    required this.onRemoveShortcut,
    required this.onOpenShortcut,
  });

  final _ProtectionCenterData initialData;
  final Future<_ProtectionCenterData> Function() onRefresh;
  final Future<_ProtectionCenterData> Function() onRepair;
  final String? Function(String label, String href) onAddShortcut;
  final ValueChanged<String> onRemoveShortcut;
  final Future<bool> Function(PokrovPostConnectShortcut) onOpenShortcut;

  @override
  State<_ProtectionCenterSheet> createState() => _ProtectionCenterSheetState();
}

class _ProtectionCenterSheetState extends State<_ProtectionCenterSheet> {
  late _ProtectionCenterData _data = widget.initialData;
  bool _refreshing = true;
  bool _repairing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    if (!_refreshing) {
      setState(() {
        _refreshing = true;
      });
    }
    try {
      final next = await widget.onRefresh();
      if (!mounted) {
        return;
      }
      setState(() {
        _data = next;
        _error = null;
      });
    } on _ProtectionRepairBusy {
      if (mounted) {
        setState(() {
          _error = 'POKROV уже выполняет действие. Дождитесь завершения.';
        });
      }
    } on Object {
      if (mounted) {
        setState(() {
          _error = 'Не удалось обновить проверки.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _refreshing = false;
        });
      }
    }
  }

  Future<void> _repair() async {
    if (_repairing || _refreshing) {
      return;
    }
    PokrovHaptics.tap();
    setState(() {
      _repairing = true;
      _error = null;
    });
    try {
      final next = await widget.onRepair();
      if (!mounted) {
        return;
      }
      setState(() {
        _data = next;
      });
    } on _ProtectionRepairFailed catch (failure) {
      if (mounted) {
        setState(() {
          _data = failure.data;
          _error =
              'Восстановление не завершилось. Показано состояние после остановки туннеля.';
        });
      }
    } on Object {
      if (mounted) {
        setState(() {
          _error =
              'Восстановление не завершилось. Не удалось получить свежие проверки.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _repairing = false;
        });
      }
    }
  }

  Future<void> _addShortcut() async {
    var label = '';
    var href = 'https://';
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ярлык после подключения'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              key: const ValueKey('post-connect-shortcut-label'),
              maxLength: 40,
              decoration: const InputDecoration(labelText: 'Название'),
              onChanged: (value) => label = value,
            ),
            TextFormField(
              key: const ValueKey('post-connect-shortcut-href'),
              initialValue: href,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'HTTPS-адрес'),
              onChanged: (value) => href = value,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            key: const ValueKey('post-connect-shortcut-save'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (!mounted) {
      return;
    }
    if (submitted != true) {
      return;
    }
    final error = widget.onAddShortcut(label, href);
    if (error != null) {
      setState(() {
        _error = error;
      });
      return;
    }
    await _refresh();
  }

  Future<void> _removeShortcut(String id) async {
    widget.onRemoveShortcut(id);
    await _refresh();
  }

  Future<void> _openShortcut(PokrovPostConnectShortcut shortcut) async {
    final opened = await widget.onOpenShortcut(shortcut);
    if (!opened && mounted) {
      setState(() {
        _error = 'Не удалось открыть ярлык.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = PokrovPalette.of(context);
    final checks = _protectionChecks(_data);
    return SafeArea(
      top: false,
      child: FractionallySizedBox(
        heightFactor: 0.86,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Состояние защиты',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('protection-refresh-action'),
                    tooltip: 'Обновить проверки',
                    onPressed: _refreshing || _repairing ? null : _refresh,
                    icon: _refreshing
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CupertinoActivityIndicator(radius: 9),
                          )
                        : const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'POKROV проверяет соединение на этом устройстве.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: p.muted,
                      height: 1.35,
                    ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const ValueKey('protection-repair-action'),
                  onPressed: _refreshing || _repairing ? null : _repair,
                  icon: _repairing
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CupertinoActivityIndicator(radius: 8),
                        )
                      : const Icon(Icons.build_circle_outlined),
                  label: Text(
                    _repairing
                        ? 'Восстанавливаем…'
                        : 'Проверить и восстановить',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'POKROV один раз переподключится и повторит проверку. Локация и правила сохранятся.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: p.muted,
                      height: 1.35,
                    ),
              ),
              const SizedBox(height: 16),
              Container(
                key: const ValueKey('protection-checks-group'),
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: PokrovRadii.card,
                  border: Border.all(color: p.line),
                ),
                child: Column(
                  children: [
                    for (final (index, check) in checks.indexed) ...[
                      _ProtectionCheckRow(check: check),
                      if (index != checks.length - 1)
                        Divider(height: 1, indent: 56, color: p.line),
                    ],
                  ],
                ),
              ),
              if (_data.liveStats.available) ...[
                const SizedBox(height: 14),
                _ProtectionLiveStatsCard(stats: _data.liveStats),
              ],
              const SizedBox(height: 14),
              _PostConnectShortcutsCard(
                shortcuts: _data.shortcuts,
                connected: _data.snapshot?.phase == RuntimePhase.running,
                onAdd: _addShortcut,
                onRemove: _removeShortcut,
                onOpen: _openShortcut,
              ),
              if (_data.history.isNotEmpty) ...[
                const SizedBox(height: 14),
                _ProtectionHistoryCard(events: _data.history),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  key: const ValueKey('protection-center-error'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: p.danger,
                      ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

List<_ProtectionCheck> _protectionChecks(_ProtectionCenterData data) {
  final snapshot = data.snapshot;
  final running = snapshot?.phase == RuntimePhase.running;
  final tunnel = !running
      ? _ProtectionCheck(
          title: 'Туннель',
          value: snapshot == null ? 'Нет измерения' : 'Отключён',
          detail: _consumerTunnelDetail(snapshot),
          icon: Icons.shield_outlined,
          tone: _ProtectionCheckTone.unknown,
        )
      : switch (snapshot!.hostHealth) {
          RuntimeHostHealth.healthy => const _ProtectionCheck(
              title: 'Туннель',
              value: 'Активен',
              detail: 'Защищённое соединение работает.',
              icon: Icons.shield_rounded,
              tone: _ProtectionCheckTone.success,
            ),
          RuntimeHostHealth.degraded => _ProtectionCheck(
              title: 'Туннель',
              value: 'Требует внимания',
              detail: _consumerTunnelDetail(snapshot),
              icon: Icons.warning_amber_rounded,
              tone: _ProtectionCheckTone.warning,
            ),
          RuntimeHostHealth.unknown => const _ProtectionCheck(
              title: 'Туннель',
              value: 'Активен, проверяем',
              detail: 'Соединение запущено, свежий результат ещё не получен.',
              icon: Icons.shield_outlined,
              tone: _ProtectionCheckTone.unknown,
            ),
        };

  final dns = !running
      ? const _ProtectionCheck(
          title: 'Адреса сайтов',
          value: 'Не проверялся',
          detail: 'Проверка начнётся после подключения.',
          icon: Icons.dns_outlined,
          tone: _ProtectionCheckTone.unknown,
        )
      : switch (snapshot!.dnsState) {
          RuntimeDiagnosticState.healthy => const _ProtectionCheck(
              title: 'Адреса сайтов',
              value: 'Готов',
              detail: 'POKROV может находить адреса сайтов и локаций.',
              icon: Icons.dns_rounded,
              tone: _ProtectionCheckTone.success,
            ),
          RuntimeDiagnosticState.degraded => const _ProtectionCheck(
              title: 'Адреса сайтов',
              value: 'Недоступен',
              detail: 'Не удалось получить адрес для подключения.',
              icon: Icons.dns_outlined,
              tone: _ProtectionCheckTone.danger,
            ),
          RuntimeDiagnosticState.unknown => const _ProtectionCheck(
              title: 'Адреса сайтов',
              value: 'Нет измерения',
              detail: 'Результат проверки пока не получен.',
              icon: Icons.dns_outlined,
              tone: _ProtectionCheckTone.unknown,
            ),
        };

  final https = !running
      ? const _ProtectionCheck(
          title: 'Выход через VPN',
          value: 'Не проверяется',
          detail: 'Проверка запускается после подключения.',
          icon: Icons.public_outlined,
          tone: _ProtectionCheckTone.unknown,
        )
      : snapshot!.coreEgressValidated == true
          ? const _ProtectionCheck(
              title: 'Выход через VPN',
              value: 'Подтверждён',
              detail: 'Тестовый адрес открылся через выбранную локацию.',
              icon: Icons.public_rounded,
              tone: _ProtectionCheckTone.success,
            )
          : snapshot.coreEgressValidated == false
              ? const _ProtectionCheck(
                  title: 'Выход через VPN',
                  value: 'Не подтверждён',
                  detail: 'Тестовый адрес не открылся через выбранную локацию.',
                  icon: Icons.public_off_outlined,
                  tone: _ProtectionCheckTone.danger,
                )
              : const _ProtectionCheck(
                  title: 'Выход через VPN',
                  value: 'Проверяется',
                  detail: 'Ожидаем свежий результат проверки.',
                  icon: Icons.public_outlined,
                  tone: _ProtectionCheckTone.unknown,
                );

  final v4 = snapshot?.ipv4RouteCount;
  final v6 = snapshot?.ipv6RouteCount;
  final routeKnown = v4 != null || v6 != null;
  final routeCount = (v4 ?? 0) + (v6 ?? 0);
  final routes = !running
      ? const _ProtectionCheck(
          title: 'Маршруты',
          value: 'Не активны',
          detail: 'Локальные VPN-маршруты появятся после подключения.',
          icon: Icons.alt_route_rounded,
          tone: _ProtectionCheckTone.unknown,
        )
      : !routeKnown
          ? const _ProtectionCheck(
              title: 'Маршруты',
              value: 'Нет измерения',
              detail: 'Хост не отдал счётчики локальных маршрутов.',
              icon: Icons.alt_route_rounded,
              tone: _ProtectionCheckTone.unknown,
            )
          : routeCount > 0
              ? _ProtectionCheck(
                  title: 'Маршруты',
                  value: 'Назначены',
                  detail:
                      'Локально: IPv4 ${v4 ?? 0}, IPv6 ${v6 ?? 0}. Это не внешний leak-тест.',
                  icon: Icons.alt_route_rounded,
                  tone: _ProtectionCheckTone.success,
                )
              : const _ProtectionCheck(
                  title: 'Маршруты',
                  value: 'Не подтверждены',
                  detail: 'Хост сообщил нулевое число VPN-маршрутов.',
                  icon: Icons.alt_route_rounded,
                  tone: _ProtectionCheckTone.warning,
                );
  return <_ProtectionCheck>[tunnel, dns, https, routes];
}

String _consumerTunnelDetail(RuntimeSnapshot? snapshot) {
  final failureKind = snapshot?.lastFailureKind?.trim() ?? '';
  return switch (failureKind) {
    'resolver_timeout' ||
    'resolver_response_error' ||
    'resolver_callback_error' =>
      'Не удалось подтвердить DNS-подключение устройства. Попробуйте подключиться снова.',
    'tls_handshake_failed' ||
    'tunnel_handshake_failed' =>
      'Защищённый канал до выбранной локации не отвечает. Попробуйте другую локацию или подключитесь снова.',
    'core_egress_probe_failed' =>
      'Не удалось подтвердить защищённое подключение. Попробуйте подключиться снова.',
    'default_network_unavailable' ||
    'default_network_interface_unresolved' ||
    'default_network_index_unresolved' =>
      'Устройство не подтвердило доступ к сети. Проверьте соединение и попробуйте снова.',
    _ when failureKind.startsWith('dns_') =>
      'Не удалось подготовить DNS для защищённого подключения. Попробуйте снова.',
    _ when failureKind.isNotEmpty =>
      'Подключение требует внимания. Попробуйте подключиться снова.',
    _ => snapshot == null
        ? 'Runtime не подтвердил активное соединение.'
        : 'Подключение сейчас не активно. Попробуйте подключиться снова.',
  };
}

class _ProtectionCheckRow extends StatelessWidget {
  const _ProtectionCheckRow({required this.check});

  final _ProtectionCheck check;

  @override
  Widget build(BuildContext context) {
    final p = PokrovPalette.of(context);
    final color = switch (check.tone) {
      _ProtectionCheckTone.success => p.success,
      _ProtectionCheckTone.warning => p.warning,
      _ProtectionCheckTone.danger => p.danger,
      _ProtectionCheckTone.unknown => p.muted,
    };
    return Padding(
      key: ValueKey('protection-check-${check.title}'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(check.icon, color: color, size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        check.title,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    Text(
                      check.value,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  check.detail,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: p.muted,
                        height: 1.3,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProtectionLiveStatsCard extends StatelessWidget {
  const _ProtectionLiveStatsCard({required this.stats});

  final RuntimeLiveStats stats;

  @override
  Widget build(BuildContext context) {
    final p = PokrovPalette.of(context);
    final location = <String>[stats.serverCountry, stats.serverCode]
        .where((item) => item.trim().isNotEmpty)
        .join(' · ');
    return Container(
      key: const ValueKey('protection-live-stats'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: PokrovRadii.card,
        border: Border.all(color: p.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Сейчас', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 10),
          Wrap(
            spacing: 18,
            runSpacing: 10,
            children: [
              _ProtectionMetric(
                label: 'Ping',
                value: stats.latencyMs == null ? '—' : '${stats.latencyMs} мс',
              ),
              _ProtectionMetric(
                label: 'Входящая',
                value: _formatProtectionRate(stats.downlinkBps),
              ),
              _ProtectionMetric(
                label: 'Исходящая',
                value: _formatProtectionRate(stats.uplinkBps),
              ),
              _ProtectionMetric(
                label: 'Сессия',
                value: _formatProtectionSession(stats.since),
              ),
              if (location.isNotEmpty)
                _ProtectionMetric(label: 'Узел', value: location),
              if (stats.protocol.trim().isNotEmpty)
                _ProtectionMetric(label: 'Протокол', value: stats.protocol),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProtectionMetric extends StatelessWidget {
  const _ProtectionMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final p = PokrovPalette.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 92),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 2),
          Text(
            value,
            style:
                Theme.of(context).textTheme.labelLarge?.copyWith(color: p.ink),
          ),
        ],
      ),
    );
  }
}

class _PostConnectShortcutsCard extends StatelessWidget {
  const _PostConnectShortcutsCard({
    required this.shortcuts,
    required this.connected,
    required this.onAdd,
    required this.onRemove,
    required this.onOpen,
  });

  final List<PokrovPostConnectShortcut> shortcuts;
  final bool connected;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;
  final ValueChanged<PokrovPostConnectShortcut> onOpen;

  @override
  Widget build(BuildContext context) {
    final p = PokrovPalette.of(context);
    return Container(
      key: const ValueKey('post-connect-shortcuts-card'),
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 10),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: PokrovRadii.card,
        border: Border.all(color: p.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'После подключения',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              TextButton.icon(
                key: const ValueKey('post-connect-shortcut-add'),
                onPressed: shortcuts.length >= 6 ? null : onAdd,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Добавить'),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 4, bottom: 6),
            child: Text(
              'Только ваши HTTPS-ссылки. Они никогда не открываются автоматически.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: p.muted,
                    height: 1.3,
                  ),
            ),
          ),
          if (shortcuts.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 4, bottom: 4),
              child: Text(
                'Ярлыков пока нет.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: p.muted,
                    ),
              ),
            )
          else
            for (final shortcut in shortcuts)
              Padding(
                key: ValueKey('post-connect-shortcut-${shortcut.id}'),
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        onPressed: connected ? () => onOpen(shortcut) : null,
                        icon: const Icon(Icons.open_in_new_rounded, size: 18),
                        label: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            shortcut.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Удалить ярлык',
                      onPressed: () => onRemove(shortcut.id),
                      icon: const Icon(Icons.close_rounded, size: 19),
                    ),
                  ],
                ),
              ),
          if (!connected && shortcuts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4, right: 4),
              child: Text(
                'Сначала подключите POKROV.',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: p.muted,
                    ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProtectionHistoryCard extends StatelessWidget {
  const _ProtectionHistoryCard({required this.events});

  final List<PokrovProtectionEvent> events;

  @override
  Widget build(BuildContext context) {
    final p = PokrovPalette.of(context);
    final visibleEvents = events.take(8).toList(growable: false);
    return Container(
      key: const ValueKey('protection-history-card'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: PokrovRadii.card,
        border: Border.all(color: p.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('История защиты', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          for (final (index, event) in visibleEvents.indexed) ...[
            _ProtectionHistoryRow(event: event),
            if (index != visibleEvents.length - 1)
              Divider(height: 1, indent: 30, color: p.line),
          ],
        ],
      ),
    );
  }
}

class _ProtectionHistoryRow extends StatelessWidget {
  const _ProtectionHistoryRow({required this.event});

  final PokrovProtectionEvent event;

  @override
  Widget build(BuildContext context) {
    final p = PokrovPalette.of(context);
    final color = switch (event.tone) {
      PokrovProtectionEventTone.success => p.success,
      PokrovProtectionEventTone.warning => p.warning,
      PokrovProtectionEventTone.error => p.danger,
      PokrovProtectionEventTone.neutral => p.muted,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Icon(Icons.circle, color: color, size: 9),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        event.title,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                    Text(
                      _formatProtectionEventTime(event.occurredAt),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  event.detail,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: p.muted,
                        height: 1.3,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatProtectionEventTime(String rawIso, {DateTime? now}) {
  final eventAt = DateTime.tryParse(rawIso)?.toUtc();
  if (eventAt == null) {
    return '—';
  }
  final age = (now ?? DateTime.now()).toUtc().difference(eventAt);
  if (age.isNegative) {
    return '—';
  }
  if (age < const Duration(minutes: 1)) {
    return 'сейчас';
  }
  if (age < const Duration(hours: 1)) {
    return '${age.inMinutes} мин';
  }
  if (age < const Duration(days: 1)) {
    return '${age.inHours} ч';
  }
  return '${age.inDays} дн';
}

String _formatProtectionRate(int? bytesPerSecond) {
  if (bytesPerSecond == null || bytesPerSecond < 0) {
    return '—';
  }
  if (bytesPerSecond < 1024) {
    return '$bytesPerSecond Б/с';
  }
  final kib = bytesPerSecond / 1024;
  if (kib < 1024) {
    return '${kib.toStringAsFixed(kib >= 100 ? 0 : 1)} КБ/с';
  }
  final mib = kib / 1024;
  return '${mib.toStringAsFixed(mib >= 100 ? 0 : 1)} МБ/с';
}

String _formatProtectionSession(DateTime? since) {
  if (since == null) {
    return '—';
  }
  final elapsed = DateTime.now().toUtc().difference(since.toUtc());
  if (elapsed.isNegative) {
    return '—';
  }
  final hours = elapsed.inHours;
  final minutes = elapsed.inMinutes.remainder(60);
  return hours > 0 ? '$hours ч $minutes мин' : '${elapsed.inMinutes} мин';
}
