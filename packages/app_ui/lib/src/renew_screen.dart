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
          padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: SingleChildScrollView(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              BackCircle(onPressed: onBack),
              SizedBox(height: 12),
              Text('Продлить доступ', style: pokrovTextStyle(context, PokrovText.title)),
              Text(data.current, style: pokrovTextStyle(context, PokrovText.body)),
              SizedBox(height: 16),
              if (data.plans.isNotEmpty) LayoutBuilder(builder: (context, constraints) {
                final scale = MediaQuery.textScalerOf(context);
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: (data.plans.length * scale.scale(58)).clamp(constraints.maxWidth, double.infinity),
                    child: PokrovSegmented(
                labels: [for (final p in data.plans) p.short],
                index: index < 0 ? data.plans.length - 1 : index,
                onChanged: (i) => onSelect(data.plans[i].id),
                height: scale.scale(46),
              )));
              }),
              SizedBox(height: 12),
              if (plan != null) AnimatedSwitcher(
                duration: PokrovMotion.quick,
                transitionBuilder: (child, a) => FadeTransition(opacity: a, child: ScaleTransition(scale: Tween(begin: 0.97, end: 1.0).animate(a), child: child)),
                child: Container(
                  key: ValueKey(plan.id),
                  width: double.infinity,
                  padding: EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: pokrovColor(context, PokrovColors.surface),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: pokrovColor(context, PokrovColors.accent), width: 2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(plan.title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
                          if (plan.saving.isNotEmpty)
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                              decoration: BoxDecoration(color: pokrovColor(context, PokrovColors.accentSoft), borderRadius: BorderRadius.circular(999)),
                              child: Text(plan.saving, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: pokrovColor(context, PokrovColors.accentText))),
                            ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(plan.price, style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                      if (plan.perMonth.isNotEmpty) Text(plan.perMonth, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: pokrovColor(context, PokrovColors.accent))),
                      SizedBox(height: 4),
                    ],
                  ),
                ),
              ),
              if (onIntroOffer != null && data.introOffer.isNotEmpty) LinkButton(label: '${data.introOffer} ›', onPressed: onIntroOffer),
              Container(
                padding: EdgeInsets.all(14),
                decoration: BoxDecoration(color: pokrovColor(context, PokrovColors.accentSoft), borderRadius: BorderRadius.circular(18)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, size: 18, color: pokrovColor(context, PokrovColors.accent)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Оплата откроется в браузере на защищённой странице. Подтверди там срок и вернись сюда — доступ обновится.',
                        style: TextStyle(fontSize: 13, height: 1.45, color: pokrovColor(context, PokrovColors.accentText)),
                      ),
                    ),
                  ],
                ),
              ),
              ],
              ))),
              SizedBox(height: 16),
              PrimaryButton(label: plan == null ? 'Перейти к оплате' : 'Перейти к оплате · ${plan.price}', onPressed: onPay, height: 58),
              if (onActivationCode != null) Center(child: LinkButton(label: 'Есть код активации? Ввести', onPressed: onActivationCode)),
            ],
          ),
        ),
      ),
    );
  }
}
