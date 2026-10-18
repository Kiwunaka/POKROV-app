import 'package:flutter/material.dart';

import 'brand.dart';
import 'models.dart';
import 'tokens.dart';
import 'widgets.dart';

/// «Профиль»: access card first, then three short groups. The interface
/// mode switches inline instead of in a separate sheet.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.data,
    required this.onRenew,
    required this.onModeChanged,
    this.onDevices,
    this.onLoginCode,
    this.onTheme,
    this.onNotifications,
    this.onHelp,
    this.onBonuses,
    this.onAbout,
    this.onAccount,
    this.onActivate,
    this.onDiagnostics,
    this.onShare,
    this.onWarp,
    this.onAppSettings,
  });

  final ProfileViewData data;
  final VoidCallback onRenew;
  final ValueChanged<InterfaceMode> onModeChanged;
  final VoidCallback? onDevices;
  final VoidCallback? onLoginCode;
  final VoidCallback? onTheme;
  final VoidCallback? onNotifications;
  final VoidCallback? onHelp;
  final VoidCallback? onBonuses;
  final VoidCallback? onAbout;
  final VoidCallback? onAccount;
  final VoidCallback? onActivate;
  final VoidCallback? onDiagnostics;
  final VoidCallback? onShare;
  final VoidCallback? onWarp;
  final VoidCallback? onAppSettings;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 112),
        children: [
          Text('Профиль', style: pokrovTextStyle(context, PokrovText.title)),
          SizedBox(height: 12),
          _AccessCard(data: data, onRenew: onRenew),
          SectionLabel('Аккаунт'),
          PokrovCard(
            child: Column(
              children: [
                if (onAccount != null) PokrovRow(title: 'Telegram и почта', value: data.accountLinked, valueColor: pokrovColor(context, PokrovColors.accent), valueBold: true, onTap: onAccount),
                if (onDevices != null) PokrovRow(title: 'Устройства', value: data.devices, onTap: onDevices),
                if (onLoginCode != null) PokrovRow(title: 'Код для входа на другом устройстве', onTap: onLoginCode),
                if (onActivate != null) PokrovRow(title: 'Ввести код входа или активации', onTap: onActivate, divider: false),
              ],
            ),
          ),
          SectionLabel('Настройки'),
          PokrovCard(
            child: Column(
              children: [
                Container(
                  height: 60,
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: pokrovColor(context, PokrovColors.line)))),
                  child: Row(
                    children: [
                      Expanded(child: Text('Вид', style: TextStyle(fontSize: 16))),
                      SizedBox(
                        width: 214,
                        child: PokrovSegmented(
                          labels: ['Просто', 'Продвинутый'],
                          index: data.mode == InterfaceMode.simple ? 0 : 1,
                          onChanged: (i) => onModeChanged(i == 0 ? InterfaceMode.simple : InterfaceMode.advanced),
                        ),
                      ),
                    ],
                  ),
                ),
                if (onTheme != null) PokrovRow(title: 'Тема', value: data.theme, onTap: onTheme),
                if (onNotifications != null) PokrovRow(title: 'Уведомления', onTap: onNotifications),
                if (onWarp != null) PokrovRow(title: 'WARP', onTap: onWarp),
                if (onAppSettings != null) PokrovRow(title: 'Работа приложения', onTap: onAppSettings, divider: false),
              ],
            ),
          ),
          SizedBox(height: 12),
          PokrovCard(
            child: Column(
              children: [
                if (onHelp != null) PokrovRow(title: 'Помощь', value: 'чат', onTap: onHelp),
                if (onDiagnostics != null) PokrovRow(title: 'Диагностика', onTap: onDiagnostics),
                if (onBonuses != null) PokrovRow(title: 'Бонусы и друзья', value: data.bonuses, valueColor: pokrovColor(context, PokrovColors.accent), valueBold: true, onTap: onBonuses),
                if (onShare != null) PokrovRow(title: 'Поделиться приложением', onTap: onShare),
                if (onAbout != null) PokrovRow(title: 'О приложении', value: data.version, onTap: onAbout, divider: false),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccessCard extends StatelessWidget {
  const _AccessCard({required this.data, required this.onRenew});

  final ProfileViewData data;
  final VoidCallback onRenew;

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
                child: Text('Продлить'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
