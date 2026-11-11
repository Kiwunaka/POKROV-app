import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/app_first_runtime_bootstrap.dart';
import 'package:pokrov_core_domain/core_domain.dart';

class _TimeoutThenProxyClient implements HttpClient {
  _TimeoutThenProxyClient(this.port, {this.allowDirectHealth = false, this.timeoutPost = false});
  final bool allowDirectHealth;
  final bool timeoutPost;
  final int port;
  final _client = HttpClient();
  bool proxied = false;
  int directAttempts = 0;
  int proxyAttempts = 0;
  @override
  set connectionTimeout(Duration? value) => _client.connectionTimeout = value;
  @override
  set findProxy(String Function(Uri)? callback) { proxied = callback != null; }
  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    if (!proxied) {
      directAttempts++;
      if (!allowDirectHealth) throw TimeoutException('offline');
    } else { proxyAttempts++; }
    return _client.getUrl(url.replace(scheme: 'http', host: '127.0.0.1', port: port));
  }
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    if (!proxied) {
      directAttempts++;
      if (timeoutPost || !allowDirectHealth) throw TimeoutException('offline');
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
  test('timed out POST is not repeated through proxy', () async {
    final overrides = HttpOverrides.current;
    HttpOverrides.global = null;
    addTearDown(() => HttpOverrides.global = overrides);
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    unawaited(() async {
      await for (final request in server) {
        await request.drain<void>();
        request.response.headers.contentType = ContentType.json;
        request.response.write('{}');
        await request.response.close();
      }
    }());
    var starts = 0;
    const channel = MethodChannel('space.pokrov/runtime_engine');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      starts++;
      return 12345;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));
    final client = _TimeoutThenProxyClient(server.port, allowDirectHealth: true, timeoutPost: true);
    final bootstrapper = AppFirstRuntimeBootstrapper(httpClientFactory: () => client, maxRequestAttempts: 1);
    await expectLater(bootstrapper.requestEmailLoginCode(hostPlatform: HostPlatform.android, email: 'test@example.com'),
      throwsA(isA<BootstrapFailure>()));
    expect(client.directAttempts, 2);
    expect(client.proxyAttempts, 0);
    expect(starts, 0);
  });

  test('API timeout starts one proxy and retries through it', () async {
    final overrides = HttpOverrides.current;
    HttpOverrides.global = null;
    addTearDown(() => HttpOverrides.global = overrides);
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    unawaited(() async {
      await for (final request in server) {
        await request.drain<void>();
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(<String, Object?>{}));
        await request.response.close();
      }
    }());
    var starts = 0;
    const channel = MethodChannel('space.pokrov/runtime_engine');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'runtimeEngine.startApiLoopbackProxy') { starts++; return 12345; }
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));
    final clients = <_TimeoutThenProxyClient>[];
    final bootstrapper = AppFirstRuntimeBootstrapper(httpClientFactory: () {
      final client = _TimeoutThenProxyClient(server.port);
      clients.add(client);
      return client;
    }, maxRequestAttempts: 1);
    await bootstrapper.requestEmailLoginCode(hostPlatform: HostPlatform.android, email: 'test@example.com');
    await bootstrapper.requestEmailLoginCode(hostPlatform: HostPlatform.android, email: 'test@example.com');
    expect(clients.first.directAttempts, 2);
    expect(clients.first.proxyAttempts, 2);
    expect(clients.last.directAttempts, 0);
    expect(clients.last.proxyAttempts, 1);
    expect(starts, 1);
  });
}
