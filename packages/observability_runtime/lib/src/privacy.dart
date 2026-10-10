import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:pokrov_observability_contracts/observability_contracts.dart';

abstract final class OperationalAttributePolicy {
  static const candidateHTTP64KFailures = <String>{
    'write_error', 'header_error', 'body_short', 'body_read_error',
  };
  static Map<String, Object>? candidateHTTP64KObservation(Object? value) {
    if (value is! Map || value.length != 4 ||
        !const {'owned_api', 'owned_reserve'}.contains(value['target']) || value['status'] is! int || value['status'] != 200 ||
        value['received_bytes'] is! int || (value['received_bytes'] as int) < 0 || (value['received_bytes'] as int) >= 65536 ||
        value['expected_bytes'] is! int || value['expected_bytes'] != 65536) return null;
    return Map<String, Object>.unmodifiable({'target': value['target'] as String, 'status': 200,
      'received_bytes': value['received_bytes'] as int, 'expected_bytes': 65536});
  }
  static const candidateProbeStages = <String>{
    'parse_profile', 'create_instance', 'start_instance', 'select_outbound',
    'proxy_dial', 'egress_check', 'tls_handshake', 'tls_read', 'tls_write',
    'tls_processing', 'tls_certificate_verified', 'tls_complete', 'http_204',
    'http_64k',
  };
  static const candidateProbeFailureKinds = <String>{
    'none',
    'invalid_request',
    'invalid_profile',
    'unavailable',
    'start_failed',
    'probe_failed',
    'probe_budget_expired',
    'connect_failed',
    'data_stalled',
    'tls_failed',
    'unexpected_status',
    'timeout',
    'cancelled',
    'network_changed',
    'duplicate_probe',
  };
  static const _booleanKeys = <String>{
    'interface_ready',
    'routes_ready',
    'dns_ready',
    'egress_ready',
  };
  static const _integerKeys = <String>{
    'duration_ms',
    'retry_count',
    'retry_after_ms',
    'effective_mtu',
    'bytes_in',
    'bytes_out',
    'queue_depth',
    'dropped_count',
    'segment_number',
    'selected_app_count',
    'core_abi',
    'bundle_item_count',
    'bundle_size_bytes',
    'retention_days',
    'error_count',
    'http_status',
    'os_error_code',
  };
  static const _releaseHealthKeys = <String>{
    'phase',
    'duration_ms',
    'status_class',
    'network_class',
    'reason_class',
    'retry_count',
    'dropped_count',
    'core_abi',
    'update_channel',
    'artifact_kind',
    'error_count',
    'selected_app_count',
  };
  static const _serverAuditKeys = <String>{
    'operation',
    'duration_ms',
    'status_class',
    'reason_class',
    'retry_count',
    'error_count',
  };
  static const _enums = <String, Set<String>>{
    'api_failure_kind': <String>{
      'origin_socket', 'origin_http', 'origin_tls', 'origin_timeout',
      'origin_content_type', 'origin_http_status', 'origin_json_syntax',
      'origin_json_not_object', 'origin_response_rejected',
      'request_socket', 'request_http', 'request_tls', 'request_timeout',
    },
    'phase': <String>{
      'bootstrap',
      'auth',
      'profile',
      'core',
      'tun',
      'routes',
      'dns',
      'egress',
      'recovery',
      'stop',
      'update',
      'support',
    },
    'operation': <String>{
      'initialize',
      'connect',
      'disconnect',
      'reconnect',
      'verify',
      'install',
      'upload',
      'export',
      'recover',
      'refresh',
      'request',
    },
    'status_class': <String>{
      'success',
      'client_error',
      'server_error',
      'timeout',
      'cancelled',
      'unavailable',
      'rate_limited',
      'invalid',
    },
    'network_class': <String>{
      'unknown',
      'offline',
      'wifi',
      'ethernet',
      'cellular',
      'vpn',
    },
    'reason_class': <String>{
      'unknown',
      'permission',
      'timeout',
      'integrity',
      'compatibility',
      'policy',
      'network',
      'provider',
      'operating_system',
      'user',
      'superseded',
    },
    'journal_kind': <String>{'none', 'runtime', 'network', 'update', 'service'},
    'update_channel': <String>{'direct', 'store', 'windows'},
    'artifact_kind': <String>{'apk', 'aab', 'exe', 'msix', 'zip', 'dll'},
    'permission_state': <String>{
      'unknown',
      'required',
      'granted',
      'denied',
      'revoked',
    },
    'support_mode': <String>{'off', 'temporary'},
    'prepare_reason': <String>{
      'access_preparing',
      'account_restricted',
      'acquisition_expired',
      'acquisition_replayed',
      'auth_session_expired',
      'candidate_selection_exhausted',
      'catalog_algorithm_invalid',
      'catalog_android_identity',
      'catalog_android_lineage',
      'catalog_app_scope_changed',
      'catalog_audience_mismatch',
      'catalog_blocked_service_direct',
      'catalog_browser_auto_direct',
      'catalog_cache_invalid',
      'catalog_cache_too_large',
      'catalog_cache_unavailable',
      'catalog_clock_rollback',
      'catalog_collection_invalid',
      'catalog_control_trust_unconfigured',
      'catalog_digest_mismatch',
      'catalog_disabled',
      'catalog_discovery_invalid',
      'catalog_discovery_too_large',
      'catalog_discovery_unavailable',
      'catalog_discovery_unsupported',
      'catalog_dns_lane_invalid',
      'catalog_domain_conflict',
      'catalog_domain_scope',
      'catalog_duplicate_evidence',
      'catalog_duplicate_network',
      'catalog_duplicate_service',
      'catalog_duplicate_source',
      'catalog_duplicate_windows_identity',
      'catalog_envelope_invalid',
      'catalog_evidence_service_mismatch',
      'catalog_fetch_superseded',
      'catalog_field_invalid',
      'catalog_full_coverage',
      'catalog_gateway_authority',
      'catalog_gateway_binding',
      'catalog_gateway_lease_missing',
      'catalog_gateway_pokrov',
      'catalog_gateway_scope',
      'catalog_gateway_service_not_eligible',
      'catalog_host_unsupported',
      'catalog_key_not_trusted',
      'catalog_local_dpi_authority',
      'catalog_local_dpi_control_scope',
      'catalog_native_control_unsupported',
      'catalog_native_targets_invalid',
      'catalog_native_window_unsupported',
      'catalog_nesting_invalid',
      'catalog_not_current',
      'catalog_payload_invalid',
      'catalog_policy_eligibility',
      'catalog_policy_expired',
      'catalog_preview_superseded',
      'catalog_probe_bootstrap_conflict',
      'catalog_process_dns_transport_unsupported',
      'catalog_process_scope_invalid',
      'catalog_profile_access_changed',
      'catalog_profile_access_invalid',
      'catalog_profile_binding_invalid',
      'catalog_profile_invalid',
      'catalog_projection_boolean',
      'catalog_projection_digest',
      'catalog_projection_domain',
      'catalog_projection_enum',
      'catalog_projection_id',
      'catalog_projection_lifetime',
      'catalog_projection_set',
      'catalog_projection_shape',
      'catalog_projection_text',
      'catalog_projection_time',
      'catalog_replacement_not_current',
      'catalog_response_invalid',
      'catalog_revision_floor_invalid',
      'catalog_revision_invalid',
      'catalog_rollback_rejected',
      'catalog_route_intent',
      'catalog_runtime_identity_invalid',
      'catalog_same_revision_changed',
      'catalog_schema_unsupported',
      'catalog_selected_service_unsupported',
      'catalog_selective_policy_required',
      'catalog_selective_unavailable',
      'catalog_service_revocation_invalid',
      'catalog_service_selection_changed',
      'catalog_service_selection_empty',
      'catalog_service_selection_scope',
      'catalog_service_stage_revoked',
      'catalog_session_changed',
      'catalog_shape_invalid',
      'catalog_shared_domain_not_routable',
      'catalog_signature_invalid',
      'catalog_source_url',
      'catalog_stage_revoked',
      'catalog_synthetic_production_evidence',
      'catalog_time_invalid',
      'catalog_too_large',
      'catalog_trust_unconfigured',
      'catalog_tun_scope_missing',
      'catalog_unknown_evidence_service',
      'catalog_unknown_source',
      'catalog_unverified_route_authority',
      'catalog_value_invalid',
      'catalog_verification_failed',
      'catalog_verified_evidence_missing',
      'catalog_windows_path_not_public',
      'catalog_windows_platform',
      'device_limit_exceeded',
      'device_recovery_required',
      'fresh_auth_required',
      'managed_profile_superseded',
      'node_capacity_exhausted',
      'routing_catalog_disabled',
      'routing_catalog_unavailable',
      'smart_access_budget_exhausted',
      'smart_access_capability_mismatch',
      'smart_access_clock_rollback',
      'smart_access_control_binding_mismatch',
      'smart_access_control_not_current',
      'smart_access_control_request_invalid',
      'smart_access_disabled',
      'smart_access_envelope_invalid',
      'smart_access_fetch_superseded',
      'smart_access_floor_invalid',
      'smart_access_grant_binding_mismatch',
      'smart_access_lease_invalid',
      'smart_access_lease_not_current',
      'smart_access_lease_scope_mismatch',
      'smart_access_native_binding_mismatch',
      'smart_access_native_projection_invalid',
      'smart_access_native_recovery_required',
      'smart_access_native_recovery_unsupported',
      'smart_access_native_tag_collision',
      'smart_access_native_unsupported',
      'smart_access_policy_invalid',
      'smart_access_policy_not_current',
      'smart_access_profile_already_leased',
      'smart_access_profile_changed',
      'smart_access_recovery_changed',
      'smart_access_recovery_requires_stopped_runtime',
      'smart_access_recovery_superseded',
      'smart_access_reference_invalid',
      'smart_access_relay_budget_invalid',
      'smart_access_renewal_binding_missing',
      'smart_access_renewal_revoked',
      'smart_access_renewal_scope_mismatch',
      'smart_access_renewal_superseded',
      'smart_access_request_invalid',
      'smart_access_response_invalid',
      'smart_access_restage_requires_fresh_profile',
      'smart_access_runtime_binding_missing',
      'smart_access_runtime_capability_expired',
      'smart_access_runtime_capability_invalid',
      'smart_access_runtime_inventory_full',
      'smart_access_runtime_origin_invalid',
      'smart_access_runtime_renewal_capability_expired',
      'smart_access_runtime_renewal_capability_invalid',
      'smart_access_runtime_storage_invalid',
      'smart_access_service_not_eligible',
      'smart_access_signature_invalid',
      'smart_access_stage_expired',
      'smart_access_stage_revoked',
      'smart_access_stage_unsupported',
      'smart_access_storage_unavailable',
      'smart_access_trust_unconfigured',
      'smart_access_verification_failed',
      'transport_https_required',
    },
    'probe_stage': candidateProbeStages,
    'http_64k_failure': candidateHTTP64KFailures,
    'failure_kind': candidateProbeFailureKinds,
  };

  static final _versionPattern = RegExp(
    r'^[0-9]+\.[0-9]+\.[0-9]+(?:[-+][A-Za-z0-9.-]+)?$',
  );
  static final _shaPattern = RegExp(r'^[0-9a-f]{64}$');
  static final _signaturePattern = RegExp(r'^[0-9a-f]{16,64}$');

  // Unknown server/exception text must not discard the failed phase or enter
  // the local journal. Only source-defined preparation codes are retained.
  static Map<String, Object?> prepareFailureAttributes({
    String? reason,
    int? httpStatus,
    String? apiFailureKind,
    int? osErrorCode,
  }) =>
      <String, Object?>{
        if (reason != null && _enums['prepare_reason']!.contains(reason))
          'prepare_reason': reason,
        if (httpStatus != null && httpStatus >= 100 && httpStatus <= 599)
          'http_status': httpStatus,
        if (apiFailureKind != null && _enums['api_failure_kind']!.contains(apiFailureKind))
          'api_failure_kind': apiFailureKind,
        if (osErrorCode != null && osErrorCode >= 0)
          'os_error_code': osErrorCode,
      };

  static void validate(
    Map<String, Object?> attributes,
    ObservabilityPrivacyClass privacyClass,
  ) {
    if (attributes.length > 12) {
      throw ArgumentError.value(attributes.length, 'attributes');
    }
    if (attributes.containsKey('http_64k_observation') && (attributes['failure_kind'] != 'probe_failed' ||
        attributes['probe_stage'] != 'http_64k' ||
        !const {'body_short', 'body_read_error'}.contains(attributes['http_64k_failure']))) {
      throw ArgumentError('HTTP64 observation requires a failed body read');
    }
    final allowedForMode = switch (privacyClass) {
      ObservabilityPrivacyClass.releaseHealth => _releaseHealthKeys,
      ObservabilityPrivacyClass.serverSecurityAudit => _serverAuditKeys,
      ObservabilityPrivacyClass.localOperational ||
      ObservabilityPrivacyClass.supportBundle =>
        ObservabilityAttributeKeys.allowed,
    };
    for (final entry in attributes.entries) {
      if (!ObservabilityAttributeKeys.allowed.contains(entry.key) ||
          !allowedForMode.contains(entry.key)) {
        throw ArgumentError.value(
          entry.key,
          'attributes',
          'Field is not allowed',
        );
      }
      _validateValue(entry.key, entry.value);
    }
  }

  static void _validateValue(String key, Object? value) {
    if (key == 'http_64k_observation') {
      if (candidateHTTP64KObservation(value) == null) throw ArgumentError('Invalid HTTP64 observation');
      return;
    }
    if (_booleanKeys.contains(key)) {
      if (value is! bool) {
        throw ArgumentError.value(value, key, 'Boolean required');
      }
      return;
    }
    if (_integerKeys.contains(key)) {
      if (value is! int || value < 0) {
        throw ArgumentError.value(value, key, 'Non-negative integer required');
      }
      if (key == 'effective_mtu' && (value < 576 || value > 9000)) {
        throw ArgumentError.value(value, key, 'MTU outside contract');
      }
      if (key == 'http_status' && (value < 100 || value > 599)) {
        throw ArgumentError.value(value, key, 'HTTP status outside contract');
      }
      if ((key == 'duration_ms' || key == 'retry_after_ms') &&
          value > 86400000) {
        throw ArgumentError.value(value, key, 'Duration outside contract');
      }
      if (key == 'retry_count' && value > 100) {
        throw ArgumentError.value(value, key, 'Retry count outside contract');
      }
      if (key == 'selected_app_count' && value > 128) {
        throw ArgumentError.value(
          value,
          key,
          'Selected app count outside contract',
        );
      }
      if (key == 'bundle_item_count' && value > 1000) {
        throw ArgumentError.value(
          value,
          key,
          'Bundle item count outside contract',
        );
      }
      if (key == 'bundle_size_bytes' && value > 268435456) {
        throw ArgumentError.value(value, key, 'Bundle size outside contract');
      }
      if (key == 'retention_days' && value > 365) {
        throw ArgumentError.value(value, key, 'Retention outside contract');
      }
      return;
    }
    if (value is! String) {
      throw ArgumentError.value(value, key, 'String required');
    }
    final enumValues = _enums[key];
    if (enumValues != null) {
      if (!enumValues.contains(value)) {
        throw ArgumentError.value(value, key, 'Unknown enum value');
      }
      return;
    }
    final valid = switch (key) {
      'manifest_version' ||
      'contract_version' ||
      'from_version' ||
      'to_version' =>
        _versionPattern.hasMatch(value),
      'contract_sha256' => _shaPattern.hasMatch(value),
      'crash_signature' => _signaturePattern.hasMatch(value),
      _ => false,
    };
    if (!valid) {
      throw ArgumentError.value(value, key, 'Value is outside contract');
    }
  }
}

abstract final class OperationalPrivacyGuard {
  static final _forbiddenPatterns = <RegExp>[
    RegExp(r'-----BEGIN [A-Z ]+-----', caseSensitive: false),
    RegExp(r'\b(?:Bearer|Basic)\s+[A-Za-z0-9._~-]{8,}', caseSensitive: false),
    RegExp(r'\b(?:ss|trojan|vless|vmess|wg)://', caseSensitive: false),
    RegExp(r'\bsk-[A-Za-z0-9_-]{20,}\b'),
    RegExp(r'\beyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.'),
    RegExp(
      r'"(?:authorization|cookie|request_body|response_body|raw_config|private_key)"\s*:',
      caseSensitive: false,
    ),
    RegExp(r'\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b'),
    RegExp(r'\b[A-Za-z]:\\[^"\r\n]+'),
    RegExp(r'/(?:home|Users|etc|var)/[^"\r\n]+', caseSensitive: false),
  ];

  static bool containsForbiddenMaterial(String value) =>
      _forbiddenPatterns.any((pattern) => pattern.hasMatch(value));

  static void validateSerialized(String value) {
    if (containsForbiddenMaterial(value)) {
      throw const FormatException('forbidden_operational_material');
    }
  }

  static String sanitizePath(String _) => '<local-path>';

  static String sanitizeLocalIdentity(String _) => '<local>';

  static String safeConfigFingerprint(
    String rawJson, {
    int maxBytes = 1048576,
  }) {
    final bytes = utf8.encode(rawJson);
    if (bytes.length > maxBytes) {
      throw const FormatException('config_fingerprint_input_too_large');
    }
    final decoded = jsonDecode(rawJson);
    final canonical = jsonEncode(_canonicalize(decoded));
    return sha256.convert(utf8.encode(canonical)).toString();
  }

  static Object? _canonicalize(Object? value) {
    if (value is Map) {
      final keys = value.keys.map((key) => key.toString()).toList()..sort();
      return <String, Object?>{
        for (final key in keys) key: _canonicalize(value[key]),
      };
    }
    if (value is List) {
      return value.map(_canonicalize).toList(growable: false);
    }
    if (value == null || value is bool || value is num || value is String) {
      return value;
    }
    throw const FormatException('config_fingerprint_value_unsupported');
  }
}
