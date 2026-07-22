import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:pokrov_app_shell/app_shell.dart';
import 'package:pokrov_core_domain/core_domain.dart';
import 'package:pokrov_runtime_engine/runtime_engine.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.supportPath);

  final String supportPath;

  @override
  Future<String?> getApplicationSupportPath() async => supportPath;
}

class _CompletedFirstLaunchStore implements PokrovFirstLaunchStore {
  @override
  Future<bool> isCompleted() async => true;

  @override
  Future<void> markCompleted() async {}
}

class _StubBootstrapper
    implements ManagedProfileBootstrapper, AppFirstExperienceService {
  const _StubBootstrapper({this.onRuntimeStats, this.onOnboardingCompleted});

  final void Function(String runtimePhase, bool connected)? onRuntimeStats;
  final VoidCallback? onOnboardingCompleted;

  @override
  Future<ManagedProfilePayload> resolveManagedProfile({
    required HostPlatform hostPlatform,
    required RouteMode routeMode,
    List<String> selectedApps = const <String>[],
    String preferredNodeCode = '',
  }) async {
    return const ManagedProfilePayload(
      profileName: 'test-profile',
      configPayload: '{}',
      materializedForRuntime: true,
    );
  }

  @override
  Future<void> reportRuntimeStats({
    required HostPlatform hostPlatform,
    required String runtimePhase,
    required bool connected,
  }) async {
    onRuntimeStats?.call(runtimePhase, connected);
  }

  @override
  Future<void> completeAccountOnboarding({
    required HostPlatform hostPlatform,
  }) async {
    onOnboardingCompleted?.call();
  }
}

void _installReadyRuntimeBridgeMock({bool connectSucceeds = true}) {
  const channel = MethodChannel('space.pokrov/runtime_engine');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  messenger.setMockMethodCallHandler(channel, (call) async {
    switch (call.method) {
      case 'runtimeEngine.snapshot':
        return <String, Object?>{
          'phase': 'artifactReady',
          'artifactDirectory': '/host/runtime',
          'coreBinaryPath': '/host/runtime/libcore.aar',
          'supportsLiveConnect': true,
          'canInitialize': true,
          'canConnect': false,
          'message': 'Host bridge ready.',
        };
      case 'runtimeEngine.initialize':
        return <String, Object?>{
          'phase': 'initialized',
          'artifactDirectory': '/host/runtime',
          'coreBinaryPath': '/host/runtime/libcore.aar',
          'supportsLiveConnect': true,
          'canInitialize': true,
          'canConnect': false,
          'message': 'Runtime bootstrap completed on the host bridge.',
        };
      case 'runtimeEngine.stageManagedProfile':
        return <String, Object?>{
          'phase': 'configStaged',
          'artifactDirectory': '/host/runtime',
          'coreBinaryPath': '/host/runtime/libcore.aar',
          'stagedConfigPath': '/host/runtime/pokrov-seed-runtime.json',
          'supportsLiveConnect': true,
          'canInitialize': true,
          'canConnect': true,
          'message': 'Managed profile staged on the host bridge.',
        };
      case 'runtimeEngine.connect':
        return <String, Object?>{
          'phase': connectSucceeds ? 'running' : 'configStaged',
          'artifactDirectory': '/host/runtime',
          'coreBinaryPath': '/host/runtime/libcore.aar',
          'stagedConfigPath': '/host/runtime/pokrov-seed-runtime.json',
          'supportsLiveConnect': true,
          'canInitialize': true,
          'canConnect': true,
          'message': connectSucceeds
              ? 'Runtime service is running.'
              : 'Connection failed.',
        };
    }
    return null;
  });
  addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
}

/// Lets real dart:io work (the file-backed hint store) complete while the
/// widget test is otherwise driven by fake async. Each IO hop needs one real
/// event-loop turn followed by a microtask flush, so the helper iterates.
Future<void> _flushRealIo(WidgetTester tester) async {
  for (var i = 0; i < 8; i += 1) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

Future<void> _pumpReadyHome(
  WidgetTester tester, {
  bool connectSucceeds = true,
  ManagedProfileBootstrapper bootstrapper = const _StubBootstrapper(),
}) async {
  await tester.binding.setSurfaceSize(const Size(760, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  _installReadyRuntimeBridgeMock(connectSucceeds: connectSucceeds);
  await tester.pumpWidget(
    PokrovSeedApp(
      appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
      bootstrapper: bootstrapper,
      firstLaunchStore: _CompletedFirstLaunchStore(),
    ),
  );
  await tester.pumpAndSettle();
  await _flushRealIo(tester);
}

void main() {
  late Directory tempDirectory;

  setUp(() {
    tempDirectory =
        Directory.systemTemp.createTempSync('pokrov-connect-hint-test-');
    PathProviderPlatform.instance =
        _FakePathProviderPlatform(tempDirectory.path);
  });

  tearDown(() {
    try {
      tempDirectory.deleteSync(recursive: true);
    } catch (_) {
      // Windows can hold file handles briefly; leftover temp dirs are fine.
    }
  });

  File hintStateFile() => File(
        '${tempDirectory.path}${Platform.pathSeparator}pokrov-connect-hint-state.txt',
      );

  test('connect hint store round-trips the done marker', () async {
    const store = PokrovFileConnectHintStore();

    expect(await store.isCompleted(), isFalse);

    await store.markCompleted();

    expect(await store.isCompleted(), isTrue);
    expect(hintStateFile().readAsStringSync().trim(), 'done');
  });

  testWidgets(
      'successful first connection dismisses the hint and reports UX state',
      (tester) async {
    final reports = <(String, bool)>[];
    var onboardingCompleted = 0;
    await _pumpReadyHome(
      tester,
      bootstrapper: _StubBootstrapper(
        onRuntimeStats: (phase, connected) => reports.add((phase, connected)),
        onOnboardingCompleted: () => onboardingCompleted += 1,
      ),
    );

    expect(
      find.byKey(const ValueKey('home-connect-hint-pill')),
      findsOneWidget,
    );
    expect(find.text('Нажмите, чтобы подключиться'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('home-connect-hint-pulse')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('primary-connect-action')));
    await tester.pumpAndSettle();
    await _flushRealIo(tester);

    expect(find.byKey(const ValueKey('home-connect-hint-pill')), findsNothing);
    expect(find.text('Нажмите, чтобы подключиться'), findsNothing);
    expect(find.byKey(const ValueKey('home-connect-hint-pulse')), findsNothing);
    expect(hintStateFile().readAsStringSync().trim(), 'done');
    expect(reports, <(String, bool)>[('running', true)]);
    expect(onboardingCompleted, 1);
  });

  testWidgets('failed first connection keeps the milestone pending',
      (tester) async {
    final reports = <(String, bool)>[];
    var onboardingCompleted = 0;
    await _pumpReadyHome(
      tester,
      connectSucceeds: false,
      bootstrapper: _StubBootstrapper(
        onRuntimeStats: (phase, connected) => reports.add((phase, connected)),
        onOnboardingCompleted: () => onboardingCompleted += 1,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('primary-connect-action')));
    await tester.pumpAndSettle();
    await _flushRealIo(tester);

    expect(find.textContaining('Connection failed.'), findsWidgets);
    expect(hintStateFile().existsSync(), isFalse);
    expect(reports, isEmpty);
    expect(onboardingCompleted, 0);
  });

  testWidgets('completed store never renders the hint on an idle ready disc',
      (tester) async {
    hintStateFile().writeAsStringSync('done', flush: true);

    await _pumpReadyHome(tester);

    // The disc really is idle and connectable, so the only reason the hint
    // is absent is the persisted dismissal.
    expect(find.text('Включить VPN'), findsOneWidget);
    expect(find.byKey(const ValueKey('home-connect-hint-pill')), findsNothing);
    expect(find.byKey(const ValueKey('home-connect-hint-pulse')), findsNothing);
  });

  testWidgets('reduced motion keeps the hint pill but disables the pulse ring',
      (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await _pumpReadyHome(tester);

    expect(
      find.byKey(const ValueKey('home-connect-hint-pill')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('home-connect-hint-pulse')), findsNothing);
  });
}
