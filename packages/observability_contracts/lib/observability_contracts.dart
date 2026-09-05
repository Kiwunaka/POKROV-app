library pokrov_observability_contracts;

class ObservabilityContractDescriptor {
  const ObservabilityContractDescriptor({
    required this.id,
    required this.version,
    required this.sha256,
  });

  final String id;
  final String version;
  final String sha256;
}

abstract final class PokrovObservabilityContracts {
  static const event = ObservabilityContractDescriptor(
    id: 'observability-event',
    version: '1.0.0',
    sha256: '24ae72442f778d7f1334ae0a4bf4d774738e4de275707b29420ec733af65cc17',
  );

  static const errorCatalog = ObservabilityContractDescriptor(
    id: 'error-catalog',
    version: '1.2.0',
    sha256: '1cef07aea2f859891794546569431d0e6aab91c6921729389fd63013f3002af1',
  );

  static const descriptors = <ObservabilityContractDescriptor>[
    errorCatalog,
    event,
  ];
}

enum ObservabilitySeverity { trace, debug, info, warn, error, fatal }

enum ObservabilityOutcome {
  started('started'),
  succeeded('succeeded'),
  failed('failed'),
  cancelled('cancelled'),
  superseded('superseded'),
  degraded('degraded'),
  blocked('blocked'),
  observed('observed'),
  notApplicable('not_applicable');

  const ObservabilityOutcome(this.wireValue);

  final String wireValue;
}

enum ObservabilityPrivacyClass {
  localOperational('local_operational'),
  releaseHealth('release_health'),
  supportBundle('support_bundle'),
  serverSecurityAudit('server_security_audit');

  const ObservabilityPrivacyClass(this.wireValue);

  final String wireValue;
}

enum ObservabilityErrorOrigin {
  client,
  host,
  core,
  portal,
  provider,
  os,
  security,
}

abstract final class ObservabilityAttributeKeys {
  static const allowed = <String>{
    'artifact_kind',
    'bundle_item_count',
    'bundle_size_bytes',
    'bytes_in',
    'bytes_out',
    'contract_sha256',
    'contract_version',
    'core_abi',
    'crash_signature',
    'dns_ready',
    'dropped_count',
    'duration_ms',
    'effective_mtu',
    'egress_ready',
    'error_count',
    'from_version',
    'interface_ready',
    'journal_kind',
    'manifest_version',
    'network_class',
    'operation',
    'permission_state',
    'phase',
    'queue_depth',
    'reason_class',
    'retention_days',
    'retry_after_ms',
    'retry_count',
    'routes_ready',
    'segment_number',
    'selected_app_count',
    'status_class',
    'support_mode',
    'to_version',
    'update_channel',
  };
}

abstract final class KnownOperationalErrorCodes {
  static const values = <String>{
    'APP-BOOT-001',
    'APP-BOOT-002',
    'APP-BOOT-003',
    'APP-BOOT-004',
    'APP-BOOT-005',
    'APP-BOOT-006',
    'APP-BOOT-007',
    'APP-BOOT-008',
    'AUTH-001',
    'AUTH-002',
    'AUTH-003',
    'AUTH-004',
    'AUTH-005',
    'AUTH-006',
    'API-001',
    'API-002',
    'API-003',
    'API-004',
    'API-005',
    'API-006',
    'API-007',
    'API-008',
    'API-009',
    'API-010',
    'API-011',
    'ENT-001',
    'ENT-002',
    'ENT-003',
    'ENT-004',
    'CONN-001',
    'CONN-002',
    'CONN-003',
    'CONN-004',
    'CONN-005',
    'CONN-006',
    'CONN-007',
    'CONN-008',
    'CORE-001',
    'CORE-002',
    'CORE-003',
    'CORE-004',
    'CORE-005',
    'CORE-006',
    'CORE-007',
    'CORE-008',
    'CORE-009',
    'TRANSPORT-001',
    'TRANSPORT-002',
    'TRANSPORT-003',
    'TRANSPORT-004',
    'TRANSPORT-005',
    'TRANSPORT-006',
    'TRANSPORT-007',
    'TUN-001',
    'TUN-002',
    'TUN-003',
    'TUN-004',
    'ROUTE-001',
    'ROUTE-002',
    'ROUTE-003',
    'ROUTE-004',
    'ROUTE-005',
    'DNS-001',
    'DNS-002',
    'DNS-003',
    'DNS-004',
    'EGRESS-001',
    'EGRESS-002',
    'EGRESS-003',
    'RECON-001',
    'RECON-002',
    'RECON-003',
    'WIN-SVC-001',
    'WIN-SVC-002',
    'WIN-SVC-003',
    'WIN-SVC-004',
    'WIN-SVC-005',
    'WIN-SVC-006',
    'WIN-TUN-001',
    'WIN-TUN-002',
    'WIN-TUN-003',
    'WIN-DNS-001',
    'WIN-DNS-002',
    'AND-VPN-001',
    'AND-VPN-002',
    'AND-VPN-003',
    'AND-VPN-004',
    'AND-VPN-005',
    'AND-BG-001',
    'AND-BG-002',
    'AND-BG-003',
    'AND-UPD-001',
    'AND-UPD-002',
    'LNX-SVC-001',
    'LNX-SVC-002',
    'LNX-IPC-001',
    'LNX-POLKIT-001',
    'LNX-NM-001',
    'LNX-DNS-001',
    'LNX-NFT-001',
    'LNX-NFT-002',
    'UPD-001',
    'UPD-002',
    'UPD-003',
    'UPD-004',
    'UPD-005',
    'UPD-006',
    'UPD-007',
    'CRASH-001',
    'CRASH-002',
    'CRASH-003',
    'HANG-001',
    'HANG-002',
    'HANG-003',
    'PERF-001',
    'PERF-002',
    'PERF-003',
    'SUP-001',
    'SUP-002',
    'SUP-003',
    'SUP-004',
    'SUP-005',
    'SUP-006',
    'SEC-001',
    'SEC-002',
    'SEC-003',
    'SEC-004',
  };

  static bool contains(String code) => values.contains(code);
}
