library pokrov_core_domain;

enum HostPlatform {
  android,
  ios,
  macos,
  windows,
}

enum ClientPlatform {
  android,
  ios,
  macos,
  windows,
}

enum RuntimeCore {
  singBox,
  xray,
}

enum AccessLane {
  trialPremium,
  bonusPremium,
  paidUnlimited,
  freeMonthly,
  freeSoftMode,
}

enum RouteMode {
  fullTunnel,
  selectedApps,
  allExceptRu,
}

enum TransportKind {
  vlessReality,
  vmess,
  trojan,
  xhttp,
}

enum VariantAvailability {
  live,
  gated,
}

extension HostPlatformPresentation on HostPlatform {
  String get label {
    switch (this) {
      case HostPlatform.android:
        return 'Android';
      case HostPlatform.ios:
        return 'iOS';
      case HostPlatform.macos:
        return 'macOS';
      case HostPlatform.windows:
        return 'Windows';
    }
  }

  bool get supportsSelectedAppsMode {
    switch (this) {
      case HostPlatform.android:
      case HostPlatform.windows:
        return true;
      case HostPlatform.ios:
      case HostPlatform.macos:
        return false;
    }
  }
}

extension ClientPlatformPresentation on ClientPlatform {
  String get label {
    switch (this) {
      case ClientPlatform.android:
        return 'Android';
      case ClientPlatform.ios:
        return 'iOS';
      case ClientPlatform.macos:
        return 'macOS';
      case ClientPlatform.windows:
        return 'Windows';
    }
  }
}

extension RuntimeCorePresentation on RuntimeCore {
  String get label {
    switch (this) {
      case RuntimeCore.singBox:
        return 'sing-box';
      case RuntimeCore.xray:
        return 'xray';
    }
  }
}

extension AccessLanePresentation on AccessLane {
  String get label {
    switch (this) {
      case AccessLane.trialPremium:
        return 'Пробный период';
      case AccessLane.bonusPremium:
        return 'Бонусный доступ';
      case AccessLane.paidUnlimited:
        return 'Премиум';
      case AccessLane.freeMonthly:
        return 'Базовый режим';
      case AccessLane.freeSoftMode:
        return 'Лимит закончился';
    }
  }

  String get summary {
    switch (this) {
      case AccessLane.trialPremium:
        return '5 дней полного доступа без карты на первом устройстве.';
      case AccessLane.bonusPremium:
        return 'Привяжите Telegram, чтобы получить +10 дней к доступу.';
      case AccessLane.paidUnlimited:
        return 'Платный доступ открывает полный пул доступных узлов без месячного лимита трафика.';
      case AccessLane.freeMonthly:
        return 'После полного доступа остается базовый режим: бесплатный узел и возобновляемый лимит.';
      case AccessLane.freeSoftMode:
        return 'Если месячный лимит закончился, приложение покажет продление и поддержку.';
    }
  }
}

extension RouteModePresentation on RouteMode {
  String get label {
    switch (this) {
      case RouteMode.fullTunnel:
        return 'Всё устройство';
      case RouteMode.selectedApps:
        return 'Выбранные приложения';
      case RouteMode.allExceptRu:
        return 'Всё, кроме РФ';
    }
  }

  String get summary {
    switch (this) {
      case RouteMode.fullTunnel:
        return 'Весь трафик этого устройства идет через POKROV.';
      case RouteMode.selectedApps:
        return 'POKROV используют только выбранные приложения. Остальное идет напрямую.';
      case RouteMode.allExceptRu:
        return 'Российские и локальные сервисы идут напрямую, остальное — через POKROV.';
    }
  }
}

extension TransportKindPresentation on TransportKind {
  String get label {
    switch (this) {
      case TransportKind.vlessReality:
        return 'VLESS+REALITY';
      case TransportKind.vmess:
        return 'VMess';
      case TransportKind.trojan:
        return 'Trojan';
      case TransportKind.xhttp:
        return 'XHTTP';
    }
  }
}

extension VariantAvailabilityPresentation on VariantAvailability {
  String get label {
    switch (this) {
      case VariantAvailability.live:
        return 'Готово';
      case VariantAvailability.gated:
        return 'Закрыто до запуска';
    }
  }
}

class ProgramScope {
  const ProgramScope({
    required this.publicReleaseTargets,
    required this.readinessOnlyTargets,
  });

  final List<ClientPlatform> publicReleaseTargets;
  final List<ClientPlatform> readinessOnlyTargets;

  String get publicReleaseSummary =>
      publicReleaseTargets.map((platform) => platform.label).join(', ');

  String get readinessOnlySummary =>
      readinessOnlyTargets.map((platform) => platform.label).join(', ');
}

class FreeTierPolicy {
  const FreeTierPolicy({
    required this.trafficGb,
    required this.periodDays,
    required this.speedMbps,
    required this.deviceLimit,
    required this.nodePool,
  });

  final int trafficGb;
  final int periodDays;
  final int speedMbps;
  final int deviceLimit;
  final String nodePool;

  String get quotaSummary => '$trafficGb ГБ на $periodDays дней';
  String get speedSummary => 'до $speedMbps Мбит/с на IP';
  String get deviceSummary =>
      deviceLimit == 1 ? '1 устройство' : 'до $deviceLimit устройств';
  String get nodePoolLabel =>
      nodePool.trim().toLowerCase() == 'nl-free' ? 'Бесплатный узел' : nodePool;
}

class RuntimeProfile {
  const RuntimeProfile({
    required this.defaultCore,
    required this.advancedFallbackCore,
    required this.defaultRouteMode,
    required this.supportedRouteModes,
    required this.trialDays,
    required this.telegramBonusDays,
    required this.freeTier,
    required this.allowsExternalCheckoutOnly,
    required this.firstPartyPromosOnly,
  });

  final RuntimeCore defaultCore;
  final RuntimeCore advancedFallbackCore;
  final RouteMode defaultRouteMode;
  final List<RouteMode> supportedRouteModes;
  final int trialDays;
  final int telegramBonusDays;
  final FreeTierPolicy freeTier;
  final bool allowsExternalCheckoutOnly;
  final bool firstPartyPromosOnly;

  String get supportedRouteSummary =>
      supportedRouteModes.map((mode) => mode.label).join(', ');
}

class SmartConnectProfile {
  const SmartConnectProfile({
    required this.eligible,
    required this.fallbackRequired,
    required this.shortlistReason,
    required this.shortlistLimit,
    required this.shortlistRevision,
    required this.transportProfile,
    required this.profileRevision,
    required this.fallbackOrder,
    required this.shortlist,
    required this.stickiness,
  });

  final bool eligible;
  final bool fallbackRequired;
  final String shortlistReason;
  final int shortlistLimit;
  final String shortlistRevision;
  final String transportProfile;
  final String profileRevision;
  final List<String> fallbackOrder;
  final List<SmartConnectNode> shortlist;
  final SmartConnectStickiness stickiness;

  static SmartConnectProfile? tryParse(Object? value) {
    if (value is! Map) {
      return null;
    }
    final json = value.map((key, value) => MapEntry(key.toString(), value));
    return SmartConnectProfile(
      eligible: _readBool(json['eligible']),
      fallbackRequired: _readBool(json['fallback_required']),
      shortlistReason: _readText(json['shortlist_reason']),
      shortlistLimit: _readInt(json['shortlist_limit']),
      shortlistRevision: _readText(json['shortlist_revision']),
      transportProfile: _readText(json['transport_profile']),
      profileRevision: _readText(json['profile_revision']),
      fallbackOrder: _readStringList(json['fallback_order']),
      shortlist: _readMapList(json['shortlist'])
          .map(SmartConnectNode.fromJson)
          .toList(growable: false),
      stickiness: SmartConnectStickiness.fromJson(
        _readMap(json['stickiness']),
      ),
    );
  }
}

class SmartConnectNode {
  const SmartConnectNode({
    required this.code,
    required this.country,
    required this.rank,
    required this.rankHint,
    this.probeHost = '',
    this.probePort = 0,
  });

  final String code;
  final String country;
  final int rank;
  final SmartConnectRankHint rankHint;
  final String probeHost;
  final int probePort;

  factory SmartConnectNode.fromJson(Map<String, dynamic> json) {
    final probe = _readMap(json['probe']);
    return SmartConnectNode(
      code: _readText(json['code']),
      country: _readText(json['country']),
      rank: _readInt(json['rank']),
      rankHint: SmartConnectRankHint.fromJson(_readMap(json['rank_hint'])),
      probeHost: _readText(probe['host'] ?? json['probe_host']),
      probePort: _readInt(probe['port'] ?? json['probe_port']),
    );
  }
}

class SmartConnectRankHint {
  const SmartConnectRankHint({
    required this.healthScore,
    required this.cpuPercent,
    required this.panelLatencyMs,
    required this.backendPenalty,
    required this.cpuPenalty,
    required this.stickyPreferred,
  });

  final double healthScore;
  final double cpuPercent;
  final int? panelLatencyMs;
  final int backendPenalty;
  final int cpuPenalty;
  final bool stickyPreferred;

  factory SmartConnectRankHint.fromJson(Map<String, dynamic> json) {
    return SmartConnectRankHint(
      healthScore: _readDouble(json['health_score']),
      cpuPercent: _readDouble(json['cpu_percent']),
      panelLatencyMs: _readNullableInt(json['panel_latency_ms']),
      backendPenalty: _readInt(json['backend_penalty']),
      cpuPenalty: _readInt(json['cpu_penalty']),
      stickyPreferred: _readBool(json['sticky_preferred']),
    );
  }
}

class SmartConnectStickiness {
  const SmartConnectStickiness({
    required this.preferredNodeCode,
    required this.thresholdPercent,
    required this.latestSampleAt,
    required this.stickinessApplied,
  });

  final String preferredNodeCode;
  final int thresholdPercent;
  final String latestSampleAt;
  final bool stickinessApplied;

  factory SmartConnectStickiness.fromJson(Map<String, dynamic> json) {
    return SmartConnectStickiness(
      preferredNodeCode: _readText(json['preferred_node_code']),
      thresholdPercent: _readInt(json['threshold_percent']),
      latestSampleAt: _readText(json['latest_sample_at']),
      stickinessApplied: _readBool(json['stickiness_applied']),
    );
  }
}

class LocationVariant {
  const LocationVariant({
    required this.kind,
    this.availability = VariantAvailability.live,
    this.note = '',
  });

  final TransportKind kind;
  final VariantAvailability availability;
  final String note;

  bool get isLive => availability == VariantAvailability.live;
}

class LocationCluster {
  const LocationCluster({
    required this.code,
    required this.label,
    required this.city,
    required this.countryCode,
    required this.variants,
    this.recommendedLane = '',
  });

  final String code;
  final String label;
  final String city;
  final String countryCode;
  final List<LocationVariant> variants;
  final String recommendedLane;

  String get heading => '$label · $city';
}

Map<String, dynamic> _readMap(Object? value) {
  if (value is! Map) {
    return const <String, dynamic>{};
  }
  return value.map((key, value) => MapEntry(key.toString(), value));
}

List<Map<String, dynamic>> _readMapList(Object? value) {
  if (value is! List) {
    return const <Map<String, dynamic>>[];
  }
  return value.whereType<Map>().map(_readMap).toList(growable: false);
}

List<String> _readStringList(Object? value) {
  if (value is! List) {
    return const <String>[];
  }
  return value
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

String _readText(Object? value) => value?.toString().trim() ?? '';

bool _readBool(Object? value) {
  if (value is bool) {
    return value;
  }
  final text = _readText(value).toLowerCase();
  return text == 'true' || text == '1' || text == 'yes';
}

int _readInt(Object? value) => _readNullableInt(value) ?? 0;

int? _readNullableInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.round();
  }
  return int.tryParse(_readText(value));
}

double _readDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(_readText(value)) ?? 0;
}
