part of pokrov_app_shell;

String _routeModeShortLabel(RouteMode mode) {
  return switch (mode) {
    RouteMode.allExceptRu => 'Россия напрямую',
    RouteMode.fullTunnel => 'Всё устройство',
    RouteMode.selectiveServices => 'Выбранные сервисы',
    RouteMode.selectedApps => 'Только выбранные',
    RouteMode.excludedApps => 'Кроме выбранных',
  };
}

String _routeModeRowTitle(RouteMode mode) {
  return switch (mode) {
    RouteMode.allExceptRu => 'Россия напрямую',
    RouteMode.fullTunnel => 'Всё устройство',
    RouteMode.selectiveServices => 'Выбранные сервисы',
    RouteMode.selectedApps => 'Только выбранные',
    RouteMode.excludedApps => 'Кроме выбранных',
  };
}

String _routeModeRowSummary(RouteMode mode) {
  return switch (mode) {
    RouteMode.allExceptRu =>
      'Российские сервисы работают напрямую, остальное через POKROV VPN.',
    RouteMode.fullTunnel => 'Весь трафик идет через POKROV VPN.',
    RouteMode.selectiveServices => 'Защищённый маршрут только для выбранных сервисов. Остальное — напрямую.',
    RouteMode.selectedApps =>
      'POKROV VPN работает только для выбранных приложений.',
    RouteMode.excludedApps =>
      'Выбранные приложения работают напрямую, остальные — через POKROV VPN.',
  };
}
