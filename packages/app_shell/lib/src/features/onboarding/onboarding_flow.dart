part of pokrov_app_shell;

enum FirstSessionAcquisitionState { idle, consuming, linked, failed }

enum FirstSessionVpnPermissionState {
  unknown,
  explaining,
  requesting,
  denied,
  granted,
}

/// Owns the bounded first-session journey while host and account actions remain
/// injected by the shell. Opaque acquisition handles are kept only in this
/// in-memory coordinator and are never exposed to presentation or persistence.
class FirstSessionCoordinator {
  FirstSessionCoordinator({required PokrovFirstLaunchStore store})
      : _store = store;

  final PokrovFirstLaunchStore _store;
  _FirstLaunchStep _step = _FirstLaunchStep.choice;
  bool _busy = false;
  bool _exitAnimated = false;
  final Set<String> _processedAcquisitionHandles = <String>{};
  FirstSessionAcquisitionState _acquisitionState =
      FirstSessionAcquisitionState.idle;
  FirstSessionVpnPermissionState _vpnPermissionState =
      FirstSessionVpnPermissionState.unknown;
  bool _firstHomeSeen = false;
  bool _firstVerifiedConnectSeen = false;
  bool _authenticatedAppOpenSeen = false;
  bool _restoredCompletion = false;

  _FirstLaunchStep get _stepForView => _step;
  bool get isChoice => _step == _FirstLaunchStep.choice;
  bool get isReady => _step == _FirstLaunchStep.ready;
  bool get isRestore => _step == _FirstLaunchStep.restore;
  bool get busy => _busy;
  bool get exitAnimated => _exitAnimated;
  FirstSessionAcquisitionState get acquisitionState => _acquisitionState;
  FirstSessionVpnPermissionState get vpnPermissionState => _vpnPermissionState;
  bool get vpnPermissionDenied =>
      _vpnPermissionState == FirstSessionVpnPermissionState.denied;

  Future<bool> loadPersistedCompletion() async {
    var completed = false;
    try {
      completed = await _store.isCompleted();
    } catch (_) {
      completed = false;
    }
    if (completed) {
      _step = _FirstLaunchStep.ready;
      _exitAnimated = false;
      _restoredCompletion = true;
    }
    return completed;
  }

  Future<void> persistCompletion() async {
    try {
      await _store.markCompleted();
    } catch (_) {
      // Local persistence is best-effort; access must not be blocked by it.
    }
  }

  void complete({required bool animated}) {
    _exitAnimated = animated;
    _step = _FirstLaunchStep.ready;
  }

  bool selectTrial() {
    if (_busy) {
      return false;
    }
    complete(animated: true);
    return true;
  }

  bool selectExistingAccess() {
    if (_busy) {
      return false;
    }
    _step = _FirstLaunchStep.restore;
    return true;
  }

  void openRestore() {
    selectExistingAccess();
  }

  void backToChoice() {
    if (_busy) {
      return;
    }
    _step = _FirstLaunchStep.choice;
  }

  bool beginRestore() {
    if (_busy) {
      return false;
    }
    _busy = true;
    return true;
  }

  void finishRestore({required bool succeeded}) {
    _busy = false;
    if (succeeded) {
      complete(animated: true);
    }
  }

  bool rejectInvalidAcquisition() {
    if (_acquisitionState == FirstSessionAcquisitionState.consuming) {
      return false;
    }
    _acquisitionState = FirstSessionAcquisitionState.failed;
    return true;
  }

  bool beginAcquisition(String handle) {
    final opaqueHandle = handle.trim();
    if (opaqueHandle.isEmpty ||
        _acquisitionState == FirstSessionAcquisitionState.consuming ||
        !_processedAcquisitionHandles.add(opaqueHandle)) {
      return false;
    }
    _acquisitionState = FirstSessionAcquisitionState.consuming;
    return true;
  }

  void finishAcquisition({required bool succeeded}) {
    if (_acquisitionState != FirstSessionAcquisitionState.consuming) {
      return;
    }
    _acquisitionState = succeeded
        ? FirstSessionAcquisitionState.linked
        : FirstSessionAcquisitionState.failed;
  }

  bool beginVpnPermissionExplanation() {
    if (_vpnPermissionState == FirstSessionVpnPermissionState.requesting ||
        _vpnPermissionState == FirstSessionVpnPermissionState.granted) {
      return false;
    }
    _vpnPermissionState = FirstSessionVpnPermissionState.explaining;
    return true;
  }

  void dismissVpnPermissionExplanation() {
    if (_vpnPermissionState == FirstSessionVpnPermissionState.explaining) {
      _vpnPermissionState = FirstSessionVpnPermissionState.unknown;
    }
  }

  bool beginVpnPermissionRequest() {
    if (_vpnPermissionState != FirstSessionVpnPermissionState.explaining) {
      return false;
    }
    _vpnPermissionState = FirstSessionVpnPermissionState.requesting;
    return true;
  }

  void finishVpnPermissionRequest({
    required bool granted,
    required bool denied,
  }) {
    if (granted) {
      _vpnPermissionState = FirstSessionVpnPermissionState.granted;
      return;
    }
    _vpnPermissionState = denied
        ? FirstSessionVpnPermissionState.denied
        : FirstSessionVpnPermissionState.unknown;
  }

  bool markFirstHomeSeen() {
    if (_restoredCompletion || _firstHomeSeen) {
      return false;
    }
    _firstHomeSeen = true;
    return true;
  }

  bool markAuthenticatedAppOpenSeen() {
    if (_restoredCompletion || _authenticatedAppOpenSeen) {
      return false;
    }
    _authenticatedAppOpenSeen = true;
    return true;
  }

  bool markFirstVerifiedConnectSeen() {
    if (_firstVerifiedConnectSeen) {
      return false;
    }
    _firstVerifiedConnectSeen = true;
    return true;
  }
}

Future<bool> _showVpnPermissionExplainer(
  BuildContext context, {
  required bool recovery,
}) async {
  final approved = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      key: const ValueKey('vpn-permission-explainer'),
      icon: const Icon(Icons.vpn_key_rounded),
      title: Text(recovery ? 'Разрешение на VPN не выдано' : 'Разрешите VPN'),
      content: Text(
        recovery
            ? 'Android снова покажет системный запрос. Выберите «ОК», чтобы POKROV смог создать защищённое подключение.'
            : 'Сейчас Android покажет системный запрос на VPN. POKROV использует это разрешение только для создания защищённого подключения.',
      ),
      actions: [
        TextButton(
          key: const ValueKey('vpn-permission-not-now'),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Не сейчас'),
        ),
        FilledButton(
          key: const ValueKey('vpn-permission-continue'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(recovery ? 'Повторить запрос' : 'Продолжить'),
        ),
      ],
    ),
  );
  return approved ?? false;
}

class _FirstLaunchGate extends StatelessWidget {
  const _FirstLaunchGate({
    required this.appContext,
    required this.step,
    required this.acquisitionState,
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
  final FirstSessionAcquisitionState acquisitionState;
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
    // Fills whatever slot hosts it (the shell keeps it in a Positioned.fill)
    // so the Welcome Handover transition can wrap it freely.
    return PopScope(
      // Android back on the restore step returns to the new/returning
      // choice instead of backgrounding the app; the choice step keeps
      // the default system behavior.
      canPop: step == _FirstLaunchStep.choice,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !busy) {
          onBack();
        }
      },
      child: SafeArea(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: p.canvas.withValues(alpha: 0.96),
          ),
          child: Stack(
            children: [
              // Single soft brand glow behind the card: calm depth on the
              // canvas plane, never behind dense text.
              Positioned(
                top: -180,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Center(
                    child: Container(
                      width: 520,
                      height: 420,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            p.accentSoft.withValues(alpha: 0.85),
                            p.accentSoft.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SingleChildScrollView(
                padding:
                    EdgeInsets.fromLTRB(18, compactHeight ? 14 : 28, 18, 28),
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
                              acquisitionState: acquisitionState,
                              onNewUser: onNewUser,
                              onReturningUser: onReturningUser,
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Staggered entrance for the welcome card: fade + gentle rise with the
/// Apple-like emphasized curve. Finite by construction and collapsed to an
/// instant pass when [PokrovMotionScope] disables animations, so widget-test
/// `pumpAndSettle` contracts stay bounded.
class _FirstLaunchReveal extends StatelessWidget {
  const _FirstLaunchReveal({
    required this.order,
    required this.child,
  });

  final int order;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final motion = PokrovMotionScope.of(context);
    final duration = motion.duration(
      PokrovMotionTokens.homeReveal + PokrovMotionTokens.short * order,
    );
    if (duration == Duration.zero) {
      return child;
    }
    final start = (order * 0.14).clamp(0.0, 0.6);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: Interval(start, 1, curve: PokrovMotionTokens.emphasized),
      builder: (context, value, staged) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 14),
            child: staged,
          ),
        );
      },
      child: child,
    );
  }
}

class _FirstLaunchChoiceScreen extends StatelessWidget {
  const _FirstLaunchChoiceScreen({
    required this.appContext,
    required this.acquisitionState,
    required this.onNewUser,
    required this.onReturningUser,
  });

  final SeedAppContext appContext;
  final FirstSessionAcquisitionState acquisitionState;
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
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
        decoration: BoxDecoration(
          color: p.surface.withValues(alpha: 0.98),
          borderRadius: BorderRadius.circular(28),
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
                _FirstLaunchReveal(
                  order: 0,
                  child: Column(
                    children: [
                      const _BrandLockup(markSize: 44, center: true),
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
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _FirstLaunchReveal(
                  order: 1,
                  child: Column(
                    children: [
                      Text(
                        'Добро пожаловать',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: p.ink,
                          fontWeight: FontWeight.w700,
                          height: 1.05,
                          letterSpacing: -0.2,
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
                  ),
                ),
                const SizedBox(height: 18),
                _FirstLaunchReveal(
                  order: 2,
                  child: const _FirstLaunchValueStrip(),
                ),
                if (acquisitionState != FirstSessionAcquisitionState.idle) ...[
                  const SizedBox(height: 12),
                  _FirstLaunchReveal(
                    order: 3,
                    child: _FirstLaunchAcquisitionNotice(
                      state: acquisitionState,
                    ),
                  ),
                ],
              ],
            );
            final actions = [
              _FirstLaunchChoiceCard(
                key: const ValueKey('first-launch-new-user'),
                icon: Icons.flash_on_rounded,
                title: 'Начать бесплатно',
                subtitle:
                    '${ruDays(appContext.runtimeProfile.trialDays)} премиум-доступа',
                primary: true,
                compact: compact,
                onTap: onNewUser,
              ),
              _FirstLaunchChoiceCard(
                key: const ValueKey('first-launch-returning-user'),
                icon: Icons.key_rounded,
                title: 'У меня есть код',
                subtitle: 'Восстановить доступ',
                primary: false,
                compact: compact,
                onTap: onReturningUser,
              ),
            ];
            final networkPrivacyNotice = appContext.hostPlatform == HostPlatform.android
                ? Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      'Для диагностики подключения автоматически передаются исходный IP, '
                      'оператор и примерный регион сети. Хранение — до 72 часов. '
                      'История посещённых сайтов не собирается.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(color: p.muted),
                    ),
                  )
                : const SizedBox.shrink();
            if (compact) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  header,
                  const SizedBox(height: 22),
                  for (var index = 0; index < actions.length; index += 1) ...[
                    _FirstLaunchReveal(
                      order: 3 + index,
                      child: actions[index],
                    ),
                    if (index != actions.length - 1) const SizedBox(height: 12),
                  ],
                  networkPrivacyNotice,
                ],
              );
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                header,
                const SizedBox(height: 26),
                _FirstLaunchReveal(
                  order: 3,
                  child: Row(
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
                ),
                networkPrivacyNotice,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FirstLaunchAcquisitionNotice extends StatelessWidget {
  const _FirstLaunchAcquisitionNotice({required this.state});

  final FirstSessionAcquisitionState state;

  @override
  Widget build(BuildContext context) {
    final p = PokrovPalette.of(context);
    final linked = state == FirstSessionAcquisitionState.linked;
    final consuming = state == FirstSessionAcquisitionState.consuming;
    final color = linked
        ? p.success
        : consuming
            ? p.accent
            : p.warning;
    final icon = linked
        ? Icons.check_circle_outline_rounded
        : consuming
            ? Icons.sync_rounded
            : Icons.info_outline_rounded;
    final text = linked
        ? 'Переход подтверждён. Можно продолжить без кода.'
        : consuming
            ? 'Подтверждаем переход… Выбор доступа уже доступен.'
            : 'Переход не применён. Начните бесплатно или восстановите доступ — ничего не потеряно.';
    return Semantics(
      liveRegion: true,
      child: Container(
        key: ValueKey('first-launch-acquisition-${state.name}'),
        constraints: const BoxConstraints(maxWidth: 620),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 9),
            Flexible(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: p.ink,
                      height: 1.3,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Three calm value points under the welcome header — what the user gets
/// before any choice is asked. Wraps on narrow widths.
class _FirstLaunchValueStrip extends StatelessWidget {
  const _FirstLaunchValueStrip();

  @override
  Widget build(BuildContext context) {
    const items = <(IconData, String)>[
      (Icons.power_settings_new_rounded, 'Одна кнопка'),
      (Icons.verified_user_outlined, 'Защита сразу'),
      (Icons.devices_rounded, 'Android и Windows'),
    ];
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (icon, label) in items)
          _FirstLaunchValueChip(icon: icon, label: label),
      ],
    );
  }
}

class _FirstLaunchValueChip extends StatelessWidget {
  const _FirstLaunchValueChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = PokrovPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: p.surfaceMuted.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: p.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: p.accent),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              softWrap: true,
              style: theme.textTheme.bodySmall?.copyWith(
                color: p.ink.withValues(alpha: 0.82),
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
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
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool primary;
  final VoidCallback onTap;

  /// Phones get comfortable thumb-reach rows; the hollow-tower card layout
  /// stays reserved for the wide two-column branch.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = PokrovPalette.of(context);
    final background = primary
        ? p.accentSoft.withValues(alpha: 0.62)
        : p.surfaceMuted.withValues(alpha: 0.66);
    final border = primary ? p.accent.withValues(alpha: 0.26) : p.line;
    final iconBackground =
        primary ? p.accent : p.accent.withValues(alpha: 0.10);
    final iconColor =
        primary ? Theme.of(context).colorScheme.onPrimary : p.accent;
    final iconBox = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: iconBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: primary
            ? [
                BoxShadow(
                  color: p.accent.withValues(alpha: 0.28),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Icon(icon, color: iconColor, size: 23),
    );
    final chevron = Icon(
      Icons.chevron_right_rounded,
      color: primary ? p.accent : p.ink.withValues(alpha: 0.38),
    );
    final titleText = Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.titleMedium?.copyWith(
        color: p.ink,
        fontWeight: FontWeight.w700,
      ),
    );
    final subtitleText = Text(
      subtitle,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodySmall?.copyWith(
        color: p.muted,
        height: 1.28,
      ),
    );
    if (compact) {
      return PokrovSettingsRowPressSurface(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: border),
          ),
          child: Row(
            children: [
              iconBox,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleText,
                    const SizedBox(height: 3),
                    subtitleText,
                  ],
                ),
              ),
              const SizedBox(width: 8),
              chevron,
            ],
          ),
        ),
      );
    }
    return PokrovSettingsRowPressSurface(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 150),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                iconBox,
                const Spacer(),
                chevron,
              ],
            ),
            const SizedBox(height: 34),
            titleText,
            const SizedBox(height: 5),
            subtitleText,
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
    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.6;
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
                'Введите одноразовый код устройства из бота или кабинета. Код активации из Telegram, сайта или письма тоже подойдет.',
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
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) {
                  if (!busy) {
                    onRedeemCode();
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Код входа или активации',
                  hintText: 'ABCD-EFGH или POKROV-…',
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
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: p.accent.withValues(alpha: 0.55),
                      width: 1.4,
                    ),
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
              const SizedBox(height: 16),
              if (largeText)
                Text(
                  'Нет кода под рукой?',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: p.muted,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(child: Divider(color: p.line, height: 1)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        'Нет кода под рукой?',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: p.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: p.line, height: 1)),
                  ],
                ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final telegramButton = OutlinedButton.icon(
                    key: const ValueKey('first-launch-open-telegram-code'),
                    onPressed: busy ? null : onOpenTelegram,
                    icon: const Icon(Icons.send_outlined),
                    label: const Text('Получить код в боте'),
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
