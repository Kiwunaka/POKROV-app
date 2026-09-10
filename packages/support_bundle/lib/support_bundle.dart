library pokrov_support_bundle;

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as hashes;
import 'package:cryptography/cryptography.dart';
import 'package:pokrov_diagnostics_collectors/diagnostics_collectors.dart';

final class SupportBundleFailure implements Exception {
  const SupportBundleFailure(this.code);

  final String code;

  @override
  String toString() => 'SupportBundleFailure($code)';
}

final class SupportBundlePreviewFile {
  const SupportBundlePreviewFile({
    required this.path,
    required this.category,
    required this.size,
    required this.sha256,
  });

  final String path;
  final DiagnosticCategory category;
  final int size;
  final String sha256;
}

final class SupportBundlePreview {
  SupportBundlePreview({
    required this.diagnosticId,
    required this.profile,
    required List<SupportBundlePreviewFile> files,
    required List<DiagnosticCategory> categories,
    required this.totalPlaintextBytes,
    required this.removedFieldCount,
  })  : files = List<SupportBundlePreviewFile>.unmodifiable(files),
        categories = List<DiagnosticCategory>.unmodifiable(categories);

  final String diagnosticId;
  final SupportDiagnosticProfile profile;
  final List<SupportBundlePreviewFile> files;
  final List<DiagnosticCategory> categories;
  final int totalPlaintextBytes;
  final int removedFieldCount;
}

final class VerifiedSupportRecipient {
  VerifiedSupportRecipient._({
    required this.keyId,
    required List<int> publicKeyBytes,
    required this.notAfter,
  }) : _publicKeyBytes = Uint8List.fromList(publicKeyBytes) {
    if (!RegExp(r'^[a-z0-9][a-z0-9._-]{2,63}$').hasMatch(keyId) ||
        _publicKeyBytes.length != 32 ||
        !notAfter.isUtc) {
      throw ArgumentError('Support recipient is invalid.');
    }
  }

  final String keyId;
  final Uint8List _publicKeyBytes;
  Uint8List get publicKeyBytes => Uint8List.fromList(_publicKeyBytes);
  final DateTime notAfter;
}

final class VerifiedSupportKeySet {
  VerifiedSupportKeySet._({
    required this.expiresAt,
    required List<VerifiedSupportRecipient> recipients,
  }) : recipients = List<VerifiedSupportRecipient>.unmodifiable(recipients);

  final DateTime expiresAt;
  final List<VerifiedSupportRecipient> recipients;

  VerifiedSupportRecipient activeRecipient(DateTime now) {
    final instant = now.toUtc();
    if (!instant.isBefore(expiresAt)) {
      throw const SupportBundleFailure('support_key_set_expired');
    }
    for (final recipient in recipients) {
      if (instant.isBefore(recipient.notAfter)) {
        return recipient;
      }
    }
    throw const SupportBundleFailure('support_recipient_missing');
  }
}

final class VerifiedSupportCollectionPolicy {
  VerifiedSupportCollectionPolicy._({
    required this.policyId,
    required this.nonce,
    required this.issuedAt,
    required this.expiresAt,
    required this.platform,
    required this.appVersion,
    required this.buildNumber,
    required this.maximumBundleBytes,
    required this.maximumTotalBytes,
    required this.maximumBundles,
    required Set<DiagnosticCategory> allowedCategories,
    required Set<String> allowedCollectors,
  })  : allowedCategories = Set<DiagnosticCategory>.unmodifiable(
          allowedCategories,
        ),
        allowedCollectors = Set<String>.unmodifiable(allowedCollectors);

  final String policyId;
  final String nonce;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final String platform;
  final String appVersion;
  final String buildNumber;
  final int maximumBundleBytes;
  final int maximumTotalBytes;
  final int maximumBundles;
  final Set<DiagnosticCategory> allowedCategories;
  final Set<String> allowedCollectors;
}

const _collectorByCategory = <DiagnosticCategory, String>{
  DiagnosticCategory.build: 'build_summary',
  DiagnosticCategory.crashes: 'crash_index',
  DiagnosticCategory.events: 'operational_events',
  DiagnosticCategory.network: 'network_summary',
  DiagnosticCategory.redaction: 'redaction_report',
  DiagnosticCategory.system: 'system_summary',
};

final class SupportDiagnosticCodeFacts {
  const SupportDiagnosticCodeFacts({
    required this.platform,
    required this.routeMode,
    required this.connectionState,
    required this.appVersion,
    required this.buildNumber,
    required this.diagnosticHashPrefix,
    required this.issuedOn,
    required this.expiresOn,
    required this.expired,
  });

  final String platform;
  final String routeMode;
  final String connectionState;
  final String appVersion;
  final int buildNumber;
  final String diagnosticHashPrefix;
  final DateTime issuedOn;
  final DateTime expiresOn;
  final bool expired;
}

abstract final class SupportDiagnosticCode {
  static const _alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
  static const _routeModes = <String>[
    'full_tunnel',
    'all_except_ru',
    'selected_apps',
    'excluded_apps',
  ];
  static const _connectionStates = <String>[
    'disconnected',
    'connecting',
    'verified',
    'degraded',
    'blocked',
  ];
  static final _epoch = DateTime.utc(2020);

  static String encode({
    required String diagnosticId,
    required String platform,
    required String routeMode,
    required String connectionState,
    required String appVersion,
    required DateTime generatedAt,
  }) {
    final id = RegExp(r'^diag-([0-9a-f]{24})$').firstMatch(diagnosticId);
    final version =
        RegExp(r'^(\d+)\.(\d+)\.(\d+)\+(\d+)$').firstMatch(appVersion);
    final platformIndex = switch (platform) {
      'android' => 0,
      'windows' => 1,
      _ => -1,
    };
    final routeIndex = _routeModes.indexOf(routeMode);
    final stateIndex = _connectionStates.indexOf(connectionState);
    if (id == null ||
        version == null ||
        platformIndex < 0 ||
        routeIndex < 0 ||
        stateIndex < 0) {
      throw const SupportBundleFailure('support_diagnostic_code_invalid');
    }
    final versionParts = <int>[
      for (var index = 1; index <= 3; index++)
        int.tryParse(version.group(index)!) ?? -1,
    ];
    final buildNumber = int.tryParse(version.group(4)!) ?? -1;
    if (versionParts.any((value) => value < 0 || value > 255) ||
        buildNumber < 0 ||
        buildNumber > 0x7fffffff) {
      throw const SupportBundleFailure('support_diagnostic_code_invalid');
    }
    final issued = DateTime.utc(
      generatedAt.toUtc().year,
      generatedAt.toUtc().month,
      generatedAt.toUtc().day,
    );
    final days = issued.difference(_epoch).inDays;
    if (days < 0 || days > 0xffff) {
      throw const SupportBundleFailure('support_diagnostic_code_invalid');
    }
    final hash = id.group(1)!;
    final legacy = buildNumber <= 0xff;
    final raw = <int>[
      (platformIndex << 5) | (routeIndex << 3) | stateIndex,
      (days >> 8) & 0xff,
      days & 0xff,
      ...versionParts,
      if (legacy)
        buildNumber
      else ...<int>[
        (buildNumber >> 24) & 0xff,
        (buildNumber >> 16) & 0xff,
        (buildNumber >> 8) & 0xff,
        buildNumber & 0xff,
      ],
      int.parse(hash.substring(0, 2), radix: 16),
      int.parse(hash.substring(2, 4), radix: 16),
    ];
    raw.add(_crc8(raw));
    final body = _encodeCrockford(raw);
    if (legacy) {
      return 'PSD1-${body.substring(0, 4)}-${body.substring(4, 8)}-'
          '${body.substring(8, 12)}-${body.substring(12, 16)}';
    }
    return 'PSD2-${body.substring(0, 4)}-${body.substring(4, 8)}-'
        '${body.substring(8, 12)}-${body.substring(12, 16)}-'
        '${body.substring(16, 21)}';
  }

  static SupportDiagnosticCodeFacts decode(
    String value, {
    required DateTime now,
  }) {
    final rawCode = value.toUpperCase().replaceAll(RegExp(r'[\s-]+'), '');
    final legacy =
        RegExp(r'^PSD1[0-9A-HJKMNPQRSTVWXYZ]{16}$').hasMatch(rawCode);
    final extended =
        RegExp(r'^PSD2[0-9A-HJKMNPQRSTVWXYZ]{21}$').hasMatch(rawCode);
    if (!legacy && !extended) {
      throw const SupportBundleFailure('support_diagnostic_code_invalid');
    }
    final packed = _decodeCrockford(rawCode.substring(4));
    final expectedLength = legacy ? 10 : 13;
    if (packed.length != expectedLength ||
        _crc8(packed.sublist(0, expectedLength - 1)) != packed.last) {
      throw const SupportBundleFailure('support_diagnostic_code_invalid');
    }
    final facts = packed[0];
    final platformIndex = (facts >> 5) & 1;
    final routeIndex = (facts >> 3) & 3;
    final stateIndex = facts & 7;
    if (stateIndex >= _connectionStates.length) {
      throw const SupportBundleFailure('support_diagnostic_code_invalid');
    }
    final issuedOn = _epoch.add(
      Duration(days: (packed[1] << 8) | packed[2]),
    );
    final expiresOn = issuedOn.add(const Duration(days: 14));
    final current = DateTime.utc(
      now.toUtc().year,
      now.toUtc().month,
      now.toUtc().day,
    );
    final buildNumber = legacy
        ? packed[6]
        : (packed[6] << 24) | (packed[7] << 16) | (packed[8] << 8) | packed[9];
    final hashIndex = legacy ? 7 : 10;
    return SupportDiagnosticCodeFacts(
      platform: const <String>['android', 'windows'][platformIndex],
      routeMode: _routeModes[routeIndex],
      connectionState: _connectionStates[stateIndex],
      appVersion: '${packed[3]}.${packed[4]}.${packed[5]}',
      buildNumber: buildNumber,
      diagnosticHashPrefix:
          '${packed[hashIndex].toRadixString(16).padLeft(2, '0')}'
          '${packed[hashIndex + 1].toRadixString(16).padLeft(2, '0')}',
      issuedOn: issuedOn,
      expiresOn: expiresOn,
      expired: current.isAfter(expiresOn),
    );
  }

  static String _encodeCrockford(List<int> bytes) {
    var accumulator = 0;
    var bits = 0;
    final output = StringBuffer();
    for (final byte in bytes) {
      accumulator = (accumulator << 8) | byte;
      bits += 8;
      while (bits >= 5) {
        bits -= 5;
        output.write(_alphabet[(accumulator >> bits) & 31]);
        accumulator &= (1 << bits) - 1;
      }
    }
    if (bits != 0) {
      output.write(_alphabet[(accumulator << (5 - bits)) & 31]);
    }
    return output.toString();
  }

  static List<int> _decodeCrockford(String value) {
    var accumulator = 0;
    var bits = 0;
    final output = <int>[];
    for (final char in value.split('')) {
      final digit = _alphabet.indexOf(char);
      if (digit < 0) {
        throw const SupportBundleFailure('support_diagnostic_code_invalid');
      }
      accumulator = (accumulator << 5) | digit;
      bits += 5;
      while (bits >= 8) {
        bits -= 8;
        output.add((accumulator >> bits) & 0xff);
        accumulator &= (1 << bits) - 1;
      }
    }
    if (bits != 0 && accumulator != 0) {
      throw const SupportBundleFailure('support_diagnostic_code_invalid');
    }
    return output;
  }

  static int _crc8(List<int> bytes) {
    var crc = 0;
    for (final byte in bytes) {
      crc ^= byte;
      for (var bit = 0; bit < 8; bit++) {
        crc = crc & 0x80 != 0 ? ((crc << 1) ^ 0x07) & 0xff : (crc << 1) & 0xff;
      }
    }
    return crc;
  }
}

final class SupportModeUsageLedger {
  SupportModeUsageLedger({
    required this.policy,
    int consumedBytes = 0,
    Iterable<String> consumedDiagnosticIds = const <String>[],
    bool disabled = false,
  })  : _consumedBytes = consumedBytes,
        _consumedDiagnosticIds = <String>{...consumedDiagnosticIds},
        _disabled = disabled {
    if (_consumedBytes < 0 ||
        _consumedBytes > policy.maximumTotalBytes ||
        _consumedDiagnosticIds.length > policy.maximumBundles ||
        _consumedDiagnosticIds.any(
          (value) => !RegExp(r'^diag-[0-9a-f]{24}$').hasMatch(value),
        )) {
      throw const SupportBundleFailure('support_mode_usage_invalid');
    }
  }

  final VerifiedSupportCollectionPolicy policy;
  int _consumedBytes;
  final Set<String> _consumedDiagnosticIds;
  bool _disabled;

  int get consumedBytes => _consumedBytes;
  int get consumedBundles => _consumedDiagnosticIds.length;
  Set<String> get consumedDiagnosticIds =>
      Set<String>.unmodifiable(_consumedDiagnosticIds);
  bool get disabled => _disabled;

  bool isActive(DateTime now) =>
      !_disabled && now.toUtc().isBefore(policy.expiresAt);

  void register(PreparedSupportBundle prepared, {required DateTime now}) {
    if (!isActive(now)) {
      throw const SupportBundleFailure('support_mode_inactive');
    }
    if (prepared.preview.profile != SupportDiagnosticProfile.extended) {
      throw const SupportBundleFailure('support_mode_profile_invalid');
    }
    final diagnosticId = prepared.preview.diagnosticId;
    if (_consumedDiagnosticIds.contains(diagnosticId)) {
      return;
    }
    final bytes = prepared.preview.totalPlaintextBytes;
    if (_consumedDiagnosticIds.length >= policy.maximumBundles ||
        _consumedBytes + bytes > policy.maximumTotalBytes) {
      throw const SupportBundleFailure('support_mode_volume_exhausted');
    }
    _consumedDiagnosticIds.add(diagnosticId);
    _consumedBytes += bytes;
  }

  void disable() {
    _disabled = true;
  }
}

final class SupportSignedContractVerifier {
  SupportSignedContractVerifier({
    required Map<String, String> signingPublicKeysById,
    Ed25519? signatureAlgorithm,
  })  : _signingPublicKeysById = Map<String, String>.unmodifiable(
          signingPublicKeysById,
        ),
        _signatureAlgorithm = signatureAlgorithm ?? Ed25519();

  final Map<String, String> _signingPublicKeysById;
  final Ed25519 _signatureAlgorithm;

  Future<VerifiedSupportKeySet> verifyKeySet(
    Map<String, Object?> envelope, {
    required DateTime now,
  }) async {
    final payload = await _verifiedPayload(envelope, maximumBytes: 16 * 1024);
    _expectKeys(
        payload,
        <String>{
          'expires_at',
          'issued_at',
          'keys',
          'schema_version',
          'type',
        },
        'support_key_set_shape_invalid');
    if (payload['type'] != 'pokrov.support.key_set' ||
        payload['schema_version'] != 1) {
      throw const SupportBundleFailure('support_key_set_version_invalid');
    }
    final issuedAt = _utc(payload['issued_at'], 'support_key_set_time_invalid');
    final expiresAt = _utc(
      payload['expires_at'],
      'support_key_set_time_invalid',
    );
    final instant = now.toUtc();
    if (issuedAt.isAfter(instant.add(const Duration(minutes: 5))) ||
        !expiresAt.isAfter(instant) ||
        expiresAt.difference(issuedAt) > const Duration(days: 31)) {
      throw const SupportBundleFailure('support_key_set_time_invalid');
    }
    final rawKeys = payload['keys'];
    if (rawKeys is! List || rawKeys.isEmpty || rawKeys.length > 8) {
      throw const SupportBundleFailure('support_key_set_keys_invalid');
    }
    final recipients = <VerifiedSupportRecipient>[];
    final seen = <String>{};
    for (final raw in rawKeys) {
      final key = _objectMap(raw, 'support_key_invalid');
      _expectKeys(
          key,
          <String>{
            'algorithm',
            'key_id',
            'not_after',
            'public_key_b64',
          },
          'support_key_invalid');
      final keyId = _text(key['key_id']);
      if (!seen.add(keyId) ||
          key['algorithm'] != 'X25519-HKDF-SHA256-AES-256-GCM') {
        throw const SupportBundleFailure('support_key_invalid');
      }
      final notAfter = _utc(key['not_after'], 'support_key_invalid');
      if (notAfter.isAfter(expiresAt) || !notAfter.isAfter(instant)) {
        throw const SupportBundleFailure('support_key_invalid');
      }
      recipients.add(
        VerifiedSupportRecipient._(
          keyId: keyId,
          publicKeyBytes: _base64Url(
            key['public_key_b64'],
            exactBytes: 32,
            code: 'support_key_invalid',
          ),
          notAfter: notAfter,
        ),
      );
    }
    recipients.sort((left, right) => left.keyId.compareTo(right.keyId));
    return VerifiedSupportKeySet._(
      expiresAt: expiresAt,
      recipients: recipients,
    );
  }

  Future<VerifiedSupportCollectionPolicy> verifyCollectionPolicy(
    Map<String, Object?> envelope, {
    required DateTime now,
    required String platform,
    required String appVersion,
    required String buildNumber,
  }) async {
    final payload = await _verifiedPayload(envelope, maximumBytes: 8 * 1024);
    _expectKeys(
        payload,
        <String>{
          'allowed_categories',
          'allowed_collectors',
          'audience',
          'expires_at',
          'issued_at',
          'maximum_bundle_bytes',
          'maximum_bundles',
          'maximum_total_bytes',
          'nonce',
          'policy_id',
          'profile',
          'schema_version',
          'type',
        },
        'support_policy_shape_invalid');
    if (payload['type'] != 'pokrov.support.collection_policy' ||
        payload['schema_version'] != 2 ||
        payload['profile'] != 'extended') {
      throw const SupportBundleFailure('support_policy_version_invalid');
    }
    final instant = now.toUtc();
    final issuedAt = _utc(payload['issued_at'], 'support_policy_time_invalid');
    final expiresAt = _utc(
      payload['expires_at'],
      'support_policy_time_invalid',
    );
    if (issuedAt.isAfter(instant.add(const Duration(minutes: 1))) ||
        !expiresAt.isAfter(instant) ||
        expiresAt.difference(issuedAt) > const Duration(minutes: 30)) {
      throw const SupportBundleFailure('support_policy_time_invalid');
    }
    final policyId = _text(payload['policy_id']);
    if (!RegExp(r'^spol-[0-9a-f]{24}$').hasMatch(policyId)) {
      throw const SupportBundleFailure('support_policy_id_invalid');
    }
    final nonce = _text(payload['nonce']);
    if (!RegExp(r'^[A-Za-z0-9_-]{22}$').hasMatch(nonce)) {
      throw const SupportBundleFailure('support_policy_nonce_invalid');
    }
    final audience = _objectMap(
      payload['audience'],
      'support_policy_audience_invalid',
    );
    _expectKeys(
      audience,
      <String>{'app_version', 'build_number', 'platform'},
      'support_policy_audience_invalid',
    );
    final policyPlatform = _text(audience['platform']);
    final policyAppVersion = _text(audience['app_version']);
    final policyBuildNumber = _text(audience['build_number']);
    if ((policyPlatform != 'android' && policyPlatform != 'windows') ||
        !RegExp(r'^[0-9]+\.[0-9]+\.[0-9]+(?:\+[0-9]+)?$')
            .hasMatch(policyAppVersion) ||
        !RegExp(r'^[A-Za-z0-9][A-Za-z0-9._+-]{0,79}$')
            .hasMatch(policyBuildNumber) ||
        policyPlatform != platform ||
        policyAppVersion != appVersion ||
        policyBuildNumber != buildNumber) {
      throw const SupportBundleFailure('support_policy_audience_invalid');
    }
    final maximumBundleBytes = payload['maximum_bundle_bytes'];
    if (maximumBundleBytes is! int ||
        maximumBundleBytes < 64 * 1024 ||
        maximumBundleBytes > 2 * 1024 * 1024) {
      throw const SupportBundleFailure('support_policy_budget_invalid');
    }
    final maximumTotalBytes = payload['maximum_total_bytes'];
    final maximumBundles = payload['maximum_bundles'];
    if (maximumTotalBytes is! int ||
        maximumTotalBytes < maximumBundleBytes ||
        maximumTotalBytes > 4 * 1024 * 1024 ||
        maximumBundles is! int ||
        maximumBundles < 1 ||
        maximumBundles > 2) {
      throw const SupportBundleFailure('support_policy_budget_invalid');
    }
    final rawCategories = payload['allowed_categories'];
    if (rawCategories is! List || rawCategories.isEmpty) {
      throw const SupportBundleFailure('support_policy_categories_invalid');
    }
    final categories = <DiagnosticCategory>{};
    for (final raw in rawCategories) {
      final name = _text(raw);
      final category = DiagnosticCategory.values
          .where((candidate) => candidate.name == name)
          .firstOrNull;
      if (category == null || !categories.add(category)) {
        throw const SupportBundleFailure('support_policy_categories_invalid');
      }
    }
    final rawCollectors = payload['allowed_collectors'];
    if (rawCollectors is! List || rawCollectors.isEmpty) {
      throw const SupportBundleFailure('support_policy_collectors_invalid');
    }
    final collectors = <String>{};
    for (final raw in rawCollectors) {
      final collector = _text(raw);
      if (!_collectorByCategory.values.contains(collector) ||
          !collectors.add(collector)) {
        throw const SupportBundleFailure('support_policy_collectors_invalid');
      }
    }
    final expectedCollectors =
        categories.map((category) => _collectorByCategory[category]!).toSet();
    if (collectors.length != expectedCollectors.length ||
        !collectors.containsAll(expectedCollectors)) {
      throw const SupportBundleFailure('support_policy_collectors_invalid');
    }
    return VerifiedSupportCollectionPolicy._(
      policyId: policyId,
      nonce: nonce,
      issuedAt: issuedAt,
      expiresAt: expiresAt,
      platform: policyPlatform,
      appVersion: policyAppVersion,
      buildNumber: policyBuildNumber,
      maximumBundleBytes: maximumBundleBytes,
      maximumTotalBytes: maximumTotalBytes,
      maximumBundles: maximumBundles,
      allowedCategories: categories,
      allowedCollectors: collectors,
    );
  }

  Future<Map<String, Object?>> _verifiedPayload(
    Map<String, Object?> envelope, {
    required int maximumBytes,
  }) async {
    _expectKeys(
        envelope,
        <String>{
          'algorithm',
          'key_id',
          'payload_b64',
          'schema_version',
          'signature_b64',
        },
        'support_signed_envelope_invalid');
    if (envelope['schema_version'] != 1 || envelope['algorithm'] != 'Ed25519') {
      throw const SupportBundleFailure('support_signed_envelope_invalid');
    }
    final keyId = _text(envelope['key_id']);
    final publicKeyEncoded = _signingPublicKeysById[keyId];
    if (publicKeyEncoded == null) {
      throw const SupportBundleFailure('support_signing_key_unknown');
    }
    final payloadBytes = _base64Url(
      envelope['payload_b64'],
      maximumBytes: maximumBytes,
      code: 'support_signed_payload_invalid',
    );
    final signatureBytes = _base64Url(
      envelope['signature_b64'],
      exactBytes: 64,
      code: 'support_signature_invalid',
    );
    final publicKeyBytes = _base64Url(
      publicKeyEncoded,
      exactBytes: 32,
      code: 'support_signing_key_invalid',
    );
    final verified = await _signatureAlgorithm.verify(
      payloadBytes,
      signature: Signature(
        signatureBytes,
        publicKey: SimplePublicKey(publicKeyBytes, type: KeyPairType.ed25519),
      ),
    );
    if (!verified) {
      throw const SupportBundleFailure('support_signature_invalid');
    }
    try {
      return _objectMap(
        jsonDecode(utf8.decode(payloadBytes)),
        'support_signed_payload_invalid',
      );
    } on SupportBundleFailure {
      rethrow;
    } on Object {
      throw const SupportBundleFailure('support_signed_payload_invalid');
    }
  }
}

final class PreparedSupportBundle {
  PreparedSupportBundle._({
    required this.preview,
    required Uint8List payload,
    required this.manifestSha256,
  }) : _payload = Uint8List.fromList(payload);

  final SupportBundlePreview preview;
  final Uint8List _payload;
  final String manifestSha256;

  Future<EncryptedSupportBundle> encrypt({
    required VerifiedSupportRecipient recipient,
    required DateTime now,
    X25519? keyAgreement,
    Hkdf? keyDerivation,
    AesGcm? cipher,
  }) async {
    if (!now.toUtc().isBefore(recipient.notAfter)) {
      throw const SupportBundleFailure('support_recipient_expired');
    }
    final agreement = keyAgreement ?? X25519();
    final ephemeralKeyPair = await agreement.newKeyPair();
    final ephemeralPublicKey = await ephemeralKeyPair.extractPublicKey();
    final sharedSecret = await agreement.sharedSecretKey(
      keyPair: ephemeralKeyPair,
      remotePublicKey: SimplePublicKey(
        recipient.publicKeyBytes,
        type: KeyPairType.x25519,
      ),
    );
    final derivation =
        keyDerivation ?? Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    final encryptionKey = await derivation.deriveKey(
      secretKey: sharedSecret,
      nonce: utf8.encode(preview.diagnosticId),
      info: utf8.encode('pokrov-support-bundle-v1'),
    );
    final aead = cipher ?? AesGcm.with256bits();
    final box = await aead.encrypt(
      _payload,
      secretKey: encryptionKey,
      aad: utf8.encode(manifestSha256),
    );
    final envelope = <String, Object?>{
      'algorithm': 'X25519-HKDF-SHA256-AES-256-GCM',
      'bundle_sha256': _sha256(_payload),
      'ciphertext_b64': _encodeBase64Url(box.cipherText),
      'diagnostic_id': preview.diagnosticId,
      'ephemeral_public_key_b64': _encodeBase64Url(ephemeralPublicKey.bytes),
      'mac_b64': _encodeBase64Url(box.mac.bytes),
      'manifest_sha256': manifestSha256,
      'nonce_b64': _encodeBase64Url(box.nonce),
      'recipient_key_id': recipient.keyId,
      'schema_version': 1,
    };
    final bytes = Uint8List.fromList(utf8.encode(_canonicalJson(envelope)));
    if (utf8.decode(bytes).contains('connection_state')) {
      throw const SupportBundleFailure('plaintext_export_detected');
    }
    return EncryptedSupportBundle._(
      diagnosticId: preview.diagnosticId,
      recipientKeyId: recipient.keyId,
      bytes: bytes,
    );
  }
}

final class EncryptedSupportBundle {
  EncryptedSupportBundle._({
    required this.diagnosticId,
    required this.recipientKeyId,
    required Uint8List bytes,
  }) : _bytes = Uint8List.fromList(bytes);

  final String diagnosticId;
  final String recipientKeyId;
  final Uint8List _bytes;
  Uint8List get bytes => Uint8List.fromList(_bytes);

  String get suggestedFileName => '$diagnosticId.pokrov-support';
}

enum SupportBundleDeliveryState { queued, offlineEncrypted }

enum SupportBundleExportState { exported, cancelled }

final class SupportBundleExportResult {
  const SupportBundleExportResult({
    required this.state,
    required this.fileName,
  });

  final SupportBundleExportState state;
  final String fileName;
}

final class SupportBundleDeliveryResult {
  const SupportBundleDeliveryResult({
    required this.state,
    required this.diagnosticId,
    required this.outboxReference,
    this.ticketId,
    this.failureCode,
  });

  final SupportBundleDeliveryState state;
  final String diagnosticId;
  final String outboxReference;
  final int? ticketId;
  final String? failureCode;
}

final class StoredEncryptedSupportBundle {
  StoredEncryptedSupportBundle({
    required this.diagnosticId,
    required this.reference,
    required List<int> bytes,
  }) : bytes = Uint8List.fromList(bytes);

  final String diagnosticId;
  final String reference;
  final Uint8List bytes;
}

abstract interface class SupportBundleEncryptedOutbox {
  Future<List<String>> listDiagnosticIds();

  Future<StoredEncryptedSupportBundle?> load(String diagnosticId);

  Future<StoredEncryptedSupportBundle> save(EncryptedSupportBundle bundle);

  Future<void> remove(StoredEncryptedSupportBundle stored);
}

final class SupportBundleUploadRequest {
  SupportBundleUploadRequest({
    required this.idempotencyKey,
    required this.bundleId,
    required this.sizeBytes,
    required this.sha256,
    required this.contentType,
    required this.caseSummary,
    this.ticketId,
  });

  final String idempotencyKey;
  final String bundleId;
  final int sizeBytes;
  final String sha256;
  final String contentType;
  final String caseSummary;
  final int? ticketId;
}

final class SupportBundleUploadTicket {
  const SupportBundleUploadTicket({
    required this.uploadId,
    required this.uploadTicket,
    required this.ticketId,
    required this.nextOffset,
    required this.status,
  });

  final String uploadId;
  final String uploadTicket;
  final int ticketId;
  final int nextOffset;
  final String status;
}

final class SupportBundleChunkReceipt {
  const SupportBundleChunkReceipt({
    required this.nextOffset,
    required this.complete,
  });

  final int nextOffset;
  final bool complete;
}

abstract interface class SupportBundleUploadTransport {
  Future<SupportBundleUploadTicket> issue(SupportBundleUploadRequest request);

  Future<SupportBundleChunkReceipt> putChunk({
    required SupportBundleUploadTicket ticket,
    required int offset,
    required String sha256,
    required List<int> bytes,
  });

  Future<String> complete(SupportBundleUploadTicket ticket);
}

final class SupportBundleDeliveryCoordinator {
  const SupportBundleDeliveryCoordinator({
    required this.transport,
    required this.outbox,
    this.maximumAttempts = 3,
    this.chunkSizeBytes = 256 * 1024,
    this.delayScheduler = _defaultDeliveryDelay,
  });

  final SupportBundleUploadTransport transport;
  final SupportBundleEncryptedOutbox outbox;
  final int maximumAttempts;
  final int chunkSizeBytes;
  final Future<void> Function(Duration delay) delayScheduler;

  Future<SupportBundleDeliveryResult> deliver({
    required PreparedSupportBundle prepared,
    required VerifiedSupportRecipient? recipient,
    required DateTime now,
    required String caseSummary,
    int? ticketId,
  }) async {
    var stored = await outbox.load(prepared.preview.diagnosticId);
    if (stored == null) {
      if (recipient == null) {
        throw const SupportBundleFailure('support_recipient_required');
      }
      final encrypted = await prepared.encrypt(recipient: recipient, now: now);
      stored = await outbox.save(encrypted);
    }
    return _deliverStored(stored, caseSummary: caseSummary, ticketId: ticketId);
  }

  Future<SupportBundleDeliveryResult> retry({
    required String diagnosticId,
    required String caseSummary,
  }) async {
    final stored = await outbox.load(diagnosticId);
    if (stored == null) {
      throw const SupportBundleFailure('support_saved_bundle_missing');
    }
    return _deliverStored(stored, caseSummary: caseSummary);
  }

  Future<SupportBundleDeliveryResult> _deliverStored(
    StoredEncryptedSupportBundle stored, {
    required String caseSummary,
    int? ticketId,
  }) async {
    final bytes = Uint8List.fromList(stored.bytes);
    final checksum = _sha256(bytes);
    final request = SupportBundleUploadRequest(
      idempotencyKey:
          'bundle-${stored.diagnosticId.substring(5)}-${checksum.substring(0, 16)}',
      bundleId: stored.diagnosticId,
      sizeBytes: bytes.length,
      sha256: checksum,
      contentType: 'application/vnd.pokrov.support-bundle+json',
      caseSummary: caseSummary,
      ticketId: ticketId,
    );
    SupportBundleUploadTicket? lastTicket;
    final attempts = maximumAttempts.clamp(1, 5);
    final chunkSize = chunkSizeBytes.clamp(16 * 1024, 256 * 1024);
    for (var attempt = 0; attempt < attempts; attempt += 1) {
      try {
        final issued = await transport.issue(request);
        lastTicket = issued;
        var offset = issued.nextOffset;
        if (offset < 0 || offset > bytes.length) {
          throw const SupportBundleFailure('upload_offset_invalid');
        }
        if (issued.status == 'validated') {
          await outbox.remove(stored);
          return SupportBundleDeliveryResult(
            state: SupportBundleDeliveryState.queued,
            diagnosticId: stored.diagnosticId,
            outboxReference: stored.reference,
            ticketId: issued.ticketId,
          );
        }
        while (offset < bytes.length) {
          final end = (offset + chunkSize).clamp(0, bytes.length);
          final chunk = Uint8List.sublistView(bytes, offset, end);
          final receipt = await transport.putChunk(
            ticket: issued,
            offset: offset,
            sha256: _sha256(chunk),
            bytes: chunk,
          );
          if (receipt.nextOffset != end) {
            throw const SupportBundleFailure('upload_offset_invalid');
          }
          offset = receipt.nextOffset;
        }
        final status = await transport.complete(issued);
        if (status != 'queued' && status != 'validated') {
          throw const SupportBundleFailure('upload_completion_invalid');
        }
        await outbox.remove(stored);
        return SupportBundleDeliveryResult(
          state: SupportBundleDeliveryState.queued,
          diagnosticId: stored.diagnosticId,
          outboxReference: stored.reference,
          ticketId: issued.ticketId,
        );
      } on Object {
        if (attempt + 1 < attempts) {
          await delayScheduler(Duration(milliseconds: 250 * (attempt + 1)));
          continue;
        }
      }
    }
    return SupportBundleDeliveryResult(
      state: SupportBundleDeliveryState.offlineEncrypted,
      diagnosticId: stored.diagnosticId,
      outboxReference: stored.reference,
      ticketId: lastTicket?.ticketId,
      failureCode: 'upload_deferred',
    );
  }
}

Future<void> _defaultDeliveryDelay(Duration delay) =>
    Future<void>.delayed(delay);

final class SupportBundleBuilder {
  const SupportBundleBuilder({
    this.collector = const BoundedDiagnosticsCollector(),
  });

  final BoundedDiagnosticsCollector collector;

  PreparedSupportBundle prepare({
    required DiagnosticSnapshot snapshot,
    required SupportDiagnosticProfile profile,
    required DateTime now,
    Set<DiagnosticCategory> excludedOptionalCategories =
        const <DiagnosticCategory>{},
    VerifiedSupportCollectionPolicy? extendedPolicy,
  }) {
    final instant = now.toUtc();
    final collection = collector.collect(
      snapshot: snapshot,
      profile: profile,
      excludedOptionalCategories: excludedOptionalCategories,
    );
    final categories = <DiagnosticCategory>{
      for (final file in collection.files) file.category,
    };
    final profileLimit = switch (profile) {
      SupportDiagnosticProfile.summary => 64 * 1024,
      SupportDiagnosticProfile.standard => 512 * 1024,
      SupportDiagnosticProfile.extended => 2 * 1024 * 1024,
      SupportDiagnosticProfile.crash => 512 * 1024,
    };
    var activeLimit = profileLimit;
    if (profile == SupportDiagnosticProfile.extended) {
      final policy = extendedPolicy;
      if (policy == null || !instant.isBefore(policy.expiresAt)) {
        throw const SupportBundleFailure('extended_policy_required');
      }
      if (!policy.allowedCategories.containsAll(categories)) {
        throw const SupportBundleFailure('extended_category_not_allowed');
      }
      final collectors =
          categories.map((category) => _collectorByCategory[category]!).toSet();
      if (!policy.allowedCollectors.containsAll(collectors)) {
        throw const SupportBundleFailure('extended_collector_not_allowed');
      }
      activeLimit = policy.maximumBundleBytes < activeLimit
          ? policy.maximumBundleBytes
          : activeLimit;
    }
    for (final file in collection.files) {
      _scanFile(file);
    }
    final previewFiles = <SupportBundlePreviewFile>[
      for (final file in collection.files)
        SupportBundlePreviewFile(
          path: file.path,
          category: file.category,
          size: file.bytes.length,
          sha256: _sha256(file.bytes),
        ),
    ];
    final manifestCore = <String, Object?>{
      'build': snapshot.build.toJson(),
      'files': <Object?>[
        for (final file in previewFiles)
          <String, Object?>{
            'category': file.category.name,
            'path': file.path,
            'sha256': file.sha256,
            'size': file.size,
          },
      ],
      'profile': profile.name,
      'redaction': <String, Object?>{
        'removed': <String, Object?>{
          for (final reason in DiagnosticRemovalReason.values)
            reason.name: collection.removalCounts[reason] ?? 0,
        },
      },
      'schema_version': 1,
    };
    final contentRoot = _sha256(utf8.encode(_canonicalJson(manifestCore)));
    final diagnosticId = 'diag-${contentRoot.substring(0, 24)}';
    final manifest = <String, Object?>{
      ...manifestCore,
      'diagnostic_id': diagnosticId,
    };
    final manifestBytes = Uint8List.fromList(
      utf8.encode(_canonicalJson(manifest)),
    );
    final payload = Uint8List.fromList(
      utf8.encode(
        _canonicalJson(<String, Object?>{
          'files': <Object?>[
            for (var index = 0; index < collection.files.length; index += 1)
              <String, Object?>{
                'content_b64': _encodeBase64Url(collection.files[index].bytes),
                'path': collection.files[index].path,
              },
          ],
          'manifest': manifest,
          'schema_version': 1,
        }),
      ),
    );
    if (payload.length > activeLimit) {
      throw const SupportBundleFailure('bundle_budget_exceeded');
    }
    final orderedCategories = categories.toList()
      ..sort((left, right) => left.name.compareTo(right.name));
    return PreparedSupportBundle._(
      preview: SupportBundlePreview(
        diagnosticId: diagnosticId,
        profile: profile,
        files: previewFiles,
        categories: orderedCategories,
        totalPlaintextBytes: payload.length,
        removedFieldCount: collection.removalCounts.values.fold<int>(
          0,
          (total, value) => total + value,
        ),
      ),
      payload: payload,
      manifestSha256: _sha256(manifestBytes),
    );
  }
}

void _scanFile(CollectedDiagnosticFile file) {
  if (file.path.startsWith('/') ||
      file.path.startsWith(r'\') ||
      file.path.contains('..') ||
      file.path.contains(r'\') ||
      !RegExp(r'^[a-z0-9_/.-]{1,96}$').hasMatch(file.path)) {
    throw const SupportBundleFailure('unsafe_virtual_path');
  }
  final content = utf8.decode(file.bytes, allowMalformed: false);
  final lowered = content.toLowerCase();
  const forbiddenFragments = <String>{
    '://',
    'access-token',
    'authorization',
    'bearer ',
    'cookie',
    'credential',
    'outbounds',
    'package_name',
    'private-key',
    'refresh_token',
    'server_address',
    'session_token',
  };
  if (forbiddenFragments.any(lowered.contains) ||
      RegExp(r'\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b').hasMatch(content) ||
      RegExp(
        r'\b(?:[a-z0-9-]+\.)+[a-z]{2,63}\b',
        caseSensitive: false,
      ).hasMatch(content) ||
      RegExp(
        r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b',
      ).hasMatch(content)) {
    throw const SupportBundleFailure('forbidden_content');
  }
}

String _canonicalJson(Object? value) {
  if (value == null || value is bool || value is num || value is String) {
    return jsonEncode(value);
  }
  if (value is List) {
    return '[${value.map(_canonicalJson).join(',')}]';
  }
  if (value is Map) {
    final entries = <MapEntry<String, Object?>>[];
    for (final entry in value.entries) {
      if (entry.key is! String) {
        throw const SupportBundleFailure('canonical_json_key_invalid');
      }
      entries.add(MapEntry<String, Object?>(entry.key as String, entry.value));
    }
    entries.sort((left, right) => left.key.compareTo(right.key));
    return '{${entries.map((entry) => '${jsonEncode(entry.key)}:${_canonicalJson(entry.value)}').join(',')}}';
  }
  throw const SupportBundleFailure('canonical_json_value_invalid');
}

String _sha256(List<int> bytes) => hashes.sha256.convert(bytes).toString();

String _encodeBase64Url(List<int> bytes) =>
    base64UrlEncode(bytes).replaceAll('=', '');

Uint8List _base64Url(
  Object? raw, {
  int? exactBytes,
  int? maximumBytes,
  required String code,
}) {
  final value = raw;
  final byteLimit = maximumBytes ?? exactBytes ?? 65536;
  final encodedLimit = ((byteLimit + 2) ~/ 3) * 4;
  if (value is! String ||
      value.trim() != value ||
      value.isEmpty ||
      value.length > encodedLimit ||
      !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(value)) {
    throw SupportBundleFailure(code);
  }
  try {
    final padding = '=' * ((4 - value.length % 4) % 4);
    final decoded = base64Url.decode('$value$padding');
    if ((exactBytes != null && decoded.length != exactBytes) ||
        (maximumBytes != null && decoded.length > maximumBytes)) {
      throw SupportBundleFailure(code);
    }
    return Uint8List.fromList(decoded);
  } on SupportBundleFailure {
    rethrow;
  } on Object {
    throw SupportBundleFailure(code);
  }
}

Map<String, Object?> _objectMap(Object? raw, String code) {
  if (raw is! Map) {
    throw SupportBundleFailure(code);
  }
  final value = <String, Object?>{};
  for (final entry in raw.entries) {
    if (entry.key is! String || value.containsKey(entry.key)) {
      throw SupportBundleFailure(code);
    }
    value[entry.key as String] = entry.value;
  }
  return value;
}

void _expectKeys(
  Map<String, Object?> value,
  Set<String> expected,
  String code,
) {
  if (value.length != expected.length || !expected.every(value.containsKey)) {
    throw SupportBundleFailure(code);
  }
}

String _text(Object? raw) {
  if (raw is! String || raw.trim() != raw || raw.isEmpty || raw.length > 256) {
    throw const SupportBundleFailure('support_text_invalid');
  }
  return raw;
}

DateTime _utc(Object? raw, String code) {
  try {
    final parsed = DateTime.parse(_text(raw));
    if (!parsed.isUtc || parsed.year < 2020 || parsed.year > 2100) {
      throw SupportBundleFailure(code);
    }
    return parsed;
  } on SupportBundleFailure {
    rethrow;
  } on Object {
    throw SupportBundleFailure(code);
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
