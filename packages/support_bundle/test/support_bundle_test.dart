import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_diagnostics_collectors/diagnostics_collectors.dart';
import 'package:pokrov_support_bundle/support_bundle.dart';

void main() {
  final now = DateTime.utc(2026, 8, 21, 12);

  test(
    'signed recipient encrypts exact preview contents without plaintext',
    () async {
      final signing = Ed25519();
      final signingPair = await signing.newKeyPair();
      final signingPublic = await signingPair.extractPublicKey();
      final recipientAgreement = X25519();
      final recipientPair = await recipientAgreement.newKeyPair();
      final recipientPublic = await recipientPair.extractPublicKey();
      final verifier = SupportSignedContractVerifier(
        signingPublicKeysById: <String, String>{
          'root-test': _b64(signingPublic.bytes),
        },
      );
      final keySet = await verifier.verifyKeySet(
        await _signed(signing, signingPair, <String, Object?>{
          'expires_at': now.add(const Duration(days: 7)).toIso8601String(),
          'issued_at':
              now.subtract(const Duration(minutes: 1)).toIso8601String(),
          'keys': <Object?>[
            <String, Object?>{
              'algorithm': 'X25519-HKDF-SHA256-AES-256-GCM',
              'key_id': 'support-test-1',
              'not_after': now.add(const Duration(days: 6)).toIso8601String(),
              'public_key_b64': _b64(recipientPublic.bytes),
            },
          ],
          'schema_version': 1,
          'type': 'pokrov.support.key_set',
        }),
        now: now,
      );
      final prepared = const SupportBundleBuilder().prepare(
        snapshot: _snapshot(),
        profile: SupportDiagnosticProfile.crash,
        now: now,
      );
      final encrypted = await prepared.encrypt(
        recipient: keySet.activeRecipient(now),
        now: now,
      );
      final rendered = utf8.decode(encrypted.bytes);

      final recipient = keySet.activeRecipient(now);
      final recipientBytes = recipient.publicKeyBytes;
      final signedFirstByte = recipientBytes.first;
      recipientBytes[0] ^= 0xff;
      expect(recipient.publicKeyBytes.first, signedFirstByte);
      final exportedBytes = encrypted.bytes;
      final encryptedFirstByte = exportedBytes.first;
      exportedBytes[0] ^= 0xff;
      expect(encrypted.bytes.first, encryptedFirstByte);

      expect(rendered, isNot(contains('degraded')));
      expect(rendered, isNot(contains('EGRESS-001')));
      expect(encrypted.suggestedFileName, endsWith('.pokrov-support'));

      final envelope = jsonDecode(rendered) as Map<String, dynamic>;
      final shared = await recipientAgreement.sharedSecretKey(
        keyPair: recipientPair,
        remotePublicKey: SimplePublicKey(
          _decode(envelope['ephemeral_public_key_b64'] as String),
          type: KeyPairType.x25519,
        ),
      );
      final key = await Hkdf(hmac: Hmac.sha256(), outputLength: 32).deriveKey(
        secretKey: shared,
        nonce: utf8.encode(prepared.preview.diagnosticId),
        info: utf8.encode('pokrov-support-bundle-v1'),
      );
      final plaintext = await AesGcm.with256bits().decrypt(
        SecretBox(
          _decode(envelope['ciphertext_b64'] as String),
          nonce: _decode(envelope['nonce_b64'] as String),
          mac: Mac(_decode(envelope['mac_b64'] as String)),
        ),
        secretKey: key,
        aad: utf8.encode(prepared.manifestSha256),
      );
      final payload =
          jsonDecode(utf8.decode(plaintext)) as Map<String, dynamic>;
      final manifest = payload['manifest'] as Map<String, dynamic>;
      final files = manifest['files'] as List<dynamic>;
      expect(manifest['diagnostic_id'], prepared.preview.diagnosticId);
      expect(files.length, prepared.preview.files.length);
      expect(
        files.map((raw) => (raw as Map<String, dynamic>)['path']),
        prepared.preview.files.map((file) => file.path),
      );
    },
  );

  test('planted request material blocks output before encryption', () {
    final hostile = _snapshot(
      system: DiagnosticSystemSummary(
        osFamily: 'windows',
        osVersion: 'Bearer planted-secret',
        architecture: 'x64',
        locale: 'ru-RU',
      ),
    );
    expect(
      () => const SupportBundleBuilder().prepare(
        snapshot: hostile,
        profile: SupportDiagnosticProfile.standard,
        now: now,
      ),
      throwsA(
        isA<SupportBundleFailure>().having(
          (error) => error.code,
          'code',
          'forbidden_content',
        ),
      ),
    );
  });

  test('planted hostname blocks output before encryption', () {
    final hostile = _snapshot(
      system: DiagnosticSystemSummary(
        osFamily: 'windows',
        osVersion: 'internal-gateway.example.net',
        architecture: 'x64',
        locale: 'ru-RU',
      ),
    );
    expect(
      () => const SupportBundleBuilder().prepare(
        snapshot: hostile,
        profile: SupportDiagnosticProfile.standard,
        now: now,
      ),
      throwsA(
        isA<SupportBundleFailure>().having(
          (error) => error.code,
          'code',
          'forbidden_content',
        ),
      ),
    );
  });

  test('raw legacy configuration marker blocks output', () {
    final hostile = _snapshot(
      system: DiagnosticSystemSummary(
        osFamily: 'windows',
        osVersion: 'outbounds legacy material',
        architecture: 'x64',
        locale: 'ru-RU',
      ),
    );
    expect(
      () => const SupportBundleBuilder().prepare(
        snapshot: hostile,
        profile: SupportDiagnosticProfile.standard,
        now: now,
      ),
      throwsA(
        isA<SupportBundleFailure>().having(
          (error) => error.code,
          'code',
          'forbidden_content',
        ),
      ),
    );
  });

  test('tampered signed contracts and oversized TTL fail closed', () async {
    final signing = Ed25519();
    final pair = await signing.newKeyPair();
    final public = await pair.extractPublicKey();
    final verifier = SupportSignedContractVerifier(
      signingPublicKeysById: <String, String>{'root-test': _b64(public.bytes)},
    );
    final envelope = await _signed(
      signing,
      pair,
      _collectionPolicyPayload(
        now: now,
        expiresAt: now.add(const Duration(minutes: 31)),
      ),
    );
    await expectLater(
      verifier.verifyCollectionPolicy(
        envelope,
        now: now,
        platform: 'windows',
        appVersion: '1.2.0+30',
        buildNumber: 'candidate-test',
      ),
      throwsA(isA<SupportBundleFailure>()),
    );
    envelope['payload_b64'] = '${envelope['payload_b64']}A';
    await expectLater(
      verifier.verifyCollectionPolicy(
        envelope,
        now: now,
        platform: 'windows',
        appVersion: '1.2.0+30',
        buildNumber: 'candidate-test',
      ),
      throwsA(isA<SupportBundleFailure>()),
    );
  });

}

Future<Map<String, Object?>> _signed(
  Ed25519 algorithm,
  SimpleKeyPair keyPair,
  Map<String, Object?> payload,
) async {
  final bytes = utf8.encode(jsonEncode(payload));
  final signature = await algorithm.sign(bytes, keyPair: keyPair);
  return <String, Object?>{
    'algorithm': 'Ed25519',
    'key_id': 'root-test',
    'payload_b64': _b64(bytes),
    'schema_version': 1,
    'signature_b64': _b64(signature.bytes),
  };
}

Map<String, Object?> _collectionPolicyPayload({
  required DateTime now,
  DateTime? expiresAt,
  int maximumBundleBytes = 1024 * 1024,
  int maximumTotalBytes = 2 * 1024 * 1024,
  int maximumBundles = 2,
}) =>
    <String, Object?>{
      'allowed_categories':
          DiagnosticCategory.values.map((category) => category.name).toList(),
      'allowed_collectors': const <String>[
        'build_summary',
        'crash_index',
        'network_summary',
        'operational_events',
        'redaction_report',
        'system_summary',
      ],
      'audience': const <String, Object?>{
        'app_version': '1.2.0+30',
        'build_number': 'candidate-test',
        'platform': 'windows',
      },
      'expires_at':
          (expiresAt ?? now.add(const Duration(minutes: 20))).toIso8601String(),
      'issued_at': now.toIso8601String(),
      'maximum_bundle_bytes': maximumBundleBytes,
      'maximum_bundles': maximumBundles,
      'maximum_total_bytes': maximumTotalBytes,
      'nonce': 'AAAAAAAAAAAAAAAAAAAAAA',
      'policy_id': 'spol-0123456789abcdef01234567',
      'profile': 'extended',
      'schema_version': 2,
      'type': 'pokrov.support.collection_policy',
    };

DiagnosticSnapshot _snapshot({
  DiagnosticSystemSummary? system,
  List<DiagnosticEventRecord>? events,
}) =>
    DiagnosticSnapshot(
      build: DiagnosticBuildSummary(
        platform: 'windows',
        appVersion: '1.2.0+30',
        buildId: 'candidate-test',
        channel: 'stable',
      ),
      system: system ??
          DiagnosticSystemSummary(
            osFamily: 'windows',
            osVersion: '11 24H2',
            architecture: 'x64',
            locale: 'ru-RU',
          ),
      network: DiagnosticNetworkSummary(
        routeMode: 'full_tunnel',
        connectionState: 'degraded',
        hostHealth: 'healthy',
        dnsState: 'healthy',
        egressState: 'failed',
        warpState: 'fallback',
      ),
      events: events ??
          <DiagnosticEventRecord>[
            DiagnosticEventRecord(
              occurredAt: DateTime.utc(2026, 8, 21, 10),
              subsystem: 'connection',
              stage: 'egress',
              outcome: 'failed',
              errorCode: 'EGRESS-001',
              durationMs: 1200,
            ),
          ],
      crashes: <DiagnosticCrashRecord>[
        DiagnosticCrashRecord(
          occurredAt: DateTime.utc(2026, 8, 21, 9),
          errorCode: 'CRASH-001',
          signature: '0123456789abcdef',
        ),
      ],
      removalCounts: const <DiagnosticRemovalReason, int>{
        DiagnosticRemovalReason.forbiddenField: 2,
      },
    );

String _b64(List<int> value) => base64UrlEncode(value).replaceAll('=', '');

List<int> _decode(String value) =>
    base64Url.decode('$value${'=' * ((4 - value.length % 4) % 4)}');
