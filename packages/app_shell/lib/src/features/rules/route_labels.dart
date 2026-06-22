part of pokrov_app_shell;

String _routeModeShortLabel(RouteMode mode) {
  return switch (mode) {
    RouteMode.allExceptRu => 'Умный режим',
    RouteMode.fullTunnel => 'Всё устройство',
    RouteMode.selectedApps => 'Только выбранные',
  };
}

String _routeModeRowTitle(RouteMode mode) {
  return switch (mode) {
    RouteMode.allExceptRu => 'Умный режим',
    RouteMode.fullTunnel => 'Всё устройство',
    RouteMode.selectedApps => 'Только выбранные',
  };
}

String _routeModeRowSummary(RouteMode mode) {
  return switch (mode) {
    RouteMode.allExceptRu =>
      'Российские сервисы работают напрямую, остальное через POKROV VPN.',
    RouteMode.fullTunnel => 'Весь трафик идет через POKROV VPN.',
    RouteMode.selectedApps =>
      'POKROV VPN работает только для выбранных приложений.',
  };
}
