import 'package:flutter/material.dart';

import 'models.dart';
import 'tokens.dart';
import 'widgets.dart';

/// «Бонусы»: what you already got in one number, then a short list where
/// locked items say plainly when they open.
class BonusesScreen extends StatelessWidget {
  const BonusesScreen({super.key, required this.data, required this.onBack, this.onItem});

  final BonusesViewData data;
  final VoidCallback onBack;
  final ValueChanged<BonusItem>? onItem;

  @override
  Widget build(BuildContext context) {
    final earned = data.achievements.where((a) => a.earned).length;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            ScreenHeader(title: 'Бонусы', onBack: onBack),
            const SizedBox(height: 14),
            PokrovCard(
              color: PokrovColors.warnBg,
              borderColor: PokrovColors.warnLine,
              radius: 26,
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.6, end: 1),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.elasticOut,
                    builder: (context, s, child) => Transform.scale(scale: s, child: child),
                    child: Text(data.total, style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: Color(0xFF7A4B0B), height: 1)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(data.totalCaption, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: PokrovColors.warnTitle)),
                        Text(data.breakdown, style: const TextStyle(fontSize: 13, color: PokrovColors.warnBody)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            PokrovCard(
              child: Column(
                children: [
                  for (final (i, item) in data.items.indexed)
                    InkWell(
                      onTap: onItem == null ? null : () => onItem!(item),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 64),
                        decoration: BoxDecoration(border: i < data.items.length - 1 ? const Border(bottom: BorderSide(color: PokrovColors.line)) : null),
                        child: Row(
                          children: [
                            _StateDot(state: item.state),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                  Text(item.subtitle, style: PokrovText.caption),
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
            const SizedBox(height: 12),
            PokrovCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Expanded(child: Text('Достижения', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                      Text('$earned из ${data.achievements.length}', style: PokrovText.value),
                    ],
                  ),
                  const SizedBox(height: 12),
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
                            decoration: BoxDecoration(color: a.earned ? PokrovColors.accentSoft : PokrovColors.chip, shape: BoxShape.circle),
                            child: Icon(a.earned ? Icons.star_rounded : Icons.lock_outline_rounded, size: 18, color: a.earned ? PokrovColors.accent : const Color(0xFFB4BBB8)),
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
      BonusState.done => (PokrovColors.accent, Colors.white, Icons.check_rounded),
      BonusState.available => (PokrovColors.accentSoft, PokrovColors.accent, Icons.card_giftcard_rounded),
      BonusState.locked => (PokrovColors.chip, PokrovColors.muted, Icons.lock_outline_rounded),
    };
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Icon(icon, size: 18, color: fg),
    );
  }
}
