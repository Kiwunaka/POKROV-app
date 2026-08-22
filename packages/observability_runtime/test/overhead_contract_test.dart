import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_observability_runtime/observability_runtime.dart';

void main() {
  test('Android and Windows overhead budgets match release plan', () {
    final android = OperationalOverheadBudget.forTarget(
      OperationalOverheadTarget.android,
    );
    final windows = OperationalOverheadBudget.forTarget(
      OperationalOverheadTarget.windows,
    );

    expect(android.idleBytesPerMinute, 50 * 1024);
    expect(android.connectBurstBytesPerMinute, 1024 * 1024);
    expect(android.queueBytes, 2 * 1024 * 1024);
    expect(android.idleCpuPercentOfOneCore, 1);
    expect(windows.idleBytesPerMinute, 100 * 1024);
    expect(windows.connectBurstBytesPerMinute, 2 * 1024 * 1024);
    expect(windows.queueBytes, 4 * 1024 * 1024);
    expect(windows.idleCpuPercentOfOneCore, 0.5);
    expect(android.maxEventBytes, 8 * 1024);
    expect(windows.maxEventBytes, 8 * 1024);
  });

  test('local pipeline report cannot claim unmeasured device overhead', () {
    final report = OperationalOverheadAssessment(
      target: OperationalOverheadTarget.windows,
      observation: _observation(),
    ).toJson(
      os: 'Windows test host',
      runtimeVersion: 'Dart test runtime',
      processors: 8,
    );
    final results = report['results']! as Map<String, Object?>;

    expect(report['state'], 'PARTIAL_LOCAL');
    expect(report['candidate_proven'], isFalse);
    expect(results['idle_volume'], 'PASS');
    expect(results['connect_volume'], 'PASS');
    expect(results['payload'], 'PASS');
    expect(results['queue_volume'], 'PASS');
    expect(results['queue_loss'], 'PASS');
    expect(results['idle_cpu'], 'NOT_MEASURED');
    expect(results['cold_start_delta'], 'NOT_MEASURED');
    expect(results['connect_latency_delta'], 'NOT_MEASURED');
    expect(results['idle_app_delta'], 'NOT_MEASURED');
    expect(results['physical_battery'], 'NOT_MEASURED');
  });

  test('volume, payload, queue size and event loss regressions fail', () {
    final report = OperationalOverheadAssessment(
      target: OperationalOverheadTarget.android,
      observation: _observation(
        idleBytesPerMinute: 50 * 1024 + 1,
        connectBurstBytes: 1024 * 1024 + 1,
        maxEventBytes: 8 * 1024 + 1,
        peakQueueBytes: 2 * 1024 * 1024 + 1,
        eventsDropped: 1,
      ),
    ).toJson(
      os: 'test',
      runtimeVersion: 'test',
      processors: 1,
    );
    final results = report['results']! as Map<String, Object?>;

    expect(results['idle_volume'], 'FAIL');
    expect(results['connect_volume'], 'FAIL');
    expect(results['payload'], 'FAIL');
    expect(results['queue_volume'], 'FAIL');
    expect(results['queue_loss'], 'FAIL');
  });
}

OperationalOverheadObservation _observation({
  int idleBytesPerMinute = 1024,
  int connectBurstBytes = 4096,
  int maxEventBytes = 1024,
  int peakQueueBytes = 2048,
  int eventsDropped = 0,
}) =>
    OperationalOverheadObservation(
      idleBytesPerMinute: idleBytesPerMinute,
      connectBurstBytes: connectBurstBytes,
      maxEventBytes: maxEventBytes,
      emitP95Microseconds: 100,
      eventsAttempted: 10,
      eventsAccepted: 10 - eventsDropped,
      eventsDropped: eventsDropped,
      peakQueueBytes: peakQueueBytes,
      rssDeltaBytes: 4096,
    );
