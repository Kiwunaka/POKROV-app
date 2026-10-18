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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 112),
        children: [
          const Text('Профиль', style: PokrovText.title),
          const SizedBox(height: 12),
          _AccessCard(data: data, onRenew: onRenew),
          const SectionLabel('Аккаунт'),
          PokrovCard(
            child: Column(
              children: [
                PokrovRow(title: 'Telegram и почта', value: data.accountLinked, valueColor: PokrovColors.accent, valueBold: true),
                PokrovRow(title: 'Устройства', value: data.devices, onTap: onDevices ?? () {}),
                PokrovRow(title: 'Код для входа на другом устройстве', onTap: onLoginCode ?? () {}, divider: false),
              ],
            ),
          ),
          const SectionLabel('Настройки'),
          PokrovCard(
            child: Column(
              children: [
                Container(
                  height: 60,
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: PokrovColors.line))),
                  child: Row(
                    children: [
                      const Expanded(child: Text('Вид', style: TextStyle(fontSize: 16))),
                      SizedBox(
                        width: 214,
                        child: PokrovSegmented(
                          labels: const ['Просто', 'Продвинутый'],
                          index: data.mode == InterfaceMode.simple ? 0 : 1,
                          onChanged: (i) => onModeChanged(i == 0 ? InterfaceMode.simple : InterfaceMode.advanced),
                        ),
                      ),
                    ],
                  ),
                ),
                PokrovRow(title: 'Тема', value: data.theme, onTap: onTheme ?? () {}),
                PokrovRow(title: 'Уведомления', onTap: onNotifications ?? () {}, divider: false),
              ],
            ),
          ),
          const SizedBox(height: 12),
          PokrovCard(
            child: Column(
              children: [
                PokrovRow(title: 'Помощь', value: 'чат', onTap: onHelp ?? () {}),
                PokrovRow(title: 'Бонусы и друзья', value: data.bonuses, valueColor: PokrovColors.accent, valueBold: true, onTap: onBonuses ?? () {}),
                PokrovRow(title: 'О приложении', value: data.version, onTap: onAbout ?? () {}, divider: false),
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
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(color: PokrovColors.accent, borderRadius: BorderRadius.circular(PokrovRadii.card)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const PokrovMark(size: 28, color: Colors.white),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(999)),
                child: Text(data.accessBadge, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(data.accessTitle, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white))),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data.accessDetail, style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.92))),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: data.accessProgress),
                        duration: const Duration(milliseconds: 900),
                        curve: PokrovMotion.settle,
                        builder: (context, value, _) => LinearProgressIndicator(
                          value: value,
                          minHeight: 6,
                          backgroundColor: Colors.white.withValues(alpha: 0.25),
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: onRenew,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: PokrovColors.accentDeep,
                  minimumSize: const Size(0, 40),
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(fontFamily: pokrovFontFamily, fontSize: 14, fontWeight: FontWeight.w800),
                ),
                child: const Text('Продлить'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
