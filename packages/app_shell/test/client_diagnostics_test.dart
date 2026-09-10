import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/app_shell.dart';
import 'package:pokrov_core_domain/core_domain.dart';
import 'package:pokrov_observability_contracts/observability_contracts.dart';
import 'package:pokrov_observability_runtime/observability_runtime.dart';
import 'package:pokrov_runtime_engine/runtime_engine.dart';
import 'package:pokrov_support_bundle/support_bundle.dart';

void main() {
  final now = DateTime.utc(2026, 8, 22, 12);

  test('verified runtime exposes four current proofs and stable message keys',
      () {
    final report = PokrovDiagnosticsPresenter.fromRuntime(
      hostPlatform: HostPlatform.android,
      routeMode: RouteMode.allExceptRu,
      snapshot: _snapshot(),
      statusLabel: 'Защищено',
      warpState: 'disabled',
      now: now,
      checkedAtUtc: now,
      appVersion: '1.2.0',
      buildNumber: '30',
      releaseChannel: 'store',
      candidateLabel: 'pokrov-1.2.0-test',
      encryptedDeliveryAvailable: true,
    );

    expect(report.summaryKey, PokrovDiagnosticMessageKey.verified);
    expect(
      report.summaryKey.wireKey,
      'diagnostics.summary.verified',
    );
    expect(
      report.causalKey.wireKey,
      'diagnostics.causal.proofs_complete',
    );
    expect(report.checkedAtUtc, now);
    expect(report.problemBookId, isNull);
    expect(report.errorCode, isNull);
    expect(report.safeActionKeys, isEmpty);
    expect(report.evidence.map((item) => item.key),
        <String>['tunnel', 'routes', 'dns', 'egress']);
    expect(
      report.evidence.map((item) => item.state),
      everyElement(PokrovDiagnosticEvidenceState.confirmed),
    );
  });

  test('explicit failures are not relabelled by unconfirmed DNS and egress',
      () {
    for (final entry in <String, String>{
      'default_network_unavailable': 'CONN-003',
      'runtime_start_failed': 'CORE-003',
      'core_egress_probe_unavailable': 'CONN-008',
      'runtime_failure': 'CORE-009',
      'default_network_interface_unresolved': 'ROUTE-005',
    }.entries) {
      final report = PokrovDiagnosticsPresenter.fromRuntime(
        hostPlatform: HostPlatform.android,
        routeMode: RouteMode.fullTunnel,
        snapshot: _snapshot(
          lastFailureKind: entry.key,
          hostHealth: RuntimeHostHealth.degraded,
          dnsState: RuntimeDiagnosticState.degraded,
          dnsReady: false,
          coreEgressValidated: false,
        ),
        statusLabel: 'Нужно внимание',
        warpState: 'disabled',
        now: now,
        appVersion: '1.2.0',
        buildNumber: '30',
        releaseChannel: 'store',
        candidateLabel: 'pokrov-1.2.0-test',
        encryptedDeliveryAvailable: false,
      );
      expect(report.errorCode, entry.value, reason: entry.key);
      expect(report.summaryKey, PokrovDiagnosticMessageKey.attention);
    }
  });

  test('degraded DNS maps only to evidence and a supported problem-book rule',
      () {
    const rawHostSummary =
        'resolver failed at private-host.example with raw provider detail';
    final report = PokrovDiagnosticsPresenter.fromRuntime(
      hostPlatform: HostPlatform.windows,
      routeMode: RouteMode.fullTunnel,
      snapshot: _snapshot(
        hostHealth: RuntimeHostHealth.degraded,
        dnsState: RuntimeDiagnosticState.degraded,
        dnsReady: false,
        coreEgressValidated: null,
        hostDiagnosticsSummary: rawHostSummary,
      ),
      statusLabel: 'Нужно внимание',
      warpState: 'unavailable',
      now: now,
      appVersion: '1.2.0',
      buildNumber: '30',
      releaseChannel: 'stable',
      candidateLabel: 'pokrov-1.2.0-test',
      encryptedDeliveryAvailable: false,
    );

    expect(report.summaryKey, PokrovDiagnosticMessageKey.attention);
    expect(report.causalKey, PokrovDiagnosticMessageKey.evidenceGap);
    expect(report.errorCode, 'DNS-002');
    expect(report.problemBookId, 'PB-05');
    expect(
      report.safeActionKeys,
      <String>['retry_verification', 'rotate_node', 'send_bundle'],
    );
    expect(
      report.evidence.singleWhere((item) => item.key == 'dns').state,
      PokrovDiagnosticEvidenceState.attention,
    );
    expect(
      <String?>[
        report.statusLabel,
        report.summaryKey.wireKey,
        report.causalKey.wireKey,
        report.errorCode,
        report.problemBookId,
      ].join(' '),
      isNot(contains(rawHostSummary)),
    );
  });

  test('bounded AWG category appears only in the diagnostics evidence list',
      () {
    final report = PokrovDiagnosticsPresenter.fromRuntime(
      hostPlatform: HostPlatform.android,
      routeMode: RouteMode.allExceptRu,
      snapshot: _snapshot(
        safeProtocolDiagnosticCode: 'handshake_retry',
        safeProtocolDiagnosticOccurrence: 3,
      ),
      statusLabel: 'Проверяется',
      warpState: 'disabled',
      now: now,
      appVersion: '1.2.0',
      buildNumber: '4046',
      releaseChannel: 'direct',
      candidateLabel: 'pokrov-1.2.0-test',
      encryptedDeliveryAvailable: true,
    );

    final protocol =
        report.evidence.singleWhere((item) => item.key == 'protocol');
    expect(protocol.label, 'AWG · handshake_retry · #3');
    expect(protocol.state, PokrovDiagnosticEvidenceState.pending);
    expect(report.summaryKey, PokrovDiagnosticMessageKey.verified);
  });

  test('summary package preview remains bounded and category-only', () {
    final report = PokrovDiagnosticsPresenter.fromRuntime(
      hostPlatform: HostPlatform.android,
      routeMode: RouteMode.selectedApps,
      snapshot: _snapshot(),
      statusLabel: 'Защищено',
      warpState: 'enabled',
      now: now,
      appVersion: '1.2.0',
      buildNumber: '30',
      releaseChannel: 'direct',
      candidateLabel: 'pokrov-1.2.0-test',
      encryptedDeliveryAvailable: true,
    );
    final preview = report.preparedBundle.preview;

    expect(preview.profile.name, 'summary');
    expect(preview.files, isNotEmpty);
    expect(preview.totalPlaintextBytes, greaterThan(0));
    expect(preview.totalPlaintextBytes, lessThanOrEqualTo(256 * 1024));
    expect(
      preview.categories.map((category) => category.name),
      <String>['build', 'network', 'redaction'],
    );
    expect(
      preview.files.every((file) => file.path.endsWith('.json')),
      isTrue,
    );
  });

  test('safe message keys resolve in Russian and English without raw details',
      () {
    expect(
      PokrovDiagnosticMessages.resolve(
        PokrovDiagnosticMessageKey.evidenceGap,
        languageCode: 'ru',
      ),
      'Одна или несколько обязательных проверок не подтверждены.',
    );
    expect(
      PokrovDiagnosticMessages.resolve(
        PokrovDiagnosticMessageKey.evidenceGap,
        languageCode: 'en-US',
      ),
      'One or more required checks are not verified.',
    );
  });

  test('phase timeline is bounded to closed events and marks reconnects', () {
    final report = PokrovDiagnosticsPresenter.fromRuntime(
      hostPlatform: HostPlatform.windows,
      routeMode: RouteMode.fullTunnel,
      snapshot: _snapshot(),
      statusLabel: 'Защищено',
      warpState: 'disabled',
      now: now,
      appVersion: '1.2.0',
      buildNumber: '30',
      releaseChannel: 'stable',
      candidateLabel: 'pokrov-1.2.0-test',
      encryptedDeliveryAvailable: true,
      timelineBreadcrumbs: <OperationalBreadcrumb>[
        _breadcrumb(
          name: 'app.connection.intent.received',
          generation: 1,
          sequence: 1,
          outcome: ObservabilityOutcome.started,
        ),
        _breadcrumb(
          name: 'app.connection.profile.started',
          generation: 1,
          sequence: 2,
          outcome: ObservabilityOutcome.started,
        ),
        _breadcrumb(
          name: 'app.connection.profile.finished',
          generation: 1,
          sequence: 3,
          outcome: ObservabilityOutcome.succeeded,
        ),
        _breadcrumb(
          name: 'app.connection.private-host.example',
          generation: 1,
          sequence: 4,
          outcome: ObservabilityOutcome.failed,
        ),
        _breadcrumb(
          name: 'app.connection.rollback.started',
          generation: 2,
          sequence: 1,
          outcome: ObservabilityOutcome.started,
        ),
        _breadcrumb(
          name: 'app.connection.rollback.finished',
          generation: 2,
          sequence: 2,
          outcome: ObservabilityOutcome.succeeded,
        ),
        _breadcrumb(
          name: 'app.connection.dns.finished',
          generation: 2,
          sequence: 3,
          outcome: ObservabilityOutcome.failed,
          errorCode: 'DNS-002',
        ),
      ],
    );

    expect(report.timelineAttempts, hasLength(2));
    expect(report.timelineAttempts.first.isReconnect, isFalse);
    expect(report.timelineAttempts.first.entries, hasLength(2));
    expect(
      report.timelineAttempts.first.entries.last.state,
      PokrovDiagnosticTimelineState.confirmed,
    );
    expect(report.timelineAttempts.last.isReconnect, isTrue);
    expect(
      report.timelineAttempts.last.entries.map((entry) => entry.phaseKey),
      <String>['rollback', 'dns'],
    );
    expect(report.timelineAttempts.last.entries.last.errorCode, 'DNS-002');
    expect(
      report.timelineAttempts
          .expand((attempt) => attempt.entries)
          .map((entry) => entry.label)
          .join(' '),
      isNot(contains('private-host')),
    );
  });

  testWidgets('screen renders catalog rule and sanitized safe actions',
      (tester) async {
    const rawHostSummary = 'private resolver/provider detail';
    final report = PokrovDiagnosticsPresenter.fromRuntime(
      hostPlatform: HostPlatform.android,
      routeMode: RouteMode.allExceptRu,
      snapshot: _snapshot(
        hostHealth: RuntimeHostHealth.degraded,
        dnsState: RuntimeDiagnosticState.degraded,
        dnsReady: false,
        hostDiagnosticsSummary: rawHostSummary,
      ),
      statusLabel: 'Нужно внимание',
      warpState: 'disabled',
      now: now,
      checkedAtUtc: now,
      appVersion: '1.2.0',
      buildNumber: '30',
      releaseChannel: 'direct',
      candidateLabel: 'pokrov-1.2.0-test',
      encryptedDeliveryAvailable: false,
      timelineBreadcrumbs: <OperationalBreadcrumb>[
        _breadcrumb(
          name: 'app.connection.dns.finished',
          generation: 2,
          sequence: 1,
          outcome: ObservabilityOutcome.failed,
          errorCode: 'DNS-002',
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          scaffoldBackgroundColor: Colors.transparent,
          canvasColor: const Color(0xFFF5F7F6),
        ),
        home: PokrovDiagnosticsScreen(
          initialReport: report,
          onRefresh: () async => report,
          onOpenProtection: () {},
          onOpenSupport: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<Scaffold>(
        find.byKey(const ValueKey('diagnostics-screen')),
      ).backgroundColor,
      const Color(0xFFF5F7F6),
    );
    await tester.drag(
      find.byKey(const ValueKey('diagnostics-scroll')),
      const Offset(0, -360),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('diagnostics-problem-book')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('diagnostics-safe-actions')),
      findsOneWidget,
    );
    expect(find.textContaining('Правило PB-05 · DNS-002'), findsOneWidget);
    expect(find.textContaining(rawHostSummary), findsNothing);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('diagnostics-timeline')),
      120,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('diagnostics-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(
      find.byKey(const ValueKey('diagnostics-timeline-2-dns')),
      findsOneWidget,
    );
  });

  testWidgets('screen shows same-build bands without exact cohort numbers',
      (tester) async {
    final report = PokrovDiagnosticsPresenter.fromRuntime(
      hostPlatform: HostPlatform.android,
      routeMode: RouteMode.allExceptRu,
      snapshot: _snapshot(),
      statusLabel: 'Защищено',
      warpState: 'disabled',
      now: now,
      checkedAtUtc: now,
      appVersion: '1.2.0',
      buildNumber: '4046',
      releaseChannel: 'local',
      candidateLabel: 'pokrov-1.2.0-local',
      encryptedDeliveryAvailable: false,
      releaseHealthBaseline: _availableBaseline(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PokrovDiagnosticsScreen(
          initialReport: report,
          onRefresh: () async => report,
          onOpenProtection: () {},
          onOpenSupport: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('diagnostics-release-health-baseline')),
      findsOneWidget,
    );
    final summary = tester.widget<Text>(
      find.byKey(
        const ValueKey('diagnostics-release-health-baseline-summary'),
      ),
    );
    expect(summary.data, contains('этой же сборки'));
    expect(summary.data, contains('Точные проценты'));
    expect(summary.data, isNot(contains('%')));
    expect(summary.data, isNot(contains('устройств:')));
  });

  testWidgets('encrypted export cancellation never claims a file was saved',
      (tester) async {
    final report = PokrovDiagnosticsPresenter.fromRuntime(
      hostPlatform: HostPlatform.windows,
      routeMode: RouteMode.allExceptRu,
      snapshot: _snapshot(),
      statusLabel: 'Нужно внимание',
      warpState: 'disabled',
      now: now,
      checkedAtUtc: now,
      appVersion: '1.2.0',
      buildNumber: '30',
      releaseChannel: 'direct',
      candidateLabel: 'pokrov-1.2.0-test',
      encryptedDeliveryAvailable: true,
    );
    PreparedSupportBundle? exported;
    await tester.pumpWidget(
      MaterialApp(
        home: PokrovDiagnosticsScreen(
          initialReport: report,
          onRefresh: () async => report,
          onOpenProtection: () {},
          onOpenSupport: () {},
          onExportBundle: (prepared) async {
            exported = prepared;
            return SupportBundleExportResult(
              state: SupportBundleExportState.cancelled,
              fileName: prepared.preview.diagnosticId + '.pokrov-support',
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('diagnostics-export-bundle')),
      180,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('diagnostics-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );

    await tester.tap(
      find.byKey(const ValueKey('diagnostics-export-bundle')),
    );
    await tester.pumpAndSettle();

    expect(exported, same(report.preparedBundle));
    expect(find.text('Экспорт отменен. Файл не создан.'), findsOneWidget);
    expect(find.textContaining('Зашифрованный пакет сохранен:'), findsNothing);
  });
}

ClientReleaseHealthBaseline _availableBaseline() {
  final build = OperationalBuildIdentity(
    appVersion: '1.2.0',
    buildNumber: '4046',
    channel: 'local',
    candidateLabel: 'pokrov-1.2.0-local',
    gitRevision: '0123456789abcdef0123456789abcdef01234567',
    coreVersion: null,
    coreAbi: null,
    platform: 'android',
    architecture: 'arm64-v8a',
  );
  return ClientReleaseHealthBaseline.parse(
    <String, Object?>{
      'schema_version': 1,
      'state': 'available',
      'scope': <String, Object?>{
        'app_version': build.appVersion,
        'build_number': build.buildNumber,
        'channel': build.channel,
        'candidate_label': build.candidateLabel,
        'git_revision': build.gitRevision,
        'core_abi': build.coreAbi,
        'platform': build.platform,
        'architecture': build.architecture,
      },
      'window': <String, Object?>{
        'kind': 'utc_week',
        'started_at': '2026-08-24T00:00:00Z',
        'ends_at': '2026-08-31T00:00:00Z',
      },
      'privacy': <String, Object?>{
        'minimum_contributors': 10,
        'minimum_satisfied': true,
        'contribution_cap_per_window': 64,
      },
      'baseline': <String, Object?>{
        'overall': <String, Object?>{
          'state': 'available',
          'sample_band': '30_to_99',
          'failure_rate_band': 'below_1_percent',
        },
        'families': <String, Object?>{
          for (final family in <String>['crash', 'connect', 'update'])
            family: <String, Object?>{
              'state': 'available',
              'sample_band': '30_to_99',
              'failure_rate_band': 'below_1_percent',
            },
        },
      },
    },
    expectedBuild: build,
  );
}

OperationalBreadcrumb _breadcrumb({
  required String name,
  required int generation,
  required int sequence,
  required ObservabilityOutcome outcome,
  String? errorCode,
}) =>
    OperationalBreadcrumb(
      eventId: 'event-$generation-$sequence',
      occurredAtUtc: DateTime.utc(2026, 8, 22, 12, 0, sequence),
      name: name,
      outcome: outcome,
      errorCode: errorCode,
      generation: generation,
      sequence: sequence,
    );

RuntimeSnapshot _snapshot({
  RuntimeHostHealth hostHealth = RuntimeHostHealth.healthy,
  RuntimeDiagnosticState dnsState = RuntimeDiagnosticState.healthy,
  RuntimeDiagnosticState uplinkState = RuntimeDiagnosticState.healthy,
  bool? dnsReady = true,
  bool? coreEgressValidated = true,
  String? hostDiagnosticsSummary,
  String? lastFailureKind,
  String? safeProtocolDiagnosticCode,
  int? safeProtocolDiagnosticOccurrence,
}) =>
    RuntimeSnapshot(
      hostPlatform: HostPlatform.android,
      lane: RuntimeLane.mobileArtifact,
      phase: RuntimePhase.running,
      artifactDirectory: '/host/runtime',
      coreBinaryPath: '/host/runtime/pokrov-core',
      helperBinaryPath: null,
      stagedConfigPath: '/host/runtime/profile.json',
      supportsLiveConnect: true,
      canInitialize: true,
      canConnect: true,
      message: 'Safe public runtime message.',
      hostHealth: hostHealth,
      dnsState: dnsState,
      uplinkState: uplinkState,
      hostDiagnosticsSummary: hostDiagnosticsSummary,
      lastFailureKind: lastFailureKind,
      dnsReady: dnsReady,
      coreEgressValidated: coreEgressValidated,
      coreEgressValidationRequired: true,
      safeProtocolDiagnosticCode: safeProtocolDiagnosticCode,
      safeProtocolDiagnosticOccurrence: safeProtocolDiagnosticOccurrence,
    );
