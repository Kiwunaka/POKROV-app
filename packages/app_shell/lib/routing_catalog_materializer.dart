import 'routing_catalog_contract.dart';
import 'routing_catalog_policy.dart';
import 'smart_access_profile.dart';

/// A contiguous curated layer for the existing route/DNS assembler. Insertion
/// must follow OS app scope, immutable safety and explicit user rules. These
/// lists deliberately do not replace the host's full configuration or defaults.
class CatalogNativeRuleLayer {
  const CatalogNativeRuleLayer._({
    required this.policy, required this.routeRules, required this.dnsRules,
    required this.outbounds, required this.dnsServers,
  });
  final CatalogDomainPolicy policy;
  final List<Map<String, Object?>> routeRules;
  final List<Map<String, Object?>> dnsRules;
  final List<Map<String, Object?>> outbounds;
  final List<Map<String, Object?>> dnsServers;
}

CatalogNativeRuleLayer materializeCatalogRuleLayer({
  required CatalogDomainPolicy policy,
  required int nativeWindowVersion,
  required String vpnOutbound,
  required String directOutbound,
  required String vpnDnsServer,
  required String directDnsServer,
  required DateTime now,
  int nativeSmartAccessLeaseVersion = 0,
}) {
  if (nativeWindowVersion != 1) {
    throw const RoutingCatalogFailure('catalog_native_window_unsupported');
  }
  if (now.toUtc().isBefore(policy.issuedAt) || !now.toUtc().isBefore(policy.expiresAt)) {
    throw const RoutingCatalogFailure('catalog_policy_expired');
  }
  final hasGateway = policy.rules.any((rule) => rule.action == CatalogRouteAction.approvedGateway);
  if (hasGateway && nativeSmartAccessLeaseVersion != 1) {
    throw const RoutingCatalogFailure('smart_access_native_unsupported');
  }
  final needsVpn = (hasGateway && policy.vpnAvailable) || policy.rules.any((rule) => rule.action == CatalogRouteAction.vpn);
  final needsDirect = hasGateway || policy.rules.any((rule) => rule.action == CatalogRouteAction.direct);
  if ((needsVpn && (vpnOutbound.isEmpty || vpnDnsServer.isEmpty)) ||
      (needsDirect && (directOutbound.isEmpty || directDnsServer.isEmpty)) ||
      (needsVpn && needsDirect &&
        (vpnOutbound == directOutbound || vpnDnsServer == directDnsServer))) {
    throw const RoutingCatalogFailure('catalog_native_targets_invalid');
  }
  final catalogWindow = Map<String, Object?>.unmodifiable({
    'issued_at': _utcSeconds(policy.issuedAt),
    'expires_at': _utcSeconds(policy.expiresAt),
  });
  final route = <Map<String, Object?>>[];
  final dns = <Map<String, Object?>>[];
  final outbounds = <Map<String, Object?>>[];
  final dnsServers = <Map<String, Object?>>[];
  final emitted = <String>{};
  for (final rule in policy.rules) {
    final window = Map<String, Object?>.unmodifiable({...catalogWindow, 'service_id': rule.serviceId});
    final match = <String, Object?>{
      rule.domain.suffix ? 'domain_suffix' : 'domain': List<String>.unmodifiable([rule.domain.name]),
    };
    if (rule.action == CatalogRouteAction.approvedGateway) {
      final grants = rule.gatewayLeases;
      if (grants.isEmpty || grants.any((grant) => !grant.admitsNewFlows(now)) ||
          policy.smartAccessProfile?.byService[rule.serviceId] != grants) {
        throw const RoutingCatalogFailure('catalog_gateway_lease_missing');
      }
      final group = List<String>.unmodifiable(grants.map((grant) => grant.lease['lease_id']! as String));
      for (final grant in grants) {
        final tag = smartAccessOutboundTag(grant);
        if (emitted.add(tag)) {
          outbounds.add(smartAccessNativeOutbound(grant));
          dnsServers.add(smartAccessNativeDns(grant,
            directOutbound: directOutbound, bootstrapDnsServer: directDnsServer));
        }
        final leaseWindow = Map<String, Object?>.unmodifiable({
          // Every domain in the service shares the same ordered group. Native
          // route and DNS windows use one sticky selection for these pointers.
          ...catalogWindow, 'lease_id': grant.lease['lease_id'],
          'lease_group': group, 'service_id': rule.serviceId,
        });
        final ipv4 = grant.lease['family'] == 'ipv4';
        route.add(Map.unmodifiable({
          ...match, 'network': 'tcp', 'port': [443], 'ip_version': ipv4 ? 4 : 6,
          'pokrov_catalog_window': leaseWindow, 'action': 'route', 'outbound': tag,
        }));
        dns.add(Map.unmodifiable({
          ...match, 'query_type': [ipv4 ? 'A' : 'AAAA'],
          'pokrov_catalog_window': leaseWindow, 'action': 'route', 'server': smartAccessDnsTag(grant),
          'disable_cache': true, 'rewrite_ttl': 0,
        }));
      }
      // Unsupported family/port/UDP and lease admission expiry retain the
      // declared protected fallback. A rejected ClientHello is never retried
      // against a different egress by this layer.
      if (policy.vpnAvailable) {
        route.add(Map.unmodifiable({...match, 'pokrov_catalog_window': window,
          'action': 'route', 'outbound': vpnOutbound}));
        dns.add(Map.unmodifiable({...match, 'pokrov_catalog_window': window,
          'action': 'route', 'server': vpnDnsServer, 'disable_cache': true, 'rewrite_ttl': 0}));
      }
    } else if (rule.action != CatalogRouteAction.block) {
      final direct = rule.action == CatalogRouteAction.direct;
      route.add(Map.unmodifiable({
        ...match, 'pokrov_catalog_window': window,
        'action': 'route', 'outbound': direct ? directOutbound : vpnOutbound,
      }));
      dns.add(Map.unmodifiable({
        ...match, 'pokrov_catalog_window': window,
        'action': 'route', 'server': direct ? directDnsServer : vpnDnsServer,
        'disable_cache': true, 'rewrite_ttl': 0,
      }));
    }
    // Keep each fallback immediately after its active rule. On expiry it must
    // win over a broader curated rule or a Direct selective-mode default.
    // Direct bank exceptions likewise become unavailable, not silently VPN.
    route.add(Map.unmodifiable({...match, 'action': 'reject'}));
    dns.add(Map.unmodifiable({...match, 'action': 'reject'}));
  }
  return CatalogNativeRuleLayer._(
    policy: policy, routeRules: List.unmodifiable(route), dnsRules: List.unmodifiable(dns),
    outbounds: List.unmodifiable(outbounds), dnsServers: List.unmodifiable(dnsServers),
  );
}

String _utcSeconds(DateTime value) =>
    '${value.toUtc().toIso8601String().substring(0, 19)}Z';
