import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/src/shell/mts_bridge_material.dart';
import 'package:pokrov_app_shell/src/shell/vk_bridge_material.dart';
import 'package:pokrov_core_domain/core_domain.dart';
import 'package:pokrov_runtime_engine/runtime_engine.dart';

void main() {
  final mts = TransportCandidate(candidateRef: 'ch:mts', profileRef: 'mts',
    nodeCode: 'ch', countryCode: 'CH', protocol: 'vless', transport: 'mts',
    protection: 'noise', priority: 1, network: 'tcp', flow: '', minimumClientRelease: '1',
    minimumCoreRelease: null, platforms: {HostPlatform.android}, requiredFeatures: const {});
  final other = TransportCandidate(candidateRef: 'de:mts', profileRef: 'mts',
    nodeCode: 'de', countryCode: 'DE', protocol: 'vless', transport: 'mts',
    protection: 'noise', priority: 1, network: 'tcp', flow: '', minimumClientRelease: '1',
    minimumCoreRelease: null, platforms: {HostPlatform.android}, requiredFeatures: const {});
  final catalog = TransportCandidateCatalog(revision: 'test',
    selectedCandidateRef: other.candidateRef, candidates: [mts, other]);

  ManagedProfilePayload material(String ref, String suffix, {String detour = 'carrier'}) =>
    ManagedProfilePayload(profileName: ref, transportCatalog: catalog, materialCandidateRef: ref,
      configPayload: jsonEncode({'outbounds': [
        {'type': 'mts', 'tag': 'carrier', 'board_url': 'https://$suffix.example', 'public_key': 'key-$suffix'},
        {'type': 'vless', 'tag': 'node', 'detour': detour, 'uuid': 'uuid-$suffix'},
      ]}));

  test('uses one selected managed material for bridge and local link', () {
    final selected = material(mts.candidateRef, 'selected');
    final bundle = material(other.candidateRef, 'other').copyWith(
      candidateMaterials: {mts.candidateRef: selected});
    final result = selectedMtsBridgeMaterial(bundle, mts.candidateRef);
    final link = Uri.parse(result.link);
    expect(result.board, 'https://selected.example');
    expect(result.key, 'key-selected');
    expect(link.userInfo, 'uuid-selected');
    expect(link.host, '127.0.0.1');
    expect(link.port, 9002);
  });

  test('rejects a different candidate or an unlinked VLESS outbound', () {
    expect(() => selectedMtsBridgeMaterial(material(other.candidateRef, 'other'), mts.candidateRef),
      throwsFormatException);
    expect(() => selectedMtsBridgeMaterial(material(mts.candidateRef, 'selected', detour: 'other'), mts.candidateRef),
      throwsStateError);
  });

  test('VK companion keeps authenticated inner VLESS in its check and shared link', () {
    final vk = TransportCandidate(candidateRef: 'ch:vk', profileRef: 'vk', nodeCode: 'ch',
      countryCode: 'CH', protocol: 'vless', transport: 'vk', protection: 'reality', priority: 1,
      network: 'tcp', flow: 'xtls-rprx-vision', minimumClientRelease: '2.0.9', minimumCoreRelease: '1.2.18',
      platforms: {HostPlatform.android}, requiredFeatures: const {});
    final profile = ManagedProfilePayload(profileName: 'VK', materialCandidateRef: vk.candidateRef,
      transportCatalog: TransportCandidateCatalog(revision: 'vk', selectedCandidateRef: vk.candidateRef, candidates: [vk]),
      configPayload: jsonEncode({'outbounds': [
        {'type': 'vk', 'tag': 'vk-tunnel', 'call_url': 'https://vk.ru/call/join/owned-call',
          'server': '151.243.191.143', 'server_port': 56000, 'connect_timeout': '90s'},
        {'type': 'vless', 'tag': 'proxy', 'detour': 'vk-tunnel', 'uuid': 'owned-user',
          'server': '151.243.191.143', 'server_port': 443, 'flow': 'xtls-rprx-vision',
          'tls': {'enabled': true, 'server_name': 'example.org', 'utls': {'enabled': true, 'fingerprint': 'chrome'},
            'reality': {'enabled': true, 'public_key': 'owned-key', 'short_id': 'abcd'}}},
      ]}));
    final result = selectedVkBridgeMaterial(profile, vk.candidateRef);
    final link = Uri.parse(result.link);
    expect((link.host, link.port, link.userInfo), ('127.0.0.1', 9000, 'owned-user'));
    expect(link.queryParameters['security'], 'reality');
    expect(link.queryParameters['pbk'], 'owned-key');
    expect(link.queryParameters['sni'], 'example.org');
    final config = jsonDecode(result.config) as Map<String, dynamic>;
    final check = (config['outbounds'] as List).cast<Map<String, dynamic>>().singleWhere((item) => item['tag'] == 'vk-check');
    expect(check['uuid'], 'owned-user');
    expect(check['tls']['reality']['enabled'], true);
  });
}
