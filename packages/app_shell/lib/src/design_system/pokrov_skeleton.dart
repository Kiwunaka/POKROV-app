import 'package:flutter/material.dart';

import 'pokrov_palette.dart';

class PokrovSkeletonList extends StatelessWidget {
  const PokrovSkeletonList({
    super.key,
    this.rows = 4,
  });

  final int rows;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: PokrovPalette.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: PokrovPalette.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(rows, (index) {
            return Padding(
              padding: EdgeInsets.only(bottom: index == rows - 1 ? 0 : 14),
              child: Row(
                children: [
                  const PokrovSkeletonLine(width: 36, height: 36, radius: 18),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PokrovSkeletonLine(
                          width: index.isEven ? 168 : 132,
                          height: 12,
                        ),
                        const SizedBox(height: 8),
                        PokrovSkeletonLine(
                          width: index.isEven ? 232 : 188,
                          height: 10,
                          opacity: 0.08,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}

class PokrovAccountSkeletonSummary extends StatelessWidget {
  const PokrovAccountSkeletonSummary({super.key});

  static const summaryKey = ValueKey('account-skeleton-summary');

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        key: summaryKey,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: PokrovPalette.surface.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: PokrovPalette.line),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PokrovSkeletonLine(width: 220, height: 12),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: PokrovSkeletonLine(height: 74, radius: 12),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: PokrovSkeletonLine(height: 74, radius: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class PokrovSkeletonLine extends StatelessWidget {
  const PokrovSkeletonLine({
    this.width,
    required this.height,
    this.radius = 999,
    this.opacity = 0.12,
    super.key,
  });

  static const lineKey = ValueKey('motion-skeleton-line');

  final double? width;
  final double height;
  final double radius;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: lineKey,
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: PokrovPalette.ink.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
