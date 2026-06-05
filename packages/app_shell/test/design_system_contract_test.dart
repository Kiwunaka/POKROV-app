import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/src/design_system/design_system.dart';

void main() {
  test('palette keeps the POKROV beta shell colors stable', () {
    expect(PokrovPalette.canvas, const Color(0xFFF9FAFB));
    expect(PokrovPalette.canvasAlt, const Color(0xFFFFFFFF));
    expect(PokrovPalette.ink, const Color(0xFF10131A));
    expect(PokrovPalette.accent, const Color(0xFF0F725D));
    expect(PokrovPalette.accentBright, const Color(0xFF16A27B));
    expect(PokrovPalette.success, const Color(0xFF159A68));
    expect(PokrovPalette.warning, const Color(0xFFE29A1F));
    expect(PokrovPalette.surface, const Color(0xFFFFFFFF));
    expect(PokrovPalette.surfaceMuted, const Color(0xFFF3F5F8));
    expect(PokrovPalette.line, const Color(0x1A10131A));
    expect(PokrovPalette.muted, const Color(0xFF697080));
  });

  test('motion tokens match the premium shell contract', () {
    expect(PokrovMotionTokens.quick, const Duration(milliseconds: 120));
    expect(PokrovMotionTokens.short, const Duration(milliseconds: 180));
    expect(PokrovMotionTokens.standard, const Duration(milliseconds: 240));
    expect(PokrovMotionTokens.homeReveal, const Duration(milliseconds: 680));
    expect(PokrovMotionTokens.ease, Curves.easeOutCubic);
  });

  testWidgets('motion scope collapses durations when reduced motion is active',
      (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: PokrovMotionScope(
          disableAnimations: true,
          child: _MotionDurationProbe(),
        ),
      ),
    );

    expect(find.text('0'), findsOneWidget);
  });

  testWidgets('motion scope preserves durations by default', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: PokrovMotionScope(
          disableAnimations: false,
          child: _MotionDurationProbe(),
        ),
      ),
    );

    expect(find.text('240'), findsOneWidget);
  });

  testWidgets('brand mark uses the official raster asset contract',
      (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: PokrovBrandMark(size: 32, opacity: 0.72),
      ),
    );

    final image = tester.widget<Image>(
      find.byKey(PokrovBrandMark.imageKey),
    );
    final resized = image.image as ResizeImage;
    final asset = resized.imageProvider as AssetImage;

    expect(asset.assetName, PokrovBrandAssets.mark);
    expect(image.width, 32);
    expect(image.height, 32);
    expect(find.byType(Opacity), findsOneWidget);
  });

  testWidgets('skeleton primitives preserve geometry and stable keys',
      (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Column(
          children: [
            PokrovSkeletonLine(width: 64, height: 18, radius: 9),
            PokrovSkeletonList(rows: 2),
            PokrovAccountSkeletonSummary(),
          ],
        ),
      ),
    );

    expect(find.byKey(PokrovSkeletonLine.lineKey), findsWidgets);
    expect(
      tester.getSize(find.byKey(PokrovSkeletonLine.lineKey).first),
      const Size(64, 18),
    );
    expect(
      find.byKey(PokrovAccountSkeletonSummary.summaryKey),
      findsOneWidget,
    );
    expect(find.byType(RepaintBoundary), findsAtLeastNWidgets(2));
  });
}

class _MotionDurationProbe extends StatelessWidget {
  const _MotionDurationProbe();

  @override
  Widget build(BuildContext context) {
    final scope = PokrovMotionScope.of(context);
    final duration = scope.duration(PokrovMotionTokens.standard);
    return Text(duration.inMilliseconds.toString());
  }
}
