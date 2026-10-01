import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/client_routing_preferences.dart';
import 'package:pokrov_app_shell/routing_catalog_contract.dart';
import 'package:pokrov_app_shell/routing_catalog_policy.dart';
import 'package:pokrov_core_domain/core_domain.dart';
import 'package:pokrov_runtime_engine/runtime_engine.dart';

void main() {
  test('DPI is default off; selective opt-in keeps signed envelope and VPN fallback', () async {
    const defaults = PokrovRoutingPreferences.defaults();
    expect(PokrovRoutingPreferences.fromJson({}).localDpiEnabled, isFalse);
    final preferences = defaults.copyWith(localDpiEnabled: true, selectedCatalogServiceIds: {'video'});
    expect(PokrovRoutingPreferences.fromJson(preferences.toJson()).localDpiEnabled, isTrue);
    final catalog = await _catalog();
    final policy = compileCatalogDomainPolicy(policy: catalog, mode: CatalogRoutingMode.selective,
      platform: 'android', accessState: 'trial_premium', vpnAvailable: true, now: DateTime.now(), selectedServiceIds: {'video'});
    ManagedProfilePayload assemble(PokrovRoutingPreferences p) => applyPokrovRoutingPreferences(
      _profile(RouteMode.selectiveServices), p, hostPlatform: HostPlatform.android, catalogPolicy: policy,
      catalogAccessState: 'trial_premium', nativeCatalogWindowVersion: 1);
    final off = assemble(preferences.copyWith(localDpiEnabled: false));
    expect(localDpiServiceIdsForPayload(off), isEmpty);
    final enabled = assemble(preferences);
    final config = jsonDecode(enabled.configPayload) as Map;
    final metadata = (config['_meta'] as Map)['local_dpi'] as Map;
    expect(metadata['catalog_envelope'], catalog.catalog.canonicalEnvelopeJson);
    expect(localDpiServiceIdsForPayload(enabled), {'video'});
    final rules = (config['route'] as Map)['rules'] as List;
    expect(rules.whereType<Map>().where((rule) => rule['pokrov_catalog_window'] != null).single['outbound'], 'proxy');
    final full = compileCatalogDomainPolicy(policy: catalog, mode: CatalogRoutingMode.full,
      platform: 'android', accessState: 'trial_premium', vpnAvailable: true, now: DateTime.now());
    final fullProfile = applyPokrovRoutingPreferences(_profile(RouteMode.fullTunnel, localDpiMetadata: metadata), preferences,
      hostPlatform: HostPlatform.android, catalogPolicy: full, catalogAccessState: 'trial_premium', nativeCatalogWindowVersion: 1);
    expect(localDpiServiceIdsForPayload(fullProfile), isEmpty);
  });

  test('valid signed VPN intent without explicit DPI host grants no DPI authority', () async {
    final catalog = await _catalog(host: null);
    final policy = compileCatalogDomainPolicy(policy: catalog, mode: CatalogRoutingMode.selective,
      platform: 'android', accessState: 'trial_premium', vpnAvailable: true, now: DateTime.now(), selectedServiceIds: {'video'});
    expect(policy.localDpiControlHosts, isEmpty);
    expect(policy.rules.single.action, CatalogRouteAction.vpn);
  });

  test('Windows selective opt-in hands signed scope to its native owner; full stays VPN', () async {
    final catalog = await _catalog(platform: 'windows');
    final policy = compileCatalogDomainPolicy(policy: catalog, mode: CatalogRoutingMode.selective,
      platform: 'windows', accessState: 'trial_premium', vpnAvailable: true, now: DateTime.now(), selectedServiceIds: {'video'});
    final defaults = const PokrovRoutingPreferences.defaults().copyWith(selectedCatalogServiceIds: {'video'});
    ManagedProfilePayload assemble(PokrovRoutingPreferences preferences) => applyPokrovRoutingPreferences(
      _profile(RouteMode.selectiveServices), preferences, hostPlatform: HostPlatform.windows, catalogPolicy: policy,
      catalogAccessState: 'trial_premium', nativeCatalogWindowVersion: 1);
    expect(localDpiServiceIdsForPayload(assemble(defaults)), isEmpty);
    final optedIn = defaults.copyWith(localDpiEnabled: true, selectedCatalogServiceIds: {'video'});
    final prepared = assemble(optedIn);
    final meta = ((jsonDecode(prepared.configPayload) as Map)['_meta'] as Map)['local_dpi'] as Map;
    expect(meta['platform'], 'windows');
    expect(meta['catalog_envelope'], catalog.catalog.canonicalEnvelopeJson);
    expect(localDpiServiceIdsForPayload(prepared), {'video'});
    final full = compileCatalogDomainPolicy(policy: catalog, mode: CatalogRoutingMode.full,
      platform: 'windows', accessState: 'trial_premium', vpnAvailable: true, now: DateTime.now());
    expect(localDpiServiceIdsForPayload(applyPokrovRoutingPreferences(
      _profile(RouteMode.fullTunnel, localDpiMetadata: meta), optedIn,
      hostPlatform: HostPlatform.windows, catalogPolicy: full,
      catalogAccessState: 'trial_premium', nativeCatalogWindowVersion: 1)), isEmpty);
    final identity = await catalogRuntimeIdentity(policy, localDpiServiceIds: {'video'});
    expect(await catalogRuntimeRevocations(identity, policy.payloadSha256,
      await _catalog(platform: 'windows', host: null, revision: 2), DateTime.now()), {'video'});
  });

  test('received DPI authority removal revokes only a profile which opted in', () async {
    final original = await _catalog();
    final compiled = compileCatalogDomainPolicy(policy: original, mode: CatalogRoutingMode.selective,
      platform: 'android', accessState: 'trial_premium', vpnAvailable: true, now: DateTime.now(), selectedServiceIds: {'video'});
    final replacement = await _catalog(host: null, revision: 2);
    final ordinary = await catalogRuntimeIdentity(compiled);
    final enabled = await catalogRuntimeIdentity(compiled, localDpiServiceIds: {'video'});
    expect(await catalogRuntimeRevocations(ordinary, compiled.payloadSha256, replacement, DateTime.now()), isEmpty);
    expect(await catalogRuntimeRevocations(enabled, compiled.payloadSha256, replacement, DateTime.now()), {'video'});
  });
}

Future<RoutingCatalogPolicy> _catalog({String? host = 'media.service.example', int revision = 1,
  String platform = 'android'}) async {
  final now = DateTime.now().toUtc();
  String time(DateTime value) => '${value.toIso8601String().substring(0, 19)}Z';
  final before = time(now.subtract(const Duration(minutes: 1)));
  final after = time(now.add(const Duration(hours: 1)));
  final digest = (await Sha256().hash(utf8.encode('public test fixture'))).bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  final payload = <String, Object?>{
    'schema_version': 'pokrov-routing-catalog-v1', 'revision': revision, 'security_revision': 1,
    'audience': 'lab', 'issued_at': before, 'expires_at': after,
    'sources': [{'source_id': 'source', 'url': 'https://example.com/source', 'revision': 'test', 'sha256': digest,
      'license': 'MIT', 'retrieved_at': before, 'expires_at': after}],
    'evidence': [{'evidence_id': 'evidence', 'service_id': 'video', 'source_ids': ['source'], 'sha256': digest,
      'origin': 'synthetic', 'observed_at': before, 'expires_at': after}],
    'services': [{'service_id': 'video', 'display_name': 'Video', 'categories': ['video'], 'enabled': true,
      'classification': 'blocked_inside_ru', 'reason': 'Public fixture', 'evidence_status': 'verified',
      'source_ids': ['source'], 'evidence_ids': ['evidence'], 'platforms': [platform], 'access_states': ['trial_premium'],
      'route_intents': [{'mode': 'full', 'action': 'vpn'}, {'mode': 'selective', 'action': 'vpn', if (host != null) 'local_dpi_control_host': host}],
      'android': [], 'windows': [], 'domains': [{'name': 'media.service.example', 'match': 'exact', 'role': 'media',
        'shared': false, 'source_ids': ['source']}], 'networks': [], 'provider_capability_refs': [], 'external_gateway_policy': 'forbidden'}],
  };
  String sorted(Object? value) {
    if (value is Map<String, Object?>) { final keys = value.keys.toList()..sort(); return '{${keys.map((key) => '${jsonEncode(key)}:${sorted(value[key])}').join(',')}}'; }
    if (value is List) return '[${value.map(sorted).join(',')}]';
    return jsonEncode(value);
  }
  final body = utf8.encode(sorted(payload));
  final key = await Ed25519().newKeyPair();
  final signature = await Ed25519().sign([...utf8.encode('pokrov-routing-catalog-v1\n'), ...body], keyPair: key);
  final public = await key.extractPublicKey();
  final hash = (await Sha256().hash(body)).bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  final envelope = {'algorithm': 'Ed25519', 'key_id': 'test', 'payload_sha256': hash, 'payload': payload,
    'signature_b64': base64Url.encode(signature.bytes).replaceAll('=', '')};
  final verified = await RoutingCatalogVerifier(publicKeysById: {'test': base64Encode(public.bytes)}, audience: 'lab')
      .verify(envelope, now: now, minimumRevision: 0, minimumSecurityRevision: 1, currentPayloadSha256: null);
  expect(jsonDecode(verified.canonicalEnvelopeJson), envelope);
  return RoutingCatalogPolicy.fromVerified(verified);
}

ManagedProfilePayload _profile(RouteMode mode, {Object? localDpiMetadata}) => ManagedProfilePayload(profileName: 'test', routeMode: mode,
  materializedForRuntime: true, configPayload: jsonEncode({
    if (localDpiMetadata != null) '_meta': {'local_dpi': localDpiMetadata},
    'inbounds': [{'type': 'tun', 'tag': 'tun-in'}],
    'outbounds': [{'type': 'direct', 'tag': 'direct'}, {'type': 'vless', 'tag': 'proxy'}],
    'route': {'final': 'proxy', 'rules': []},
    'dns': {'servers': [{'tag': 'dns-remote', 'address': '1.1.1.1', 'detour': 'proxy'},
      {'tag': 'dns-direct', 'address': '1.1.1.1', 'detour': 'direct'}], 'rules': [], 'final': 'dns-remote'},
  }));
