import 'package:pokrov_observability_contracts/observability_contracts.dart';

enum PortalTransportFailure {
  dns,
  connect,
  tls,
  timeout,
  responseTooLarge,
  schema
}

enum ClientUpdateFailure {
  manifest,
  artifactIntegrity,
  signature,
  identity,
  installer,
  postHealth,
  recovery,
  androidPermission,
}

enum OperationalFaultCoverage { localAutomated, sourceMapped, notShipped }

enum OperationalFaultInjection {
  portalDnsUnavailable,
  tlsInterceptionOrClockSkew,
  runtimeProfileInvalid,
  coreArtifactMissing,
  coreAbiMismatch,
  coreStartTimeout,
  tunCreateDenied,
  routesApplyFailure,
  dnsApplyFailure,
  dnsProofTimeout,
  egressWrongRegion,
  serviceCrash,
  networkFlapping,
  androidPermissionRevoked,
  windowsIpcMismatch,
  linuxPolkitDenial,
  apkIdentityMismatch,
  bundlePlantedToken,
  uploadInterrupted,
}

enum OperationalNetworkChaosScenario {
  packetLoss,
  dnsUnavailable,
  mtuBlackHole,
  ipv6PathUnavailable,
}

final class OperationalFaultExpectation {
  const OperationalFaultExpectation({
    required this.phase,
    required this.errorCodes,
    required this.coverage,
    required this.privilegedMutationAllowed,
    required this.rollbackRequired,
  });

  final String phase;
  final List<String> errorCodes;
  final OperationalFaultCoverage coverage;
  final bool privilegedMutationAllowed;
  final bool rollbackRequired;
}

final class OperationalNetworkChaosExpectation {
  const OperationalNetworkChaosExpectation({
    required this.phase,
    required this.runtimeFailureKind,
    required this.errorCode,
  });

  final String phase;
  final String runtimeFailureKind;
  final String errorCode;
}

abstract final class OperationalFailureMapper {
  static String portal({
    int? statusCode,
    PortalTransportFailure? transport,
    String platformCode = '',
  }) {
    final platform = platformCode.trim().toLowerCase();
    final mappedPlatform = _platformCodes[platform];
    if (mappedPlatform != null) {
      return mappedPlatform;
    }
    if (transport != null) {
      return switch (transport) {
        PortalTransportFailure.dns => 'API-001',
        PortalTransportFailure.connect ||
        PortalTransportFailure.timeout =>
          'API-002',
        PortalTransportFailure.tls => 'API-003',
        PortalTransportFailure.schema => 'API-008',
        PortalTransportFailure.responseTooLarge => 'API-010',
      };
    }
    return switch (statusCode) {
      401 => 'API-004',
      403 => 'API-005',
      429 => 'API-006',
      final value when value != null && value >= 500 => 'API-007',
      _ => 'API-008',
    };
  }

  static String connection(
    String? runtimeFailureKind, {
    bool timedOut = false,
    bool permissionDenied = false,
  }) {
    if (timedOut) {
      return 'CONN-008';
    }
    if (permissionDenied) {
      return 'CONN-001';
    }
    final normalized = runtimeFailureKind?.trim().toLowerCase() ?? '';
    return _runtimeCodes[normalized] ?? 'CONN-005';
  }

  static String update(ClientUpdateFailure failure) => switch (failure) {
        ClientUpdateFailure.manifest => 'UPD-001',
        ClientUpdateFailure.artifactIntegrity => 'UPD-002',
        ClientUpdateFailure.signature => 'UPD-003',
        ClientUpdateFailure.identity => 'UPD-004',
        ClientUpdateFailure.installer => 'UPD-005',
        ClientUpdateFailure.postHealth => 'UPD-006',
        ClientUpdateFailure.recovery => 'UPD-007',
        ClientUpdateFailure.androidPermission => 'AND-UPD-001',
      };

  static OperationalFaultExpectation injectedFault(
    OperationalFaultInjection fault,
  ) =>
      _faultExpectations[fault]!;

  static OperationalNetworkChaosExpectation networkChaos(
    OperationalNetworkChaosScenario scenario,
  ) =>
      _networkChaosExpectations[scenario]!;

  static void validateCatalogCoverage() {
    for (final code in <String>{
      ..._platformCodes.values,
      ..._runtimeCodes.values,
      for (final failure in ClientUpdateFailure.values) update(failure),
      for (final expectation in _faultExpectations.values)
        ...expectation.errorCodes,
      for (final expectation in _networkChaosExpectations.values)
        expectation.errorCode,
    }) {
      if (!KnownOperationalErrorCodes.contains(code)) {
        throw StateError('Failure mapping references unknown code: $code');
      }
    }
    if (_faultExpectations.length != OperationalFaultInjection.values.length ||
        _networkChaosExpectations.length !=
            OperationalNetworkChaosScenario.values.length) {
      throw StateError('Fault or network-chaos matrix is incomplete');
    }
  }

  static const Map<String, String> _platformCodes = <String, String>{
    'auth_session_expired': 'AUTH-002',
    'fresh_auth_required': 'AUTH-002',
    'device_recovery_required': 'AUTH-002',
    'device_limit_exceeded': 'AUTH-004',
    'account_restricted': 'AUTH-005',
    'acquisition_expired': 'AUTH-006',
    'acquisition_replayed': 'AUTH-006',
    'node_capacity_exhausted': 'CONN-006',
  };

  static const Map<String, String> _runtimeCodes = <String, String>{
    'desktop_competing_vpn_active': 'WIN-TUN-003',
    'desktop_loopback_port_conflict': 'CORE-003',
    'desktop_tun_start_failed': 'WIN-TUN-002',
    'tun_create_denied': 'TUN-001',
    'route_apply_failed': 'ROUTE-001',
    'dns_apply_failed': 'DNS-001',
    'runtime_initialization_failed': 'CORE-001',
    'core_abi_mismatch': 'CORE-002',
    'core_capabilities_incompatible': 'CORE-002',
    'runtime_start_after_permission_failed': 'CONN-001',
    'runtime_start_failed': 'CORE-003',
    'runtime_service_start_failed': 'WIN-SVC-003',
    'foreground_start_failed': 'AND-VPN-002',
    'runtime_stop_failed': 'CORE-008',
    'core_egress_probe_failed': 'EGRESS-001',
    'core_egress_probe_unavailable': 'CONN-008',
    'desktop_tun_egress_probe_failed': 'EGRESS-001',
    'emergency_endpoint_unreachable': 'CONN-006',
    'profile_staging_failed': 'CONN-005',
    'config_apply_failed': 'CORE-005',
    'notification_permission_denied': 'AND-BG-002',
    'resolver_response_error': 'DNS-002',
    'resolver_callback_error': 'DNS-002',
    'resolver_timeout': 'DNS-002',
    'dns_failure': 'DNS-002',
    'network_flapping': 'RECON-002',
    'mtu_path_unverified': 'EGRESS-001',
    'ipv6_route_unavailable': 'ROUTE-003',
    'egress_region_mismatch': 'EGRESS-002',
    'vpn_permission_revoked': 'AND-VPN-004',
    'service_protocol_mismatch': 'WIN-SVC-004',
    'default_network_unavailable': 'CONN-003',
    'default_network_interface_unresolved': 'ROUTE-003',
    'default_network_index_unresolved': 'ROUTE-003',
    'network_unavailable': 'CONN-003',
    'tunnel_handshake_failed': 'CORE-006',
    'runtime_failure': 'CONN-005',
  };

  static const Map<OperationalFaultInjection, OperationalFaultExpectation>
      _faultExpectations =
      <OperationalFaultInjection, OperationalFaultExpectation>{
    OperationalFaultInjection.portalDnsUnavailable: OperationalFaultExpectation(
      phase: 'profile',
      errorCodes: <String>['API-001'],
      coverage: OperationalFaultCoverage.sourceMapped,
      privilegedMutationAllowed: false,
      rollbackRequired: false,
    ),
    OperationalFaultInjection.tlsInterceptionOrClockSkew:
        OperationalFaultExpectation(
      phase: 'profile',
      errorCodes: <String>['API-003', 'AUTH-003'],
      coverage: OperationalFaultCoverage.sourceMapped,
      privilegedMutationAllowed: false,
      rollbackRequired: false,
    ),
    OperationalFaultInjection.runtimeProfileInvalid:
        OperationalFaultExpectation(
      phase: 'profile',
      errorCodes: <String>['CONN-005'],
      coverage: OperationalFaultCoverage.localAutomated,
      privilegedMutationAllowed: false,
      rollbackRequired: false,
    ),
    OperationalFaultInjection.coreArtifactMissing: OperationalFaultExpectation(
      phase: 'core',
      errorCodes: <String>['CORE-001'],
      coverage: OperationalFaultCoverage.localAutomated,
      privilegedMutationAllowed: false,
      rollbackRequired: false,
    ),
    OperationalFaultInjection.coreAbiMismatch: OperationalFaultExpectation(
      phase: 'core',
      errorCodes: <String>['CORE-002'],
      coverage: OperationalFaultCoverage.localAutomated,
      privilegedMutationAllowed: false,
      rollbackRequired: false,
    ),
    OperationalFaultInjection.coreStartTimeout: OperationalFaultExpectation(
      phase: 'core',
      errorCodes: <String>['CORE-003'],
      coverage: OperationalFaultCoverage.localAutomated,
      privilegedMutationAllowed: true,
      rollbackRequired: true,
    ),
    OperationalFaultInjection.tunCreateDenied: OperationalFaultExpectation(
      phase: 'tun',
      errorCodes: <String>['TUN-001'],
      coverage: OperationalFaultCoverage.sourceMapped,
      privilegedMutationAllowed: false,
      rollbackRequired: false,
    ),
    OperationalFaultInjection.routesApplyFailure: OperationalFaultExpectation(
      phase: 'routes',
      errorCodes: <String>['ROUTE-001'],
      coverage: OperationalFaultCoverage.localAutomated,
      privilegedMutationAllowed: true,
      rollbackRequired: true,
    ),
    OperationalFaultInjection.dnsApplyFailure: OperationalFaultExpectation(
      phase: 'dns',
      errorCodes: <String>['DNS-001'],
      coverage: OperationalFaultCoverage.localAutomated,
      privilegedMutationAllowed: true,
      rollbackRequired: true,
    ),
    OperationalFaultInjection.dnsProofTimeout: OperationalFaultExpectation(
      phase: 'dns',
      errorCodes: <String>['DNS-002'],
      coverage: OperationalFaultCoverage.localAutomated,
      privilegedMutationAllowed: true,
      rollbackRequired: true,
    ),
    OperationalFaultInjection.egressWrongRegion: OperationalFaultExpectation(
      phase: 'egress',
      errorCodes: <String>['EGRESS-002'],
      coverage: OperationalFaultCoverage.sourceMapped,
      privilegedMutationAllowed: true,
      rollbackRequired: true,
    ),
    OperationalFaultInjection.serviceCrash: OperationalFaultExpectation(
      phase: 'recovery',
      errorCodes: <String>['CRASH-003'],
      coverage: OperationalFaultCoverage.localAutomated,
      privilegedMutationAllowed: true,
      rollbackRequired: true,
    ),
    OperationalFaultInjection.networkFlapping: OperationalFaultExpectation(
      phase: 'recovery',
      errorCodes: <String>['RECON-002'],
      coverage: OperationalFaultCoverage.sourceMapped,
      privilegedMutationAllowed: true,
      rollbackRequired: false,
    ),
    OperationalFaultInjection.androidPermissionRevoked:
        OperationalFaultExpectation(
      phase: 'tun',
      errorCodes: <String>['AND-VPN-004'],
      coverage: OperationalFaultCoverage.localAutomated,
      privilegedMutationAllowed: true,
      rollbackRequired: true,
    ),
    OperationalFaultInjection.windowsIpcMismatch: OperationalFaultExpectation(
      phase: 'bootstrap',
      errorCodes: <String>['WIN-SVC-004'],
      coverage: OperationalFaultCoverage.localAutomated,
      privilegedMutationAllowed: false,
      rollbackRequired: false,
    ),
    OperationalFaultInjection.linuxPolkitDenial: OperationalFaultExpectation(
      phase: 'bootstrap',
      errorCodes: <String>['LNX-POLKIT-001'],
      coverage: OperationalFaultCoverage.notShipped,
      privilegedMutationAllowed: false,
      rollbackRequired: false,
    ),
    OperationalFaultInjection.apkIdentityMismatch: OperationalFaultExpectation(
      phase: 'update',
      errorCodes: <String>['AND-UPD-002'],
      coverage: OperationalFaultCoverage.localAutomated,
      privilegedMutationAllowed: false,
      rollbackRequired: false,
    ),
    OperationalFaultInjection.bundlePlantedToken: OperationalFaultExpectation(
      phase: 'support',
      errorCodes: <String>['SUP-002', 'SEC-001'],
      coverage: OperationalFaultCoverage.localAutomated,
      privilegedMutationAllowed: false,
      rollbackRequired: false,
    ),
    OperationalFaultInjection.uploadInterrupted: OperationalFaultExpectation(
      phase: 'support',
      errorCodes: <String>['SUP-005'],
      coverage: OperationalFaultCoverage.localAutomated,
      privilegedMutationAllowed: false,
      rollbackRequired: false,
    ),
  };

  static const Map<OperationalNetworkChaosScenario,
          OperationalNetworkChaosExpectation> _networkChaosExpectations =
      <OperationalNetworkChaosScenario, OperationalNetworkChaosExpectation>{
    OperationalNetworkChaosScenario.packetLoss:
        OperationalNetworkChaosExpectation(
      phase: 'egress',
      runtimeFailureKind: 'core_egress_probe_failed',
      errorCode: 'EGRESS-001',
    ),
    OperationalNetworkChaosScenario.dnsUnavailable:
        OperationalNetworkChaosExpectation(
      phase: 'dns',
      runtimeFailureKind: 'resolver_timeout',
      errorCode: 'DNS-002',
    ),
    OperationalNetworkChaosScenario.mtuBlackHole:
        OperationalNetworkChaosExpectation(
      phase: 'egress',
      runtimeFailureKind: 'mtu_path_unverified',
      errorCode: 'EGRESS-001',
    ),
    OperationalNetworkChaosScenario.ipv6PathUnavailable:
        OperationalNetworkChaosExpectation(
      phase: 'routes',
      runtimeFailureKind: 'ipv6_route_unavailable',
      errorCode: 'ROUTE-003',
    ),
  };
}
