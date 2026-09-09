import 'package:pokrov_runtime_engine/runtime_engine.dart';

/// A diagnostic self-report, not server-observed traffic or entitlement proof.
Map<String, Object?> runtimeConnectivityReport(RuntimeSnapshot? snapshot) {
  if (snapshot == null) return {'proof_stage': 'unknown'};
  final report = <String, Object?>{};
  for (final entry in {
    'fetched': snapshot.fetchedProfileSource,
    'staged': snapshot.stagedProfileSource,
    'effective': snapshot.effectiveProfileSource,
  }.entries) {
    final source = entry.value;
    final revision = source?.revision.trim() ?? '';
    if (revision.isEmpty || revision.length > 128) continue;
    report['${entry.key}_revision'] = revision;
    report['${entry.key}_protocol'] = const {
      'vless',
      'awg2',
      'awg31',
      'hysteria2',
    }.contains(source?.protocol)
        ? source!.protocol
        : 'unknown';
  }
  report['proof_stage'] = snapshot.phase != RuntimePhase.running
      ? 'not_running'
      : snapshot.hasDegradedHostDiagnostics
          ? 'degraded'
          : snapshot.isCleanlyHealthy
              ? 'egress'
              : snapshot.dnsState == RuntimeDiagnosticState.healthy &&
                      snapshot.dnsReady != false
                  ? 'dns'
                  : 'tunnel';
  if (snapshot.proofObservedAt != null && snapshot.isCleanlyHealthy) {
    report['observed_at_ms'] = snapshot.proofObservedAt!.millisecondsSinceEpoch;
  }
  return report;
}
