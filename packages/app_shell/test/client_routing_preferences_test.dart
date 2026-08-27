import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/app_shell.dart';
import 'package:pokrov_core_domain/core_domain.dart';
import 'package:pokrov_runtime_engine/runtime_engine.dart';

Future<String> _readRoutingFixture(String name) async {
  for (final path in <String>[
    'packages/app_shell/test/fixtures/$name',
    'test/fixtures/$name',
  ]) {
    final file = File(path);
    if (await file.exists()) {
      return file.readAsString();
    }
  }
  throw FileSystemException('Fixture not found', name);
}

void main() {
  test('validates and normalizes domain, IP and CIDR overrides', () {
    final domain = PokrovRouteOverride.tryCreate(
      value: '*.Example.COM.',
      action: PokrovRouteAction.vpn,
    );
    final ip = PokrovRouteOverride.tryCreate(
      value: '1.1.1.1',
      action: PokrovRouteAction.direct,
    );
    final subnet = PokrovRouteOverride.tryCreate(
      value: '10.0.0.0/8',
      action: PokrovRouteAction.direct,
    );

    expect(domain?.value, 'example.com');
    expect(domain?.matchType, PokrovRouteMatchType.domain);
    expect(ip?.matchType, PokrovRouteMatchType.ip);
    expect(subnet?.matchType, PokrovRouteMatchType.subnet);
    expect(
      PokrovRouteOverride.tryCreate(
        value: 'https://example.com/path',
        action: PokrovRouteAction.vpn,
      ),
      isNull,
    );
    expect(
      PokrovRouteOverride.tryCreate(
        value: '10.0.0.0/33',
        action: PokrovRouteAction.vpn,
      ),
      isNull,
    );
  });

  test('custom and purpose routes are injected ahead of base rules', () {
    final directIp = PokrovRouteOverride.tryCreate(
      value: '1.1.1.1',
      action: PokrovRouteAction.direct,
    )!;
    final vpnDomain = PokrovRouteOverride.tryCreate(
      value: 'private.example',
      action: PokrovRouteAction.vpn,
    )!;
    final preferences = PokrovRoutingPreferences.defaults().copyWith(
      purposeRoutes: const <PokrovPurposeRoute>{
        PokrovPurposeRoute.video,
        PokrovPurposeRoute.ruDirect,
      },
      overrides: <PokrovRouteOverride>[vpnDomain, directIp],
    );

    final transformed = applyPokrovRoutingPreferences(
      _profile(),
      preferences,
      hostPlatform: HostPlatform.android,
    );
    final config = _jsonMap(transformed.configPayload);
    final route = _map(config['route']);
    final rules = _maps(route['rules']);

    expect(rules[0]['domain_suffix'], <String>['private.example']);
    expect(rules[0]['outbound'], 'proxy');
    expect(rules[1]['ip_cidr'], <String>['1.1.1.1']);
    expect(rules[1]['outbound'], 'direct');
    expect(
      rules.any(
        (rule) =>
            (rule['domain_suffix'] as List<Object?>?)
                    ?.contains('youtube.com') ==
                true &&
            rule['outbound'] == 'proxy',
      ),
      isTrue,
    );
    expect(
      rules.any(
        (rule) =>
            (rule['domain_suffix'] as List<Object?>?)?.contains('ru') == true &&
            rule['outbound'] == 'direct',
      ),
      isTrue,
    );
    expect(rules.last['protocol'], 'dns');
  });

  test('DNS and LAN settings materially change staged config', () {
    final preferences = PokrovRoutingPreferences.defaults().copyWith(
      dnsPreset: PokrovDnsPreset.cloudflare,
      allowLan: false,
    );
    final transformed = applyPokrovRoutingPreferences(
      _profile(),
      preferences,
      hostPlatform: HostPlatform.android,
    );
    final config = _jsonMap(transformed.configPayload);
    final routeRules = _maps(_map(config['route'])['rules']);
    final dns = _map(config['dns']);
    final dnsServers = _maps(dns['servers']);

    expect(
      routeRules.any(
        (rule) => rule['ip_is_private'] == true && rule['outbound'] == 'direct',
      ),
      isFalse,
    );
    expect(dns['final'], 'pokrov-user-dns');
    expect(dnsServers.first['address'], 'https://1.1.1.1/dns-query');
    expect(dnsServers.first['detour'], 'proxy');
  });

  test('direct-only Windows profile fails closed before native staging', () {
    final directOnly = ManagedProfilePayload(
      profileName: 'direct-only',
      configPayload: jsonEncode(<String, Object?>{
        'inbounds': <Object?>[
          <String, Object?>{'type': 'tun', 'tag': 'tun-in'},
        ],
        'outbounds': <Object?>[
          <String, Object?>{'type': 'direct', 'tag': 'direct'},
        ],
        'route': <String, Object?>{'final': 'direct', 'rules': <Object?>[]},
      }),
      materializedForRuntime: true,
    );

    expect(
      () => applyPokrovRoutingPreferences(
        directOnly,
        const PokrovRoutingPreferences.defaults().copyWith(
          purposeRoutes: <PokrovPurposeRoute>{PokrovPurposeRoute.ai},
        ),
        hostPlatform: HostPlatform.windows,
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('AWG endpoint is a valid VPN target for AI and DNS rules', () {
    final awgProfile = ManagedProfilePayload(
      profileName: 'awg31-routing',
      configPayload: jsonEncode(<String, Object?>{
        'dns': <String, Object?>{'servers': <Object?>[]},
        'endpoints': <Object?>[
          <String, Object?>{'type': 'awg', 'tag': 'awg31-lab'},
        ],
        'outbounds': <Object?>[
          <String, Object?>{'type': 'direct', 'tag': 'direct'},
          <String, Object?>{'type': 'dns', 'tag': 'dns-out'},
        ],
        'route': <String, Object?>{
          'final': 'awg31-lab',
          'rules': <Object?>[],
        },
      }),
      materializedForRuntime: true,
    );

    final transformed = applyPokrovRoutingPreferences(
      awgProfile,
      const PokrovRoutingPreferences.defaults().copyWith(
        purposeRoutes: <PokrovPurposeRoute>{PokrovPurposeRoute.ai},
        dnsPreset: PokrovDnsPreset.cloudflare,
      ),
      hostPlatform: HostPlatform.android,
    );
    final config = _jsonMap(transformed.configPayload);
    final rules = _maps(_map(config['route'])['rules']);
    final servers = _maps(_map(config['dns'])['servers']);

    expect(rules.first['outbound'], 'awg31-lab');
    expect((rules.first['domain_suffix'] as List), contains('chatgpt.com'));
    expect(servers.first['detour'], 'awg31-lab');
  });

  test('AdGuard toggle stages the filtering DoH resolver through VPN', () {
    final transformed = applyPokrovRoutingPreferences(
      _profile(),
      const PokrovRoutingPreferences.defaults().copyWith(
        dnsPreset: PokrovDnsPreset.adguard,
      ),
      hostPlatform: HostPlatform.android,
    );
    final dns = _map(_jsonMap(transformed.configPayload)['dns']);
    final dnsServers = _maps(dns['servers']);

    expect(dns['final'], 'pokrov-user-dns');
    expect(dns['independent_cache'], isTrue);
    expect(dnsServers.first, <String, Object?>{
      'tag': 'pokrov-user-dns',
      'address': 'https://dns.adguard-dns.com/dns-query',
      'detour': 'proxy',
    });
  });

  test('direct DoH lab keeps AI traffic on VPN and only DNS on direct', () {
    final transformed = applyPokrovRoutingPreferences(
      _profile(),
      const PokrovRoutingPreferences.defaults().copyWith(
        purposeRoutes: <PokrovPurposeRoute>{PokrovPurposeRoute.ai},
        dnsPreset: PokrovDnsPreset.google,
        dnsTransport: PokrovDnsTransport.direct,
      ),
      hostPlatform: HostPlatform.android,
    );
    final config = _jsonMap(transformed.configPayload);
    final rules = _maps(_map(config['route'])['rules']);
    final dnsServers = _maps(_map(config['dns'])['servers']);

    expect(
      rules.firstWhere(
        (rule) =>
            (rule['domain_suffix'] as List<Object?>?)
                    ?.contains('chatgpt.com') ==
                true,
      )['outbound'],
      'proxy',
    );
    expect(dnsServers.first, <String, Object?>{
      'tag': 'pokrov-user-dns',
      'address': 'https://dns.google/dns-query',
      'detour': 'direct',
    });
  });

  test('missing DNS transport state keeps the safe VPN default', () {
    final restored = PokrovRoutingPreferences.fromJson(<String, Object?>{
      'dnsPreset': 'cloudflare',
    });

    expect(restored.dnsTransport, PokrovDnsTransport.vpn);
    expect(restored.toJson()['dnsTransport'], 'vpn');
  });

  test('Windows keeps DNS interception ahead of LAN and applies TUN stack', () {
    final override = PokrovRouteOverride.tryCreate(
      value: 'private.example',
      action: PokrovRouteAction.vpn,
    )!;
    final transformed = applyPokrovRoutingPreferences(
      _windowsProfile(),
      const PokrovRoutingPreferences.defaults().copyWith(
        purposeRoutes: <PokrovPurposeRoute>{PokrovPurposeRoute.video},
        overrides: <PokrovRouteOverride>[override],
        tunStack: PokrovTunStack.gvisor,
      ),
      hostPlatform: HostPlatform.windows,
    );
    final config = _jsonMap(transformed.configPayload);
    final rules = _maps(_map(config['route'])['rules']);
    final inbounds = _maps(config['inbounds']);

    expect(rules.first, <String, Object?>{
      'port': 53,
      'action': 'hijack-dns',
    });
    expect(rules[1], <String, Object?>{'action': 'sniff'});
    expect(
      rules.indexWhere((rule) => rule['ip_is_private'] == true),
      greaterThan(1),
    );
    expect(
      inbounds.singleWhere((inbound) => inbound['type'] == 'tun')['stack'],
      'gvisor',
    );
    expect(
      inbounds
          .singleWhere((inbound) => inbound['type'] == 'mixed')
          .containsKey('set_system_proxy'),
      isFalse,
    );
  });

  test('legacy Windows system-proxy preference migrates to service TUN',
      () async {
    final fixture = jsonDecode(
      await _readRoutingFixture('routing-preferences-v0.json'),
    ) as Map<String, dynamic>;
    final migrated = PokrovRoutingPreferences.fromJson(
      fixture,
    );
    final transformed = applyPokrovRoutingPreferences(
      _windowsProfile(),
      migrated,
      hostPlatform: HostPlatform.windows,
    );
    final inbounds = _maps(_jsonMap(transformed.configPayload)['inbounds']);

    expect(migrated.windowsConnectionMode, PokrovWindowsConnectionMode.vpn);
    expect(inbounds.where((inbound) => inbound['type'] == 'tun'), isNotEmpty);
    expect(
      inbounds.singleWhere((inbound) => inbound['type'] == 'mixed'),
      isNot(contains('set_system_proxy')),
    );
  });

  test('same preferences are idempotent and malformed config is untouched', () {
    final rule = PokrovRouteOverride.tryCreate(
      value: 'example.com',
      action: PokrovRouteAction.vpn,
    )!;
    final preferences = PokrovRoutingPreferences.defaults().copyWith(
      overrides: <PokrovRouteOverride>[rule],
      dnsPreset: PokrovDnsPreset.google,
    );
    final once = applyPokrovRoutingPreferences(
      _profile(),
      preferences,
      hostPlatform: HostPlatform.android,
    );
    final twice = applyPokrovRoutingPreferences(
      once,
      preferences,
      hostPlatform: HostPlatform.android,
    );
    final rules = _maps(_map(_jsonMap(twice.configPayload)['route'])['rules']);

    expect(
      rules
          .where(
            (item) =>
                (item['domain_suffix'] as List<Object?>?)?.contains(
                  'example.com',
                ) ==
                true,
          )
          .length,
      1,
    );
    expect(
      _maps(_map(_jsonMap(twice.configPayload)['dns'])['servers'])
          .where((item) => item['tag'] == 'pokrov-user-dns')
          .length,
      1,
    );

    const malformed = ManagedProfilePayload(
      profileName: 'broken',
      configPayload: '{broken',
      materializedForRuntime: true,
    );
    expect(
      identical(
        applyPokrovRoutingPreferences(
          malformed,
          preferences,
          hostPlatform: HostPlatform.android,
        ),
        malformed,
      ),
      isTrue,
    );
  });

  test('route explainer reports the exact matching rule', () {
    final subnet = PokrovRouteOverride.tryCreate(
      value: '10.0.0.0/8',
      action: PokrovRouteAction.direct,
    )!;
    final preferences = PokrovRoutingPreferences.defaults().copyWith(
      purposeRoutes: const <PokrovPurposeRoute>{PokrovPurposeRoute.ai},
      overrides: <PokrovRouteOverride>[subnet],
    );

    final privateDecision = explainPokrovRouteDecision(
      destination: '10.1.2.3',
      preferences: preferences,
      fallbackMode: RouteMode.fullTunnel,
    );
    final aiDecision = explainPokrovRouteDecision(
      destination: 'api.openai.com',
      preferences: preferences,
      fallbackMode: RouteMode.allExceptRu,
    );

    expect(privateDecision.action, PokrovRouteAction.direct);
    expect(privateDecision.matchedValue, '10.0.0.0/8');
    expect(privateDecision.reason, contains('Ваше правило'));
    expect(aiDecision.action, PokrovRouteAction.vpn);
    expect(aiDecision.reason, contains('AI-сервисы'));
  });

  test('AI and Games purpose routes cover Gemini and Xbox service domains', () {
    final preferences = PokrovRoutingPreferences.defaults().copyWith(
      purposeRoutes: const <PokrovPurposeRoute>{
        PokrovPurposeRoute.ai,
        PokrovPurposeRoute.games,
      },
    );

    for (final destination in <String>[
      'gemini.google.com',
      'generativelanguage.googleapis.com',
      'chat.openai.com',
      'presence-heartbeat.xboxlive.com',
      'catalog.gamepass.com',
    ]) {
      final decision = explainPokrovRouteDecision(
        destination: destination,
        preferences: preferences,
        fallbackMode: RouteMode.allExceptRu,
      );
      expect(decision.action, PokrovRouteAction.vpn, reason: destination);
    }
  });
}

ManagedProfilePayload _profile() => ManagedProfilePayload(
      profileName: 'routing-test',
      configPayload: jsonEncode(<String, Object?>{
        'dns': <String, Object?>{
          'servers': <Object?>[
            <String, Object?>{'tag': 'profile-dns', 'address': 'local'},
          ],
          'final': 'profile-dns',
        },
        'outbounds': <Object?>[
          <String, Object?>{'type': 'direct', 'tag': 'direct'},
          <String, Object?>{'type': 'vless', 'tag': 'proxy'},
        ],
        'route': <String, Object?>{
          'final': 'proxy',
          'rules': <Object?>[
            <String, Object?>{
              'ip_is_private': true,
              'outbound': 'direct',
            },
            <String, Object?>{'protocol': 'dns', 'outbound': 'dns-out'},
          ],
        },
      }),
      materializedForRuntime: true,
    );

ManagedProfilePayload _windowsProfile() => ManagedProfilePayload(
      profileName: 'windows-routing-test',
      configPayload: jsonEncode(<String, Object?>{
        'dns': <String, Object?>{
          'servers': <Object?>[
            <String, Object?>{
              'type': 'tcp',
              'tag': 'dns-remote',
              'server': '1.1.1.1',
              'detour': 'proxy',
            },
          ],
          'final': 'dns-remote',
        },
        'inbounds': <Object?>[
          <String, Object?>{
            'type': 'tun',
            'tag': 'tun-in',
            'stack': 'system',
            'auto_route': true,
            'strict_route': true,
          },
          <String, Object?>{
            'type': 'mixed',
            'tag': 'mixed-in',
            'listen': '127.0.0.1',
            'listen_port': 12334,
          },
        ],
        'outbounds': <Object?>[
          <String, Object?>{'type': 'direct', 'tag': 'direct'},
          <String, Object?>{'type': 'vless', 'tag': 'proxy'},
        ],
        'route': <String, Object?>{
          'final': 'proxy',
          'rules': <Object?>[
            <String, Object?>{
              'ip_is_private': true,
              'outbound': 'direct',
            },
            <String, Object?>{'port': 53, 'action': 'hijack-dns'},
            <String, Object?>{'action': 'sniff'},
          ],
        },
      }),
      materializedForRuntime: true,
    );

Map<String, dynamic> _jsonMap(String value) => (jsonDecode(value) as Map).map(
      (key, item) => MapEntry(key.toString(), item),
    );

Map<String, dynamic> _map(Object? value) => (value as Map).map(
      (key, item) => MapEntry(key.toString(), item),
    );

List<Map<String, dynamic>> _maps(Object? value) => (value as List<Object?>)
    .whereType<Map>()
    .map((item) => item.map((key, value) => MapEntry(key.toString(), value)))
    .toList(growable: false);
