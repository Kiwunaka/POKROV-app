part of pokrov_app_shell;

void _showAdvancedSettingsSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: _SeedPalette.surface,
    builder: (context) {
      return const SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(18, 0, 18, 24),
          child: _AdvancedSettingsCard(
            key: ValueKey('profile-advanced-settings-sheet'),
          ),
        ),
      );
    },
  );
}

void _showRedeemSheet(
  BuildContext context, {
  required String hintCode,
  required ValueChanged<String> onRedeem,
}) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: _SeedPalette.surface,
    builder: (context) => SafeArea(
      top: false,
      child: SingleChildScrollView(
        key: const ValueKey('profile-redeem-sheet'),
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Код активации',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: _SeedPalette.ink,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Введите код из приложения, кабинета, Telegram или письма.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _SeedPalette.muted,
                    height: 1.35,
                  ),
            ),
            const SizedBox(height: 14),
            _RedeemFields(
              hintCode: hintCode,
              onRedeem: (code) {
                Navigator.of(context).pop();
                onRedeem(code);
              },
            ),
          ],
        ),
      ),
    ),
  );
}

class _RedeemFields extends StatefulWidget {
  const _RedeemFields({
    required this.hintCode,
    required this.onRedeem,
  });

  final String hintCode;
  final ValueChanged<String> onRedeem;

  @override
  State<_RedeemFields> createState() => _RedeemFieldsState();
}

class _RedeemFieldsState extends State<_RedeemFields> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.hintCode);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const ValueKey('profile-redeem-code-field'),
          controller: _controller,
          decoration: const InputDecoration(
            labelText: 'Код активации',
            hintText: 'POKROV-XXXX-XXXX',
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          key: const ValueKey('profile-redeem-submit'),
          onPressed: () => widget.onRedeem(_controller.text.trim()),
          icon: const Icon(Icons.verified_outlined),
          label: const Text('Ввести код'),
        ),
      ],
    );
  }
}

class _AdvancedSettingsCard extends StatelessWidget {
  const _AdvancedSettingsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Диагностика',
      lines: const [
        'Информация, которая помогает поддержке быстрее разобраться.',
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _SettingsRow(
            key: ValueKey('advanced-app-version'),
            icon: Icons.info_outline_rounded,
            title: 'Версия приложения',
            value: _pokrovAppVersion,
          ),
          _SettingsRow(
            key: ValueKey('advanced-runtime-core'),
            icon: Icons.memory_rounded,
            title: 'Core',
            value: 'sing-box',
          ),
          _SettingsRow(
            key: ValueKey('advanced-windows-route'),
            icon: Icons.desktop_windows_outlined,
            title: 'Windows-подключение',
            value: 'Через настройки Windows',
          ),
          _SettingsRow(
            key: ValueKey('advanced-tun-status'),
            icon: Icons.apps_rounded,
            title: 'Выбранные процессы',
            value: 'Учитываются',
          ),
          _SettingsRow(
            key: ValueKey('advanced-xray-fallback'),
            icon: Icons.construction_rounded,
            title: 'Совместимый режим',
            value: 'По запросу',
          ),
          _SettingsRow(
            key: ValueKey('advanced-support-diagnostics'),
            icon: Icons.support_agent_rounded,
            title: 'Логи и диагностика',
            value: 'В чате поддержки',
          ),
        ],
      ),
    );
  }
}
