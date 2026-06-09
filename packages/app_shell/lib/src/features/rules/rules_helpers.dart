part of pokrov_app_shell;

class _PresetRow extends StatelessWidget {
  const _PresetRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.statusLabel,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final String statusLabel;

  @override
  Widget build(BuildContext context) {
    return _SettingsRow(
      icon: icon,
      title: title,
      value: statusLabel,
      onTap: () => _showInfoSheet(
        context,
        title: title,
        lines: [
          subtitle,
          enabled
              ? 'Эта настройка уже работает в текущих правилах.'
              : 'POKROV включит настройку после проверки.',
        ],
      ),
    );
  }
}

IconData _rulesPresetIcon(String id) {
  return switch (id) {
    'ru-banks' => Icons.account_balance_outlined,
    'gosuslugi' => Icons.verified_user_outlined,
    'marketplaces' => Icons.shopping_bag_outlined,
    'messengers' => Icons.forum_outlined,
    'ru-region' => Icons.travel_explore_outlined,
    'local-network' => Icons.router_outlined,
    'full-tunnel' => Icons.public_outlined,
    'selected-apps' => Icons.add_box_outlined,
    _ => Icons.rule_folder_outlined,
  };
}

String _rulesPresetStatusLabel(RulesPresetState state) {
  return switch (state) {
    RulesPresetState.enabled => 'Активно',
    RulesPresetState.staged => 'Скоро',
    RulesPresetState.locked => 'Пока нельзя',
  };
}
