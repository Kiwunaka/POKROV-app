import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_observability_contracts/observability_contracts.dart';

void main() {
  test('typed descriptors match the checked client snapshot', () {
    final snapshotFile = File('../../config/observability-contracts.seed.json');
    final snapshot =
        jsonDecode(snapshotFile.readAsStringSync()) as Map<String, Object?>;
    final contracts = Map<String, Map<String, Object?>>.fromEntries(
      (snapshot['contracts']! as List<Object?>)
          .cast<Map<String, Object?>>()
          .map((entry) => MapEntry(entry['id']! as String, entry)),
    );

    expect(snapshot['schema_version'], 1);
    expect(snapshot['canonical_repository'], 'Kiwunaka/portal');
    expect(contracts.keys.toSet(), {'error-catalog', 'observability-event'});
    for (final descriptor in PokrovObservabilityContracts.descriptors) {
      final snapshotDescriptor = contracts[descriptor.id]!;
      expect(snapshotDescriptor['version'], descriptor.version);
      expect(snapshotDescriptor['sha256'], descriptor.sha256);
      expect(descriptor.sha256, matches(RegExp(r'^[0-9a-f]{64}$')));
    }
  });

  test('catalog snapshot exposes every base 1.2.0 family', () {
    expect(KnownOperationalErrorCodes.values, hasLength(121));
    for (final family in <String>{
      'APP-BOOT',
      'AUTH',
      'API',
      'ENT',
      'CONN',
      'CORE',
      'TRANSPORT',
      'TUN',
      'ROUTE',
      'DNS',
      'EGRESS',
      'RECON',
      'WIN-SVC',
      'WIN-TUN',
      'WIN-DNS',
      'AND-VPN',
      'AND-BG',
      'AND-UPD',
      'LNX-SVC',
      'LNX-IPC',
      'LNX-POLKIT',
      'LNX-NM',
      'LNX-DNS',
      'LNX-NFT',
      'UPD',
      'CRASH',
      'HANG',
      'PERF',
      'SUP',
      'SEC',
    }) {
      expect(
        KnownOperationalErrorCodes.values.any(
          (code) => code.startsWith('$family-'),
        ),
        isTrue,
        reason: 'missing $family family',
      );
    }
    expect(KnownOperationalErrorCodes.contains('DNS-002'), isTrue);
    expect(KnownOperationalErrorCodes.contains('DNS-999'), isFalse);
  });

  test('event wire enums and attribute names remain closed', () {
    expect(ObservabilityOutcome.notApplicable.wireValue, 'not_applicable');
    expect(
      ObservabilityPrivacyClass.serverSecurityAudit.wireValue,
      'server_security_audit',
    );
    expect(ObservabilityAttributeKeys.allowed, hasLength(35));
    expect(ObservabilityAttributeKeys.allowed, contains('dns_ready'));
    expect(ObservabilityAttributeKeys.allowed, contains('selected_app_count'));
    expect(ObservabilityAttributeKeys.allowed, isNot(contains('destination')));
  });
}
