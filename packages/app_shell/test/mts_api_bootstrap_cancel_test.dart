import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/app_first_runtime_bootstrap.dart';
import 'package:pokrov_core_domain/core_domain.dart';

class _TimeoutThenProxyClient implements HttpClient {
  _TimeoutThenProxyClient(this.port);
  final int port;
  final _client = HttpClient();
  bool proxied = false;
  int directAttempts = 0;
  int proxyAttempts = 0;
  @override
  set connectionTimeout(Duration? value) => _client.connectionTimeout = value;
  @override
  set findProxy(String Function(Uri)? callback) {
    proxied = callback?.call(Uri.parse('https://app.pokrov.space/api/health'))
        .startsWith('PROXY ') ?? false;
  }
  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    if (!proxied) {
      directAttempts++;
      throw TimeoutException('offline');
    } else { proxyAttempts++; }
    return _client.getUrl(url.replace(scheme: 'http', host: '127.0.0.1', port: port));
  }
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    if (!proxied) {
      directAttempts++;
      throw TimeoutException('offline');
    } else { proxyAttempts++; }
    return _client.openUrl(method, url.replace(scheme: 'http', host: '127.0.0.1', port: port));
  }
  @override
  void close({bool force = false}) => _client.close(force: force);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('cancelled profile does not retry after proxy starts', () async {
    final directory = await Directory.systemTemp.createTemp('pokrov-mts-cancel-');
    addTearDown(() => directory.delete(recursive: true));
    final started = Completer<void>();
    final release = Completer<int>();
    const channel = MethodChannel('space.pokrov/runtime_engine');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'runtimeEngine.startApiLoopbackProxy') {
        started.complete();
        return release.future;
      }
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));
    final client = _TimeoutThenProxyClient(1);
    final bootstrapper = AppFirstRuntimeBootstrapper(httpClientFactory: () => client,
      supportDirectoryResolver: () async => directory, sessionSecretStore: MemoryAppFirstSessionSecretStore(),
      maxRequestAttempts: 1);
    final cancelled = Completer<void>();
    final operation = bootstrapper.resolveManagedProfile(hostPlatform: HostPlatform.android,
      routeMode: RouteMode.fullTunnel, cancelled: cancelled.future);
    final result = expectLater(operation, throwsA(isA<Exception>()));
    await started.future.timeout(const Duration(seconds: 5));
    cancelled.complete();
    release.complete(12345);
    await result;
    await Future<void>.delayed(Duration.zero);
    expect(client.proxyAttempts, 0);
  });
}
