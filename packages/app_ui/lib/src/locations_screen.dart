import 'package:flutter/material.dart';

import 'models.dart';
import 'tokens.dart';
import 'widgets.dart';

/// «Страна» (simple) / «Локации» (advanced): Auto first, then the list.
/// Simple mode shows «быстро / далеко», advanced shows milliseconds.
class LocationsScreen extends StatelessWidget {
  const LocationsScreen({super.key, required this.data, required this.onAuto, required this.onSelect,
    this.onRefresh, this.onSelectConnection, this.selectedConnectionLabel});

  final LocationsViewData data;
  final VoidCallback? onAuto;
  final ValueChanged<String> onSelect;
  final VoidCallback? onRefresh;
  final VoidCallback? onSelectConnection;
  final String? selectedConnectionLabel;

  @override
  Widget build(BuildContext context) {
    final advanced = data.mode == InterfaceMode.advanced;
    final auto = data.selectedCode == null;
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 112),
        children: [
          Row(
            children: [
              Expanded(child: Text(advanced ? 'Локации' : 'Страна', style: pokrovTextStyle(context, PokrovText.title))),
              if (onRefresh != null) IconButton.filledTonal(
                key: ValueKey('locations-refresh-measurements'),
                onPressed: onRefresh,
                tooltip: 'Обновить список',
                style: IconButton.styleFrom(backgroundColor: pokrovColor(context, PokrovColors.surface), foregroundColor: pokrovColor(context, PokrovColors.accent)),
                icon: Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          SizedBox(height: 12),
          Semantics(
            key: ValueKey('locations-auto-section'),
            selected: auto,
            button: true,
            child: GestureDetector(
              onTap: onAuto,
              child: AnimatedContainer(
                duration: PokrovMotion.quick,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: auto ? pokrovColor(context, PokrovColors.accentWash) : pokrovColor(context, PokrovColors.surface),
                  borderRadius: BorderRadius.circular(PokrovRadii.card),
                  border: Border.all(color: auto ? pokrovColor(context, PokrovColors.accent) : pokrovColor(context, PokrovColors.line), width: 2),
                ),
                child: Row(
                  children: [
                    IconSquare(icon: Icons.bolt_rounded, size: 48, background: pokrovColor(context, PokrovColors.accent), color: pokrovOnAccent(context)),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Авто', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                          Text('POKROV подберёт рабочее соединение', style: pokrovTextStyle(context, PokrovText.caption)),
                        ],
                      ),
                    ),
                    SelectionCheck(visible: auto),
                  ],
                ),
              ),
            ),
          ),
          SectionLabel('Или выбери страну'),
          if (data.notice != null) Padding(padding: EdgeInsets.only(bottom: 12), child: Text(data.notice!, style: pokrovTextStyle(context, PokrovText.caption))),
          PokrovCard(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 2),
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
          if (advanced && onSelectConnection != null) ...[
            SizedBox(height: 12),
            TextButton.icon(
              key: ValueKey('locations-select-connection'),
              onPressed: onSelectConnection,
              icon: Icon(Icons.tune_rounded),
              label: Text('Выбрать соединение вручную'),
            ),
            if (selectedConnectionLabel != null) Text('Выбрано: $selectedConnectionLabel',
              textAlign: TextAlign.center, style: pokrovTextStyle(context, PokrovText.caption)),
          ],
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
    final ping = country.pingMs;
    final fast = ping != null && ping < 60;
    return Semantics(
      key: ValueKey('locations-country-${country.code}'),
      selected: selected,
      button: true,
      child: InkWell(
        onTap: country.available ? onTap : null,
        child: Container(
          height: 64,
          decoration: BoxDecoration(border: divider ? Border(bottom: BorderSide(color: pokrovColor(context, PokrovColors.line))) : null),
          child: Row(
            children: [
              FlagTile(code: country.code, size: 40),
              SizedBox(width: 14),
              Expanded(child: Text(country.name, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600))),
              if (ping != null) Container(width: 8, height: 8, decoration: BoxDecoration(color: fast ? pokrovColor(context, PokrovColors.connected) : pokrovColor(context, PokrovColors.warnDot), shape: BoxShape.circle)),
              if (ping != null) SizedBox(width: 6),
              if (ping != null || !country.available) Text(
                !country.available ? 'Недоступна' : advanced ? '$ping мс' : (fast ? 'быстро' : 'далеко'),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: pokrovColor(context, PokrovColors.soft), fontFeatures: [FontFeature.tabularFigures()]),
              ),
              SizedBox(width: 8),
              SelectionCheck(visible: selected),
            ],
          ),
        ),
      ),
    );
  }
}
