part of pokrov_app_shell;

const _locationBridgeRouteDescription =
    'Через промежуточный узел.';

String _locationCountryDisplayName(String code, String fallback) {
  const names = <String, String>{
    'CH': 'Швейцария',
    'DE': 'Германия',
    'FI': 'Финляндия',
    'FR': 'Франция',
    'GB': 'Великобритания',
    'IT': 'Италия',
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

String _smartConnectNodeTitle(SmartConnectNode node) {
  final country = node.country.trim();
  if (country.isNotEmpty) {
    return _locationCountryDisplayName(
      _locationCountryCodeFromNode(node.code, country),
      country,
    );
  }
  return 'Локация POKROV';
}

String _smartConnectNodeCity(SmartConnectNode node) {
  return node.country.trim().isEmpty ? 'Доступная локация' : 'Доступная страна';
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

String _locationCandidateLabel(domain.TransportCandidate candidate) {
  final protocol = switch (candidate.protocol) {
    'vless' => switch (candidate.transport) {
        'xhttp' => 'VLESS XHTTP',
        'grpc' => 'VLESS gRPC',
        _ => candidate.protection == 'reality' ? 'VLESS REALITY' : 'VLESS TLS',
      },
    'hysteria2' => 'Hysteria 2',
    'awg' => 'AWG 3.1',
    _ => 'Соединение',
  };
  final path = candidate.bridgeId != null ? ' · Через мост' : '';
  final warp = candidate.warpMode == null ? '' : ' · WARP';
  return '$protocol$path$warp';
}

String _locationHealthMeasuredAt(ClientLocationCity city) =>
    // Older device RTT cache entries overwrote the Portal measurement time.
    city.latencySource == 'device' && city.latencyMeasuredAt.isEmpty
        ? ''
        : city.measuredAt;

String _locationNodeStatusLabel(ClientLocationCity city, {DateTime? now}) {
  final health = _normalizeLocationHealthScore(city.healthScore);
  if (_locationMetricFreshness(_locationHealthMeasuredAt(city), now: now) !=
          _LocationMetricFreshness.current ||
      health == null) {
    return 'Нода: нет свежих данных';
  }
  return health > 0 ? 'Нода: онлайн' : 'Нода: недоступна';
}

String _smartConnectQualityLabel(SmartConnectNode node) {
  return _locationQualityLabel(
        node.rankHint.healthScore,
        latencyMs: node.rankHint.panelLatencyMs,
      ) ??
      'Нет свежих данных';
}

double? _normalizeLocationHealthScore(double? rawScore) {
  if (rawScore == null || !rawScore.isFinite || rawScore < 0) {
    return null;
  }
  if (rawScore <= 1) {
    return rawScore;
  }
  if (rawScore <= 100) {
    return rawScore / 100;
  }
  return null;
}

String? _locationQualityLabel(double? rawScore, {int? latencyMs}) {
  final score = _normalizeLocationHealthScore(rawScore);
  if (score == null || latencyMs == null || latencyMs <= 0) {
    return null;
  }
  final healthRank = _locationHealthQualityRank(score);
  final latencyRank = _locationLatencyQualityRank(latencyMs);
  final rank = latencyRank != null && latencyRank > healthRank
      ? latencyRank
      : healthRank;
  return const <String>['Отлично', 'Хорошо', 'Стабильно', 'Медленно'][rank];
}

int _locationHealthQualityRank(double score) {
  if (score >= 0.88) {
    return 0;
  }
  if (score >= 0.68) {
    return 1;
  }
  if (score >= 0.42) {
    return 2;
  }
  return 3;
}

int? _locationLatencyQualityRank(int? latencyMs) {
  if (latencyMs == null || latencyMs <= 0) {
    return null;
  }
  if (latencyMs <= 150) {
    return 0;
  }
  if (latencyMs <= 350) {
    return 1;
  }
  if (latencyMs <= 800) {
    return 2;
  }
  return 3;
}

String _locationLatencyLabel(int? latencyMs) {
  if (latencyMs == null || latencyMs <= 0) {
    return 'ping —';
  }
  return '$latencyMs мс';
}

String _locationLoadLabel(double? rawLoad) {
  if (rawLoad == null || !rawLoad.isFinite || rawLoad < 0) {
    return 'нагрузка —';
  }
  final percent = (rawLoad <= 1 ? rawLoad * 100 : rawLoad).clamp(0, 100);
  final label = percent < 40
      ? 'низкая'
      : percent < 75
          ? 'средняя'
          : 'высокая';
  return 'нагрузка $label';
}

enum _LocationMetricFreshness { current, stale, unknown }

_LocationMetricFreshness _locationMetricFreshness(
  String rawIso, {
  DateTime? now,
}) {
  final measuredAt = DateTime.tryParse(rawIso.trim())?.toUtc();
  if (measuredAt == null) {
    return _LocationMetricFreshness.unknown;
  }
  final clock = (now ?? DateTime.now()).toUtc();
  final age = clock.difference(measuredAt);
  if (age.isNegative) {
    return _LocationMetricFreshness.unknown;
  }
  if (age <= const Duration(minutes: 15)) {
    return _LocationMetricFreshness.current;
  }
  return _LocationMetricFreshness.stale;
}

String _locationFreshnessLabel(String rawIso, {DateTime? now}) {
  final measuredAt = DateTime.tryParse(rawIso.trim())?.toUtc();
  if (measuredAt == null) {
    return 'замер —';
  }
  final clock = (now ?? DateTime.now()).toUtc();
  final age = clock.difference(measuredAt);
  if (age.isNegative) {
    return 'время замера —';
  }
  if (age <= const Duration(minutes: 2)) {
    return 'замер сейчас';
  }
  if (age <= const Duration(minutes: 15)) {
    return 'замер ${age.inMinutes} мин назад';
  }
  return 'замер устарел';
}

String _locationCompactFreshnessLabel(String rawIso, {DateTime? now}) {
  final measuredAt = DateTime.tryParse(rawIso.trim())?.toUtc();
  if (measuredAt == null) {
    return 'нет замера';
  }
  final clock = (now ?? DateTime.now()).toUtc();
  final age = clock.difference(measuredAt);
  if (age.isNegative) {
    return 'нет замера';
  }
  if (age <= const Duration(minutes: 2)) {
    return 'сейчас';
  }
  if (age <= const Duration(minutes: 15)) {
    return '${age.inMinutes} мин';
  }
  return 'устарел';
}

String _locationMetricsLabel(
  ClientLocationCity city, {
  DateTime? now,
  bool compact = false,
}) {
  final healthFreshness =
      _locationMetricFreshness(_locationHealthMeasuredAt(city), now: now);
  final hasHealthMeasurement =
      healthFreshness != _LocationMetricFreshness.unknown;
  final latencyMeasuredAt = city.latencySource == 'device' &&
          city.latencyMeasuredAt.isNotEmpty
      ? city.latencyMeasuredAt
      : city.measuredAt;
  final hasLatencyMeasurement =
      _locationMetricFreshness(latencyMeasuredAt, now: now) !=
          _LocationMetricFreshness.unknown;
  final freshness = compact
      ? _locationCompactFreshnessLabel(latencyMeasuredAt, now: now)
      : _locationFreshnessLabel(latencyMeasuredAt, now: now);
  final freshnessLabel =
      city.latencySource == 'device' ? 'ping $freshness' : freshness;
  final load = _locationLoadLabel(hasHealthMeasurement ? city.load : null);
  final loadLabel = city.latencySource == 'device' &&
          healthFreshness == _LocationMetricFreshness.stale &&
          load != 'нагрузка —'
      ? '$load (устарела)'
      : load;
  if (compact) {
    final latency =
        !hasLatencyMeasurement || city.latencyMs == null || city.latencyMs! <= 0
            ? '— мс'
            : '${city.latencyMs} мс';
    return <String>[
      _locationNodeStatusLabel(city, now: now),
      latency,
      loadLabel,
      freshnessLabel,
    ].join(' · ');
  }
  return <String>[
    _locationLatencyLabel(hasLatencyMeasurement ? city.latencyMs : null),
    loadLabel,
    freshnessLabel,
  ].join(' · ');
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
