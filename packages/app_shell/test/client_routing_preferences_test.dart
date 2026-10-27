import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/client_routing_preferences.dart';
import 'package:pokrov_app_shell/routing_catalog_contract.dart';
import 'package:pokrov_core_domain/core_domain.dart';
import 'package:pokrov_runtime_engine/runtime_engine.dart';

const _unsupportedUrls = [
  'https://dns.example/dns-query?profile=test',
  'https://dns.example/dns-query?',
  'https://dns.example/dns-query#profile',
  'https://dns.example/dns-query#',
];

PokrovRoutingPreferences _storedDns(String url,
        {PokrovDnsTransport transport = PokrovDnsTransport.vpn}) =>
    PokrovRoutingPreferences.fromJson({
      'dnsPreset': 'custom',
      'dnsTransport': transport.name,
      'customDnsUrl': url,
    });

ManagedProfilePayload _profile({RouteMode mode = RouteMode.fullTunnel}) =>
    ManagedProfilePayload(
      profileName: 'fixture',
      routeMode: mode,
      configPayload: jsonEncode({
        'outbounds': [
          {'type': 'direct', 'tag': 'direct'},
          {'type': 'vless', 'tag': 'proxy'},
        ],
        'route': {'final': 'proxy', 'rules': []},
        'dns': {
          'servers': [
            {
              'tag': 'dns-remote',
              'address': 'https://1.1.1.1/dns-query',
              'detour': 'proxy',
            },
            {'tag': 'dns-direct', 'address': 'local', 'detour': 'direct'},
          ],
          'final': 'dns-remote',
        },
      }),
    );

Map _dnsConfig(PokrovRoutingPreferences preferences, HostPlatform platform,
        {RouteMode mode = RouteMode.fullTunnel}) =>
    (jsonDecode(applyPokrovRoutingPreferences(_profile(mode: mode), preferences,
            hostPlatform: platform)
        .configPayload) as Map)['dns'] as Map;

void main() {
  test('local DPI defaults to auto but preserves a saved opt-out', () {
    expect(const PokrovRoutingPreferences.defaults().localDpiEnabled, isTrue);
    expect(PokrovRoutingPreferences.fromJson({}).localDpiEnabled, isTrue);
    final optedOut = PokrovRoutingPreferences.fromJson({'localDpiEnabled': false});
    expect(optedOut.localDpiEnabled, isFalse);
    expect(PokrovRoutingPreferences.fromJson(optedOut.toJson()).localDpiEnabled, isFalse);
  });

  test('Full ignores saved Internet Direct rules and keeps them for Smart Safe', () {
    final preferences = const PokrovRoutingPreferences.defaults().copyWith(
      overrides: [
        PokrovRouteOverride.tryCreate(value: 'youtube.com', action: PokrovRouteAction.direct)!,
        PokrovRouteOverride.tryCreate(value: 'example.org', action: PokrovRouteAction.vpn)!,
      ],
      purposeRoutes: {PokrovPurposeRoute.ruDirect},
      allowLan: true, lanSubnets: ['10.20.0.0/16'],
      dnsPreset: PokrovDnsPreset.cloudflare, dnsTransport: PokrovDnsTransport.direct,
    );
    Map config(RouteMode mode) => jsonDecode(applyPokrovRoutingPreferences(
      _profile(mode: mode), preferences, hostPlatform: HostPlatform.android).configPayload) as Map;
    List<Map> rules(Map value) => (value['route']['rules'] as List).cast<Map>();
    final full = config(RouteMode.fullTunnel);
    final smart = config(RouteMode.allExceptRu);
    expect(rules(full).any((rule) => rule['domain_suffix']?.contains('youtube.com') == true), isFalse);
    expect(rules(full).any((rule) => rule['domain_suffix']?.contains('ru') == true), isFalse);
    expect(rules(full).any((rule) => rule['domain_suffix']?.contains('example.org') == true &&
        rule['outbound'] == 'proxy'), isTrue);
    expect(rules(full).any((rule) => rule['ip_cidr']?.contains('10.20.0.0/16') == true &&
        rule['outbound'] == 'direct'), isTrue);
    expect(rules(smart).any((rule) => rule['domain_suffix']?.contains('youtube.com') == true &&
        rule['outbound'] == 'direct'), isTrue);
    expect(rules(smart).any((rule) => rule['domain_suffix']?.contains('ru') == true &&
        rule['outbound'] == 'direct'), isTrue);
    final fullDns = full['dns'] as Map;
    final fullResolver = (fullDns['servers'] as List).cast<Map>()
        .singleWhere((server) => server['tag'] == fullDns['final']);
    expect(fullResolver['detour'], 'proxy');
    final smartDns = smart['dns'] as Map;
    final smartResolver = (smartDns['servers'] as List).cast<Map>()
        .singleWhere((server) => server['tag'] == smartDns['final']);
    expect(smartResolver['detour'], isNull);
    expect(explainPokrovRouteDecision(destination: 'youtube.com', preferences: preferences,
        fallbackMode: RouteMode.fullTunnel).action, PokrovRouteAction.vpn);
    expect(explainPokrovRouteDecision(destination: 'youtube.com', preferences: preferences,
        fallbackMode: RouteMode.allExceptRu).action, PokrovRouteAction.direct);
    expect(preferences.dnsTransport, PokrovDnsTransport.direct);
    expect(preferences.overrides.first.action, PokrovRouteAction.direct);
  });

  test('saved custom DoH query and fragment remain editable but are not used',
      () {
    for (final url in _unsupportedUrls) {
      final preferences = _storedDns(url);
      expect(preferences.dnsPreset, PokrovDnsPreset.custom);
      expect(preferences.customDnsUrl, url);
      expect(preferences.effectiveDnsAddress, isNull, reason: url);
      expect(preferences.customDnsError, isNotNull);
      expect(preferences.effectiveDnsTransport, PokrovDnsTransport.vpn);
      final restored = PokrovRoutingPreferences.fromJson(preferences.toJson());
      expect(restored.customDnsUrl, url);
      expect(restored.effectiveDnsAddress, isNull);
    }
  });

  test('unsupported custom DoH keeps complete profile DNS for VPN and Direct',
      () {
    for (final platform in [HostPlatform.android, HostPlatform.windows]) {
      final expected =
          _dnsConfig(const PokrovRoutingPreferences.defaults(), platform);
      for (final transport in PokrovDnsTransport.values) {
        for (final url in _unsupportedUrls) {
          final actual =
              _dnsConfig(_storedDns(url, transport: transport), platform);
          expect(actual, expected,
              reason: '${platform.name}/${transport.name}: $url');
          expect(actual['final'], 'dns-remote');
          expect(
              (actual['servers'] as List)
                  .cast<Map>()
                  .any((server) => server['tag'] == 'pokrov-user-dns'),
              isFalse);
        }
      }
    }
  });

  test('ordinary custom DoH retains host, port and resolver path', () {
    for (final url in [
      'https://dns.example/dns-query',
      'https://dns.example:8443/account/path',
      'https://1.1.1.1/dns-query',
      'https://[2606:4700:4700::1111]/dns-query',
    ]) {
      final preferences = _storedDns(url, transport: PokrovDnsTransport.direct);
      expect(preferences.effectiveDnsAddress, url);
      expect(preferences.customDnsError, isNull);
      final uri = Uri.parse(url);
      final dns = _dnsConfig(preferences, HostPlatform.windows);
      final custom = (dns['servers'] as List)
          .cast<Map>()
          .singleWhere((server) => server['tag'] == 'pokrov-user-dns');
      expect(custom['type'], 'https');
      expect(custom['server'], uri.host);
      expect(custom['server_port'], uri.hasPort ? uri.port : null);
      expect(custom['path'] ?? '/dns-query', uri.path);
      expect(dns['final'], 'pokrov-user-dns');
    }
  });

  test('unsupported direct custom DoH keeps Windows app-scoped DNS usable', () {
    for (final mode in [RouteMode.selectedApps, RouteMode.excludedApps]) {
      final preferences = _storedDns(_unsupportedUrls.first,
          transport: PokrovDnsTransport.direct);
      expect(
          _dnsConfig(preferences, HostPlatform.windows, mode: mode),
          _dnsConfig(
              const PokrovRoutingPreferences.defaults(), HostPlatform.windows,
              mode: mode));
      expect(preferences.effectiveDnsTransport, PokrovDnsTransport.vpn);
      expect(preferences.dnsTransport, PokrovDnsTransport.direct,
          reason:
              'retain the saved choice for correction, without applying it');
      final automatic = preferences.copyWith(
          dnsPreset: PokrovDnsPreset.automatic, customDnsUrl: '');
      expect(automatic.effectiveDnsTransport, PokrovDnsTransport.vpn);
      expect(_dnsConfig(automatic, HostPlatform.windows, mode: mode),
          _dnsConfig(const PokrovRoutingPreferences.defaults(),
              HostPlatform.windows, mode: mode));
      expect(
          () => _dnsConfig(
              _storedDns('https://dns.example/dns-query',
                  transport: PokrovDnsTransport.direct),
              HostPlatform.windows,
              mode: mode),
          throwsA(isA<RoutingCatalogFailure>().having((failure) => failure.code,
              'code', 'catalog_process_dns_transport_unsupported')));
    }
  });

  test('unsafe or malformed stored custom DNS keeps existing automatic default',
      () {
    for (final url in [
      'http://dns.example/dns-query',
      'https://user:password@dns.example/dns-query',
      'https://',
      'https://dns.example/${'x' * 240}',
    ]) {
      final preferences = _storedDns(url);
      expect(preferences.dnsPreset, PokrovDnsPreset.automatic);
      expect(preferences.customDnsUrl, isEmpty);
      expect(preferences.effectiveDnsAddress, isNull);
    }
  });
}
