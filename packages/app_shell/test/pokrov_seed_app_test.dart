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
  List<String> lastSelectedAppIds = const [];

  @override
  Future<ManagedProfilePayload> resolveManagedProfile({
    required HostPlatform hostPlatform,
    required RouteMode routeMode,
    List<String> selectedAppIds = const [],
  }) async {
    calls += 1;
    lastRouteMode = routeMode;
    lastHostPlatform = hostPlatform;
    lastSelectedAppIds = selectedAppIds;
    return payload;
  }
}

class _RecordingLinkLauncher implements ExternalLinkLauncher {
  final targets = <String>[];

  @override
  Future<bool> openExternal(String target) async {
    targets.add(target);
    return true;
  }
}

Future<void> _chooseDefaultDeviceRoute(WidgetTester tester) async {
  final routeChoice = find.text('Оптимизировать все устройство');
  await tester.ensureVisible(routeChoice);
  await tester.pumpAndSettle();
  await tester.tap(routeChoice);
  await tester.pumpAndSettle();
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

    expect(find.text('Подключение'), findsWidgets);
    expect(find.text('Локации'), findsOneWidget);
    expect(find.text('Правила'), findsOneWidget);
    expect(find.text('Профиль'), findsOneWidget);
    final protectionPolicy = find.text('Начало в 3 шага');
    await tester.dragUntilVisible(
      protectionPolicy,
      find.byType(Scrollable).first,
      const Offset(0, -260),
    );
    await tester.pumpAndSettle();
    expect(protectionPolicy, findsOneWidget);
    final runtimeLane = find.text('Состояние подключения');
    await tester.dragUntilVisible(
      runtimeLane,
      find.byType(Scrollable).first,
      const Offset(0, -260),
    );
    await tester.pumpAndSettle();
    expect(runtimeLane, findsOneWidget);
    await tester.tap(find.text('Профиль').last);
    await tester.pumpAndSettle();
    expect(find.text('Подписка'), findsWidgets);
    expect(find.text('Бонус Telegram'), findsWidgets);
    final redeemPanel = find.text('Активировать ключ доступа');
    await tester.dragUntilVisible(
      redeemPanel,
      find.byType(Scrollable).first,
      const Offset(0, -260),
    );
    await tester.pumpAndSettle();
    expect(redeemPanel, findsWidgets);
  });

  testWidgets('first-layer app shell copy hides transport and control terms',
      (tester) async {
    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.windows),
      ),
    );
    await tester.pumpAndSettle();

    for (final term in <String>[
      'VPN',
      'SNI',
      'DNS',
      'VLESS',
      'VMess',
      'Trojan',
      'XHTTP',
      'xray',
      'sing-box',
      'system proxy',
      'service mode',
      'subscription_url',
      'host:port',
    ]) {
      expect(find.textContaining(term, findRichText: true), findsNothing);
    }
  });

  testWidgets('windows shell uses the real brand asset instead of a text mark',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.windows),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('P'), findsNothing);
    expect(find.byType(Image), findsWidgets);
  });

  testWidgets(
      'first connect waits for an explicit device route choice before starting runtime',
      (tester) async {
    const channel = MethodChannel('space.pokrov/runtime_engine');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final calls = <String>[];

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
        bootstrapper: _FakeBootstrapper(
          const ManagedProfilePayload(
            profileName: 'managed-from-api',
            configPayload: '{}',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Как должно работать это устройство?'), findsOneWidget);

    expect(calls, isNot(contains('runtimeEngine.connect')));

    await _chooseDefaultDeviceRoute(tester);

    await tester.drag(find.byType(ListView).first, const Offset(0, -900));
    await tester.pumpAndSettle();
    final connectAction = find.text('Подключить');
    expect(connectAction, findsWidgets);
    await tester.tap(connectAction.last);
    await tester.pumpAndSettle();

    expect(calls, contains('runtimeEngine.connect'));
  });

  testWidgets('profile exposes system light and dark theme choices',
      (tester) async {
    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Профиль').last);
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('Система'),
      find.byType(Scrollable).first,
      const Offset(0, -280),
    );
    await tester.pumpAndSettle();

    expect(find.text('Система'), findsOneWidget);
    expect(find.text('Светлая'), findsOneWidget);
    expect(find.text('Темная'), findsOneWidget);
  });

  testWidgets('dark theme changes the shell surface colors', (tester) async {
    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.windows),
      ),
    );
    await tester.pumpAndSettle();

    final scaffoldBefore = tester.widget<Scaffold>(find.byType(Scaffold));
    final beforeColor = scaffoldBefore.backgroundColor;

    await tester.tap(find.text('Профиль').last);
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.text('Темная'),
      find.byType(Scrollable).first,
      const Offset(0, -280),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Темная'));
    await tester.pumpAndSettle();

    final scaffoldAfter = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffoldAfter.backgroundColor, isNot(beforeColor));
    expect(
      Theme.of(tester.element(find.byType(Scaffold))).brightness,
      Brightness.dark,
    );
  });

  testWidgets('desktop windows surface uses a two column protection layout',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.windows),
      ),
    );
    await tester.pumpAndSettle();

    expect(
        find.byKey(const ValueKey('pokrov-desktop-sidebar')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('pokrov-desktop-protection-grid')),
      findsOneWidget,
    );
  });

  testWidgets('selected app route persists picked package identifiers',
      (tester) async {
    const runtimeChannel = MethodChannel('space.pokrov/runtime_engine');
    const appPickerChannel = MethodChannel('space.pokrov/app_picker');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'managed-from-api',
        configPayload: '{}',
      ),
    );

    messenger.setMockMethodCallHandler(appPickerChannel, (call) async {
      expect(call.method, 'listSelectableApps');
      return <Object?>[
        <String, Object?>{
          'id': 'org.telegram.messenger',
          'name': 'Telegram',
        },
      ];
    });
    messenger.setMockMethodCallHandler(runtimeChannel, (call) async {
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
        case 'runtimeEngine.stageManagedProfile':
          return <String, Object?>{
            'phase': 'configStaged',
            'artifactDirectory': '/host/runtime',
            'coreBinaryPath': '/host/runtime/libcore.aar',
            'stagedConfigPath': '/host/runtime/pokrov-runtime.json',
            'supportsLiveConnect': true,
            'canInitialize': true,
            'canConnect': true,
            'message': 'Ready.',
          };
        case 'runtimeEngine.connect':
          return <String, Object?>{
            'phase': 'running',
            'artifactDirectory': '/host/runtime',
            'coreBinaryPath': '/host/runtime/libcore.aar',
            'stagedConfigPath': '/host/runtime/pokrov-runtime.json',
            'supportsLiveConnect': true,
            'canInitialize': true,
            'canConnect': true,
            'message': 'Running.',
          };
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(appPickerChannel, null);
      messenger.setMockMethodCallHandler(runtimeChannel, null);
    });

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: bootstrapper,
      ),
    );
    await tester.pumpAndSettle();

    final selectedAppsRoute =
        find.byKey(const ValueKey('pokrov-route-selected-apps'));
    await tester.ensureVisible(selectedAppsRoute);
    await tester.pumpAndSettle();
    await tester.tap(selectedAppsRoute);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pokrov-scan-selected-apps')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Telegram'));
    await tester.pumpAndSettle();

    final connectAction =
        find.byKey(const ValueKey('pokrov-primary-connect-action'));
    await tester.dragUntilVisible(
      find.text('Подключить'),
      find.byType(Scrollable).first,
      const Offset(0, -320),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(connectAction);
    await tester.pumpAndSettle();
    await tester.tap(connectAction);
    await tester.pumpAndSettle();

    expect(bootstrapper.lastRouteMode, RouteMode.selectedApps);
    expect(bootstrapper.lastSelectedAppIds, ['org.telegram.messenger']);
  });

  testWidgets(
      'selected app route offers curated fallback when scanning is empty',
      (tester) async {
    const appPickerChannel = MethodChannel('space.pokrov/app_picker');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    messenger.setMockMethodCallHandler(appPickerChannel, (call) async {
      return <Object?>[];
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(appPickerChannel, null);
    });

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.windows),
      ),
    );
    await tester.pumpAndSettle();

    final selectedAppsRoute =
        find.byKey(const ValueKey('pokrov-route-selected-apps'));
    await tester.ensureVisible(selectedAppsRoute);
    await tester.pumpAndSettle();
    await tester.tap(selectedAppsRoute);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pokrov-scan-selected-apps')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('pokrov-selected-app-fallback')),
      findsWidgets,
    );
  });

  testWidgets('first-layer shell hides technical node and demo code copy',
      (tester) async {
    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('NL-free'), findsNothing);
    await tester.tap(find.text('Профиль').last);
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.text('Активировать ключ доступа'),
      find.byType(Scrollable).first,
      const Offset(0, -280),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('POKROV-START-2026'), findsNothing);
    expect(find.textContaining('техническ'), findsNothing);
  });

  testWidgets('external handoffs do not stop at a snackbar-only message',
      (tester) async {
    final launcher = _RecordingLinkLauncher();

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        linkLauncher: launcher,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Профиль').last);
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.text('Перейти к оплате'),
      find.byType(Scrollable).first,
      const Offset(0, -280),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Перейти к оплате'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Откроем внешний переход'), findsNothing);
    expect(
      launcher.targets,
      contains('https://pay.pokrov.space/checkout/?plan=1_month'),
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

    final runtimeLane = find.text('Состояние подключения');
    await tester.dragUntilVisible(
      runtimeLane,
      find.byType(Scrollable).first,
      const Offset(0, -260),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Нужно внимание'), findsWidgets);
    expect(find.textContaining('приложение заметило'), findsWidgets);
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

    final runtimeLane = find.text('Состояние подключения');
    await tester.dragUntilVisible(
      runtimeLane,
      find.byType(Scrollable).first,
      const Offset(0, -260),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Нужно внимание'), findsWidgets);
    expect(find.textContaining('приложение заметило'), findsWidgets);
    expect(find.textContaining('Last failure kind'), findsNothing);
    expect(
      find.text('Подключение активно.'),
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

    await tester.tap(find.text('Локации').last);
    await tester.pumpAndSettle();

    expect(find.text('Автовыбор'), findsOneWidget);
    expect(find.text('Откроется после подготовки'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.textContaining('Премиум использует доступные платные локации'),
        findsOneWidget);
    expect(
      find.textContaining('Детали подключения скрыты'),
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
    await _chooseDefaultDeviceRoute(tester);

    final connectAction = find.text('Подключить');
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
    await _chooseDefaultDeviceRoute(tester);

    final connectAction = find.text('Подключить');
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

    await _chooseDefaultDeviceRoute(tester);
    await tester.drag(find.byType(ListView).first, const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(find.text('Сначала завершите подготовку'), findsWidgets);
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
    await _chooseDefaultDeviceRoute(tester);

    final connectAction = find.text('Подключить');
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
      find.text('Отключить'),
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
    await _chooseDefaultDeviceRoute(tester);

    final connectAction = find.text('Подключить');
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
      find.textContaining('Профиль готов'),
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
    await _chooseDefaultDeviceRoute(tester);

    final runtimeLane = find.text('Состояние подключения');
    await tester.dragUntilVisible(
      runtimeLane,
      find.byType(Scrollable).first,
      const Offset(0, -260),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Сейчас: Готово'), findsWidgets);
    expect(
      find.textContaining('Профиль готов'),
      findsWidgets,
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(snapshotCalls, greaterThanOrEqualTo(2));
    expect(
      find.textContaining('Профиль готов'),
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
      expect(appContext.locations, hasLength(1));
    }
  });
}
