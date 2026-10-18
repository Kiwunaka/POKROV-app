import 'package:flutter/material.dart';

import 'models.dart';
import 'tokens.dart';
import 'widgets.dart';

/// «Бонусы»: what you already got in one number, then a short list where
/// locked items say plainly when they open.
class BonusesScreen extends StatelessWidget {
  const BonusesScreen({super.key, required this.data, required this.onBack, this.onItem, this.onRefresh});

  final BonusesViewData data;
  final VoidCallback onBack;
  final ValueChanged<BonusItem>? onItem;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final earned = data.achievements.where((a) => a.earned).length;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            ScreenHeader(title: 'Бонусы', onBack: onBack),
            if (onRefresh != null) Align(alignment: Alignment.centerRight, child: IconButton(tooltip: 'Обновить бонусы', onPressed: onRefresh, icon: Icon(Icons.refresh_rounded))),
            if (data.notice != null) Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text(data.notice!, style: pokrovTextStyle(context, PokrovText.body))),
            SizedBox(height: 14),
            PokrovCard(
              color: pokrovColor(context, PokrovColors.warnBg),
              borderColor: pokrovColor(context, PokrovColors.warnLine),
              radius: 26,
              padding: EdgeInsets.all(18),
              child: Row(
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.6, end: 1),
                    duration: Duration(milliseconds: 700),
                    curve: Curves.elasticOut,
                    builder: (context, s, child) => Transform.scale(scale: s, child: child),
                    child: Text(data.total, style: TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: pokrovColor(context, PokrovColors.warnStrong), height: 1)),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(data.totalCaption, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: pokrovColor(context, PokrovColors.warnTitle))),
                        Text(data.breakdown, style: TextStyle(fontSize: 13, color: pokrovColor(context, PokrovColors.warnBody))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
            PokrovCard(
              child: Column(
                children: [
                  for (final (i, item) in data.items.indexed)
                    InkWell(
                      onTap: onItem == null || !item.actionable ? null : () => onItem!(item),
                      child: Container(
                        constraints: BoxConstraints(minHeight: 64),
                        decoration: BoxDecoration(border: i < data.items.length - 1 ? Border(bottom: BorderSide(color: pokrovColor(context, PokrovColors.line))) : null),
                        child: Row(
                          children: [
                            _StateDot(state: item.state),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                  Text(item.subtitle, style: pokrovTextStyle(context, PokrovText.caption)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: 12),
            if (data.achievements.isNotEmpty) PokrovCard(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: Text('Достижения', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                      Text('$earned из ${data.achievements.length}', style: pokrovTextStyle(context, PokrovText.value)),
                    ],
                  ),
                  SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final a in data.achievements)
                        Tooltip(
                          message: a.label,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(color: a.earned ? pokrovColor(context, PokrovColors.accentSoft) : pokrovColor(context, PokrovColors.chip), shape: BoxShape.circle),
                            child: Icon(a.earned ? Icons.star_rounded : Icons.lock_outline_rounded, size: 18, color: a.earned ? pokrovColor(context, PokrovColors.accent) : Color(0xFFB4BBB8)),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StateDot extends StatelessWidget {
  const _StateDot({required this.state});

  final BonusState state;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon) = switch (state) {
      BonusState.done => (pokrovColor(context, PokrovColors.accent), pokrovOnAccent(context), Icons.check_rounded),
      BonusState.available => (pokrovColor(context, PokrovColors.accentSoft), pokrovColor(context, PokrovColors.accent), Icons.card_giftcard_rounded),
      BonusState.locked => (pokrovColor(context, PokrovColors.chip), pokrovColor(context, PokrovColors.muted), Icons.lock_outline_rounded),
    };
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Icon(icon, size: 18, color: fg),
    );
  }
}
