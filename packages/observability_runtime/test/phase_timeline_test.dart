import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_observability_contracts/observability_contracts.dart';
import 'package:pokrov_observability_runtime/observability_runtime.dart';

void main() {
  test('phase timeline records duration and requires every current proof',
      () async {
    final writer = _MemoryWriter();
    final dispatcher = OperationalEventDispatcher(writer: writer);
    final ids = OperationalIdFactory(random: Random(1));
    var now = DateTime.utc(2026, 8, 21, 10);
    final timeline = OperationalAttemptTimeline(
      dispatcher: dispatcher,
      build: _build(),
      runId: ids.uuidV4(),
      attemptId: ids.uuidV4(),
      generation: 1,
      ids: ids,
      clock: () => now,
    );

    timeline.start();
    timeline.enter(OperationalTimelinePhase.profile);
    now = now.add(const Duration(milliseconds: 37));
    timeline.complete(
      OperationalTimelinePhase.profile,
      outcome: ObservabilityOutcome.succeeded,
    );
    const incomplete = OperationalProofSnapshot(
      interfaceReady: true,
      routesReady: true,
      dnsReady: true,
      egressReady: false,
    );
    expect(() => timeline.markVerified(incomplete), throwsStateError);
    timeline.observeProof(incomplete);
    expect(
      () => timeline.finish(OperationalTerminalKind.succeeded),
      throwsStateError,
    );

    const complete = OperationalProofSnapshot(
      interfaceReady: true,
      routesReady: true,
      dnsReady: true,
      egressReady: true,
    );
    timeline.markVerified(complete);
    timeline.finish(OperationalTerminalKind.succeeded);
    await dispatcher.flush();

    final events = writer.events;
    expect(
      events.map((event) => event.name),
      containsAllInOrder(<String>[
        'app.connection.intent.received',
        'app.connection.profile.started',
        'app.connection.profile.finished',
        'app.connection.verified.started',
        'app.connection.verified.finished',
        'app.connection.attempt.finished',
      ]),
    );
    expect(
      events
          .singleWhere(
            (event) => event.name == 'app.connection.profile.finished',
          )
          .attributes['duration_ms'],
      37,
    );
    expect(
      events
          .singleWhere(
            (event) => event.name == 'app.connection.verified.finished',
          )
          .attributes,
      containsPair('egress_ready', true),
    );
    expect(
      events
          .singleWhere(
            (event) => event.name == 'app.connection.proof.observed',
          )
          .attributes,
      containsPair('egress_ready', false),
    );
  });

  test('cancel, supersede, timeout and crash are distinct closed terminals',
      () async {
    final results = <OperationalTerminalKind, OperationalEvent>{};
    for (final kind in <OperationalTerminalKind>[
      OperationalTerminalKind.cancelled,
      OperationalTerminalKind.superseded,
      OperationalTerminalKind.timeout,
      OperationalTerminalKind.crash,
    ]) {
      final writer = _MemoryWriter();
      final dispatcher = OperationalEventDispatcher(writer: writer);
      final ids = OperationalIdFactory(random: Random(kind.index + 8));
      final timeline = OperationalAttemptTimeline(
        dispatcher: dispatcher,
        build: _build(),
        runId: ids.uuidV4(),
        attemptId: ids.uuidV4(),
        generation: 1,
        ids: ids,
      )..start();
      timeline.enter(OperationalTimelinePhase.core);
      timeline.finish(kind);
      await dispatcher.flush();
      results[kind] = writer.events.last;
    }

    expect(
      results[OperationalTerminalKind.cancelled]!.outcome,
      ObservabilityOutcome.cancelled,
    );
    expect(
      results[OperationalTerminalKind.superseded]!.outcome,
      ObservabilityOutcome.superseded,
    );
    expect(
      results[OperationalTerminalKind.timeout]!.error!.code,
      'CONN-008',
    );
    expect(
      results[OperationalTerminalKind.crash]!.error!.code,
      'CRASH-001',
    );
  });

  test('portal correlation scope retains only canonical UUIDv4', () async {
    final ids = OperationalIdFactory(random: Random(4));
    final correlationId = ids.uuidV4();
    expect(PortalCorrelationScope.current, isNull);
    expect(
      await PortalCorrelationScope.run(
        correlationId,
        () async => PortalCorrelationScope.current,
      ),
      correlationId,
    );
    expect(
      () => PortalCorrelationScope.run('not-a-uuid', () async {}),
      throwsArgumentError,
    );
  });

  test('release-health mirror strips correlation and arbitrary attributes',
      () async {
    final local = _MemoryWriter();
    Map<String, Object?>? sent;
    String? sentCorrelation;
    final mirror = ReleaseHealthMirrorWriter(
      localWriter: local,
      transport: (batch, correlationId) async {
        sent = batch;
        sentCorrelation = correlationId;
        return true;
      },
    );
    final ids = OperationalIdFactory(random: Random(5));
    final event = _event(ids);
    final record = const OperationalEventSerializer().serialize(event);
    await mirror.appendBatch(<SerializedOperationalEvent>[record]);

    expect(local.events, <OperationalEvent>[event]);
    expect(sentCorrelation, event.correlation.attemptId);
    final serialized = jsonEncode(sent);
    expect(serialized, isNot(contains('correlation')));
    expect(serialized, isNot(contains('attributes')));
    expect(serialized, contains('"privacy_class":"release_health"'));
    expect(mirror.snapshot().acceptedBatches, 1);
  });

  test('release-health mirrors count only for exact Android routing terminal',
      () async {
    final local = _MemoryWriter();
    Map<String, Object?>? sent;
    final mirror = ReleaseHealthMirrorWriter(
      localWriter: local,
      transport: (batch, _) async {
        sent = batch;
        return true;
      },
    );
    final ids = OperationalIdFactory(random: Random(55));
    await mirror.appendBatch(<SerializedOperationalEvent>[
      const OperationalEventSerializer().serialize(
        _routingEvent(ids, stage: 'complete'),
      ),
      const OperationalEventSerializer().serialize(
        _routingEvent(ids, stage: 'apply'),
      ),
    ]);

    final events = (sent!['events']! as List<Object?>)
        .whereType<Map<String, Object?>>()
        .toList();
    expect(events[0]['attributes'], <String, Object?>{'selected_app_count': 3});
    expect(events[1], isNot(contains('attributes')));
  });

  test('previous-exit marker recovers safe breadcrumbs and is not authority',
      () async {
    final directory = await Directory.systemTemp.createTemp('pokrov-exit-');
    addTearDown(() => directory.delete(recursive: true));
    final ids = OperationalIdFactory(random: Random(6));
    final store = PreviousExitMarkerStore(
      file:
          File('${directory.path}${Platform.pathSeparator}previous-exit.json'),
    );
    expect(await store.beginRun(ids.uuidV4()), isA<PreviousExitReport>());
    final event = _event(ids);
    final breadcrumb = OperationalBreadcrumb.fromEvent(event);
    store.markCrashSynchronously(
      errorCode: 'CRASH-001',
      crashSignature: '0123456789abcdef',
      breadcrumbs: <OperationalBreadcrumb>[breadcrumb],
    );
    await store.markCleanExit(breadcrumbs: <OperationalBreadcrumb>[breadcrumb]);

    final report = await store.readPrevious();
    expect(report.kind, PreviousExitKind.crash);
    expect(report.errorCode, 'CRASH-001');
    expect(report.breadcrumbs.single.eventId, event.eventId);
    expect(report.isRuntimeAuthority, isFalse);
    final raw = await store.file.readAsString();
    expect(OperationalPrivacyGuard.containsForbiddenMaterial(raw), isFalse);
    final invalid = jsonDecode(raw) as Map<String, Object?>;
    invalid['error_code'] = 'DNS-002';
    await store.file.writeAsString(jsonEncode(invalid));
    expect((await store.readPrevious()).kind, PreviousExitKind.corrupt);
  });

  test('failure maps and all problem-book paths remain closed', () {
    OperationalFailureMapper.validateCatalogCoverage();
    expect(
      OperationalFailureMapper.portal(transport: PortalTransportFailure.tls),
      'API-003',
    );
    expect(
      OperationalFailureMapper.connection('core_egress_probe_failed'),
      'EGRESS-001',
    );
    expect(OperationalFailureMapper.connection('core_egress_dns_failed'), 'DNS-002');
    expect(OperationalFailureMapper.connection('core_egress_response_timeout'),
        'TRANSPORT-007');
    expect(
      OperationalFailureMapper.update(ClientUpdateFailure.identity),
      'UPD-004',
    );
    expect(OperationalProblemBook.entries.length, 14);
    expect(
      OperationalProblemBook.entries.map((entry) => entry.id).toSet().length,
      14,
    );
    final androidOem = OperationalProblemBook.entries
        .singleWhere((entry) => entry.id == 'PB-08');
    expect(
      androidOem.errorCodes,
      <String>['AND-BG-001', 'AND-BG-002', 'AND-BG-003', 'AND-VPN-004'],
    );
    expect(
      androidOem.safeActions,
      containsAll(<String>[
        'open_android_guidance',
        'retry_connect',
        'send_bundle',
      ]),
    );
    final linux = OperationalProblemBook.entries
        .singleWhere((entry) => entry.id == 'PB-09');
    expect(linux.availability, ProblemBookAvailability.notShipped);
    expect(linux.errorCodes, isEmpty);
    expect(linux.safeActions, <String>['state_linux_not_shipped']);
    for (final entry in OperationalProblemBook.entries) {
      if (entry.id == 'PB-09') {
        expect(entry.availability, ProblemBookAvailability.notShipped);
      } else {
        expect(entry.observedEvents, isNotEmpty, reason: entry.id);
        expect(entry.notObservedEvents, isNotEmpty, reason: entry.id);
        expect(entry.safeActions, isNotEmpty, reason: entry.id);
      }
      for (final code in entry.errorCodes) {
        expect(KnownOperationalErrorCodes.contains(code), isTrue,
            reason: entry.id);
      }
    }
  });
}

OperationalBuildIdentity _build() => OperationalBuildIdentity(
      appVersion: '1.2.0',
      buildNumber: '30',
      channel: 'local',
      candidateLabel: 'pokrov-1.2.0-local',
      gitRevision: '0123456789abcdef0123456789abcdef01234567',
      coreVersion: '1.2.0',
      coreAbi: 2,
      platform: 'android',
      architecture: 'arm64-v8a',
    );

OperationalEvent _event(OperationalIdFactory ids) => OperationalEvent(
      eventId: ids.uuidV4(),
      occurredAtUtc: DateTime.utc(2026, 8, 21, 10),
      component: 'app',
      subsystem: 'connection',
      stage: 'complete',
      name: 'app.connection.attempt.finished',
      severity: ObservabilitySeverity.info,
      outcome: ObservabilityOutcome.succeeded,
      privacyClass: ObservabilityPrivacyClass.localOperational,
      correlation: OperationalCorrelation(
        traceId: ids.traceId(),
        spanId: ids.spanId(),
        parentSpanId: null,
        runId: ids.uuidV4(),
        attemptId: ids.uuidV4(),
        generation: 1,
        sequence: 1,
      ),
      build: _build(),
      error: null,
      attributes: const <String, Object?>{'phase': 'egress'},
    );

OperationalEvent _routingEvent(
  OperationalIdFactory ids, {
  required String stage,
}) =>
    OperationalEvent(
      eventId: ids.uuidV4(),
      occurredAtUtc: DateTime.utc(2026, 8, 21, 10),
      component: 'app',
      subsystem: 'routing',
      stage: stage,
      name: 'app.routing.selection.finished',
      severity: ObservabilitySeverity.info,
      outcome: ObservabilityOutcome.observed,
      privacyClass: ObservabilityPrivacyClass.localOperational,
      correlation: OperationalCorrelation(
        traceId: ids.traceId(),
        spanId: ids.spanId(),
        parentSpanId: null,
        runId: ids.uuidV4(),
        attemptId: ids.uuidV4(),
        generation: 1,
        sequence: 1,
      ),
      build: _build(),
      error: null,
      attributes: const <String, Object?>{'selected_app_count': 3},
    );

final class _MemoryWriter implements OperationalEventWriter {
  final List<OperationalEvent> events = <OperationalEvent>[];

  @override
  Future<void> appendBatch(List<SerializedOperationalEvent> records) async {
    events.addAll(records.map((record) => record.event));
  }
}
