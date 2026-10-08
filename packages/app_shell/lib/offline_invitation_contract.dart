import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const invitationRequestPurpose = 'pokrov.invitation-request.v1';
const offlineInvitationPurpose = 'pokrov.offline-invitation.v1';

class OfflineInvitationFailure implements Exception {
  const OfflineInvitationFailure(this.code);
  final String code;
  @override
  String toString() => 'offline_invitation_$code';
}

// Matches the issuer's compact, sorted JSON with ensure_ascii=True.
String canonicalInvitationJson(Object? value) {
  if (value is String) {
    final encoded = jsonEncode(value);
    return encoded.codeUnits.map((unit) => unit < 128
        ? String.fromCharCode(unit) : '\\u${unit.toRadixString(16).padLeft(4, '0')}').join();
  }
  if (value == null || value is bool || value is int) return jsonEncode(value);
  if (value is List) return '[${value.map(canonicalInvitationJson).join(',')}]';
  if (value is Map && value.keys.every((key) => key is String)) {
    final keys = value.keys.cast<String>().toList()..sort();
    return '{${keys.map((key) => '${canonicalInvitationJson(key)}:${canonicalInvitationJson(value[key])}').join(',')}}';
  }
  throw const OfflineInvitationFailure('canonical_value_invalid');
}

String _encode(List<int> bytes) => base64Url.encode(bytes).replaceAll('=', '');
List<int> _decode(Object? value, int? size) {
  if (value is! String || !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(value)) {
    throw const OfflineInvitationFailure('encoding_invalid');
  }
  try {
    final bytes = base64Url.decode(base64Url.normalize(value));
    if ((size != null && bytes.length != size) || _encode(bytes) != value) {
      throw const OfflineInvitationFailure('encoding_invalid');
    }
    return bytes;
  } on FormatException {
    throw const OfflineInvitationFailure('encoding_invalid');
  }
}

Future<String> _digest(List<int> bytes) async => (await Sha256().hash(bytes)).bytes
    .map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
List<int> _digestBytes(String value) {
  if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(value)) {
    throw const OfflineInvitationFailure('digest_invalid');
  }
  return [for (var i = 0; i < value.length; i += 2) int.parse(value.substring(i, i + 2), radix: 16)];
}
Map<String, dynamic> _object(Object? value) {
  if (value is! Map<String, dynamic>) throw const OfflineInvitationFailure('object_invalid');
  return value;
}
void _keys(Map<String, dynamic> value, Set<String> keys) {
  if (value.length != keys.length || !value.keys.every(keys.contains)) {
    throw const OfflineInvitationFailure('fields_invalid');
  }
}
String _ascii(Object? value) {
  if (value is! String || value.isEmpty || value.length > 256 ||
      value.codeUnits.any((unit) => unit < 32 || unit > 126)) {
    throw const OfflineInvitationFailure('text_invalid');
  }
  return value;
}
void _token(Object? value) {
  // Normal app-session tokens have no 256-character identifier bound. The
  // authenticated packet's total byte bound also bounds these credentials.
  if (value is! String || !RegExp(r'^[A-Za-z0-9_.-]+$').hasMatch(value)) {
    throw const OfflineInvitationFailure('session_invalid');
  }
}

class OfflineInvitationTrust {
  OfflineInvitationTrust({required this.audience, required Map<String, String> issuerPublicKeys})
      : issuerPublicKeys = Map.unmodifiable(issuerPublicKeys);
  final String audience;
  // These keys authorize invitation purpose only, never support bundles.
  final Map<String, String> issuerPublicKeys;
}

class OfflineInvitationRequest {
  OfflineInvitationRequest._(this._json, this.digest);
  final String _json;
  final String digest;
  Map<String, dynamic> toJson() => _object(jsonDecode(_json));
  @override
  String toString() => 'OfflineInvitationRequest(redacted)';
}

class VerifiedOfflineInvitation {
  VerifiedOfflineInvitation._(this._plaintext, this._request, this.inviteId, this.issuedAt, this.expiresAt);
  final String _plaintext;
  final Map<String, dynamic> _request;
  final String inviteId;
  final DateTime issuedAt;
  final DateTime expiresAt;
  Map<String, dynamic> get recipient => _object(jsonDecode(_plaintext));
  Map<String, dynamic> get request => _object(jsonDecode(canonicalInvitationJson(_request)));
  void requireLive(DateTime now) {
    if (now.toUtc().isBefore(issuedAt) || !now.toUtc().isBefore(expiresAt)) {
      throw const OfflineInvitationFailure('expired');
    }
  }
  @override
  String toString() => 'VerifiedOfflineInvitation(redacted)';
}

class OfflineInvitationReceiver {
  OfflineInvitationReceiver({required this.trust, FlutterSecureStorage? storage,
      DateTime Function()? clock}) : _storage = storage ?? const FlutterSecureStorage(),
      _clock = clock ?? DateTime.now;
  final OfflineInvitationTrust trust;
  final FlutterSecureStorage _storage;
  final DateTime Function() _clock;
  DateTime get now => _clock().toUtc();
  String _key(String platform, String installId) => 'pokrov.offline-invitation.$platform.$installId';

  Future<OfflineInvitationRequest> createRequest({required String installId, required String platform,
      required bool consent, required String clientRelease, required String coreRelease,
      required List<String> runtimeFeatures, required String routeMode,
      required bool Function() operationIsCurrent, SimpleKeyPair? proofKeyPair,
      SimpleKeyPair? deliveryKeyPair, List<int>? nonce}) async {
    if (!consent || !const {'android', 'windows'}.contains(platform)) {
      throw const OfflineInvitationFailure('consent_or_platform_invalid');
    }
    if (routeMode != 'full_tunnel') throw const OfflineInvitationFailure('route_unsupported');
    final proof = proofKeyPair ?? await Ed25519().newKeyPair();
    final delivery = deliveryKeyPair ?? await X25519().newKeyPair();
    final proofPublic = await proof.extractPublicKey();
    final deliveryPublic = await delivery.extractPublicKey();
    final random = Random.secure();
    final requestNonce = nonce ?? List.generate(32, (_) => random.nextInt(256));
    if (requestNonce.length != 32 || proofPublic.type != KeyPairType.ed25519 ||
        deliveryPublic.type != KeyPairType.x25519) throw const OfflineInvitationFailure('keys_invalid');
    final features = runtimeFeatures.toSet().toList()..sort();
    final body = <String, dynamic>{
      'purpose': invitationRequestPurpose, 'install_id': _ascii(installId), 'platform': platform,
      'request_nonce': _encode(requestNonce), 'proof_public_key': _encode(proofPublic.bytes),
      'delivery_public_key': _encode(deliveryPublic.bytes), 'consent': true,
      'client_release': _ascii(clientRelease), 'core_release': _ascii(coreRelease),
      'runtime_features': features.map(_ascii).toList(), 'route_mode': _ascii(routeMode),
    };
    final canonical = canonicalInvitationJson(body);
    final signature = await Ed25519().sign(utf8.encode('$invitationRequestPurpose\n$canonical'), keyPair: proof);
    final request = {'payload': body, 'signature': _encode(signature.bytes)};
    final digest = await _digest(utf8.encode(canonical));
    if (!operationIsCurrent()) throw const OfflineInvitationFailure('superseded');
    await _storage.write(key: _key(platform, installId), value: canonicalInvitationJson({
      'request': request, 'request_digest': digest,
      'proof_private_key': _encode(await proof.extractPrivateKeyBytes()),
      'delivery_private_key': _encode(await delivery.extractPrivateKeyBytes()),
      'accepted_packet': null,
    }));
    if (!operationIsCurrent()) throw const OfflineInvitationFailure('superseded');
    return OfflineInvitationRequest._(canonicalInvitationJson(request), digest);
  }

  Future<Map<String, dynamic>?> _read(String platform, String installId) async {
    final raw = await _storage.read(key: _key(platform, installId));
    return raw == null ? null : _object(jsonDecode(raw));
  }

  Future<VerifiedOfflineInvitation> importPacket({required String platform, required String installId,
      required String packet, required bool Function() operationIsCurrent,
      Future<void> Function(VerifiedOfflineInvitation)? beforeCommit}) async {
    if (packet.length > 1024 * 1024) throw const OfflineInvitationFailure('packet_too_large');
    final value = await _read(platform, installId);
    if (value == null) throw const OfflineInvitationFailure('request_missing');
    final parsed = _object(jsonDecode(packet));
    if (canonicalInvitationJson(parsed) != packet) throw const OfflineInvitationFailure('packet_not_canonical');
    final verified = await _verify(parsed, value, platform, installId);
    if (!operationIsCurrent()) throw const OfflineInvitationFailure('superseded');
    if (value['accepted_packet'] != null && canonicalInvitationJson(value['accepted_packet']) != canonicalInvitationJson(parsed)) {
      throw const OfflineInvitationFailure('already_consumed');
    }
    await beforeCommit?.call(verified);
    if (!operationIsCurrent()) throw const OfflineInvitationFailure('superseded');
    value['accepted_packet'] = parsed;
    value['accepted_account_id'] = verified.recipient['account_id'];
    value['accepted_session_digest'] = await _digest(utf8.encode(
        (verified.recipient['session'] as Map)['access_token'] as String));
    await _storage.write(key: _key(platform, installId), value: canonicalInvitationJson(value));
    if (!operationIsCurrent()) throw const OfflineInvitationFailure('superseded');
    return verified;
  }

  Future<VerifiedOfflineInvitation?> open({required String platform, required String installId,
      String? accountId, String? accessToken}) async {
    final value = await _read(platform, installId);
    if (value == null || value['accepted_packet'] == null || value['cancelled'] == true) return null;
    // Eligibility only: authority is still verified below. A stale packet must
    // not intercept the normal account/session that replaced its recipient.
    if (accountId != null && value['accepted_account_id'] != accountId ||
        accessToken != null && value['accepted_session_digest'] != await _digest(utf8.encode(accessToken))) return null;
    try {
      return await _verify(_object(value['accepted_packet']), value, platform, installId);
    } on OfflineInvitationFailure catch (error) {
      if (error.code == 'expired') return null;
      rethrow;
    }
  }

  Future<void> cancel({required String platform, required String installId}) async {
    final value = await _read(platform, installId);
    if (value == null) return;
    value['cancelled'] = true;
    await _storage.write(key: _key(platform, installId), value: canonicalInvitationJson(value));
  }

  Future<VerifiedOfflineInvitation> _verify(Map<String, dynamic> envelope, Map<String, dynamic> local,
      String platform, String installId) async {
    _keys(envelope, const {'purpose','audience','key_id','invite_id','request_digest','recipient_key_digest',
      'issued_at','expires_at','ephemeral_public_key','nonce','ciphertext','mac','signature'});
    if (envelope['purpose'] != offlineInvitationPurpose || envelope['audience'] != trust.audience) {
      throw const OfflineInvitationFailure('authority_invalid');
    }
    final publicKey = trust.issuerPublicKeys[envelope['key_id']];
    if (publicKey == null) throw const OfflineInvitationFailure('issuer_unknown');
    final signed = Map<String, dynamic>.from(envelope)..remove('signature');
    final valid = await Ed25519().verify(utf8.encode('$offlineInvitationPurpose\n${canonicalInvitationJson(signed)}'),
      signature: Signature(_decode(envelope['signature'], 64),
        publicKey: SimplePublicKey(_decode(publicKey, 32), type: KeyPairType.ed25519)));
    if (!valid) throw const OfflineInvitationFailure('signature_invalid');
    final issued = envelope['issued_at'];
    final expires = envelope['expires_at'];
    final now = _clock().toUtc();
    if (issued is! int || expires is! int || issued <= 0 || expires <= issued || expires - issued > 600 ||
        now.millisecondsSinceEpoch ~/ 1000 < issued || now.millisecondsSinceEpoch ~/ 1000 >= expires) {
      throw const OfflineInvitationFailure('expired');
    }
    final request = _object(_object(local['request'])['payload']);
    if (local['cancelled'] == true) throw const OfflineInvitationFailure('cancelled');
    final requestDigest = await _digest(utf8.encode(canonicalInvitationJson(request)));
    final deliveryPublic = _decode(request['delivery_public_key'], 32);
    final delivery = SimpleKeyPairData(_decode(local['delivery_private_key'], 32),
        publicKey: SimplePublicKey(deliveryPublic, type: KeyPairType.x25519), type: KeyPairType.x25519);
    final derivedPublic = await (await X25519().newKeyPairFromSeed(_decode(local['delivery_private_key'], 32))).extractPublicKey();
    final proofPublic = await (await Ed25519().newKeyPairFromSeed(_decode(local['proof_private_key'], 32))).extractPublicKey();
    if (request['purpose'] != invitationRequestPurpose || request['consent'] != true ||
        request['platform'] != platform || request['install_id'] != installId ||
        local['request_digest'] != requestDigest || envelope['request_digest'] != requestDigest ||
        envelope['recipient_key_digest'] != await _digest(deliveryPublic) ||
        _encode(derivedPublic.bytes) != request['delivery_public_key'] ||
        _encode(proofPublic.bytes) != request['proof_public_key']) {
      throw const OfflineInvitationFailure('recipient_mismatch');
    }
    final header = Map<String, dynamic>.from(signed)..remove('ciphertext')..remove('mac');
    final shared = await X25519().sharedSecretKey(keyPair: delivery,
        remotePublicKey: SimplePublicKey(_decode(envelope['ephemeral_public_key'], 32), type: KeyPairType.x25519));
    final key = await Hkdf(hmac: Hmac.sha256(), outputLength: 32).deriveKey(secretKey: shared,
        nonce: _digestBytes(requestDigest), info: utf8.encode(offlineInvitationPurpose));
    late final List<int> plaintext;
    try {
      plaintext = await AesGcm.with256bits().decrypt(SecretBox(_decode(envelope['ciphertext'], null),
        nonce: _decode(envelope['nonce'], 12), mac: Mac(_decode(envelope['mac'], 16))),
        secretKey: key, aad: utf8.encode(canonicalInvitationJson(header)));
    } on SecretBoxAuthenticationError {
      throw const OfflineInvitationFailure('decryption_failed');
    }
    final raw = utf8.decode(plaintext);
    final recipient = _object(jsonDecode(raw));
    _keys(recipient, const {'account_id','device_id','install_id','session','managed_response','inviter_ref','trial_ref'});
    if (recipient['install_id'] != installId || _ascii(recipient['account_id']).isEmpty ||
        _ascii(recipient['device_id']).isEmpty) throw const OfflineInvitationFailure('recipient_mismatch');
    final session = _object(recipient['session']);
    _keys(session, const {'access_token','refresh_token'});
    _token(session['access_token']); _token(session['refresh_token']);
    _ascii(recipient['inviter_ref']); _ascii(recipient['trial_ref']);
    _object(recipient['managed_response']);
    return VerifiedOfflineInvitation._(raw, request, _ascii(envelope['invite_id']),
        DateTime.fromMillisecondsSinceEpoch(issued * 1000, isUtc: true),
        DateTime.fromMillisecondsSinceEpoch(expires * 1000, isUtc: true));
  }
}
