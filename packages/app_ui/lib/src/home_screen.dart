import 'package:flutter/material.dart';

import 'brand.dart';
import 'connect_button.dart';
import 'models.dart';
import 'season.dart';
import 'tokens.dart';
import 'widgets.dart';

/// «Защита»: the big button, a plain status line and the widgets the person
/// chose for this screen. The next step and the ad slot follow the widgets.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.data,
    required this.onToggle,
    required this.onOpenStatus,
    required this.onOpenAccess,
    this.onNotifications,
    this.onEditTiles,
    this.onTip,
    this.onHelp,
    this.adSlot,
  });

  final HomeViewData data;
  final VoidCallback? onToggle;
  final VoidCallback onOpenStatus;
  final VoidCallback onOpenAccess;
  final VoidCallback? onNotifications;
  final VoidCallback? onEditTiles;
  final VoidCallback? onTip;
  final VoidCallback? onHelp;
  final Widget? adSlot;

  @override
  Widget build(BuildContext context) {
    final error = data.phase == ConnectionPhase.error;
    return PokrovSeasonBackdrop(phase: data.phase, child: SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 112),
        children: [
          _Header(accessBadge: data.accessBadge, onAccess: onOpenAccess, onNotifications: onNotifications, unread: data.notificationsUnread),
          SizedBox(height: 8),
          Center(
            child: PokrovConnectButton(
              key: ValueKey('connect-action'),
              phase: data.phase,
              label: data.actionLabel,
              diameter: 200,
              onPressed: onToggle,
            ),
          ),
          SizedBox(height: 6),
          Center(child: _StatusPill(data: data, onTap: onOpenStatus)),
          SizedBox(height: 16),
          if (error) ...[
            WarnCard(
              title: data.errorTitle,
              body: data.errorMessage ?? 'Причину установить не удалось. Попробуй ещё раз или напиши в поддержку.',
              actions: [
                Expanded(child: _SmallButton(label: data.actionLabel ?? 'Попробовать снова', primary: true, onTap: onToggle)),
                SizedBox(width: 8),
                if (onHelp != null) _SmallButton(label: 'Помощь', onTap: onHelp),
              ],
            ),
            SizedBox(height: 10),
          ],
          _TileGrid(tiles: data.tiles),
          if (onEditTiles != null) Center(
            child: TextButton.icon(
              key: const ValueKey('home-edit-tiles'),
              onPressed: onEditTiles,
              style: TextButton.styleFrom(minimumSize: Size(48, 48), foregroundColor: pokrovColor(context, PokrovColors.accent)),
              icon: Icon(Icons.dashboard_customize_outlined, size: 20),
              label: Text('Изменить виджеты'),
            ),
          ),
          if (!error && data.tip != null && onTip != null) ...[
            SizedBox(height: 4),
            _TipCard(tip: data.tip!, onTap: onTip),
          ],
          if (!error && data.showAdSlot && adSlot != null) ...[SizedBox(height: 10), adSlot!],
        ],
      ),
    ));
  }
}

/// Two widgets per row; one per row once large text needs the room.
class _TileGrid extends StatelessWidget {
  const _TileGrid({required this.tiles});

  final List<HomeTile> tiles;

  @override
  Widget build(BuildContext context) {
    if (tiles.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
      final columns = scale > 1.4 ? 1 : 2;
      final width = (constraints.maxWidth - 10 * (columns - 1)) / columns;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [for (final tile in tiles) SizedBox(width: width, child: _TileCard(tile: tile))],
      );
    });
  }
}

class _TileCard extends StatelessWidget {
  const _TileCard({required this.tile});

  final HomeTile tile;

  @override
  Widget build(BuildContext context) {
    final on = tile.toggled == true;
    return Semantics(
      key: ValueKey('home-tile-${tile.id}'),
      button: tile.toggled == null,
      toggled: tile.toggled,
      label: '${tile.title}, ${tile.value}',
      excludeSemantics: true,
      onTap: tile.onTap,
      child: Material(
        color: on ? pokrovColor(context, PokrovColors.accentSoft) : pokrovColor(context, PokrovColors.surface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PokrovRadii.tile),
          side: BorderSide(color: on ? pokrovColor(context, PokrovColors.accentBorder) : pokrovColor(context, PokrovColors.line)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: tile.onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: 92),
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(tile.icon, size: 20, color: pokrovColor(context, PokrovColors.accent)),
                      SizedBox(width: 6),
                      Expanded(child: Text(tile.title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(tile.value, style: TextStyle(fontSize: 13, height: 1.3, color: pokrovColor(context, PokrovColors.soft))),
                  if (tile.toggled != null) ...[
                    SizedBox(height: 8),
                    IgnorePointer(child: PokrovToggle(value: on, onChanged: (_) {}, semanticLabel: tile.title)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
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
        // Large text keeps the mark and gives the room to the actions.
        Expanded(child: Align(alignment: Alignment.centerLeft,
          child: MediaQuery.textScalerOf(context).scale(16) > 24 ? PokrovMark(size: 34) : PokrovWordmark())),
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
            minimumSize: Size(0, 48),
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
      ConnectionPhase.off => ('Защита выключена', pokrovColor(context, PokrovColors.chip), Theme.of(context).brightness == Brightness.dark ? Color(0xFFB4C0B8) : Color(0xFF4A525B), pokrovColor(context, PokrovColors.faint)),
      ConnectionPhase.connecting => ('Подключаемся', pokrovColor(context, PokrovColors.accentSoft), pokrovColor(context, PokrovColors.accentText), pokrovColor(context, PokrovColors.accent)),
      ConnectionPhase.on => (data.connectedCountry.isEmpty ? 'Защищено' : 'Защищено · ${data.connectedCountry}', pokrovColor(context, PokrovColors.accentSoft), pokrovColor(context, PokrovColors.accentText), pokrovColor(context, PokrovColors.connected)),
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
              padding: EdgeInsets.fromLTRB(14, 14, 10, 14),
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
                  Flexible(
                    // Show the current status even when tickers are muted.
                    child: Text(
                      data.statusLabel ?? text,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: fg),
                    ),
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
