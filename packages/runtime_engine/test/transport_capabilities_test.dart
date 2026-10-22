import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_runtime_engine/runtime_engine.dart';

// Core 7a62031 adds DNSTT without changing Core's 1.2.14 version. This is
// the full compiled inventory, not authorization to select a DNSTT profile.
const _dnsttCoreFeatures = <String>[
  'dnstt_vless_v1',
  'pokrov_ats_lease_v1',
  'pokrov_awg31_endpoint_v1',
  'pokrov_telegram_ws_v1',
  'singbox_grpc_v1',
  'singbox_hysteria2_v1',
  'singbox_reality_v1',
  'singbox_tls_v1',
  'singbox_utls_v1',
  'singbox_vless_v1',
  'singbox_xhttp_v1',
];

String _inventory(List<String> features) =>
    jsonEncode({'schema': 1, 'features': features});

void main() {
  test('DNSTT Core inventory retains the ordinary transport capabilities', () {
    final wire = _inventory(_dnsttCoreFeatures);
    final capabilities = RuntimeTransportCapabilities.fromWire(wire);

    expect(capabilities, isNotNull);
    expect(capabilities!.canonicalJson, wire);
    expect(capabilities.features.map((feature) => feature.wireName),
        orderedEquals(_dnsttCoreFeatures));
    expect(capabilities.features, containsAll([
      RuntimeTransportFeature.reality,
      RuntimeTransportFeature.grpc,
      RuntimeTransportFeature.xhttp,
      RuntimeTransportFeature.awg31,
      RuntimeTransportFeature.hysteria2,
    ]));
  });

  test('older Core inventory remains usable without advertising DNSTT', () {
    final capabilities = RuntimeTransportCapabilities.fromWire(
        _inventory(_dnsttCoreFeatures.sublist(1)));

    expect(capabilities, isNotNull);
    expect(capabilities!.features.map((feature) => feature.wireName),
        isNot(contains('dnstt_vless_v1')));
    expect(capabilities.features, contains(RuntimeTransportFeature.vless));
  });

  test('a future unknown capability still invalidates the entire inventory', () {
    final names = [..._dnsttCoreFeatures, 'unknown_transport_v1']..sort();
    expect(RuntimeTransportCapabilities.fromWire(_inventory(names)), isNull);
    expect(RuntimeTransportCapabilities.fromWire(
        _inventory(['singbox_vless_v1', 'unknown_transport_v1'])), isNull);
  });

  test('duplicate, reordered and noncanonical DNSTT inventories are rejected', () {
    for (final names in <List<String>>[
      ['dnstt_vless_v1', 'dnstt_vless_v1'],
      _dnsttCoreFeatures.reversed.toList(),
    ]) {
      expect(RuntimeTransportCapabilities.fromWire(_inventory(names)), isNull);
    }
    expect(RuntimeTransportCapabilities.fromWire(
        '{ "schema":1,"features":["dnstt_vless_v1"]}'), isNull);
  });

  test('DNSTT does not bypass the existing REALITY dependency validation', () {
    expect(RuntimeTransportCapabilities.fromWire(_inventory([
      'dnstt_vless_v1', 'singbox_reality_v1', 'singbox_vless_v1',
    ])), isNull);
  });
}
