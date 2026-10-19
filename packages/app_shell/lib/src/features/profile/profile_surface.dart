part of pokrov_app_shell;

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({
    required this.appContext,
    required this.freeProfileAccess,
    required this.selectedRouteMode,
    required this.hasProvisionedAccess,
    required this.onOpenHandoff,
    required this.onPromoEvent,
    required this.onOpenSupportHub,
    required this.onOpenDiagnostics,
    required this.onShareApp,
    required this.appShareBusy,
    required this.onCreateTelegramLink,
    required this.onCheckTelegramBonus,
    required this.onClaimTelegramBonus,
    required this.telegramBonusStatus,
    required this.telegramBonusBusy,
    required this.telegramBonusCanClaim,
    required this.telegramBonusError,
    required this.bonusSummary,
    required this.bonusSummaryBusy,
    required this.bonusSummaryError,
    required this.bonusRewardBusy,
    required this.onRefreshBonusSummary,
    required this.onSpinWheel,
    required this.onCheckInCalendar,
    required this.warpPolicy,
    required this.warpRuntimeConsent,
    required this.warpBusy,
    required this.connectionPresentation,
    required this.runtimeHeadline,
    required this.onOpenWarp,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.interfaceMode,
    required this.onInterfaceModeChanged,
    required this.subscriptionInfo,
    required this.systemSurfacePreferences,
    required this.onSystemSurfacePreferencesChanged,
    required this.windowsShellPreferences,
    required this.onWindowsShellPreferencesChanged,
    required this.onOpenNotificationSettings,
    required this.notifications,
    required this.notificationsUnread,
    required this.notificationsBusy,
    required this.notificationsUsingCache,
    required this.notificationsCachedAt,
    required this.onOpenNotifications,
    required this.onRefreshNotifications,
    required this.onDismissNotifications,
    required this.onFetchDevices,
    required this.onRevokeDevice,
    required this.onIssuePairingCode,
    required this.onCancelPairingCode,
  });

  final SeedAppContext appContext;
  final FreeProfileAccess? freeProfileAccess;
  final RouteMode selectedRouteMode;
  final bool hasProvisionedAccess;
  final void Function(String label, String value) onOpenHandoff;
  final void Function(AppFirstPromoSlot slot, String eventName) onPromoEvent;
  final VoidCallback onOpenSupportHub;
  final VoidCallback onOpenDiagnostics;
  final Future<void> Function() onShareApp;
  final bool appShareBusy;
  final VoidCallback onCreateTelegramLink;
  final VoidCallback onCheckTelegramBonus;
  final VoidCallback onClaimTelegramBonus;
  final String telegramBonusStatus;
  final bool telegramBonusBusy;
  final bool telegramBonusCanClaim;
  final String? telegramBonusError;

  /// Live getter into the shell state so the rewards sheet stays current
  /// while it is open (the sheet lives outside this widget's subtree).
  final AppFirstBonusSummary? Function() bonusSummary;
  final bool bonusSummaryBusy;
  final String? bonusSummaryError;
  final bool Function() bonusRewardBusy;
  final Future<void> Function() onRefreshBonusSummary;
  final Future<AppFirstBonusRewardResult?> Function() onSpinWheel;
  final Future<void> Function() onCheckInCalendar;
  final WarpRuntimePolicy warpPolicy;
  final bool warpRuntimeConsent;
  final bool warpBusy;
  final ConnectionPresentation connectionPresentation;
  final String? runtimeHeadline;
  final Future<void> Function() onOpenWarp;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final PokrovInterfaceMode interfaceMode;
  final ValueChanged<PokrovInterfaceMode> onInterfaceModeChanged;
  final ClientSubscriptionInfo? subscriptionInfo;
  final PokrovSystemSurfacePreferences systemSurfacePreferences;
  final Future<bool> Function(PokrovSystemSurfacePreferences preferences)
      onSystemSurfacePreferencesChanged;
  final PokrovWindowsShellPreferences windowsShellPreferences;
  final Future<bool> Function(PokrovWindowsShellPreferences preferences)
      onWindowsShellPreferencesChanged;
  final Future<bool> Function() onOpenNotificationSettings;
  final List<ClientNotificationItem> notifications;
  final int notificationsUnread;
  final bool notificationsBusy;
  final bool notificationsUsingCache;
  final String notificationsCachedAt;
  final VoidCallback onOpenNotifications;
  final Future<void> Function() onRefreshNotifications;
  final Future<bool> Function(List<String> ids) onDismissNotifications;
  final Future<ClientDeviceList> Function() onFetchDevices;
  final Future<bool> Function(String deviceId) onRevokeDevice;
  final Future<ClientDevicePairingCode> Function() onIssuePairingCode;
  final Future<bool> Function(String pairingId) onCancelPairingCode;

  String _bonusHubValue() {
    final summary = bonusSummary();
    if (bonusSummaryBusy) {
      return 'Обновляем';
    }
    if (summary == null) {
      return _bonusPaidRequired(null)
          ? _PlatformProductCopy.telegramRewardLabel
          : 'Открыть';
    }
    if (_bonusPaidRequired(summary)) {
      if (summary.channelBonusClaimed) {
        return 'Telegram получен';
      }
      final bonusDays = _availableTelegramBonusDays(summary);
      return bonusDays > 0 ? '+${ruDays(bonusDays)}' : 'Telegram';
    }
    final claimed = summary.channelBonusClaimed;
    final bonusDays = claimed
        ? summary.channelBonusPremiumDays
        : _availableTelegramBonusDays(summary);
    final parts = <String>[
      if (bonusDays > 0) '+${ruDays(bonusDays)}',
      if (summary.referralCount > 0) '${summary.referralCount} реф.',
    ];
    return parts.isEmpty ? 'Открыть' : parts.join(' · ');
  }

  bool _bonusPaidRequired(AppFirstBonusSummary? summary) {
    if (summary?.rewardAccess.paidRequired ?? false) {
      return true;
    }
    return _effectiveAccessLane(appContext, subscriptionInfo) ==
        AccessLane.trialPremium;
  }

  void _devices(BuildContext context) => _showDevicesSheet(
    context, currentPlatformLabel: appContext.hostPlatform.label,
    onFetchDevices: onFetchDevices, onRevokeDevice: onRevokeDevice,
    onIssuePairingCode: onIssuePairingCode, onCancelPairingCode: onCancelPairingCode,
  );

  void _account(BuildContext context) {
    final telegramLinked = subscriptionInfo?.telegramLinked == true;
    final emailLinked = subscriptionInfo?.emailVerified == true;
    ui.showPokrovSheet<void>(context, (context) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Telegram и почта', style: ui.pokrovTextStyle(context, ui.PokrovText.heading)),
        ui.PokrovRow(title: 'Telegram', value: telegramLinked ? 'Привязан' : 'Привязать',
          onTap: telegramLinked || telegramBonusBusy ? null : onCreateTelegramLink),
        ui.PokrovRow(title: 'Почта', value: emailLinked ? 'Подтверждена' : 'Добавить',
          onTap: emailLinked ? null : () => _showEmailRecoverySheet(context,
            appContext: appContext, onOpenHandoff: onOpenHandoff)),
        ui.PokrovRow(title: 'Личный кабинет', onTap: () => onOpenHandoff('cabinet', appContext.cabinetUrl)),
      ]),
    ));
  }

  void _about(BuildContext context) => ui.showPokrovSheet<void>(context, (context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('POKROV ' + pokrovClientVersion, style: ui.pokrovTextStyle(context, ui.PokrovText.heading)),
      Text('Обновления приходят в уведомления.', style: ui.pokrovTextStyle(context, ui.PokrovText.body)),
      ui.PokrovRow(title: 'Публичная оферта', onTap: () => onOpenHandoff('legal', PlatformProductFacts.offerUrl)),
      ui.PokrovRow(title: 'Конфиденциальность', onTap: () => onOpenHandoff('legal', PlatformProductFacts.privacyUrl)),
      ui.PokrovRow(title: 'Официальные релизы', onTap: () => onOpenHandoff('release', PlatformProductFacts.githubReleasesUrl)),
    ]),
  ));

  @override
  Widget build(BuildContext context) {
    final summary = bonusSummary();
    final accountPromo = (summary?.promoSlots.visibleForPlacement('account') ?? const <AppFirstPromoSlot>[])
        .where(_isRenderableHomePromoSlot).firstOrNull;
    final linked = <String>[
      if (subscriptionInfo?.telegramLinked == true) 'Telegram',
      if (subscriptionInfo?.emailVerified == true) 'почта',
    ];
    final expires = _formatClientDate(subscriptionInfo?.expiresAt ?? '');
    return RefreshIndicator(
      onRefresh: () async => Future.wait<void>([onRefreshBonusSummary(), onRefreshNotifications()]),
      child: ui.ProfileScreen(
        data: ui.ProfileViewData(
          mode: interfaceMode == PokrovInterfaceMode.advanced ? ui.InterfaceMode.advanced : ui.InterfaceMode.simple,
          accessBadge: 'Доступ',
          accessTitle: _accessMainLabel(appContext, summary, freeProfileAccess, subscriptionInfo),
          accessDetail: _freeProfileAccessNotice(freeProfileAccess) ??
              (expires.isEmpty ? '' : 'До ' + expires),
          accountLinked: linked.isEmpty ? 'Добавить' : linked.join(' · '),
          devices: 'Управлять',
          theme: _themeModeLabel(themeMode),
          bonuses: _bonusHubValue(),
          version: pokrovClientVersion,
        ),
        adSlot: accountPromo == null ? null : _HomeAdminPromoCard(slot: accountPromo, compact: false,
          keyPrefix: 'profile-promo', onOpenHandoff: onOpenHandoff, onPromoEvent: onPromoEvent),
        onRenew: () => _showSubscriptionSheet(context, appContext: appContext,
          hasProvisionedAccess: hasProvisionedAccess, subscriptionInfo: subscriptionInfo,
          onOpenHandoff: onOpenHandoff),
        onModeChanged: (mode) => onInterfaceModeChanged(mode == ui.InterfaceMode.simple
            ? PokrovInterfaceMode.simple : PokrovInterfaceMode.advanced),
        onAccount: () => _account(context),
        onDevices: () => _devices(context),
        onLoginCode: () => _devices(context),
        onActivate: () => _showRedeemSheet(context, hintCode: appContext.redeemHint,
          onRedeem: (code) => onOpenHandoff('redeem', code)),
        onTheme: () => _showThemeModeSheet(context, selected: themeMode, onChanged: onThemeModeChanged),
        onNotifications: () {
          onOpenNotifications();
          _showNotificationsSheet(context, notifications: notifications,
            usingCache: notificationsUsingCache, cachedAt: notificationsCachedAt,
            onRefresh: onRefreshNotifications, onDismiss: onDismissNotifications,
            onOpenHandoff: onOpenHandoff);
        },
        onHelp: onOpenSupportHub,
        onDiagnostics: onOpenDiagnostics,
        onBonuses: () => _showRewardsHubSheet(context, summary: bonusSummary,
          rewardBusy: bonusRewardBusy, paidRequired: _bonusPaidRequired(summary),
          onRefreshBonusSummary: onRefreshBonusSummary, onSpinWheel: onSpinWheel,
          onTelegramBonus: telegramBonusBusy ? null
              : telegramBonusCanClaim ? onClaimTelegramBonus : onCheckTelegramBonus,
          onCheckInCalendar: onCheckInCalendar, onOpenHandoff: onOpenHandoff, onPromoEvent: onPromoEvent),
        onAbout: () => _about(context),
        onShare: appShareBusy ? null : () => unawaited(onShareApp()),
        onWarp: interfaceMode == PokrovInterfaceMode.advanced ? () => unawaited(onOpenWarp()) : null,
        onAppSettings: appContext.hostPlatform == HostPlatform.windows
            ? () => _showWindowsShellPreferencesSheet(context, preferences: windowsShellPreferences,
                onChanged: onWindowsShellPreferencesChanged)
            : appContext.hostPlatform == HostPlatform.android
                ? () => _showSystemSurfacePreferencesSheet(context, onOpenNotificationSettings: onOpenNotificationSettings)
                : null,
      ),
    );
  }
}

class _SettingsRowDivider extends StatelessWidget {
  const _SettingsRowDivider();

  @override
  Widget build(BuildContext context) {
    final p = PokrovPalette.of(context);
    return Divider(height: 1, thickness: 1, indent: 46, color: p.line);
  }
}

/// Screen-Time-style living counter for entitlement numbers: counts old→new
/// once per data change (the first arrival counts up from zero), rebuilds
/// its text every frame so RU plural forms track the interpolated value, and
/// lands with one soft spring pulse. Static under reduced motion or when the
/// target is zero — bad news is never dramatized.
String _themeModeLabel(ThemeMode mode) {
  return switch (mode) {
    ThemeMode.system => 'Системная',
    ThemeMode.light => 'Светлая',
    ThemeMode.dark => 'Тёмная',
  };
}

void _showThemeModeSheet(
  BuildContext context, {
  required ThemeMode selected,
  required ValueChanged<ThemeMode> onChanged,
}) {
  void select(ThemeMode mode) {
    // Apply immediately so the springy checkmark is visible, then let the
    // sheet leave once the selection has settled. The settle delay follows
    // the motion scope: under reduced motion the sheet pops right away.
    onChanged(mode);
    final settle = _MotionScope.of(
      context,
    ).duration(const Duration(milliseconds: 320));
    Future<void>.delayed(settle, () {
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    sheetAnimationStyle: _pokrovSheetAnimationStyle(context),
    builder: (context) => SafeArea(
      top: false,
      child: Padding(
        key: const ValueKey('profile-theme-sheet'),
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Тема', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'POKROV может следовать системе или всегда открываться в выбранном оформлении.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: PokrovPalette.of(context).muted,
                    height: 1.35,
                  ),
            ),
            const SizedBox(height: 14),
            PokrovCheckRow(
              key: const ValueKey('profile-theme-system'),
              icon: Icons.brightness_auto_outlined,
              title: 'Системная',
              selected: selected == ThemeMode.system,
              onTap: () => select(ThemeMode.system),
            ),
            PokrovCheckRow(
              key: const ValueKey('profile-theme-light'),
              icon: Icons.light_mode_outlined,
              title: 'Светлая',
              selected: selected == ThemeMode.light,
              onTap: () => select(ThemeMode.light),
            ),
            PokrovCheckRow(
              key: const ValueKey('profile-theme-dark'),
              icon: Icons.dark_mode_outlined,
              title: 'Тёмная',
              selected: selected == ThemeMode.dark,
              onTap: () => select(ThemeMode.dark),
            ),
          ],
        ),
      ),
    ),
  );
}

void _showSystemSurfacePreferencesSheet(
  BuildContext context, {
  required Future<bool> Function() onOpenNotificationSettings,
}) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    sheetAnimationStyle: _pokrovSheetAnimationStyle(context),
    builder: (sheetContext) => SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          22,
          4,
          22,
          24 + MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: Column(
          key: const ValueKey('profile-system-surfaces-sheet'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Шторка и VPN-уведомление',
              style: Theme.of(sheetContext).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Android получает только общий статус защиты. Страна, маршрут, приложения, узел и скорость доступны только внутри разблокированного POKROV.',
              style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                    color: PokrovPalette.of(sheetContext).muted,
                    height: 1.35,
                  ),
            ),
            const SizedBox(height: 16),
            Text(
              'Быстрая кнопка',
              style: Theme.of(sheetContext).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Если плитки POKROV нет: раскройте шторку, нажмите «Изменить» и перетащите POKROV в активные кнопки.',
              style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                    color: PokrovPalette.of(sheetContext).muted,
                    height: 1.35,
                  ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const ValueKey(
                  'system-surface-notification-settings-action',
                ),
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  unawaited(onOpenNotificationSettings());
                },
                icon: const Icon(Icons.settings_outlined),
                label: const Text('Настройки уведомлений Android'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void _showWindowsShellPreferencesSheet(
  BuildContext context, {
  required PokrovWindowsShellPreferences preferences,
  required Future<bool> Function(PokrovWindowsShellPreferences preferences)
      onChanged,
}) {
  var current = preferences;
  var busy = false;

  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    sheetAnimationStyle: _pokrovSheetAnimationStyle(context),
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) {
        Future<void> save(PokrovWindowsShellPreferences next) async {
          if (busy) {
            return;
          }
          setSheetState(() => busy = true);
          final saved = await onChanged(next);
          if (!sheetContext.mounted) {
            return;
          }
          setSheetState(() {
            if (saved) {
              current = next;
            }
            busy = false;
          });
          if (!saved) {
            showPokrovSnack(
              sheetContext,
              'Не удалось сохранить настройки Windows.',
              tone: PokrovSnackTone.danger,
            );
          }
        }

        Widget toggleRow({
          required Key key,
          required String title,
          required String description,
          required bool value,
          required PokrovWindowsShellPreferences Function(bool value) next,
        }) {
          return Padding(
            key: key,
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(sheetContext).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        description,
                        style: Theme.of(sheetContext)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                              color: PokrovPalette.of(sheetContext).muted,
                              height: 1.3,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                PokrovSwitch(
                  value: value,
                  onChanged: busy
                      ? null
                      : (value) {
                          unawaited(save(next(value)));
                        },
                ),
              ],
            ),
          );
        }

        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              22,
              4,
              22,
              24 + MediaQuery.viewInsetsOf(sheetContext).bottom,
            ),
            child: Column(
              key: const ValueKey('profile-windows-shell-sheet'),
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'POKROV в Windows',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Автозапуск не включает VPN сам. Системный туннель запросит права Windows только при подключении.',
                  style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                        color: PokrovPalette.of(sheetContext).muted,
                        height: 1.35,
                      ),
                ),
                const SizedBox(height: 8),
                toggleRow(
                  key: const ValueKey('windows-launch-at-login-toggle'),
                  title: 'Запускать вместе с Windows',
                  description:
                      'POKROV откроется после входа в систему, но подключение останется под вашим контролем.',
                  value: current.launchAtLogin,
                  next: (value) => current.copyWith(launchAtLogin: value),
                ),
                const Divider(height: 1),
                toggleRow(
                  key: const ValueKey('windows-close-to-tray-toggle'),
                  title: 'Крестик сворачивает в трей',
                  description:
                      'Если выключить, крестик полностью закроет POKROV. Пункт «Выход» в трее работает всегда.',
                  value: current.closeToTray,
                  next: (value) => current.copyWith(closeToTray: value),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

String _formatClientDate(String iso) {
  final parsed = DateTime.tryParse(iso.trim());
  if (parsed == null) {
    return '';
  }
  final local = parsed.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(local.day)}.${two(local.month)}.${local.year}';
}

void _showSubscriptionSheet(
  BuildContext context, {
  required SeedAppContext appContext,
  required bool hasProvisionedAccess,
  required ClientSubscriptionInfo? subscriptionInfo,
  required void Function(String label, String value) onOpenHandoff,
}) {
  final plans = subscriptionInfo?.plans ?? const <ClientSubscriptionPlan>[];
  var selected = plans.isEmpty ? '' : plans.first.id;
  final renewUrl = subscriptionInfo?.renewUrl;
  final renewTarget = renewUrl != null && renewUrl.toString().trim().isNotEmpty
      ? renewUrl.toString() : appContext.checkoutUrl;
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (routeContext) =>
    StatefulBuilder(builder: (context, setRouteState) => ui.RenewScreen(
      data: ui.RenewViewData(
        current: _accessMainLabel(appContext, null, null, subscriptionInfo),
        plans: [for (final plan in plans) ui.PlanOption(
          id: plan.id, short: plan.title, title: plan.title, price: plan.price,
          perMonth: '', saving: '',
        )],
        selectedId: selected, introOffer: '',
      ),
      onSelect: (id) => setRouteState(() => selected = id),
      onPay: () {
        Navigator.of(routeContext).pop();
        onOpenHandoff('checkout', renewTarget);
      },
      onBack: () => Navigator.of(routeContext).pop(),
      onActivationCode: () => _showRedeemSheet(context, hintCode: appContext.redeemHint,
        onRedeem: (code) => onOpenHandoff('redeem', code)),
    )),
  ));
}

void _showEmailRecoverySheet(
  BuildContext context, {
  required SeedAppContext appContext,
  required void Function(String label, String value) onOpenHandoff,
}) {
  final emailUrl = Uri.parse(
    appContext.cabinetUrl,
  ).replace(path: '/account/email');
  final recoveryUrl = Uri.parse(
    appContext.cabinetUrl,
  ).replace(path: '/auth/recovery');
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    sheetAnimationStyle: _pokrovSheetAnimationStyle(context),
    builder: (context) => SafeArea(
      top: false,
      child: SingleChildScrollView(
        key: const ValueKey('profile-email-recovery-sheet'),
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Email и восстановление',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Email нужен для восстановления доступа и входа в кабинет. Все действия открываются через короткую защищенную сессию.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: PokrovPalette.of(context).muted,
                    height: 1.35,
                  ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  key: const ValueKey('profile-email-add-action'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    onOpenHandoff('download', emailUrl.toString());
                  },
                  icon: const Icon(Icons.alternate_email_rounded),
                  label: const Text('Добавить email'),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('profile-email-cabinet-action'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    onOpenHandoff('cabinet', appContext.cabinetUrl);
                  },
                  icon: const Icon(Icons.web_outlined),
                  label: const Text('Кабинет'),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('profile-email-recovery-action'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    onOpenHandoff('download', recoveryUrl.toString());
                  },
                  icon: const Icon(Icons.lock_reset_rounded),
                  label: const Text('Восстановить'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
