import 'package:flutter/material.dart';

import 'models.dart';
import 'tokens.dart';
import 'widgets.dart';

/// «Продлить доступ»: term picker, one clear price card and an honest note
/// that payment opens in the browser.
class RenewScreen extends StatelessWidget {
  const RenewScreen({super.key, required this.data, required this.onSelect, required this.onPay, required this.onBack, this.onIntroOffer, this.onActivationCode});

  final RenewViewData data;
  final ValueChanged<String> onSelect;
  final VoidCallback onPay;
  final VoidCallback onBack;
  final VoidCallback? onIntroOffer;
  final VoidCallback? onActivationCode;

  @override
  Widget build(BuildContext context) {
    final plan = data.selected;
    final index = data.plans.indexWhere((p) => p.id == data.selectedId);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BackCircle(onPressed: onBack),
              const SizedBox(height: 12),
              const Text('Продлить доступ', style: PokrovText.title),
              Text(data.current, style: PokrovText.body),
              const SizedBox(height: 16),
              PokrovSegmented(
                labels: [for (final p in data.plans) p.short],
                index: index < 0 ? data.plans.length - 1 : index,
                onChanged: (i) => onSelect(data.plans[i].id),
                height: 46,
              ),
              const SizedBox(height: 12),
              AnimatedSwitcher(
                duration: PokrovMotion.quick,
                transitionBuilder: (child, a) => FadeTransition(opacity: a, child: ScaleTransition(scale: Tween(begin: 0.97, end: 1.0).animate(a), child: child)),
                child: Container(
                  key: ValueKey(plan.id),
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: PokrovColors.surface,
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: PokrovColors.accent, width: 2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(plan.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
                          if (plan.saving.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                              decoration: BoxDecoration(color: PokrovColors.accentSoft, borderRadius: BorderRadius.circular(999)),
                              child: Text(plan.saving, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: PokrovColors.accentText)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(plan.price, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                      Text(plan.perMonth, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: PokrovColors.accent)),
                      const SizedBox(height: 4),
                      const Text('До 5 устройств · безлимитный трафик', style: PokrovText.caption),
                    ],
                  ),
                ),
              ),
              LinkButton(label: '${data.introOffer} ›', onPressed: onIntroOffer),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: PokrovColors.accentSoft, borderRadius: BorderRadius.circular(18)),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, size: 18, color: PokrovColors.accent),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Оплата откроется в браузере на защищённой странице. Потом просто вернись сюда — срок обновится.',
                        style: TextStyle(fontSize: 13, height: 1.45, color: PokrovColors.accentText),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              PrimaryButton(label: 'Перейти к оплате · ${plan.price}', onPressed: onPay, height: 58),
              Center(child: LinkButton(label: 'Есть код активации? Ввести', onPressed: onActivationCode)),
            ],
          ),
        ),
      ),
    );
  }
}
