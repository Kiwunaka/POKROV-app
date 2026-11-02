part of pokrov_app_shell;

/// Widgets the person can put on the main screen, in catalog order.
const _homeTileIds = <String>[
  'country', 'route', 'bypass', 'warp', 'access', 'help', 'devices', 'bonuses',
  'notifications', 'tgproxy', 'diagnostics', 'history', 'wifi', 'dns',
];

const _homeTileDefaults = <String>['country', 'route', 'bypass', 'warp'];

const _homeTileOptions = <String, (String, String, IconData)>{
  'country': ('Страна', 'Авто или конкретная страна', Icons.public_rounded),
  'route': ('Маршрут', 'Что идёт через POKROV', Icons.alt_route_rounded),
  'bypass': ('Обход блокировок', 'YouTube и похожее сначала напрямую', Icons.turn_right_rounded),
  'warp': ('WARP', 'Если сайты не открываются', Icons.cloud_outlined),
  'access': ('Доступ', 'Сколько осталось', Icons.vpn_key_outlined),
  'help': ('Помощь', 'ИИ и человек', Icons.help_outline_rounded),
  'devices': ('Устройства', '«Код для входа» для нового', Icons.devices_rounded),
  'bonuses': ('Бонусы', 'Дни к доступу', Icons.card_giftcard_rounded),
  'notifications': ('Уведомления', 'Новости и ответы', Icons.notifications_none_rounded),
  'tgproxy': ('Telegram-прокси', 'Бесплатно', Icons.send_rounded),
  'diagnostics': ('Проверка', 'Код для поддержки', Icons.health_and_safety_outlined),
  'history': ('История и скорость', 'Ярлыки после подключения', Icons.history_rounded),
  'wifi': ('Доверенный Wi-Fi', 'Пауза дома', Icons.wifi_rounded),
  'dns': ('DNS', 'Защищённый DNS', Icons.dns_outlined),
};

extension _HomeTiles on _PokrovSeedShellState {
  bool get _bypassAvailable =>
      const {HostPlatform.android, HostPlatform.windows}.contains(widget.appContext.hostPlatform);

  List<String> get _availableHomeTileIds =>
      [for (final id in _homeTileIds) if (id != 'bypass' || _bypassAvailable) id];

  List<String> get _shownHomeTileIds =>
      [for (final id in _homeTiles ?? _homeTileDefaults) if (_availableHomeTileIds.contains(id)) id];

  List<ui.HomeTile> _homeTileViews(BuildContext context, String selectedCountry) {
    final country = selectedCountry.trim();
    final location = _homeLocationLabel.split(' · ').first;
    ui.HomeTile tile(String id, String value, VoidCallback onTap, {bool? toggled}) {
      final (title, _, icon) = _homeTileOptions[id]!;
      return ui.HomeTile(id: id, title: title, value: value, icon: icon, onTap: onTap, toggled: toggled);
    }
    return [
      for (final id in _shownHomeTileIds) switch (id) {
        'country' => tile(id, country.isNotEmpty ? _locationCountryDisplayName(country, country)
            : _connectionPresentation.isVerified ? 'Авто · $location' : 'Авто', () => _selectTab(SeedTab.locations)),
        'route' => tile(id, _routeModeShortLabel(_selectedRouteMode), _openRulesPage),
        'bypass' => tile(id, _clientExperience.routingPreferences.localDpiEnabled ? 'Включён' : 'Выключен', _openLocalDpiControl),
        'warp' => tile(id, _warpRuntimeConsent ? 'Включится при подключении' : 'Если сайты не открываются', () {
            if (_managedWarpPolicy.canOfferRuntime && !_warpPolicyBusy) {
              unawaited(_setWarpRuntimeConsent(!_warpRuntimeConsent));
            } else {
              unawaited(_openWarpControl());
            }
          }, toggled: _warpRuntimeConsent),
        'access' => tile(id, _accountSessionCoordinator.loginRecoveryRequired ? 'Восстановить вход'
            : _accessShortValue(widget.appContext, _bonusSummary, _accountSessionCoordinator.freeProfileAccessForDisplay, _subscriptionInfo),
            () => _selectTab(SeedTab.access)),
        'help' => tile(id, 'ИИ и человек', () => _selectTab(SeedTab.help)),
        'devices' => tile(id, '«Код для входа» для нового', () => _showDevicesSheet(context,
            currentPlatformLabel: widget.appContext.hostPlatform.label,
            onFetchDevices: _fetchClientDevices, onRevokeDevice: _revokeClientDevice,
            onIssuePairingCode: _issueDevicePairingCode, onCancelPairingCode: _cancelDevicePairingCode)),
        'bonuses' => tile(id, 'Дни к доступу', () => _selectTab(SeedTab.access)),
        'notifications' => tile(id, _notificationsUnread > 0 ? 'Новых: $_notificationsUnread' : 'Новых нет',
            () => unawaited(_openNotificationsInbox())),
        'tgproxy' => tile(id, 'Бесплатно', () => _showSeedHandoff('cabinet',
            Uri.parse(widget.appContext.cabinetUrl).resolve('/telegram/').toString())),
        'diagnostics' => tile(id, 'Код для поддержки', _openDiagnostics),
        'history' => tile(id, 'Ярлыки после подключения', () => _openProtectionCenter(technical: true)),
        'wifi' => tile(id, 'Пауза дома', () => _openRulesPage(expert: true)),
        _ => tile(id, 'Защищённый DNS', () => _openRulesPage(expert: true)),
      },
    ];
  }

  void _openHomeTilesSheet(BuildContext context) {
    PokrovHaptics.tap();
    ui.showPokrovSheet<void>(context, (sheetContext) => ui.HomeTilesSheet(
      options: [
        for (final id in _availableHomeTileIds)
          ui.HomeTileOption(id: id, title: _homeTileOptions[id]!.$1, hint: _homeTileOptions[id]!.$2, icon: _homeTileOptions[id]!.$3),
      ],
      selected: _shownHomeTileIds,
      defaults: [for (final id in _homeTileDefaults) if (_availableHomeTileIds.contains(id)) id],
      onChanged: _setHomeTiles,
    ));
  }
}
