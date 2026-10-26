part of pokrov_app_shell;

String _locationCountryDisplayName(String code, String fallback) {
  const names = <String, String>{
    'CH': 'Швейцария',
    'DE': 'Германия',
    'FI': 'Финляндия',
    'FR': 'Франция',
    'GB': 'Великобритания',
    'IT': 'Италия',
    'IS': 'Исландия',
    'NL': 'Нидерланды',
    'PL': 'Польша',
    'RU': 'Россия',
    'US': 'США',
  };
  return names[code.trim().toUpperCase()] ??
      _safeLocationLabel(fallback, fallback: 'Страна');
}

String _locationCityDisplayName(
  ClientLocationCity city,
  ClientLocationCountry country,
) {
  final raw = _safeLocationLabel(city.city, fallback: '');
  if (RegExp('[А-Яа-яЁё]').hasMatch(raw)) {
    return raw;
  }
  if (raw.toUpperCase() == country.code.trim().toUpperCase() ||
      raw.toLowerCase() == 'unknown') {
    return _locationCountryDisplayName(country.code, country.country);
  }
  final parts = city.code
      .trim()
      .toLowerCase()
      .split(RegExp(r'[-_.]+'))
      .where((part) => part.isNotEmpty)
      .toSet();
  const cityNames = <String, String>{
    'ams': 'Амстердам',
    'fra': 'Франкфурт',
    'hel': 'Хельсинки',
    'lon': 'Лондон',
    'mil': 'Милан',
    'msk': 'Москва',
    'nyc': 'Нью-Йорк',
    'par': 'Париж',
    'spb': 'Санкт-Петербург',
    'waw': 'Варшава',
  };
  for (final entry in cityNames.entries) {
    if (parts.contains(entry.key)) {
      return entry.value;
    }
  }
  const rawNames = <String, String>{
    'amsterdam': 'Амстердам',
    'frankfurt': 'Франкфурт',
    'helsinki': 'Хельсинки',
    'london': 'Лондон',
    'milan': 'Милан',
    'moscow': 'Москва',
    'new york': 'Нью-Йорк',
    'paris': 'Париж',
    'saint petersburg': 'Санкт-Петербург',
    'st petersburg': 'Санкт-Петербург',
    'warsaw': 'Варшава',
    'switzerland': 'Швейцария',
  };
  if (rawNames.containsKey(raw.toLowerCase())) {
    return rawNames[raw.toLowerCase()]!;
  }
  if (raw.isNotEmpty) {
    return raw;
  }
  return _locationCountryDisplayName(country.code, country.country);
}

String _locationCountryCodeFromNode(String nodeCode, String country) {
  final parts = nodeCode
      .trim()
      .toUpperCase()
      .split(RegExp(r'[-_.]+'))
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  final base = parts.isEmpty ? '' : parts.first;
  if (RegExp(r'^[A-Z]{2}$').hasMatch(base)) {
    return base;
  }
  const countryCodes = <String, String>{
    'finland': 'FI',
    'france': 'FR',
    'germany': 'DE',
    'italy': 'IT',
    'netherlands': 'NL',
    'poland': 'PL',
    'russia': 'RU',
    'switzerland': 'CH',
    'usa': 'US',
    'united kingdom': 'GB',
    'united states': 'US',
  };
  return countryCodes[country.trim().toLowerCase()] ?? '';
}

String _protectionLiveLocationLabel(RuntimeLiveStats stats) {
  final country = stats.serverCountry.trim();
  return <String>[
    if (country.isNotEmpty && country.toLowerCase() != 'unknown')
      _locationCountryDisplayName(country, country),
  ].join(' · ');
}

String _safeLocationLabel(String value, {required String fallback}) {
  final text = value.trim();
  if (text.isEmpty ||
      RegExp(r'\b(?:\d{1,3}\.){3}\d{1,3}\b').hasMatch(text) ||
      RegExp(r'\b(?:[a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}\b').hasMatch(text) ||
      RegExp(r'(?:[0-9a-fA-F]{0,4}:){2,}[0-9a-fA-F:]{0,4}').hasMatch(text) ||
      text.contains('://')) {
    return fallback;
  }
  return text.replaceAll(
      RegExp(r'белые\s+списки', caseSensitive: false), 'Через мост');
}

String _locationCacheLabel(String rawIso, {DateTime? now}) {
  final cachedAt = DateTime.tryParse(rawIso.trim())?.toUtc();
  if (cachedAt == null) {
    return 'Время сохранения неизвестно.';
  }
  final age = (now ?? DateTime.now()).toUtc().difference(cachedAt);
  if (age.isNegative) {
    return 'Время сохранения неизвестно.';
  }
  if (age < const Duration(minutes: 2)) {
    return 'Сохранено только что.';
  }
  if (age < const Duration(hours: 1)) {
    return 'Сохранено ${age.inMinutes} мин назад.';
  }
  if (age < const Duration(days: 2)) {
    return 'Сохранено ${age.inHours} ч назад.';
  }
  return 'Сохранено ${age.inDays} дн назад.';
}

String _locationCandidateLabel(domain.TransportCandidate candidate) {
  final protocol = switch (candidate.protocol) {
    'vless' => switch (candidate.transport) {
        'dnstt' => 'SlipNet',
        'xhttp' => 'VLESS XHTTP',
        'grpc' => 'VLESS gRPC',
        _ => candidate.protection == 'reality' ? 'VLESS REALITY' : 'VLESS TLS',
      },
    'hysteria2' => 'HY2',
    'awg' => 'AWG 3.1',
    'naive' => 'Naive HTTPS / H2',
    _ => 'Соединение',
  };
  final bridge = candidate.bridgeId;
  final path = bridge == null ? '' : bridge.endsWith('-xhttp') ? ' · Через мост · XHTTP' : ' · Через мост';
  final warp = candidate.warpMode == null ? '' : ' · WARP';
  return '$protocol$path$warp';
}
