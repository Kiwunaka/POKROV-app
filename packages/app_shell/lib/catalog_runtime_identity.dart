import 'routing_catalog_contract.dart';

/// Restriction metadata only: no domain names, profile bytes or route authority.
class CatalogRuntimeIdentity {
  CatalogRuntimeIdentity._(this.revision, this.securityRevision, this.audience,
    this.platform, this.mode, this.accessState, this.services);
  final int revision;
  final int securityRevision;
  final String audience;
  final String platform;
  final String mode;
  final String accessState;
  final Map<String, CatalogRuntimeServiceIdentity> services;

  factory CatalogRuntimeIdentity.fromStored(Object? input) {
    Never invalid() => throw const RoutingCatalogFailure('catalog_runtime_identity_invalid');
    if (input is! Map<String, Object?> || input.length != 7 ||
        input['services'] is! Map<String, Object?>) invalid();
    for (final field in const ['revision', 'security_revision']) {
      final value = input[field];
      if (value is! int || value < 1 || value > 9007199254740991) invalid();
    }
    if (!const {'lab', 'production'}.contains(input['audience']) ||
        !const {'android', 'windows'}.contains(input['platform']) ||
        !const {'full', 'smartSafe', 'selective', 'includeApps', 'excludeApps'}.contains(input['mode']) ||
        !const {'trial_premium', 'bonus_premium', 'paid_unlimited', 'free_monthly', 'free_soft_mode'}.contains(input['access_state'])) invalid();
    final rows = input['services']! as Map<String, Object?>;
    if (rows.length > 256) invalid();
    final services = <String, CatalogRuntimeServiceIdentity>{};
    for (final entry in rows.entries) {
      final row = entry.value;
      if (!RegExp(r'^[a-z0-9][a-z0-9._-]{0,63}$').hasMatch(entry.key) ||
          row is! Map<String, Object?> || row.length != 2 || row['rules'] is! List || row['capabilities'] is! List) invalid();
      Set<String> strings(Object? value, int maximum, RegExp pattern) {
        if (value is! List || value.length > maximum || value.any((item) => item is! String || !pattern.hasMatch(item)) ||
            value.toSet().length != value.length) invalid();
        return Set.unmodifiable(value.cast<String>());
      }
      final rules = strings(row['rules'], 4096, RegExp(r'^[a-f0-9]{64}$'));
      if (rules.isEmpty) invalid();
      services[entry.key] = CatalogRuntimeServiceIdentity._(rules,
        strings(row['capabilities'], 16, RegExp(r'^[a-z0-9][a-z0-9._-]{0,63}$')));
    }
    return CatalogRuntimeIdentity._(input['revision']! as int, input['security_revision']! as int,
      input['audience']! as String, input['platform']! as String, input['mode']! as String,
      input['access_state']! as String, Map.unmodifiable(services));
  }

  Map<String, Object?> toStored() => {
    'revision': revision, 'security_revision': securityRevision, 'audience': audience,
    'platform': platform, 'mode': mode, 'access_state': accessState,
    'services': {for (final entry in services.entries) entry.key: {
      'rules': entry.value.rules.toList()..sort(), 'capabilities': entry.value.capabilities.toList()..sort()}}
  };
}

class CatalogRuntimeServiceIdentity {
  const CatalogRuntimeServiceIdentity._(this.rules, this.capabilities);
  final Set<String> rules;
  final Set<String> capabilities;
}
