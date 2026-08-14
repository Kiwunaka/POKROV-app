import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/app_shell.dart';
import 'package:pokrov_core_domain/core_domain.dart';
import 'package:pokrov_runtime_engine/runtime_engine.dart';

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

  test('AdGuard toggle stages the filtering DoH resolver through VPN', () {
    final transformed = applyPokrovRoutingPreferences(
      _profile(),
      const PokrovRoutingPreferences.defaults().copyWith(
        dnsPreset: PokrovDnsPreset.adguard,
      ),
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

  test('same preferences are idempotent and malformed config is untouched', () {
    final rule = PokrovRouteOverride.tryCreate(
      value: 'example.com',
      action: PokrovRouteAction.vpn,
    )!;
    final preferences = PokrovRoutingPreferences.defaults().copyWith(
      overrides: <PokrovRouteOverride>[rule],
      dnsPreset: PokrovDnsPreset.google,
    );
    final once = applyPokrovRoutingPreferences(_profile(), preferences);
    final twice = applyPokrovRoutingPreferences(once, preferences);
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
        applyPokrovRoutingPreferences(malformed, preferences),
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
