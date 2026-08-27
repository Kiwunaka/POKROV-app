part of pokrov_app_shell;

class _WindowsConnectionCard extends StatelessWidget {
  const _WindowsConnectionCard({
    required this.preferences,
    required this.onChanged,
  });

  final PokrovRoutingPreferences preferences;
  final ValueChanged<PokrovRoutingPreferences> onChanged;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      key: const ValueKey('rules-windows-connection'),
      title: 'Подключение Windows',
      lines: const [
        'Приложение работает без повышенных прав. TUN и Core принадлежат защищённой службе POKROV.',
      ],
      child: Column(
        children: [
          _SettingsRow(
            key: const ValueKey('rules-windows-connection-mode'),
            icon: Icons.vpn_lock_outlined,
            title: 'Режим подключения',
            value: preferences.windowsConnectionMode.title,
            valueIsAction: false,
          ),
          const _SettingsRowDivider(),
          _SettingsRow(
            key: const ValueKey('rules-windows-tun-stack'),
            icon: Icons.memory_rounded,
            title: 'Сетевой стек VPN',
            value: preferences.tunStack.title,
            valueIsAction: true,
            onTap: () => _showWindowsTunStackSheet(
              context,
              preferences: preferences,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _PurposeRoutingCard extends StatelessWidget {
  const _PurposeRoutingCard({
    required this.preferences,
    required this.onChanged,
  });

  final PokrovRoutingPreferences preferences;
  final ValueChanged<PokrovRoutingPreferences> onChanged;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      key: const ValueKey('rules-purpose-routes'),
      title: 'Готовые маршруты',
      lines: const [
        'Выберите задачи. POKROV добавит проверяемые доменные правила поверх основного режима.',
      ],
      child: Column(
        children: [
          for (var index = 0;
              index < PokrovPurposeRoute.values.length;
              index += 1) ...[
            if (index > 0) const _SettingsRowDivider(),
            _RoutingToggleRow(
              key: ValueKey(
                'rules-purpose-${PokrovPurposeRoute.values[index].name}',
              ),
              title: PokrovPurposeRoute.values[index].title,
              subtitle: PokrovPurposeRoute.values[index].summary,
              value: preferences.purposeRoutes.contains(
                PokrovPurposeRoute.values[index],
              ),
              onChanged: (enabled) {
                final next = Set<PokrovPurposeRoute>.of(
                  preferences.purposeRoutes,
                );
                if (enabled) {
                  next.add(PokrovPurposeRoute.values[index]);
                } else {
                  next.remove(PokrovPurposeRoute.values[index]);
                }
                onChanged(preferences.copyWith(purposeRoutes: next));
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _CustomRoutingCard extends StatelessWidget {
  const _CustomRoutingCard({
    required this.preferences,
    required this.fallbackMode,
    required this.onChanged,
    required this.onRoutingLessonCompleted,
  });

  final PokrovRoutingPreferences preferences;
  final RouteMode fallbackMode;
  final ValueChanged<PokrovRoutingPreferences> onChanged;
  final VoidCallback onRoutingLessonCompleted;

  @override
  Widget build(BuildContext context) {
    final p = PokrovPalette.of(context);
    return _SectionCard(
      key: const ValueKey('rules-custom-routes'),
      title: 'Свои правила',
      lines: const [
        'Домен, IP или подсеть можно отправить через VPN либо оставить напрямую. Первым срабатывает ваше точное правило.',
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (preferences.overrides.isEmpty)
            Container(
              key: const ValueKey('rules-custom-empty'),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: p.surfaceMuted,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'Пока нет своих правил.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: p.muted,
                    ),
              ),
            )
          else
            for (var index = 0;
                index < preferences.overrides.length;
                index += 1) ...[
              if (index > 0) const _SettingsRowDivider(),
              _RouteOverrideRow(
                rule: preferences.overrides[index],
                onRemove: () {
                  onChanged(
                    preferences.copyWith(
                      overrides: preferences.overrides
                          .where(
                            (item) =>
                                item.id != preferences.overrides[index].id,
                          )
                          .toList(growable: false),
                    ),
                  );
                },
              ),
            ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const ValueKey('rules-custom-add'),
            onPressed: preferences.overrides.length >= 40
                ? null
                : () => _showAddRouteRuleSheet(
                      context,
                      onAdded: (rule) {
                        final withoutDuplicate = preferences.overrides
                            .where((item) => item.id != rule.id)
                            .toList(growable: true);
                        onChanged(
                          preferences.copyWith(
                            overrides: <PokrovRouteOverride>[
                              rule,
                              ...withoutDuplicate,
                            ],
                          ),
                        );
                      },
                    ),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Добавить правило'),
          ),
          const SizedBox(height: 18),
          _RouteDecisionProbe(
            preferences: preferences,
            fallbackMode: fallbackMode,
            onLessonCompleted: onRoutingLessonCompleted,
          ),
        ],
      ),
    );
  }
}

class _DnsAndLanCard extends StatelessWidget {
  const _DnsAndLanCard({
    required this.preferences,
    required this.onChanged,
  });

  final PokrovRoutingPreferences preferences;
  final ValueChanged<PokrovRoutingPreferences> onChanged;

  @override
  Widget build(BuildContext context) {
    final adBlockEnabled = preferences.dnsPreset == PokrovDnsPreset.adguard;
    return _SectionCard(
      key: const ValueKey('rules-dns-lan'),
      title: 'Блокировка и DNS',
      lines: [
        preferences.dnsTransport == PokrovDnsTransport.direct
            ? 'DoH идёт напрямую. Внешний IP не меняется, доступ к сервисам не гарантируется.'
            : 'Защитный DNS блокирует известные рекламные и трекинговые домены внутри VPN.',
      ],
      child: Column(
        children: [
          _RoutingToggleRow(
            key: const ValueKey('rules-ad-block-toggle'),
            title: 'Блокировать рекламу',
            subtitle:
                'AdGuard DNS. Некоторые объявления внутри приложений могут остаться.',
            value: adBlockEnabled,
            onChanged: (value) => onChanged(
              preferences.copyWith(
                dnsPreset:
                    value ? PokrovDnsPreset.adguard : PokrovDnsPreset.automatic,
              ),
            ),
          ),
          const _SettingsRowDivider(),
          _SettingsRow(
            key: const ValueKey('rules-dns-picker'),
            icon: Icons.dns_outlined,
            title: 'DNS',
            value: preferences.dnsPreset.title,
            valueIsAction: true,
            onTap: () => _showDnsPresetSheet(
              context,
              preferences: preferences,
              onChanged: onChanged,
            ),
          ),
          if (preferences.dnsPreset != PokrovDnsPreset.automatic) ...[
            const _SettingsRowDivider(),
            _RoutingToggleRow(
              key: const ValueKey('rules-dns-direct-toggle'),
              title: 'DNS напрямую · лаборатория',
              subtitle: preferences.dnsTransport == PokrovDnsTransport.direct
                  ? 'Только зашифрованный DoH идёт без VPN. IP-адрес не меняется.'
                  : 'DoH идёт через VPN. Надёжнее при сетевых блокировках.',
              value: preferences.dnsTransport == PokrovDnsTransport.direct,
              onChanged: (value) => onChanged(
                preferences.copyWith(
                  dnsTransport: value
                      ? PokrovDnsTransport.direct
                      : PokrovDnsTransport.vpn,
                ),
              ),
            ),
          ],
          const _SettingsRowDivider(),
          _RoutingToggleRow(
            key: const ValueKey('rules-lan-toggle'),
            title: 'Локальная сеть',
            subtitle: 'Принтеры, NAS и устройства в домашней сети напрямую.',
            value: preferences.allowLan,
            onChanged: (value) => onChanged(
              preferences.copyWith(allowLan: value),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrustedWifiCard extends StatefulWidget {
  const _TrustedWifiCard({
    required this.hostPlatform,
    required this.preferences,
    required this.onChanged,
    required this.onReadCurrentWifi,
    required this.onRequestWifiPermission,
  });

  final HostPlatform hostPlatform;
  final PokrovRoutingPreferences preferences;
  final ValueChanged<PokrovRoutingPreferences> onChanged;
  final PokrovWifiProbe onReadCurrentWifi;
  final PokrovWifiPermissionRequester onRequestWifiPermission;

  @override
  State<_TrustedWifiCard> createState() => _TrustedWifiCardState();
}

class _TrustedWifiCardState extends State<_TrustedWifiCard> {
  bool _busy = false;
  PokrovWifiNetworkStatus? _lastStatus;

  Future<void> _detectCurrentWifi() async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    final status = await widget.onReadCurrentWifi();
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = false;
      _lastStatus = status;
    });
    final name = status.name?.trim();
    if (name == null || name.isEmpty) {
      return;
    }
    _addName(name);
  }

  Future<void> _requestPermission() async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    final requested = await widget.onRequestWifiPermission();
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = false;
      _lastStatus = PokrovWifiNetworkStatus(
        connected: true,
        name: null,
        permissionRequired: true,
        reason: requested ? 'permission_requested' : 'permission_failed',
      );
    });
  }

  void _addName(String rawName) {
    final name = rawName.trim().replaceAll(RegExp(r'[\r\n\t]+'), ' ');
    if (name.isEmpty || name.length > 64) {
      return;
    }
    final names = <String>[
      name,
      ...widget.preferences.trustedWifiNames.where(
        (item) => item.trim().toLowerCase() != name.toLowerCase(),
      ),
    ].take(20).toList(growable: false);
    widget.onChanged(widget.preferences.copyWith(trustedWifiNames: names));
  }

  Future<void> _addManually() async {
    var input = '';
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      sheetAnimationStyle: _pokrovSheetAnimationStyle(context),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          20 + MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Доверенная Wi-Fi сеть',
              style: Theme.of(sheetContext).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Введите точное имя сети. Пароль не нужен и не сохраняется.',
              style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                    color: PokrovPalette.of(sheetContext).muted,
                  ),
            ),
            const SizedBox(height: 14),
            TextField(
              key: const ValueKey('rules-trusted-wifi-manual-input'),
              autofocus: true,
              maxLength: 64,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(labelText: 'Имя Wi-Fi'),
              onChanged: (value) {
                input = value;
              },
              onSubmitted: (value) =>
                  Navigator.of(sheetContext).pop(value.trim()),
            ),
            const SizedBox(height: 10),
            FilledButton(
              key: const ValueKey('rules-trusted-wifi-manual-save'),
              onPressed: () => Navigator.of(sheetContext).pop(input.trim()),
              child: const Text('Добавить'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || result == null) {
      return;
    }
    _addName(result);
  }

  String? _statusCopy() {
    final status = _lastStatus;
    if (status == null) {
      return null;
    }
    if (status.name?.isNotEmpty == true) {
      return 'Сеть «${status.name}» добавлена.';
    }
    if (status.reason == 'permission_requested') {
      return 'После системного разрешения нажмите «Определить текущую» ещё раз.';
    }
    if (status.permissionRequired) {
      return 'Android скрывает имя сети без отдельного разрешения.';
    }
    if (!status.connected) {
      return 'Устройство сейчас не подключено к Wi-Fi.';
    }
    return 'Имя текущей сети определить не удалось. Добавьте его вручную.';
  }

  @override
  Widget build(BuildContext context) {
    final preferences = widget.preferences;
    final p = PokrovPalette.of(context);
    final statusCopy = _statusCopy();
    return _SectionCard(
      key: const ValueKey('rules-trusted-wifi'),
      title: 'Доверенный Wi-Fi',
      lines: const [
        'POKROV не подключается в выбранных сетях и ставит активный туннель на паузу после возврата в приложение.',
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RoutingToggleRow(
            key: const ValueKey('rules-trusted-wifi-toggle'),
            title: 'Пауза в доверенных сетях',
            subtitle: preferences.trustedWifiNames.isEmpty
                ? 'Сначала добавьте хотя бы одну сеть.'
                : 'Точное совпадение по имени Wi-Fi.',
            value: preferences.pauseOnTrustedWifi,
            onChanged: preferences.trustedWifiNames.isEmpty
                ? (_) {}
                : (value) => widget.onChanged(
                      preferences.copyWith(pauseOnTrustedWifi: value),
                    ),
          ),
          if (preferences.trustedWifiNames.isNotEmpty) ...[
            const _SettingsRowDivider(),
            for (final name in preferences.trustedWifiNames)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Icon(Icons.wifi_rounded, size: 20, color: p.accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    IconButton(
                      key: ValueKey('rules-trusted-wifi-remove-$name'),
                      tooltip: 'Удалить сеть',
                      onPressed: () {
                        final next = preferences.trustedWifiNames
                            .where((item) => item != name)
                            .toList(growable: false);
                        widget.onChanged(
                          preferences.copyWith(
                            trustedWifiNames: next,
                            pauseOnTrustedWifi: next.isNotEmpty &&
                                preferences.pauseOnTrustedWifi,
                          ),
                        );
                      },
                      icon: const Icon(Icons.remove_circle_outline_rounded),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                key: const ValueKey('rules-trusted-wifi-detect'),
                onPressed: _busy ? null : _detectCurrentWifi,
                icon: _busy
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location_rounded),
                label: const Text('Определить текущую'),
              ),
              TextButton(
                key: const ValueKey('rules-trusted-wifi-manual'),
                onPressed: _busy ? null : _addManually,
                child: const Text('Добавить вручную'),
              ),
            ],
          ),
          if (statusCopy != null) ...[
            const SizedBox(height: 8),
            Text(
              statusCopy,
              key: const ValueKey('rules-trusted-wifi-status'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: p.muted,
                  ),
            ),
          ],
          if (_lastStatus?.permissionRequired == true &&
              widget.hostPlatform == HostPlatform.android) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const ValueKey('rules-trusted-wifi-permission'),
                onPressed: _busy ? null : _requestPermission,
                child: const Text('Разрешить видеть имя Wi-Fi'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AlwaysOnGuideCard extends StatelessWidget {
  const _AlwaysOnGuideCard({
    required this.hostPlatform,
    required this.onOpenVpnSettings,
  });

  final HostPlatform hostPlatform;
  final PokrovVpnSettingsLauncher onOpenVpnSettings;

  @override
  Widget build(BuildContext context) {
    final isAndroid = hostPlatform == HostPlatform.android;
    return _SectionCard(
      key: const ValueKey('rules-always-on-guide'),
      title:
          isAndroid ? 'Always-on и блокировка без VPN' : 'Защита при запуске',
      lines: [
        isAndroid
            ? 'Эти системные функции Android не подменяются переключателем внутри приложения.'
            : 'На Windows подключение и автозапуск контролируются приложением и системным треем.',
      ],
      child: Column(
        children: [
          _SettingsRow(
            key: const ValueKey('rules-always-on-help'),
            icon: Icons.lock_outline_rounded,
            title: isAndroid ? 'Как включить безопасно' : 'Как это работает',
            value: 'Инструкция',
            valueIsAction: true,
            onTap: () => _showInfoSheet(
              context,
              title: isAndroid
                  ? 'Always-on VPN в Android'
                  : 'Подключение при запуске Windows',
              lines: isAndroid
                  ? const [
                      'Откройте настройки Android → Сеть и интернет → VPN → POKROV.',
                      'Сначала включите «Постоянная VPN». Проверьте обычное подключение.',
                      'Только после проверки включайте «Блокировать соединения без VPN»: при ошибке туннеля интернет будет недоступен.',
                    ]
                  : const [
                      'POKROV показывает текущее состояние в трее и не скрывает ошибку подключения.',
                      'Автоподключение включайте только после успешной ручной проверки профиля.',
                    ],
            ),
          ),
          if (isAndroid) ...[
            const _SettingsRowDivider(),
            _SettingsRow(
              key: const ValueKey('rules-open-vpn-settings'),
              icon: Icons.open_in_new_rounded,
              title: 'Системные настройки VPN',
              value: 'Открыть',
              valueIsAction: true,
              onTap: () async {
                final opened = await onOpenVpnSettings();
                if (!context.mounted || opened) {
                  return;
                }
                showPokrovSnack(
                  context,
                  'Android не открыл настройки VPN на этом устройстве.',
                  tone: PokrovSnackTone.danger,
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _RoutingToggleRow extends StatelessWidget {
  const _RoutingToggleRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = PokrovPalette.of(context);
    return Semantics(
      container: true,
      enabled: true,
      label: title,
      hint: subtitle,
      toggled: value,
      onTap: () => onChanged(!value),
      child: ExcludeSemantics(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onChanged(!value),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: p.ink,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: p.muted,
                              height: 1.28,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Switch.adaptive(value: value, onChanged: onChanged),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RouteOverrideRow extends StatelessWidget {
  const _RouteOverrideRow({required this.rule, required this.onRemove});

  final PokrovRouteOverride rule;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final p = PokrovPalette.of(context);
    final direct = rule.action == PokrovRouteAction.direct;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            direct ? Icons.call_split_rounded : Icons.shield_outlined,
            color: direct ? p.muted : p.accent,
            size: 20,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rule.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: p.ink,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Text(
                  '${_routeMatchTypeLabel(rule.matchType)} · ${direct ? 'Напрямую' : 'Через VPN'}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: p.muted,
                      ),
                ),
              ],
            ),
          ),
          IconButton(
            key: ValueKey('rules-custom-remove-${rule.id}'),
            tooltip: 'Удалить правило',
            onPressed: onRemove,
            icon: const Icon(Icons.remove_circle_outline_rounded),
          ),
        ],
      ),
    );
  }
}

class _RouteDecisionProbe extends StatefulWidget {
  const _RouteDecisionProbe({
    required this.preferences,
    required this.fallbackMode,
    required this.onLessonCompleted,
  });

  final PokrovRoutingPreferences preferences;
  final RouteMode fallbackMode;
  final VoidCallback onLessonCompleted;

  @override
  State<_RouteDecisionProbe> createState() => _RouteDecisionProbeState();
}

class _RouteDecisionProbeState extends State<_RouteDecisionProbe> {
  final TextEditingController _controller = TextEditingController();
  PokrovRouteDecision? _decision;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _explain() {
    final value = _controller.text.trim();
    if (PokrovRouteOverride.tryCreate(
          value: value,
          action: PokrovRouteAction.vpn,
        ) ==
        null) {
      setState(() {
        _decision = null;
        _error = 'Введите домен, IP или подсеть CIDR.';
      });
      return;
    }
    setState(() {
      _decision = explainPokrovRouteDecision(
        destination: value,
        preferences: widget.preferences,
        fallbackMode: widget.fallbackMode,
      );
      _error = null;
    });
    widget.onLessonCompleted();
  }

  @override
  Widget build(BuildContext context) {
    final p = PokrovPalette.of(context);
    return Container(
      key: const ValueKey('rules-route-explainer'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Куда пойдёт адрес?',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: p.ink,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          TextField(
            key: const ValueKey('rules-route-explainer-input'),
            controller: _controller,
            autocorrect: false,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _explain(),
            decoration: InputDecoration(
              hintText: 'example.com или 10.0.0.0/8',
              errorText: _error,
              suffixIcon: IconButton(
                tooltip: 'Проверить маршрут',
                onPressed: _explain,
                icon: const Icon(Icons.arrow_forward_rounded),
              ),
            ),
          ),
          if (_decision != null) ...[
            const SizedBox(height: 10),
            Text(
              _decision!.action == PokrovRouteAction.vpn
                  ? 'Через POKROV VPN'
                  : 'Напрямую',
              key: const ValueKey('rules-route-explainer-result'),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: _decision!.action == PokrovRouteAction.vpn
                        ? p.accent
                        : p.ink,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 3),
            Text(
              _decision!.reason,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: p.muted,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

Future<void> _showAddRouteRuleSheet(
  BuildContext context, {
  required ValueChanged<PokrovRouteOverride> onAdded,
}) async {
  var value = '';
  var action = PokrovRouteAction.vpn;
  String? error;
  final result = await showModalBottomSheet<PokrovRouteOverride>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    sheetAnimationStyle: _pokrovSheetAnimationStyle(context),
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setSheetState) {
        final p = PokrovPalette.of(context);
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              22,
              4,
              22,
              22 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Новое правило',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: p.ink,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Например: youtube.com, 1.1.1.1 или 10.0.0.0/8.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: p.muted,
                      ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const ValueKey('rules-custom-value-input'),
                  autofocus: true,
                  autocorrect: false,
                  keyboardType: TextInputType.url,
                  onChanged: (next) => value = next,
                  decoration: InputDecoration(
                    labelText: 'Домен, IP или подсеть',
                    errorText: error,
                  ),
                ),
                const SizedBox(height: 14),
                SegmentedButton<PokrovRouteAction>(
                  key: const ValueKey('rules-custom-action'),
                  segments: const [
                    ButtonSegment(
                      value: PokrovRouteAction.vpn,
                      label: Text('Через VPN'),
                      icon: Icon(Icons.shield_outlined),
                    ),
                    ButtonSegment(
                      value: PokrovRouteAction.direct,
                      label: Text('Напрямую'),
                      icon: Icon(Icons.call_split_rounded),
                    ),
                  ],
                  selected: <PokrovRouteAction>{action},
                  onSelectionChanged: (selection) => setSheetState(() {
                    action = selection.first;
                  }),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  key: const ValueKey('rules-custom-save'),
                  onPressed: () {
                    final rule = PokrovRouteOverride.tryCreate(
                      value: value,
                      action: action,
                    );
                    if (rule == null) {
                      setSheetState(() {
                        error = 'Проверьте формат адреса.';
                      });
                      return;
                    }
                    Navigator.of(sheetContext).pop(rule);
                  },
                  child: const Text('Сохранить правило'),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
  if (result != null) {
    onAdded(result);
  }
}

Future<void> _showDnsPresetSheet(
  BuildContext context, {
  required PokrovRoutingPreferences preferences,
  required ValueChanged<PokrovRoutingPreferences> onChanged,
}) async {
  var customDnsUrl = preferences.customDnsUrl;
  String? error;
  final result = await showModalBottomSheet<PokrovRoutingPreferences>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    sheetAnimationStyle: _pokrovSheetAnimationStyle(context),
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setSheetState) {
        final p = PokrovPalette.of(context);
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              22,
              4,
              22,
              22 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Защищённый DNS',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: p.ink,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Пресеты используют DNS-over-HTTPS. «Автоматически» сохраняет DNS профиля сервера. Путь DoH можно изменить после выбора пресета.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: p.muted,
                      ),
                ),
                const SizedBox(height: 12),
                for (final preset in PokrovDnsPreset.values)
                  ListTile(
                    key: ValueKey('rules-dns-${preset.name}'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(preset.title),
                    trailing: preferences.dnsPreset == preset
                        ? Icon(Icons.check_rounded, color: p.accent)
                        : null,
                    onTap: () {
                      if (preset == PokrovDnsPreset.custom) {
                        setSheetState(() {
                          error = null;
                        });
                        return;
                      }
                      Navigator.of(sheetContext).pop(
                        preferences.copyWith(
                          dnsPreset: preset,
                          customDnsUrl: '',
                        ),
                      );
                    },
                  ),
                TextFormField(
                  key: const ValueKey('rules-dns-custom-input'),
                  initialValue: preferences.customDnsUrl,
                  autocorrect: false,
                  keyboardType: TextInputType.url,
                  onChanged: (value) => customDnsUrl = value,
                  decoration: InputDecoration(
                    labelText: 'Свой HTTPS DoH-адрес',
                    hintText: 'https://dns.example/dns-query',
                    errorText: error,
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton(
                  key: const ValueKey('rules-dns-custom-save'),
                  onPressed: () {
                    final value = customDnsUrl.trim();
                    final uri = Uri.tryParse(value);
                    if (uri == null ||
                        uri.scheme.toLowerCase() != 'https' ||
                        uri.host.isEmpty ||
                        uri.userInfo.isNotEmpty ||
                        value.length > 240) {
                      setSheetState(() {
                        error = 'Нужен полный безопасный адрес https://…';
                      });
                      return;
                    }
                    Navigator.of(sheetContext).pop(
                      preferences.copyWith(
                        dnsPreset: PokrovDnsPreset.custom,
                        customDnsUrl: value,
                      ),
                    );
                  },
                  child: const Text('Использовать свой DNS'),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
  if (result != null) {
    onChanged(result);
  }
}

Future<void> _showWindowsTunStackSheet(
  BuildContext context, {
  required PokrovRoutingPreferences preferences,
  required ValueChanged<PokrovRoutingPreferences> onChanged,
}) async {
  final result = await showModalBottomSheet<PokrovTunStack>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    sheetAnimationStyle: _pokrovSheetAnimationStyle(context),
    builder: (sheetContext) {
      final p = PokrovPalette.of(sheetContext);
      return SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Сетевой стек VPN',
                style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                      color: p.ink,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'System — стабильный вариант по умолчанию. Mixed и gVisor нужны только для совместимости с отдельными сетями.',
                style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                      color: p.muted,
                    ),
              ),
              const SizedBox(height: 12),
              for (final stack in PokrovTunStack.values)
                ListTile(
                  key: ValueKey('rules-windows-stack-${stack.name}'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(stack.title),
                  trailing: preferences.tunStack == stack
                      ? Icon(Icons.check_rounded, color: p.accent)
                      : null,
                  onTap: () => Navigator.of(sheetContext).pop(stack),
                ),
            ],
          ),
        ),
      );
    },
  );
  if (result != null) {
    onChanged(preferences.copyWith(tunStack: result));
  }
}

String _routeMatchTypeLabel(PokrovRouteMatchType type) => switch (type) {
      PokrovRouteMatchType.domain => 'Домен',
      PokrovRouteMatchType.ip => 'IP',
      PokrovRouteMatchType.subnet => 'Подсеть',
    };
