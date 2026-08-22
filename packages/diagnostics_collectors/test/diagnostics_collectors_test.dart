import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_diagnostics_collectors/diagnostics_collectors.dart';

void main() {
  test('summary profile does not require an unavailable system snapshot', () {
    final collection = const BoundedDiagnosticsCollector().collect(
      snapshot: DiagnosticSnapshot(
        build: DiagnosticBuildSummary(
          platform: 'android',
          appVersion: '1.2.0+30',
          buildId: 'candidate-test',
          channel: 'direct',
        ),
        network: DiagnosticNetworkSummary(
          routeMode: 'all_except_ru',
          connectionState: 'disconnected',
          hostHealth: 'unknown',
          dnsState: 'unknown',
          egressState: 'unknown',
          warpState: 'disabled',
        ),
      ),
      profile: SupportDiagnosticProfile.summary,
    );

    expect(
      collection.files.map((file) => file.path),
      containsAll(<String>[
        'build/identity.json',
        'network/summary.json',
        'redaction/report.json',
      ]),
    );
    expect(
      collection.files.map((file) => file.path),
      isNot(contains('system/summary.json')),
    );
  });

  test(
    'collectors expose only fixed virtual files and bounded typed values',
    () {
      final collection = const BoundedDiagnosticsCollector().collect(
        snapshot: _snapshot(),
        profile: SupportDiagnosticProfile.standard,
      );

      expect(collection.files.map((file) => file.path), <String>[
        'build/identity.json',
        'events/recent.jsonl',
        'network/summary.json',
        'redaction/report.json',
        'system/summary.json',
      ]);
      expect(
        utf8.decode(
          collection.files
              .singleWhere((file) => file.path.startsWith('network'))
              .bytes,
        ),
        isNot(contains('example.com')),
      );
    },
  );

  test('profile and optional category boundaries are deterministic', () {
    final first = const BoundedDiagnosticsCollector().collect(
      snapshot: _snapshot(),
      profile: SupportDiagnosticProfile.crash,
      excludedOptionalCategories: const <DiagnosticCategory>{
        DiagnosticCategory.system,
      },
    );
    final second = const BoundedDiagnosticsCollector().collect(
      snapshot: _snapshot(),
      profile: SupportDiagnosticProfile.crash,
      excludedOptionalCategories: const <DiagnosticCategory>{
        DiagnosticCategory.system,
      },
    );

    expect(
      first.files.map((file) => utf8.decode(file.bytes)),
      second.files.map((file) => utf8.decode(file.bytes)),
    );
    expect(
      first.removalCounts[DiagnosticRemovalReason.optionalCategoryRemoved],
      1,
    );
    expect(first.files.any((file) => file.path.startsWith('system/')), isFalse);
  });

  test('arbitrary fields, paths and unbounded inputs are not accepted', () {
    expect(
      () => DiagnosticNetworkSummary(
        routeMode: '../../profile',
        connectionState: 'verified',
        hostHealth: 'healthy',
        dnsState: 'healthy',
        egressState: 'healthy',
        warpState: 'disabled',
      ),
      throwsArgumentError,
    );
    expect(
      () => CollectedDiagnosticFile(
        path: '../raw/config.json',
        category: DiagnosticCategory.system,
        bytes: utf8.encode('{}'),
      ),
      throwsArgumentError,
    );
  });

  test('collector owns copied bytes so caller mutation cannot race output', () {
    final source = utf8.encode('{"schema_version":1}');
    final file = CollectedDiagnosticFile(
      path: 'redaction/report.json',
      category: DiagnosticCategory.redaction,
      bytes: source,
    );

    source.fillRange(0, source.length, 0x78);

    expect(utf8.decode(file.bytes), '{"schema_version":1}');
    expect(() => file.bytes[0] = 0x78, throwsUnsupportedError);
  });

  test('production collector has no filesystem enumeration surface', () {
    final source = File('lib/diagnostics_collectors.dart').readAsStringSync();

    expect(source, isNot(contains("import 'dart:io'")));
    expect(source, isNot(matches(RegExp(r'\bFile\s*\('))));
    expect(source, isNot(matches(RegExp(r'\bDirectory\s*\('))));
    expect(source, isNot(matches(RegExp(r'\bLink\s*\('))));
    expect(source, isNot(contains('listSync(')));
  });
}

DiagnosticSnapshot _snapshot() => DiagnosticSnapshot(
      build: DiagnosticBuildSummary(
        platform: 'windows',
        appVersion: '1.2.0+30',
        buildId: 'local-test',
        channel: 'stable',
      ),
      system: DiagnosticSystemSummary(
        osFamily: 'windows',
        osVersion: '11 24H2',
        architecture: 'x64',
        locale: 'ru-RU',
      ),
      network: DiagnosticNetworkSummary(
        routeMode: 'full_tunnel',
        connectionState: 'degraded',
        hostHealth: 'healthy',
        dnsState: 'healthy',
        egressState: 'failed',
        warpState: 'fallback',
      ),
      events: <DiagnosticEventRecord>[
        DiagnosticEventRecord(
          occurredAt: DateTime.utc(2026, 8, 21, 10),
          subsystem: 'connection',
          stage: 'egress',
          outcome: 'failed',
          errorCode: 'EGRESS-001',
          durationMs: 1200,
        ),
      ],
      crashes: <DiagnosticCrashRecord>[
        DiagnosticCrashRecord(
          occurredAt: DateTime.utc(2026, 8, 21, 9),
          errorCode: 'CRASH-001',
          signature: '0123456789abcdef',
        ),
      ],
      removalCounts: const <DiagnosticRemovalReason, int>{
        DiagnosticRemovalReason.forbiddenField: 2,
      },
    );
