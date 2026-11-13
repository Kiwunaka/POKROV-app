import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_core_domain/core_domain.dart';
import 'package:pokrov_runtime_engine/runtime_engine.dart';

void main() {
  final coreRoot = Platform.environment['POKROV_REAL_CORE_ROOT'];
  test('real Windows POKROV Core starts and stops without system routes',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.write('pokrov-lifecycle-ok');
      await request.response.close();
    });
    addTearDown(() => server.close(force: true));
    var proxyPort = 0;
    Future<String?> probe() async {
      final socket =
          await Socket.connect(InternetAddress.loopbackIPv4, proxyPort);
      try {
        final auth = base64Encode(utf8.encode('lifecycle:loopback-only'));
        socket.write(
            'GET http://127.0.0.1:${server.port}/ HTTP/1.1\r\nHost: 127.0.0.1:${server.port}\r\nProxy-Authorization: Basic $auth\r\nConnection: close\r\n\r\n');
        await socket.flush();
        final response = await utf8.decoder
            .bind(socket)
            .join()
            .timeout(const Duration(seconds: 5));
        return response.startsWith('HTTP/1.1 200') &&
                response.contains('pokrov-lifecycle-ok')
            ? null
            : 'wrong-response';
      } finally {
        socket.destroy();
      }
    }

    final engine = DesktopRuntimeEngine(
        hostPlatform: HostPlatform.windows,
        assetRootOverride: coreRoot,
        connectivityProbe: probe,
        competingVpnProbe: () async => false);
    final initialized = await engine.initialize();
    expect(initialized.phase, RuntimePhase.initialized,
        reason: initialized.lastFailureKind);
    expect(
        initialized.availableTransportFeatures,
        containsAll([
          RuntimeTransportFeature.psiphonTcp,
          RuntimeTransportFeature.warpMasqueH2
        ]));
    addTearDown(engine.disconnect);
    for (var cycle = 0; cycle < 3; cycle++) {
      final reservation =
          await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = reservation.port;
      await reservation.close();
      final staged = await engine.stageManagedProfile(ManagedProfilePayload(
        profileName: 'local-lifecycle',
        materializedForRuntime: true,
        routeMode: RouteMode.fullTunnel,
        configPayload: jsonEncode({
          'log': {'disabled': true},
          'inbounds': [
            {
              'type': 'mixed',
              'tag': 'local',
              'listen': '127.0.0.1',
              'listen_port': port,
              'users': [
                {'username': 'lifecycle', 'password': 'loopback-only'}
              ]
            }
          ],
          'outbounds': [
            {'type': 'direct', 'tag': 'direct'}
          ],
          'dns': {
            'servers': [
              {'type': 'local', 'tag': 'bootstrap'}
            ],
            'final': 'bootstrap'
          },
          'route': {'final': 'direct', 'default_domain_resolver': 'bootstrap'},
        }),
      ));
      expect(staged.phase, RuntimePhase.configStaged,
          reason: 'cycle=$cycle ${staged.lastFailureKind}: ${staged.message}');
      final config =
          jsonDecode(await File(staged.stagedConfigPath!).readAsString())
              as Map;
      expect(
          (config['inbounds'] as List).any((value) => value['type'] == 'tun'),
          isFalse);
      proxyPort = (config['inbounds'] as List).single['listen_port'] as int;
      final running = await engine.connect();
      expect(running.phase, RuntimePhase.running,
          reason: running.lastFailureKind);
      final stopped = await engine.disconnect();
      expect(stopped.phase, isNot(RuntimePhase.running),
          reason: stopped.lastFailureKind);
    }
  },
      skip: !Platform.isWindows || coreRoot == null,
      timeout: const Timeout(Duration(minutes: 2)));
}
