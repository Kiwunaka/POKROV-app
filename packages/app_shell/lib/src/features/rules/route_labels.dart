part of pokrov_app_shell;

String _routeModeShortLabel(RouteMode mode) {
  return switch (mode) {
    RouteMode.allExceptRu => 'Зарубежные сайты',
    RouteMode.fullTunnel => 'Весь трафик',
    RouteMode.selectedApps => 'Выбранные приложения',
  };
}

String _routeModeRowTitle(RouteMode mode) {
  return switch (mode) {
    RouteMode.allExceptRu => 'Зарубежные сайты через POKROV',
    RouteMode.fullTunnel => 'Весь трафик через POKROV',
    RouteMode.selectedApps => 'Только выбранные приложения',
  };
}

String _routeModeRowSummary(RouteMode mode) {
  return switch (mode) {
    RouteMode.allExceptRu =>
      'Российские и локальные сервисы работают напрямую, остальное идет через POKROV.',
    RouteMode.fullTunnel => 'Весь трафик устройства идет через POKROV.',
    RouteMode.selectedApps =>
      'POKROV используют только выбранные приложения или .exe.',
  };
}
