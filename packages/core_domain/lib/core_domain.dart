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
        return 'Trial premium';
      case AccessLane.bonusPremium:
        return 'Bonus premium';
      case AccessLane.paidUnlimited:
        return 'Paid unlimited';
      case AccessLane.freeMonthly:
        return 'Free monthly';
      case AccessLane.freeSoftMode:
        return 'Free soft mode';
    }
  }

  String get summary {
    switch (this) {
      case AccessLane.trialPremium:
        return 'First run starts with a real 5-day premium access lane.';
      case AccessLane.bonusPremium:
        return 'Channel linking unlocks a one-time +10 day premium bonus.';
      case AccessLane.paidUnlimited:
        return 'Paid access keeps all enabled non-free nodes available without quota messaging.';
      case AccessLane.freeMonthly:
        return 'Free monthly keeps the user on NL-free with renewable quota and gentle upsell.';
      case AccessLane.freeSoftMode:
        return 'Soft mode keeps continuity after quota pressure while the app pushes upgrade and support help.';
    }
  }
}

extension RouteModePresentation on RouteMode {
  String get label {
    switch (this) {
      case RouteMode.fullTunnel:
        return 'Full tunnel';
      case RouteMode.selectedApps:
        return 'Selected apps';
      case RouteMode.allExceptRu:
        return 'All except RU';
    }
  }

  String get summary {
    switch (this) {
      case RouteMode.fullTunnel:
        return 'Route the entire device through the managed profile.';
      case RouteMode.selectedApps:
        return 'Split tunnel only the chosen apps or processes when the host supports it.';
      case RouteMode.allExceptRu:
        return 'Keep a regional bypass lane for local services while routing everything else.';
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
        return 'Live';
      case VariantAvailability.gated:
        return 'Launch gated';
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

  String get quotaSummary => '$trafficGb GB / $periodDays days';
  String get speedSummary => '$speedMbps Mbps per IP';
  String get deviceSummary => 'Up to $deviceLimit device';
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
