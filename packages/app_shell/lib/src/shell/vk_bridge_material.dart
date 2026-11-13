import 'dart:convert';

import 'package:pokrov_runtime_engine/runtime_engine.dart';

({String config, String link}) selectedVkBridgeMaterial(ManagedProfilePayload payload, String selected) {
  final material = payload.candidateMaterials[selected] ?? payload;
  if (material.materialCandidate?.candidateRef != selected || material.materialCandidate?.transport != 'vk') {
    throw const FormatException('Invalid selected connection');
  }
  final source = jsonDecode(material.configPayload) as Map<String, dynamic>;
  final outbounds = (source['outbounds'] as List).cast<Map<String, dynamic>>();
  final carrier = {...outbounds.singleWhere((item) => item['type'] == 'vk'), 'domain_resolver': {'server': 'bootstrap'}};
  final leaf = outbounds.singleWhere((item) => item['type'] == 'vless' && item['detour'] == carrier['tag']);
  final tls = leaf['tls'] as Map<String, dynamic>;
  final reality = tls['reality'] as Map<String, dynamic>;
  final config = jsonEncode({
    'log': {'disabled': true},
    'dns': {'servers': [{'type': 'udp', 'tag': 'bootstrap', 'server': '77.88.8.8', 'server_port': 53}]},
    'inbounds': [{'type': 'direct', 'listen': '127.0.0.1', 'listen_port': 9000, 'network': 'tcp',
      'override_address': leaf['server'], 'override_port': 443}],
    'outbounds': [carrier, {...leaf, 'tag': 'vk-check', 'domain_resolver': {'server': 'bootstrap'}}],
    'route': {'final': carrier['tag'], 'auto_detect_interface': true, 'default_domain_resolver': 'bootstrap'},
  });
  final link = Uri(scheme: 'vless', userInfo: leaf['uuid'] as String, host: '127.0.0.1', port: 9000,
    queryParameters: {'encryption': 'none', 'security': 'reality', 'type': 'tcp', 'flow': 'xtls-rprx-vision',
      'sni': tls['server_name'] as String, 'fp': 'chrome', 'pbk': reality['public_key'] as String,
      'sid': reality['short_id'] as String}, fragment: 'POKROV VK').toString();
  return (config: config, link: link);
}
