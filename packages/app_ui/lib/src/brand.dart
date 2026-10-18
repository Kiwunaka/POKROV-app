import 'package:flutter/material.dart';

import 'tokens.dart';

/// The POKROV mark from the brand assets (the same file the app ships).
class PokrovMark extends StatelessWidget {
  const PokrovMark({super.key, this.size = 30, this.color});

  final double size;

  /// Optional tint, e.g. white on the green access card.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/brand/pokrov_mark_256.png',
      package: 'pokrov_app_ui',
      width: size,
      height: size,
      color: color ?? (Theme.of(context).brightness == Brightness.dark ? pokrovColor(context, PokrovColors.accent) : null),
      colorBlendMode: BlendMode.srcIn,
      semanticLabel: 'POKROV',
    );
  }
}

/// Logo + «POKROV VPN» wordmark, as in the current app header.
class PokrovWordmark extends StatelessWidget {
  const PokrovWordmark({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PokrovMark(size: 34),
        SizedBox(width: 8),
        Flexible(
          child: Text(
            'POKROV VPN',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: pokrovColor(context, PokrovColors.ink)),
          ),
        ),
      ],
    );
  }
}
