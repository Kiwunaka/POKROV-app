import 'package:flutter/material.dart';

import 'models.dart';
import 'tokens.dart';
import 'widgets.dart';

/// «Страна» (simple) / «Локации» (advanced): Auto first, then the list.
/// Simple mode shows «быстро / далеко», advanced shows milliseconds.
class LocationsScreen extends StatelessWidget {
  const LocationsScreen({super.key, required this.data, required this.onAuto, required this.onSelect, this.onRefresh});

  final LocationsViewData data;
  final VoidCallback onAuto;
  final ValueChanged<String> onSelect;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final advanced = data.mode == InterfaceMode.advanced;
    final auto = data.selectedCode == null;
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 112),
        children: [
          Row(
            children: [
              Expanded(child: Text(advanced ? 'Локации' : 'Страна', style: PokrovText.title)),
              IconButton.filledTonal(
                onPressed: onRefresh,
                tooltip: 'Обновить список',
                style: IconButton.styleFrom(backgroundColor: PokrovColors.surface, foregroundColor: PokrovColors.accent),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Semantics(
            selected: auto,
            button: true,
            child: GestureDetector(
              onTap: onAuto,
              child: AnimatedContainer(
                duration: PokrovMotion.quick,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: auto ? PokrovColors.accentWash : PokrovColors.surface,
                  borderRadius: BorderRadius.circular(PokrovRadii.card),
                  border: Border.all(color: auto ? PokrovColors.accent : PokrovColors.line, width: 2),
                ),
                child: Row(
                  children: [
                    const IconSquare(icon: Icons.bolt_rounded, size: 48, background: PokrovColors.accent, color: Colors.white),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Авто', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                          Text('Самая быстрая страна прямо сейчас', style: PokrovText.caption),
                        ],
                      ),
                    ),
                    SelectionCheck(visible: auto),
                  ],
                ),
              ),
            ),
          ),
          const SectionLabel('Или выбери страну'),
          PokrovCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            child: Column(
              children: [
                for (final (i, c) in data.countries.indexed)
                  _CountryRow(
                    country: c,
                    advanced: advanced,
                    selected: c.code == data.selectedCode,
                    divider: i < data.countries.length - 1,
                    onTap: () => onSelect(c.code),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CountryRow extends StatelessWidget {
  const _CountryRow({required this.country, required this.advanced, required this.selected, required this.divider, required this.onTap});

  final CountryOption country;
  final bool advanced;
  final bool selected;
  final bool divider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fast = country.pingMs < 60;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 64,
          decoration: BoxDecoration(border: divider ? const Border(bottom: BorderSide(color: PokrovColors.line)) : null),
          child: Row(
            children: [
              FlagTile(code: country.code, size: 40),
              const SizedBox(width: 14),
              Expanded(child: Text(country.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600))),
              Container(width: 8, height: 8, decoration: BoxDecoration(color: fast ? PokrovColors.connected : PokrovColors.warnDot, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(
                advanced ? '${country.pingMs} мс' : (fast ? 'быстро' : 'далеко'),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: PokrovColors.soft, fontFeatures: [FontFeature.tabularFigures()]),
              ),
              const SizedBox(width: 8),
              SelectionCheck(visible: selected),
            ],
          ),
        ),
      ),
    );
  }
}
