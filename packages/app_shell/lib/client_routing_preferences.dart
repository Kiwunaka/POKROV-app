import 'dart:convert';
import 'dart:io';

import 'package:pokrov_core_domain/core_domain.dart';
import 'package:pokrov_runtime_engine/runtime_engine.dart';

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
        PokrovPurposeRoute.games => 'Игры',
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
    required this.allowLan,
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
        allowLan = true,
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
  final bool allowLan;
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
    bool? allowLan,
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
      allowLan: allowLan ?? this.allowLan,
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
        dnsTransport == PokrovDnsTransport.direct &&
        purposes.any((purpose) => purpose.supportsExternalSmartDns);
    return PokrovRoutingPreferences(
      purposeRoutes: Set<PokrovPurposeRoute>.unmodifiable(purposes),
      overrides: List<PokrovRouteOverride>.unmodifiable(overrides),
      dnsPreset: normalizedDnsPreset,
      dnsTransport: dnsTransport,
      customDnsUrl: customDns,
      externalSmartDnsEnabled: externalSmartDnsEnabled,
      allowLan: json['allowLan'] != false,
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
        'allowLan': allowLan,
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
      effectiveDnsAddress != null &&
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

  final PokrovRouteAction action;
  final String reason;
  final String matchedValue;
}

PokrovRouteDecision explainPokrovRouteDecision({
  required String destination,
  required PokrovRoutingPreferences preferences,
  required RouteMode fallbackMode,
}) {
  final normalized = _normalizeRouteMatch(destination);
  if (normalized != null) {
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
}) {
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
  if (preferences.allowLan) {
    _appendUniqueRule(injected, <String, dynamic>{
      'ip_is_private': true,
      'outbound': directTag,
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
    dns
      ..['servers'] = servers
      ..['final'] = 'pokrov-user-dns'
      ..['independent_cache'] = true;
    config['dns'] = dns;
  }

  return payload.copyWith(configPayload: jsonEncode(config));
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
