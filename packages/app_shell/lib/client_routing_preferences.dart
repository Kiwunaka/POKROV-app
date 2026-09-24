import 'dart:convert';
import 'dart:io';

import 'package:pokrov_core_domain/core_domain.dart';
import 'package:pokrov_runtime_engine/runtime_engine.dart';

import 'routing_catalog_contract.dart';
import 'routing_catalog_materializer.dart';
import 'routing_catalog_policy.dart';

enum PokrovPurposeRoute { video, ai, social, games, ruDirect }

enum PokrovRouteAction { vpn, direct }

enum PokrovRouteMatchType { domain, ip, subnet }

enum PokrovDnsPreset { automatic, cloudflare, google, adguard, custom }

enum PokrovDnsTransport { vpn, direct }

enum PokrovWindowsConnectionMode { vpn }

enum PokrovTunStack { system, mixed, gvisor }

extension PokrovPurposeRoutePresentation on PokrovPurposeRoute {
  String get title => switch (this) {
        PokrovPurposeRoute.video => 'Видео',
        PokrovPurposeRoute.ai => 'AI-сервисы',
        PokrovPurposeRoute.social => 'Соцсети',
        PokrovPurposeRoute.games => 'Игровые сервисы',
        PokrovPurposeRoute.ruDirect => 'RU напрямую',
      };

  String get summary => switch (this) {
        PokrovPurposeRoute.video => 'Стриминг и видеохостинги через VPN.',
        PokrovPurposeRoute.ai =>
          'ChatGPT, Gemini и другие AI-сервисы через VPN.',
        PokrovPurposeRoute.social => 'Соцсети и сообщества через VPN.',
        PokrovPurposeRoute.games =>
          'Xbox, магазины и игровые сообщества через VPN.',
        PokrovPurposeRoute.ruDirect => 'Российские домены и сервисы без VPN.',
      };

  bool get supportsExternalSmartDns => switch (this) {
        PokrovPurposeRoute.ai || PokrovPurposeRoute.games => true,
        _ => false,
      };
}

extension PokrovDnsPresetPresentation on PokrovDnsPreset {
  String get title => switch (this) {
        PokrovDnsPreset.automatic => 'Автоматически',
        PokrovDnsPreset.cloudflare => 'Cloudflare',
        PokrovDnsPreset.google => 'Google',
        PokrovDnsPreset.adguard => 'AdGuard',
        PokrovDnsPreset.custom => 'Свой DoH',
      };

  String? get address => switch (this) {
        PokrovDnsPreset.automatic => null,
        PokrovDnsPreset.cloudflare => 'https://1.1.1.1/dns-query',
        PokrovDnsPreset.google => 'https://dns.google/dns-query',
        PokrovDnsPreset.adguard => 'https://dns.adguard-dns.com/dns-query',
        PokrovDnsPreset.custom => null,
      };
}

extension PokrovWindowsConnectionModePresentation
    on PokrovWindowsConnectionMode {
  String get title => 'VPN через службу POKROV';

  String get summary =>
      'Защищает TCP и UDP через TUN. Приложение остаётся без повышенных прав; системную часть выполняет установленная служба.';
}

extension PokrovTunStackPresentation on PokrovTunStack {
  String get title => switch (this) {
        PokrovTunStack.system => 'System · рекомендуется',
        PokrovTunStack.mixed => 'Mixed · system TCP + gVisor UDP',
        PokrovTunStack.gvisor => 'gVisor · виртуальный стек',
      };
}

class PokrovRouteOverride {
  const PokrovRouteOverride({
    required this.id,
    required this.value,
    required this.matchType,
    required this.action,
  });

  final String id;
  final String value;
  final PokrovRouteMatchType matchType;
  final PokrovRouteAction action;

  static PokrovRouteOverride? tryCreate({
    required String value,
    required PokrovRouteAction action,
  }) {
    final normalized = _normalizeRouteMatch(value);
    if (normalized == null) {
      return null;
    }
    final rawId = '${normalized.$2.name}:${normalized.$1}:${action.name}';
    final id = base64Url.encode(utf8.encode(rawId)).replaceAll('=', '');
    return PokrovRouteOverride(
      id: id.length > 96 ? id.substring(0, 96) : id,
      value: normalized.$1,
      matchType: normalized.$2,
      action: action,
    );
  }

  factory PokrovRouteOverride.fromJson(Map<String, dynamic> json) {
    final action = PokrovRouteAction.values.firstWhere(
      (item) => item.name == _routingText(json['action']),
      orElse: () => PokrovRouteAction.vpn,
    );
    return tryCreate(value: _routingText(json['value']), action: action) ??
        const PokrovRouteOverride(
          id: '',
          value: '',
          matchType: PokrovRouteMatchType.domain,
          action: PokrovRouteAction.vpn,
        );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'value': value,
        'matchType': matchType.name,
        'action': action.name,
      };
}

class PokrovRoutingPreferences {
  const PokrovRoutingPreferences({
    required this.purposeRoutes,
    required this.overrides,
    required this.dnsPreset,
    required this.dnsTransport,
    required this.customDnsUrl,
    this.externalSmartDnsEnabled = false,
    this.selectedCatalogServiceIds = const <String>{},
    required this.allowLan,
    this.lanSubnets = const <String>[],
    required this.trustedWifiNames,
    required this.pauseOnTrustedWifi,
    required this.windowsConnectionMode,
    required this.tunStack,
  });

  const PokrovRoutingPreferences.defaults()
      : purposeRoutes = const <PokrovPurposeRoute>{},
        overrides = const <PokrovRouteOverride>[],
        dnsPreset = PokrovDnsPreset.automatic,
        dnsTransport = PokrovDnsTransport.vpn,
        customDnsUrl = '',
        externalSmartDnsEnabled = false,
        selectedCatalogServiceIds = const <String>{},
        allowLan = false,
        lanSubnets = const <String>[],
        trustedWifiNames = const <String>[],
        pauseOnTrustedWifi = false,
        windowsConnectionMode = PokrovWindowsConnectionMode.vpn,
        tunStack = PokrovTunStack.system;

  final Set<PokrovPurposeRoute> purposeRoutes;
  final List<PokrovRouteOverride> overrides;
  final PokrovDnsPreset dnsPreset;
  final PokrovDnsTransport dnsTransport;
  final String customDnsUrl;
  final bool externalSmartDnsEnabled;
  final Set<String> selectedCatalogServiceIds;
  final bool allowLan;
  final List<String> lanSubnets;
  final List<String> trustedWifiNames;
  final bool pauseOnTrustedWifi;
  final PokrovWindowsConnectionMode windowsConnectionMode;
  final PokrovTunStack tunStack;

  PokrovRoutingPreferences copyWith({
    Set<PokrovPurposeRoute>? purposeRoutes,
    List<PokrovRouteOverride>? overrides,
    PokrovDnsPreset? dnsPreset,
    PokrovDnsTransport? dnsTransport,
    String? customDnsUrl,
    bool? externalSmartDnsEnabled,
    Set<String>? selectedCatalogServiceIds,
    bool? allowLan,
    List<String>? lanSubnets,
    List<String>? trustedWifiNames,
    bool? pauseOnTrustedWifi,
    PokrovWindowsConnectionMode? windowsConnectionMode,
    PokrovTunStack? tunStack,
  }) {
    return PokrovRoutingPreferences(
      purposeRoutes: purposeRoutes ?? this.purposeRoutes,
      overrides: overrides ?? this.overrides,
      dnsPreset: dnsPreset ?? this.dnsPreset,
      dnsTransport: dnsTransport ?? this.dnsTransport,
      customDnsUrl: customDnsUrl ?? this.customDnsUrl,
      externalSmartDnsEnabled:
          externalSmartDnsEnabled ?? this.externalSmartDnsEnabled,
      selectedCatalogServiceIds: Set.unmodifiable(
          selectedCatalogServiceIds ?? this.selectedCatalogServiceIds),
      allowLan: allowLan ?? this.allowLan,
      lanSubnets: List.unmodifiable(lanSubnets ?? this.lanSubnets),
      trustedWifiNames: trustedWifiNames ?? this.trustedWifiNames,
      pauseOnTrustedWifi: pauseOnTrustedWifi ?? this.pauseOnTrustedWifi,
      windowsConnectionMode:
          windowsConnectionMode ?? this.windowsConnectionMode,
      tunStack: tunStack ?? this.tunStack,
    );
  }

  factory PokrovRoutingPreferences.fromJson(Map<String, dynamic> json) {
    final purposes = _routingList(json['purposeRoutes'])
        .map(_routingText)
        .map(
          (name) => PokrovPurposeRoute.values
              .where((item) => item.name == name)
              .firstOrNull,
        )
        .whereType<PokrovPurposeRoute>()
        .toSet();
    final overrides = _routingListOfMaps(json['overrides'])
        .map(PokrovRouteOverride.fromJson)
        .where((item) => item.id.isNotEmpty)
        .take(40)
        .toList(growable: false);
    final dnsPreset = PokrovDnsPreset.values.firstWhere(
      (item) => item.name == _routingText(json['dnsPreset']),
      orElse: () => PokrovDnsPreset.automatic,
    );
    final dnsTransport = PokrovDnsTransport.values.firstWhere(
      (item) => item.name == _routingText(json['dnsTransport']),
      orElse: () => PokrovDnsTransport.vpn,
    );
    final customDns =
        _normalizeDnsUrl(_routingText(json['customDnsUrl'])) ?? '';
    final trustedWifi = _routingList(json['trustedWifiNames'])
        .map(_routingText)
        .where((item) => item.isNotEmpty && item.length <= 64)
        .toSet()
        .take(20)
        .toList(growable: false);
    // `systemProxy` was a pre-service compatibility mode. A LocalSystem Core
    // cannot safely own a per-user WinINET proxy, so old persisted values are
    // deliberately migrated to the authenticated service/TUN lane.
    const windowsConnectionMode = PokrovWindowsConnectionMode.vpn;
    final tunStack = PokrovTunStack.values.firstWhere(
      (item) => item.name == _routingText(json['tunStack']),
      orElse: () => PokrovTunStack.system,
    );
    final normalizedDnsPreset =
        dnsPreset == PokrovDnsPreset.custom && customDns.isEmpty
            ? PokrovDnsPreset.automatic
            : dnsPreset;
    final externalSmartDnsEnabled = json['externalSmartDnsEnabled'] == true &&
        normalizedDnsPreset == PokrovDnsPreset.custom &&
        _isExternalSmartDnsUrl(customDns) &&
        dnsTransport == PokrovDnsTransport.direct &&
        purposes.any((purpose) => purpose.supportsExternalSmartDns);
    final lanSubnets = _readLanSubnets(json['lanSubnets']);
    return PokrovRoutingPreferences(
      purposeRoutes: Set<PokrovPurposeRoute>.unmodifiable(purposes),
      overrides: List<PokrovRouteOverride>.unmodifiable(overrides),
      dnsPreset: normalizedDnsPreset,
      dnsTransport: dnsTransport,
      customDnsUrl: customDns,
      externalSmartDnsEnabled: externalSmartDnsEnabled,
      selectedCatalogServiceIds: _readCatalogServiceSelection(json['selectedCatalogServiceIds']),
      allowLan: json['lanScopeEnabled'] == true && lanSubnets.isNotEmpty,
      lanSubnets: lanSubnets,
      trustedWifiNames: List<String>.unmodifiable(trustedWifi),
      pauseOnTrustedWifi:
          json['pauseOnTrustedWifi'] == true && trustedWifi.isNotEmpty,
      windowsConnectionMode: windowsConnectionMode,
      tunStack: tunStack,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'purposeRoutes': purposeRoutes.map((item) => item.name).toList(),
        'overrides': overrides.take(40).map((item) => item.toJson()).toList(),
        'dnsPreset': dnsPreset.name,
        'dnsTransport': dnsTransport.name,
        'customDnsUrl': customDnsUrl,
        'externalSmartDnsEnabled': externalSmartDnsEnabled,
        'selectedCatalogServiceIds': selectedCatalogServiceIds.toList()..sort(),
        // Older clients interpret allowLan as a blanket private-IP bypass.
        // Do not grant that broader permission when they read this file.
        'allowLan': false,
        'lanScopeEnabled': allowLan,
        'lanSubnets': lanSubnets,
        'trustedWifiNames': trustedWifiNames.take(20).toList(),
        'pauseOnTrustedWifi': pauseOnTrustedWifi,
        'windowsConnectionMode': windowsConnectionMode.name,
        'tunStack': tunStack.name,
      };

  String? get effectiveDnsAddress => switch (dnsPreset) {
        PokrovDnsPreset.custom => _normalizeDnsUrl(customDnsUrl),
        _ => dnsPreset.address,
      };

  bool get canEnableExternalSmartDns =>
      dnsPreset == PokrovDnsPreset.custom &&
      _isExternalSmartDnsUrl(effectiveDnsAddress) &&
      dnsTransport == PokrovDnsTransport.direct &&
      purposeRoutes.any((purpose) => purpose.supportsExternalSmartDns);

  bool routesPurposeThroughExternalSmartDns(PokrovPurposeRoute purpose) =>
      externalSmartDnsEnabled &&
      canEnableExternalSmartDns &&
      purpose.supportsExternalSmartDns;
}

class PokrovRouteDecision {
  const PokrovRouteDecision({
    required this.action,
    required this.reason,
    required this.matchedValue,
  });

  /// Null means a safety block: no Direct or VPN route is selected.
  final PokrovRouteAction? action;
  final String reason;
  final String matchedValue;
}

Set<String> _readCatalogServiceSelection(Object? value) {
  if (value == null) return const {};
  if (value is! List || value.length > 256 || value.any((id) =>
      id is! String || !RegExp(r'^[a-z0-9][a-z0-9._-]{0,63}$').hasMatch(id))) {
    // A corrupt protected selection must not be silently truncated. Selective
    // compilation rejects the empty result until the user selects again.
    return const {};
  }
  return Set<String>.unmodifiable(value.cast<String>());
}

/// Only explicitly entered RFC1918 / IPv6 ULA networks are LAN exceptions.
/// Link-local IPv6 requires interface scope and is not admitted by this field.
String? normalizePokrovLanSubnet(String raw) {
  final value = raw.trim();
  if (value.length > 64 || value.contains(RegExp(r'\s|%'))) return null;
  final parts = value.split('/');
  if (parts.length != 2 || !RegExp(r'^[0-9]{1,3}$').hasMatch(parts.last)) return null;
  final address = InternetAddress.tryParse(parts.first);
  final prefix = int.tryParse(parts.last);
  if (address == null || prefix == null) return null;
  final bytes = address.rawAddress;
  final v4 = address.type == InternetAddressType.IPv4;
  final minimumPrefix = v4
      ? (bytes[0] == 10 ? 8
          : bytes[0] == 172 && bytes[1] >= 16 && bytes[1] <= 31 ? 12
          : bytes[0] == 192 && bytes[1] == 168 ? 16 : 33)
      : ((bytes[0] & 0xfe) == 0xfc ? 7 : 129);
  if (prefix < minimumPrefix || prefix > (v4 ? 32 : 128)) return null;
  for (var index = 0; index < bytes.length; index++) {
    final bits = (prefix - index * 8).clamp(0, 8).toInt();
    bytes[index] &= bits == 0 ? 0 : (0xff << (8 - bits)) & 0xff;
  }
  return '${InternetAddress.fromRawAddress(bytes).address}/$prefix';
}

List<String> _readLanSubnets(Object? value) {
  if (value is! List || value.length > 16) return const [];
  final subnets = <String>{};
  for (final item in value) {
    final subnet = item is String ? normalizePokrovLanSubnet(item) : null;
    if (subnet == null) return const [];
    subnets.add(subnet);
  }
  return List.unmodifiable(subnets.toList()..sort());
}

List<String> _enabledLanSubnets(PokrovRoutingPreferences preferences) {
  if (!preferences.allowLan) return const [];
  final subnets = _readLanSubnets(preferences.lanSubnets);
  if (subnets.isEmpty) throw const FormatException('LAN requires explicit local subnets');
  return subnets;
}

bool _isLocalDestination(String value) {
  var address = InternetAddress.tryParse(value);
  if (address == null) return false;
  final bytes = address.rawAddress;
  if (bytes.length == 16 && bytes.take(10).every((byte) => byte == 0) &&
      bytes[10] == 0xff && bytes[11] == 0xff) {
    address = InternetAddress.fromRawAddress(bytes.sublist(12));
  }
  // Matches the private/loopback/multicast/link-local/unspecified classes of
  // the pinned Core's network.IsPublicAddr, not every reserved Internet range.
  return const ['10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16',
    '127.0.0.0/8', '169.254.0.0/16', '224.0.0.0/4', '0.0.0.0/32',
    'fc00::/7', 'fe80::/10', 'ff00::/8', '::1/128', '::/128']
      .any((subnet) => _ipInSubnet(address!.address, subnet));
}

PokrovRouteDecision explainPokrovRouteDecision({
  required String destination,
  required PokrovRoutingPreferences preferences,
  required RouteMode fallbackMode,
}) {
  final normalized = _normalizeRouteMatch(destination);
  if (normalized != null) {
    if (normalized.$2 == PokrovRouteMatchType.ip && _isLocalDestination(normalized.$1)) {
      final allowed = _enabledLanSubnets(preferences)
          .where((subnet) => _ipInSubnet(normalized.$1, subnet)).firstOrNull;
      return PokrovRouteDecision(
        action: allowed == null ? null : PokrovRouteAction.direct,
        reason: allowed == null
            ? 'Локальный адрес не входит в разрешённые подсети LAN. Перехваченный трафик блокируется.'
            : 'Разрешённая подсеть LAN идёт напрямую; VPN для этого адреса не используется.',
        matchedValue: allowed ?? normalized.$1,
      );
    }
    for (final rule in preferences.overrides) {
      if (_routeOverrideMatches(rule, normalized.$1, normalized.$2)) {
        return PokrovRouteDecision(
          action: rule.action,
          reason: rule.action == PokrovRouteAction.vpn
              ? 'Ваше правило отправляет адрес через POKROV VPN.'
              : 'Ваше правило оставляет адрес напрямую.',
          matchedValue: rule.value,
        );
      }
    }
    if (normalized.$2 == PokrovRouteMatchType.domain) {
      for (final purpose in preferences.purposeRoutes) {
        if (_purposeDomains[purpose]!.any(
          (suffix) => _domainMatches(normalized.$1, suffix),
        )) {
          final direct = purpose == PokrovPurposeRoute.ruDirect ||
              preferences.routesPurposeThroughExternalSmartDns(purpose);
          return PokrovRouteDecision(
            action: direct ? PokrovRouteAction.direct : PokrovRouteAction.vpn,
            reason: preferences.routesPurposeThroughExternalSmartDns(purpose)
                ? 'Лабораторный Smart DNS оставляет профиль «${purpose.title}» напрямую; внешний IP не скрывается.'
                : 'Сработал профиль «${purpose.title}».',
            matchedValue: purpose.name,
          );
        }
      }
    }
  }
  return switch (fallbackMode) {
    RouteMode.selectiveServices => const PokrovRouteDecision(
        action: PokrovRouteAction.direct,
        reason: 'Базовый маршрут — напрямую. Правила выбранных сервисов нужно смотреть в каталоге; этот пример их не рассчитывает.',
        matchedValue: 'selectiveServices',
      ),
    RouteMode.fullTunnel => const PokrovRouteDecision(
        action: PokrovRouteAction.vpn,
        reason: 'Базовый режим отправляет всё устройство через POKROV VPN.',
        matchedValue: 'fullTunnel',
      ),
    RouteMode.allExceptRu => const PokrovRouteDecision(
        action: PokrovRouteAction.vpn,
        reason: 'Специальное правило не найдено; действует умный режим.',
        matchedValue: 'allExceptRu',
      ),
    RouteMode.selectedApps => const PokrovRouteDecision(
        action: PokrovRouteAction.vpn,
        reason: 'Решение зависит от выбранного приложения.',
        matchedValue: 'selectedApps',
      ),
    RouteMode.excludedApps => const PokrovRouteDecision(
        action: PokrovRouteAction.vpn,
        reason: 'Прямое подключение задаётся списком исключений.',
        matchedValue: 'excludedApps',
      ),
  };
}

ManagedProfilePayload applyPokrovRoutingPreferences(
  ManagedProfilePayload payload,
  PokrovRoutingPreferences preferences, {
  required HostPlatform hostPlatform,
  CatalogDomainPolicy? catalogPolicy,
  String? catalogAccessState,
  int nativeCatalogWindowVersion = 0,
  int nativeSmartAccessLeaseVersion = 0,
}) {
  if (catalogPolicy != null) {
    return _applyCatalogRoutingPreferences(payload, preferences,
      hostPlatform: hostPlatform, policy: catalogPolicy,
      catalogAccessState: catalogAccessState,
      nativeWindowVersion: nativeCatalogWindowVersion,
      nativeSmartAccessLeaseVersion: nativeSmartAccessLeaseVersion);
  }
  if (payload.routeMode == RouteMode.selectiveServices) {
    throw const RoutingCatalogFailure('catalog_selective_policy_required');
  }
  Map<String, dynamic> config;
  try {
    final decoded = jsonDecode(payload.configPayload);
    if (decoded is! Map) {
      return payload;
    }
    config = decoded.map((key, value) => MapEntry(key.toString(), value));
  } on Object {
    return payload;
  }

  final outbounds = _routingListOfMaps(config['outbounds']);
  final endpoints = _routingListOfMaps(config['endpoints']);
  final route = _routingMap(config['route']);
  final directTag = _findOutboundByType(outbounds, 'direct');
  final proxyTag = _resolveProxyTag(outbounds, endpoints, route);
  if (directTag.isEmpty) {
    throw const FormatException('Managed profile has no direct outbound');
  }
  if (proxyTag.isEmpty) {
    throw const FormatException('Managed profile has no VPN route target');
  }
  if (preferences.externalSmartDnsEnabled &&
      !preferences.canEnableExternalSmartDns) {
    throw const FormatException(
      'External Smart DNS prerequisites are invalid',
    );
  }

  final rules = _routingListOfMaps(route['rules']);
  final lanSubnets = _enabledLanSubnets(preferences);
  rules.removeWhere(
    (rule) =>
        rule['ip_is_private'] == true &&
        _routingText(rule['outbound']) == directTag,
  );
  final protectedRules = <Map<String, dynamic>>[];
  if (hostPlatform == HostPlatform.windows) {
    rules.removeWhere((rule) {
      final action = _routingText(rule['action']).toLowerCase();
      final isDnsRule = rule['port'] == 53 ||
          _routingText(rule['protocol']).toLowerCase() == 'dns' ||
          action == 'hijack-dns';
      return isDnsRule || action == 'sniff';
    });
    protectedRules.addAll(const <Map<String, dynamic>>[
      <String, dynamic>{'port': 53, 'action': 'hijack-dns'},
      <String, dynamic>{'action': 'sniff'},
    ]);
  }
  final injected = <Map<String, dynamic>>[];
  final safetyTags = outbounds.where((outbound) =>
      outbound['type'] == 'block' || outbound['type'] == 'dns')
      .map((outbound) => outbound['tag']).toSet();
  rules.removeWhere((rule) {
    final action = _routingText(rule['action']);
    if (action == 'reject' || action == 'sniff' || action == 'hijack-dns' ||
        safetyTags.contains(rule['outbound'])) {
      protectedRules.add(rule);
      return true;
    }
    return false;
  });
  injected.addAll([
    if (lanSubnets.isNotEmpty) {'ip_cidr': lanSubnets, 'outbound': directTag},
    {'ip_is_private': true, 'action': 'reject'},
  ]);
  for (final override in preferences.overrides) {
    final target =
        override.action == PokrovRouteAction.direct ? directTag : proxyTag;
    final rule = <String, dynamic>{'outbound': target};
    switch (override.matchType) {
      case PokrovRouteMatchType.domain:
        rule['domain_suffix'] = <String>[override.value];
      case PokrovRouteMatchType.ip:
      case PokrovRouteMatchType.subnet:
        rule['ip_cidr'] = <String>[override.value];
    }
    _appendUniqueRule(injected, rule);
  }
  for (final purpose in PokrovPurposeRoute.values) {
    if (!preferences.purposeRoutes.contains(purpose)) {
      continue;
    }
    _appendUniqueRule(injected, <String, dynamic>{
      'domain_suffix': _purposeDomains[purpose],
      'outbound': purpose == PokrovPurposeRoute.ruDirect ||
              preferences.routesPurposeThroughExternalSmartDns(purpose)
          ? directTag
          : proxyTag,
    });
  }
  rules.insertAll(0, protectedRules);
  rules.insertAll(
    protectedRules.length,
    injected.where(
      (rule) => !rules.any((existing) => _sameRoutingRule(existing, rule)),
    ),
  );
  route['rules'] = rules;
  config['route'] = route;

  final existingDns = _routingMap(config['dns']);
  existingDns['rules'] = [
    for (final rule in _routingListOfMaps(existingDns['rules']))
      if (rule['ip_is_private'] == true && _routingText(rule['server']) == 'dns-direct') ...[
        if (lanSubnets.isNotEmpty) {'ip_cidr': lanSubnets, 'server': 'dns-direct'},
      ] else rule,
  ];
  config['dns'] = existingDns;

  if (hostPlatform == HostPlatform.windows) {
    final inbounds = _routingListOfMaps(config['inbounds']);
    final mixedInbound = inbounds
        .where((inbound) => _routingText(inbound['type']) == 'mixed')
        .firstOrNull;
    mixedInbound?.remove('set_system_proxy');
    for (final inbound in inbounds) {
      if (_routingText(inbound['type']) == 'tun') {
        inbound['stack'] = preferences.tunStack.name;
      }
    }
    config['inbounds'] = inbounds;
  }

  final dnsAddress = preferences.effectiveDnsAddress;
  if (dnsAddress != null) {
    final dns = _routingMap(config['dns']);
    final servers = _routingListOfMaps(dns['servers'])
      ..removeWhere(
          (server) => _routingText(server['tag']) == 'pokrov-user-dns');
    servers.insert(0, <String, dynamic>{
      'tag': 'pokrov-user-dns',
      'address': dnsAddress,
      'detour': preferences.dnsTransport == PokrovDnsTransport.direct
          ? directTag
          : proxyTag,
    });
    dns['servers'] = servers;
    if (preferences.externalSmartDnsEnabled) {
      final selectedDomains = <String>{
        for (final purpose in preferences.purposeRoutes)
          if (purpose.supportsExternalSmartDns) ..._purposeDomains[purpose]!,
      }.toList()
        ..sort();
      final dnsRules = _routingListOfMaps(dns['rules'])
        ..removeWhere(
          (rule) => _routingText(rule['server']) == 'pokrov-user-dns',
        );
      dnsRules.insert(0, <String, dynamic>{
        'domain_suffix': selectedDomains,
        'action': 'route',
        'server': 'pokrov-user-dns',
      });
      dns['rules'] = dnsRules;
    } else {
      dns['final'] = 'pokrov-user-dns';
    }
    dns['independent_cache'] = true;
    config['dns'] = dns;
  }

  return payload.copyWith(configPayload: jsonEncode(config), lanScopeVersion: 1);
}

ManagedProfilePayload _applyCatalogRoutingPreferences(
  ManagedProfilePayload payload,
  PokrovRoutingPreferences preferences, {
  required HostPlatform hostPlatform,
  required CatalogDomainPolicy policy,
  String? catalogAccessState,
  required int nativeWindowVersion,
  required int nativeSmartAccessLeaseVersion,
}) {
  final expectedMode = switch (payload.routeMode) {
    RouteMode.selectiveServices => CatalogRoutingMode.selective,
    RouteMode.fullTunnel => CatalogRoutingMode.full,
    RouteMode.allExceptRu => CatalogRoutingMode.smartSafe,
    RouteMode.selectedApps => CatalogRoutingMode.includeApps,
    RouteMode.excludedApps => CatalogRoutingMode.excludeApps,
  };
  if (!payload.materializedForRuntime || policy.mode != expectedMode ||
       policy.platform != hostPlatform.name ||
       policy.accessState != (catalogAccessState ?? payload.freeProfileAccess?.accessState) ||
       (catalogAccessState != null && payload.freeProfileAccess != null &&
         payload.freeProfileAccess!.accessState != catalogAccessState) ||
      policy.defaultAction != (expectedMode == CatalogRoutingMode.selective
          ? CatalogRouteAction.direct : CatalogRouteAction.vpn)) {
    throw const RoutingCatalogFailure('catalog_profile_binding_invalid');
  }
  final selective = expectedMode == CatalogRoutingMode.selective;
  if (policy.smartAccessProfile != null && !policy.smartAccessProfile!.matchesProfile(payload.configPayload)) {
    throw const RoutingCatalogFailure('smart_access_profile_changed');
  }
  final lanSubnets = _enabledLanSubnets(preferences);
  if (selective && (policy.selectedServiceIds.isEmpty ||
      policy.selectedServiceIds.length != preferences.selectedCatalogServiceIds.length ||
      !policy.selectedServiceIds.containsAll(preferences.selectedCatalogServiceIds))) {
    throw const RoutingCatalogFailure('catalog_service_selection_changed');
  }
  if (hostPlatform != HostPlatform.android && hostPlatform != HostPlatform.windows) {
    throw const RoutingCatalogFailure('catalog_host_unsupported');
  }
  if (hostPlatform == HostPlatform.windows &&
      (payload.routeMode == RouteMode.selectedApps || payload.routeMode == RouteMode.excludedApps)) {
    // Shared Windows DNS processes do not prove the requesting application's
    // scope. Do not silently broaden a per-app choice to device-wide policy.
    throw const RoutingCatalogFailure('catalog_process_dns_scope_unsupported');
  }
  if (preferences.externalSmartDnsEnabled) {
    throw const RoutingCatalogFailure('catalog_gateway_lease_missing');
  }
  final decoded = jsonDecode(payload.configPayload);
  if (decoded is! Map) throw const RoutingCatalogFailure('catalog_profile_invalid');
  final config = _routingMap(decoded);
  final outbounds = _routingListOfMaps(config['outbounds']);
  final endpoints = _routingListOfMaps(config['endpoints']);
  if (outbounds.any((value) => value['type'] == 'pokrov-smart-access')) {
    throw const RoutingCatalogFailure('smart_access_profile_already_leased');
  }
  final route = _routingMap(config['route']);
  final dns = _routingMap(config['dns']);
  final direct = _findOutboundByType(outbounds, 'direct');
  final vpn = _resolveProxyTag(outbounds, endpoints, route);
  if (direct.isEmpty || vpn.isEmpty || direct == vpn ||
      (selective && vpn != _routingText(route['final']))) {
    throw const RoutingCatalogFailure('catalog_native_targets_invalid');
  }
  final inbounds = _routingListOfMaps(config['inbounds']);
  final tun = inbounds.where((value) => value['type'] == 'tun').firstOrNull;
  if (tun == null) throw const RoutingCatalogFailure('catalog_tun_scope_missing');
  if (hostPlatform == HostPlatform.android) {
    final include = tun['include_package'];
    final exclude = tun['exclude_package'];
    if (selective && include is List && include.isNotEmpty) {
      throw const RoutingCatalogFailure('catalog_tun_scope_missing');
    }
    if ((payload.routeMode == RouteMode.selectedApps &&
            (include is! List || include.isEmpty || (exclude is List && exclude.isNotEmpty))) ||
        (payload.routeMode == RouteMode.excludedApps &&
            (exclude is! List || exclude.isEmpty || (include is List && include.isNotEmpty)))) {
      throw const RoutingCatalogFailure('catalog_tun_scope_missing');
    }
  } else {
    tun['stack'] = preferences.tunStack.name;
    for (final inbound in inbounds) {
      if (inbound['type'] == 'mixed') inbound.remove('set_system_proxy');
    }
  }
  config['inbounds'] = inbounds;

  final servers = _routingListOfMaps(dns['servers']);
  var vpnDns = 'dns-remote';
  var directDns = 'dns-direct';
  final dnsAddress = preferences.effectiveDnsAddress;
  if (dnsAddress != null) {
    vpnDns = 'pokrov-catalog-user-dns-vpn';
    directDns = 'pokrov-catalog-user-dns-direct';
    servers.removeWhere((server) => server['tag'] == vpnDns || server['tag'] == directDns);
    servers.addAll([
      {'tag': vpnDns, 'address': dnsAddress, 'address_resolver': 'dns-local', 'detour': vpn},
      {'tag': directDns, 'address': dnsAddress, 'address_resolver': 'dns-local', 'detour': direct},
    ]);
  }
  for (final (tag, target) in [(vpnDns, vpn), (directDns, direct)]) {
    final resolver = servers.where((server) => server['tag'] == tag).firstOrNull;
    if (resolver == null || resolver['detour'] != target) {
      throw const RoutingCatalogFailure('catalog_dns_lane_invalid');
    }
  }
  final layer = materializeCatalogRuleLayer(policy: policy,
    nativeWindowVersion: nativeWindowVersion, vpnOutbound: vpn, directOutbound: direct,
    vpnDnsServer: vpnDns, directDnsServer: directDns, now: DateTime.now(),
    nativeSmartAccessLeaseVersion: nativeSmartAccessLeaseVersion);
  final existingOutboundTags = [...outbounds, ...endpoints].map((value) => value['tag']).toSet();
  final existingDnsTags = servers.map((value) => value['tag']).toSet();
  if (layer.outbounds.any((value) => existingOutboundTags.contains(value['tag'])) ||
      layer.dnsServers.any((value) => existingDnsTags.contains(value['tag']))) {
    throw const RoutingCatalogFailure('smart_access_native_tag_collision');
  }
  outbounds.addAll(layer.outbounds.map((value) => Map<String, dynamic>.from(value)));
  servers.addAll(layer.dnsServers.map((value) => Map<String, dynamic>.from(value)));
  config['outbounds'] = outbounds;
  final blockTags = outbounds.where((value) => value['type'] == 'block')
      .map((value) => value['tag']).toSet();
  final safety = <Map<String, dynamic>>[];
  final remaining = <Map<String, dynamic>>[];
  for (final rule in _routingListOfMaps(route['rules'])) {
    final action = _routingText(rule['action']);
    if (action == 'reject' || blockTags.contains(rule['outbound']) ||
        action == 'sniff' || action == 'hijack-dns') {
      safety.add(rule);
    } else if (_routingText(rule['outbound']) != direct &&
        (!selective || _routingText(rule['outbound']).isEmpty)) {
      remaining.add(rule);
    }
  }
  // All implicit Direct classifications (including legacy RU lists) are
  // replaced by this catalog. Explicit local choices are rebuilt below.
  final manual = <Map<String, dynamic>>[];
  final manualDns = <Map<String, dynamic>>[];
  for (final override in preferences.overrides) {
    final isDirect = override.action == PokrovRouteAction.direct;
    final match = override.matchType == PokrovRouteMatchType.domain ? 'domain_suffix' : 'ip_cidr';
    manual.add({match: [override.value], 'outbound': isDirect ? direct : vpn});
    if (override.matchType == PokrovRouteMatchType.domain) {
      manualDns.add({match: [override.value], 'server': isDirect ? directDns : vpnDns});
    }
  }
  for (final purpose in PokrovPurposeRoute.values) {
    if (!preferences.purposeRoutes.contains(purpose)) continue;
    final isDirect = purpose == PokrovPurposeRoute.ruDirect;
    manual.add({'domain_suffix': _purposeDomains[purpose], 'outbound': isDirect ? direct : vpn});
    manualDns.add({'domain_suffix': _purposeDomains[purpose], 'server': isDirect ? directDns : vpnDns});
  }
  // Native health must exercise this exact protected target even when the
  // remainder defaults to Direct. Keep the owned HTTPS probe before user and
  // catalog classifications, without changing the rest of the device scope.
  final probeRoute = <String, dynamic>{
    'domain': ['api.pokrov.space'], 'network': 'tcp', 'port': [443],
    'action': 'route', 'outbound': vpn,
  };
  route['rules'] = [
    ...safety, if (selective) probeRoute,
    if (lanSubnets.isNotEmpty) {'ip_cidr': lanSubnets, 'outbound': direct},
    {'ip_is_private': true, 'action': 'reject'},
    ...manual, ...layer.routeRules, ...remaining,
  ];
  route['final'] = selective ? direct : vpn;
  config['route'] = route;

  final blockedDns = servers.where((server) =>
      _routingText(server['address']).startsWith('rcode://')).map((server) => server['tag']).toSet();
  final dnsSafety = _routingListOfMaps(dns['rules']).where((rule) =>
      (_routingText(rule['server']).isEmpty && _routingText(rule['action']) != 'route') ||
      blockedDns.contains(rule['server'])).toList();
  final bootstrapDomains = <String>{
    for (final outbound in [...outbounds, ...endpoints])
      if (_routingText(outbound['server']).isNotEmpty &&
          InternetAddress.tryParse(_routingText(outbound['server'])) == null)
        _routingText(outbound['server']),
  }.toList()..sort();
  if (selective && bootstrapDomains.any((domain) =>
      domain.toLowerCase().replaceFirst(RegExp(r'\.$'), '') == 'api.pokrov.space')) {
    // A tunnel cannot depend on its own protected proof hostname to bootstrap.
    throw const RoutingCatalogFailure('catalog_probe_bootstrap_conflict');
  }
  dns['servers'] = servers;
  dns['rules'] = [
    ...dnsSafety,
    if (bootstrapDomains.isNotEmpty) {'domain': bootstrapDomains, 'server': directDns},
    if (selective) {
      'domain': ['api.pokrov.space'], 'action': 'route', 'server': vpnDns,
      'disable_cache': true, 'rewrite_ttl': 0,
    },
    if (lanSubnets.isNotEmpty) {'ip_cidr': lanSubnets, 'server': directDns},
    ...manualDns,
    ...layer.dnsRules,
  ];
  dns['final'] = selective || (dnsAddress != null && preferences.dnsTransport == PokrovDnsTransport.direct)
      ? directDns : vpnDns;
  dns['independent_cache'] = true;
  dns['disable_expire'] = false;
  config['dns'] = dns;
  // Removed automatic classifications must not leave unused remote rule sets
  // that Core would still load. Keep every set referenced by retained rules.
  final referencedSets = <String>{};
  void collectSets(Object? rules) {
    for (final rule in _routingListOfMaps(rules)) {
      final sets = rule['rule_set'];
      if (sets is String) referencedSets.add(sets);
      if (sets is List) referencedSets.addAll(sets.whereType<String>());
      collectSets(rule['rules']);
    }
  }
  collectSets(route['rules']);
  collectSets(dns['rules']);
  if (route['rule_set'] is List) {
    route['rule_set'] = _routingListOfMaps(route['rule_set'])
        .where((definition) => referencedSets.contains(definition['tag'])).toList();
  }
  return payload.copyWith(configPayload: jsonEncode(config), lanScopeVersion: 1);
}

const Map<PokrovPurposeRoute, List<String>> _purposeDomains = {
  PokrovPurposeRoute.video: <String>[
    'youtube.com',
    'youtu.be',
    'googlevideo.com',
    'netflix.com',
    'vimeo.com',
  ],
  PokrovPurposeRoute.ai: <String>[
    'openai.com',
    'chatgpt.com',
    'oaistatic.com',
    'oaiusercontent.com',
    'gemini.google.com',
    'aistudio.google.com',
    'ai.google.dev',
    'generativelanguage.googleapis.com',
    'anthropic.com',
    'claude.ai',
    'perplexity.ai',
  ],
  PokrovPurposeRoute.social: <String>[
    'instagram.com',
    'facebook.com',
    'x.com',
    'twitter.com',
    'discord.com',
  ],
  PokrovPurposeRoute.games: <String>[
    'steampowered.com',
    'steamcommunity.com',
    'epicgames.com',
    'playstation.com',
    'xbox.com',
    'xboxlive.com',
    'xboxservices.com',
    'gamepass.com',
  ],
  PokrovPurposeRoute.ruDirect: <String>[
    'ru',
    'xn--p1ai',
    'su',
    'gosuslugi.ru',
    'sberbank.ru',
    'tinkoff.ru',
    'ozon.ru',
    'wildberries.ru',
  ],
};

List<String> pokrovPurposeDomains(PokrovPurposeRoute purpose) =>
    List<String>.unmodifiable(_purposeDomains[purpose]!);

(String, PokrovRouteMatchType)? _normalizeRouteMatch(String raw) {
  var value = raw.trim().toLowerCase();
  if (value.isEmpty || value.length > 253 || value.contains(RegExp(r'\s'))) {
    return null;
  }
  if (value.contains('/')) {
    final parts = value.split('/');
    if (parts.length == 2) {
      final address = InternetAddress.tryParse(parts.first);
      final prefix = int.tryParse(parts.last);
      final maxPrefix = address?.type == InternetAddressType.IPv4 ? 32 : 128;
      if (address != null &&
          prefix != null &&
          prefix >= 0 &&
          prefix <= maxPrefix) {
        return ('${address.address}/$prefix', PokrovRouteMatchType.subnet);
      }
    }
    return null;
  }
  final address = InternetAddress.tryParse(value);
  if (address != null) {
    return (address.address, PokrovRouteMatchType.ip);
  }
  if (value.startsWith('*.')) {
    value = value.substring(2);
  }
  if (value.endsWith('.')) {
    value = value.substring(0, value.length - 1);
  }
  final domainPattern = RegExp(
    r'^(?=.{1,253}$)(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$',
  );
  return domainPattern.hasMatch(value)
      ? (value, PokrovRouteMatchType.domain)
      : null;
}

String? _normalizeDnsUrl(String raw) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null ||
      uri.scheme.toLowerCase() != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.toString().length > 240) {
    return null;
  }
  return uri.toString();
}

bool _isExternalSmartDnsUrl(String? raw) {
  if (raw == null) return false;
  final normalized = _normalizeDnsUrl(raw);
  if (normalized == null) return false;
  final uri = Uri.parse(normalized);
  return uri.path == '/dns-query' &&
      uri.query.isEmpty &&
      uri.fragment.isEmpty &&
      (!uri.hasPort || uri.port == 443);
}

bool _routeOverrideMatches(
  PokrovRouteOverride rule,
  String destination,
  PokrovRouteMatchType destinationType,
) {
  if (rule.matchType == PokrovRouteMatchType.domain &&
      destinationType == PokrovRouteMatchType.domain) {
    return _domainMatches(destination, rule.value);
  }
  if (rule.matchType == PokrovRouteMatchType.ip &&
      destinationType == PokrovRouteMatchType.ip) {
    return destination == rule.value;
  }
  if (rule.matchType == PokrovRouteMatchType.subnet &&
      destinationType == PokrovRouteMatchType.ip) {
    return _ipInSubnet(destination, rule.value);
  }
  return destination == rule.value;
}

bool _domainMatches(String domain, String suffix) {
  return domain == suffix || domain.endsWith('.$suffix');
}

bool _ipInSubnet(String ipText, String subnetText) {
  final parts = subnetText.split('/');
  if (parts.length != 2) return false;
  final ip = InternetAddress.tryParse(ipText);
  final network = InternetAddress.tryParse(parts.first);
  final prefix = int.tryParse(parts.last);
  if (ip == null ||
      network == null ||
      prefix == null ||
      ip.type != network.type) {
    return false;
  }
  final fullBytes = prefix ~/ 8;
  final remainingBits = prefix.remainder(8);
  for (var index = 0; index < fullBytes; index += 1) {
    if (ip.rawAddress[index] != network.rawAddress[index]) return false;
  }
  if (remainingBits == 0) return true;
  final mask = (0xff << (8 - remainingBits)) & 0xff;
  return (ip.rawAddress[fullBytes] & mask) ==
      (network.rawAddress[fullBytes] & mask);
}

String _resolveProxyTag(
  List<Map<String, dynamic>> outbounds,
  List<Map<String, dynamic>> endpoints,
  Map<String, dynamic> route,
) {
  final finalTag = _routingText(route['final']);
  final finalOutbound = outbounds
      .where((item) => _routingText(item['tag']) == finalTag)
      .firstOrNull;
  if (finalOutbound != null &&
      !_nonProxyTypes
          .contains(_routingText(finalOutbound['type']).toLowerCase())) {
    return finalTag;
  }
  final finalEndpoint = endpoints
      .where((item) => _routingText(item['tag']) == finalTag)
      .firstOrNull;
  if (finalEndpoint != null && _routingText(finalEndpoint['type']).isNotEmpty) {
    return finalTag;
  }
  for (final preferredType in const <String>['selector', 'urltest']) {
    final tag = _findOutboundByType(outbounds, preferredType);
    if (tag.isNotEmpty) return tag;
  }
  for (final outbound in outbounds) {
    final type = _routingText(outbound['type']).toLowerCase();
    final tag = _routingText(outbound['tag']);
    if (tag.isNotEmpty && !_nonProxyTypes.contains(type)) return tag;
  }
  // Selected Windows processes can use an AWG endpoint while unselected
  // traffic has a direct final. Follow the existing route, not an unused peer.
  final endpointTags = endpoints
      .where((endpoint) => _routingText(endpoint['type']).isNotEmpty)
      .map((endpoint) => _routingText(endpoint['tag']))
      .where((tag) => tag.isNotEmpty)
      .toSet();
  for (final rule in _routingListOfMaps(route['rules'])) {
    final tag = _routingText(rule['outbound']);
    if (endpointTags.contains(tag)) return tag;
  }
  return '';
}

const Set<String> _nonProxyTypes = <String>{'direct', 'block', 'dns'};

String _findOutboundByType(
  List<Map<String, dynamic>> outbounds,
  String type,
) {
  return _routingText(
    outbounds
        .where(
          (item) => _routingText(item['type']).toLowerCase() == type,
        )
        .firstOrNull?['tag'],
  );
}

void _appendUniqueRule(
  List<Map<String, dynamic>> rules,
  Map<String, dynamic> rule,
) {
  if (!rules.any((existing) => _sameRoutingRule(existing, rule))) {
    rules.add(rule);
  }
}

bool _sameRoutingRule(Map<String, dynamic> left, Map<String, dynamic> right) {
  return jsonEncode(left) == jsonEncode(right);
}

String _routingText(Object? value) =>
    value == null ? '' : value.toString().trim();

List<Object?> _routingList(Object? value) =>
    value is List ? value.cast<Object?>() : const <Object?>[];

Map<String, dynamic> _routingMap(Object? value) {
  if (value is! Map) return <String, dynamic>{};
  return value.map((key, item) => MapEntry(key.toString(), item));
}

List<Map<String, dynamic>> _routingListOfMaps(Object? value) {
  if (value is! List) return <Map<String, dynamic>>[];
  return value
      .whereType<Map>()
      .map((item) => item.map((key, value) => MapEntry(key.toString(), value)))
      .toList(growable: true);
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
