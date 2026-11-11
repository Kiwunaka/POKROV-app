import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/app_first_runtime_bootstrap.dart';
import 'package:pokrov_core_domain/core_domain.dart';

class _Headers implements HttpHeaders {
  @override
  ContentType? contentType = ContentType.json;
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  String? value(String name) => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Response extends Stream<List<int>> implements HttpClientResponse {
  _Response(this.statusCode);
  @override
  final int statusCode;
  @override
  final HttpHeaders headers = _Headers();
  @override
  int get contentLength => 2;
  @override
  StreamSubscription<List<int>> listen(void Function(List<int>)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) =>
      Stream<List<int>>.value(utf8.encode('{}')).listen(onData,
          onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Request implements HttpClientRequest {
  _Request(this.statusCode);
  final int statusCode;
  @override
  final HttpHeaders headers = _Headers();
  @override
  void write(Object? value) {}
  @override
  void add(List<int> data) {}
  @override
  Future<HttpClientResponse> close() async => _Response(statusCode);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

typedef _Route = ({bool proxy, String method, String path});
typedef _Reply = Object? Function(bool proxy, String method, Uri uri);

class _Client implements HttpClient {
  _Client(this.reply);
  final _Reply reply;
  final routes = <_Route>[];
  bool proxy = false;
  @override
  set connectionTimeout(Duration? value) {}
  @override
  set findProxy(String Function(Uri)? callback) {
    proxy = callback?.call(Uri.parse('https://app.pokrov.space/api/health'))
            .startsWith('PROXY ') ?? false;
  }
  Future<HttpClientRequest> request(String method, Uri uri) async {
    routes.add((proxy: proxy, method: method, path: uri.path));
    final value = reply(proxy, method, uri);
    if (value is Exception) throw value;
    return _Request(value is int ? value : HttpStatus.ok);
  }
  @override
  Future<HttpClientRequest> getUrl(Uri url) => request('GET', url);
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) => request(method, url);
  @override
  void close({bool force = false}) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _channel = MethodChannel('space.pokrov/runtime_engine');

AppFirstRuntimeBootstrapper _bootstrapper(_Client Function() client,
    {bool preflight = false}) => AppFirstRuntimeBootstrapper(
  apiFallbackBaseUrls: preflight ? null : const [],
  httpClientFactory: client,
  androidAbiResolver: (_) async => null,
  maxRequestAttempts: 1,
);

Future<void> _post(AppFirstRuntimeBootstrapper bootstrapper) =>
    bootstrapper.requestEmailLoginCode(hostPlatform: HostPlatform.android, email: 'test@example.com');

Future<void> _get(AppFirstRuntimeBootstrapper bootstrapper) async {
  await bootstrapper.fetchClientApps(hostPlatform: HostPlatform.android, currentVersion: '1');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() async {
    // Leave the process-wide route in its normal direct-first state.
    messenger.setMockMethodCallHandler(_channel, (call) async => 12345);
    final client = _Client((proxy, _, __) => proxy ? const SocketException('offline') : null);
    await _post(_bootstrapper(() => client, preflight: true));
  });
  tearDown(() => messenger.setMockMethodCallHandler(_channel, null));

  test('preflight socket failure switches POST to proxy without sending it twice', () async {
    var starts = 0;
    messenger.setMockMethodCallHandler(_channel, (call) async { starts++; return 12345; });
    final client = _Client((proxy, _, __) => proxy ? null : const SocketException('offline'));
    await _post(_bootstrapper(() => client, preflight: true));
    expect(client.routes.where((route) => !route.proxy).map((route) => route.path),
        ['/api/health', '/api/health']);
    expect(client.routes.where((route) => route.method == 'POST').map((route) => route.proxy), [true]);
    expect(starts, 1);
  });

  test('GET returns to direct after CONNECT 502 and remembers direct', () async {
    var phase = 0;
    var starts = 0;
    messenger.setMockMethodCallHandler(_channel, (call) async { starts++; return 12345; });
    final clients = <_Client>[];
    final bootstrapper = _bootstrapper(() {
      final client = _Client((proxy, _, __) {
        if (phase == 0 && !proxy) return const SocketException('offline');
        if (phase == 1 && proxy) return const HttpException('Proxy failed to establish tunnel (502 Bad Gateway)');
        return null;
      });
      clients.add(client);
      return client;
    });
    await _get(bootstrapper);
    phase = 1;
    await _get(bootstrapper);
    phase = 2;
    await _get(bootstrapper);
    expect(clients.map((client) => client.routes.map((route) => route.proxy).toList()).toList(),
        [[false, true], [true, false], [false]]);
    expect(starts, 2);
  });

  test('POST is not repeated after a proxy request fails', () async {
    var phase = 0;
    final clients = <_Client>[];
    final bootstrapper = _bootstrapper(() {
      final client = _Client((proxy, _, __) {
        if (phase == 0 && !proxy) return const SocketException('offline');
        if (phase == 1 && proxy) return const SocketException('offline');
        return null;
      });
      clients.add(client);
      return client;
    });
    await _get(bootstrapper);
    phase = 1;
    await expectLater(_post(bootstrapper), throwsA(isA<BootstrapFailure>()));
    phase = 2;
    await _post(bootstrapper);
    expect(clients.map((client) => client.routes.map((route) => route.proxy).toList()).toList(),
        [[false, true], [true], [false]]);
  });

  test('timed out direct POST is not repeated through proxy', () async {
    var starts = 0;
    messenger.setMockMethodCallHandler(_channel, (call) async { starts++; return 12345; });
    final client = _Client((_, __, ___) => TimeoutException('offline'));
    await expectLater(_post(_bootstrapper(() => client)), throwsA(isA<BootstrapFailure>()));
    expect(client.routes.map((route) => route.proxy), [false]);
    expect(starts, 0);
  });

  test('POST switches to direct when proxy fails during preflight', () async {
    final priming = _Client((proxy, _, __) => proxy ? null : const SocketException('offline'));
    await _get(_bootstrapper(() => priming));
    final client = _Client((proxy, _, __) => proxy
        ? const HttpException('Proxy failed to establish tunnel (502 Bad Gateway)') : null);
    await _post(_bootstrapper(() => client, preflight: true));
    expect(client.routes.where((route) => route.method == 'POST').map((route) => route.proxy), [false]);
    expect(client.routes.map((route) => route.proxy), [true, true, false, false]);
  });

  test('reused client follows a preference reset by another request', () async {
    var offline = true;
    final reused = _Client((proxy, _, __) => !proxy && offline
        ? const SocketException('offline') : null);
    final firstBootstrapper = _bootstrapper(() => reused);
    await _get(firstBootstrapper);
    offline = false;
    final other = _Client((proxy, _, __) => proxy
        ? const HttpException('Proxy failed to establish tunnel (502 Bad Gateway)') : null);
    await _get(_bootstrapper(() => other));
    await _get(firstBootstrapper);
    expect(reused.routes.map((route) => route.proxy), [false, true, false]);
    expect(other.routes.map((route) => route.proxy), [true, false]);
  });

  test('concurrent proxy starts share only the in-flight start', () async {
    final start = Completer<int>();
    final invoked = Completer<void>();
    var starts = 0;
    messenger.setMockMethodCallHandler(_channel, (call) async {
      starts++;
      if (!invoked.isCompleted) invoked.complete();
      return start.future;
    });
    final clients = <_Client>[];
    final bootstrapper = _bootstrapper(() {
      final client = _Client((proxy, _, __) => proxy ? null : const SocketException('offline'));
      clients.add(client);
      return client;
    }, preflight: true);
    final first = _post(bootstrapper);
    final second = _post(bootstrapper);
    await invoked.future;
    await Future<void>.delayed(Duration.zero);
    expect(starts, 1);
    start.complete(12345);
    await Future.wait([first, second]);
    expect(clients.expand((client) => client.routes).where((route) => route.method == 'POST').length, 2);
    await _post(bootstrapper);
    expect(starts, 2);
  });

  test('cancellation while a preferred proxy start fails sends no request', () async {
    final priming = _Client((proxy, _, __) => proxy ? null : const SocketException('offline'));
    await _get(_bootstrapper(() => priming));
    final invoked = Completer<void>();
    final release = Completer<int>();
    messenger.setMockMethodCallHandler(_channel, (call) async {
      invoked.complete();
      return release.future;
    });
    final directory = await Directory.systemTemp.createTemp('pokrov-mts-cancel-');
    addTearDown(() => directory.delete(recursive: true));
    final client = _Client((_, __, ___) => null);
    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiFallbackBaseUrls: const [], httpClientFactory: () => client,
      supportDirectoryResolver: () async => directory,
      sessionSecretStore: MemoryAppFirstSessionSecretStore(), maxRequestAttempts: 1,
    );
    final cancelled = Completer<void>();
    final operation = bootstrapper.resolveManagedProfile(hostPlatform: HostPlatform.android,
      routeMode: RouteMode.fullTunnel, cancelled: cancelled.future);
    final result = expectLater(operation, throwsA(isA<Exception>()));
    await invoked.future.timeout(const Duration(seconds: 5));
    cancelled.complete();
    await Future<void>.delayed(Duration.zero);
    release.completeError(PlatformException(code: 'unavailable'));
    await result;
    await Future<void>.delayed(Duration.zero);
    expect(client.routes, isEmpty);
  });

  test('TLS or authorization failure is not hidden by another origin socket failure', () async {
    var starts = 0;
    messenger.setMockMethodCallHandler(_channel, (call) async { starts++; return 12345; });
    for (final firstFailure in [const HandshakeException('bad certificate'), HttpStatus.unauthorized]) {
      final client = _Client((_, __, uri) => uri.host == 'app.pokrov.space'
          ? firstFailure : const SocketException('offline'));
      await expectLater(_post(_bootstrapper(() => client, preflight: true)),
          throwsA(isA<BootstrapFailure>()));
      expect(client.routes.every((route) => !route.proxy), isTrue);
    }
    expect(starts, 0);
  });
}
