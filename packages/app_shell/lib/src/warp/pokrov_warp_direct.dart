import 'dart:convert';

import 'package:pokrov_runtime_engine/runtime_engine.dart';

const pokrovDirectWarpCandidateRef = 'warp:warp_free:warp_direct';

/// The server supplies routing rules, never a node or WARP account.
void validatePokrovDirectWarpProfile(Object raw) {
  final config = raw is String ? jsonDecode(raw) : raw;
  if (config is! Map || config['endpoints'] != null || config['outbounds'] is! List) {
    throw const FormatException('Direct WARP profile is invalid');
  }
  final outbounds = config['outbounds'] as List;
  for (final outbound in outbounds) {
    if (outbound is! Map ||
        !const {'selector', 'direct', 'block', 'dns'}.contains(outbound['type']) ||
        outbound.keys.any((key) => !const {'type', 'tag', 'outbounds', 'default'}.contains(key)) ||
        (outbound['type'] == 'selector' &&
          (jsonEncode(outbound['outbounds']) != '["block"]' || outbound['default'] != 'block'))) {
      throw const FormatException('Direct WARP profile contains connection material');
    }
  }
}

/// Direct WARP registers on this installation, independently of node WARP.
WarpRuntimePolicy pokrovDirectWarpPolicy(String installId) {
  if (installId.trim().isEmpty) {
    throw const FormatException('Direct WARP installation identity is missing');
  }
  return WarpRuntimePolicy.clientLocalDefault.copyWith(
    mode: 'warp_direct',
    id: 'warp-direct:${installId.trim()}',
  );
}
