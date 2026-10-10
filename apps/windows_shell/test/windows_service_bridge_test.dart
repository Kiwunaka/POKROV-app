import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/app_shell.dart';
import 'package:pokrov_core_domain/core_domain.dart';
import 'package:pokrov_windows_shell/main.dart' as windows;

class _TrayController extends PokrovShellController {
  bool connected = true;
  int connects = 0;
  int disconnects = 0;

  @override
  Future<void> toggleConnection() async {
    if (connected) {
      disconnects++;
    } else {
      connects++;
    }
  }

  @override
  Future<void> disconnectConnection() async => disconnects++;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('rendered tray disconnect never connects after runtime becomes idle', () async {
    final controller = _TrayController();
    addTearDown(controller.dispose);
    final item = windows.pokrovWindowsTrayConnectionItem(
      attached: true, connected: controller.connected, busy: false, canToggle: true,
    );
    expect(item.label, 'Отключить VPN');
    controller.connected = false;
    await windows.pokrovWindowsTrayConnectionAction(item, controller);
    expect(controller.disconnects, 1);
    expect(controller.connects, 0);
  });

  test('windows tunnel authorization accepts the authenticated service',
      () async {
    const channel = MethodChannel('space.pokrov/windows-shell');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final calls = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return <String, Object?>{
        'state': 'service_bootstrap',
        'available': true,
        'trusted': true,
        'compatible': true,
        'runtimeReady': false,
      };
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    expect(
      await requestPokrovWindowsTunnelAuthorization(HostPlatform.windows),
      PokrovWindowsTunnelAuthorization.allowed,
    );
    expect(calls, ['readServiceStatus']);
  });

  test('windows tunnel authorization rejects an untrusted service', () async {
    const channel = MethodChannel('space.pokrov/windows-shell');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final calls = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return <String, Object?>{
        'state': 'server_untrusted',
        'available': true,
        'trusted': false,
        'compatible': false,
        'runtimeReady': false,
      };
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    expect(
      await requestPokrovWindowsTunnelAuthorization(HostPlatform.windows),
      PokrovWindowsTunnelAuthorization.denied,
    );
    expect(calls, ['readServiceStatus']);
  });

  test('windows service status accepts a consistent authenticated probe',
      () async {
    const channel = MethodChannel('space.pokrov/windows-shell');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final calls = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return <String, Object?>{
        'state': 'service_ready',
        'available': true,
        'trusted': true,
        'compatible': true,
        'runtimeReady': true,
      };
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    final status = await readPokrovWindowsServiceStatus(HostPlatform.windows);

    expect(status.state, PokrovWindowsServiceState.serviceReady);
    expect(status.available, isTrue);
    expect(status.trusted, isTrue);
    expect(status.compatible, isTrue);
    expect(status.runtimeReady, isTrue);
    expect(calls, ['readServiceStatus']);
  });

  test('windows service status rejects inconsistent or unsupported input',
      () async {
    final malformed = PokrovWindowsServiceStatus.fromMap(
      const <String, Object?>{
        'state': 'service_ready',
        'available': true,
        'trusted': false,
        'compatible': true,
        'runtimeReady': true,
      },
    );
    expect(malformed.state, PokrovWindowsServiceState.unavailable);
    expect(malformed.available, isFalse);
    expect(
      (await readPokrovWindowsServiceStatus(HostPlatform.android)).state,
      PokrovWindowsServiceState.unavailable,
    );
  });

}
