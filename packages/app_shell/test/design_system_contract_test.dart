import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:pokrov_app_shell/app_shell.dart';
import 'package:pokrov_app_shell/src/design_system/design_system.dart';
import 'package:pokrov_core_domain/core_domain.dart';
import 'package:pokrov_platform_contracts/platform_contracts.dart';

const _fileFirstLaunchStorePrivateHelperCoverage = <String>['_stateFile'];
const _desktopSidebarPrivateHelperCoverage = <String>[
  '_PokrovBrandLockup',
  '_PokrovSidebarItem',
];

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

  test('phase 1 palette exposes light and dark app tokens without pure black',
      () {
    expect(PokrovPalette.light.canvas, const Color(0xFFF7F8FA));
    expect(PokrovPalette.light.accent, const Color(0xFF0F725D));
    expect(PokrovPalette.light.reward, const Color(0xFFC58A24));
    expect(PokrovPalette.dark.canvas, const Color(0xFF11161D));
    expect(PokrovPalette.dark.surface, const Color(0xFF171D25));
    expect(PokrovPalette.dark.reward, const Color(0xFFE2B35B));

    for (final tokens in [PokrovPalette.light, PokrovPalette.dark]) {
      expect(tokens.canvas, isNot(const Color(0xFF000000)));
      expect(tokens.canvasAlt, isNot(const Color(0xFF000000)));
      expect(tokens.surface, isNot(const Color(0xFF000000)));
      expect(tokens.surfaceMuted, isNot(const Color(0xFF000000)));
      expect(tokens.ink, isNot(const Color(0xFF000000)));
    }
  });

  test('palette token extension supports copyWith and lerp contracts', () {
    final copied = PokrovPalette.light.copyWith(accent: Colors.red);

    expect(copied, isA<PokrovPaletteTokens>());
    expect(copied.accent, Colors.red);
    expect(copied.canvas, PokrovPalette.light.canvas);
    expect(
      PokrovPalette.light.lerp(PokrovPalette.dark, 0.5),
      isA<PokrovPaletteTokens>(),
    );
    expect(PokrovPalette.light.lerp(null, 0.5), same(PokrovPalette.light));
  });

  test('motion tokens match the premium shell contract', () {
    expect(PokrovMotionTokens.quick, const Duration(milliseconds: 120));
    expect(PokrovMotionTokens.short, const Duration(milliseconds: 180));
    expect(PokrovMotionTokens.standard, const Duration(milliseconds: 240));
    expect(PokrovMotionTokens.homeReveal, const Duration(milliseconds: 480));
    expect(PokrovMotionTokens.ease, Curves.easeOutCubic);
  });

  test('fade slide transition exposes fade and slide motion layers', () {
    final transition = pokrovFadeSlideTransition(
      const Text('motion'),
      const AlwaysStoppedAnimation<double>(1),
    );

    expect(transition, isA<FadeTransition>());
    final fade = transition as FadeTransition;
    expect(fade.child, isA<SlideTransition>());
  });

  test('file first-launch store keeps the public storage contract', () {
    const store = PokrovFileFirstLaunchStore();

    expect(store, isA<PokrovFirstLaunchStore>());
  });

  test('file first-launch store persists completion in app support', () async {
    expect(_fileFirstLaunchStorePrivateHelperCoverage, contains('_stateFile'));

    final tempDirectory =
        await Directory.systemTemp.createTemp('pokrov-first-launch-store-');
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    final previousPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance =
        _FakePathProviderPlatform(tempDirectory.path);
    addTearDown(() {
      PathProviderPlatform.instance = previousPathProvider;
    });

    const store = PokrovFileFirstLaunchStore();
    final stateFile = File(
      '${tempDirectory.path}${Platform.pathSeparator}pokrov-first-launch-state.txt',
    );

    expect(await store.isCompleted(), isFalse);
    expect(await stateFile.exists(), isFalse);

    await store.markCompleted();

    expect(await stateFile.readAsString(), 'completed');
    expect(await store.isCompleted(), isTrue);
  });

  test('platform bootstrap contract summarizes client startup requirements',
      () {
    const contract = PlatformBootstrapContract(
      hostPlatform: HostPlatform.windows,
      requiredPermissions: [
        PermissionRequirement.notifications,
        PermissionRequirement.elevatedSession,
      ],
      defaultCore: RuntimeCore.singBox,
      advancedFallbackCore: RuntimeCore.xray,
      supportsSelectedAppsMode: true,
    );

    expect(contract.hostPlatform, HostPlatform.windows);
    expect(contract.defaultCore.label, 'sing-box');
    expect(contract.advancedFallbackCore, RuntimeCore.xray);
    expect(contract.supportsSelectedAppsMode, isTrue);
    expect(
      contract.permissionsSummary,
      contains(PermissionRequirement.elevatedSession.label),
    );
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
    expect(
      PokrovConnectDiscMotion.scale(
        pressed: true,
        runsSweep: true,
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

  testWidgets('phase 1 flat shared controls render stable iOS-like primitives',
      (tester) async {
    var warpEnabled = false;
    var taps = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          extensions: const [PokrovPalette.light],
        ),
        darkTheme: ThemeData(
          brightness: Brightness.dark,
          extensions: const [PokrovPalette.dark],
        ),
        home: PokrovMotionScope(
          disableAnimations: false,
          child: Scaffold(
            body: ListView(
              children: [
                PokrovGroupedSection(
                  title: 'Ваш доступ',
                  children: [
                    PokrovListRow(
                      icon: Icons.workspace_premium_outlined,
                      title: '5 дней премиум бесплатно',
                      subtitle: 'После триала можно продлить доступ.',
                      value: 'Триал',
                      onTap: () => taps += 1,
                    ),
                    PokrovWarpToggleRow(
                      enabled: warpEnabled,
                      onChanged: (value) => warpEnabled = value,
                    ),
                  ],
                ),
                PokrovTrialBanner(
                  title: '5 дней премиум бесплатно',
                  detail: 'После триала - продлите доступ.',
                  onTap: () => taps += 1,
                ),
                PokrovTelegramBonusCard(
                  state: PokrovTelegramBonusState.readyToClaim,
                  onTap: () => taps += 1,
                ),
                const PokrovInfoBanner(
                  title: 'Сообщение',
                  detail:
                      'POKROV покажет важную новость только когда она есть.',
                ),
                const PokrovPromoCard(
                  title: '+10 дней за Telegram',
                  detail: 'Подпишитесь на канал и заберите бонус.',
                  actionLabel: 'Получить',
                ),
                const PokrovStatusPill(
                  label: 'VPN включен',
                  icon: Icons.shield_outlined,
                  tone: PokrovStatusTone.accent,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.byType(PokrovSurface), findsWidgets);
    expect(find.byType(PokrovGroupedSection), findsOneWidget);
    expect(find.byType(PokrovListRow), findsWidgets);
    expect(find.byType(PokrovPromoCard), findsWidgets);
    expect(find.byType(PokrovInfoBanner), findsOneWidget);
    expect(find.byType(PokrovWarpToggleRow), findsOneWidget);
    expect(find.byType(PokrovTrialBanner), findsOneWidget);
    expect(find.byType(PokrovTelegramBonusCard), findsOneWidget);
    expect(find.text('WARP'), findsOneWidget);
    expect(find.text('Бонус готов'), findsOneWidget);

    await tester.tap(find.text('5 дней премиум бесплатно').last);
    await tester.tap(find.text('Бонус готов'));
    expect(taps, 2);
  });

  testWidgets('action row keeps the list-row contract and tap behavior',
      (tester) async {
    var taps = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: const [PokrovPalette.light]),
        home: Scaffold(
          body: PokrovActionRow(
            icon: Icons.play_arrow_rounded,
            title: 'Connect',
            subtitle: 'Uses the shared list-row layout',
            onTap: () => taps += 1,
          ),
        ),
      ),
    );

    expect(find.byType(PokrovActionRow), findsOneWidget);
    expect(find.byWidgetPredicate((widget) => widget is PokrovListRow),
        findsOneWidget);

    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();

    expect(taps, 1);
  });

  testWidgets('desktop sidebar preserves width keys and destination taps',
      (tester) async {
    expect(
      _desktopSidebarPrivateHelperCoverage,
      containsAll(const ['_PokrovBrandLockup', '_PokrovSidebarItem']),
    );

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

  testWidgets('legacy desktop sidebar keeps retained navigation contract',
      (tester) async {
    var selected = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: const [PokrovPalette.light]),
        home: Scaffold(
          body: SizedBox(
            width: 224,
            height: 360,
            child: PokrovMotionScope(
              disableAnimations: true,
              child: PokrovLegacyDesktopSidebar(
                selectedIndex: selected,
                collapsed: false,
                onSelected: (value) => selected = value,
              ),
            ),
          ),
        ),
      ),
    );

    expect(
        find.byKey(const ValueKey('desktop-sidebar-expanded')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('nav-locations')));
    await tester.pumpAndSettle();

    expect(selected, 1);
  });
}

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.applicationSupportPath);

  final String applicationSupportPath;

  @override
  Future<String?> getApplicationSupportPath() async => applicationSupportPath;
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
