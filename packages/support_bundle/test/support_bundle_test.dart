import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_diagnostics_collectors/diagnostics_collectors.dart';
import 'package:pokrov_support_bundle/support_bundle.dart';

void main() {
  final now = DateTime.utc(2026, 8, 21, 12);

  test('same sanitized input produces identical preview manifest hashes', () {
    final first = const SupportBundleBuilder().prepare(
      snapshot: _snapshot(),
      profile: SupportDiagnosticProfile.standard,
      now: now,
    );
    final second = const SupportBundleBuilder().prepare(
      snapshot: _snapshot(),
      profile: SupportDiagnosticProfile.standard,
      now: now,
    );

    expect(first.preview.diagnosticId, second.preview.diagnosticId);
    expect(first.manifestSha256, second.manifestSha256);
    expect(
      first.preview.files.map((file) => file.sha256),
      second.preview.files.map((file) => file.sha256),
    );
    expect(first.preview.removedFieldCount, 2);
  });

  test('standard 1.2.0 bundle manifest matches the retained golden', () {
    final prepared = const SupportBundleBuilder().prepare(
      snapshot: _snapshot(),
      profile: SupportDiagnosticProfile.standard,
      now: now,
    );
    final actual = <String, Object?>{
      'diagnostic_id': prepared.preview.diagnosticId,
      'manifest_sha256': prepared.manifestSha256,
      'total_plaintext_bytes': prepared.preview.totalPlaintextBytes,
      'removed_field_count': prepared.preview.removedFieldCount,
      'categories': prepared.preview.categories
          .map((category) => category.name)
          .toList(growable: false),
      'files': <Object?>[
        for (final file in prepared.preview.files)
          <String, Object?>{
            'path': file.path,
            'category': file.category.name,
            'size': file.size,
            'sha256': file.sha256,
          },
      ],
    };
    expect(actual, <String, Object?>{
      'diagnostic_id': 'diag-f79687ad6970f9d9fb579d41',
      'manifest_sha256':
          '0b9a5427b67783fe9c5edd40fbf0fa17c5ace8046fa45647e45f9f712dd07dc3',
      'total_plaintext_bytes': 2135,
      'removed_field_count': 2,
      'categories': <String>[
        'build',
        'events',
        'network',
        'redaction',
        'system',
      ],
      'files': <Object?>[
        <String, Object?>{
          'path': 'build/identity.json',
          'category': 'build',
          'size': 94,
          'sha256':
              '49327774875c75406ddfd8ddd4554828baacb2cfaa4eba56d55f27c92e064acd',
        },
        <String, Object?>{
          'path': 'events/recent.jsonl',
          'category': 'events',
          'size': 149,
          'sha256':
              '7e488ed777106305e65382a19642492e7745f0bd42f8139969295ff3af1b5742',
        },
        <String, Object?>{
          'path': 'network/summary.json',
          'category': 'network',
          'size': 152,
          'sha256':
              'eaef30ea64a3c0b8b4efd8046107c5c607633b2f09bc30cd7f05953a755058d8',
        },
        <String, Object?>{
          'path': 'redaction/report.json',
          'category': 'redaction',
          'size': 137,
          'sha256':
              '508fca8e660e5326e1ec3f62ebf867b45ffdc573dd91a64b136639ec148302d2',
        },
        <String, Object?>{
          'path': 'system/summary.json',
          'category': 'system',
          'size': 84,
          'sha256':
              '5200f035ddc2d03a233f461b54eacfc558baadcec1ac0759e7403fe45faf9627',
        },
      ],
    });
  });

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

  test('extended profile requires a valid short-lived signed policy', () async {
    expect(
      () => const SupportBundleBuilder().prepare(
        snapshot: _snapshot(),
        profile: SupportDiagnosticProfile.extended,
        now: now,
      ),
      throwsA(
        isA<SupportBundleFailure>().having(
          (error) => error.code,
          'code',
          'extended_policy_required',
        ),
      ),
    );

    final signing = Ed25519();
    final pair = await signing.newKeyPair();
    final public = await pair.extractPublicKey();
    final verifier = SupportSignedContractVerifier(
      signingPublicKeysById: <String, String>{'root-test': _b64(public.bytes)},
    );
    final policy = await verifier.verifyCollectionPolicy(
      await _signed(
        signing,
        pair,
        _collectionPolicyPayload(now: now),
      ),
      now: now,
      platform: 'windows',
      appVersion: '1.2.0+30',
      buildNumber: 'candidate-test',
    );
    final prepared = const SupportBundleBuilder().prepare(
      snapshot: _snapshot(),
      profile: SupportDiagnosticProfile.extended,
      now: now,
      extendedPolicy: policy,
    );
    expect(prepared.preview.profile, SupportDiagnosticProfile.extended);
  });

  test('signed policy byte ceiling blocks an oversized extended bundle',
      () async {
    final signing = Ed25519();
    final pair = await signing.newKeyPair();
    final public = await pair.extractPublicKey();
    final verifier = SupportSignedContractVerifier(
      signingPublicKeysById: <String, String>{'root-test': _b64(public.bytes)},
    );
    final policy = await verifier.verifyCollectionPolicy(
      await _signed(
        signing,
        pair,
        _collectionPolicyPayload(
          now: now,
          maximumBundleBytes: 64 * 1024,
        ),
      ),
      now: now,
      platform: 'windows',
      appVersion: '1.2.0+30',
      buildNumber: 'candidate-test',
    );
    final events = List<DiagnosticEventRecord>.generate(
      1200,
      (index) => DiagnosticEventRecord(
        occurredAt: DateTime.utc(2026, 8, 21, 10).add(
          Duration(milliseconds: index),
        ),
        subsystem: 'connection',
        stage: 'egress',
        outcome: 'failed',
        errorCode: 'EGRESS-001',
        durationMs: index,
      ),
    );

    expect(
      () => const SupportBundleBuilder().prepare(
        snapshot: _snapshot(events: events),
        profile: SupportDiagnosticProfile.extended,
        now: now,
        extendedPolicy: policy,
      ),
      throwsA(
        isA<SupportBundleFailure>().having(
          (error) => error.code,
          'code',
          'bundle_budget_exceeded',
        ),
      ),
    );
  });

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

  test('production bundle code has no plaintext or temp filesystem surface',
      () {
    final source = File('lib/support_bundle.dart').readAsStringSync();

    expect(source, isNot(contains("import 'dart:io'")));
    expect(source, isNot(matches(RegExp(r'\bFile\s*\('))));
    expect(source, isNot(matches(RegExp(r'\bDirectory\s*\('))));
    expect(source, isNot(matches(RegExp(r'\bLink\s*\('))));
    expect(source, isNot(contains('writeAsBytes')));
    expect(source, isNot(contains('.zip')));
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

  test('short diagnostic code is versioned, bounded and cross-language stable',
      () {
    final code = SupportDiagnosticCode.encode(
      diagnosticId: 'diag-abcd0123456789abcdef0123',
      platform: 'windows',
      routeMode: 'selected_apps',
      connectionState: 'degraded',
      appVersion: '1.2.0+30',
      generatedAt: DateTime.utc(2026, 8, 22, 23, 59),
    );
    final decoded = SupportDiagnosticCode.decode(
      code.toLowerCase(),
      now: DateTime.utc(2026, 8, 23),
    );

    expect(code, 'PSD1-6C4Q-J082-00FA-QK8B');
    expect(decoded.platform, 'windows');
    expect(decoded.routeMode, 'selected_apps');
    expect(decoded.connectionState, 'degraded');
    expect(decoded.appVersion, '1.2.0');
    expect(decoded.buildNumber, 30);
    expect(decoded.diagnosticHashPrefix, 'abcd');
    expect(decoded.expired, isFalse);
  });

  test('extended diagnostic code preserves a release-sized build number', () {
    final code = SupportDiagnosticCode.encode(
      diagnosticId: 'diag-abcd0123456789abcdef0123',
      platform: 'android',
      routeMode: 'all_except_ru',
      connectionState: 'verified',
      appVersion: '1.2.0+4046',
      generatedAt: DateTime.utc(2026, 8, 28),
    );
    final decoded = SupportDiagnosticCode.decode(
      code.toLowerCase(),
      now: DateTime.utc(2026, 8, 28),
    );

    expect(code, startsWith('PSD2-'));
    expect(code.length, 30);
    expect(decoded.platform, 'android');
    expect(decoded.routeMode, 'all_except_ru');
    expect(decoded.connectionState, 'verified');
    expect(decoded.appVersion, '1.2.0');
    expect(decoded.buildNumber, 4046);
    expect(decoded.diagnosticHashPrefix, 'abcd');
    expect(decoded.expired, isFalse);
  });

  test('support mode usage enforces cumulative bytes, count and hard expiry',
      () async {
    final signing = Ed25519();
    final pair = await signing.newKeyPair();
    final public = await pair.extractPublicKey();
    final verifier = SupportSignedContractVerifier(
      signingPublicKeysById: <String, String>{'root-test': _b64(public.bytes)},
    );
    final policy = await verifier.verifyCollectionPolicy(
      await _signed(
        signing,
        pair,
        _collectionPolicyPayload(
          now: now,
          maximumTotalBytes: 2 * 1024 * 1024,
          maximumBundles: 1,
        ),
      ),
      now: now,
      platform: 'windows',
      appVersion: '1.2.0+30',
      buildNumber: 'candidate-test',
    );
    final prepared = const SupportBundleBuilder().prepare(
      snapshot: _snapshot(),
      profile: SupportDiagnosticProfile.extended,
      now: now,
      extendedPolicy: policy,
    );
    final ledger = SupportModeUsageLedger(policy: policy);

    ledger.register(prepared, now: now);
    ledger.register(prepared, now: now);
    expect(ledger.consumedBundles, 1);
    expect(ledger.consumedBytes, prepared.preview.totalPlaintextBytes);
    expect(
      () => ledger.register(
        const SupportBundleBuilder().prepare(
          snapshot: _snapshot(
            system: DiagnosticSystemSummary(
              osFamily: 'windows',
              osVersion: '11 24H2',
              architecture: 'arm64',
              locale: 'ru-RU',
            ),
          ),
          profile: SupportDiagnosticProfile.extended,
          now: now,
          extendedPolicy: policy,
        ),
        now: now,
      ),
      throwsA(
        isA<SupportBundleFailure>().having(
          (error) => error.code,
          'code',
          'support_mode_volume_exhausted',
        ),
      ),
    );
    expect(
      () => ledger.register(
        prepared,
        now: policy.expiresAt,
      ),
      throwsA(isA<SupportBundleFailure>()),
    );
  });

  test('delivery resumes after an accepted chunk loses its response', () async {
    final recipient = await _verifiedRecipient(now);
    final prepared = const SupportBundleBuilder().prepare(
      snapshot: _snapshot(),
      profile: SupportDiagnosticProfile.summary,
      now: now,
    );
    final outbox = _FakeEncryptedOutbox();
    final transport = _FakeUploadTransport(failAfterFirstAcceptedChunk: true);
    final result = await SupportBundleDeliveryCoordinator(
      transport: transport,
      outbox: outbox,
      delayScheduler: (_) async {},
    ).deliver(
      prepared: prepared,
      recipient: recipient,
      now: now,
      caseSummary: 'Версия 1.2.0; Windows; код CORE-START-01.',
    );

    expect(result.state, SupportBundleDeliveryState.queued);
    expect(result.ticketId, 701);
    expect(transport.issueCalls, 2);
    expect(transport.putCalls, 1);
    expect(transport.completeCalls, 1);
    expect(outbox.saveCalls, 1);
    expect(outbox.removeCalls, 1);
    expect(outbox.stored, isNull);
  });

  test('offline delivery retains one encrypted outbox object for retry',
      () async {
    final recipient = await _verifiedRecipient(now);
    final prepared = const SupportBundleBuilder().prepare(
      snapshot: _snapshot(),
      profile: SupportDiagnosticProfile.summary,
      now: now,
    );
    final outbox = _FakeEncryptedOutbox();
    final offline = _FakeUploadTransport(alwaysOffline: true);
    final first = await SupportBundleDeliveryCoordinator(
      transport: offline,
      outbox: outbox,
      maximumAttempts: 2,
      delayScheduler: (_) async {},
    ).deliver(
      prepared: prepared,
      recipient: recipient,
      now: now,
      caseSummary: 'Версия 1.2.0; Windows; код CORE-START-01.',
    );

    expect(first.state, SupportBundleDeliveryState.offlineEncrypted);
    expect(first.failureCode, 'upload_deferred');
    expect(outbox.stored?.reference, endsWith('.pokrov-support'));
    expect(outbox.saveCalls, 1);
    expect(outbox.removeCalls, 0);
    final retainedBytes = List<int>.from(outbox.stored!.bytes);

    final resumed = _FakeUploadTransport();
    final second = await SupportBundleDeliveryCoordinator(
      transport: resumed,
      outbox: outbox,
      delayScheduler: (_) async {},
    ).deliver(
      prepared: prepared,
      recipient: recipient,
      now: now,
      caseSummary: 'Версия 1.2.0; Windows; код CORE-START-01.',
    );

    expect(second.state, SupportBundleDeliveryState.queued);
    expect(outbox.saveCalls, 1);
    expect(outbox.removeCalls, 1);
    expect(resumed.receivedBytes, retainedBytes);
  });
}

Future<VerifiedSupportRecipient> _verifiedRecipient(DateTime now) async {
  final signing = Ed25519();
  final signingPair = await signing.newKeyPair();
  final signingPublic = await signingPair.extractPublicKey();
  final recipientPair = await X25519().newKeyPair();
  final recipientPublic = await recipientPair.extractPublicKey();
  final verifier = SupportSignedContractVerifier(
    signingPublicKeysById: <String, String>{
      'root-test': _b64(signingPublic.bytes),
    },
  );
  final keySet = await verifier.verifyKeySet(
    await _signed(signing, signingPair, <String, Object?>{
      'expires_at': now.add(const Duration(days: 7)).toIso8601String(),
      'issued_at': now.subtract(const Duration(minutes: 1)).toIso8601String(),
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
  return keySet.activeRecipient(now);
}

final class _FakeEncryptedOutbox implements SupportBundleEncryptedOutbox {
  StoredEncryptedSupportBundle? stored;
  int saveCalls = 0;
  int removeCalls = 0;

  @override
  Future<StoredEncryptedSupportBundle?> load(String diagnosticId) async {
    final value = stored;
    return value?.diagnosticId == diagnosticId ? value : null;
  }

  @override
  Future<StoredEncryptedSupportBundle> save(
      EncryptedSupportBundle bundle) async {
    saveCalls += 1;
    stored = StoredEncryptedSupportBundle(
      diagnosticId: bundle.diagnosticId,
      reference: bundle.suggestedFileName,
      bytes: bundle.bytes,
    );
    return stored!;
  }

  @override
  Future<void> remove(StoredEncryptedSupportBundle stored) async {
    removeCalls += 1;
    this.stored = null;
  }
}

final class _FakeUploadTransport implements SupportBundleUploadTransport {
  _FakeUploadTransport({
    this.failAfterFirstAcceptedChunk = false,
    this.alwaysOffline = false,
  });

  final bool failAfterFirstAcceptedChunk;
  final bool alwaysOffline;
  int issueCalls = 0;
  int putCalls = 0;
  int completeCalls = 0;
  int serverOffset = 0;
  bool _lostResponse = false;
  final List<int> receivedBytes = <int>[];

  @override
  Future<SupportBundleUploadTicket> issue(
    SupportBundleUploadRequest request,
  ) async {
    issueCalls += 1;
    if (alwaysOffline) {
      throw StateError('offline');
    }
    return SupportBundleUploadTicket(
      uploadId: '01234567-89ab-4def-8123-456789abcdef',
      uploadTicket: 'signed-ticket',
      ticketId: 701,
      nextOffset: serverOffset,
      status: 'uploading',
    );
  }

  @override
  Future<SupportBundleChunkReceipt> putChunk({
    required SupportBundleUploadTicket ticket,
    required int offset,
    required String sha256,
    required List<int> bytes,
  }) async {
    putCalls += 1;
    expect(offset, serverOffset);
    receivedBytes.addAll(bytes);
    serverOffset += bytes.length;
    if (failAfterFirstAcceptedChunk && !_lostResponse) {
      _lostResponse = true;
      throw StateError('response lost');
    }
    return SupportBundleChunkReceipt(nextOffset: serverOffset, complete: true);
  }

  @override
  Future<String> complete(SupportBundleUploadTicket ticket) async {
    completeCalls += 1;
    return 'queued';
  }
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
