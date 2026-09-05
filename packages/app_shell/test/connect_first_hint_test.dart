import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:pokrov_app_shell/app_shell.dart';
import 'package:pokrov_core_domain/core_domain.dart';
import 'package:pokrov_runtime_engine/runtime_engine.dart';

const _materializedRuntimeConfig =
    '{"outbounds":[{"type":"socks","tag":"node","server":"127.0.0.1","server_port":1080},{"type":"selector","tag":"proxy","outbounds":["node"]},{"type":"direct","tag":"direct"}],"route":{"final":"proxy"}}';

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
    implements
        ManagedProfileBootstrapper,
        AppFirstExperienceService,
        AppFirstFirstSessionEventService {
  const _StubBootstrapper({
    this.onRuntimeStats,
    this.onRuntimeError,
    this.onOnboardingCompleted,
    this.onFirstSessionEvent,
  });

  final void Function(String runtimePhase, bool connected)? onRuntimeStats;
  final void Function(String errorCode)? onRuntimeError;
  final VoidCallback? onOnboardingCompleted;
  final void Function(String eventName, String result)? onFirstSessionEvent;

  @override
  Future<ManagedProfilePayload> resolveManagedProfile({
    required HostPlatform hostPlatform,
    required RouteMode routeMode,
    List<String> selectedApps = const <String>[],
    String preferredNodeCode = '',
    String preferredVariantId = 'direct',
    Set<String> excludedNodeCodes = const <String>{},
  }) async {
    return const ManagedProfilePayload(
      profileName: 'test-profile',
      configPayload: _materializedRuntimeConfig,
      materializedForRuntime: true,
    );
  }

  @override
  Future<void> reportRuntimeStats({
    required HostPlatform hostPlatform,
    required String runtimePhase,
    required bool connected,
    String errorCode = '',
    String selectedNodeCode = '',
    String routeMode = '',
    int? durationMs,
    int? attemptNumber,
    bool? retryable,
    String networkClass = '',
  }) async {
    onRuntimeStats?.call(runtimePhase, connected);
    if (errorCode.isNotEmpty) {
      onRuntimeError?.call(errorCode);
    }
  }

  @override
  Future<void> completeAccountOnboarding({
    required HostPlatform hostPlatform,
  }) async {
    onOnboardingCompleted?.call();
  }

  @override
  Future<void> reportFirstSessionEvent({
    required HostPlatform hostPlatform,
    required String eventName,
    required String stage,
    required String result,
    String errorCode = '',
    bool? retryable,
  }) async {
    onFirstSessionEvent?.call(eventName, result);
  }
}

void _installReadyRuntimeBridgeMock({bool connectSucceeds = true}) {
  const channel = MethodChannel('space.pokrov/runtime_engine');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  var connectAttempted = false;

  messenger.setMockMethodCallHandler(channel, (call) async {
    switch (call.method) {
      case 'runtimeEngine.snapshot':
        if (connectAttempted && !connectSucceeds) {
          return <String, Object?>{
            'phase': 'configStaged',
            'artifactDirectory': '/host/runtime',
            'coreBinaryPath': '/host/runtime/pokrov-core.aar',
            'stagedConfigPath': '/host/runtime/pokrov-seed-runtime.json',
            'supportsLiveConnect': true,
            'canInitialize': true,
            'canConnect': true,
            'last_failure_kind': 'runtime_start_failed',
            'message': 'Connection failed.',
          };
        }
        return <String, Object?>{
          'phase': 'artifactReady',
          'artifactDirectory': '/host/runtime',
          'coreBinaryPath': '/host/runtime/pokrov-core.aar',
          'supportsLiveConnect': true,
          'canInitialize': true,
          'canConnect': false,
          'message': 'Host bridge ready.',
        };
      case 'runtimeEngine.initialize':
        return <String, Object?>{
          'phase': 'initialized',
          'artifactDirectory': '/host/runtime',
          'coreBinaryPath': '/host/runtime/pokrov-core.aar',
          'supportsLiveConnect': true,
          'canInitialize': true,
          'canConnect': false,
          'message': 'Runtime bootstrap completed on the host bridge.',
        };
      case 'runtimeEngine.stageManagedProfile':
        return <String, Object?>{
          'phase': 'configStaged',
          'artifactDirectory': '/host/runtime',
          'coreBinaryPath': '/host/runtime/pokrov-core.aar',
          'stagedConfigPath': '/host/runtime/pokrov-seed-runtime.json',
          'supportsLiveConnect': true,
          'canInitialize': true,
          'canConnect': true,
          'message': 'Managed profile staged on the host bridge.',
        };
      case 'runtimeEngine.connect':
        connectAttempted = true;
        return <String, Object?>{
          'phase': connectSucceeds ? 'running' : 'configStaged',
          'artifactDirectory': '/host/runtime',
          'coreBinaryPath': '/host/runtime/pokrov-core.aar',
          'stagedConfigPath': '/host/runtime/pokrov-seed-runtime.json',
          'supportsLiveConnect': true,
          'canInitialize': true,
          'canConnect': true,
          if (connectSucceeds) 'hostHealth': 'healthy',
          if (connectSucceeds) 'dnsState': 'healthy',
          if (connectSucceeds) 'uplinkState': 'healthy',
          if (connectSucceeds) 'core_egress_validated': true,
          if (!connectSucceeds) 'last_failure_kind': 'runtime_start_failed',
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

Future<void> _confirmFirstRouteScope(WidgetTester tester) async {
  final choice = find.byKey(const ValueKey('first-connect-scope-whole-device'));
  expect(choice, findsOneWidget);
  await tester.ensureVisible(choice);
  await tester.pumpAndSettle();
  await tester.tap(choice);
  await tester.pumpAndSettle();
  final permission = find.byKey(
    const ValueKey('vpn-permission-continue'),
  );
  if (permission.evaluate().isNotEmpty) {
    await tester.tap(permission);
    await tester.pumpAndSettle();
  }
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
    final firstSessionEvents = <(String, String)>[];
    var onboardingCompleted = 0;
    await _pumpReadyHome(
      tester,
      bootstrapper: _StubBootstrapper(
        onRuntimeStats: (phase, connected) => reports.add((phase, connected)),
        onOnboardingCompleted: () => onboardingCompleted += 1,
        onFirstSessionEvent: (eventName, result) {
          firstSessionEvents.add((eventName, result));
        },
      ),
    );

    expect(
        find.byKey(const ValueKey('primary-connect-action')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-connect-hint-pill')), findsNothing);
    expect(find.text('Нажмите, чтобы подключиться'), findsNothing);
    expect(
      find.byKey(const ValueKey('home-connect-hint-pulse')),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('primary-connect-action')));
    await tester.pumpAndSettle();
    await _confirmFirstRouteScope(tester);
    await _flushRealIo(tester);

    expect(find.byKey(const ValueKey('home-connect-hint-pill')), findsNothing);
    expect(find.text('Нажмите, чтобы подключиться'), findsNothing);
    expect(find.byKey(const ValueKey('home-connect-hint-pulse')), findsNothing);
    expect(hintStateFile().readAsStringSync().trim(), 'done');
    expect(reports, <(String, bool)>[
      ('app_opened', false),
      ('connect_requested', false),
      ('running', true),
    ]);
    expect(onboardingCompleted, 1);
    expect(
      firstSessionEvents,
      containsAllInOrder(const <(String, String)>[
        ('vpn_permission_explainer_shown', 'shown'),
        ('connect_requested', 'started'),
        ('vpn_permission_result', 'success'),
        ('first_verified_connect', 'success'),
      ]),
    );
  });

  testWidgets('failed first connection keeps the milestone pending',
      (tester) async {
    final reports = <(String, bool)>[];
    final errors = <String>[];
    var onboardingCompleted = 0;
    await _pumpReadyHome(
      tester,
      connectSucceeds: false,
      bootstrapper: _StubBootstrapper(
        onRuntimeStats: (phase, connected) => reports.add((phase, connected)),
        onRuntimeError: errors.add,
        onOnboardingCompleted: () => onboardingCompleted += 1,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('primary-connect-action')));
    await tester.pumpAndSettle();
    await _confirmFirstRouteScope(tester);
    await _flushRealIo(tester);

    // Native runtime details are intentionally redacted. The milestone stays
    // pending until a confirmed running snapshot, not until a failed attempt.
    expect(find.textContaining('Connection failed.'), findsNothing);
    expect(hintStateFile().existsSync(), isFalse);
    expect(reports, <(String, bool)>[
      ('app_opened', false),
      ('connect_requested', false),
      ('failed', false),
    ]);
    expect(errors, <String>['runtime_start_failed']);
    expect(onboardingCompleted, 0);
  });

  testWidgets(
      'Android permission callback refreshes a later running host snapshot without another tap',
      (tester) async {
    const channel = MethodChannel('space.pokrov/runtime_engine');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    var phase = 'artifactReady';
    var connectCalls = 0;

    Map<String, Object?> snapshot() => <String, Object?>{
          'phase': phase,
          'artifactDirectory': '/host/runtime',
          'coreBinaryPath': '/host/runtime/pokrov-core.aar',
          'stagedConfigPath':
              phase == 'artifactReady' ? null : '/host/runtime/pokrov.json',
          'supportsLiveConnect': true,
          'canInitialize': phase == 'artifactReady',
          'canConnect': phase == 'configStaged',
          if (phase == 'running') 'hostHealth': 'healthy',
          if (phase == 'running') 'dnsState': 'healthy',
          if (phase == 'running') 'uplinkState': 'healthy',
          if (phase == 'running') 'core_egress_validated': true,
          'message': phase == 'running'
              ? 'Android runtime service is running.'
              : connectCalls > 0
                  ? 'Android permission required.'
                  : 'Host bridge ready.',
        };

    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'runtimeEngine.snapshot':
          return snapshot();
        case 'runtimeEngine.initialize':
          phase = 'initialized';
          return snapshot();
        case 'runtimeEngine.stageManagedProfile':
          phase = 'configStaged';
          return snapshot();
        case 'runtimeEngine.connect':
          connectCalls += 1;
          return snapshot();
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: const _StubBootstrapper(),
        firstLaunchStore: _CompletedFirstLaunchStore(),
      ),
    );
    await tester.pumpAndSettle();
    await _flushRealIo(tester);

    await tester.tap(find.byKey(const ValueKey('primary-connect-action')));
    await tester.pumpAndSettle();
    await _confirmFirstRouteScope(tester);
    await tester.pumpAndSettle();
    expect(connectCalls, 1);

    // This represents the Android VPN permission callback starting the
    // service after the original method call already returned its snapshot.
    phase = 'running';
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('connect-disc-connected-settle')),
        findsOneWidget);
    expect(connectCalls, 1);
  });

  testWidgets('Android VPN permission denial remains disconnected',
      (tester) async {
    const channel = MethodChannel('space.pokrov/runtime_engine');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    var phase = 'artifactReady';
    var permissionDenied = false;

    Map<String, Object?> snapshot() => <String, Object?>{
          'phase': phase,
          'artifactDirectory': '/host/runtime',
          'coreBinaryPath': '/host/runtime/pokrov-core.aar',
          'stagedConfigPath':
              phase == 'artifactReady' ? null : '/host/runtime/pokrov.json',
          'supportsLiveConnect': true,
          'canInitialize': phase == 'artifactReady',
          'canConnect': phase == 'configStaged',
          if (permissionDenied)
            'last_failure_kind': 'vpn_permission_denied',
          'message': permissionDenied
              ? 'Permission denied.'
              : 'Host bridge ready.',
        };

    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'runtimeEngine.snapshot':
          return snapshot();
        case 'runtimeEngine.initialize':
          phase = 'initialized';
          return snapshot();
        case 'runtimeEngine.stageManagedProfile':
          phase = 'configStaged';
          permissionDenied = false;
          return snapshot();
        case 'runtimeEngine.connect':
          permissionDenied = true;
          return snapshot();
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: const _StubBootstrapper(),
        firstLaunchStore: _CompletedFirstLaunchStore(),
      ),
    );
    await tester.pumpAndSettle();
    await _flushRealIo(tester);

    await tester.tap(find.byKey(const ValueKey('primary-connect-action')));
    await tester.pumpAndSettle();
    await _confirmFirstRouteScope(tester);
    await tester.pumpAndSettle();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('connect-disc-connected-settle')),
        findsNothing);
    expect(
        find.byKey(const ValueKey('primary-connect-action')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('home-vpn-permission-recovery')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('home-vpn-permission-retry')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Разрешение на VPN не выдано'), findsOneWidget);
  });

  testWidgets('VPN permission explainer can be dismissed without connecting',
      (tester) async {
    final events = <(String, String)>[];
    await _pumpReadyHome(
      tester,
      bootstrapper: _StubBootstrapper(
        onFirstSessionEvent: (eventName, result) {
          events.add((eventName, result));
        },
      ),
    );

    await tester.tap(find.byKey(const ValueKey('primary-connect-action')));
    await tester.pumpAndSettle();
    final scope = find.byKey(
      const ValueKey('first-connect-scope-whole-device'),
    );
    await tester.tap(scope);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('vpn-permission-explainer')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('vpn-permission-not-now')));
    await tester.pumpAndSettle();

    expect(find.text('Подключить'), findsOneWidget);
    expect(find.byKey(const ValueKey('connect-disc-connected-settle')),
        findsNothing);
    expect(
      events,
      containsAllInOrder(const <(String, String)>[
        ('vpn_permission_explainer_shown', 'shown'),
        ('vpn_permission_result', 'dismissed'),
      ]),
    );
    expect(events.where((event) => event.$1 == 'connect_requested'), isEmpty);
  });

  testWidgets('completed store never renders the hint on an idle ready disc',
      (tester) async {
    hintStateFile().writeAsStringSync('done', flush: true);

    await _pumpReadyHome(tester);

    // The disc really is idle and connectable, so the only reason the hint
    // is absent is the persisted dismissal.
    expect(find.text('Подключить'), findsOneWidget);
    expect(find.byKey(const ValueKey('home-connect-hint-pill')), findsNothing);
    expect(find.byKey(const ValueKey('home-connect-hint-pulse')), findsNothing);
  });

  testWidgets('reduced motion keeps the clean button without a pulse ring',
      (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await _pumpReadyHome(tester);

    expect(
        find.byKey(const ValueKey('primary-connect-action')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-connect-hint-pill')), findsNothing);
    expect(find.byKey(const ValueKey('home-connect-hint-pulse')), findsNothing);
  });
}
