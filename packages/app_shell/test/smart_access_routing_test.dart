import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/routing_catalog_contract.dart';
import 'package:pokrov_app_shell/routing_catalog_materializer.dart';
import 'package:pokrov_app_shell/routing_catalog_policy.dart';
import 'package:pokrov_app_shell/smart_access_profile.dart';

void main() {
  test('owned Smart DNS supports RU-direct and DNS-only with protected fallback', () async {
    final now = DateTime.utc(2026, 10, 2);
    final catalog = _Catalog(now);
    final policy = RoutingCatalogPolicy.fromVerified(catalog);
    for (final mode in [CatalogRoutingMode.smartSafe, CatalogRoutingMode.selective]) {
      final wireMode = mode == CatalogRoutingMode.smartSafe ? 'smart_safe' : 'selective';
      final grant = _Grant(now, wireMode, await smartAccessProfileSha256('{}'));
      final leases = await SmartAccessProfileLeases.bind(baseProfile: '{}', leases: [grant], routeMode: wireMode);
      final compiled = compileCatalogDomainPolicy(policy: policy, mode: mode,
        platform: 'android', accessState: 'paid_unlimited', vpnAvailable: true, now: now,
        selectedServiceIds: mode == CatalogRoutingMode.selective ? {'ai'} : {}, smartAccessProfile: leases);
      final layer = materializeCatalogRuleLayer(policy: compiled, nativeWindowVersion: 1,
        nativeSmartAccessLeaseVersion: 1, vpnOutbound: 'vpn', directOutbound: 'direct',
        vpnDnsServer: 'vpn-dns', directDnsServer: 'direct-dns', now: now);
      expect(layer.outbounds.single['type'], 'pokrov-smart-access');
      expect(layer.dnsServers.single['address'], 'https://dns.example.test/dns-query');
      expect(layer.routeRules[1]['outbound'], 'vpn');
      expect(layer.dnsRules[1]['server'], 'vpn-dns');
      expect(compiled.defaultAction, mode == CatalogRoutingMode.selective ? CatalogRouteAction.direct : CatalogRouteAction.vpn);
      final unavailable = compileCatalogDomainPolicy(policy: policy, mode: mode,
        platform: 'android', accessState: 'paid_unlimited', vpnAvailable: true, now: now,
        selectedServiceIds: mode == CatalogRoutingMode.selective ? {'ai'} : {});
      expect(unavailable.rules.single.action, CatalogRouteAction.vpn);
      expect(() => compileCatalogDomainPolicy(policy: policy,
        mode: mode == CatalogRoutingMode.smartSafe ? CatalogRoutingMode.selective : CatalogRoutingMode.smartSafe,
        platform: 'android', accessState: 'paid_unlimited', vpnAvailable: true, now: now,
        selectedServiceIds: mode == CatalogRoutingMode.smartSafe ? {'ai'} : {}, smartAccessProfile: leases),
        throwsA(isA<RoutingCatalogFailure>()));
    }
  });
}

class _Catalog implements VerifiedRoutingCatalog {
  _Catalog(this.now);
  final DateTime now;
  @override
  int get revision => 1;
  @override
  int get securityRevision => 1;
  @override
  String get payloadSha256 => 'ab' * 32;
  @override
  DateTime get issuedAt => now.subtract(const Duration(minutes: 1));
  @override
  DateTime get expiresAt => now.add(const Duration(hours: 1));
  @override
  Map<String, Object?> get payload => {
    'audience': 'lab',
    'sources': [{'source_id': 'owned', 'license': 'owner', 'revision': '1',
      'url': 'https://source.example.test/list', 'sha256': 'bc' * 32,
      'retrieved_at': issuedAt.toIso8601String().replaceFirst('.000Z', 'Z'), 'expires_at': expiresAt.toIso8601String().replaceFirst('.000Z', 'Z')}],
    'evidence': [{'evidence_id': 'probe', 'service_id': 'ai', 'source_ids': ['owned'],
      'sha256': 'cd' * 32, 'origin': 'synthetic', 'observed_at': issuedAt.toIso8601String().replaceFirst('.000Z', 'Z'),
      'expires_at': expiresAt.toIso8601String().replaceFirst('.000Z', 'Z')}],
    'services': [{'service_id': 'ai', 'display_name': 'AI', 'categories': ['ai'],
      'enabled': true, 'classification': 'geo_restricted', 'reason': 'Owned Smart DNS',
      'evidence_status': 'verified', 'source_ids': ['owned'], 'evidence_ids': ['probe'],
      'platforms': ['android'], 'access_states': ['paid_unlimited'],
      'route_intents': [{'mode': 'smart_safe', 'action': 'approved_gateway'},
        {'mode': 'selective', 'action': 'approved_gateway'}],
      'android': [], 'windows': [], 'domains': [{'name': 'chatgpt.com', 'match': 'suffix',
        'role': 'web', 'shared': false, 'source_ids': ['owned']}],
      'networks': [], 'provider_capability_refs': ['ai-android'], 'external_gateway_policy': 'approved'}],
  };
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Grant implements VerifiedSmartAccessLease {
  _Grant(this.now, this.mode, this.profile);
  final DateTime now;
  final String mode;
  final String profile;
  @override
  Map<String, Object?> get grant => {'profile_sha256': profile, 'route_mode': mode};
  @override
  DateTime get issuedAt => now.subtract(const Duration(minutes: 1));
  @override
  DateTime get newFlowsUntil => now.add(const Duration(minutes: 9));
  @override
  DateTime get activeFlowsUntil => now.add(const Duration(minutes: 59));
  @override
  bool admitsNewFlows(DateTime value) => value.isBefore(newFlowsUntil);
  @override
  Map<String, Object?> get lease => {
    'lease_id': '0123456789abcdef0123456789abcdef', 'service_id': 'ai', 'provider_id': 'owned',
    'platform': 'android', 'audience': 'lab', 'origin': 'synthetic', 'family': 'ipv4',
    'feature': 'web_request', 'transport': 'tls_tcp_443_visible_sni',
    'catalog_sha256': 'ab' * 32, 'catalog_revision': 1, 'catalog_security_revision': 1,
    'resolver_url': 'https://dns.example.test/dns-query', 'relay_addresses': ['8.8.8.8'],
    'domains': [{'name': 'chatgpt.com', 'match': 'suffix'}], 'relay_connect_policy': null,
    'issued_at': issuedAt.toIso8601String().replaceFirst('.000Z', 'Z'), 'new_flows_until': newFlowsUntil.toIso8601String().replaceFirst('.000Z', 'Z'),
    'active_flows_until': activeFlowsUntil.toIso8601String().replaceFirst('.000Z', 'Z'),
    'max_new_connections_per_minute': 10, 'max_concurrent_connections': 4,
  };
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
