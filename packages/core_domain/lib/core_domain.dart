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
        return 'Try free gives this device full access for 5 days.';
      case AccessLane.bonusPremium:
        return 'Link Telegram to claim one extra +10 day extension.';
      case AccessLane.paidUnlimited:
        return 'Paid access keeps every enabled non-free location available without data limits.';
      case AccessLane.freeMonthly:
        return 'After the premium period, the app keeps a lighter NL-free connection with a renewable quota.';
      case AccessLane.freeSoftMode:
        return 'If the monthly quota runs out, the app keeps things calm and points you to renew or get help.';
    }
  }
}

extension RouteModePresentation on RouteMode {
  String get label {
    switch (this) {
      case RouteMode.fullTunnel:
        return 'Full tunnel';
      case RouteMode.selectedApps:
        return 'Only selected apps';
      case RouteMode.allExceptRu:
        return 'All except RU';
    }
  }

  String get summary {
    switch (this) {
      case RouteMode.fullTunnel:
        return 'Send all traffic on this device through POKROV.';
      case RouteMode.selectedApps:
        return 'Only the apps you choose use POKROV. Everything else stays direct.';
      case RouteMode.allExceptRu:
        return 'Keep Russian and local services direct while protecting the rest of the device.';
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
