part of pokrov_app_shell;

String _routeModeShortLabel(RouteMode mode, {bool smartDnsActive = false}) {
  return switch (mode) {
    RouteMode.allExceptRu => 'Россия напрямую',
    RouteMode.fullTunnel => 'Всё устройство',
    RouteMode.selectiveServices => smartDnsActive ? 'Только DNS' : 'Выбранные сервисы',
    RouteMode.selectedApps => 'Только выбранные',
    RouteMode.excludedApps => 'Кроме выбранных',
  };
}

String _routeModeRowTitle(RouteMode mode, {bool smartDnsActive = false}) {
  return switch (mode) {
    RouteMode.allExceptRu => 'Россия напрямую',
    RouteMode.fullTunnel => 'Всё устройство',
    RouteMode.selectiveServices => smartDnsActive ? 'Только DNS' : 'Выбранные сервисы',
    RouteMode.selectedApps => 'Только выбранные',
    RouteMode.excludedApps => 'Кроме выбранных',
  };
}

String _routeModeRowSummary(RouteMode mode, {bool smartDnsActive = false}) {
  return switch (mode) {
    RouteMode.allExceptRu =>
      'Российские сервисы работают напрямую, остальное через POKROV VPN.',
    RouteMode.fullTunnel => 'Весь трафик идет через POKROV VPN.',
    RouteMode.selectiveServices => smartDnsActive
      ? 'Умный DNS для поддерживаемых сервисов, VPN при сбое. Остальное — напрямую.'
      : 'Защищённый маршрут только для выбранных сервисов. Остальное — напрямую.',
    RouteMode.selectedApps =>
      'POKROV VPN работает только для выбранных приложений.',
    RouteMode.excludedApps =>
      'Выбранные приложения работают напрямую, остальные — через POKROV VPN.',
  };
}
