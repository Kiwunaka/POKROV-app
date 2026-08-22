import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/app_shell.dart';
import 'package:pokrov_diagnostics_collectors/diagnostics_collectors.dart';
import 'package:pokrov_support_bundle/support_bundle.dart';

void main() {
  final now = DateTime.utc(2026, 8, 22, 12);

  test('support mode requires consent, persists usage and rejects nonce replay',
      () async {
    final temporary = await Directory.systemTemp.createTemp('pokrov-mode-');
    addTearDown(() => temporary.delete(recursive: true));
    final fixture = await _activationFixture(now: now);
    final controller = _controller(
      temporary: temporary,
      now: () => now,
      signingPublicKey: fixture.signingPublicKey,
    );
    addTearDown(controller.dispose);
    await controller.initialize();

    await expectLater(
      controller.activate(fixture.activation, userConfirmed: false),
      throwsA(isA<SupportBundleFailure>()),
    );
    expect(controller.view.active, isFalse);

    await controller.activate(fixture.activation, userConfirmed: true);
    final prepared = const SupportBundleBuilder().prepare(
      snapshot: _snapshot(),
      profile: SupportDiagnosticProfile.extended,
      now: now,
      extendedPolicy: fixture.activation.policy,
    );
    await controller.registerBundle(prepared);
    expect(controller.view.active, isTrue);
    expect(controller.view.consumedBundles, 1);
    expect(controller.view.consumedBytes, greaterThan(0));

    final restored = _controller(
      temporary: temporary,
      now: () => now,
      signingPublicKey: fixture.signingPublicKey,
    );
    addTearDown(restored.dispose);
    await restored.initialize();
    expect(restored.view.active, isTrue);
    expect(restored.view.consumedBundles, 1);

    await restored.disable();
    await expectLater(
      restored.activate(fixture.activation, userConfirmed: true),
      throwsA(isA<SupportBundleFailure>()),
    );
    expect(restored.view.active, isFalse);
  });

  test('support mode fails closed on cap, expiry and corrupt local state',
      () async {
    final temporary = await Directory.systemTemp.createTemp('pokrov-mode-');
    addTearDown(() => temporary.delete(recursive: true));
    var clock = now;
    final fixture = await _activationFixture(
      now: now,
      maximumBundles: 1,
    );
    final controller = _controller(
      temporary: temporary,
      now: () => clock,
      signingPublicKey: fixture.signingPublicKey,
    );
    await controller.initialize();
    await controller.activate(fixture.activation, userConfirmed: true);
    await controller.registerBundle(
      const SupportBundleBuilder().prepare(
        snapshot: _snapshot(),
        profile: SupportDiagnosticProfile.extended,
        now: now,
        extendedPolicy: fixture.activation.policy,
      ),
    );
    await expectLater(
      controller.registerBundle(
        const SupportBundleBuilder().prepare(
          snapshot: _snapshot(connectionState: 'blocked'),
          profile: SupportDiagnosticProfile.extended,
          now: now.add(const Duration(seconds: 1)),
          extendedPolicy: fixture.activation.policy,
        ),
      ),
      throwsA(isA<SupportBundleFailure>()),
    );

    clock = now.add(const Duration(minutes: 21));
    expect(controller.view.active, isFalse);
    await expectLater(
      controller.registerBundle(
        const SupportBundleBuilder().prepare(
          snapshot: _snapshot(connectionState: 'blocked'),
          profile: SupportDiagnosticProfile.extended,
          now: now.add(const Duration(seconds: 2)),
          extendedPolicy: fixture.activation.policy,
        ),
      ),
      throwsA(isA<SupportBundleFailure>()),
    );

    controller.dispose();
    final state = File(
      '${temporary.path}${Platform.pathSeparator}support-mode-state-v1.json',
    );
    await state.writeAsString('{"schema_version":1,"session":"hostile"}');
    final corrupt = _controller(
      temporary: temporary,
      now: () => now,
      signingPublicKey: fixture.signingPublicKey,
    );
    addTearDown(corrupt.dispose);
    await corrupt.initialize();
    expect(corrupt.view.active, isFalse);
    expect(await state.exists(), isFalse);
  });

  testWidgets('persistent support-mode indicator exposes open and disable',
      (tester) async {
    var opened = false;
    var disabled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: PokrovPersistentSupportModeBanner(
          view: PokrovSupportModeView(
            active: true,
            expiresAt: now.add(const Duration(minutes: 20)),
            allowedCategories: const <DiagnosticCategory>[
              DiagnosticCategory.build,
              DiagnosticCategory.network,
            ],
            maximumTotalBytes: 2 * 1024 * 1024,
            consumedBytes: 128 * 1024,
            maximumBundles: 2,
            consumedBundles: 1,
          ),
          onOpenDiagnostics: () => opened = true,
          onDisable: () => disabled = true,
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('persistent-support-mode-banner')),
      findsOneWidget,
    );
    expect(find.textContaining('Режим поддержки до'), findsOneWidget);
    await tester.tap(find.textContaining('Режим поддержки до'));
    expect(opened, isTrue);
    await tester.tap(
      find.byKey(const ValueKey('persistent-support-mode-disable')),
    );
    expect(disabled, isTrue);
  });
}

PokrovSupportModeController _controller({
  required Directory temporary,
  required DateTime Function() now,
  required String signingPublicKey,
}) =>
    PokrovSupportModeController(
      signingPublicKeysById: <String, String>{
        'root-test': signingPublicKey,
      },
      platform: 'windows',
      appVersion: '1.2.0',
      buildNumber: '30',
      directoryResolver: () async => temporary,
      clock: now,
    );

Future<({SupportModeActivation activation, String signingPublicKey})>
    _activationFixture({
  required DateTime now,
  int maximumBundles = 2,
  String platform = 'windows',
  String appVersion = '1.2.0',
  String buildNumber = '30',
}) async {
  final algorithm = Ed25519();
  final keyPair = await algorithm.newKeyPair();
  final publicKey = await keyPair.extractPublicKey();
  final payload = <String, Object?>{
    'allowed_categories':
        DiagnosticCategory.values.map((category) => category.name).toList(),
    'allowed_collectors': const <String>[
      'build_summary',
      'crash_index',
      'network_summary',
      'operational_events',
      'redaction_report',
      'system_summary',
    ],
    'audience': <String, Object?>{
      'app_version': appVersion,
      'build_number': buildNumber,
      'platform': platform,
    },
    'expires_at': now.add(const Duration(minutes: 20)).toIso8601String(),
    'issued_at': now.toIso8601String(),
    'maximum_bundle_bytes': 1024 * 1024,
    'maximum_bundles': maximumBundles,
    'maximum_total_bytes': 2 * 1024 * 1024,
    'nonce': 'AAAAAAAAAAAAAAAAAAAAAA',
    'policy_id': 'spol-0123456789abcdef01234567',
    'profile': 'extended',
    'schema_version': 2,
    'type': 'pokrov.support.collection_policy',
  };
  final payloadBytes = utf8.encode(jsonEncode(payload));
  final signature = await algorithm.sign(payloadBytes, keyPair: keyPair);
  final envelope = <String, Object?>{
    'algorithm': 'Ed25519',
    'key_id': 'root-test',
    'payload_b64': _b64(payloadBytes),
    'schema_version': 1,
    'signature_b64': _b64(signature.bytes),
  };
  final signingPublicKey = _b64(publicKey.bytes);
  final policy = await SupportSignedContractVerifier(
    signingPublicKeysById: <String, String>{
      'root-test': signingPublicKey,
    },
  ).verifyCollectionPolicy(
    envelope,
    now: now,
    platform: platform,
    appVersion: appVersion,
    buildNumber: buildNumber,
  );
  return (
    activation: SupportModeActivation(
      signedPolicy: envelope,
      policy: policy,
    ),
    signingPublicKey: signingPublicKey,
  );
}

DiagnosticSnapshot _snapshot({String connectionState = 'degraded'}) =>
    DiagnosticSnapshot(
      build: DiagnosticBuildSummary(
        platform: 'windows',
        appVersion: '1.2.0',
        buildId: '30',
        channel: 'direct',
      ),
      system: DiagnosticSystemSummary(
        osFamily: 'windows',
        osVersion: '11 24H2',
        architecture: 'x64',
        locale: 'ru-RU',
      ),
      network: DiagnosticNetworkSummary(
        routeMode: 'all_except_ru',
        connectionState: connectionState,
        hostHealth: 'healthy',
        dnsState: 'healthy',
        egressState: 'failed',
        warpState: 'fallback',
      ),
      events: <DiagnosticEventRecord>[
        DiagnosticEventRecord(
          occurredAt: DateTime.utc(2026, 8, 22, 11, 59),
          subsystem: 'connection',
          stage: 'egress',
          outcome: 'failed',
          errorCode: 'EGRESS-001',
          durationMs: 1200,
        ),
      ],
      crashes: <DiagnosticCrashRecord>[
        DiagnosticCrashRecord(
          occurredAt: DateTime.utc(2026, 8, 22, 11),
          errorCode: 'CRASH-001',
          signature: '0123456789abcdef',
        ),
      ],
      removalCounts: const <DiagnosticRemovalReason, int>{
        DiagnosticRemovalReason.forbiddenField: 2,
      },
    );

String _b64(List<int> value) => base64UrlEncode(value).replaceAll('=', '');
