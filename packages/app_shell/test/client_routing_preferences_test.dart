import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/app_shell.dart';
import 'package:pokrov_app_shell/routing_catalog_contract.dart';
import 'package:pokrov_app_shell/routing_catalog_policy.dart';
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
  test('untrusted Wi-Fi auto-connect defaults off and round trips explicit opt-in', () {
    const defaults = PokrovRoutingPreferences.defaults();
    expect(defaults.autoConnectOnUntrustedWifi, isFalse);
    expect(PokrovRoutingPreferences.fromJson({}).autoConnectOnUntrustedWifi, isFalse);
    final enabled = defaults.copyWith(autoConnectOnUntrustedWifi: true);
    expect(PokrovRoutingPreferences.fromJson(enabled.toJson()).autoConnectOnUntrustedWifi, isTrue);
    expect(enabled.copyWith(autoConnectOnUntrustedWifi: false).autoConnectOnUntrustedWifi, isFalse);
  });

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

    final vpnRule = rules.firstWhere((rule) =>
        (rule['domain_suffix'] as List?)?.contains('private.example') == true);
    final directRule = rules.firstWhere((rule) =>
        (rule['ip_cidr'] as List?)?.contains('1.1.1.1') == true);
    expect(vpnRule['outbound'], 'proxy');
    expect(directRule['outbound'], 'direct');
    expect(rules.indexOf(vpnRule), lessThan(rules.indexOf(directRule)));
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

    final aiRule = rules.firstWhere((rule) =>
        (rule['domain_suffix'] as List?)?.contains('chatgpt.com') == true);
    expect(aiRule['outbound'], 'awg31-lab');
    expect(servers.first['detour'], 'awg31-lab');
  });

  test('Windows selected process keeps its AWG endpoint with a direct final', () {
    final awgProfile = ManagedProfilePayload(
      profileName: 'awg31-selected-process',
      configPayload: jsonEncode(<String, Object?>{
        'endpoints': <Object?>[
          <String, Object?>{'type': 'awg', 'tag': 'unused-awg'},
          <String, Object?>{'type': 'awg', 'tag': 'awg31-lab'},
        ],
        'outbounds': <Object?>[
          <String, Object?>{'type': 'direct', 'tag': 'direct'},
          <String, Object?>{'type': 'block', 'tag': 'block'},
        ],
        'route': <String, Object?>{
          'final': 'direct',
          'rules': <Object?>[
            <String, Object?>{
              'process_name': <String>['powershell.exe'],
              'outbound': 'awg31-lab',
            },
          ],
        },
      }),
      materializedForRuntime: true,
    );

    final transformed = applyPokrovRoutingPreferences(
      awgProfile,
      const PokrovRoutingPreferences.defaults().copyWith(
        dnsPreset: PokrovDnsPreset.cloudflare,
      ),
      hostPlatform: HostPlatform.windows,
    );
    final config = _jsonMap(transformed.configPayload);
    final route = _map(config['route']);
    final processRule = _maps(route['rules'])
        .singleWhere((rule) => rule.containsKey('process_name'));
    final dnsServers = _maps(_map(config['dns'])['servers']);

    expect(route['final'], 'direct');
    expect(processRule['process_name'], <String>['powershell.exe']);
    expect(processRule['outbound'], 'awg31-lab');
    expect(dnsServers.first['detour'], 'awg31-lab');
    expect(config['endpoints'], _jsonMap(awgProfile.configPayload)['endpoints']);
  });

  test('Windows catalog selected EXEs bound data rules with protected shared DNS', () {
    final profile = _windowsAppProfile(RouteMode.selectedApps);
    final config = _jsonMap(applyPokrovRoutingPreferences(
      profile,
      const PokrovRoutingPreferences.defaults().copyWith(
        dnsPreset: PokrovDnsPreset.cloudflare,
        overrides: [PokrovRouteOverride.tryCreate(
          value: 'bank.example', action: PokrovRouteAction.direct)!],
      ),
      hostPlatform: HostPlatform.windows,
      catalogPolicy: _WindowsAppCatalogPolicy(CatalogRoutingMode.includeApps),
      catalogAccessState: 'paid_unlimited',
      nativeCatalogWindowVersion: 1,
    ).configPayload);
    final route = _map(config['route']);
    final rules = _maps(route['rules']);
    final bypass = rules.indexWhere((rule) => rule['type'] == 'logical');
    final unknownOwner = rules.indexWhere((rule) =>
        rule['invert'] == true && rule['action'] == 'reject');
    final manual = rules.indexWhere((rule) =>
        (rule['domain_suffix'] as List?)?.contains('bank.example') == true);
    final gate = _maps(rules[bypass]['rules']);
    final selected = _maps(gate[1]['rules']);
    expect(rules.first, {'port': 53, 'action': 'hijack-dns'});
    expect(route['find_process'], isTrue);
    expect(route['final'], 'proxy');
    expect(rules[bypass]['outbound'], 'direct');
    expect(gate.first, {'process_path_regex': ['.+']});
    expect(gate[1]['invert'], isTrue);
    expect(selected, contains(equals({'process_name': ['discord.exe']})));
    expect(selected, contains(equals({'process_path_regex': [r'(?i).*\\Discord\\Update\.exe$']})));
    expect(bypass, lessThan(manual));
    expect(unknownOwner, greaterThan(bypass));
    expect(unknownOwner, lessThan(manual));
    expect(rules.where((rule) => rule.containsKey('process_name')), [
      containsPair('process_name', ['pokrov_service.exe']),
    ]);
    final catalogRules = rules.where((rule) =>
        (rule['domain_suffix'] as List?)?.contains('catalog-bank.example') == true).toList();
    expect(catalogRules.first['outbound'], 'direct');
    expect(catalogRules.first['pokrov_catalog_window'], isNotNull);
    expect(catalogRules.last['action'], 'reject');

    final dns = _map(config['dns']);
    final dnsRules = _maps(dns['rules']);
    expect(dns['final'], 'pokrov-catalog-user-dns-vpn');
    expect(dnsRules.where((rule) => rule.containsKey('process_name')), isEmpty);
    expect(dnsRules.where((rule) => rule['server'] == 'pokrov-catalog-user-dns-direct'),
        [containsPair('domain', ['node.example'])]);
    expect(dnsRules.firstWhere((rule) =>
        (rule['domain_suffix'] as List?)?.contains('bank.example') == true)['server'],
        'pokrov-catalog-user-dns-vpn');
    final catalogDnsRules = dnsRules.where((rule) =>
        (rule['domain_suffix'] as List?)?.contains('catalog-bank.example') == true).toList();
    expect(catalogDnsRules.first['server'], 'pokrov-catalog-user-dns-vpn');
    expect(catalogDnsRules.first['pokrov_catalog_window'], catalogRules.first['pokrov_catalog_window']);
    expect(catalogDnsRules.last['action'], 'reject');
  });

  test('Windows catalog excluded EXEs bypass manual and catalog data policy', () {
    final config = _jsonMap(applyPokrovRoutingPreferences(
      _windowsAppProfile(RouteMode.excludedApps),
      const PokrovRoutingPreferences.defaults().copyWith(
        overrides: [PokrovRouteOverride.tryCreate(
          value: 'bank.example', action: PokrovRouteAction.vpn)!],
      ),
      hostPlatform: HostPlatform.windows,
      catalogPolicy: _WindowsAppCatalogPolicy(CatalogRoutingMode.excludeApps),
      catalogAccessState: 'paid_unlimited',
      nativeCatalogWindowVersion: 1,
    ).configPayload);
    final route = _map(config['route']);
    final rules = _maps(route['rules']);
    final excluded = rules.indexWhere((rule) =>
        rule.containsKey('process_name') && rule['outbound'] == 'direct');
    final manual = rules.indexWhere((rule) => rule.containsKey('domain_suffix'));
    expect(rules[excluded], {
      'process_name': ['discord.exe'], 'action': 'route', 'outbound': 'direct',
    });
    expect(excluded, lessThan(manual));
    expect(route['final'], 'proxy');
    expect(_map(config['dns'])['final'], 'dns-remote');
    expect(_maps(_map(config['dns'])['rules']).where((rule) =>
        rule['server'] == 'dns-direct'), [containsPair('domain', ['node.example'])]);
  });

  test('Windows catalog rejects missing native app scope and direct shared DNS', () {
    final profile = _windowsAppProfile(RouteMode.selectedApps);
    final config = _jsonMap(profile.configPayload);
    (config['route'] as Map)['rules'] = [];
    expect(() => applyPokrovRoutingPreferences(
      profile.copyWith(configPayload: jsonEncode(config)),
      const PokrovRoutingPreferences.defaults(),
      hostPlatform: HostPlatform.windows,
      catalogPolicy: _WindowsAppCatalogPolicy(CatalogRoutingMode.includeApps),
      catalogAccessState: 'paid_unlimited',
      nativeCatalogWindowVersion: 1,
    ), throwsA(isA<RoutingCatalogFailure>().having(
        (error) => error.code, 'code', 'catalog_process_scope_invalid')));
    expect(() => applyPokrovRoutingPreferences(
      profile,
      const PokrovRoutingPreferences.defaults().copyWith(
        dnsPreset: PokrovDnsPreset.cloudflare, dnsTransport: PokrovDnsTransport.direct),
      hostPlatform: HostPlatform.windows,
      catalogPolicy: _WindowsAppCatalogPolicy(CatalogRoutingMode.includeApps),
      catalogAccessState: 'paid_unlimited',
      nativeCatalogWindowVersion: 1,
    ), throwsA(isA<RoutingCatalogFailure>().having(
        (error) => error.code, 'code', 'catalog_process_dns_transport_unsupported')));
  });

  test('Windows legacy app modes protect shared DNS without changing data scope', () {
    final profile = _windowsAppProfile(RouteMode.selectedApps);
    final config = _jsonMap(applyPokrovRoutingPreferences(
      profile, const PokrovRoutingPreferences.defaults(),
      hostPlatform: HostPlatform.windows,
    ).configPayload);
    final route = _map(config['route']);
    final processRule = _maps(route['rules'])
        .singleWhere((rule) => rule.containsKey('process_name'));
    expect(route['final'], 'direct');
    expect(processRule['outbound'], 'proxy');
    final dns = _map(config['dns']);
    expect(dns['final'], 'dns-remote');
    expect(_maps(dns['rules']).where((rule) => rule.containsKey('process_name')), isEmpty);
    expect(_maps(dns['rules']).where((rule) => rule['server'] == 'dns-direct'),
        [containsPair('domain', ['node.example'])]);
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

  test(
      'external Smart DNS lab routes selected AI and Games directly through custom DoH',
      () {
    final preferences = const PokrovRoutingPreferences.defaults().copyWith(
      purposeRoutes: const <PokrovPurposeRoute>{
        PokrovPurposeRoute.ai,
        PokrovPurposeRoute.games,
        PokrovPurposeRoute.video,
      },
      dnsPreset: PokrovDnsPreset.custom,
      dnsTransport: PokrovDnsTransport.direct,
      customDnsUrl: 'https://smart.example/dns-query',
      externalSmartDnsEnabled: true,
    );
    final transformed = applyPokrovRoutingPreferences(
      _profile(),
      preferences,
      hostPlatform: HostPlatform.android,
    );
    final config = _jsonMap(transformed.configPayload);
    final rules = _maps(_map(config['route'])['rules']);
    final dns = _map(config['dns']);
    final dnsServers = _maps(dns['servers']);
    final dnsRules = _maps(dns['rules']);

    String outboundFor(String domain) => rules.firstWhere(
          (rule) =>
              (rule['domain_suffix'] as List<Object?>?)?.contains(domain) ==
              true,
        )['outbound'] as String;

    expect(outboundFor('chatgpt.com'), 'direct');
    expect(outboundFor('xbox.com'), 'direct');
    expect(outboundFor('youtube.com'), 'proxy');
    expect(dnsServers.first, <String, Object?>{
      'tag': 'pokrov-user-dns',
      'address': 'https://smart.example/dns-query',
      'detour': 'direct',
    });
    expect(dns['final'], 'profile-dns');
    expect(dnsRules.first['action'], 'route');
    expect(dnsRules.first['server'], 'pokrov-user-dns');
    expect(
      dnsRules.first['domain_suffix'],
      allOf(contains('chatgpt.com'), contains('xbox.com'),
          isNot(contains('youtube.com'))),
    );
    expect(
      explainPokrovRouteDecision(
        destination: 'chatgpt.com',
        preferences: preferences,
        fallbackMode: RouteMode.fullTunnel,
      ).action,
      PokrovRouteAction.direct,
    );
  });

  test('external Smart DNS state fails closed without exact prerequisites', () {
    final invalid = const PokrovRoutingPreferences.defaults().copyWith(
      purposeRoutes: const <PokrovPurposeRoute>{PokrovPurposeRoute.ai},
      dnsPreset: PokrovDnsPreset.google,
      dnsTransport: PokrovDnsTransport.direct,
      externalSmartDnsEnabled: true,
    );

    expect(
      () => applyPokrovRoutingPreferences(
        _profile(),
        invalid,
        hostPlatform: HostPlatform.android,
      ),
      throwsA(isA<FormatException>()),
    );
    expect(
      explainPokrovRouteDecision(
        destination: 'chatgpt.com',
        preferences: invalid,
        fallbackMode: RouteMode.fullTunnel,
      ).action,
      PokrovRouteAction.vpn,
    );

    final sanitized = PokrovRoutingPreferences.fromJson(<String, Object?>{
      'purposeRoutes': <String>['ai'],
      'dnsPreset': 'google',
      'dnsTransport': 'direct',
      'externalSmartDnsEnabled': true,
    });
    expect(sanitized.externalSmartDnsEnabled, isFalse);

    for (final unsafeUrl in <String>[
      'https://smart.example/dns-query?token=plaintext',
      'https://smart.example/dns-query#credential',
      'https://token@smart.example/dns-query',
      'https://smart.example:8443/dns-query',
      'https://smart.example/other-path',
    ]) {
      final unsafe = const PokrovRoutingPreferences.defaults().copyWith(
        purposeRoutes: const <PokrovPurposeRoute>{PokrovPurposeRoute.ai},
        dnsPreset: PokrovDnsPreset.custom,
        dnsTransport: PokrovDnsTransport.direct,
        customDnsUrl: unsafeUrl,
        externalSmartDnsEnabled: true,
      );
      expect(unsafe.canEnableExternalSmartDns, isFalse, reason: unsafeUrl);
      expect(
        () => applyPokrovRoutingPreferences(
          _profile(),
          unsafe,
          hostPlatform: HostPlatform.android,
        ),
        throwsA(isA<FormatException>()),
        reason: unsafeUrl,
      );
    }
  });

  test('valid external Smart DNS preference survives persistence round-trip',
      () {
    final source = const PokrovRoutingPreferences.defaults().copyWith(
      purposeRoutes: const <PokrovPurposeRoute>{PokrovPurposeRoute.games},
      dnsPreset: PokrovDnsPreset.custom,
      dnsTransport: PokrovDnsTransport.direct,
      customDnsUrl: 'https://smart.example/dns-query',
      externalSmartDnsEnabled: true,
    );

    final restored = PokrovRoutingPreferences.fromJson(source.toJson());

    expect(restored.externalSmartDnsEnabled, isTrue);
    expect(restored.canEnableExternalSmartDns, isTrue);
    expect(restored.toJson()['externalSmartDnsEnabled'], isTrue);
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

  test('allExceptRu rejects BitTorrent after sniff and before Direct on Windows', () {
    final direct = PokrovRouteOverride.tryCreate(
      value: 'example.ru',
      action: PokrovRouteAction.direct,
    )!;
    final transformed = applyPokrovRoutingPreferences(
      _windowsProfile().copyWith(routeMode: RouteMode.allExceptRu),
      PokrovRoutingPreferences.defaults().copyWith(
        overrides: <PokrovRouteOverride>[direct],
      ),
      hostPlatform: HostPlatform.windows,
    );
    final config = _jsonMap(transformed.configPayload);
    final rules = _maps(_map(config['route'])['rules']);
    expect(rules[0]['action'], 'hijack-dns');
    expect(rules[1]['action'], 'sniff');
    expect(rules[2], <String, Object?>{
      'protocol': 'bittorrent',
      'action': 'reject',
    });
    expect(rules.indexWhere((rule) => rule['outbound'] == 'direct'), greaterThan(2));
    expect(_maps(config['inbounds']).first.containsKey('exclude_package'), isFalse);
  });

  test('allExceptRu excludes reviewed Android packages from TUN once', () {
    final config = _jsonMap(_profile().configPayload);
    config['inbounds'] = <Object?>[
      <String, Object?>{
        'type': 'tun',
        'tag': 'tun-in',
        'sniff': true,
        'exclude_package': <String>['space.pokrov.pokrov_android_shell'],
      },
    ];
    final route = _map(config['route']);
    route['rules'] = <Object?>[
      <String, Object?>{'protocol': 'dns', 'action': 'hijack-dns'},
      ..._maps(route['rules']),
    ];
    config['route'] = route;
    final packageIds = pokrovRuAppCatalog.map((entry) => entry.packageId).toList();
    final profile = _profile().copyWith(
      routeMode: RouteMode.allExceptRu,
      configPayload: jsonEncode(config),
    );
    final once = applyPokrovRoutingPreferences(
      profile,
      const PokrovRoutingPreferences.defaults(),
      hostPlatform: HostPlatform.android,
      defaultRuAppPackageIds: packageIds,
    );
    final twice = applyPokrovRoutingPreferences(
      once,
      const PokrovRoutingPreferences.defaults(),
      hostPlatform: HostPlatform.android,
      defaultRuAppPackageIds: packageIds,
    );
    final finalConfig = _jsonMap(twice.configPayload);
    final tun = _maps(finalConfig['inbounds']).single;
    final rules = _maps(_map(finalConfig['route'])['rules']);
    expect(tun['exclude_package'], <String>[
      'space.pokrov.pokrov_android_shell',
      ...packageIds,
    ]);
    expect(tun.containsKey('include_package'), isFalse);
    expect(rules[0]['action'], 'hijack-dns');
    expect(rules[1], <String, Object?>{
      'protocol': 'bittorrent',
      'action': 'reject',
    });
    expect(rules.where((rule) => rule['protocol'] == 'bittorrent'), hasLength(1));
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
      value: '8.8.8.0/24',
      action: PokrovRouteAction.direct,
    )!;
    final preferences = PokrovRoutingPreferences.defaults().copyWith(
      purposeRoutes: const <PokrovPurposeRoute>{PokrovPurposeRoute.ai},
      overrides: <PokrovRouteOverride>[subnet],
    );

    final privateDecision = explainPokrovRouteDecision(
      destination: '8.8.8.8',
      preferences: preferences,
      fallbackMode: RouteMode.fullTunnel,
    );
    final aiDecision = explainPokrovRouteDecision(
      destination: 'api.openai.com',
      preferences: preferences,
      fallbackMode: RouteMode.allExceptRu,
    );

    expect(privateDecision.action, PokrovRouteAction.direct);
    expect(privateDecision.matchedValue, '8.8.8.0/24');
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

  test('client AI and gaming domains match the Smart DNS policy copy',
      () async {
    final policy = _jsonMap(
      await _readRepositoryFile('config/smart-dns-policy.v1.json'),
    );
    final groups = _map(policy['groups']);

    expect(
      pokrovPurposeDomains(PokrovPurposeRoute.ai),
      (groups['ai'] as List<Object?>).cast<String>(),
    );
    expect(
      pokrovPurposeDomains(PokrovPurposeRoute.games),
      (groups['gaming_services'] as List<Object?>).cast<String>(),
    );
    expect(policy['recursive_dns'], isFalse);
  });
}

Future<String> _readRepositoryFile(String relativePath) async {
  for (final path in <String>[
    relativePath,
    '../../$relativePath',
  ]) {
    final file = File(path);
    if (await file.exists()) {
      return file.readAsString();
    }
  }
  throw FileSystemException('Repository file not found', relativePath);
}

class _WindowsAppCatalogPolicy implements CatalogDomainPolicy {
  _WindowsAppCatalogPolicy(this.mode);

  @override
  final CatalogRoutingMode mode;
  @override
  String get platform => 'windows';
  @override
  String get accessState => 'paid_unlimited';
  @override
  CatalogRouteAction get defaultAction => CatalogRouteAction.vpn;
  @override
  DateTime get issuedAt => DateTime.now().toUtc().subtract(const Duration(hours: 1));
  @override
  DateTime get expiresAt => DateTime.now().toUtc().add(const Duration(hours: 1));
  @override
  List<CatalogDomainDecision> get rules => [_WindowsAppCatalogDecision()];
  @override
  Set<String> get selectedServiceIds => const {};
  @override
  Null get smartAccessProfile => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _WindowsAppCatalogDecision implements CatalogDomainDecision {
  @override
  String get serviceId => 'catalog-bank';
  @override
  CatalogDomain get domain => _WindowsAppCatalogDomain();
  @override
  CatalogRouteAction get action => CatalogRouteAction.direct;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _WindowsAppCatalogDomain implements CatalogDomain {
  @override
  String get name => 'catalog-bank.example';
  @override
  bool get suffix => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ManagedProfilePayload _windowsAppProfile(RouteMode mode) {
  final config = _jsonMap(_windowsProfile().configPayload);
  final outbounds = _maps(config['outbounds']);
  final leaf = outbounds.singleWhere((outbound) => outbound['tag'] == 'proxy');
  leaf['tag'] = 'proxy-leaf';
  leaf['server'] = 'node.example';
  config['outbounds'] = [
    {'type': 'selector', 'tag': 'unused-proxy', 'outbounds': ['proxy-leaf']},
    {'type': 'selector', 'tag': 'proxy', 'outbounds': ['proxy-leaf']},
    ...outbounds,
  ];
  final route = _map(config['route']);
  route['final'] = mode == RouteMode.selectedApps ? 'direct' : 'proxy';
  route['rules'] = [
    ..._maps(route['rules']),
    {'process_name': ['discord.exe'],
      'outbound': mode == RouteMode.selectedApps ? 'proxy' : 'direct'},
    if (mode == RouteMode.selectedApps)
      {'process_path_regex': [r'(?i).*\\Discord\\Update\.exe$'], 'outbound': 'proxy'},
  ];
  config['route'] = route;
  final dns = _map(config['dns']);
  dns['servers'] = [..._maps(dns['servers']),
    {'tag': 'dns-direct', 'type': 'udp', 'server': '1.1.1.1', 'detour': 'direct'}];
  dns['rules'] = [
    {'domain': ['node.example'], 'server': 'dns-direct'},
    {'process_name': ['discord.exe'], 'server': 'dns-remote'},
    {'domain_suffix': ['bank.example'], 'server': 'dns-direct'},
  ];
  dns['final'] = 'dns-direct';
  config['dns'] = dns;
  return _windowsProfile().copyWith(routeMode: mode, configPayload: jsonEncode(config));
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
