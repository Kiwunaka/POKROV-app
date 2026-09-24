import 'package:flutter/services.dart';

import 'routing_catalog_contract.dart';
import 'routing_catalog_policy.dart';

enum CatalogAndroidMatch { matched, unavailable, unsupported, manualOnly, signerMismatch, lineageMismatch }

class CatalogAndroidDiscoveryResult {
  const CatalogAndroidDiscoveryResult(this.catalogDigest, this.expiresAt, this.matches,
    this.matchedSigners, this.matchedLineages);
  final String catalogDigest;
  final DateTime expiresAt;
  final Map<String, CatalogAndroidMatch> matches;
  final Map<String, List<String>> matchedSigners;
  final Map<String, List<String>> matchedLineages;
}

/// Local observations for the existing explicit app-selection preview. A match
/// is not an automatic Builder exclusion or an entitlement/service-health proof.
class CatalogAndroidDiscovery {
  const CatalogAndroidDiscovery({
    MethodChannel channel = const MethodChannel('space.pokrov/runtime_engine'),
  }) : _channel = channel;
  final MethodChannel _channel;

  Future<Map<String, CatalogAndroidMatch>> matchDirectCandidates(
    RoutingCatalogPolicy policy, {
    required String accessState,
    bool fresh = false,
  }) async => (await inspectDirectCandidates(policy, accessState: accessState, fresh: fresh)).matches;

  Future<CatalogAndroidDiscoveryResult> inspectDirectCandidates(
    RoutingCatalogPolicy policy, {
    required String accessState,
    bool fresh = false,
  }) async {
    void requireCurrent() {
      final now = DateTime.now().toUtc();
      if (now.isBefore(policy.catalog.issuedAt) || !now.isBefore(policy.catalog.expiresAt)) {
        throw const RoutingCatalogFailure('catalog_policy_expired');
      }
    }
    requireCurrent();
    final identities = <String, List<CatalogAndroidIdentity>>{};
    final manualOnlyPackages = <String>{};
    for (final service in policy.services) {
      // A browser/container identity stays manual even if its service is not
      // currently eligible. Another service cannot grant that whole app Direct.
      for (final identity in service.android) {
        if (identity.browserOrContainer) manualOnlyPackages.add(identity.package);
      }
      if (!service.enabled || !service.verified || !service.platforms.contains('android') ||
          !service.accessStates.contains(accessState)) continue;
      final direct = service.intents[CatalogRoutingMode.smartSafe] == CatalogRouteAction.direct;
      for (final identity in service.android) {
        if (direct) {
          identities.putIfAbsent(identity.package, () => []).add(identity);
        } else {
          // No explicit intent also keeps the Smart Safe VPN default. A
          // whole-app recommendation must not override another service's scope.
          manualOnlyPackages.add(identity.package);
        }
      }
    }
    if (identities.length > 256) throw const RoutingCatalogFailure('catalog_discovery_too_large');
    if (identities.isEmpty) return CatalogAndroidDiscoveryResult(
      policy.catalog.payloadSha256, policy.catalog.expiresAt, const {}, const {}, const {});
    final packages = identities.keys.toList()..sort();
    final Object? raw;
    try {
      raw = await _channel.invokeMethod<Object?>('runtimeEngine.catalogAppIdentities', {
        'catalogDigest': policy.catalog.payloadSha256, 'packages': packages, 'fresh': fresh,
      }).timeout(const Duration(seconds: 10));
    } on MissingPluginException {
      throw const RoutingCatalogFailure('catalog_discovery_unsupported');
    } on PlatformException {
      throw const RoutingCatalogFailure('catalog_discovery_unavailable');
    }
    requireCurrent();
    if (raw is! Map || raw['schema'] is! int || raw['schema'] != 1 || raw['status'] != 'ready') {
      throw const RoutingCatalogFailure('catalog_discovery_unavailable');
    }
    if (raw.length != 5 || raw['catalog_digest'] != policy.catalog.payloadSha256 ||
        raw['generation'] is! int || (raw['generation'] as int) < 0 || raw['packages'] is! List) {
      throw const RoutingCatalogFailure('catalog_discovery_invalid');
    }
    final rows = raw['packages'] as List;
    if (rows.length != identities.length) throw const RoutingCatalogFailure('catalog_discovery_invalid');
    final result = <String, CatalogAndroidMatch>{};
    final matchedSigners = <String, List<String>>{};
    final matchedLineages = <String, List<String>>{};
    for (final row in rows) {
      if (row is! Map || !identities.containsKey(row['package']) || result.containsKey(row['package'])) {
        throw const RoutingCatalogFailure('catalog_discovery_invalid');
      }
      final name = row['package'] as String;
      if (row['state'] == 'unavailable' || row['state'] == 'unsupported') {
        if (row.length != 2) throw const RoutingCatalogFailure('catalog_discovery_invalid');
        result[name] = row['state'] == 'unsupported' ? CatalogAndroidMatch.unsupported : CatalogAndroidMatch.unavailable;
        continue;
      }
      if (row.length != 7 || row['state'] != 'visible' || row['multiple_signers'] is! bool ||
          row['browser'] is! bool || row['shared_uid'] is! bool) {
        throw const RoutingCatalogFailure('catalog_discovery_invalid');
      }
      final signers = _digests(row['signers'], maximum: 8, allowEmpty: false);
      final lineage = _digests(row['lineage'], maximum: 16, allowEmpty: true);
      final multiple = row['multiple_signers'] as bool;
      if (multiple ? (signers.length < 2 || lineage.isNotEmpty) :
          (signers.length != 1 || lineage.isEmpty || lineage.last != signers.single)) {
        throw const RoutingCatalogFailure('catalog_discovery_invalid');
      }
      if (row['browser'] == true || row['shared_uid'] == true ||
          manualOnlyPackages.contains(name)) {
        result[name] = CatalogAndroidMatch.manualOnly;
        continue;
      }
      var outcome = CatalogAndroidMatch.signerMismatch;
      for (final identity in identities[name]!) {
        if (identity.signers.length != signers.length || !identity.signers.containsAll(signers)) continue;
        if (identity.lineage.isNotEmpty && (identity.lineage.length != lineage.length ||
            !Iterable<int>.generate(lineage.length).every((i) => identity.lineage[i] == lineage[i]))) {
          outcome = CatalogAndroidMatch.lineageMismatch;
          continue;
        }
        outcome = CatalogAndroidMatch.matched;
        matchedSigners[name] = List.unmodifiable(signers);
        matchedLineages[name] = List.unmodifiable(lineage);
        break;
      }
      result[name] = outcome;
    }
    return CatalogAndroidDiscoveryResult(policy.catalog.payloadSha256, policy.catalog.expiresAt,
      Map.unmodifiable(result), Map.unmodifiable(matchedSigners), Map.unmodifiable(matchedLineages));
  }
}

List<String> _digests(Object? raw, {required int maximum, required bool allowEmpty}) {
  if (raw is! List || raw.length > maximum || (!allowEmpty && raw.isEmpty) ||
      raw.any((value) => value is! String || !RegExp(r'^[0-9a-f]{64}$').hasMatch(value)) ||
      raw.toSet().length != raw.length) {
    throw const RoutingCatalogFailure('catalog_discovery_invalid');
  }
  return raw.cast<String>();
}
