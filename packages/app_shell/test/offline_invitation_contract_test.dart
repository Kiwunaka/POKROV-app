import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/offline_invitation_contract.dart';

List<int> _hex(String value) => [for (var i = 0; i < value.length; i += 2)
  int.parse(value.substring(i, i + 2), radix: 16)];
String _b64(List<int> bytes) => base64Url.encode(bytes).replaceAll('=', '');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<String, dynamic> vector;
  late FlutterSecureStoragePlatform originalStorage;
  setUp(() async {
    originalStorage = FlutterSecureStoragePlatform.instance;
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(<String, String>{});
    vector = jsonDecode(await File('test/fixtures/offline-invitation.v1.vector.json').readAsString()) as Map<String, dynamic>;
  });
  tearDown(() => FlutterSecureStoragePlatform.instance = originalStorage);

  Future<OfflineInvitationReceiver> recipient({List<int>? deliverySeed, List<int>? nonce,
      DateTime? now}) async {
    final seeds = vector['seeds'] as Map;
    final body = vector['request']['payload'] as Map;
    final issuer = await Ed25519().newKeyPairFromSeed(_hex(seeds['issuer_private_hex'] as String));
    final receiver = OfflineInvitationReceiver(
      trust: OfflineInvitationTrust(audience: 'production', issuerPublicKeys: {
        vector['envelope']['key_id'] as String: _b64((await issuer.extractPublicKey()).bytes),
      }), clock: () => now ?? DateTime.fromMillisecondsSinceEpoch(
          (vector['envelope']['issued_at'] as int) * 1000 + 1000, isUtc: true));
    final request = await receiver.createRequest(installId: body['install_id'] as String,
      platform: body['platform'] as String, consent: true,
      clientRelease: body['client_release'] as String, coreRelease: body['core_release'] as String,
      runtimeFeatures: (body['runtime_features'] as List).cast<String>(), routeMode: body['route_mode'] as String,
      operationIsCurrent: () => true,
      proofKeyPair: await Ed25519().newKeyPairFromSeed(_hex(seeds['proof_private_hex'] as String)),
      deliveryKeyPair: await X25519().newKeyPairFromSeed(deliverySeed ?? _hex(seeds['delivery_private_hex'] as String)),
      nonce: nonce ?? base64Url.decode(base64Url.normalize(body['request_nonce'] as String)));
    if (deliverySeed == null && nonce == null) expect(request.toJson(), vector['request']);
    return receiver;
  }

  Future<VerifiedOfflineInvitation> import(OfflineInvitationReceiver receiver,
      {Map<String, dynamic>? packet}) => receiver.importPacket(
      platform: vector['request']['payload']['platform'] as String,
      installId: vector['request']['payload']['install_id'] as String,
      packet: canonicalInvitationJson(packet ?? vector['envelope']), operationIsCurrent: () => true);

  test('Python invitation vector verifies decrypts and consumes idempotently for its recipient', () async {
    final receiver = await recipient();
    final verified = await import(receiver);
    expect(verified.recipient, vector['plaintext']);
    expect((verified.recipient['session'] as Map)['access_token'].toString().length, greaterThan(256),
        reason: 'the real synthetic issuer token must not use the short identifier limit');
    expect((await import(receiver)).inviteId, verified.inviteId);
    expect((await receiver.open(platform: verified.request['platform'] as String,
        installId: verified.request['install_id'] as String))?.inviteId, verified.inviteId);
    expect(canonicalInvitationJson({'text': 'П😀'}), r'{"text":"\u041f\ud83d\ude00"}');
  });

  test('copied invitation rejects another key request expiry and signature before acceptance', () async {
    final wrongKey = await recipient(deliverySeed: List.filled(32, 7));
    await expectLater(import(wrongKey), throwsA(isA<OfflineInvitationFailure>()
        .having((error) => error.code, 'code', 'recipient_mismatch')));
    final wrongRequest = await recipient(nonce: List.filled(32, 9));
    await expectLater(import(wrongRequest), throwsA(isA<OfflineInvitationFailure>()
        .having((error) => error.code, 'code', 'recipient_mismatch')));
    final expired = await recipient(now: DateTime.fromMillisecondsSinceEpoch(
        (vector['envelope']['expires_at'] as int) * 1000, isUtc: true));
    await expectLater(import(expired), throwsA(isA<OfflineInvitationFailure>()
        .having((error) => error.code, 'code', 'expired')));
    final current = await recipient();
    final packet = Map<String, dynamic>.from(vector['envelope'] as Map);
    final signature = base64Url.decode(base64Url.normalize(packet['signature'] as String));
    signature[0] ^= 1;
    packet['signature'] = _b64(signature);
    await expectLater(import(current, packet: packet), throwsA(isA<OfflineInvitationFailure>()
        .having((error) => error.code, 'code', 'signature_invalid')));
  });
}
