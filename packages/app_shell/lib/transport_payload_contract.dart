part of 'routing_catalog_contract.dart';

/// Wire validation only. Session, nonce, upload and native-path authority are
/// supplied by the owned exchange; a parsed body alone is never a proof.
Map<String, dynamic> decodeTransportPayloadResponse(String raw) {
  try {
    if (raw.length > 2048 || utf8.encode(raw).length > 2048) throw const FormatException();
    final value = _transportMap(_freeze(jsonDecode(raw), 0));
    _keys(value, const {'schema', 'request_nonce', 'probe_set_ref', 'verifier_ref',
      'device_binding', 'upload_sha256', 'download_hex', 'receipt_ref', 'observed_client_ip'});
    if (value['schema'] != 'transport-payload-response-v1' || raw != '${_canonical(value)}\n' ||
        value['request_nonce'] is! String || !RegExp(r'^[a-f0-9]{32}$').hasMatch(value['request_nonce'] as String) ||
        value['download_hex'] is! String || !RegExp(r'^[a-f0-9]{512}$').hasMatch(value['download_hex'] as String)) {
      throw const FormatException();
    }
    for (final name in const ['device_binding', 'upload_sha256']) { _transportDigest(value[name]); }
    for (final name in const ['probe_set_ref', 'verifier_ref', 'receipt_ref']) {
      final ref = value[name];
      if (ref is! String || !RegExp(r'^[a-z][a-z0-9_]{1,23}_[a-f0-9]{16,64}$').hasMatch(ref)) {
        throw const FormatException();
      }
    }
    final observedIp = value['observed_client_ip'];
    if (observedIp is! String || InternetAddress.tryParse(observedIp) == null) {
      throw const FormatException();
    }
    return Map<String, dynamic>.unmodifiable(value);
  } on Object {
    throw const TransportManifestFailure('transport_payload_response_invalid');
  }
}
