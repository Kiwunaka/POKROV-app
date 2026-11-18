part of '../../client_routing_preferences.dart';

const _youtubeDomains = ['youtube.com', 'youtu.be', 'googlevideo.com', 'ytimg.com',
  'youtube-nocookie.com', 'youtubei.googleapis.com', 'youtube.googleapis.com'];
const _youtubeGroup = 'pokrov-youtube';
const _youtubeProxyTypes = {'vless', 'hysteria2', 'naive', 'awg', 'wireguard'};

/// The original route's restrictions are evaluated before its YouTube branch.
/// No DNS, app exclusion, account restriction or default exit is replaced.
ManagedProfilePayload applyPokrovYouTubeFailover(ManagedProfilePayload payload, {required bool autoCountry}) {
  final selected = payload.materialCandidate;
  final catalog = payload.transportCatalog;
  if (selected == null || catalog == null || selected.warpMode != null ||
      selected.countryCode.isEmpty || payload.candidateMaterials.isEmpty) return payload;
  final config = _routingMap(jsonDecode(payload.configPayload));
  final outbounds = _routingListOfMaps(config['outbounds']);
  final endpoints = _routingListOfMaps(config['endpoints']);
  final route = _routingMap(config['route']);
  final byTag = {for (final row in [...outbounds, ...endpoints]) _routingText(row['tag']): row};
  if (byTag.containsKey(_youtubeGroup)) return payload;
  final vpn = _resolveProxyTag(outbounds, endpoints, route);
  final primary = _youtubeLeaf(byTag, vpn);
  if (primary == null) return payload;
  final paths = [_routingText(primary['tag'])];
  final rules = _routingListOfMaps(route['rules']);
  final ordinaryTags = {vpn, paths.first};
  final targets = catalog.candidates.where((candidate) =>
      candidate.candidateRef != selected.candidateRef && candidate.warpMode == null &&
      candidate.protocol == 'vless' && const {'tcp', 'grpc', 'xhttp'}.contains(candidate.transport) &&
      candidate.countryCode.isNotEmpty && payload.candidateMaterials.containsKey(candidate.candidateRef));
  final ordered = [
    ...targets.where((c) => c.countryCode == selected.countryCode && c.nodeCode != selected.nodeCode),
    ...targets.where((c) => c.countryCode == selected.countryCode && c.nodeCode == selected.nodeCode),
    if (autoCountry) ...targets.where((c) => c.countryCode != selected.countryCode),
  ];
  for (final candidate in ordered) {
    final material = payload.candidateMaterials[candidate.candidateRef]!;
    if (material.materialCandidate?.candidateRef != candidate.candidateRef ||
        material.transportCatalog?.revision != catalog.revision) continue;
    final other = _routingMap(jsonDecode(material.configPayload));
    final collection = _routingListOfMaps(other['outbounds']);
    final otherTags = {for (final item in collection) _routingText(item['tag']): item};
    final leaf = _youtubeLeaf(otherTags,
        _resolveProxyTag(collection, _routingListOfMaps(other['endpoints']), _routingMap(other['route'])));
    // HY2 and AWG are bound to the contract of their original profile. Only a
    // self-contained TLS-protected VLESS route can be added to another profile.
    if (leaf == null || leaf['type'] != 'vless' || _routingMap(leaf['tls'])['enabled'] != true) continue;
    final tag = 'pokrov-youtube-path-${paths.length}';
    final detour = _routingText(leaf['detour']);
    final bridge = otherTags[detour];
    if (detour.isNotEmpty &&
        (bridge == null || bridge['type'] != 'vless' || _routingText(bridge['detour']).isNotEmpty)) continue;
    if (byTag.containsKey(tag) || byTag.containsKey('$tag-bridge')) continue;
    if (detour.isNotEmpty) outbounds.add({...bridge!, 'tag': '$tag-bridge'});
    outbounds.add({...leaf, 'tag': tag, if (detour.isNotEmpty) 'detour': '$tag-bridge'});
    paths.add(tag);
  }
  if (paths.length == 1) return payload;
  final service = {'domain_suffix': _youtubeDomains, 'port': 443};
  final splitRules = <Map<String, dynamic>>[];
  for (final rule in rules) {
    if (ordinaryTags.contains(rule['outbound']) && (rule['action'] == null || rule['action'] == 'route')) {
      final predicate = Map.of(rule)..remove('outbound')..remove('action');
      // Native proof, app scope and classifiers retain their original order.
      splitRules.add(predicate.isEmpty ? {...service, 'outbound': _youtubeGroup} : {
        'type': 'logical', 'mode': 'and', 'rules': [predicate, service], 'outbound': _youtubeGroup,
      });
    }
    splitRules.add(rule);
  }
  if (ordinaryTags.contains(route['final'])) splitRules.add({...service, 'outbound': _youtubeGroup});
  if (splitRules.length == rules.length) return payload;
  config['route'] = {...route, 'rules': splitRules};
  config['outbounds'] = [...outbounds, {'type': _youtubeGroup, 'tag': _youtubeGroup, 'outbounds': paths}];
  return payload.copyWith(configPayload: jsonEncode(config));
}

Map<String, dynamic>? _youtubeLeaf(Map<String, Map<String, dynamic>> byTag, String tag) {
  final seen = <String>{};
  while (seen.add(tag)) {
    final leaf = byTag[tag];
    if (leaf == null) return null;
    if (_youtubeProxyTypes.contains(leaf['type'])) return leaf;
    if (leaf['type'] != 'selector' && leaf['type'] != 'urltest') return null;
    final members = leaf['outbounds'];
    if (members is! List || members.isEmpty) return null;
    tag = _routingText(leaf['default']);
    if (tag.isEmpty) tag = _routingText(members.first);
    if (!members.contains(tag)) return null;
  }
  return null;
}
