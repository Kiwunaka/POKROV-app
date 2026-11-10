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
    sha256: 'bc54f03e91135e6fc017f484fdb628bd0e089308891964a26f0e1303efdce238',
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

// Only source-defined API reasons may cross the diagnostics boundary.
enum PortalFailureReason {
  deviceLimitReached('device_limit_reached'),
  deviceLimitExceeded('device_limit_exceeded'),
  pairingNotFound('pairing_not_found'),
  pairingCodeInvalid('pairing_code_invalid'),
  pairingCodeExpired('pairing_code_expired'),
  pairingCodeUsed('pairing_code_used'),
  deviceAlreadyRegistered('device_already_registered'),
  deviceIdentityConflict('device_identity_conflict'),
  deviceInvalid('device_invalid'),
  pairingNotConfigured('pairing_not_configured'),
  authSessionExpired('auth_session_expired'),
  freshAuthRequired('fresh_auth_required'),
  deviceRecoveryRequired('device_recovery_required'),
  accessExpired('access_expired'),
  refreshTokenInvalid('refresh_token_invalid'),
  refreshReuseDetected('refresh_reuse_detected'),
  refreshExpired('refresh_expired'),
  sessionRevoked('session_revoked'),
  deviceRevoked('device_revoked'),
  deviceCredentialChanged('device_credential_changed'),
  sessionEpochChanged('session_epoch_changed'),
  sessionIdentityChanged('session_identity_changed'),
  accountNotFound('account_not_found'),
  accountUnavailable('account_unavailable'),
  accountRestricted('account_restricted'),
  rateLimited('rate_limited'),
  serviceUnavailable('service_unavailable'),
  nodeCapacityExhausted('node_capacity_exhausted'),
  emailOtpInvalid('email_otp_invalid'),
  emailOtpExpired('email_otp_expired'),
  redeemCodeRequired('redeem_code_required'),
  subscriptionLinkNotRedeemCode('subscription_link_not_redeem_code'),
  redeemCodeNotSupported('redeem_code_not_supported'),
  accessKeyNotFound('access_key_not_found'),
  accessKeyRevoked('access_key_revoked'),
  accessKeyAlreadyRedeemed('access_key_already_redeemed'),
  accessKeySelfRedeem('access_key_self_redeem'),
  accessKeyTypeUnsupported('access_key_type_unsupported'),
  termsRequired('terms_required'),
  promoNotFound('promo_not_found'),
  promoExhausted('promo_exhausted'),
  promoExpired('promo_expired'),
  promoAlreadyRedeemed('promo_already_redeemed'),
  promoInvalid('promo_invalid'),
  promoCampaignRestricted('promo_campaign_restricted'),
  giftCodeInvalid('gift_code_invalid'),
  giftCodeNotFound('gift_code_not_found'),
  giftCodeRevoked('gift_code_revoked'),
  giftCodeTypeUnsupported('gift_code_type_unsupported'),
  giftCodeAlreadyRedeemed('gift_code_already_redeemed'),
  giftCodeSelfRedeem('gift_code_self_redeem'),
  paymentPending('payment_pending'),
  paymentClaimReversed('payment_claim_reversed'),
  paymentManualReview('payment_manual_review'),
  paymentAccountConflict('payment_account_conflict'),
  activeAccessRequired('active_access_required'),
  sessionNotConfigured('session_not_configured'),
  paymentNotRedeemable('payment_not_redeemable'),
  giftCampaignRestricted('gift_campaign_restricted');

  const PortalFailureReason(this.wireValue);
  final String wireValue;

  static PortalFailureReason? fromCode(String? code) {
    final normalized = code?.trim().toLowerCase();
    for (final reason in values) {
      if (reason.wireValue == normalized) return reason;
    }
    return null;
  }
}

const managedProfileFallbackEventName = 'app.connection.managed_profile_fallback.finished';
const cachedCandidateMaterialsEventName = 'app.connection.cached_candidate_materials.finished';

abstract final class ObservabilityAttributeKeys {
  static const allowed = <String>{
    'api_failure_kind',
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
    'fallback_kind',
    'failure_kind',
    'failure_operation',
    'failure_reason',
    'from_version',
    'http_status',
    'interface_ready',
    'journal_kind',
    'manifest_version',
    'material_origin',
    'network_class',
    'offline_classification_elapsed_ms',
    'operation',
    'os_error_code',
    'permission_state',
    'phase',
    'preparation',
    'prepare_reason',
    'probe_stage',
    'http_64k_failure',
    'http_64k_observation',
    'probe_error',
    'queue_depth',
    'reason_class',
    'refresh_elapsed_ms',
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

const connectionFailureOperations = <String>{
  'managed_profile_stage', 'core_connect', 'tunnel_settle', 'managed_profile_refresh',
  'qa_claim', 'managed_profile', 'routing_catalog', 'auth_refresh',
  'redeem', 'device_pairing_claim', 'session_start_trial',
  'subscription_refresh',
  'email_otp_start', 'email_otp_finish',
};

// Fixed admission/request failures; these are not network-quality failures.
const connectionClosedGuardCodes = <String>{
  'request_socket', 'request_http', 'request_timeout',
  'candidate_selection_exhausted', 'catalog_clock_rollback',
  'runtime_clock_unavailable', 'runtime_busy', 'network_context_unavailable', 'connect_owner_changed',
  'core_identity_connect_unavailable', 'catalog_native_control_unsupported',
  'invalid_connect_identity', 'invalid_connect_deadline',
  'managed_profile_stage_failed', 'smart_access_stage_identity_invalid', 'profile_payload_invalid',
  'core_identity_stage_binding_mismatch', 'core_identity_stage_superseded', 'smart_access_stage_superseded',
  'connect_deadline', 'operation_cancelled', 'core_identity_connect_superseded',
  'core_identity_connect_unacknowledged', 'core_identity_connect_mismatch', 'core_identity_connect_cancel_unconfirmed',
  'smart_access_qa_binding_mismatch', 'smart_access_qa_verification_failed', 'smart_access_qa_response_invalid',
  'smart_access_qa_not_current', 'smart_access_qa_superseded', 'smart_access_qa_stage_changed',
  'smart_access_qa_scope_changed', 'smart_access_qa_core_changed', 'smart_access_qa_connect_unsupported',
};

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
