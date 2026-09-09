import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/src/shell/runtime_connectivity_report.dart';
import 'package:pokrov_core_domain/core_domain.dart';
import 'package:pokrov_runtime_engine/runtime_engine.dart';

void main() {
  test('connectivity preserves fetched/effective mismatch without local inputs',
      () {
    final observed = DateTime.utc(2026, 9, 10);
    RuntimeSnapshot snapshot(RuntimePhase phase) => RuntimeSnapshot(
          hostPlatform: HostPlatform.android,
          lane: RuntimeLane.mobileArtifact,
          phase: phase,
          artifactDirectory: '/private/runtime',
          coreBinaryPath: '/private/core',
          helperBinaryPath: null,
          stagedConfigPath: '/private/profile.json',
          supportsLiveConnect: true,
          canInitialize: true,
          canConnect: true,
          message: 'private native detail',
          hostHealth: RuntimeHostHealth.healthy,
          dnsState: RuntimeDiagnosticState.healthy,
          uplinkState: RuntimeDiagnosticState.healthy,
          dnsReady: true,
          coreEgressValidated: true,
          fetchedProfileSource: const RuntimeProfileSource(
            revision: 'assigned-awg2',
            protocol: 'awg2',
            origin: RuntimeProfileSourceOrigin.managedManifest,
          ),
          stagedProfileSource: const RuntimeProfileSource(
            revision: 'applied-awg31',
            protocol: 'awg31',
            origin: RuntimeProfileSourceOrigin.managedManifest,
          ),
          effectiveProfileSource: const RuntimeProfileSource(
            revision: 'applied-awg31',
            protocol: 'awg31',
            origin: RuntimeProfileSourceOrigin.managedManifest,
          ),
          proofObservedAt: observed,
        );
    final active = runtimeConnectivityReport(snapshot(RuntimePhase.running));
    expect(active, {
      'fetched_revision': 'assigned-awg2',
      'fetched_protocol': 'awg2',
      'staged_revision': 'applied-awg31',
      'staged_protocol': 'awg31',
      'effective_revision': 'applied-awg31',
      'effective_protocol': 'awg31',
      'proof_stage': 'egress',
      'observed_at_ms': observed.millisecondsSinceEpoch,
    });
    expect(jsonEncode(active), isNot(contains('private')));
    final stopped =
        runtimeConnectivityReport(snapshot(RuntimePhase.artifactReady));
    expect(stopped['proof_stage'], 'not_running');
    expect(stopped.containsKey('observed_at_ms'), isFalse);
    expect(runtimeConnectivityReport(null), {'proof_stage': 'unknown'});
  });
}
