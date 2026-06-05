import 'package:flutter/material.dart';

import 'pokrov_palette.dart';

abstract final class PokrovBrandAssets {
  static const mark = 'assets/brand/pokrov_mark.png';
}

class PokrovBrandMark extends StatelessWidget {
  const PokrovBrandMark({
    required this.size,
    this.opacity = 1,
    this.assetName = PokrovBrandAssets.mark,
    super.key,
  });

  static const imageKey = ValueKey('pokrov-brand-mark');

  final double size;
  final double opacity;
  final String assetName;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Image.asset(
        assetName,
        key: imageKey,
        width: size,
        height: size,
        cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
        filterQuality: FilterQuality.medium,
        errorBuilder: (context, error, stackTrace) {
          return SizedBox(
            width: size,
            height: size,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: PokrovPalette.accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  'P',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: PokrovPalette.accent,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
