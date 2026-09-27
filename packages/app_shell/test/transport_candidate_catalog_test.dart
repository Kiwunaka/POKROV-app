import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/routing_catalog_contract.dart';
import 'package:pokrov_core_domain/core_domain.dart';
import 'package:pokrov_runtime_engine/runtime_engine.dart';

Map<String, Object?> candidate(String node, String profile, {
  String protocol = 'vless', String transport = 'tcp', String protection = 'reality',
  List<String> features = const ['singbox_vless_v1', 'singbox_reality_v1'],
}) => {
  'candidate_ref': '$node:$profile', 'profile_ref': profile, 'node_code': node,
  'country_code': 'DE', 'protocol': protocol, 'transport': transport,
  'protection': protection, 'priority': 0,
  'parameters': {'network': transport == 'udp' ? 'udp' : 'tcp',
    'flow': transport == 'tcp' ? 'xtls-rprx-vision' : ''},
  'requirements': {'minimum_client_release': '1.2.0', 'minimum_core_release': null,
    'platforms': ['android', 'windows'], 'required_features': features},
};

Map<String, Object?> catalog(List<Map<String, Object?>> candidates) => {
  'schema_version': 'pokrov-transport-catalog-v1', 'revision': 'rev-1',
  'selected_candidate_ref': candidates.first['candidate_ref'], 'candidates': candidates,
};

TransportCandidateCatalog parse(Map<String, Object?> value, {String node = ''}) =>
    decodeManagedTransportCatalog(value, platform: HostPlatform.windows,
      clientRelease: '1.2.0', runtimeFeatures: RuntimeTransportFeature.values.toSet(),
      requestedNodeCode: node);

void main() {
  test('one egress catalog retains every authorized protocol and payload identity', () {
    final value = parse(catalog([
      candidate('de', 'legacy_reality_fallback'),
      candidate('de', 'grpc_443_primary', transport: 'grpc', protection: 'tls',
        features: ['singbox_vless_v1', 'singbox_grpc_v1']),
      candidate('de', 'awg31_lab', protocol: 'awg', transport: 'udp', protection: 'awg31',
        features: ['pokrov_awg31_endpoint_v1']),
      candidate('de', 'hy2_lab', protocol: 'hysteria2', transport: 'udp', protection: 'tls',
        features: ['singbox_hysteria2_v1']),
    ]), node: 'de');
    expect(value.candidates.map((item) => item.protocol), ['vless', 'vless', 'awg', 'hysteria2']);
    expect(value.selected.candidateRef, 'de:legacy_reality_fallback');
    final payload = ManagedProfilePayload(profileName: 'test', configPayload: '{}', transportCatalog: value);
    expect(payload.copyWith(configPayload: '{"route":{}}').transportCatalog, same(value));
    expect(() => value.candidates.clear(), throwsUnsupportedError);
  });

  test('catalog rejects secret fields, missing selection and changed egress', () {
    final secret = candidate('de', 'legacy_reality_fallback');
    (secret['parameters'] as Map)['private_key'] = 'not-catalog-material';
    expect(() => parse(catalog([secret])), throwsA(isA<TransportManifestFailure>()));
    final missing = catalog([candidate('de', 'legacy_reality_fallback')]);
    missing['selected_candidate_ref'] = 'pl:legacy_reality_fallback';
    expect(() => parse(missing), throwsA(isA<TransportManifestFailure>()));
    expect(() => parse(catalog([candidate('de', 'legacy_reality_fallback')]), node: 'pl'),
      throwsA(isA<TransportManifestFailure>()));
  });

  test('unknown Core release cannot satisfy a mandatory version requirement', () {
    final row = candidate('de', 'legacy_reality_fallback');
    (row['requirements'] as Map)['minimum_core_release'] = '1.1.0';
    expect(() => parse(catalog([row])), throwsA(isA<TransportManifestFailure>()
      .having((failure) => failure.code, 'code', 'transport_catalog_incompatible')));
    expect(() => decodeManagedTransportCatalog(catalog([candidate('de', 'legacy_reality_fallback')]),
      platform: HostPlatform.windows, clientRelease: '1.2.0', runtimeFeatures: const {}),
      throwsA(isA<TransportManifestFailure>()));
  });
}
