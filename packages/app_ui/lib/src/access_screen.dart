import 'package:flutter/material.dart';

import 'brand.dart';
import 'models.dart';
import 'tokens.dart';
import 'widgets.dart';

/// «Доступ»: how much access is left, the next useful step, devices and
/// codes, then bonuses and sharing. Every row says what it is for.
class AccessScreen extends StatelessWidget {
  const AccessScreen({
    super.key,
    required this.data,
    required this.onRenew,
    this.accessActionLabel = 'Продлить',
    this.steps = const <NextStepTip>[],
    this.onStep,
    this.onDevices,
    this.onAddDevice,
    this.onActivate,
    this.onAccount,
    this.onBonuses,
    this.onTelegramProxy,
    this.onShare,
    this.adSlot,
  });

  final AccessViewData data;
  final VoidCallback onRenew;
  final String accessActionLabel;
  final List<NextStepTip> steps;
  final ValueChanged<int>? onStep;
  final VoidCallback? onDevices;
  final VoidCallback? onAddDevice;
  final VoidCallback? onActivate;
  final VoidCallback? onAccount;
  final VoidCallback? onBonuses;
  final VoidCallback? onTelegramProxy;
  final VoidCallback? onShare;
  final Widget? adSlot;

  @override
  Widget build(BuildContext context) {
    final device = [
      if (onDevices != null) (Icons.devices_rounded, 'Устройства', 'Где ты вошёл в POKROV', onDevices),
      if (onAddDevice != null) (Icons.add_to_home_screen_rounded, 'Добавить устройство', 'Создать «Код для входа» для нового устройства', onAddDevice),
      if (onActivate != null) (Icons.key_rounded, 'Ввести код', '«Код для входа» или «Код активации»', onActivate),
      if (onAccount != null) (Icons.alternate_email_rounded, 'Telegram и почта', 'Чтобы не потерять доступ', onAccount),
    ];
    final more = [
      if (onBonuses != null) (Icons.card_giftcard_rounded, 'Бонусы и друзья', 'Дополнительные дни к доступу', onBonuses),
      if (onTelegramProxy != null) (Icons.send_rounded, 'Telegram-прокси', 'Бесплатно ускоряет Telegram', onTelegramProxy),
      if (onShare != null) (Icons.ios_share_rounded, 'Поделиться приложением', 'Отправить POKROV другу', onShare),
    ];
    Widget group(List<(IconData, String, String, VoidCallback?)> rows) => PokrovCard(
      child: Column(children: [
        for (final (i, row) in rows.indexed) PokrovEntryRow(
          icon: row.$1, title: row.$2, hint: row.$3, onTap: row.$4,
          value: row.$2 == 'Бонусы и друзья' && data.bonuses.isNotEmpty ? data.bonuses
              : row.$2 == 'Telegram и почта' && data.accountLinked.isNotEmpty ? data.accountLinked : null,
          divider: i < rows.length - 1,
        ),
      ]),
    );
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 112),
        children: [
          Text('Доступ', style: pokrovTextStyle(context, PokrovText.title), textScaler: pokrovTitleScaler(context)),
          SizedBox(height: 12),
          _AccessCard(data: data, onRenew: onRenew, actionLabel: accessActionLabel),
          if (adSlot != null) Padding(padding: const EdgeInsets.only(top: 12), child: adSlot!),
          if (steps.isNotEmpty) ...[
            SectionLabel('Твой следующий шаг'),
            PokrovCard(child: Column(children: [
              for (final (i, step) in steps.indexed) PokrovEntryRow(
                icon: step.icon, title: step.title, hint: step.text,
                onTap: onStep == null ? null : () => onStep!(i), divider: i < steps.length - 1,
              ),
            ])),
          ],
          if (device.isNotEmpty) ...[SectionLabel('Устройства и вход'), group(device)],
          if (more.isNotEmpty) ...[SectionLabel('Ещё'), group(more)],
        ],
      ),
    );
  }
}

class _AccessCard extends StatelessWidget {
  const _AccessCard({required this.data, required this.onRenew, required this.actionLabel});

  final AccessViewData data;
  final VoidCallback onRenew;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(color: pokrovColor(context, PokrovColors.accent), borderRadius: BorderRadius.circular(PokrovRadii.card)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PokrovMark(size: 28, color: pokrovOnAccent(context)),
              SizedBox(width: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(color: pokrovOnAccent(context).withValues(alpha: 0.18), borderRadius: BorderRadius.circular(999)),
                child: Text(data.accessBadge, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: pokrovOnAccent(context))),
              ),
              SizedBox(width: 8),
              Expanded(child: Text(data.accessTitle, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: pokrovOnAccent(context)))),
            ],
          ),
          SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data.accessDetail, style: TextStyle(fontSize: 14, color: pokrovOnAccent(context).withValues(alpha: 0.92))),
                    SizedBox(height: 8),
                    if (data.accessProgress != null) ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: data.accessProgress!),
                        duration: Duration(milliseconds: 900),
                        curve: PokrovMotion.settle,
                        builder: (context, value, _) => LinearProgressIndicator(
                          value: value,
                          minHeight: 6,
                          backgroundColor: pokrovOnAccent(context).withValues(alpha: 0.25),
                          color: pokrovOnAccent(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12),
              FilledButton(
                onPressed: onRenew,
                style: FilledButton.styleFrom(
                  backgroundColor: pokrovOnAccent(context),
                  foregroundColor: pokrovColor(context, PokrovColors.accentDeep),
                  minimumSize: Size(0, 40),
                  shape: StadiumBorder(),
                  textStyle: TextStyle(fontFamily: pokrovFontFamily, fontSize: 14, fontWeight: FontWeight.w800),
                ),
                child: Text(actionLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
