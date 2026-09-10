import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:pokrov_app_shell/app_first_runtime_bootstrap.dart';
import 'package:pokrov_core_domain/core_domain.dart';
import 'package:pokrov_diagnostics_collectors/diagnostics_collectors.dart';
import 'package:pokrov_support_bundle/support_bundle.dart';

void main() {
  final now = DateTime.utc(2026, 8, 21, 12);

  test('restarted service completes saved ciphertext without a fresh preview or key',
      () async {
    final temporary = await Directory.systemTemp.createTemp('pokrov-retry-');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final previousSecureStorage = FlutterSecureStoragePlatform.instance;
    FlutterSecureStoragePlatform.instance =
        TestFlutterSecureStoragePlatform(<String, String>{});
    addTearDown(() async {
      FlutterSecureStoragePlatform.instance = previousSecureStorage;
      await server.close(force: true);
      await temporary.delete(recursive: true);
    });
    final prepared = const SupportBundleBuilder().prepare(
      snapshot: _snapshot(),
      profile: SupportDiagnosticProfile.summary,
      now: now,
    );
    final encrypted = await prepared.encrypt(
      recipient: await _recipient(now),
      now: now,
    );
    final oldOutbox = PokrovFileSupportBundleOutbox(
      directoryResolver: () async => temporary,
    );
    final saved = await oldOutbox.save(encrypted);
    final checksum = (await Sha256().hash(saved.bytes)).bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    final paths = <String>[];
    Map<String, dynamic>? issuedRequest;
    const uploadId = '01234567-89ab-4cde-8fab-0123456789ab';
    unawaited(() async {
      await for (final request in server) {
        final body = await utf8.decoder.bind(request).join();
        final path = request.uri.path;
        paths.add(path);
        request.response.headers.contentType = ContentType.json;
        if (path == '/api/client/session/start-trial') {
          request.response.write(jsonEncode({
            'session': {
              'session_token': 'retry-fixture-session',
              'account_id': 'retry-fixture-account',
            },
            'provisioning': {'status': 'ready', 'sync_ok': true},
          }));
        } else if (path == '/api/client/support/bundles/upload-tickets') {
          issuedRequest = jsonDecode(body) as Map<String, dynamic>;
          expect(request.headers.value(HttpHeaders.authorizationHeader),
              'Bearer retry-fixture-session');
          request.response.write(jsonEncode({
            'upload_id': uploadId,
            'upload_ticket': 'fixture-upload-ticket',
            'ticket_id': 56,
            'next_offset': saved.bytes.length,
            'status': 'uploading',
          }));
        } else if (path == '/api/client/support/bundles/uploads/$uploadId/complete') {
          request.response.write('{"status":"queued"}');
        } else {
          request.response.statusCode = 404;
          request.response.write('{}');
        }
        await request.response.close();
      }
    }());
    final restarted = AppFirstSupportTicketService(
      apiBaseUrl: 'http://127.0.0.1:${server.port}',
      supportDirectoryResolver: () async => temporary,
      supportSigningPublicKeysById: const {'old-root': 'not-needed-for-retry'},
      maxRequestAttempts: 1,
      delayScheduler: (_) async {},
    );
    expect(await restarted.listPendingSupportBundles(), [saved.diagnosticId]);
    final result = await restarted.retrySupportBundle(
      hostPlatform: HostPlatform.windows,
      diagnosticId: saved.diagnosticId,
    );
    expect(result.state, SupportBundleDeliveryState.queued);
    expect(result.ticketId, 56);
    expect(result.diagnosticId, saved.diagnosticId);
    expect(issuedRequest?['bundle_id'], saved.diagnosticId);
    expect(issuedRequest?['sha256'], checksum);
    expect(issuedRequest?['size_bytes'], saved.bytes.length);
    expect(issuedRequest?['idempotency_key'],
        'bundle-${saved.diagnosticId.substring(5)}-${checksum.substring(0, 16)}');
    expect(paths, [
      '/api/client/session/start-trial',
      '/api/client/support/bundles/upload-tickets',
      '/api/client/support/bundles/uploads/$uploadId/complete',
    ]);
    expect(await restarted.listPendingSupportBundles(), isEmpty);
    expect(await File(saved.reference).exists(), isFalse);
  });

  test('file outbox stores and restores only the encrypted envelope', () async {
    final temporary = await Directory.systemTemp.createTemp('pokrov-outbox-');
    addTearDown(() => temporary.delete(recursive: true));
    final recipient = await _recipient(now);
    final prepared = const SupportBundleBuilder().prepare(
      snapshot: _snapshot(),
      profile: SupportDiagnosticProfile.summary,
      now: now,
    );
    final encrypted = await prepared.encrypt(recipient: recipient, now: now);
    final outbox = PokrovFileSupportBundleOutbox(
      directoryResolver: () async => temporary,
    );

    final stored = await outbox.save(encrypted);
    final restored = await outbox.load(prepared.preview.diagnosticId);
    final rendered = utf8.decode(restored!.bytes);

    expect(stored.reference, endsWith('.pokrov-support'));
    expect(restored.bytes, encrypted.bytes);
    expect(rendered, contains('ciphertext_b64'));
    expect(rendered, isNot(contains('connection_state')));
    expect(rendered, isNot(contains('files')));
    expect(
      temporary.listSync(recursive: true).whereType<File>().length,
      1,
    );

    await File('${stored.reference}.next').writeAsString('interrupted fixture');
    await File('${File(stored.reference).parent.path}/other.pokrov-support')
        .writeAsString('unrelated fixture');
    expect(await outbox.listDiagnosticIds(), [stored.diagnosticId]);

    await outbox.remove(restored);
    expect(await outbox.load(prepared.preview.diagnosticId), isNull);
    expect(await outbox.listDiagnosticIds(), isEmpty);
  });

  test('full outbox preserves retries and bounds concurrent admission',
      () async {
    final temporary =
        await Directory.systemTemp.createTemp('pokrov-outbox-cap-');
    addTearDown(() => temporary.delete(recursive: true));
    final recipient = await _recipient(now);
    final bundles = <EncryptedSupportBundle>[];
    for (final buildId in ['candidate-a', 'candidate-b']) {
      bundles.add(await const SupportBundleBuilder()
          .prepare(
              snapshot: _snapshot(buildId: buildId),
              profile: SupportDiagnosticProfile.summary,
              now: now)
          .encrypt(recipient: recipient, now: now));
    }
    final first = PokrovFileSupportBundleOutbox(
      directoryResolver: () async => temporary,
    );
    final second = PokrovFileSupportBundleOutbox(
      directoryResolver: () async => temporary,
    );
    final root = Directory('${temporary.path}/support-bundle-outbox');
    await root.create();
    // An interrupted write still occupies capacity and must not be purged.
    final interrupted = File('${root.path}/retained.pokrov-support.next');
    final available = bundles.map((b) => b.bytes.length).reduce(
          (a, b) => a > b ? a : b,
        );
    final handle = await interrupted.open(mode: FileMode.write);
    await handle.truncate(24 * 1024 * 1024 - available);
    await handle.close();
    final preservedLength = await interrupted.length();
    final outcomes = await Future.wait<Object>([
      first.save(bundles[0]).then<Object>((v) => v, onError: (Object e) => e),
      second.save(bundles[1]).then<Object>((v) => v, onError: (Object e) => e),
    ]);
    final stored = outcomes.whereType<StoredEncryptedSupportBundle>().single;
    final failure = outcomes.whereType<SupportBundleTransferFailure>().single;
    expect(failure.code, 'outbox_full');
    final accepted =
        bundles.singleWhere((b) => b.diagnosticId == stored.diagnosticId);
    final rejected =
        bundles.singleWhere((b) => b.diagnosticId != stored.diagnosticId);
    expect((await second.save(accepted)).bytes, accepted.bytes);
    expect(await first.load(rejected.diagnosticId), isNull);
    final files =
        await root.list().where((e) => e is File).cast<File>().toList();
    var totalBytes = 0;
    for (final file in files) {
      totalBytes += await file.length();
    }
    expect(totalBytes, lessThanOrEqualTo(24 * 1024 * 1024));
    expect(await interrupted.length(), preservedLength);
    expect(files, hasLength(2));
    await first.remove(stored);
    expect((await second.save(rejected)).bytes, rejected.bytes);
    expect(await interrupted.length(), preservedLength);
  });

  test('file outbox rejects planted plaintext and build pin stays explicit',
      () async {
    final temporary = await Directory.systemTemp.createTemp('pokrov-outbox-');
    addTearDown(() => temporary.delete(recursive: true));
    final diagnosticId = 'diag-0123456789abcdef01234567';
    final root = Directory('${temporary.path}/support-bundle-outbox');
    await root.create(recursive: true);
    await File('${root.path}/$diagnosticId.pokrov-support').writeAsString(
      '{"diagnostic_id":"$diagnosticId","files":["plaintext"]}',
      flush: true,
    );
    final outbox = PokrovFileSupportBundleOutbox(
      directoryResolver: () async => temporary,
    );

    await expectLater(
      outbox.load(diagnosticId),
      throwsA(isA<SupportBundleTransferFailure>()),
    );
    expect(
      AppFirstSupportTicketService(
        supportDirectoryResolver: () async => temporary,
      ).supportBundleEncryptionConfigured,
      isFalse,
    );
    expect(
      AppFirstSupportTicketService(
        supportDirectoryResolver: () async => temporary,
        supportSigningPublicKeysById: const <String, String>{
          'root-test': 'explicit-build-pin',
        },
      ).supportBundleEncryptionConfigured,
      isTrue,
    );
  });

  test('file outbox rejects an encrypted envelope with unknown fields',
      () async {
    final temporary = await Directory.systemTemp.createTemp('pokrov-outbox-');
    addTearDown(() => temporary.delete(recursive: true));
    final now = DateTime.utc(2026, 8, 21, 12);
    final recipient = await _recipient(now);
    final prepared = SupportBundleBuilder().prepare(
      snapshot: _snapshot(),
      profile: SupportDiagnosticProfile.summary,
      now: now,
    );
    final encrypted = await prepared.encrypt(recipient: recipient, now: now);
    final outbox = PokrovFileSupportBundleOutbox(
      directoryResolver: () async => temporary,
    );
    final stored = await outbox.save(encrypted);
    final tampered =
        jsonDecode(utf8.decode(stored.bytes)) as Map<String, dynamic>;
    tampered['files'] = <String>['plaintext'];
    await File(stored.reference)
        .writeAsString(jsonEncode(tampered), flush: true);

    await expectLater(
      outbox.load(prepared.preview.diagnosticId),
      throwsA(isA<SupportBundleTransferFailure>()),
    );
  });

  test('manual export destination receives only an encrypted container',
      () async {
    final temporary = await Directory.systemTemp.createTemp('pokrov-export-');
    addTearDown(() => temporary.delete(recursive: true));
    final exportNow = DateTime.now().toUtc();
    final fixture = await _keySetFixture(exportNow);
    await File(
      '${temporary.path}${Platform.pathSeparator}support-key-set-v1.json',
    ).writeAsString(jsonEncode(fixture.envelope), flush: true);
    final destination = _RecordingExportDestination();
    final service = AppFirstSupportTicketService(
      apiBaseUrl: 'http://127.0.0.1:1/',
      supportDirectoryResolver: () async => temporary,
      supportSigningPublicKeysById: <String, String>{
        'root-test': fixture.signingPublicKey,
      },
      supportBundleExportDestination: destination,
      maxRequestAttempts: 1,
      connectionTimeout: const Duration(milliseconds: 100),
      requestTimeout: const Duration(milliseconds: 100),
    );
    final prepared = const SupportBundleBuilder().prepare(
      snapshot: _snapshot(),
      profile: SupportDiagnosticProfile.summary,
      now: exportNow,
    );

    final result = await service.exportSupportBundle(
      hostPlatform: HostPlatform.windows,
      prepared: prepared,
    );

    final exported = destination.bundle;
    expect(result.state, SupportBundleExportState.exported);
    expect(result.fileName, '${prepared.preview.diagnosticId}.pokrov-support');
    expect(destination.platform, HostPlatform.windows);
    expect(exported, isNotNull);
    final decoded = jsonDecode(utf8.decode(exported!.bytes)) as Map;
    expect(decoded['algorithm'], 'X25519-HKDF-SHA256-AES-256-GCM');
    expect(decoded['diagnostic_id'], prepared.preview.diagnosticId);
    expect(decoded['ciphertext_b64'], isNotEmpty);
    expect(decoded, isNot(contains('files')));
    expect(decoded, isNot(contains('connection_state')));
  });
}

Future<VerifiedSupportRecipient> _recipient(DateTime now) async {
  return (await _keySetFixture(now)).recipient;
}

Future<
    ({
      Map<String, Object?> envelope,
      String signingPublicKey,
      VerifiedSupportRecipient recipient,
    })> _keySetFixture(DateTime now) async {
  final signing = Ed25519();
  final signingPair = await signing.newKeyPair();
  final signingPublic = await signingPair.extractPublicKey();
  final recipientPair = await X25519().newKeyPair();
  final recipientPublic = await recipientPair.extractPublicKey();
  final payload = <String, Object?>{
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
  };
  final payloadBytes = utf8.encode(jsonEncode(payload));
  final signature = await signing.sign(payloadBytes, keyPair: signingPair);
  final signingPublicKey = _b64(signingPublic.bytes);
  final envelope = <String, Object?>{
    'algorithm': 'Ed25519',
    'key_id': 'root-test',
    'payload_b64': _b64(payloadBytes),
    'schema_version': 1,
    'signature_b64': _b64(signature.bytes),
  };
  final keySet = await SupportSignedContractVerifier(
    signingPublicKeysById: <String, String>{
      'root-test': signingPublicKey,
    },
  ).verifyKeySet(
    envelope,
    now: now,
  );
  return (
    envelope: envelope,
    signingPublicKey: signingPublicKey,
    recipient: keySet.activeRecipient(now),
  );
}

DiagnosticSnapshot _snapshot({String buildId = 'candidate-test'}) =>
    DiagnosticSnapshot(
      build: DiagnosticBuildSummary(
        platform: 'windows',
        appVersion: '1.2.0',
        buildId: buildId,
        channel: 'stable',
      ),
      network: DiagnosticNetworkSummary(
        routeMode: 'all_except_ru',
        connectionState: 'degraded',
        hostHealth: 'healthy',
        dnsState: 'healthy',
        egressState: 'failed',
        warpState: 'fallback',
      ),
    );

String _b64(List<int> value) => base64UrlEncode(value).replaceAll('=', '');

final class _RecordingExportDestination
    implements SupportBundleExportDestination {
  HostPlatform? platform;
  EncryptedSupportBundle? bundle;

  @override
  Future<bool> save({
    required HostPlatform hostPlatform,
    required EncryptedSupportBundle bundle,
  }) async {
    platform = hostPlatform;
    this.bundle = bundle;
    return true;
  }
}
