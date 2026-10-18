import 'package:flutter/material.dart';

import 'brand.dart';
import 'connect_button.dart';
import 'models.dart';
import 'tokens.dart';
import 'widgets.dart';

/// «Защита»: the big button, a human status line, country and route chips.
/// Simple mode adds a «next step» card and the ad slot; advanced mode adds
/// WARP, live numbers and the quick checks row.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.data,
    required this.onToggle,
    required this.onOpenStatus,
    required this.onOpenCountry,
    required this.onOpenRoute,
    required this.onOpenAccess,
    this.onNotifications,
    this.onWarpChanged,
    this.onTip,
    this.onHelp,
    this.adSlot,
  });

  final HomeViewData data;
  final VoidCallback? onToggle;
  final VoidCallback onOpenStatus;
  final VoidCallback onOpenCountry;
  final VoidCallback onOpenRoute;
  final VoidCallback onOpenAccess;
  final VoidCallback? onNotifications;
  final ValueChanged<bool>? onWarpChanged;
  final VoidCallback? onTip;
  final VoidCallback? onHelp;
  final Widget? adSlot;

  bool get _advanced => data.mode == InterfaceMode.advanced;

  @override
  Widget build(BuildContext context) {
    final error = data.phase == ConnectionPhase.error;
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 112),
        children: [
          _Header(accessBadge: data.accessBadge, onAccess: onOpenAccess, onNotifications: onNotifications, unread: data.notificationsUnread),
          SizedBox(height: _advanced ? 8 : 14),
          Center(
            child: PokrovConnectButton(
              key: ValueKey('connect-action'),
              phase: data.phase,
              label: data.actionLabel,
              diameter: _advanced ? 176 : 232,
              onPressed: onToggle,
            ),
          ),
          SizedBox(height: 6),
          Center(child: _StatusPill(data: data, onTap: onOpenStatus)),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ChipTile(
                  key: const ValueKey('home-location-chip'),
                  leading: FlagTile(code: data.countryCode, size: 36),
                  label: data.countryCaption,
                  value: data.countryLabel,
                  onTap: onOpenCountry,
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _ChipTile(
                  leading: IconSquare(icon: Icons.alt_route_rounded, size: 36),
                  label: 'Российские сайты',
                  value: data.routeValue,
                  onTap: onOpenRoute,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          if (error) ...[
            WarnCard(
              title: 'Не получилось подключиться',
              body: 'Похоже, сеть мешает. Попробуем другой путь — это пара секунд.',
              actions: [
                Expanded(child: _SmallButton(label: 'Попробовать снова', primary: true, onTap: onToggle)),
                SizedBox(width: 8),
                if (onHelp != null) _SmallButton(label: 'Помощь', onTap: onHelp),
              ],
            ),
            SizedBox(height: 10),
          ],
          if (_advanced) ..._advancedBlock(context) else ..._simpleBlock(error),
        ],
      ),
    );
  }

  List<Widget> _simpleBlock(bool error) {
    return [
      if (!error && data.tip != null && onTip != null) ...[
        _TipCard(tip: data.tip!, onTap: onTip),
        SizedBox(height: 10),
      ],
      if (!error && data.showAdSlot && adSlot != null) adSlot!,
    ];
  }

  List<Widget> _advancedBlock(BuildContext context) {
    final on = data.phase == ConnectionPhase.on;
    return [
      if (onWarpChanged != null) PokrovCard(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        radius: PokrovRadii.tile,
        child: Row(
          children: [
            IconSquare(icon: Icons.blur_on_rounded, size: 38),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('WARP', style: pokrovTextStyle(context, PokrovText.rowStrong)),
                  Text('Если сайты всё равно не открываются', style: pokrovTextStyle(context, PokrovText.caption)),
                ],
              ),
            ),
            PokrovToggle(value: data.warpEnabled, onChanged: onWarpChanged!, semanticLabel: 'WARP'),
          ],
        ),
      ),
      SizedBox(height: 10),
      Row(
        children: [
          for (final (i, s) in [
            ('Пинг', data.stats.ping, 'мс'),
            ('В сети', data.stats.uptime, ''),
            ('Загрузка', data.stats.download, 'Мбит/с'),
            ('Отдача', data.stats.upload, 'Мбит/с'),
          ].indexed) ...[
            if (i > 0) SizedBox(width: 8),
            Expanded(child: _StatTile(label: s.$1, value: s.$2, unit: on ? s.$3 : '')),
          ],
        ],
      ),
      SizedBox(height: 10),
      Material(
        color: pokrovColor(context, PokrovColors.surface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: pokrovColor(context, PokrovColors.line)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpenStatus,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                for (final check in data.checks) ...[
                  Icon(Icons.check_rounded, size: 16, color: check.ok ? pokrovColor(context, PokrovColors.accent) : pokrovColor(context, PokrovColors.faint)),
                  SizedBox(width: 3),
                  Text(check.label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: check.ok ? pokrovColor(context, PokrovColors.accent) : pokrovColor(context, PokrovColors.faint))),
                  SizedBox(width: 10),
                ],
                Spacer(),
                Icon(Icons.chevron_right_rounded, size: 20, color: pokrovColor(context, PokrovColors.faint)),
              ],
            ),
          ),
        ),
      ),
      if (data.showAdSlot && adSlot != null) ...[SizedBox(height: 10), adSlot!],
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.accessBadge, required this.onAccess, this.onNotifications, this.unread = 0});

  final String accessBadge;
  final VoidCallback onAccess;
  final VoidCallback? onNotifications;
  final int unread;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Align(alignment: Alignment.centerLeft, child: PokrovWordmark())),
        if (onNotifications != null) IconButton(
          key: ValueKey('home-notifications-action'),
          onPressed: onNotifications,
          tooltip: unread > 0 ? 'Уведомления · $unread' : 'Уведомления',
          icon: Badge(isLabelVisible: unread > 0, label: Text('$unread'), child: Icon(Icons.notifications_none_rounded, color: pokrovColor(context, PokrovColors.ink))),
        ),
        OutlinedButton(
          onPressed: onAccess,
          style: OutlinedButton.styleFrom(
            foregroundColor: pokrovColor(context, PokrovColors.accent),
            side: BorderSide(color: pokrovColor(context, PokrovColors.accentBorder), width: 1.5),
            shape: StadiumBorder(),
            padding: EdgeInsets.only(left: 14, right: 8),
            minimumSize: Size(0, 38),
            textStyle: TextStyle(fontFamily: pokrovFontFamily, fontSize: 14, fontWeight: FontWeight.w700),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [Text(accessBadge), Icon(Icons.chevron_right_rounded, size: 18)],
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.data, required this.onTap});

  final HomeViewData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (text, bg, fg, dot) = switch (data.phase) {
      ConnectionPhase.off => ('Защита выключена', pokrovColor(context, PokrovColors.chip), Color(0xFF4A525B), pokrovColor(context, PokrovColors.faint)),
      ConnectionPhase.connecting => ('Ищем быстрый путь', pokrovColor(context, PokrovColors.accentSoft), pokrovColor(context, PokrovColors.accentText), pokrovColor(context, PokrovColors.accent)),
      ConnectionPhase.on => ('${data.connectedCountry} · ${data.uptime}', pokrovColor(context, PokrovColors.accentSoft), pokrovColor(context, PokrovColors.accentText), pokrovColor(context, PokrovColors.connected)),
      ConnectionPhase.error => ('Не получилось', pokrovColor(context, PokrovColors.warnBg), pokrovColor(context, PokrovColors.warnStrong), pokrovColor(context, PokrovColors.warnDot)),
    };
    return Semantics(
      button: true,
      label: 'Состояние защиты: ${data.statusLabel ?? text}',
      onTap: onTap,
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: PokrovMotion.state,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.fromLTRB(14, 9, 10, 9),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: PokrovMotion.state,
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                  ),
                  SizedBox(width: 8),
                  AnimatedSwitcher(
                    duration: PokrovMotion.quick,
                    child: Text(data.statusLabel ?? text, key: ValueKey(data.statusLabel ?? text), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: fg)),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 18, color: fg),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChipTile extends StatelessWidget {
  const _ChipTile({super.key, required this.leading, required this.label, required this.value, required this.onTap});

  final Widget leading;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: pokrovColor(context, PokrovColors.surface),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PokrovRadii.tile), side: BorderSide(color: pokrovColor(context, PokrovColors.line))),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            children: [
              leading,
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: pokrovColor(context, PokrovColors.muted))),
                    Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
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

class _TipCard extends StatelessWidget {
  const _TipCard({required this.tip, this.onTap});

  final NextStepTip tip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: pokrovColor(context, PokrovColors.surface),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: BorderSide(color: pokrovColor(context, PokrovColors.line))),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(14),
          child: Row(
            children: [
              IconSquare(icon: tip.icon),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('СЛЕДУЮЩИЙ ШАГ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.4, color: pokrovColor(context, PokrovColors.accent))),
                    Text(tip.title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    Text(tip.text, style: TextStyle(fontSize: 13, color: pokrovColor(context, PokrovColors.soft))),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: pokrovColor(context, PokrovColors.faint)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, required this.unit});

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return PokrovCard(
      radius: 16,
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: pokrovColor(context, PokrovColors.muted))),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, fontFeatures: [FontFeature.tabularFigures()])),
          ),
          Text(unit, maxLines: 1, style: TextStyle(fontSize: 10, color: pokrovColor(context, PokrovColors.muted))),
        ],
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  const _SmallButton({required this.label, required this.onTap, this.primary = false});

  final String label;
  final VoidCallback? onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          backgroundColor: primary ? pokrovColor(context, PokrovColors.accent) : pokrovColor(context, PokrovColors.surface),
          foregroundColor: primary ? pokrovOnAccent(context) : pokrovColor(context, PokrovColors.ink),
          padding: EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: TextStyle(fontFamily: pokrovFontFamily, fontSize: 15, fontWeight: FontWeight.w700),
        ),
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}
