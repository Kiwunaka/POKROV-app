library pokrov_platform_contracts;

import 'package:pokrov_core_domain/core_domain.dart';

enum PermissionRequirement {
  notifications,
  vpnProfile,
  backgroundStart,
  elevatedSession,
}

class PlatformBootstrapContract {
  const PlatformBootstrapContract({
    required this.hostPlatform,
    required this.requiredPermissions,
    required this.defaultCore,
    this.advancedFallbackCore,
    required this.supportsSelectedAppsMode,
  });

  final HostPlatform hostPlatform;
  final List<PermissionRequirement> requiredPermissions;
  final RuntimeCore defaultCore;
  final RuntimeCore? advancedFallbackCore;
  final bool supportsSelectedAppsMode;

  String get permissionsSummary =>
      requiredPermissions.map((permission) => permission.label).join(', ');
}

extension PermissionRequirementPresentation on PermissionRequirement {
  String get label {
    switch (this) {
      case PermissionRequirement.notifications:
        return 'Notifications';
      case PermissionRequirement.vpnProfile:
        return 'VPN profile';
      case PermissionRequirement.backgroundStart:
        return 'Background start';
      case PermissionRequirement.elevatedSession:
        return 'Elevated session';
    }
  }
}
