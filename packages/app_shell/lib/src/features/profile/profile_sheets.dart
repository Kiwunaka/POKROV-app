part of pokrov_app_shell;

void _showAdvancedSettingsSheet(
  BuildContext context, {
  required HostPlatform hostPlatform,
  required RouteMode selectedRouteMode,
  required String statusLabel,
  required String warpStatus,
}) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    sheetAnimationStyle: _pokrovSheetAnimationStyle(context),
    builder: (context) {
      return SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
          child: _AdvancedSettingsCard(
            key: const ValueKey('profile-advanced-settings-sheet'),
            hostPlatform: hostPlatform,
            selectedRouteMode: selectedRouteMode,
            statusLabel: statusLabel,
            warpStatus: warpStatus,
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
    isScrollControlled: true,
    sheetAnimationStyle: _pokrovSheetAnimationStyle(context),
    builder: (context) => SafeArea(
      top: false,
      child: Padding(
        // Keeps the code field and submit action above the open keyboard.
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          key: const ValueKey('profile-redeem-sheet'),
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Код активации',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Введите одноразовый код устройства из основного бота или кабинета. Код активации из Telegram или письма тоже подойдет.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: PokrovPalette.of(context).muted,
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
  String? _emptyCodeNotice;

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

  /// Validates before the sheet closes: an empty code keeps the sheet open
  /// and shows an inline notice instead of popping into a dead-end snack.
  void _submit() {
    final code = _controller.text.trim();
    if (code.isEmpty) {
      setState(() {
        _emptyCodeNotice = 'Введите код активации.';
      });
      return;
    }
    widget.onRedeem(code);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const ValueKey('profile-redeem-code-field'),
          controller: _controller,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          onChanged: (value) {
            if (_emptyCodeNotice != null && value.trim().isNotEmpty) {
              setState(() {
                _emptyCodeNotice = null;
              });
            }
          },
          decoration: InputDecoration(
            labelText: 'Код входа или активации',
            hintText: 'ABCD-EFGH или POKROV-…',
            errorText: _emptyCodeNotice,
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          key: const ValueKey('profile-redeem-submit'),
          onPressed: _submit,
          icon: const Icon(Icons.verified_outlined),
          label: const Text('Ввести код'),
        ),
      ],
    );
  }
}

class _AdvancedSettingsCard extends StatelessWidget {
  const _AdvancedSettingsCard({
    super.key,
    required this.hostPlatform,
    required this.selectedRouteMode,
    required this.statusLabel,
    required this.warpStatus,
  });

  final HostPlatform hostPlatform;
  final RouteMode selectedRouteMode;
  final String statusLabel;
  final String warpStatus;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Диагностика',
      lines: const [
        'Безопасная сводка для поддержки: устройство, версия приложения, статус VPN, режим и WARP.',
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SettingsRow(
            key: const ValueKey('advanced-app-version'),
            icon: Icons.info_outline_rounded,
            title: 'Версия',
            value: pokrovClientVersion,
          ),
          const _SettingsRowDivider(),
          _SettingsRow(
            key: const ValueKey('advanced-channel'),
            icon: Icons.science_outlined,
            title: 'Канал',
            value: 'Stable',
          ),
          const _SettingsRowDivider(),
          _SettingsRow(
            key: const ValueKey('advanced-device'),
            icon: Icons.devices_rounded,
            title: 'Устройство',
            value: hostPlatform.label,
          ),
          const _SettingsRowDivider(),
          _SettingsRow(
            key: const ValueKey('advanced-connection-status'),
            icon: Icons.shield_outlined,
            title: 'Статус VPN',
            value: statusLabel,
          ),
          const _SettingsRowDivider(),
          _SettingsRow(
            key: const ValueKey('advanced-route-mode'),
            icon: Icons.alt_route_rounded,
            title: 'Режим',
            value: _routeModeShortLabel(selectedRouteMode),
          ),
          const _SettingsRowDivider(),
          _SettingsRow(
            key: const ValueKey('advanced-warp-status'),
            icon: Icons.privacy_tip_outlined,
            title: 'WARP',
            value: warpStatus,
          ),
        ],
      ),
    );
  }
}

void _showDevicesSheet(
  BuildContext context, {
  required String currentPlatformLabel,
  required Future<ClientDeviceList> Function() onFetchDevices,
  required Future<bool> Function(String deviceId) onRevokeDevice,
  required Future<ClientDevicePairingCode> Function() onIssuePairingCode,
  required Future<bool> Function(String pairingId) onCancelPairingCode,
}) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    sheetAnimationStyle: _pokrovSheetAnimationStyle(context),
    builder: (context) => _DevicesSheet(
      onFetchDevices: onFetchDevices,
      onRevokeDevice: onRevokeDevice,
      onIssuePairingCode: onIssuePairingCode,
      onCancelPairingCode: onCancelPairingCode,
    ),
  );
}

class _DevicesSheet extends StatefulWidget {
  const _DevicesSheet({
    required this.onFetchDevices,
    required this.onRevokeDevice,
    required this.onIssuePairingCode,
    required this.onCancelPairingCode,
  });

  final Future<ClientDeviceList> Function() onFetchDevices;
  final Future<bool> Function(String deviceId) onRevokeDevice;
  final Future<ClientDevicePairingCode> Function() onIssuePairingCode;
  final Future<bool> Function(String pairingId) onCancelPairingCode;

  @override
  State<_DevicesSheet> createState() => _DevicesSheetState();
}

class _DevicesSheetState extends State<_DevicesSheet> {
  late Future<ClientDeviceList> _future;
  String? _revokingId;
  ClientDevicePairingCode? _pairingCode;
  bool _pairingBusy = false;
  String? _pairingError;

  @override
  void initState() {
    super.initState();
    _future = widget.onFetchDevices();
  }

  void _reload() {
    setState(() {
      _future = widget.onFetchDevices();
    });
  }

  Future<void> _issuePairingCode() async {
    if (_pairingBusy) {
      return;
    }
    setState(() {
      _pairingBusy = true;
      _pairingError = null;
    });
    try {
      final code = await widget.onIssuePairingCode();
      if (!mounted) {
        return;
      }
      setState(() {
        _pairingCode = code;
      });
    } on BootstrapFailure catch (error) {
      if (mounted) {
        setState(() {
          _pairingError = error.message;
        });
      }
    } on Object {
      if (mounted) {
        setState(() {
          _pairingError = 'Не удалось создать код устройства.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _pairingBusy = false;
        });
      }
    }
  }

  Future<void> _cancelPairingCode() async {
    final pairing = _pairingCode;
    if (pairing == null || _pairingBusy) {
      return;
    }
    setState(() {
      _pairingBusy = true;
      _pairingError = null;
    });
    try {
      final ok = await widget.onCancelPairingCode(pairing.id);
      if (!mounted) {
        return;
      }
      setState(() {
        if (ok) {
          _pairingCode = null;
        } else {
          _pairingError = 'Не удалось отменить код устройства.';
        }
      });
    } finally {
      if (mounted) {
        setState(() {
          _pairingBusy = false;
        });
      }
    }
  }

  Future<void> _revoke(ClientDeviceInfo device) async {
    final deviceName =
        device.label.trim().isEmpty ? device.platform : device.label;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final tokens = PokrovPalette.of(dialogContext);
        return AlertDialog(
          key: const ValueKey('profile-device-revoke-confirm'),
          title: const Text('Отвязать устройство?'),
          content: Text(
            '«$deviceName» больше не сможет пользоваться вашим доступом POKROV.',
          ),
          actions: [
            TextButton(
              key: const ValueKey('profile-device-revoke-cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Отмена'),
            ),
            TextButton(
              key: const ValueKey('profile-device-revoke-approve'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(foregroundColor: tokens.danger),
              child: const Text('Отвязать'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() {
      _revokingId = device.id;
    });
    final ok = await widget.onRevokeDevice(device.id);
    if (!mounted) {
      return;
    }
    setState(() {
      _revokingId = null;
    });
    if (ok) {
      showPokrovSnack(
        context,
        'Устройство отвязано.',
        tone: PokrovSnackTone.success,
      );
      _reload();
    } else {
      showPokrovSnack(
        context,
        'Не удалось отвязать устройство. Попробуйте еще раз.',
        tone: PokrovSnackTone.danger,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = PokrovPalette.of(context);
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: SingleChildScrollView(
          key: const ValueKey('profile-devices-sheet'),
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Устройства', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'Сеансы, где выполнен вход в ваш аккаунт POKROV.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: tokens.muted,
                      height: 1.35,
                    ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: tokens.surfaceMuted.withValues(alpha: 0.62),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: tokens.line),
                ),
                child: _pairingCode == null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Добавить устройство',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Одноразовый код на 10 минут. Для Android TV его можно ввести вручную.',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: tokens.muted,
                                      height: 1.35,
                                    ),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            key: const ValueKey(
                              'profile-device-pairing-issue',
                            ),
                            onPressed: _pairingBusy
                                ? null
                                : () => unawaited(_issuePairingCode()),
                            icon: _pairingBusy
                                ? const SizedBox.square(
                                    dimension: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.add_link_rounded),
                            label: const Text('Создать код'),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _pairingCode!.code,
                            key: const ValueKey(
                              'profile-device-pairing-code',
                            ),
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 2.2,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Введите в POKROV на новом устройстве. После первого использования код закроется.',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: tokens.muted,
                                      height: 1.35,
                                    ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                key: const ValueKey(
                                  'profile-device-pairing-copy',
                                ),
                                onPressed: () {
                                  Clipboard.setData(
                                    ClipboardData(text: _pairingCode!.code),
                                  );
                                  showPokrovSnack(
                                    context,
                                    'Код скопирован.',
                                    tone: PokrovSnackTone.success,
                                  );
                                },
                                icon: const Icon(Icons.copy_rounded),
                                label: const Text('Скопировать'),
                              ),
                              TextButton(
                                key: const ValueKey(
                                  'profile-device-pairing-cancel',
                                ),
                                onPressed: _pairingBusy
                                    ? null
                                    : () => unawaited(_cancelPairingCode()),
                                child: const Text('Отменить'),
                              ),
                            ],
                          ),
                        ],
                      ),
              ),
              if ((_pairingError ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _pairingError!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: tokens.danger,
                      ),
                ),
              ],
              const SizedBox(height: 14),
              FutureBuilder<ClientDeviceList>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const _MotionSkeletonList(rows: 3);
                  }
                  final items =
                      snapshot.data?.items ?? const <ClientDeviceInfo>[];
                  if (items.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Пока нет других устройств.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: tokens.muted,
                            ),
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (final device in items)
                        _DeviceRow(
                          key: ValueKey('profile-device-${device.id}'),
                          device: device,
                          busy: _revokingId == device.id,
                          onRevoke: device.current
                              ? null
                              : () => unawaited(_revoke(device)),
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

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({
    super.key,
    required this.device,
    required this.busy,
    required this.onRevoke,
  });

  final ClientDeviceInfo device;
  final bool busy;
  final VoidCallback? onRevoke;

  IconData get _platformIcon {
    switch (device.platform.toLowerCase()) {
      case 'windows':
        return Icons.desktop_windows_outlined;
      case 'android':
        return Icons.phone_android_rounded;
      case 'ios':
        return Icons.phone_iphone_rounded;
      case 'macos':
        return Icons.laptop_mac_rounded;
      default:
        return Icons.devices_other_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = PokrovPalette.of(context);
    final lastSeen = _formatClientDate(device.lastSeen);
    final subtitle = <String>[
      device.platform,
      if (lastSeen.isNotEmpty) 'был $lastSeen',
    ].where((item) => item.trim().isNotEmpty).join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: tokens.accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_platformIcon, size: 19, color: tokens.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.label.trim().isEmpty ? device.platform : device.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: tokens.ink,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: tokens.muted,
                          height: 1.25,
                        ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (device.current)
            const PokrovStatusPill(
              label: 'Это устройство',
              icon: Icons.check_circle_outline_rounded,
              tone: PokrovStatusTone.success,
            )
          else if (busy)
            const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            TextButton(
              key: ValueKey('profile-device-revoke-${device.id}'),
              onPressed: onRevoke,
              style: TextButton.styleFrom(foregroundColor: tokens.danger),
              child: const Text('Отвязать'),
            ),
        ],
      ),
    );
  }
}

void _showNotificationsSheet(
  BuildContext context, {
  required List<ClientNotificationItem> notifications,
  required bool usingCache,
  required String cachedAt,
  required Future<void> Function() onRefresh,
  required Future<bool> Function(List<String> ids) onDismiss,
  required void Function(String label, String value) onOpenHandoff,
}) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    sheetAnimationStyle: _pokrovSheetAnimationStyle(context),
    builder: (context) => _NotificationsSheet(
      notifications: notifications,
      usingCache: usingCache,
      cachedAt: cachedAt,
      onRefresh: onRefresh,
      onDismiss: onDismiss,
      onOpenHandoff: onOpenHandoff,
    ),
  );
}

class _NotificationsSheet extends StatelessWidget {
  const _NotificationsSheet({
    required this.notifications,
    required this.usingCache,
    required this.cachedAt,
    required this.onRefresh,
    required this.onDismiss,
    required this.onOpenHandoff,
  });

  final List<ClientNotificationItem> notifications;
  final bool usingCache;
  final String cachedAt;
  final Future<void> Function() onRefresh;
  final Future<bool> Function(List<String> ids) onDismiss;
  final void Function(String label, String value) onOpenHandoff;

  @override
  Widget build(BuildContext context) {
    final tokens = PokrovPalette.of(context);
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: SingleChildScrollView(
          key: const ValueKey('profile-notifications-sheet'),
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Уведомления',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  if (notifications.isNotEmpty)
                    TextButton(
                      key: const ValueKey('profile-notifications-clear'),
                      onPressed: () async {
                        final ids = notifications
                            .map((item) => item.id)
                            .where((id) => id.trim().isNotEmpty)
                            .toList(growable: false);
                        final ok = await onDismiss(ids);
                        if (ok && context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                      child: const Text('Очистить'),
                    ),
                  IconButton(
                    key: const ValueKey('profile-notifications-refresh'),
                    tooltip: 'Обновить',
                    onPressed: () async {
                      await onRefresh();
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              if (usingCache) ...[
                const SizedBox(height: 6),
                Container(
                  key: const ValueKey('profile-notifications-cache-notice'),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: tokens.muted.withValues(alpha: 0.08),
                    borderRadius: PokrovRadii.cardSm,
                    border: Border.all(color: tokens.line),
                  ),
                  child: Text(
                    'Нет свежих данных. Показываем сохранённые уведомления. ${_locationCacheLabel(cachedAt)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: tokens.muted,
                          height: 1.35,
                        ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              if (notifications.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Text(
                    'Пока нет уведомлений.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: tokens.muted,
                        ),
                  ),
                )
              else
                for (final item in notifications)
                  _NotificationRow(
                    key: ValueKey('profile-notification-${item.id}'),
                    item: item,
                    onOpenHandoff: onOpenHandoff,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({
    super.key,
    required this.item,
    required this.onOpenHandoff,
  });

  final ClientNotificationItem item;
  final void Function(String label, String value) onOpenHandoff;

  IconData get _kindIcon {
    switch (item.kind.toLowerCase()) {
      case 'access':
        return Icons.verified_user_outlined;
      case 'payment':
        return Icons.credit_card_rounded;
      case 'update':
        return Icons.system_update_alt_rounded;
      case 'promo':
        return Icons.card_giftcard_outlined;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = PokrovPalette.of(context);
    final created = _formatClientDate(item.createdAt);
    final href = item.ctaHref;
    final showCta = href != null && item.ctaLabel.trim().isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:
            item.read ? tokens.surface : tokens.accent.withValues(alpha: 0.06),
        borderRadius: PokrovRadii.card,
        border: Border.all(
          color: item.read ? tokens.line : tokens.accent.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_kindIcon, size: 18, color: tokens.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.title.trim().isEmpty ? 'POKROV' : item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: tokens.ink,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              if (created.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  created,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: tokens.muted,
                      ),
                ),
              ],
            ],
          ),
          if (item.body.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              item.body,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: tokens.muted,
                    height: 1.32,
                  ),
            ),
          ],
          if (showCta) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: ValueKey('profile-notification-cta-${item.id}'),
                onPressed: () {
                  Navigator.of(context).maybePop();
                  onOpenHandoff('notification', href.toString());
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 44),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(item.ctaLabel),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
