part of pokrov_app_shell;

class _FirstLaunchGate extends StatelessWidget {
  const _FirstLaunchGate({
    required this.appContext,
    required this.step,
    required this.restoreCodeController,
    required this.busy,
    required this.onNewUser,
    required this.onReturningUser,
    required this.onBack,
    required this.onRedeemCode,
    required this.onOpenTelegram,
    required this.onOpenCabinet,
  });

  final SeedAppContext appContext;
  final _FirstLaunchStep step;
  final TextEditingController restoreCodeController;
  final bool busy;
  final VoidCallback onNewUser;
  final VoidCallback onReturningUser;
  final VoidCallback onBack;
  final VoidCallback onRedeemCode;
  final VoidCallback onOpenTelegram;
  final VoidCallback onOpenCabinet;

  @override
  Widget build(BuildContext context) {
    final p = PokrovPalette.of(context);
    final compactHeight = MediaQuery.sizeOf(context).height < 680;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: p.canvas.withValues(alpha: 0.96),
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(18, compactHeight ? 14 : 28, 18, 28),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: math.max(
                  0,
                  MediaQuery.sizeOf(context).height -
                      MediaQuery.paddingOf(context).vertical -
                      (compactHeight ? 42 : 70),
                ),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: step == _FirstLaunchStep.restore ? 560 : 900,
                  ),
                  child: step == _FirstLaunchStep.restore
                      ? _FirstLaunchRestoreScreen(
                          codeController: restoreCodeController,
                          busy: busy,
                          onBack: onBack,
                          onRedeemCode: onRedeemCode,
                          onOpenTelegram: onOpenTelegram,
                          onOpenCabinet: onOpenCabinet,
                        )
                      : _FirstLaunchChoiceScreen(
                          appContext: appContext,
                          onNewUser: onNewUser,
                          onReturningUser: onReturningUser,
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FirstLaunchChoiceScreen extends StatelessWidget {
  const _FirstLaunchChoiceScreen({
    required this.appContext,
    required this.onNewUser,
    required this.onReturningUser,
  });

  final SeedAppContext appContext;
  final VoidCallback onNewUser;
  final VoidCallback onReturningUser;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = PokrovPalette.of(context);
    return Material(
      key: const ValueKey('first-launch-choice-screen'),
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
        decoration: BoxDecoration(
          color: p.surface.withValues(alpha: 0.98),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: p.line.withValues(alpha: 0.92)),
          boxShadow: [
            BoxShadow(
              color: p.ink.withValues(alpha: 0.055),
              blurRadius: 42,
              offset: const Offset(0, 22),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 700;
            final header = Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const _BrandLockup(markSize: 42, center: true),
                const SizedBox(height: 14),
                Text(
                  'POKROV VPN',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: p.accent,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Добро пожаловать',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: p.ink,
                    fontWeight: FontWeight.w700,
                    height: 1.05,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Text(
                    'Получите ${ruDays(appContext.runtimeProfile.trialDays)} премиум-доступа и включите VPN за один шаг.',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: p.muted,
                      height: 1.34,
                    ),
                  ),
                ),
              ],
            );
            final actions = [
              _FirstLaunchChoiceCard(
                key: const ValueKey('first-launch-new-user'),
                icon: Icons.flash_on_rounded,
                title: 'Я новый пользователь',
                subtitle:
                    '${ruDays(appContext.runtimeProfile.trialDays)} премиум бесплатно',
                primary: true,
                onTap: onNewUser,
              ),
              _FirstLaunchChoiceCard(
                key: const ValueKey('first-launch-returning-user'),
                icon: Icons.key_rounded,
                title: 'У меня уже есть доступ',
                subtitle: 'Восстановить по коду',
                primary: false,
                onTap: onReturningUser,
              ),
            ];
            if (compact) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  header,
                  const SizedBox(height: 24),
                  ...actions.expand(
                    (child) => [child, const SizedBox(height: 12)],
                  ),
                ],
              );
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                header,
                const SizedBox(height: 28),
                Row(
                  children: [
                    for (var index = 0; index < actions.length; index += 1)
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            left: index == 0 ? 0 : 7,
                            right: index == actions.length - 1 ? 0 : 7,
                          ),
                          child: actions[index],
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FirstLaunchChoiceCard extends StatelessWidget {
  const _FirstLaunchChoiceCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.primary,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = PokrovPalette.of(context);
    final background = primary
        ? p.accent.withValues(alpha: 0.09)
        : p.surfaceMuted.withValues(alpha: 0.66);
    final border = primary ? p.accent.withValues(alpha: 0.20) : p.line;
    final iconBackground =
        primary ? p.accent : p.accent.withValues(alpha: 0.10);
    final iconColor =
        primary ? Theme.of(context).colorScheme.onPrimary : p.accent;
    return PokrovSettingsRowPressSurface(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 150),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconBackground,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: iconColor, size: 23),
                ),
                const Spacer(),
                Icon(
                  Icons.chevron_right_rounded,
                  color: primary ? p.accent : p.ink.withValues(alpha: 0.38),
                ),
              ],
            ),
            const SizedBox(height: 34),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                color: p.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: p.muted,
                height: 1.28,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FirstLaunchRestoreScreen extends StatelessWidget {
  const _FirstLaunchRestoreScreen({
    required this.codeController,
    required this.busy,
    required this.onBack,
    required this.onRedeemCode,
    required this.onOpenTelegram,
    required this.onOpenCabinet,
  });

  final TextEditingController codeController;
  final bool busy;
  final VoidCallback onBack;
  final VoidCallback onRedeemCode;
  final VoidCallback onOpenTelegram;
  final VoidCallback onOpenCabinet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = PokrovPalette.of(context);
    return Material(
      key: const ValueKey('first-launch-restore-screen'),
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: p.surface.withValues(alpha: 0.98),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: p.line),
          boxShadow: [
            BoxShadow(
              color: p.ink.withValues(alpha: 0.055),
              blurRadius: 38,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  IconButton(
                    key: const ValueKey('first-launch-back-to-choice'),
                    tooltip: 'Назад',
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: busy ? null : onBack,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Восстановить доступ',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: p.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Введите код из Telegram, сайта, кабинета или письма.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: p.muted,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                key: const ValueKey('first-launch-restore-code-field'),
                controller: codeController,
                enabled: !busy,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) {
                  if (!busy) {
                    onRedeemCode();
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Код активации',
                  hintText: 'POKROV-XXXX-XXXX',
                  prefixIcon: const Icon(Icons.key_rounded),
                  filled: true,
                  fillColor: p.surfaceMuted.withValues(alpha: 0.64),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: p.line),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: p.line),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              PokrovPressable(
                child: FilledButton.icon(
                  key: const ValueKey('first-launch-restore-redeem'),
                  onPressed: busy ? null : onRedeemCode,
                  icon: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle_outline_rounded),
                  label: Text(busy ? 'Проверяем' : 'Продолжить'),
                ),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final telegramButton = OutlinedButton.icon(
                    key: const ValueKey('first-launch-open-telegram-code'),
                    onPressed: busy ? null : onOpenTelegram,
                    icon: const Icon(Icons.send_outlined),
                    label: const Text('Получить код в Telegram'),
                  );
                  final cabinetButton = OutlinedButton.icon(
                    key: const ValueKey('first-launch-open-cabinet'),
                    onPressed: busy ? null : onOpenCabinet,
                    icon: const Icon(Icons.web_outlined),
                    label: const Text('Открыть кабинет'),
                  );
                  if (constraints.maxWidth < 430) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        telegramButton,
                        const SizedBox(height: 10),
                        cabinetButton,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(
                        child: telegramButton,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: cabinetButton,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
