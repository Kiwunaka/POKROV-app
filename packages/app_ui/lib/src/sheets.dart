import 'package:flutter/material.dart';

import 'models.dart';
import 'tokens.dart';
import 'widgets.dart';

/// Opens a frame bottom sheet (drag handle, rounded top, scrollable).
Future<T?> showPokrovSheet<T>(BuildContext context, WidgetBuilder builder) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: builder,
  );
}

enum FirstRouteChoice { wholePhone, someApps }

/// Asked once before the first connection.
class FirstConnectSheet extends StatelessWidget {
  const FirstConnectSheet({super.key, required this.choice, required this.onChanged, required this.onContinue, this.canSelectApps = true, this.wholeDeviceLabel = 'Весь телефон'});

  final FirstRouteChoice choice;
  final ValueChanged<FirstRouteChoice> onChanged;
  final VoidCallback onContinue;
  final bool canSelectApps;
  final String wholeDeviceLabel;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Что пускать через POKROV?', style: pokrovTextStyle(context, PokrovText.heading)),
            SizedBox(height: 6),
            Text('Выбери один раз. Поменять можно в Правилах.', style: pokrovTextStyle(context, PokrovText.body)),
            SizedBox(height: 16),
            _ChoiceCard(
              selected: choice == FirstRouteChoice.wholePhone,
              icon: Icons.smartphone_rounded,
              iconFilled: true,
              title: wholeDeviceLabel,
              badge: 'советуем',
              text: 'Российские сайты и банки — как обычно',
              onTap: () => onChanged(FirstRouteChoice.wholePhone),
            ),
            SizedBox(height: 10),
            if (canSelectApps) _ChoiceCard(
              selected: choice == FirstRouteChoice.someApps,
              icon: Icons.apps_rounded,
              title: 'Только некоторые приложения',
              text: 'Выберешь сам, какие',
              onTap: () => onChanged(FirstRouteChoice.someApps),
            ),
            SizedBox(height: 16),
            PrimaryButton(label: 'Продолжить и подключить', onPressed: onContinue),
          ],
        ),
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({required this.selected, required this.icon, required this.title, required this.text, required this.onTap, this.badge, this.iconFilled = false});

  final bool selected;
  final IconData icon;
  final String title;
  final String text;
  final String? badge;
  final bool iconFilled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: PokrovMotion.quick,
          padding: EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? pokrovColor(context, PokrovColors.accentWash) : pokrovColor(context, PokrovColors.surface),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? pokrovColor(context, PokrovColors.accent) : Color(0x14111814), width: 2),
          ),
          child: Row(
            children: [
              IconSquare(
                icon: icon,
                background: iconFilled ? pokrovColor(context, PokrovColors.accent) : pokrovColor(context, PokrovColors.chip),
                color: iconFilled ? pokrovOnAccent(context) : pokrovColor(context, PokrovColors.ink),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        text: title,
                        style: pokrovTextStyle(context, PokrovText.rowStrong),
                        children: [
                          if (badge != null)
                            TextSpan(text: ' · $badge', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: pokrovColor(context, PokrovColors.accent))),
                        ],
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(text, style: pokrovTextStyle(context, PokrovText.caption)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// «Состояние защиты» in plain words. Technical evidence lives behind
/// [onDetails] (the diagnostics screen).
class StatusSheet extends StatelessWidget {
  const StatusSheet({super.key, required this.data, required this.onPrimary, required this.onDetails, this.onDisconnect});

  final StatusViewData data;
  final VoidCallback? onPrimary;
  final VoidCallback onDetails;
  final VoidCallback? onDisconnect;

  @override
  Widget build(BuildContext context) {
    final on = data.phase == ConnectionPhase.on;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 6),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.5, end: 1),
              duration: Duration(milliseconds: 650),
              curve: Curves.elasticOut,
              builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(color: on ? pokrovColor(context, PokrovColors.accent) : pokrovColor(context, PokrovColors.chip), shape: BoxShape.circle),
                child: Icon(
                  on ? Icons.check_rounded : Icons.power_settings_new_rounded,
                  size: 44,
                  color: on ? pokrovOnAccent(context) : pokrovColor(context, PokrovColors.faint),
                ),
              ),
            ),
            SizedBox(height: 14),
            Text(data.title, textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
            SizedBox(height: 4),
            Text(data.subtitle, textAlign: TextAlign.center, style: pokrovTextStyle(context, PokrovText.body)),
            SizedBox(height: 20),
            PokrovCard(
              color: pokrovColor(context, PokrovColors.canvas),
              borderColor: Colors.transparent,
              radius: 22,
              child: Column(
                children: [
                  for (final (i, row) in data.rows.indexed)
                    Container(
                      constraints: BoxConstraints(minHeight: 58),
                      decoration: BoxDecoration(
                        border: i == data.rows.length - 1 ? null : Border(bottom: BorderSide(color: pokrovColor(context, PokrovColors.line))),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(color: row.ok ? pokrovColor(context, PokrovColors.accentSoft) : pokrovColor(context, PokrovColors.chip), shape: BoxShape.circle),
                            child: Icon(row.ok ? Icons.check_rounded : Icons.remove_rounded, size: 18, color: row.ok ? pokrovColor(context, PokrovColors.accent) : pokrovColor(context, PokrovColors.faint)),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(row.title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                Text(row.detail, style: pokrovTextStyle(context, PokrovText.caption)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: 16),
            on
                ? SecondaryButton(label: 'Проверить ещё раз', onPressed: onPrimary, filled: true)
                : PrimaryButton(label: 'Включить', onPressed: onPrimary, height: 54),
            LinkButton(label: 'Подробности для поддержки ›', onPressed: onDetails),
            if (onDisconnect != null) LinkButton(label: 'Отключить', onPressed: onDisconnect!),
          ],
        ),
      ),
    );
  }
}
