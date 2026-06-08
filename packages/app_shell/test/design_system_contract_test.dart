import 'dart:math' as math;

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
    expect(PokrovMotionTokens.homeReveal, const Duration(milliseconds: 480));
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

  test('connect disc state resolves phases and stable settle contracts', () {
    final idle = PokrovConnectDiscState.resolve(
      enabled: true,
      running: false,
      degraded: false,
      error: false,
      busy: false,
    );
    expect(idle.phase, PokrovConnectDiscPhase.idle);
    expect(idle.settleKey, const ValueKey('connect-disc-idle-settle'));
    expect(idle.runsSweep, isFalse);
    expect(idle.settleInset, 20);
    expect(idle.settleOpacity, 0);

    final connecting = PokrovConnectDiscState.resolve(
      enabled: true,
      running: false,
      degraded: false,
      error: false,
      busy: true,
    );
    expect(connecting.phase, PokrovConnectDiscPhase.connecting);
    expect(connecting.settleKey, const ValueKey('connect-disc-busy-settle'));
    expect(connecting.runsSweep, isTrue);
    expect(connecting.settleInset, 16);
    expect(connecting.settleOpacity, 0.18);

    final revalidating = PokrovConnectDiscState.resolve(
      enabled: true,
      running: true,
      degraded: false,
      error: false,
      busy: true,
    );
    expect(revalidating.phase, PokrovConnectDiscPhase.reconnecting);
    expect(revalidating.settleKey, const ValueKey('connect-disc-busy-settle'));

    final connected = PokrovConnectDiscState.resolve(
      enabled: true,
      running: true,
      degraded: false,
      error: false,
      busy: false,
    );
    expect(connected.phase, PokrovConnectDiscPhase.connected);
    expect(
        connected.settleKey, const ValueKey('connect-disc-connected-settle'));
    expect(connected.settleInset, 12);
    expect(connected.settleOpacity, 0.20);

    final degraded = PokrovConnectDiscState.resolve(
      enabled: true,
      running: false,
      degraded: true,
      error: false,
      busy: false,
    );
    expect(degraded.phase, PokrovConnectDiscPhase.error);
    expect(degraded.settleKey, const ValueKey('connect-disc-error-settle'));
    expect(degraded.isError, isTrue);
    expect(degraded.settleInset, 13);
    expect(degraded.settleOpacity, 0.22);

    final disconnecting = PokrovConnectDiscState.explicit(
      enabled: true,
      phase: PokrovConnectDiscPhase.disconnecting,
    );
    expect(disconnecting.runsSweep, isTrue);
    expect(disconnecting.settleKey, const ValueKey('connect-disc-busy-settle'));
  });

  test('connect disc motion keeps finite sweep and tactile scale contract', () {
    expect(
      PokrovConnectDiscMotion.breathDuration,
      const Duration(milliseconds: 900),
    );
    expect(
      PokrovConnectDiscMotion.sweepDuration,
      const Duration(milliseconds: 1250),
    );
    expect(PokrovConnectDiscMotion.pressScale, 0.97);
    expect(PokrovConnectDiscMotion.busyScale, 0.985);
    expect(PokrovConnectDiscMotion.breathAmplitude, 0.014);
    expect(PokrovConnectDiscMotion.settleScaleBegin, 0.982);

    expect(PokrovConnectDiscMotion.busySweepArcRadians, lessThan(math.pi * 2));
    expect(
      PokrovConnectDiscMotion.busySweepArcRadians,
      closeTo(math.pi * 0.86, 0.0001),
    );
    expect(
      PokrovConnectDiscMotion.sweepStartAngle(
        disableAnimations: false,
        sweepValue: 0.25,
      ),
      closeTo(math.pi / 2, 0.0001),
    );
    expect(
      PokrovConnectDiscMotion.sweepStartAngle(
        disableAnimations: true,
        sweepValue: 0.75,
      ),
      closeTo(-math.pi / 2, 0.0001),
    );

    expect(
      PokrovConnectDiscMotion.scale(
        pressed: true,
        runsSweep: false,
        breathValue: 1,
        disableAnimations: false,
      ),
      closeTo(0.97 * 1.014, 0.0001),
    );
    expect(
      PokrovConnectDiscMotion.scale(
        pressed: false,
        runsSweep: true,
        breathValue: 1,
        disableAnimations: false,
      ),
      0.985,
    );
    expect(
      PokrovConnectDiscMotion.scale(
        pressed: false,
        runsSweep: false,
        breathValue: 1,
        disableAnimations: true,
      ),
      1,
    );
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

  testWidgets('home micro controls keep stable motion and row feedback keys',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: PokrovMotionScope(
          disableAnimations: false,
          child: Material(
            child: Column(
              children: [
                const PokrovStatusDotLabel(
                  label: 'Ready',
                  color: Colors.green,
                ),
                PokrovHomeChip(
                  icon: Icons.public,
                  label: 'Auto',
                  minLabelWidth: 140,
                  onTap: () => taps += 1,
                ),
                PokrovSettingsRow(
                  icon: Icons.info_outline,
                  title: 'Status',
                  value: 'Ready',
                  onTap: () => taps += 1,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(PokrovStatusDotLabel.switcherKey), findsOneWidget);
    expect(find.byKey(PokrovStatusDotLabel.dotMotionKey), findsOneWidget);
    expect(find.byKey(PokrovHomeChip.motionKey), findsOneWidget);
    expect(find.byKey(PokrovHomeChip.labelMotionKey), findsOneWidget);
    expect(
        find.byKey(PokrovSettingsRowPressSurface.feedbackKey), findsOneWidget);
    expect(
        tester.getSize(find.byKey(PokrovHomeChip.motionKey)), isNot(Size.zero));
    expect(
      tester.getSize(find.byKey(PokrovHomeChip.labelMotionKey)).width,
      greaterThanOrEqualTo(140),
    );

    await tester.tap(find.text('Auto'));
    await tester.tap(find.text('Status'));

    expect(taps, 2);
  });

  testWidgets('desktop sidebar preserves width keys and destination taps',
      (tester) async {
    var selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return SizedBox(
              height: 320,
              child: Row(
                children: [
                  PokrovMotionScope(
                    disableAnimations: false,
                    child: PokrovDesktopSidebar(
                      selectedIndex: selected,
                      collapsed: false,
                      destinations: const [
                        PokrovSidebarDestination(
                          itemKey: ValueKey('test-nav-home'),
                          icon: Icons.flash_on_outlined,
                          selectedIcon: Icons.flash_on,
                          label: 'Home',
                        ),
                        PokrovSidebarDestination(
                          itemKey: ValueKey('test-nav-account'),
                          icon: Icons.person_outline,
                          selectedIcon: Icons.person,
                          label: 'Account',
                        ),
                      ],
                      onSelected: (value) => setState(() {
                        selected = value;
                      }),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );

    expect(find.byKey(PokrovDesktopSidebar.expandedKey), findsOneWidget);
    expect(find.byKey(PokrovDesktopSidebar.labelMotionKey), findsWidgets);
    expect(
      tester.getSize(find.byKey(PokrovDesktopSidebar.expandedKey)).width,
      224,
    );

    await tester.tap(find.byKey(const ValueKey('test-nav-account')));
    await tester.pumpAndSettle();

    expect(selected, 1);

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          height: 320,
          child: Row(
            children: [
              PokrovMotionScope(
                disableAnimations: false,
                child: PokrovDesktopSidebar(
                  selectedIndex: selected,
                  collapsed: true,
                  destinations: const [
                    PokrovSidebarDestination(
                      itemKey: ValueKey('test-nav-home-collapsed'),
                      icon: Icons.flash_on_outlined,
                      selectedIcon: Icons.flash_on,
                      label: 'Home',
                    ),
                  ],
                  onSelected: (_) {},
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byKey(PokrovDesktopSidebar.iconRailKey), findsOneWidget);
    expect(
      tester.getSize(find.byKey(PokrovDesktopSidebar.iconRailKey)).width,
      72,
    );
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
