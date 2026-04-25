import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/app_shell.dart';
import 'package:pokrov_core_domain/core_domain.dart';
import 'package:pokrov_runtime_engine/runtime_engine.dart';

class _FakeBootstrapper implements ManagedProfileBootstrapper {
  _FakeBootstrapper(this.payload);

  final ManagedProfilePayload payload;
  int calls = 0;
  RouteMode? lastRouteMode;
  HostPlatform? lastHostPlatform;

  @override
  Future<ManagedProfilePayload> resolveManagedProfile({
    required HostPlatform hostPlatform,
    required RouteMode routeMode,
  }) async {
    calls += 1;
    lastRouteMode = routeMode;
    lastHostPlatform = hostPlatform;
    return payload;
  }
}

void main() {
  test(
      'android seed app context keeps smoke profile free of desktop route keys',
      () {
    final context = buildSeedAppContext(hostPlatform: HostPlatform.android);
    expect(
      context.managedProfileSeed.configPayload,
      isNot(contains('auto_detect_interface')),
    );
    expect(
      context.managedProfileSeed.configPayload,
      isNot(contains('override_android_vpn')),
    );
  });

  testWidgets('renders app-first protection shell with redeem actions',
      (tester) async {
    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Protection'), findsWidgets);
    expect(find.text('Locations'), findsOneWidget);
    expect(find.text('Rules'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    final protectionPolicy = find.text('What stays simple');
    await tester.dragUntilVisible(
      protectionPolicy,
      find.byType(Scrollable).first,
      const Offset(0, -260),
    );
    await tester.pumpAndSettle();
    expect(protectionPolicy, findsOneWidget);
    final runtimeLane = find.text('Connection status');
    await tester.dragUntilVisible(
      runtimeLane,
      find.byType(Scrollable).first,
      const Offset(0, -260),
    );
    await tester.pumpAndSettle();
    expect(runtimeLane, findsOneWidget);
    await tester.tap(find.text('Profile').last);
    await tester.pumpAndSettle();
    expect(find.text('Everything for this account'), findsOneWidget);
    expect(find.text('Telegram bonus'), findsWidgets);
    final redeemPanel = find.text('Redeem activation key');
    await tester.dragUntilVisible(
      redeemPanel,
      find.byType(Scrollable).first,
      const Offset(0, -260),
    );
    await tester.pumpAndSettle();
    expect(redeemPanel, findsWidgets);
  });

  testWidgets('profile handoffs open safe external destinations',
      (tester) async {
    final opened = <Uri>[];

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.windows),
        handoffLauncher: (uri) async {
          opened.add(uri);
          return true;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile').last);
    await tester.pumpAndSettle();

    final checkout = find.text('Continue to checkout');
    await tester.dragUntilVisible(
      checkout,
      find.byType(Scrollable).first,
      const Offset(0, -260),
    );
    await tester.pumpAndSettle();
    await tester.tap(checkout);
    await tester.pumpAndSettle();

    expect(opened.single.toString(),
        'https://pay.pokrov.space/checkout/?plan=1_month');

    final support = find.text('Contact support');
    await tester.dragUntilVisible(
      support,
      find.byType(Scrollable).first,
      const Offset(0, -260),
    );
    await tester.pumpAndSettle();
    await tester.tap(support);
    await tester.pumpAndSettle();

    expect(opened.last.toString(), 'https://t.me/pokrov_supportbot');
  });

  testWidgets('selected apps status is explicit beta MVP copy', (tester) async {
    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rules').last);
    await tester.pumpAndSettle();

    final selectedAppsStatus = find.text('Selected apps beta status');
    await tester.dragUntilVisible(
      selectedAppsStatus,
      find.byType(Scrollable).first,
      const Offset(0, -260),
    );
    await tester.pumpAndSettle();

    expect(selectedAppsStatus, findsOneWidget);
    expect(
      find.textContaining('Picker support is limited in this beta'),
      findsOneWidget,
    );
  });

  testWidgets(
      'android protection surface keeps degraded runtime messaging consumer friendly',
      (tester) async {
    const channel = MethodChannel('space.pokrov/runtime_engine');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'runtimeEngine.snapshot':
          return <String, Object?>{
            'phase': 'running',
            'artifactDirectory': '/host/runtime',
            'coreBinaryPath': '/host/runtime/libcore.aar',
            'stagedConfigPath': '/host/runtime/pokrov-seed-runtime.json',
            'supportsLiveConnect': true,
            'canInitialize': true,
            'canConnect': true,
            'message': 'Android runtime service is running.',
            'hostDiagnostics': <String, Object?>{
              'health': 'degraded',
              'dnsStatus': 'degraded',
              'uplinkStatus': 'healthy',
              'summary': 'DNS degraded on the current uplink.',
            },
          };
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
    });

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
      ),
    );
    await tester.pumpAndSettle();

    final runtimeLane = find.text('Connection status');
    await tester.dragUntilVisible(
      runtimeLane,
      find.byType(Scrollable).first,
      const Offset(0, -260),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Needs attention'), findsWidgets);
    expect(find.textContaining('Protection is on, but the app noticed'),
        findsWidgets);
    expect(find.textContaining('Host diagnostics'), findsNothing);
  });

  testWidgets('android protection surface hides raw top-level host diagnostics',
      (tester) async {
    const channel = MethodChannel('space.pokrov/runtime_engine');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'runtimeEngine.snapshot':
          return <String, Object?>{
            'phase': 'running',
            'artifactDirectory': '/host/runtime',
            'coreBinaryPath': '/host/runtime/libcore.aar',
            'stagedConfigPath': '/host/runtime/pokrov-seed-runtime.json',
            'supportsLiveConnect': true,
            'canInitialize': true,
            'canConnect': true,
            'message': 'Android tun established.',
            'default_network_interface': 'wlan0',
            'default_network_index': 42,
            'dns_ready': false,
            'last_failure_kind': 'default_network_unavailable',
            'ipv4_route_count': 2,
            'ipv6_route_count': 0,
          };
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
    });

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
      ),
    );
    await tester.pumpAndSettle();

    final runtimeLane = find.text('Connection status');
    await tester.dragUntilVisible(
      runtimeLane,
      find.byType(Scrollable).first,
      const Offset(0, -260),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Needs attention'), findsWidgets);
    expect(find.textContaining('Protection is on, but the app noticed'),
        findsWidgets);
    expect(find.textContaining('Last failure kind'), findsNothing);
    expect(
      find.text('Protection is on.'),
      findsNothing,
    );
  });

  testWidgets('shows a single logical location in locations', (tester) async {
    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.windows),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Locations').last);
    await tester.pumpAndSettle();

    expect(find.text('Auto-managed'), findsOneWidget);
    expect(find.text('Available after setup'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('Premium access uses enabled non-free locations'),
        findsOneWidget);
    expect(
      find.textContaining('Transport details stay hidden behind auto'),
      findsWidgets,
    );
  });

  testWidgets('primary connect action auto-prepares and starts host runtime',
      (tester) async {
    const channel = MethodChannel('space.pokrov/runtime_engine');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final calls = <String>[];
    final stagedPayloads = <String>[];
    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'managed-from-api',
        configPayload:
            '{"outbounds":[{"type":"selector","tag":"proxy"}],"route":{"final":"proxy"}}',
      ),
    );

    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
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
          final arguments = Map<Object?, Object?>.from(call.arguments as Map);
          stagedPayloads.add(arguments['configPayload'].toString());
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
            'phase': 'running',
            'artifactDirectory': '/host/runtime',
            'coreBinaryPath': '/host/runtime/libcore.aar',
            'stagedConfigPath': '/host/runtime/pokrov-seed-runtime.json',
            'supportsLiveConnect': true,
            'canInitialize': true,
            'canConnect': true,
            'message': 'Android runtime service is running.',
          };
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
    });

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: bootstrapper,
      ),
    );
    await tester.pumpAndSettle();

    final connectAction = find.text('Turn protection on');
    await tester.dragUntilVisible(
      connectAction,
      find.byType(Scrollable).first,
      const Offset(0, -280),
    );
    await tester.pumpAndSettle();

    await tester.tap(connectAction);
    await tester.pumpAndSettle();

    expect(
      calls,
      containsAllInOrder(const [
        'runtimeEngine.initialize',
        'runtimeEngine.stageManagedProfile',
        'runtimeEngine.connect',
      ]),
    );
    expect(bootstrapper.calls, 1);
    expect(bootstrapper.lastHostPlatform, HostPlatform.android);
    expect(bootstrapper.lastRouteMode, RouteMode.allExceptRu);
    expect(stagedPayloads.single, contains('"proxy"'));
    expect(stagedPayloads.single, isNot(contains('"final":"direct"')));
  });

  testWidgets(
      'android reconnect refreshes the managed profile even when one is already staged',
      (tester) async {
    const channel = MethodChannel('space.pokrov/runtime_engine');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final calls = <String>[];
    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'managed-from-api',
        configPayload:
            '{"outbounds":[{"type":"selector","tag":"proxy"}],"route":{"final":"proxy"}}',
      ),
    );

    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      switch (call.method) {
        case 'runtimeEngine.snapshot':
          return <String, Object?>{
            'phase': 'configStaged',
            'artifactDirectory': '/host/runtime',
            'coreBinaryPath': '/host/runtime/libcore.aar',
            'stagedConfigPath': '/host/runtime/previous-runtime.json',
            'supportsLiveConnect': true,
            'canInitialize': true,
            'canConnect': true,
            'message': 'Managed profile staged on the host bridge.',
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
            'phase': 'running',
            'artifactDirectory': '/host/runtime',
            'coreBinaryPath': '/host/runtime/libcore.aar',
            'stagedConfigPath': '/host/runtime/pokrov-seed-runtime.json',
            'supportsLiveConnect': true,
            'canInitialize': true,
            'canConnect': true,
            'message': 'Android runtime service is running.',
          };
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
    });

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: bootstrapper,
      ),
    );
    await tester.pumpAndSettle();

    final connectAction = find.text('Turn protection on');
    await tester.dragUntilVisible(
      connectAction,
      find.byType(Scrollable).first,
      const Offset(0, -280),
    );
    await tester.pumpAndSettle();

    await tester.tap(connectAction);
    await tester.pumpAndSettle();

    expect(bootstrapper.calls, 1);
    expect(
      calls,
      containsAllInOrder(const [
        'runtimeEngine.snapshot',
        'runtimeEngine.stageManagedProfile',
        'runtimeEngine.connect',
      ]),
    );
  });

  testWidgets(
      'primary connect action is disabled when live connect is unavailable',
      (tester) async {
    const channel = MethodChannel('space.pokrov/runtime_engine');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'runtimeEngine.snapshot') {
        return <String, Object?>{
          'phase': 'artifactMissing',
          'supportsLiveConnect': false,
          'canInitialize': false,
          'canConnect': false,
          'message': 'Host bridge is not ready.',
        };
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
    });

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: _FakeBootstrapper(
          const ManagedProfilePayload(
            profileName: 'unused',
            configPayload: '{}',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Protection unavailable'), findsOneWidget);
  });

  testWidgets(
      'primary connect action keeps the host bridge message until runtime is running',
      (tester) async {
    const channel = MethodChannel('space.pokrov/runtime_engine');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    var snapshotCalls = 0;

    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'runtimeEngine.snapshot':
          snapshotCalls += 1;
          if (snapshotCalls >= 3) {
            return <String, Object?>{
              'phase': 'running',
              'artifactDirectory': '/host/runtime',
              'coreBinaryPath': '/host/runtime/libcore.aar',
              'stagedConfigPath': '/host/runtime/pokrov-seed-runtime.json',
              'supportsLiveConnect': true,
              'canInitialize': true,
              'canConnect': true,
              'message': 'Android runtime service is running.',
            };
          }
          return <String, Object?>{
            'phase': 'configStaged',
            'artifactDirectory': '/host/runtime',
            'coreBinaryPath': '/host/runtime/libcore.aar',
            'stagedConfigPath': '/host/runtime/pokrov-seed-runtime.json',
            'supportsLiveConnect': true,
            'canInitialize': true,
            'canConnect': true,
            'message':
                'VPN permission requested. Grant it to continue the full-tunnel runtime start.',
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
            'phase': 'configStaged',
            'artifactDirectory': '/host/runtime',
            'coreBinaryPath': '/host/runtime/libcore.aar',
            'stagedConfigPath': '/host/runtime/pokrov-seed-runtime.json',
            'supportsLiveConnect': true,
            'canInitialize': true,
            'canConnect': true,
            'message':
                'VPN permission requested. Grant it to continue the full-tunnel runtime start.',
          };
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
    });

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: _FakeBootstrapper(
          const ManagedProfilePayload(
            profileName: 'managed-from-api',
            configPayload:
                '{"outbounds":[{"type":"selector","tag":"proxy"}],"route":{"final":"proxy"}}',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final connectAction = find.text('Turn protection on');
    await tester.dragUntilVisible(
      connectAction,
      find.byType(Scrollable).first,
      const Offset(0, -280),
    );
    await tester.pumpAndSettle();

    await tester.tap(connectAction);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();

    expect(
      find.text('Turn protection off'),
      findsWidgets,
    );
  });

  testWidgets(
      'primary connect action polls the host bridge until runtime is running',
      (tester) async {
    const channel = MethodChannel('space.pokrov/runtime_engine');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    var snapshotCalls = 0;

    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'runtimeEngine.snapshot':
          snapshotCalls += 1;
          if (snapshotCalls >= 3) {
            return <String, Object?>{
              'phase': 'running',
              'artifactDirectory': '/host/runtime',
              'coreBinaryPath': '/host/runtime/libcore.aar',
              'stagedConfigPath': '/host/runtime/pokrov-seed-runtime.json',
              'supportsLiveConnect': true,
              'canInitialize': true,
              'canConnect': true,
              'message': 'Android runtime service is running.',
            };
          }
          return <String, Object?>{
            'phase': 'configStaged',
            'artifactDirectory': '/host/runtime',
            'coreBinaryPath': '/host/runtime/libcore.aar',
            'stagedConfigPath': '/host/runtime/pokrov-seed-runtime.json',
            'supportsLiveConnect': true,
            'canInitialize': true,
            'canConnect': true,
            'message': 'Android runtime start is still settling.',
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
            'phase': 'configStaged',
            'artifactDirectory': '/host/runtime',
            'coreBinaryPath': '/host/runtime/libcore.aar',
            'stagedConfigPath': '/host/runtime/pokrov-seed-runtime.json',
            'supportsLiveConnect': true,
            'canInitialize': true,
            'canConnect': true,
            'message': 'Android runtime start is still settling.',
          };
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
    });

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: _FakeBootstrapper(
          const ManagedProfilePayload(
            profileName: 'managed-from-api',
            configPayload:
                '{"outbounds":[{"type":"selector","tag":"proxy"}],"route":{"final":"proxy"}}',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final connectAction = find.text('Turn protection on');
    await tester.dragUntilVisible(
      connectAction,
      find.byType(Scrollable).first,
      const Offset(0, -280),
    );
    await tester.pumpAndSettle();

    await tester.tap(connectAction);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(snapshotCalls, greaterThanOrEqualTo(2));
    expect(
      find.text('Everything is staged and ready when you tap the main action.'),
      findsNothing,
    );
  });

  testWidgets('android shell refreshes runtime snapshot when the app resumes',
      (tester) async {
    const channel = MethodChannel('space.pokrov/runtime_engine');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    var snapshotCalls = 0;

    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'runtimeEngine.snapshot') {
        snapshotCalls += 1;
        if (snapshotCalls == 1) {
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
        }
        return <String, Object?>{
          'phase': 'running',
          'artifactDirectory': '/host/runtime',
          'coreBinaryPath': '/host/runtime/libcore.aar',
          'stagedConfigPath': '/host/runtime/pokrov-seed-runtime.json',
          'supportsLiveConnect': true,
          'canInitialize': true,
          'canConnect': true,
          'message': 'Android runtime service is running.',
        };
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
    });

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
      ),
    );
    await tester.pumpAndSettle();

    final runtimeLane = find.text('Connection status');
    await tester.dragUntilVisible(
      runtimeLane,
      find.byType(Scrollable).first,
      const Offset(0, -260),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Ready to protect'), findsWidgets);
    expect(
      find.text('Everything is staged and ready when you tap the main action.'),
      findsOneWidget,
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(snapshotCalls, greaterThanOrEqualTo(2));
    expect(
      find.text('Everything is staged and ready when you tap the main action.'),
      findsNothing,
    );
  });

  test('builds seed app context for public and readiness-only host lanes', () {
    for (final platform in HostPlatform.values) {
      final appContext = buildSeedAppContext(hostPlatform: platform);

      expect(appContext.hostPlatform, platform);
      expect(appContext.bootstrapContract.hostPlatform, platform);
      expect(
        appContext.scope.publicReleaseTargets,
        containsAll(const [
          ClientPlatform.android,
          ClientPlatform.windows,
        ]),
      );
      expect(
        appContext.scope.readinessOnlyTargets,
        containsAll(const [
          ClientPlatform.ios,
          ClientPlatform.macos,
        ]),
      );
      expect(appContext.runtimeProfile.freeTier.speedMbps, 50);
      expect(appContext.redeemHint, isEmpty);
      expect(appContext.locations, hasLength(1));
    }
  });
}
