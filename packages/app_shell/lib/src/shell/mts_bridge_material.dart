import 'dart:convert';

import 'package:pokrov_runtime_engine/runtime_engine.dart';

({String board, String key, String link}) selectedMtsBridgeMaterial(
    ManagedProfilePayload payload, String selected) {
  final material = payload.candidateMaterials[selected] ?? payload;
  if (material.materialCandidate?.candidateRef != selected ||
      material.materialCandidate?.transport != 'mts') {
    throw const FormatException('Invalid selected connection');
  }
  final config = jsonDecode(material.configPayload) as Map<String, dynamic>;
  final outbounds = (config['outbounds'] as List).cast<Map<String, dynamic>>();
  final carrier = outbounds.singleWhere((item) => item['type'] == 'mts');
  final leaf = outbounds.singleWhere((item) =>
      item['type'] == 'vless' && item['detour'] == carrier['tag']);
  final link = Uri(
    scheme: 'vless', userInfo: leaf['uuid'] as String, host: '127.0.0.1', port: 9002,
    queryParameters: const {'encryption': 'none', 'security': 'none', 'type': 'tcp'},
    fragment: 'POKROV МТС',
  ).toString();
  return (board: carrier['board_url'] as String, key: carrier['public_key'] as String, link: link);
}
