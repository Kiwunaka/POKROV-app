import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:pokrov_observability_contracts/observability_contracts.dart';

abstract final class OperationalAttributePolicy {
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
  };

  static final _versionPattern = RegExp(
    r'^[0-9]+\.[0-9]+\.[0-9]+(?:[-+][A-Za-z0-9.-]+)?$',
  );
  static final _shaPattern = RegExp(r'^[0-9a-f]{64}$');
  static final _signaturePattern = RegExp(r'^[0-9a-f]{16,64}$');

  static void validate(
    Map<String, Object?> attributes,
    ObservabilityPrivacyClass privacyClass,
  ) {
    if (attributes.length > 12) {
      throw ArgumentError.value(attributes.length, 'attributes');
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
