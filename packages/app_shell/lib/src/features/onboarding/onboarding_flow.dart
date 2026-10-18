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
  Widget build(BuildContext context) => ui.StartScreen(
    key: const ValueKey('first-launch-choice-screen'),
    onStart: onNewUser, onHaveCode: onReturningUser,
    offer: ruDays(appContext.runtimeProfile.trialDays) + ' бесплатно. Карта не нужна.\nВключается одной кнопкой.',
    showPrivacyNotice: appContext.hostPlatform == HostPlatform.android,
    notice: acquisitionState == FirstSessionAcquisitionState.idle ? null
        : _FirstLaunchAcquisitionNotice(state: acquisitionState),
  );
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
