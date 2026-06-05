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
