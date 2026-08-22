import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_observability_contracts/observability_contracts.dart';
import 'package:pokrov_observability_runtime/observability_runtime.dart';

void main() {
  test('19-case integration fault contract uses canonical closed outcomes', () {
    OperationalFailureMapper.validateCatalogCoverage();
    expect(OperationalFaultInjection.values, hasLength(19));

    final expectations = <OperationalFaultInjection, List<String>>{
      OperationalFaultInjection.portalDnsUnavailable: <String>['API-001'],
      OperationalFaultInjection.tlsInterceptionOrClockSkew: <String>[
        'API-003',
        'AUTH-003',
      ],
      OperationalFaultInjection.runtimeProfileInvalid: <String>['CONN-005'],
      OperationalFaultInjection.coreArtifactMissing: <String>['CORE-001'],
      OperationalFaultInjection.coreAbiMismatch: <String>['CORE-002'],
      OperationalFaultInjection.coreStartTimeout: <String>['CORE-003'],
      OperationalFaultInjection.tunCreateDenied: <String>['TUN-001'],
      OperationalFaultInjection.routesApplyFailure: <String>['ROUTE-001'],
      OperationalFaultInjection.dnsApplyFailure: <String>['DNS-001'],
      OperationalFaultInjection.dnsProofTimeout: <String>['DNS-002'],
      OperationalFaultInjection.egressWrongRegion: <String>['EGRESS-002'],
      OperationalFaultInjection.serviceCrash: <String>['CRASH-003'],
      OperationalFaultInjection.networkFlapping: <String>['RECON-002'],
      OperationalFaultInjection.androidPermissionRevoked: <String>[
        'AND-VPN-004',
      ],
      OperationalFaultInjection.windowsIpcMismatch: <String>['WIN-SVC-004'],
      OperationalFaultInjection.linuxPolkitDenial: <String>[
        'LNX-POLKIT-001',
      ],
      OperationalFaultInjection.apkIdentityMismatch: <String>['AND-UPD-002'],
      OperationalFaultInjection.bundlePlantedToken: <String>[
        'SUP-002',
        'SEC-001',
      ],
      OperationalFaultInjection.uploadInterrupted: <String>['SUP-005'],
    };

    expect(expectations.keys.toSet(), OperationalFaultInjection.values.toSet());
    for (final entry in expectations.entries) {
      final actual = OperationalFailureMapper.injectedFault(entry.key);
      expect(actual.errorCodes, entry.value, reason: entry.key.name);
      expect(actual.phase, isNotEmpty, reason: entry.key.name);
      for (final code in actual.errorCodes) {
        expect(KnownOperationalErrorCodes.contains(code), isTrue,
            reason: entry.key.name);
      }
      if (actual.rollbackRequired) {
        expect(actual.privilegedMutationAllowed, isTrue,
            reason: entry.key.name);
      }
    }

    expect(
      OperationalFailureMapper.injectedFault(
        OperationalFaultInjection.linuxPolkitDenial,
      ).coverage,
      OperationalFaultCoverage.notShipped,
    );
  });

  test('runtime failure strings preserve specific fault codes', () {
    expect(
      OperationalFailureMapper.portal(transport: PortalTransportFailure.dns),
      'API-001',
    );
    expect(
      OperationalFailureMapper.portal(transport: PortalTransportFailure.tls),
      'API-003',
    );
    expect(
      OperationalFailureMapper.connection('vpn_permission_revoked'),
      'AND-VPN-004',
    );
    expect(
      OperationalFailureMapper.connection('core_capabilities_incompatible'),
      'CORE-002',
    );
    expect(
      OperationalFailureMapper.connection('service_protocol_mismatch'),
      'WIN-SVC-004',
    );
    expect(
      OperationalFailureMapper.connection('network_flapping'),
      'RECON-002',
    );
  });

  test('loss DNS MTU and IPv6 chaos remain phase-visible and unverified',
      () async {
    for (final scenario in OperationalNetworkChaosScenario.values) {
      final expectation = OperationalFailureMapper.networkChaos(scenario);
      expect(
        OperationalFailureMapper.connection(expectation.runtimeFailureKind),
        expectation.errorCode,
        reason: scenario.name,
      );

      final writer = _MemoryWriter();
      final dispatcher = OperationalEventDispatcher(writer: writer);
      final ids = OperationalIdFactory(random: Random(scenario.index + 80));
      final timeline = OperationalAttemptTimeline(
        dispatcher: dispatcher,
        build: _build(),
        runId: ids.uuidV4(),
        attemptId: ids.uuidV4(),
        generation: scenario.index + 1,
        ids: ids,
      )..start();
      final phase = OperationalTimelinePhase.values.byName(expectation.phase);
      timeline.enter(phase);
      timeline.finish(
        OperationalTerminalKind.failed,
        errorCode: expectation.errorCode,
      );
      await dispatcher.flush();

      final phaseFailure = writer.events.singleWhere(
        (event) => event.name == 'app.connection.${expectation.phase}.finished',
      );
      expect(phaseFailure.error?.code, expectation.errorCode,
          reason: scenario.name);
      expect(phaseFailure.attributes['phase'], expectation.phase,
          reason: scenario.name);
      expect(
        writer.events.any((event) => event.name.contains('.verified.')),
        isFalse,
        reason: scenario.name,
      );
    }
  });
}

OperationalBuildIdentity _build() => OperationalBuildIdentity(
      appVersion: '1.2.0',
      buildNumber: '30',
      channel: 'local',
      candidateLabel: 'pokrov-1.2.0-local',
      gitRevision: '0123456789abcdef0123456789abcdef01234567',
      coreVersion: '1.1.0',
      coreAbi: 2,
      platform: 'android',
      architecture: 'arm64-v8a',
    );

final class _MemoryWriter implements OperationalEventWriter {
  final List<OperationalEvent> events = <OperationalEvent>[];

  @override
  Future<void> appendBatch(List<SerializedOperationalEvent> records) async {
    events.addAll(records.map((record) => record.event));
  }
}
