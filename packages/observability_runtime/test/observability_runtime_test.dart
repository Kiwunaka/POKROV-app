import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_observability_contracts/observability_contracts.dart';
import 'package:pokrov_observability_runtime/observability_runtime.dart';

void main() {
  group('typed privacy contract', () {
    test('rejects unknown fields and privacy-mode widening', () {
      expect(
        () => _event(1, attributes: const {'destination': 'planted'}),
        throwsArgumentError,
      );
      expect(
        () => _event(
          1,
          privacyClass: ObservabilityPrivacyClass.releaseHealth,
          attributes: const {'bytes_in': 10},
        ),
        throwsArgumentError,
      );
      expect(
        () => OperationalErrorIdentity(
          code: 'DNS-999',
          origin: ObservabilityErrorOrigin.client,
        ),
        throwsArgumentError,
      );
    });

    test('allows only a bounded selected-app count in release health', () {
      expect(
        () => _event(
          1,
          privacyClass: ObservabilityPrivacyClass.releaseHealth,
          attributes: const {'selected_app_count': 128},
        ),
        returnsNormally,
      );
      expect(
        () => _event(
          1,
          privacyClass: ObservabilityPrivacyClass.releaseHealth,
          attributes: const {'selected_app_count': 129},
        ),
        throwsArgumentError,
      );
      expect(
        () => _event(
          1,
          privacyClass: ObservabilityPrivacyClass.releaseHealth,
          attributes: const {'package_name': 'org.example.app'},
        ),
        throwsArgumentError,
      );
    });

    test('planted secret corpus never passes serialized guard', () {
      const planted = <String>[
        'Bearer abcdefghijklmnopqrstuvwxyz',
        'vless://example.invalid/material',
        '-----BEGIN PRIVATE KEY-----',
        'sk-abcdefghijklmnopqrstuvwxyz123456',
        r'C:\Users\private\profile.json',
        '10.20.30.40',
      ];
      for (final value in planted) {
        expect(
          OperationalPrivacyGuard.containsForbiddenMaterial(value),
          isTrue,
          reason: value,
        );
      }
      final serialized = const OperationalEventSerializer().serialize(
        _event(1),
      );
      for (final value in planted) {
        expect(serialized.json, isNot(contains(value)));
      }
      expect(
        () => OperationalPrivacyGuard.validateSerialized(planted.join(' ')),
        throwsFormatException,
      );
    });

    test('generated redaction property corpus always fails closed', () {
      final generated = <String>[
        for (var index = 0; index < 128; index += 1) ...<String>[
          'Bearer token-${index.toRadixString(16).padLeft(32, 'a')}',
          'vless://user-$index@example.invalid:443?security=reality',
          '10.${index % 255}.${(index * 7) % 255}.${(index * 13) % 255}',
          'sk-${index.toRadixString(36).padLeft(32, 'z')}',
          r'C:\Users\owner-' '$index' r'\profile.json',
        ],
      ];

      for (final value in generated) {
        expect(
          OperationalPrivacyGuard.containsForbiddenMaterial(value),
          isTrue,
          reason: value,
        );
        expect(
          () => OperationalPrivacyGuard.validateSerialized(
            jsonEncode(<String, String>{'message': value}),
          ),
          throwsFormatException,
          reason: value,
        );
      }
    });

    test('safe config fingerprint is canonical and never returns source', () {
      final first = OperationalPrivacyGuard.safeConfigFingerprint(
        '{"b":2,"a":{"z":1,"y":0}}',
      );
      final second = OperationalPrivacyGuard.safeConfigFingerprint(
        '{"a":{"y":0,"z":1},"b":2}',
      );
      expect(first, second);
      expect(first, matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(first, isNot(contains('"b"')));
      expect(
        OperationalPrivacyGuard.sanitizePath(r'C:\Users\alice\x'),
        '<local-path>',
      );
      expect(OperationalPrivacyGuard.sanitizeLocalIdentity('alice'), '<local>');
    });
  });

  group('bounded queue and dispatcher', () {
    test('fatal and security records evict lower-priority traffic', () {
      final queue = BoundedOperationalEventQueue(maxEvents: 3, maxBytes: 20000);
      final serializer = const OperationalEventSerializer();
      expect(
        queue.tryAdd(
          serializer.serialize(
            _event(1, severity: ObservabilitySeverity.trace),
          ),
        ),
        isTrue,
      );
      expect(
        queue.tryAdd(
          serializer.serialize(
            _event(2, severity: ObservabilitySeverity.debug),
          ),
        ),
        isTrue,
      );
      expect(queue.tryAdd(serializer.serialize(_event(3))), isTrue);
      expect(
        queue.tryAdd(
          serializer.serialize(
            _event(
              4,
              subsystem: 'security',
              severity: ObservabilitySeverity.fatal,
              outcome: ObservabilityOutcome.failed,
              errorCode: 'SEC-001',
            ),
          ),
        ),
        isTrue,
      );

      final retained = queue.takeBatch().map((record) => record.event).toList();
      expect(retained.map((event) => event.correlation.sequence), [2, 3, 4]);
      expect(retained.last.isSecurity, isTrue);
      expect(
        queue.snapshot().droppedBySeverity[ObservabilitySeverity.trace],
        1,
      );
    });

    test('emit path never waits for a blocked writer', () async {
      final gate = Completer<void>();
      final writer = _TrackingWriter(gate: gate);
      final fence = OperationalSequenceFence()..activateGeneration(1);
      final dispatcher = OperationalEventDispatcher(
        writer: writer,
        queue: BoundedOperationalEventQueue(
          maxEvents: 2048,
          maxBytes: 8 * 1024 * 1024,
        ),
        sequenceFence: fence,
      );

      for (var sequence = 0; sequence < 1000; sequence += 1) {
        expect(
          dispatcher.emit(_event(sequence)),
          OperationalEmitResult.accepted,
        );
      }
      await Future<void>.delayed(Duration.zero);
      expect(writer.activeWrites, 1);
      expect(writer.completedWrites, 0);
      gate.complete();
      await dispatcher.flush();
      expect(writer.maximumConcurrentWrites, 1);
      expect(writer.records, hasLength(1000));
    });

    test('generation and sequence fence rejects stale callbacks', () async {
      final writer = _TrackingWriter();
      final fence = OperationalSequenceFence()..activateGeneration(3);
      final dispatcher = OperationalEventDispatcher(
        writer: writer,
        sequenceFence: fence,
      );

      expect(
        dispatcher.emit(_event(1, generation: 2)),
        OperationalEmitResult.rejectedAsStale,
      );
      expect(
        dispatcher.emit(_event(1, generation: 3)),
        OperationalEmitResult.accepted,
      );
      expect(
        dispatcher.emit(_event(1, generation: 3)),
        OperationalEmitResult.rejectedAsStale,
      );
      fence.activateGeneration(4);
      expect(
        dispatcher.emit(_event(0, generation: 4)),
        OperationalEmitResult.accepted,
      );
      await dispatcher.flush();
      expect(writer.records, hasLength(2));
      expect(dispatcher.snapshot().rejectedAsStale, 2);
    });

    test('breadcrumb and security rings stay separate from disk pressure', () {
      final breadcrumbs = OperationalBreadcrumbRing(capacity: 2);
      final security = OperationalSecurityRing(capacity: 2);
      final normal = _event(1);
      final fatal = _event(
        2,
        subsystem: 'security',
        severity: ObservabilitySeverity.fatal,
        outcome: ObservabilityOutcome.failed,
        errorCode: 'SEC-002',
      );
      breadcrumbs.add(normal);
      breadcrumbs.add(fatal);
      breadcrumbs.add(_event(3));
      security.add(normal);
      security.add(fatal);

      expect(breadcrumbs.snapshot().map((item) => item.sequence), [2, 3]);
      expect(security.snapshot().single.errorCode, 'SEC-002');
    });

    test('writer failure is observable without recursive emission', () async {
      final fence = OperationalSequenceFence()..activateGeneration(1);
      final dispatcher = OperationalEventDispatcher(
        writer: _FailingWriter(),
        sequenceFence: fence,
      );
      expect(dispatcher.emit(_event(1)), OperationalEmitResult.accepted);
      await dispatcher.flush();
      expect(dispatcher.snapshot().writerErrors, 1);
      expect(dispatcher.snapshot().queue.depth, 0);
    });
  });

  group('rotating JSONL store', () {
    test('platform policies are exactly 24 MiB and 64 MiB', () {
      expect(
        OperationalStoragePolicy.forPlatform(
          OperationalStoragePlatform.android,
        ).totalBytes,
        24 * 1024 * 1024,
      );
      expect(
        OperationalStoragePolicy.forPlatform(
          OperationalStoragePlatform.windows,
        ).totalBytes,
        64 * 1024 * 1024,
      );
    });

    test('rotation retains at most two bounded generations', () async {
      final root = await Directory.systemTemp.createTemp(
        'pokrov-observability-rotation-',
      );
      addTearDown(() => root.delete(recursive: true));
      final policy = OperationalStoragePolicy.forTest(
        totalBytes: 8192,
        segmentBytes: 4096,
      );
      final store = RotatingOperationalJsonlStore(
        directory: root,
        policy: policy,
      );
      final serializer = const OperationalEventSerializer();
      final records = <SerializedOperationalEvent>[
        for (var index = 0; index < 40; index += 1)
          serializer.serialize(_event(index)),
      ];

      for (final record in records) {
        await store.appendBatch([record]);
      }
      final files = await root
          .list()
          .where((entity) => entity is File)
          .cast<File>()
          .toList();
      expect(files, hasLength(2));
      expect(files.map((file) => file.path), contains(store.currentFile.path));
      expect(files.map((file) => file.path), contains(store.previousFile.path));
      expect(
        await store.currentFile.length(),
        lessThanOrEqualTo(policy.segmentBytes),
      );
      expect(
        await store.previousFile.length(),
        lessThanOrEqualTo(policy.segmentBytes),
      );
      expect(
        await store.currentFile.length() + await store.previousFile.length(),
        lessThanOrEqualTo(policy.totalBytes),
      );
      expect(store.rotations, greaterThan(0));
    });

    test(
      'crash-truncated tail is ignored and repaired before append',
      () async {
        final root = await Directory.systemTemp.createTemp(
          'pokrov-observability-tail-',
        );
        addTearDown(() => root.delete(recursive: true));
        final store = RotatingOperationalJsonlStore(
          directory: root,
          policy: OperationalStoragePolicy.forTest(
            totalBytes: 8192,
            segmentBytes: 4096,
          ),
        );
        await root.create(recursive: true);
        await store.currentFile.writeAsString('{"valid":true}\n{"partial":');

        final before = await RotatingOperationalJsonlStore.readValidRecords(
          store.currentFile,
        );
        expect(before.records, [
          <String, Object?>{'valid': true},
        ]);
        expect(before.truncatedTailIgnored, isTrue);

        await store.initialize();
        expect(await store.currentFile.readAsString(), '{"valid":true}\n');
        expect(store.truncatedTailRecoveries, 1);
      },
    );
  });

  group('legacy translation', () {
    test('runtime JSONL translates only allowlisted complete records',
        () async {
      final root = await Directory.systemTemp.createTemp(
        'pokrov-observability-legacy-runtime-',
      );
      addTearDown(() => root.delete(recursive: true));
      final file = File('${root.path}${Platform.pathSeparator}runtime.jsonl');
      await file.writeAsString(
        '${jsonEncode({
              'at': '2026-08-21T12:00:00Z',
              'platform': 'windows',
              'event': 'egress',
              'outcome': 'failed',
              'phase': 'configStaged',
              'attempt': 3,
              'failure_kind': 'desktop_tun_egress_probe_failed'
            })}\n'
        '${jsonEncode({
              'at': '2026-08-21T12:00:01Z',
              'platform': 'windows',
              'event': 'egress',
              'outcome': 'failed',
              'raw_config': 'planted'
            })}\n'
        '{"partial":',
      );

      final result = await LegacyOperationalJournalReader.readRuntimeJsonl(
        file,
        _legacyContext(),
      );
      expect(result.events, hasLength(1));
      expect(result.events.single.error?.code, 'EGRESS-001');
      expect(result.events.single.attributes, {
        'phase': 'egress',
        'retry_count': 3,
        'egress_ready': false,
      });
      expect(result.skippedRecords, 1);
      expect(result.truncatedTailIgnored, isTrue);
      final serialized = const OperationalEventSerializer()
          .serialize(result.events.single)
          .json;
      expect(serialized, isNot(contains('failure_kind')));
      expect(serialized, isNot(contains('raw_config')));
    });

    test('Windows service journal translates bounded runtime phases', () async {
      final root = await Directory.systemTemp.createTemp(
        'pokrov-observability-legacy-service-',
      );
      addTearDown(() => root.delete(recursive: true));
      final file = File('${root.path}${Platform.pathSeparator}service.log');
      await file.writeAsString(
        'POKROV_SERVICE_EVENT_V1|133000000000000000|7|runtime_dns_apply|failed|none|none|0123456789abcdef0123456789abcdef\n'
        'POKROV_SERVICE_EVENT_V1|133000000000000001|8|service_running|succeeded|none|none|none\n',
      );

      final result =
          await LegacyOperationalJournalReader.readWindowsServiceJournal(
        file,
        _legacyContext(),
      );
      expect(result.events, hasLength(1));
      expect(result.events.single.component, 'windows_service');
      expect(result.events.single.error?.code, 'WIN-DNS-001');
      expect(
        result.events.single.correlation.traceId,
        '0123456789abcdef0123456789abcdef',
      );
      expect(result.skippedRecords, 1);
      expect(result.malformedRecords, 0);
    });

    test('Core ABI records preserve correlation and reject raw codes',
        () async {
      final root = await Directory.systemTemp.createTemp(
        'pokrov-observability-core-abi-',
      );
      addTearDown(() => root.delete(recursive: true));
      final file = File('${root.path}${Platform.pathSeparator}service.log');
      const runId = '018f4f2a-6d58-4c11-8c27-4fb77bd28c15';
      const attemptId = '57ba1c00-f8a9-4b76-a3dc-d44a6d7cff33';
      await file.writeAsString(
        'POKROV_CORE_EVENT_V1|1|1|2026-08-21T12:00:00Z|$runId|$attemptId|7|4|core.runtime.start|core|start|error|failed|TRANSPORT-001|core_start\n'
        'POKROV_CORE_EVENT_V1|1|1|2026-08-21T12:00:01Z|$runId|$attemptId|7|5|core.runtime.start|core|start|error|failed|TRANSPORT-002|core_start\n'
        'POKROV_CORE_EVENT_V1|1|1|2026-08-21T12:00:02Z|$runId|$attemptId|7|6|core.runtime.start|core|start|error|failed|TRANSPORT-003|core_start\n'
        'POKROV_CORE_EVENT_V1|1|1|2026-08-21T12:00:03Z|$runId|$attemptId|7|7|core.runtime.start|core|start|error|failed|TRANSPORT-004|core_start\n'
        'POKROV_CORE_EVENT_V1|1|1|2026-08-21T12:00:03Z|$runId|$attemptId|7|8|core.egress.probe|egress|verify|error|failed|TRANSPORT-005|egress\n'
        'POKROV_CORE_EVENT_V1|1|1|2026-08-21T12:00:03Z|$runId|$attemptId|7|9|core.egress.probe|egress|verify|error|failed|TRANSPORT-006|egress\n'
        'POKROV_CORE_EVENT_V1|1|1|2026-08-21T12:00:03Z|$runId|$attemptId|7|10|core.egress.probe|egress|verify|error|failed|TRANSPORT-007|egress\n'
        'POKROV_CORE_EVENT_V1|1|1|2026-08-21T12:00:03Z|$runId|$attemptId|7|11|core.egress.probe|egress|verify|error|failed|DNS-002|egress\n'
        'POKROV_CORE_EVENT_V1|1|1|2026-08-21T12:00:04Z|$runId|$attemptId|7|12|core.runtime.start|core|start|error|failed|https://private.example.test?token=secret|core_start\n'
        'POKROV_CORE_EVENT_V1|1|1|2026-08-21T12:00:05Z|$runId|$attemptId|7|13|core.raw.line|core|start|error|failed|CORE-006|core_start\n',
      );

      final result =
          await LegacyOperationalJournalReader.readWindowsServiceJournal(
        file,
        _legacyContext(),
      );
      expect(result.events, hasLength(8));
      final event = result.events.first;
      expect(event.component, 'core');
      expect(
        result.events.map((value) => value.error?.code),
        <String?>[
          'TRANSPORT-001',
          'TRANSPORT-002',
          'TRANSPORT-003',
          'TRANSPORT-004',
          'TRANSPORT-005',
          'TRANSPORT-006',
          'TRANSPORT-007',
          'DNS-002',
        ],
      );
      expect(event.correlation.runId, runId);
      expect(event.correlation.attemptId, attemptId);
      expect(event.correlation.generation, 7);
      expect(event.correlation.sequence, 4);
      expect(result.skippedRecords, 2);
      expect(
        const OperationalEventSerializer().serialize(event).json,
        isNot(contains('private.example.test')),
      );
    });
  });
}

OperationalBuildIdentity _build() => OperationalBuildIdentity(
      appVersion: '1.2.0',
      buildNumber: '120',
      channel: 'local',
      candidateLabel: 'pokrov-1.2.0-local',
      gitRevision: '1' * 40,
      coreVersion: '1.0.3',
      coreAbi: 2,
      platform: 'windows',
      architecture: 'x64',
    );

OperationalEvent _event(
  int sequence, {
  int generation = 1,
  String subsystem = 'connection',
  ObservabilitySeverity severity = ObservabilitySeverity.info,
  ObservabilityOutcome outcome = ObservabilityOutcome.observed,
  ObservabilityPrivacyClass privacyClass =
      ObservabilityPrivacyClass.localOperational,
  String? errorCode,
  Map<String, Object?> attributes = const {'phase': 'core'},
}) {
  final suffix = sequence.toRadixString(16).padLeft(12, '0');
  return OperationalEvent(
    eventId: '018f4f86-6a0b-4d3f-8f14-$suffix',
    occurredAtUtc: DateTime.utc(
      2026,
      8,
      21,
      12,
    ).add(Duration(milliseconds: sequence)),
    component: subsystem == 'security' ? 'app' : 'windows_host',
    subsystem: subsystem,
    stage: 'run',
    name: subsystem == 'security'
        ? 'security.redaction.violation'
        : 'connection.transition.observed',
    severity: severity,
    outcome: outcome,
    privacyClass: privacyClass,
    correlation: OperationalCorrelation(
      traceId: '0' * 32,
      spanId: sequence.toRadixString(16).padLeft(16, '0'),
      parentSpanId: null,
      runId: '018f4f86-6a0b-4d3f-8f14-000000000001',
      attemptId: '018f4f86-6a0b-4d3f-8f14-000000000002',
      generation: generation,
      sequence: sequence,
    ),
    build: _build(),
    error: errorCode == null
        ? null
        : OperationalErrorIdentity(
            code: errorCode,
            origin: ObservabilityErrorOrigin.client,
          ),
    attributes: attributes,
  );
}

LegacyTranslationContext _legacyContext() => LegacyTranslationContext(
      build: _build(),
      traceId: '0' * 32,
      runId: '018f4f86-6a0b-4d3f-8f14-000000000001',
      attemptId: '018f4f86-6a0b-4d3f-8f14-000000000002',
      generation: 1,
      firstSequence: 100,
      eventIdFactory: (sequence) =>
          '018f4f86-6a0b-4d3f-8f14-${sequence.toRadixString(16).padLeft(12, '0')}',
    );

final class _TrackingWriter implements OperationalEventWriter {
  _TrackingWriter({this.gate});

  final Completer<void>? gate;
  final List<SerializedOperationalEvent> records = [];
  int activeWrites = 0;
  int maximumConcurrentWrites = 0;
  int completedWrites = 0;

  @override
  Future<void> appendBatch(List<SerializedOperationalEvent> batch) async {
    activeWrites += 1;
    if (activeWrites > maximumConcurrentWrites) {
      maximumConcurrentWrites = activeWrites;
    }
    await gate?.future;
    records.addAll(batch);
    activeWrites -= 1;
    completedWrites += 1;
  }
}

final class _FailingWriter implements OperationalEventWriter {
  @override
  Future<void> appendBatch(List<SerializedOperationalEvent> records) async {
    throw const FileSystemException('synthetic writer failure');
  }
}
