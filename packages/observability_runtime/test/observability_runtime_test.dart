import 'dart:convert';

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
        () => _event(1, attributes: const {'probe_stage': 'unknown_phase'}),
        throwsArgumentError,
      );
      expect(
        () => _event(1, attributes: const {'http_64k_failure': 'unknown_detail'}),
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

