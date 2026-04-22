import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/app_first_runtime_bootstrap.dart';
import 'package:pokrov_core_domain/core_domain.dart';

const _ruDomainWhitelistRuleSetTag = 'pokrov-ru-domain-whitelist';
const _ruDomainCategoryRuleSetTag = 'pokrov-ru-domain-category';
const _ruIpCountryRuleSetTag = 'pokrov-ru-ip-country';
const _ruIpWhitelistRuleSetTag = 'pokrov-ru-ip-whitelist';

String _expectedRuleSetCachePath(Directory tempDirectory, String fileName) {
  return '${tempDirectory.path}${Platform.pathSeparator}'
      'pokrov-runtime${Platform.pathSeparator}'
      'data${Platform.pathSeparator}'
      'rule-set${Platform.pathSeparator}'
      'all-except-ru-rule-sets${Platform.pathSeparator}'
      '$fileName';
}

Map<String, List<int>> _allExceptRuRuleSetFixtures() {
  return <String, List<int>>{
    _ruDomainWhitelistRuleSetTag: utf8.encode('pokrov ru domain whitelist'),
    _ruDomainCategoryRuleSetTag: utf8.encode('pokrov ru domain category'),
    _ruIpCountryRuleSetTag: utf8.encode('pokrov ru ip country'),
    _ruIpWhitelistRuleSetTag: utf8.encode('pokrov ru ip whitelist'),
  };
}

void main() {
  test(
      'android bootstrap can map canonical API host to a direct control-plane IP',
      () {
    expect(
      bootstrapDirectAddressForRequest(
        requestUri: Uri.parse('https://api.pokrov.space/api/health'),
        hostPlatform: HostPlatform.android,
      )?.address,
      '82.21.114.104',
    );
    expect(
      bootstrapDirectAddressForRequest(
        requestUri: Uri.parse('https://api.pokrov.space/api/health'),
        hostPlatform: HostPlatform.windows,
      ),
      isNull,
    );
    expect(
      bootstrapDirectAddressForRequest(
        requestUri: Uri.parse('https://pokrov.space/'),
        hostPlatform: HostPlatform.android,
      ),
      isNull,
    );
  });

  test('bootstraps and persists a managed profile from the app-first API',
      () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-bootstrap-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    final requests = <String>[];
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    unawaited(() async {
      await for (final request in server) {
        requests.add('${request.method} ${request.uri.path}');
        final body = await utf8.decoder.bind(request).join();
        if (request.uri.path == '/api/client/session/start-trial') {
          final decoded = jsonDecode(body) as Map<String, dynamic>;
          expect(decoded['install_id'], isNotEmpty);
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'session': <String, Object?>{
                    'session_token': 'session-token-1',
                    'account_id': '42',
                  },
                  'provisioning': <String, Object?>{
                    'managed_manifest': <String, Object?>{
                      'url': '/api/client/profile/managed',
                    },
                  },
                },
              ),
            );
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/route-policy') {
          expect(
            request.headers.value(HttpHeaders.authorizationHeader),
            'Bearer session-token-1',
          );
          final decoded = jsonDecode(body) as Map<String, dynamic>;
          expect(decoded['route_mode'], 'selected_apps');
          request.response
            ..headers.contentType = ContentType.json
            ..write(jsonEncode(<String, Object?>{'ok': true}));
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/profile/managed') {
          expect(
            request.headers.value(HttpHeaders.authorizationHeader),
            'Bearer session-token-1',
          );
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'profile_revision': 'rev-007',
                  'config_format': 'singbox-json',
                  'config_payload': <String, Object?>{
                    'outbounds': <Object?>[
                      <String, Object?>{
                        'type': 'selector',
                        'tag': 'proxy',
                      },
                    ],
                    'route': <String, Object?>{
                      'final': 'proxy',
                    },
                  },
                },
              ),
            );
          await request.response.close();
          continue;
        }

        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    }());

    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => tempDirectory,
    );

    final payload = await bootstrapper.resolveManagedProfile(
      hostPlatform: HostPlatform.windows,
      routeMode: RouteMode.selectedApps,
    );

    expect(payload.profileName, 'pokrov-windows-rev-007');
    expect(payload.configPayload, contains('"type": "tun"'));
    expect(payload.configPayload, contains('"final": "proxy"'));
    expect(payload.configPayload, contains('"auto_detect_interface": true'));
    expect(
      requests,
      containsAllInOrder(const [
        'POST /api/client/session/start-trial',
        'POST /api/client/route-policy',
        'GET /api/client/profile/managed',
      ]),
    );

    final stateFile = File(
      '${tempDirectory.path}${Platform.pathSeparator}app-first-session-windows.json',
    );
    expect(await stateFile.exists(), isTrue);
    final state =
        jsonDecode(await stateFile.readAsString()) as Map<String, dynamic>;
    expect(state['session_token'], 'session-token-1');
    expect(state['managed_manifest_path'], '/api/client/profile/managed');
  });

  test('retries a temporary 502 during start-trial and then succeeds',
      () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-bootstrap-retry-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    var startTrialAttempts = 0;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    unawaited(() async {
      await for (final request in server) {
        final body = await utf8.decoder.bind(request).join();
        if (request.uri.path == '/api/client/session/start-trial') {
          startTrialAttempts += 1;
          if (startTrialAttempts == 1) {
            request.response
              ..statusCode = HttpStatus.badGateway
              ..headers.contentType = ContentType.text
              ..write('temporary upstream outage');
            await request.response.close();
            continue;
          }
          final decoded = jsonDecode(body) as Map<String, dynamic>;
          expect(decoded['install_id'], isNotEmpty);
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'session': <String, Object?>{
                    'session_token': 'session-token-2',
                    'account_id': '84',
                  },
                  'provisioning': <String, Object?>{
                    'managed_manifest': <String, Object?>{
                      'url': '/api/client/profile/managed',
                    },
                  },
                },
              ),
            );
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/route-policy') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(jsonEncode(<String, Object?>{'ok': true}));
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/profile/managed') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'profile_revision': 'rev-retry',
                  'config_format': 'singbox-json',
                  'config_payload': <String, Object?>{
                    'outbounds': <Object?>[
                      <String, Object?>{
                        'type': 'selector',
                        'tag': 'proxy',
                        'outbounds': <Object?>['node-1'],
                      },
                      <String, Object?>{
                        'type': 'vless',
                        'tag': 'node-1',
                        'server': 'nl.kiwunaka.space',
                        'server_port': 443,
                        'uuid': 'test-uuid',
                      },
                    ],
                    'route': <String, Object?>{
                      'final': 'proxy',
                    },
                  },
                },
              ),
            );
          await request.response.close();
          continue;
        }

        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    }());

    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => tempDirectory,
      delayScheduler: (_) async {},
    );

    final payload = await bootstrapper.resolveManagedProfile(
      hostPlatform: HostPlatform.android,
      routeMode: RouteMode.fullTunnel,
    );

    expect(startTrialAttempts, 2);
    expect(payload.profileName, 'pokrov-android-rev-retry');
    expect(payload.configPayload, contains('"type": "tun"'));
    expect(payload.configPayload, contains('"override_android_vpn": true'));
    expect(payload.configPayload, contains('"final": "proxy"'));
  });

  test(
      'materializes a tunnel-ready runtime config from an outbounds-only profile',
      () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-bootstrap-materialize-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    unawaited(() async {
      await for (final request in server) {
        final body = await utf8.decoder.bind(request).join();
        if (request.uri.path == '/api/client/session/start-trial') {
          final decoded = jsonDecode(body) as Map<String, dynamic>;
          expect(decoded['install_id'], isNotEmpty);
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'session': <String, Object?>{
                    'session_token': 'session-token-3',
                    'account_id': '126',
                  },
                  'provisioning': <String, Object?>{
                    'managed_manifest': <String, Object?>{
                      'url': '/api/client/profile/managed',
                    },
                  },
                },
              ),
            );
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/route-policy') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(jsonEncode(<String, Object?>{'ok': true}));
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/profile/managed') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'profile_revision': 'rev-materialized',
                  'config_format': 'singbox-json',
                  'config_payload': <String, Object?>{
                    '_meta': <String, Object?>{
                      'source': 'managed',
                    },
                    'outbounds': <Object?>[
                      <String, Object?>{
                        'type': 'vless',
                        'tag': 'legacy-reality-fallback',
                        'server': 'nl.kiwunaka.space',
                        'server_port': 443,
                        'uuid': 'test-uuid',
                      },
                    ],
                  },
                },
              ),
            );
          await request.response.close();
          continue;
        }

        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    }());

    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => tempDirectory,
    );

    final payload = await bootstrapper.resolveManagedProfile(
      hostPlatform: HostPlatform.windows,
      routeMode: RouteMode.fullTunnel,
    );
    final config = jsonDecode(payload.configPayload) as Map<String, dynamic>;
    final inbounds = (config['inbounds'] as List).cast<Map<String, dynamic>>();
    final route = config['route'] as Map<String, dynamic>;

    expect(inbounds, isNotEmpty);
    expect(inbounds.first['type'], 'tun');
    expect(config.containsKey('_meta'), isFalse);
    expect(route['final'], 'select');
    expect(route['auto_detect_interface'], true);
    expect(config['outbounds'].toString(), contains('urltest'));
  });

  test('android materialization excludes desktop loopback listener inbounds',
      () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-bootstrap-android-runtime-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    unawaited(() async {
      await for (final request in server) {
        final body = await utf8.decoder.bind(request).join();
        if (request.uri.path == '/api/client/session/start-trial') {
          final decoded = jsonDecode(body) as Map<String, dynamic>;
          expect(decoded['install_id'], isNotEmpty);
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'session': <String, Object?>{
                    'session_token': 'session-token-android-runtime',
                    'account_id': '252',
                  },
                  'provisioning': <String, Object?>{
                    'managed_manifest': <String, Object?>{
                      'url': '/api/client/profile/managed',
                    },
                  },
                },
              ),
            );
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/route-policy') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(jsonEncode(<String, Object?>{'ok': true}));
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/profile/managed') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'profile_revision': 'rev-android-runtime',
                  'config_format': 'singbox-json',
                  'config_payload': <String, Object?>{
                    '_meta': <String, Object?>{
                      'source': 'managed',
                    },
                    'outbounds': <Object?>[
                      <String, Object?>{
                        'type': 'vless',
                        'tag': 'primary-node',
                        'server': 'nl.kiwunaka.space',
                        'server_port': 443,
                        'uuid': 'test-uuid',
                      },
                    ],
                  },
                },
              ),
            );
          await request.response.close();
          continue;
        }

        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    }());

    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => tempDirectory,
    );

    final payload = await bootstrapper.resolveManagedProfile(
      hostPlatform: HostPlatform.android,
      routeMode: RouteMode.fullTunnel,
    );
    final config = jsonDecode(payload.configPayload) as Map<String, dynamic>;
    final inbounds = (config['inbounds'] as List).cast<Map<String, dynamic>>();
    final route = config['route'] as Map<String, dynamic>;
    final rules = (route['rules'] as List).cast<Map<String, dynamic>>();
    final dns = config['dns'] as Map<String, dynamic>;
    final servers = (dns['servers'] as List).cast<Map<String, dynamic>>();
    final dnsRules = (dns['rules'] as List).cast<Map<String, dynamic>>();

    expect(inbounds, hasLength(1));
    expect(inbounds.where((inbound) => inbound['type'] == 'tun'), hasLength(1));
    expect(
      inbounds.where((inbound) => inbound['tag'] == 'android-private-dns-in'),
      isEmpty,
    );
    expect(
      inbounds.singleWhere((inbound) => inbound['type'] == 'tun')['stack'],
      'mixed',
    );
    expect(
      inbounds
          .singleWhere((inbound) => inbound['type'] == 'tun')['inet6_address'],
      isNotNull,
    );
    expect(
      inbounds.singleWhere(
          (inbound) => inbound['type'] == 'tun')['domain_strategy'],
      'prefer_ipv4',
    );
    expect(payload.configPayload, isNot(contains('"mixed-in"')));
    expect(payload.configPayload, isNot(contains('"dns-in"')));
    expect(
      rules.where((rule) => rule['inbound'] == 'dns-in'),
      isEmpty,
    );
    expect(route['auto_detect_interface'], true);
    expect(route['override_android_vpn'], true);
    expect(
      rules.any(
        (rule) =>
            (rule['inbound'] as List?)?.contains('tun-in') == true &&
            (rule['package_name'] as List?)
                    ?.contains('space.pokrov.pokrov_android_shell') ==
                true &&
            rule['outbound'] == 'direct',
      ),
      isTrue,
    );
    expect(dns['final'], isNotEmpty);
    expect(
      servers.any((server) => server['address'] == 'local'),
      isTrue,
    );
    expect(
      dnsRules.any((rule) =>
          (rule['domain'] as List?)?.contains('nl.kiwunaka.space') ?? false),
      isTrue,
    );
    expect(
      rules.any((rule) => rule['port'] == 53 && rule['outbound'] == 'dns-out'),
      isTrue,
    );
    expect(
      rules.where((rule) =>
          rule['ip_is_private'] == true && rule['outbound'] == 'direct'),
      isEmpty,
    );
  });

  test('preserves a runtime-ready managed config on desktop hosts', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-bootstrap-pass-through-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    unawaited(() async {
      await for (final request in server) {
        final body = await utf8.decoder.bind(request).join();
        if (request.uri.path == '/api/client/session/start-trial') {
          final decoded = jsonDecode(body) as Map<String, dynamic>;
          expect(decoded['install_id'], isNotEmpty);
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'session': <String, Object?>{
                    'session_token': 'session-token-4',
                    'account_id': '168',
                  },
                  'provisioning': <String, Object?>{
                    'managed_manifest': <String, Object?>{
                      'url': '/api/client/profile/managed',
                    },
                  },
                },
              ),
            );
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/route-policy') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(jsonEncode(<String, Object?>{'ok': true}));
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/profile/managed') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'profile_revision': 'rev-ready',
                  'config_format': 'singbox-json',
                  'config_payload': <String, Object?>{
                    '_meta': <String, Object?>{'source': 'managed'},
                    'log': <String, Object?>{'level': 'info'},
                    'dns': <String, Object?>{
                      'servers': <Object?>['local'],
                    },
                    'inbounds': <Object?>[
                      <String, Object?>{
                        'type': 'tun',
                        'tag': 'tun-in',
                      },
                    ],
                    'outbounds': <Object?>[
                      <String, Object?>{
                        'type': 'selector',
                        'tag': 'proxy',
                      },
                    ],
                    'route': <String, Object?>{
                      'final': 'proxy',
                      'auto_detect_interface': true,
                      'override_android_vpn': true,
                    },
                    'experimental': <String, Object?>{
                      'cache_file': <String, Object?>{'enabled': true},
                    },
                  },
                },
              ),
            );
          await request.response.close();
          continue;
        }

        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    }());

    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => tempDirectory,
    );

    final payload = await bootstrapper.resolveManagedProfile(
      hostPlatform: HostPlatform.windows,
      routeMode: RouteMode.fullTunnel,
    );
    final config = jsonDecode(payload.configPayload) as Map<String, dynamic>;

    expect(config['inbounds'], hasLength(1));
    expect(config['experimental'], isNotNull);
    expect(config.containsKey('_meta'), isFalse);
    expect(config.toString(), contains('auto_detect_interface'));
    expect(config.toString(), contains('override_android_vpn'));
    expect((config['dns'] as Map<String, dynamic>)['servers'], ['local']);
    expect(payload.routeMode, RouteMode.fullTunnel);
  });

  test(
      'android preserves managed routing semantics while removing desktop-only DNS surfaces',
      () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-bootstrap-android-runtime-ready-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    unawaited(() async {
      await for (final request in server) {
        final body = await utf8.decoder.bind(request).join();
        if (request.uri.path == '/api/client/session/start-trial') {
          final decoded = jsonDecode(body) as Map<String, dynamic>;
          expect(decoded['install_id'], isNotEmpty);
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'session': <String, Object?>{
                    'session_token': 'session-token-android-runtime-ready',
                    'account_id': '336',
                  },
                  'provisioning': <String, Object?>{
                    'managed_manifest': <String, Object?>{
                      'url': '/api/client/profile/managed',
                    },
                  },
                },
              ),
            );
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/route-policy') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(jsonEncode(<String, Object?>{'ok': true}));
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/profile/managed') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'profile_revision': 'rev-android-runtime-ready',
                  'config_format': 'singbox-json',
                  'config_payload': <String, Object?>{
                    '_meta': <String, Object?>{'source': 'managed'},
                    'log': <String, Object?>{'level': 'info'},
                    'dns': <String, Object?>{
                      'servers': <Object?>[
                        <String, Object?>{
                          'tag': 'legacy-local-dot',
                          'address': 'tls://127.0.0.1:853',
                        },
                      ],
                    },
                    'inbounds': <Object?>[
                      <String, Object?>{
                        'type': 'tun',
                        'tag': 'tun-in',
                      },
                      <String, Object?>{
                        'type': 'direct',
                        'tag': 'dns-in',
                        'listen': '127.0.0.1',
                        'listen_port': 853,
                      },
                    ],
                    'outbounds': <Object?>[
                      <String, Object?>{
                        'type': 'selector',
                        'tag': 'proxy',
                        'outbounds': <Object?>['node-1'],
                      },
                      <String, Object?>{
                        'type': 'vless',
                        'tag': 'node-1',
                        'server': 'nl.kiwunaka.space',
                        'server_port': 443,
                        'uuid': 'test-uuid',
                      },
                    ],
                    'route': <String, Object?>{
                      'final': 'proxy',
                      'auto_detect_interface': true,
                      'override_android_vpn': true,
                    },
                    'experimental': <String, Object?>{
                      'cache_file': <String, Object?>{'enabled': true},
                    },
                  },
                },
              ),
            );
          await request.response.close();
          continue;
        }

        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    }());

    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => tempDirectory,
    );

    final payload = await bootstrapper.resolveManagedProfile(
      hostPlatform: HostPlatform.android,
      routeMode: RouteMode.fullTunnel,
    );
    final config = jsonDecode(payload.configPayload) as Map<String, dynamic>;
    final dns = config['dns'] as Map<String, dynamic>;
    final inbounds = (config['inbounds'] as List).cast<Map<String, dynamic>>();
    final servers = (dns['servers'] as List).cast<Map<String, dynamic>>();
    final dnsDirectServer = servers.singleWhere(
      (server) => server['tag'] == 'dns-direct',
    );
    final route = config['route'] as Map<String, dynamic>;
    final rules = (route['rules'] as List).cast<Map<String, dynamic>>();

    expect(config.containsKey('_meta'), isFalse);
    expect(payload.configPayload, isNot(contains('"dns-in"')));
    expect(payload.configPayload, contains('"override_android_vpn": true'));
    expect(payload.configPayload, contains('"auto_detect_interface": true'));
    expect(inbounds, hasLength(1));
    expect(inbounds.where((inbound) => inbound['type'] == 'tun'), hasLength(1));
    expect(
      inbounds.where((inbound) => inbound['tag'] == 'android-private-dns-in'),
      isEmpty,
    );
    expect(
      inbounds.singleWhere((inbound) => inbound['type'] == 'tun')['stack'],
      'mixed',
    );
    expect(
      inbounds
          .singleWhere((inbound) => inbound['type'] == 'tun')['inet6_address'],
      isNotNull,
    );
    expect(
      inbounds.singleWhere(
          (inbound) => inbound['type'] == 'tun')['domain_strategy'],
      'prefer_ipv4',
    );
    expect(servers.map((server) => server['address']), contains('local'));
    expect(
      servers.map((server) => server['address']),
      contains('1.1.1.1'),
    );
    expect(
      servers.map((server) => server['address']),
      contains('1.1.1.1'),
    );
    expect(servers.map((server) => server['address']),
        isNot(contains('tls://127.0.0.1:853')));
    expect(dnsDirectServer['detour'], 'direct');
    expect(dnsDirectServer['address_resolver'], 'dns-local');
    expect(dns['final'], isNotEmpty);
    expect(dns['independent_cache'], isTrue);
    final dnsRules = (dns['rules'] as List).cast<Map<String, dynamic>>();
    final serverDomainRule = dnsRules.singleWhere(
      (rule) =>
          (rule['domain'] as List?)?.contains('nl.kiwunaka.space') ?? false,
    );
    final ipPrivateRule = dnsRules.singleWhere(
      (rule) => rule['ip_is_private'] == true,
    );
    expect(serverDomainRule['server'], isNot('local'));
    expect(ipPrivateRule['server'], isNot(serverDomainRule['server']));
    expect(route['final'], 'proxy');
    expect(rules.where((rule) => rule['protocol'] == 'dns'), isNotEmpty);
    expect(rules.where((rule) => rule['port'] == 53), isNotEmpty);
    expect(
      rules.where((rule) =>
          rule['ip_is_private'] == true && rule['outbound'] == 'direct'),
      isEmpty,
    );
    expect(payload.routeMode, RouteMode.fullTunnel);
  });

  test(
      'android full tunnel strips direct route bypass rules from managed routes',
      () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-bootstrap-android-managed-safe-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    unawaited(() async {
      await for (final request in server) {
        final body = await utf8.decoder.bind(request).join();
        if (request.uri.path == '/api/client/session/start-trial') {
          final decoded = jsonDecode(body) as Map<String, dynamic>;
          expect(decoded['install_id'], isNotEmpty);
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'session': <String, Object?>{
                    'session_token': 'session-token-android-managed-safe',
                    'account_id': '337',
                  },
                  'provisioning': <String, Object?>{
                    'managed_manifest': <String, Object?>{
                      'url': '/api/client/profile/managed',
                    },
                  },
                },
              ),
            );
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/route-policy') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(jsonEncode(<String, Object?>{'ok': true}));
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/profile/managed') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'profile_revision': 'rev-android-managed-safe',
                  'config_format': 'singbox-json',
                  'config_payload': <String, Object?>{
                    '_meta': <String, Object?>{'source': 'managed'},
                    'log': <String, Object?>{'level': 'info'},
                    'dns': <String, Object?>{
                      'servers': <Object?>[
                        <String, Object?>{
                          'tag': 'google',
                          'address': '8.8.8.8',
                          'detour': 'proxy',
                        },
                        <String, Object?>{
                          'tag': 'local',
                          'address': 'local',
                          'detour': 'direct',
                        },
                      ],
                      'final': 'google',
                    },
                    'inbounds': <Object?>[
                      <String, Object?>{
                        'type': 'tun',
                        'tag': 'tun-in',
                      },
                    ],
                    'outbounds': <Object?>[
                      <String, Object?>{
                        'type': 'selector',
                        'tag': 'proxy',
                        'outbounds': <Object?>['node-1'],
                      },
                      <String, Object?>{
                        'type': 'vless',
                        'tag': 'node-1',
                        'server': 'nl.kiwunaka.space',
                        'server_port': 443,
                        'uuid': 'test-uuid',
                      },
                      <String, Object?>{
                        'type': 'direct',
                        'tag': 'direct',
                      },
                      <String, Object?>{
                        'type': 'dns',
                        'tag': 'dns-out',
                      },
                    ],
                    'route': <String, Object?>{
                      'rule_set': <Object?>[
                        <String, Object?>{
                          'type': 'remote',
                          'tag': 'geoip-ru',
                          'format': 'binary',
                          'url': 'https://example.com/geoip-ru.srs',
                          'download_detour': 'direct',
                        },
                      ],
                      'rules': <Object?>[
                        <String, Object?>{
                          'rule_set': <Object?>['geoip-ru'],
                          'outbound': 'direct',
                        },
                        <String, Object?>{
                          'protocol': 'dns',
                          'outbound': 'dns-out',
                        },
                      ],
                      'auto_detect_interface': true,
                      'final': 'proxy',
                    },
                  },
                },
              ),
            );
          await request.response.close();
          continue;
        }

        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    }());

    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => tempDirectory,
    );

    final payload = await bootstrapper.resolveManagedProfile(
      hostPlatform: HostPlatform.android,
      routeMode: RouteMode.fullTunnel,
    );
    final config = jsonDecode(payload.configPayload) as Map<String, dynamic>;
    final dns = config['dns'] as Map<String, dynamic>;
    final servers = (dns['servers'] as List).cast<Map<String, dynamic>>();
    final dnsRules = (dns['rules'] as List).cast<Map<String, dynamic>>();
    final route = config['route'] as Map<String, dynamic>;
    final routeRules = (route['rules'] as List).cast<Map<String, dynamic>>();

    expect(servers.map((server) => server['tag']),
        containsAll(<String>['google', 'local']));
    expect(dns['final'], 'google');
    expect(dns['independent_cache'], isTrue);
    expect(
      dnsRules.any(
        (rule) =>
            (rule['domain'] as List?)?.contains('nl.kiwunaka.space') ??
            false && rule['server'] == 'local',
      ),
      isTrue,
    );
    expect(
      routeRules.any(
        (rule) =>
            (rule['rule_set'] as List?)?.contains('geoip-ru') ??
            false && rule['outbound'] == 'direct',
      ),
      isFalse,
    );
    expect(route['auto_detect_interface'], true);
    expect(route['override_android_vpn'], true);
    expect(
      routeRules.any(
        (rule) =>
            (rule['inbound'] as List?)?.contains('tun-in') == true &&
            (rule['package_name'] as List?)
                    ?.contains('space.pokrov.pokrov_android_shell') ==
                true &&
            rule['outbound'] == 'direct',
      ),
      isTrue,
    );
    expect(route['final'], 'proxy');
  });

  test('android all-except-ru preserves ru direct bypass rules', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-bootstrap-android-all-except-ru-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    final ruleSetBytesByTag = _allExceptRuRuleSetFixtures();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    unawaited(() async {
      await for (final request in server) {
        final body = await utf8.decoder.bind(request).join();
        if (request.uri.path.startsWith('/rule-sets/')) {
          final fileName = request.uri.pathSegments.isEmpty
              ? ''
              : request.uri.pathSegments.last;
          final tag = fileName.replaceAll('.srs', '');
          final bytes = ruleSetBytesByTag[tag];
          if (bytes == null) {
            request.response.statusCode = HttpStatus.notFound;
            await request.response.close();
            continue;
          }
          request.response.add(bytes);
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/session/start-trial') {
          final decoded = jsonDecode(body) as Map<String, dynamic>;
          expect(decoded['install_id'], isNotEmpty);
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'session': <String, Object?>{
                    'session_token': 'session-token-android-all-except-ru',
                    'account_id': '338',
                  },
                  'provisioning': <String, Object?>{
                    'managed_manifest': <String, Object?>{
                      'url': '/api/client/profile/managed',
                    },
                  },
                },
              ),
            );
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/route-policy') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(jsonEncode(<String, Object?>{'ok': true}));
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/profile/managed') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'profile_revision': 'rev-android-all-except-ru',
                  'config_format': 'singbox-json',
                  'config_payload': <String, Object?>{
                    'dns': <String, Object?>{
                      'servers': <Object?>[
                        <String, Object?>{
                          'tag': 'google',
                          'address': '8.8.8.8',
                          'detour': 'proxy',
                        },
                        <String, Object?>{
                          'tag': 'local',
                          'address': 'local',
                          'detour': 'direct',
                        },
                      ],
                      'final': 'google',
                    },
                    'outbounds': <Object?>[
                      <String, Object?>{
                        'type': 'selector',
                        'tag': 'proxy',
                        'outbounds': <Object?>['node-1'],
                      },
                      <String, Object?>{
                        'type': 'vless',
                        'tag': 'node-1',
                        'server': 'nl.kiwunaka.space',
                        'server_port': 443,
                        'uuid': 'test-uuid',
                      },
                      <String, Object?>{
                        'type': 'direct',
                        'tag': 'direct',
                      },
                      <String, Object?>{
                        'type': 'dns',
                        'tag': 'dns-out',
                      },
                    ],
                    'route': <String, Object?>{
                      'rules': <Object?>[
                        <String, Object?>{
                          'rule_set': <Object?>['geoip-ru'],
                          'outbound': 'direct',
                        },
                      ],
                      'final': 'proxy',
                    },
                  },
                },
              ),
            );
          await request.response.close();
          continue;
        }

        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    }());

    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => tempDirectory,
      allExceptRuRuleSetUrlsResolver: (tag) =>
          <String>['http://127.0.0.1:${server.port}/rule-sets/$tag.srs'],
    );

    final payload = await bootstrapper.resolveManagedProfile(
      hostPlatform: HostPlatform.android,
      routeMode: RouteMode.allExceptRu,
    );
    final config = jsonDecode(payload.configPayload) as Map<String, dynamic>;
    final dns = config['dns'] as Map<String, dynamic>;
    final dnsRules = (dns['rules'] as List).cast<Map<String, dynamic>>();
    final route = config['route'] as Map<String, dynamic>;
    final routeRuleSets =
        (route['rule_set'] as List).cast<Map<String, dynamic>>();
    final routeRules = (route['rules'] as List).cast<Map<String, dynamic>>();

    expect(
      routeRuleSets.map((ruleSet) => ruleSet['tag']),
      containsAll(<String>[
        _ruDomainWhitelistRuleSetTag,
        _ruDomainCategoryRuleSetTag,
        _ruIpCountryRuleSetTag,
        _ruIpWhitelistRuleSetTag,
      ]),
    );
    final domainWhitelistRuleSet = routeRuleSets.singleWhere(
      (ruleSet) => ruleSet['tag'] == _ruDomainWhitelistRuleSetTag,
    );
    expect(domainWhitelistRuleSet['type'], 'local');
    expect(domainWhitelistRuleSet['format'], 'binary');
    expect(
      domainWhitelistRuleSet['path'],
      _expectedRuleSetCachePath(tempDirectory, 'ru-domain-whitelist.srs'),
    );
    expect(
      await File(domainWhitelistRuleSet['path'] as String).exists(),
      isTrue,
    );
    expect(
      routeRules.any(
        (rule) =>
            (rule['rule_set'] as List?)?.contains('geoip-ru') ??
            false && rule['outbound'] == 'direct',
      ),
      isTrue,
    );
    expect(
      routeRules.any(
        (rule) =>
            rule['domain_suffix'] == '.ru' && rule['outbound'] == 'direct',
      ),
      isTrue,
    );
    expect(
      routeRules.any(
        (rule) =>
            (rule['rule_set'] as List?)?.contains(_ruIpCountryRuleSetTag) ??
            false && rule['outbound'] == 'direct',
      ),
      isTrue,
    );
    expect(
      dnsRules.any(
        (rule) =>
            (rule['rule_set'] as List?)?.contains(
              _ruDomainWhitelistRuleSetTag,
            ) ??
            false,
      ),
      isTrue,
    );
    expect(route['auto_detect_interface'], true);
    expect(route['override_android_vpn'], true);
    expect(route['final'], 'proxy');
  });

  test('windows all-except-ru injects cached local rule-set definitions',
      () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-bootstrap-windows-all-except-ru-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    final ruleSetBytesByTag = _allExceptRuRuleSetFixtures();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    unawaited(() async {
      await for (final request in server) {
        final body = await utf8.decoder.bind(request).join();
        if (request.uri.path.startsWith('/rule-sets/')) {
          final fileName = request.uri.pathSegments.isEmpty
              ? ''
              : request.uri.pathSegments.last;
          final tag = fileName.replaceAll('.srs', '');
          final bytes = ruleSetBytesByTag[tag];
          if (bytes == null) {
            request.response.statusCode = HttpStatus.notFound;
            await request.response.close();
            continue;
          }
          request.response.add(bytes);
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/session/start-trial') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'session': <String, Object?>{
                    'session_token': 'session-token-windows-all-except-ru',
                    'account_id': '342',
                  },
                  'provisioning': <String, Object?>{
                    'managed_manifest': <String, Object?>{
                      'url': '/api/client/profile/managed',
                    },
                  },
                },
              ),
            );
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/route-policy') {
          final decoded = jsonDecode(body) as Map<String, dynamic>;
          expect(decoded['route_mode'], 'all_traffic');
          request.response
            ..headers.contentType = ContentType.json
            ..write(jsonEncode(<String, Object?>{'ok': true}));
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/profile/managed') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'profile_revision': 'rev-windows-all-except-ru',
                  'config_format': 'singbox-json',
                  'config_payload': <String, Object?>{
                    'outbounds': <Object?>[
                      <String, Object?>{
                        'type': 'selector',
                        'tag': 'proxy',
                        'outbounds': <Object?>['node-1'],
                      },
                      <String, Object?>{
                        'type': 'vless',
                        'tag': 'node-1',
                        'server': 'nl.kiwunaka.space',
                        'server_port': 443,
                        'uuid': 'test-uuid',
                      },
                    ],
                    'route': <String, Object?>{
                      'rule_set': <Object?>[
                        <String, Object?>{
                          'type': 'remote',
                          'tag': 'geoip-ru',
                          'format': 'binary',
                          'url': 'https://example.invalid/geoip-ru.srs',
                        },
                      ],
                      'rules': <Object?>[
                        <String, Object?>{
                          'rule_set': <Object?>['geoip-ru'],
                          'outbound': 'direct',
                        },
                      ],
                      'final': 'proxy',
                    },
                  },
                },
              ),
            );
          await request.response.close();
          continue;
        }

        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    }());

    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => tempDirectory,
      allExceptRuRuleSetUrlsResolver: (tag) =>
          <String>['http://127.0.0.1:${server.port}/rule-sets/$tag.srs'],
    );

    final payload = await bootstrapper.resolveManagedProfile(
      hostPlatform: HostPlatform.windows,
      routeMode: RouteMode.allExceptRu,
    );
    final config = jsonDecode(payload.configPayload) as Map<String, dynamic>;
    final dns = config['dns'] as Map<String, dynamic>;
    final dnsRules = (dns['rules'] as List).cast<Map<String, dynamic>>();
    final route = config['route'] as Map<String, dynamic>;
    final routeRuleSets =
        (route['rule_set'] as List).cast<Map<String, dynamic>>();
    final routeRules = (route['rules'] as List).cast<Map<String, dynamic>>();

    expect(
      routeRuleSets.map((ruleSet) => ruleSet['tag']),
      containsAll(<String>[
        'geoip-ru',
        _ruDomainWhitelistRuleSetTag,
        _ruDomainCategoryRuleSetTag,
        _ruIpCountryRuleSetTag,
        _ruIpWhitelistRuleSetTag,
      ]),
    );
    expect(
      routeRules.any(
        (rule) =>
            (rule['rule_set'] as List?)?.contains(_ruIpWhitelistRuleSetTag) ??
            false && rule['outbound'] == 'direct',
      ),
      isTrue,
    );
    expect(
      routeRules.any(
        (rule) =>
            rule['domain_suffix'] == '.ru' && rule['outbound'] == 'direct',
      ),
      isTrue,
    );
    expect(
      dnsRules.any(
        (rule) =>
            (rule['rule_set'] as List?)?.contains(
              _ruDomainCategoryRuleSetTag,
            ) ??
            false,
      ),
      isTrue,
    );
    expect(route['auto_detect_interface'], true);
    expect(route['find_process'], true);
    expect(
      await File(
        _expectedRuleSetCachePath(tempDirectory, 'ru-ip-whitelist.srs'),
      ).exists(),
      isTrue,
    );
  });

  test(
      'all-except-ru falls back to suffix rules when local rule-set fetch fails',
      () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-bootstrap-all-except-ru-fallback-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    unawaited(() async {
      await for (final request in server) {
        final body = await utf8.decoder.bind(request).join();
        if (request.uri.path.startsWith('/rule-sets/')) {
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/session/start-trial') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'session': <String, Object?>{
                    'session_token': 'session-token-all-except-ru-fallback',
                    'account_id': '343',
                  },
                  'provisioning': <String, Object?>{
                    'managed_manifest': <String, Object?>{
                      'url': '/api/client/profile/managed',
                    },
                  },
                },
              ),
            );
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/route-policy') {
          final decoded = jsonDecode(body) as Map<String, dynamic>;
          expect(decoded['route_mode'], 'all_traffic');
          request.response
            ..headers.contentType = ContentType.json
            ..write(jsonEncode(<String, Object?>{'ok': true}));
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/profile/managed') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'profile_revision': 'rev-all-except-ru-fallback',
                  'config_format': 'singbox-json',
                  'config_payload': <String, Object?>{
                    'outbounds': <Object?>[
                      <String, Object?>{
                        'type': 'selector',
                        'tag': 'proxy',
                        'outbounds': <Object?>['node-1'],
                      },
                      <String, Object?>{
                        'type': 'vless',
                        'tag': 'node-1',
                        'server': 'nl.kiwunaka.space',
                        'server_port': 443,
                        'uuid': 'test-uuid',
                      },
                    ],
                    'route': <String, Object?>{
                      'final': 'proxy',
                    },
                  },
                },
              ),
            );
          await request.response.close();
          continue;
        }

        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    }());

    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => tempDirectory,
      allExceptRuRuleSetUrlsResolver: (tag) =>
          <String>['http://127.0.0.1:${server.port}/rule-sets/$tag.srs'],
    );

    final payload = await bootstrapper.resolveManagedProfile(
      hostPlatform: HostPlatform.windows,
      routeMode: RouteMode.allExceptRu,
    );
    final config = jsonDecode(payload.configPayload) as Map<String, dynamic>;
    final route = config['route'] as Map<String, dynamic>;
    final routeRules = (route['rules'] as List).cast<Map<String, dynamic>>();
    final routeRuleSets = ((route['rule_set'] as List?) ?? const <Object?>[])
        .cast<Map<String, dynamic>>();

    expect(
      routeRules.any(
        (rule) =>
            rule['domain_suffix'] == '.ru' && rule['outbound'] == 'direct',
      ),
      isTrue,
    );
    expect(
      routeRuleSets.any(
        (ruleSet) =>
            (ruleSet['tag']?.toString().startsWith('pokrov-ru-') ?? false),
      ),
      isFalse,
    );
  });

  test(
      'android selected-apps route mode stays explicit no-op until per-app parity lands',
      () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-bootstrap-android-selected-apps-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    unawaited(() async {
      await for (final request in server) {
        final body = await utf8.decoder.bind(request).join();
        if (request.uri.path == '/api/client/session/start-trial') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'session': <String, Object?>{
                    'session_token': 'session-token-android-selected-apps',
                    'account_id': '341',
                  },
                  'provisioning': <String, Object?>{
                    'managed_manifest': <String, Object?>{
                      'url': '/api/client/profile/managed',
                    },
                  },
                },
              ),
            );
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/route-policy') {
          final decoded = jsonDecode(body) as Map<String, dynamic>;
          expect(decoded['route_mode'], 'selected_apps');
          expect(decoded['selected_apps'], isEmpty);
          expect(decoded['requires_elevated_privileges'], isTrue);
          request.response
            ..headers.contentType = ContentType.json
            ..write(jsonEncode(<String, Object?>{'ok': true}));
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/profile/managed') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'profile_revision': 'rev-android-selected-apps',
                  'config_format': 'singbox-json',
                  'config_payload': <String, Object?>{
                    'outbounds': <Object?>[
                      <String, Object?>{
                        'type': 'selector',
                        'tag': 'proxy',
                        'outbounds': <Object?>['node-1'],
                      },
                      <String, Object?>{
                        'type': 'vless',
                        'tag': 'node-1',
                        'server': 'nl.kiwunaka.space',
                        'server_port': 443,
                        'uuid': 'test-uuid',
                      },
                    ],
                    'route': <String, Object?>{
                      'final': 'proxy',
                    },
                  },
                },
              ),
            );
          await request.response.close();
          continue;
        }

        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    }());

    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => tempDirectory,
    );

    final payload = await bootstrapper.resolveManagedProfile(
      hostPlatform: HostPlatform.android,
      routeMode: RouteMode.selectedApps,
    );
    final config = jsonDecode(payload.configPayload) as Map<String, dynamic>;
    final tunInbound = (config['inbounds'] as List)
        .cast<Map<String, dynamic>>()
        .singleWhere((inbound) => inbound['type'] == 'tun');

    expect(tunInbound['include_package'], isEmpty);
    expect(config['route'], containsPair('final', 'proxy'));
  });

  test(
      'android full tunnel rewrites dns final away from direct bootstrap lanes',
      () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-bootstrap-android-dns-final-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    unawaited(() async {
      await for (final request in server) {
        await utf8.decoder.bind(request).join();
        if (request.uri.path == '/api/client/session/start-trial') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'session': <String, Object?>{
                    'session_token': 'session-token-android-dns-final',
                    'account_id': '339',
                  },
                  'provisioning': <String, Object?>{
                    'managed_manifest': <String, Object?>{
                      'url': '/api/client/profile/managed',
                    },
                  },
                },
              ),
            );
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/route-policy') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(jsonEncode(<String, Object?>{'ok': true}));
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/profile/managed') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'profile_revision': 'rev-android-dns-final',
                  'config_format': 'singbox-json',
                  'config_payload': <String, Object?>{
                    'dns': <String, Object?>{
                      'servers': <Object?>[
                        <String, Object?>{
                          'tag': 'local',
                          'address': 'local',
                          'detour': 'direct',
                        },
                        <String, Object?>{
                          'tag': 'bootstrap-direct',
                          'address': '8.8.8.8',
                          'detour': 'direct',
                        },
                      ],
                      'final': 'local',
                    },
                    'outbounds': <Object?>[
                      <String, Object?>{
                        'type': 'selector',
                        'tag': 'proxy',
                        'outbounds': <Object?>['node-1'],
                      },
                      <String, Object?>{
                        'type': 'vless',
                        'tag': 'node-1',
                        'server': 'nl.kiwunaka.space',
                        'server_port': 443,
                        'uuid': 'test-uuid',
                      },
                      <String, Object?>{
                        'type': 'direct',
                        'tag': 'direct',
                      },
                    ],
                    'route': <String, Object?>{
                      'final': 'proxy',
                    },
                  },
                },
              ),
            );
          await request.response.close();
          continue;
        }

        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    }());

    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => tempDirectory,
    );

    final payload = await bootstrapper.resolveManagedProfile(
      hostPlatform: HostPlatform.android,
      routeMode: RouteMode.fullTunnel,
    );
    final config = jsonDecode(payload.configPayload) as Map<String, dynamic>;
    final dns = config['dns'] as Map<String, dynamic>;
    final servers = (dns['servers'] as List).cast<Map<String, dynamic>>();
    final finalServer = servers.singleWhere(
      (server) => server['tag'] == dns['final'],
    );

    expect(dns['final'], 'dns-remote');
    expect(finalServer['address'], '1.1.1.1');
    expect(finalServer['detour'], 'proxy');
    expect(finalServer['address_resolver'], 'local');
  });

  test('android full tunnel removes direct from selector and urltest chains',
      () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-bootstrap-android-selector-sanitize-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    unawaited(() async {
      await for (final request in server) {
        await utf8.decoder.bind(request).join();
        if (request.uri.path == '/api/client/session/start-trial') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'session': <String, Object?>{
                    'session_token': 'session-token-android-selector-sanitize',
                    'account_id': '340',
                  },
                  'provisioning': <String, Object?>{
                    'managed_manifest': <String, Object?>{
                      'url': '/api/client/profile/managed',
                    },
                  },
                },
              ),
            );
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/route-policy') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(jsonEncode(<String, Object?>{'ok': true}));
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/profile/managed') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'profile_revision': 'rev-android-selector-sanitize',
                  'config_format': 'singbox-json',
                  'config_payload': <String, Object?>{
                    'outbounds': <Object?>[
                      <String, Object?>{
                        'type': 'selector',
                        'tag': 'select',
                        'outbounds': <Object?>['auto', 'direct'],
                        'default': 'direct',
                      },
                      <String, Object?>{
                        'type': 'urltest',
                        'tag': 'auto',
                        'outbounds': <Object?>['direct', 'node-1'],
                        'url': 'http://cp.cloudflare.com',
                      },
                      <String, Object?>{
                        'type': 'vless',
                        'tag': 'node-1',
                        'server': 'nl.kiwunaka.space',
                        'server_port': 443,
                        'uuid': 'test-uuid',
                      },
                      <String, Object?>{
                        'type': 'direct',
                        'tag': 'direct',
                      },
                    ],
                    'route': <String, Object?>{
                      'final': 'select',
                    },
                  },
                },
              ),
            );
          await request.response.close();
          continue;
        }

        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    }());

    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => tempDirectory,
    );

    final payload = await bootstrapper.resolveManagedProfile(
      hostPlatform: HostPlatform.android,
      routeMode: RouteMode.fullTunnel,
    );
    final config = jsonDecode(payload.configPayload) as Map<String, dynamic>;
    final outbounds =
        (config['outbounds'] as List).cast<Map<String, dynamic>>();
    final selector =
        outbounds.singleWhere((outbound) => outbound['tag'] == 'select');
    final urltest =
        outbounds.singleWhere((outbound) => outbound['tag'] == 'auto');
    final route = config['route'] as Map<String, dynamic>;

    expect(selector['outbounds'], isNot(contains('direct')));
    expect(selector['default'], isNot('direct'));
    expect(urltest['outbounds'], isNot(contains('direct')));
    expect(route['final'], 'select');
  });

  test(
      'android ipv4-only support context does not keep a dead ipv6 tunnel lane',
      () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pokrov-bootstrap-android-ipv4-only-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    unawaited(() async {
      await for (final request in server) {
        await utf8.decoder.bind(request).join();
        if (request.uri.path == '/api/client/session/start-trial') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'session': <String, Object?>{
                    'session_token': 'session-token-android-ipv4-only',
                    'account_id': '420',
                  },
                  'provisioning': <String, Object?>{
                    'managed_manifest': <String, Object?>{
                      'url': '/api/client/profile/managed',
                    },
                  },
                },
              ),
            );
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/route-policy') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(jsonEncode(<String, Object?>{'ok': true}));
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/api/client/profile/managed') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(
                <String, Object?>{
                  'profile_revision': 'rev-android-ipv4-only',
                  'config_format': 'singbox-json',
                  'support_context': <String, Object?>{
                    'ip_version_preference': 'ipv4_only',
                  },
                  'config_payload': <String, Object?>{
                    'outbounds': <Object?>[
                      <String, Object?>{
                        'type': 'vless',
                        'tag': 'node-1',
                        'server': 'nl.kiwunaka.space',
                        'server_port': 443,
                        'uuid': 'test-uuid',
                      },
                    ],
                    'route': <String, Object?>{
                      'final': 'node-1',
                    },
                  },
                },
              ),
            );
          await request.response.close();
          continue;
        }

        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    }());

    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://127.0.0.1:${server.port}/',
      supportDirectoryResolver: () async => tempDirectory,
    );

    final payload = await bootstrapper.resolveManagedProfile(
      hostPlatform: HostPlatform.android,
      routeMode: RouteMode.fullTunnel,
    );
    final config = jsonDecode(payload.configPayload) as Map<String, dynamic>;
    final tunInbound = (config['inbounds'] as List)
        .cast<Map<String, dynamic>>()
        .singleWhere((inbound) => inbound['type'] == 'tun');

    expect(tunInbound['inet4_address'], '172.19.0.1/28');
    expect(tunInbound.containsKey('inet6_address'), isFalse);
    expect(tunInbound['domain_strategy'], 'ipv4_only');
    expect(tunInbound['stack'], 'mixed');
  });
}
