import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pokrov_core_domain/core_domain.dart';
import 'package:pokrov_diagnostics_collectors/diagnostics_collectors.dart';
import 'package:pokrov_observability_contracts/observability_contracts.dart';
import 'package:pokrov_observability_runtime/observability_runtime.dart';
import 'package:pokrov_runtime_engine/runtime_engine.dart';
import 'package:pokrov_support_bundle/support_bundle.dart';

import '../../../app_first_runtime_bootstrap.dart'
    show SupportBundleTransferFailure;
import '../../observability/release_health_baseline.dart';
import 'support_mode.dart';

bool pokrovWindowsCrashCollectionAllowed({
  required HostPlatform hostPlatform,
  required VerifiedSupportCollectionPolicy? policy,
  required DateTime now,
}) =>
    hostPlatform == HostPlatform.windows &&
    policy != null &&
    !now.isBefore(policy.issuedAt) &&
    now.isBefore(policy.expiresAt) &&
    policy.allowedCategories.contains(DiagnosticCategory.crashes) &&
    policy.allowedCollectors.contains('crash_index');

Future<List<DiagnosticCrashRecord>> collectPokrovWindowsCrashDiagnostics({
  required HostPlatform hostPlatform,
  required VerifiedSupportCollectionPolicy? policy,
  required DateTime now,
}) async {
  if (!pokrovWindowsCrashCollectionAllowed(
    hostPlatform: hostPlatform, policy: policy, now: now,
  )) return const [];
  final result = await const MethodChannel('space.pokrov/runtime_engine')
      .invokeMethod<Object?>('runtimeEngine.crashDiagnostics')
      .timeout(const Duration(seconds: 12));
  if (result is! List || result.length > 4) {
    throw const FormatException('Invalid native crash diagnostics');
  }
  return [
    for (final record in result) _nativeCrashRecord(record),
  ];
}

DiagnosticCrashRecord _nativeCrashRecord(Object? value) {
  if (value is! Map || value.length != 3 ||
      value['occurred_at_unix_ms'] is! int ||
      value['error_code'] is! String || value['signature'] is! String) {
    throw const FormatException('Invalid native crash record');
  }
  final milliseconds = value['occurred_at_unix_ms'] as int;
  if (milliseconds < 0 || milliseconds > 253402300799999) {
    throw const FormatException('Invalid native crash timestamp');
  }
  return DiagnosticCrashRecord(
    occurredAt: DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true),
    errorCode: value['error_code'] as String,
    signature: value['signature'] as String,
  );
}

enum PokrovDiagnosticMessageKey {
  verified('diagnostics.summary.verified'),
  checking('diagnostics.summary.checking'),
  attention('diagnostics.summary.attention'),
  disconnected('diagnostics.summary.disconnected'),
  blocked('diagnostics.summary.blocked'),
  proofsComplete('diagnostics.causal.proofs_complete'),
  evidenceGap('diagnostics.causal.evidence_gap'),
  awaitingEvidence('diagnostics.causal.awaiting_evidence'),
  noActiveAttempt('diagnostics.causal.no_active_attempt');

  const PokrovDiagnosticMessageKey(this.wireKey);

  final String wireKey;
}

enum PokrovDiagnosticEvidenceState { confirmed, pending, attention, unknown }

enum PokrovDiagnosticTimelineState { active, confirmed, attention, ended }

final class PokrovDiagnosticTimelineEntry {
  const PokrovDiagnosticTimelineEntry({
    required this.phaseKey,
    required this.label,
    required this.occurredAtUtc,
    required this.state,
    this.errorCode,
  });

  final String phaseKey;
  final String label;
  final DateTime occurredAtUtc;
  final PokrovDiagnosticTimelineState state;
  final String? errorCode;
}

final class PokrovDiagnosticTimelineAttempt {
  PokrovDiagnosticTimelineAttempt({
    required this.generation,
    required this.isReconnect,
    required List<PokrovDiagnosticTimelineEntry> entries,
  }) : entries = List<PokrovDiagnosticTimelineEntry>.unmodifiable(entries);

  final int generation;
  final bool isReconnect;
  final List<PokrovDiagnosticTimelineEntry> entries;
}

abstract final class PokrovDiagnosticMessages {
  static String resolve(
    PokrovDiagnosticMessageKey key, {
    required String languageCode,
  }) {
    final english = languageCode.toLowerCase().startsWith('en');
    return english ? _english(key) : _russian(key);
  }

  static String _russian(PokrovDiagnosticMessageKey key) => switch (key) {
        PokrovDiagnosticMessageKey.verified => 'Защита подтверждена',
        PokrovDiagnosticMessageKey.checking => 'Проверка продолжается',
        PokrovDiagnosticMessageKey.attention =>
          'Есть неподтвержденная проверка',
        PokrovDiagnosticMessageKey.disconnected => 'Активного подключения нет',
        PokrovDiagnosticMessageKey.blocked => 'Подключение не завершено',
        PokrovDiagnosticMessageKey.proofsComplete =>
          'Туннель, маршруты, DNS и выход через VPN подтверждены.',
        PokrovDiagnosticMessageKey.evidenceGap =>
          'Одна или несколько обязательных проверок не подтверждены.',
        PokrovDiagnosticMessageKey.awaitingEvidence =>
          'POKROV ожидает результаты обязательных проверок.',
        PokrovDiagnosticMessageKey.noActiveAttempt =>
          'Нет активной попытки подключения для причинной сводки.',
      };

  static String _english(PokrovDiagnosticMessageKey key) => switch (key) {
        PokrovDiagnosticMessageKey.verified => 'Protection verified',
        PokrovDiagnosticMessageKey.checking => 'Verification in progress',
        PokrovDiagnosticMessageKey.attention =>
          'A required check is not verified',
        PokrovDiagnosticMessageKey.disconnected => 'No active connection',
        PokrovDiagnosticMessageKey.blocked => 'Connection did not finish',
        PokrovDiagnosticMessageKey.proofsComplete =>
          'Tunnel, routes, DNS, and VPN egress are verified.',
        PokrovDiagnosticMessageKey.evidenceGap =>
          'One or more required checks are not verified.',
        PokrovDiagnosticMessageKey.awaitingEvidence =>
          'POKROV is waiting for required verification results.',
        PokrovDiagnosticMessageKey.noActiveAttempt =>
          'There is no active connection attempt to summarize.',
      };
}

final class PokrovDiagnosticEvidence {
  const PokrovDiagnosticEvidence({
    required this.key,
    required this.label,
    required this.state,
  });

  final String key;
  final String label;
  final PokrovDiagnosticEvidenceState state;
}

final class PokrovDiagnosticsReport {
  PokrovDiagnosticsReport({
    required this.statusLabel,
    required this.summaryKey,
    required this.causalKey,
    required this.checkedAtUtc,
    required List<PokrovDiagnosticEvidence> evidence,
    required this.preparedBundle,
    required this.supportCode,
    required this.encryptedDeliveryAvailable,
    this.crashDiagnosticsReady = true,
    required List<String> safeActionKeys,
    required List<PokrovDiagnosticTimelineAttempt> timelineAttempts,
    this.releaseHealthBaseline =
        const ClientReleaseHealthBaseline.unavailable(),
    this.problemBookId,
    this.errorCode,
  })  : evidence = List<PokrovDiagnosticEvidence>.unmodifiable(evidence),
        safeActionKeys = List<String>.unmodifiable(safeActionKeys),
        timelineAttempts = List<PokrovDiagnosticTimelineAttempt>.unmodifiable(
          timelineAttempts,
        );

  final String statusLabel;
  final PokrovDiagnosticMessageKey summaryKey;
  final PokrovDiagnosticMessageKey causalKey;
  final DateTime? checkedAtUtc;
  final List<PokrovDiagnosticEvidence> evidence;
  final PreparedSupportBundle preparedBundle;
  final String supportCode;
  final bool encryptedDeliveryAvailable;
  final bool crashDiagnosticsReady;
  final List<String> safeActionKeys;
  final List<PokrovDiagnosticTimelineAttempt> timelineAttempts;
  final ClientReleaseHealthBaseline releaseHealthBaseline;
  final String? problemBookId;
  final String? errorCode;

  PokrovDiagnosticsReport copyWith({
    DateTime? checkedAtUtc,
    ClientReleaseHealthBaseline? releaseHealthBaseline,
  }) =>
      PokrovDiagnosticsReport(
        statusLabel: statusLabel,
        summaryKey: summaryKey,
        causalKey: causalKey,
        checkedAtUtc: checkedAtUtc ?? this.checkedAtUtc,
        evidence: evidence,
        preparedBundle: preparedBundle,
        supportCode: supportCode,
        encryptedDeliveryAvailable: encryptedDeliveryAvailable,
        crashDiagnosticsReady: crashDiagnosticsReady,
        safeActionKeys: safeActionKeys,
        timelineAttempts: timelineAttempts,
        releaseHealthBaseline:
            releaseHealthBaseline ?? this.releaseHealthBaseline,
        problemBookId: problemBookId,
        errorCode: errorCode,
      );
}

abstract final class PokrovDiagnosticsPresenter {
  static PokrovDiagnosticsReport fromRuntime({
    required HostPlatform hostPlatform,
    required RouteMode routeMode,
    required RuntimeSnapshot? snapshot,
    required String statusLabel,
    required String warpState,
    required DateTime now,
    required String appVersion,
    required String buildNumber,
    required String releaseChannel,
    required String candidateLabel,
    required bool encryptedDeliveryAvailable,
    bool crashDiagnosticsReady = true,
    VerifiedSupportCollectionPolicy? supportModePolicy,
    DiagnosticSystemSummary? systemSummary,
    List<OperationalBreadcrumb> timelineBreadcrumbs = const [],
    List<DiagnosticCrashRecord> crashes = const [],
    DateTime? checkedAtUtc,
    ClientReleaseHealthBaseline releaseHealthBaseline =
        const ClientReleaseHealthBaseline.unavailable(),
  }) {
    final evidence = <PokrovDiagnosticEvidence>[
      PokrovDiagnosticEvidence(
        key: 'tunnel',
        label: 'Туннель',
        state: _tunnelState(snapshot),
      ),
      PokrovDiagnosticEvidence(
        key: 'routes',
        label: 'Маршруты и сеть',
        state: _runtimeState(
          snapshot?.uplinkState,
          active: snapshot?.phase == RuntimePhase.running,
        ),
      ),
      PokrovDiagnosticEvidence(
        key: 'dns',
        label: 'DNS',
        state: _dnsState(snapshot),
      ),
      PokrovDiagnosticEvidence(
        key: 'egress',
        label: 'Выход через VPN',
        state: _egressState(snapshot),
      ),
    ];
    final protocolDiagnosticCode = snapshot?.safeProtocolDiagnosticCode ?? '';
    final protocolDiagnosticOccurrence =
        snapshot?.safeProtocolDiagnosticOccurrence;
    if (protocolDiagnosticCode.isNotEmpty &&
        protocolDiagnosticOccurrence != null) {
      evidence.add(
        PokrovDiagnosticEvidence(
          key: 'protocol',
          label:
              'AWG · $protocolDiagnosticCode · #$protocolDiagnosticOccurrence',
          state: PokrovDiagnosticEvidenceState.pending,
        ),
      );
    }
    final summaryKey = _summaryKey(snapshot);
    final errorCode = _errorCode(snapshot);
    final problemBook = _problemBookFor(errorCode);
    final causalKey = switch (summaryKey) {
      PokrovDiagnosticMessageKey.verified =>
        PokrovDiagnosticMessageKey.proofsComplete,
      PokrovDiagnosticMessageKey.attention ||
      PokrovDiagnosticMessageKey.blocked =>
        PokrovDiagnosticMessageKey.evidenceGap,
      PokrovDiagnosticMessageKey.checking =>
        PokrovDiagnosticMessageKey.awaitingEvidence,
      _ => PokrovDiagnosticMessageKey.noActiveAttempt,
    };
    final prepared = preparePokrovClientSupportBundle(
      hostPlatform: hostPlatform,
      routeMode: routeMode,
      snapshot: snapshot,
      warpState: warpState,
      now: now,
      appVersion: appVersion,
      buildNumber: buildNumber,
      releaseChannel: releaseChannel,
      candidateLabel: candidateLabel,
      supportModePolicy: supportModePolicy,
      systemSummary: systemSummary,
      crashes: crashes,
      events: [
        if (supportModePolicy != null)
          for (final breadcrumb in timelineBreadcrumbs)
            if (_timelinePhase(breadcrumb.name) case final phase?)
              if (breadcrumb.outcome != ObservabilityOutcome.notApplicable)
                DiagnosticEventRecord(
                  occurredAt: breadcrumb.occurredAtUtc,
                  subsystem: 'connection',
                  stage: phase.$1,
                  outcome: switch (breadcrumb.outcome) {
                    ObservabilityOutcome.blocked ||
                    ObservabilityOutcome.degraded =>
                      'failed',
                    _ => breadcrumb.outcome.wireValue,
                  },
                  errorCode: breadcrumb.errorCode,
                ),
      ],
    );
    final supportCode = pokrovSupportDiagnosticCode(
      prepared: prepared,
      hostPlatform: hostPlatform,
      routeMode: routeMode,
      snapshot: snapshot,
      appVersion: appVersion,
      buildNumber: buildNumber,
      generatedAt: now,
    );
    return PokrovDiagnosticsReport(
      statusLabel: statusLabel,
      summaryKey: summaryKey,
      causalKey: causalKey,
      checkedAtUtc: checkedAtUtc,
      evidence: evidence,
      preparedBundle: prepared,
      supportCode: supportCode,
      encryptedDeliveryAvailable: encryptedDeliveryAvailable,
      crashDiagnosticsReady: crashDiagnosticsReady,
      safeActionKeys: problemBook?.safeActions ?? const <String>[],
      timelineAttempts: _timelineAttempts(timelineBreadcrumbs),
      releaseHealthBaseline: releaseHealthBaseline,
      problemBookId: problemBook?.id,
      errorCode: errorCode,
    );
  }

  static List<PokrovDiagnosticTimelineAttempt> _timelineAttempts(
    List<OperationalBreadcrumb> breadcrumbs,
  ) {
    final grouped = <int, List<OperationalBreadcrumb>>{};
    for (final breadcrumb in breadcrumbs) {
      if (!breadcrumb.name.startsWith('app.connection.') ||
          _timelinePhase(breadcrumb.name) == null) {
        continue;
      }
      grouped.putIfAbsent(breadcrumb.generation, () => []).add(breadcrumb);
    }
    final generations = grouped.keys.toList()..sort();
    final attempts = <PokrovDiagnosticTimelineAttempt>[];
    for (final generation in generations) {
      final source = grouped[generation]!;
      source.sort((left, right) => left.sequence.compareTo(right.sequence));
      final latestByPhase = <String, OperationalBreadcrumb>{};
      final phaseOrder = <String>[];
      for (final breadcrumb in source) {
        final phase = _timelinePhase(breadcrumb.name)!;
        if (!latestByPhase.containsKey(phase.$1)) {
          phaseOrder.add(phase.$1);
        }
        latestByPhase[phase.$1] = breadcrumb;
      }
      final entries = <PokrovDiagnosticTimelineEntry>[
        for (final phaseKey in phaseOrder)
          _timelineEntry(phaseKey, latestByPhase[phaseKey]!),
      ];
      if (entries.length > 16) {
        entries.removeRange(0, entries.length - 16);
      }
      attempts.add(
        PokrovDiagnosticTimelineAttempt(
          generation: generation,
          isReconnect: source.any(
            (item) => item.name == 'app.connection.rollback.started',
          ),
          entries: entries,
        ),
      );
    }
    return attempts.length <= 4
        ? attempts
        : attempts.sublist(attempts.length - 4);
  }

  static PokrovDiagnosticTimelineEntry _timelineEntry(
    String phaseKey,
    OperationalBreadcrumb breadcrumb,
  ) {
    final phase = _timelinePhase(breadcrumb.name)!;
    return PokrovDiagnosticTimelineEntry(
      phaseKey: phaseKey,
      label: phase.$2,
      occurredAtUtc: breadcrumb.occurredAtUtc.toUtc(),
      state: switch (breadcrumb.outcome) {
        ObservabilityOutcome.started => PokrovDiagnosticTimelineState.active,
        ObservabilityOutcome.succeeded ||
        ObservabilityOutcome.observed =>
          PokrovDiagnosticTimelineState.confirmed,
        ObservabilityOutcome.failed ||
        ObservabilityOutcome.blocked ||
        ObservabilityOutcome.degraded =>
          PokrovDiagnosticTimelineState.attention,
        _ => PokrovDiagnosticTimelineState.ended,
      },
      errorCode: breadcrumb.errorCode,
    );
  }

  static (String, String)? _timelinePhase(String name) => switch (name) {
        'app.connection.intent.received' => ('intent', 'Запрос'),
        'app.connection.profile.started' ||
        'app.connection.profile.finished' =>
          ('profile', 'Профиль'),
        'app.connection.core.started' || 'app.connection.core.finished' => (
            'core',
            'Ядро'
          ),
        'app.connection.tun.started' || 'app.connection.tun.finished' => (
            'tun',
            'Туннель'
          ),
        'app.connection.routes.started' || 'app.connection.routes.finished' => (
            'routes',
            'Маршруты'
          ),
        'app.connection.dns.started' || 'app.connection.dns.finished' => (
            'dns',
            'DNS'
          ),
        'app.connection.egress.started' || 'app.connection.egress.finished' => (
            'egress',
            'Выход через VPN'
          ),
        'app.connection.verified.started' ||
        'app.connection.verified.finished' =>
          ('verified', 'Проверка завершена'),
        'app.connection.rollback.started' ||
        'app.connection.rollback.finished' =>
          ('rollback', 'Восстановление'),
        'app.connection.stopped.started' ||
        'app.connection.stopped.finished' =>
          ('stopped', 'Остановка'),
        'app.connection.proof.observed' => ('proof', 'Доказательства'),
        'app.connection.attempt.finished' => ('result', 'Итог'),
        _ => null,
      };

  static PokrovDiagnosticMessageKey _summaryKey(RuntimeSnapshot? snapshot) {
    if (snapshot?.isCleanlyHealthy == true) {
      return PokrovDiagnosticMessageKey.verified;
    }
    if (snapshot?.hasDegradedHostDiagnostics == true ||
        snapshot?.dnsReady == false ||
        snapshot?.coreEgressValidated == false) {
      return PokrovDiagnosticMessageKey.attention;
    }
    if ((snapshot?.lastFailureKind ?? '').trim().isNotEmpty) {
      return PokrovDiagnosticMessageKey.blocked;
    }
    if (snapshot?.connectionPending == true ||
        snapshot?.phase == RuntimePhase.running) {
      return PokrovDiagnosticMessageKey.checking;
    }
    return PokrovDiagnosticMessageKey.disconnected;
  }

  static PokrovDiagnosticEvidenceState _tunnelState(
    RuntimeSnapshot? snapshot,
  ) {
    if (snapshot?.phase == RuntimePhase.running) {
      return PokrovDiagnosticEvidenceState.confirmed;
    }
    if (snapshot?.connectionPending == true) {
      return PokrovDiagnosticEvidenceState.pending;
    }
    if ((snapshot?.lastFailureKind ?? '').trim().isNotEmpty) {
      return PokrovDiagnosticEvidenceState.attention;
    }
    return PokrovDiagnosticEvidenceState.unknown;
  }

  static PokrovDiagnosticEvidenceState _runtimeState(
    RuntimeDiagnosticState? state, {
    required bool active,
  }) =>
      switch (state) {
        RuntimeDiagnosticState.healthy =>
          PokrovDiagnosticEvidenceState.confirmed,
        RuntimeDiagnosticState.degraded =>
          PokrovDiagnosticEvidenceState.attention,
        RuntimeDiagnosticState.unknown when active =>
          PokrovDiagnosticEvidenceState.pending,
        _ => PokrovDiagnosticEvidenceState.unknown,
      };

  static PokrovDiagnosticEvidenceState _dnsState(RuntimeSnapshot? snapshot) {
    if (snapshot?.dnsReady == false ||
        snapshot?.dnsState == RuntimeDiagnosticState.degraded) {
      return PokrovDiagnosticEvidenceState.attention;
    }
    if (snapshot?.dnsReady == true &&
        snapshot?.dnsState == RuntimeDiagnosticState.healthy) {
      return PokrovDiagnosticEvidenceState.confirmed;
    }
    if (snapshot?.phase == RuntimePhase.running) {
      return PokrovDiagnosticEvidenceState.pending;
    }
    return PokrovDiagnosticEvidenceState.unknown;
  }

  static PokrovDiagnosticEvidenceState _egressState(
    RuntimeSnapshot? snapshot,
  ) =>
      switch (snapshot?.coreEgressValidated) {
        true => PokrovDiagnosticEvidenceState.confirmed,
        false => PokrovDiagnosticEvidenceState.attention,
        null when snapshot?.phase == RuntimePhase.running =>
          PokrovDiagnosticEvidenceState.pending,
        _ => PokrovDiagnosticEvidenceState.unknown,
      };

  static String? _errorCode(RuntimeSnapshot? snapshot) {
    final failure = snapshot?.lastFailureKind?.trim() ?? '';
    if (failure.isNotEmpty && failure != 'notification_permission_denied') {
      return OperationalFailureMapper.connection(failure);
    }
    if (snapshot?.dnsReady == false ||
        snapshot?.dnsState == RuntimeDiagnosticState.degraded) {
      return 'DNS-002';
    }
    if (snapshot?.coreEgressValidated == false) {
      return 'EGRESS-001';
    }
    if (snapshot?.uplinkState == RuntimeDiagnosticState.degraded) {
      return 'ROUTE-003';
    }
    return failure.isEmpty
        ? null
        : OperationalFailureMapper.connection(failure);
  }

  static OperationalProblemBookEntry? _problemBookFor(String? errorCode) {
    if (errorCode == null) {
      return null;
    }
    for (final entry in OperationalProblemBook.entries) {
      if (entry.availability == ProblemBookAvailability.supported &&
          entry.errorCodes.contains(errorCode)) {
        return entry;
      }
    }
    return null;
  }
}

PreparedSupportBundle preparePokrovClientSupportBundle({
  required HostPlatform hostPlatform,
  required RouteMode routeMode,
  required RuntimeSnapshot? snapshot,
  required String warpState,
  required DateTime now,
  required String appVersion,
  required String buildNumber,
  required String releaseChannel,
  required String candidateLabel,
  VerifiedSupportCollectionPolicy? supportModePolicy,
  DiagnosticSystemSummary? systemSummary,
  List<DiagnosticEventRecord> events = const [],
  List<DiagnosticCrashRecord> crashes = const [],
}) {
  final platform = hostPlatform == HostPlatform.android ? 'android' : 'windows';
  final channel = hostPlatform == HostPlatform.android &&
          releaseChannel.toLowerCase() == 'store'
      ? 'store'
      : hostPlatform == HostPlatform.android
          ? 'direct'
          : 'stable';
  final connectionState = pokrovDiagnosticConnectionState(snapshot);
  return const SupportBundleBuilder().prepare(
    snapshot: DiagnosticSnapshot(
      system: systemSummary,
      events: events,
      crashes: crashes,
      build: DiagnosticBuildSummary(
        platform: platform,
        appVersion: appVersion,
        buildId: buildNumber,
        channel: channel,
      ),
      network: DiagnosticNetworkSummary(
        routeMode: pokrovDiagnosticRouteMode(routeMode),
        connectionState: connectionState,
        hostHealth: switch (snapshot?.hostHealth) {
          RuntimeHostHealth.healthy => 'healthy',
          RuntimeHostHealth.degraded => 'failed',
          _ => 'unknown',
        },
        dnsState: switch (snapshot?.dnsState) {
          RuntimeDiagnosticState.healthy => 'healthy',
          RuntimeDiagnosticState.degraded => 'failed',
          _ => 'unknown',
        },
        egressState: switch ((
          snapshot?.coreEgressValidated,
          snapshot?.uplinkState,
        )) {
          (false, _) || (_, RuntimeDiagnosticState.degraded) => 'failed',
          (true, RuntimeDiagnosticState.healthy) => 'healthy',
          (null, _) when snapshot?.phase == RuntimePhase.running => 'pending',
          _ => 'unknown',
        },
        warpState: warpState,
      ),
    ),
    profile: supportModePolicy == null
        ? SupportDiagnosticProfile.summary
        : SupportDiagnosticProfile.extended,
    now: now,
    extendedPolicy: supportModePolicy,
    excludedOptionalCategories: {
      if (supportModePolicy != null)
        for (final category in const [
          DiagnosticCategory.system,
          DiagnosticCategory.events,
          DiagnosticCategory.crashes,
        ])
          if (!supportModePolicy.allowedCategories.contains(category)) category,
    },
  );
}

String pokrovDiagnosticConnectionState(RuntimeSnapshot? snapshot) =>
    switch (snapshot) {
      RuntimeSnapshot(connectionPending: true) => 'connecting',
      RuntimeSnapshot(isCleanlyHealthy: true) => 'verified',
      RuntimeSnapshot(
        phase: RuntimePhase.running,
        hasDegradedHostDiagnostics: true,
      ) =>
        'degraded',
      RuntimeSnapshot(phase: RuntimePhase.running) => 'connecting',
      RuntimeSnapshot(lastFailureKind: final failure?)
          when failure.trim().isNotEmpty =>
        'blocked',
      _ => 'disconnected',
    };

String pokrovDiagnosticRouteMode(RouteMode routeMode) => switch (routeMode) {
      RouteMode.allExceptRu => 'all_except_ru',
      RouteMode.excludedApps => 'excluded_apps',
      RouteMode.fullTunnel => 'full_tunnel',
      RouteMode.selectedApps => 'selected_apps',
    };

String pokrovSupportDiagnosticCode({
  required PreparedSupportBundle prepared,
  required HostPlatform hostPlatform,
  required RouteMode routeMode,
  required RuntimeSnapshot? snapshot,
  required String appVersion,
  required String buildNumber,
  required DateTime generatedAt,
}) {
  final numericBuild = int.tryParse(buildNumber) ?? 0;
  final baseVersion = appVersion.split('+').first;
  return SupportDiagnosticCode.encode(
    diagnosticId: prepared.preview.diagnosticId,
    platform: hostPlatform == HostPlatform.android ? 'android' : 'windows',
    routeMode: pokrovDiagnosticRouteMode(routeMode),
    connectionState: pokrovDiagnosticConnectionState(snapshot),
    appVersion: '$baseVersion+$numericBuild',
    generatedAt: generatedAt,
  );
}

class PokrovDiagnosticsScreen extends StatefulWidget {
  const PokrovDiagnosticsScreen({
    required this.initialReport,
    required this.onRefresh,
    required this.onOpenProtection,
    required this.onOpenSupport,
    this.onReleaseHealthRefresh,
    this.onCreateCaseWithBundle,
    this.onLoadPendingBundles,
    this.onRetryPendingBundle,
    this.onExportBundle,
    this.initialSupportMode = const PokrovSupportModeView.inactive(),
    this.onActivateSupportMode,
    this.onDisableSupportMode,
    super.key,
  });

  final PokrovDiagnosticsReport initialReport;
  final Future<PokrovDiagnosticsReport> Function() onRefresh;
  final Future<ClientReleaseHealthBaseline> Function()? onReleaseHealthRefresh;
  final VoidCallback onOpenProtection;
  final VoidCallback onOpenSupport;
  final Future<SupportBundleDeliveryResult> Function(PreparedSupportBundle)?
      onCreateCaseWithBundle;
  final Future<List<String>> Function()? onLoadPendingBundles;
  final Future<SupportBundleDeliveryResult> Function(String)? onRetryPendingBundle;
  final Future<SupportBundleExportResult> Function(PreparedSupportBundle)?
      onExportBundle;
  final PokrovSupportModeView initialSupportMode;
  final Future<PokrovSupportModeView> Function()? onActivateSupportMode;
  final Future<void> Function()? onDisableSupportMode;

  @override
  State<PokrovDiagnosticsScreen> createState() =>
      _PokrovDiagnosticsScreenState();
}

class _PokrovDiagnosticsScreenState extends State<PokrovDiagnosticsScreen> {
  late PokrovDiagnosticsReport _report;
  bool _refreshing = false;
  bool _sending = false;
  String? _refreshError;
  SupportBundleDeliveryResult? _delivery;
  String? _deliveryError;
  List<String> _pendingBundleIds = const [];
  String? _pendingBundlesError;
  bool _exporting = false;
  SupportBundleExportResult? _export;
  String? _exportError;
  late PokrovSupportModeView _supportMode;
  bool _supportModeBusy = false;
  String? _supportModeError;

  @override
  void initState() {
    super.initState();
    _report = widget.initialReport;
    _supportMode = widget.initialSupportMode;
    unawaited(_refresh(includeReleaseHealth: false));
  }

  @override
  void didUpdateWidget(covariant PokrovDiagnosticsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _supportMode = widget.initialSupportMode;
    if (oldWidget.initialSupportMode.active != _supportMode.active ||
        oldWidget.initialSupportMode.expiresAt != _supportMode.expiresAt) {
      _report = widget.initialReport;
      unawaited(_refresh(includeReleaseHealth: false));
    }
  }

  Future<void> _activateSupportMode() async {
    final action = widget.onActivateSupportMode;
    if (action == null || _supportModeBusy) {
      return;
    }
    setState(() {
      _supportModeBusy = true;
      _supportModeError = null;
    });
    try {
      final view = await action();
      if (!mounted) {
        return;
      }
      setState(() {
        _supportMode = view;
      });
      await _refresh();
    } on Object {
      if (mounted) {
        setState(() {
          _supportModeError =
              'Режим поддержки не включен. Проверьте код и параметры сборки.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _supportModeBusy = false;
        });
      }
    }
  }

  Future<void> _disableSupportMode() async {
    final action = widget.onDisableSupportMode;
    if (action == null || _supportModeBusy) {
      return;
    }
    setState(() {
      _supportModeBusy = true;
      _supportModeError = null;
    });
    await action();
    if (!mounted) {
      return;
    }
    setState(() {
      _supportMode = const PokrovSupportModeView.inactive();
      _supportModeBusy = false;
    });
    await _refresh();
  }

  Future<void> _refresh({bool includeReleaseHealth = true}) async {
    if (_refreshing) {
      return;
    }
    setState(() {
      _refreshing = true;
      _refreshError = null;
    });
    try {
      var next = await widget.onRefresh();
      final releaseHealthRefresh = widget.onReleaseHealthRefresh;
      if (includeReleaseHealth && releaseHealthRefresh != null) {
        next = next.copyWith(
          releaseHealthBaseline: await releaseHealthRefresh(),
        );
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _report = next;
      });
    } on Object {
      if (mounted) {
        setState(() {
          _refreshError =
              'Не удалось обновить проверку. Показана последняя безопасная сводка.';
        });
      }
    } finally {
      await _loadPendingBundles();
      if (mounted) {
        setState(() {
          _refreshing = false;
        });
      }
    }
  }

  Future<void> _loadPendingBundles() async {
    final load = widget.onLoadPendingBundles;
    if (load == null || !mounted) {
      return;
    }
    try {
      final ids = await load();
      if (mounted) {
        setState(() {
          _pendingBundleIds = ids;
          _pendingBundlesError = null;
        });
      }
    } on Object {
      if (mounted) {
        setState(() {
          _pendingBundlesError =
              'Не удалось прочитать сохранённые отчёты. Обновите проверку.';
        });
      }
    }
  }

  Future<void> _createCase({String? savedDiagnosticId}) async {
    final action = widget.onCreateCaseWithBundle;
    if (_sending ||
        (savedDiagnosticId == null &&
            (!_report.crashDiagnosticsReady || _refreshing || _supportModeBusy)) ||
        (savedDiagnosticId == null
            ? action == null
            : widget.onRetryPendingBundle == null)) {
      return;
    }
    setState(() {
      _sending = true;
      _delivery = null;
      _deliveryError = null;
    });
    try {
      final result = savedDiagnosticId == null
          ? await action!(_report.preparedBundle)
          : await widget.onRetryPendingBundle!(savedDiagnosticId);
      if (!mounted) {
        return;
      }
      setState(() {
        _delivery = result;
      });
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _deliveryError = _bundleErrorMessage(
            error,
            'Не удалось передать зашифрованную диагностику. Повторите отправку сохранённого отчёта.',
          );
        });
      }
    } finally {
      await _loadPendingBundles();
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  Future<void> _exportBundle() async {
    final action = widget.onExportBundle;
    if (action == null || _exporting || !_report.crashDiagnosticsReady ||
        _refreshing || _supportModeBusy) {
      return;
    }
    setState(() {
      _exporting = true;
      _export = null;
      _exportError = null;
    });
    try {
      final result = await action(_report.preparedBundle);
      if (!mounted) {
        return;
      }
      setState(() {
        _export = result;
      });
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _exportError = _bundleErrorMessage(
            error,
            'Не удалось экспортировать зашифрованный пакет. Исходная диагностика на диск не записана.',
          );
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _exporting = false;
        });
      }
    }
  }

  String _bundleErrorMessage(Object error, String fallback) {
    final code = switch (error) {
      SupportBundleFailure failure => failure.code,
      SupportBundleTransferFailure failure => failure.code,
      _ => null,
    };
    return switch (code) {
      'support_mode_volume_exhausted' =>
        'Лимит режима поддержки исчерпан. Для нового расширенного отчёта нужен новый код от оператора. Сохранённые отчёты можно отправить повторно.',
      'support_mode_inactive' =>
        'Режим поддержки завершён. Обновите проверку или введите новый код от оператора.',
      'support_saved_bundle_missing' =>
        'Сохранённый отчёт больше не ожидает отправки. Обновите проверку.',
      'outbox_full' =>
        'Хранилище диагностики заполнено. Повторите отправку сохранённых отчётов.',
      'outbox_content_invalid' =>
        'Сохранённый отчёт повреждён. Он не отправлен и остаётся на устройстве.',
      _ => fallback,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final preview = _report.preparedBundle.preview;
    final safeActions = _report.safeActionKeys
        .map(_safeActionRu)
        .whereType<String>()
        .toList(growable: false);
    return Scaffold(
      key: const ValueKey('diagnostics-screen'),
      backgroundColor: theme.canvasColor,
      appBar: AppBar(
        title: const Text('Диагностика'),
        actions: [
          IconButton(
            key: const ValueKey('diagnostics-refresh-action'),
            tooltip: 'Обновить проверку',
            onPressed: _refreshing ? null : () => unawaited(_refresh()),
            icon: _refreshing
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          key: const ValueKey('diagnostics-scroll'),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            _DiagnosticsCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _summaryIcon(_report.summaryKey),
                        color: _summaryColor(colors, _report.summaryKey),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              PokrovDiagnosticMessages.resolve(
                                _report.summaryKey,
                                languageCode: 'ru',
                              ),
                              key: const ValueKey('diagnostics-summary'),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _report.statusLabel,
                              style: theme.textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _freshnessLabel(_report.checkedAtUtc),
                              key: const ValueKey('diagnostics-freshness'),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_refreshError case final error?) ...[
                    const SizedBox(height: 10),
                    Text(error, style: TextStyle(color: colors.error)),
                  ],
                ],
              ),
            ),
            if (_report.releaseHealthBaseline.state !=
                ClientReleaseHealthBaselineState.unavailable) ...[
              const SizedBox(height: 12),
              Text('Как у этой же сборки', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              _DiagnosticsCard(
                key: const ValueKey('diagnostics-release-health-baseline'),
                child: Text(
                  _releaseHealthBaselineRu(_report),
                  key: const ValueKey(
                    'diagnostics-release-health-baseline-summary',
                  ),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text('Доказательства', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            _DiagnosticsCard(
              child: Column(
                children: [
                  for (final item in _report.evidence) _EvidenceRow(item: item),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text('Что видит POKROV', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            _DiagnosticsCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    _report.supportCode,
                    key: const ValueKey('diagnostics-support-code'),
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 6),
                  OutlinedButton.icon(
                    key: const ValueKey('diagnostics-copy-support-code'),
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(text: _report.supportCode),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Код поддержки скопирован. Файл для него не загружается.',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text('Скопировать короткий код'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    preview.profile == SupportDiagnosticProfile.extended
                        ? 'Профиль: временный расширенный режим'
                        : 'Профиль: краткий',
                    key: const ValueKey('diagnostics-bundle-profile'),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    PokrovDiagnosticMessages.resolve(
                      _report.causalKey,
                      languageCode: 'ru',
                    ),
                    key: const ValueKey('diagnostics-causal-summary'),
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Сводка перечисляет только наблюдаемое и отсутствующее доказательство. Она не называет причину без подтверждения.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  if (_report.problemBookId case final problemId?) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Правило $problemId · ${_report.errorCode}',
                      key: const ValueKey('diagnostics-problem-book'),
                      style: theme.textTheme.labelMedium,
                    ),
                  ],
                  if (safeActions.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Безопасные действия: ${safeActions.join('; ')}.',
                      key: const ValueKey('diagnostics-safe-actions'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (_report.timelineAttempts.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Ход подключения', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              _DiagnosticsCard(
                key: const ValueKey('diagnostics-timeline'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var attemptIndex = 0;
                        attemptIndex < _report.timelineAttempts.length;
                        attemptIndex++) ...[
                      if (attemptIndex > 0) const SizedBox(height: 16),
                      _TimelineAttemptView(
                        attempt: _report.timelineAttempts[attemptIndex],
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text('Временный режим поддержки',
                style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            _DiagnosticsCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _supportMode.active
                        ? 'Включен до ${_supportMode.expiresAt?.toLocal().toString().substring(11, 16) ?? '—'}'
                        : 'Выключен',
                    key: const ValueKey('diagnostics-support-mode-status'),
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _supportMode.active
                        ? 'Категории: ${_supportMode.allowedCategories.map(_categoryRu).join(', ')}. Использовано ${_supportMode.consumedBytes} из ${_supportMode.maximumTotalBytes} байт и ${_supportMode.consumedBundles} из ${_supportMode.maximumBundles} пакетов.'
                        : 'Код выдаёт оператор для конкретного обращения, платформы и сборки. Режим всегда виден, не выполняет команды и отключится автоматически не позднее чем через 30 минут.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  if (_supportModeError case final error?) ...[
                    const SizedBox(height: 8),
                    Text(error, style: TextStyle(color: colors.error)),
                  ],
                  const SizedBox(height: 10),
                  if (_supportMode.active &&
                      widget.onDisableSupportMode != null)
                    OutlinedButton.icon(
                      key: const ValueKey('diagnostics-disable-support-mode'),
                      onPressed: _supportModeBusy ? null : _disableSupportMode,
                      icon: const Icon(Icons.stop_circle_outlined),
                      label: const Text('Выключить режим'),
                    )
                  else if (!_supportMode.active &&
                      widget.onActivateSupportMode != null)
                    OutlinedButton.icon(
                      key: const ValueKey('diagnostics-activate-support-mode'),
                      onPressed: _supportModeBusy ? null : _activateSupportMode,
                      icon: _supportModeBusy
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.support_agent_rounded),
                      label: const Text('Ввести одноразовый код'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text('Пакет поддержки', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            _DiagnosticsCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Категории: ${preview.categories.map(_categoryRu).join(', ')}',
                    key: const ValueKey('diagnostics-bundle-categories'),
                  ),
                  const SizedBox(height: 6),
                  Text(
                      'Файлов: ${preview.files.length} · ${preview.totalPlaintextBytes} байт'),
                  const SizedBox(height: 6),
                  Text(
                    'Удалено полей: ${preview.removedFieldCount}',
                    key: const ValueKey('diagnostics-redaction-count'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _report.encryptedDeliveryAvailable
                        ? 'Перед отправкой пакет шифруется на проверенный подписанный ключ. В локальном outbox хранится только .pokrov-support.'
                        : 'Подписанный ключ поддержки недоступен. Пакет не будет отправлен; можно открыть обычную поддержку.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (_pendingBundleIds.isNotEmpty) ...[
              const SizedBox(height: 12),
              _DiagnosticsCard(
                key: const ValueKey('diagnostics-pending-bundles'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ожидают отправки', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 6),
                    const Text(
                      'Эти отчёты уже зашифрованы. Повтор отправляет сохранённый файл без нового сбора диагностики.',
                    ),
                    for (final id in _pendingBundleIds) ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        key: ValueKey('diagnostics-retry-$id'),
                        onPressed: _sending || widget.onRetryPendingBundle == null
                            ? null
                            : () => _createCase(savedDiagnosticId: id),
                        icon: const Icon(Icons.upload_rounded),
                        label: Text('Повторить отправку · ${id.substring(5, 13)}'),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            if (_pendingBundlesError case final error?) ...[
              const SizedBox(height: 12),
              Text(error, style: TextStyle(color: colors.error)),
            ],
            if (_delivery case final delivery?) ...[
              const SizedBox(height: 12),
              _DiagnosticsCard(
                key: const ValueKey('diagnostics-delivery-result'),
                child: Text(
                  delivery.state == SupportBundleDeliveryState.queued
                      ? 'Обращение #${delivery.ticketId ?? '—'} создано. Зашифрованный пакет поставлен в очередь.'
                      : '${delivery.ticketId == null ? 'Отправка не завершена.' : 'Обращение #${delivery.ticketId} создано.'} Зашифрованный отчёт сохранён. Его можно отправить повторно.',
                ),
              ),
            ],
            if (_deliveryError case final error?) ...[
              const SizedBox(height: 12),
              Text(error, style: TextStyle(color: colors.error)),
            ],
            if (_export case final result?) ...[
              const SizedBox(height: 12),
              _DiagnosticsCard(
                key: const ValueKey('diagnostics-export-result'),
                child: Text(
                  result.state == SupportBundleExportState.exported
                      ? 'Зашифрованный пакет сохранен: ${result.fileName}'
                      : 'Экспорт отменен. Файл не создан.',
                ),
              ),
            ],
            if (_exportError case final error?) ...[
              const SizedBox(height: 12),
              Text(error, style: TextStyle(color: colors.error)),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const ValueKey('diagnostics-open-protection'),
              onPressed: widget.onOpenProtection,
              icon: const Icon(Icons.health_and_safety_outlined),
              label: const Text('Проверить и восстановить'),
            ),
            const SizedBox(height: 8),
            if (!_report.crashDiagnosticsReady) ...[
              const Text(
                'Сведения об авариях Windows ещё не прочитаны. Обновите проверку '
                'или выключите режим поддержки, чтобы отправить обычную сводку.',
                key: ValueKey('diagnostics-crashes-unavailable'),
              ),
              const SizedBox(height: 8),
            ],
            if (_report.encryptedDeliveryAvailable &&
                widget.onCreateCaseWithBundle != null)
              OutlinedButton.icon(
                key: const ValueKey('diagnostics-create-case-bundle'),
                onPressed: _sending || _refreshing || _supportModeBusy ||
                        !_report.crashDiagnosticsReady ? null : _createCase,
                icon: _sending
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.lock_outline_rounded),
                label: const Text('Создать обращение с пакетом'),
              ),
            if (_report.encryptedDeliveryAvailable &&
                widget.onExportBundle != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const ValueKey('diagnostics-export-bundle'),
                onPressed: _exporting || _refreshing || _supportModeBusy ||
                        !_report.crashDiagnosticsReady ? null : _exportBundle,
                icon: _exporting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_alt_rounded),
                label: const Text('Экспортировать .pokrov-support'),
              ),
            ],
            const SizedBox(height: 8),
            TextButton.icon(
              key: const ValueKey('diagnostics-open-support'),
              onPressed: widget.onOpenSupport,
              icon: const Icon(Icons.support_agent_rounded),
              label: const Text('Открыть поддержку'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiagnosticsCard extends StatelessWidget {
  const _DiagnosticsCard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: child,
    );
  }
}

class _TimelineAttemptView extends StatelessWidget {
  const _TimelineAttemptView({required this.attempt});

  final PokrovDiagnosticTimelineAttempt attempt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      key: ValueKey('diagnostics-timeline-attempt-${attempt.generation}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          attempt.isReconnect
              ? 'Переподключение #${attempt.generation}'
              : 'Попытка #${attempt.generation}',
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: 10),
        for (var index = 0; index < attempt.entries.length; index++)
          _TimelineEntryRow(
            entry: attempt.entries[index],
            generation: attempt.generation,
            isLast: index == attempt.entries.length - 1,
          ),
      ],
    );
  }
}

class _TimelineEntryRow extends StatelessWidget {
  const _TimelineEntryRow({
    required this.entry,
    required this.generation,
    required this.isLast,
  });

  final PokrovDiagnosticTimelineEntry entry;
  final int generation;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final tone = switch (entry.state) {
      PokrovDiagnosticTimelineState.active => colors.primary,
      PokrovDiagnosticTimelineState.confirmed => colors.tertiary,
      PokrovDiagnosticTimelineState.attention => colors.error,
      PokrovDiagnosticTimelineState.ended => colors.onSurfaceVariant,
    };
    final occurredAt = entry.occurredAtUtc.toLocal();
    final time = <int>[
      occurredAt.hour,
      occurredAt.minute,
      occurredAt.second,
    ].map((part) => part.toString().padLeft(2, '0')).join(':');
    final status = switch (entry.state) {
      PokrovDiagnosticTimelineState.active => 'выполняется',
      PokrovDiagnosticTimelineState.confirmed => 'готово',
      PokrovDiagnosticTimelineState.attention => 'нужно внимание',
      PokrovDiagnosticTimelineState.ended => 'завершено',
    };
    return Row(
      key: ValueKey(
        'diagnostics-timeline-$generation-${entry.phaseKey}',
      ),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 18,
          child: Column(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 28,
                  color: colors.outlineVariant,
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: entry.label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(
                    text: ' · $status · $time',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  if (entry.errorCode case final code?)
                    TextSpan(
                      text: ' · $code',
                      style: theme.textTheme.bodySmall?.copyWith(color: tone),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EvidenceRow extends StatelessWidget {
  const _EvidenceRow({required this.item});

  final PokrovDiagnosticEvidence item;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (icon, label, color) = switch (item.state) {
      PokrovDiagnosticEvidenceState.confirmed => (
          Icons.check_circle_outline_rounded,
          'Подтверждено',
          colors.primary
        ),
      PokrovDiagnosticEvidenceState.pending => (
          Icons.schedule_rounded,
          'Проверяется',
          colors.tertiary
        ),
      PokrovDiagnosticEvidenceState.attention => (
          Icons.error_outline_rounded,
          'Требует внимания',
          colors.error
        ),
      PokrovDiagnosticEvidenceState.unknown => (
          Icons.remove_circle_outline_rounded,
          'Нет данных',
          colors.onSurfaceVariant
        ),
    };
    return Padding(
      key: ValueKey('diagnostics-evidence-${item.key}'),
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(item.label)),
          const SizedBox(width: 10),
          Text(label,
              style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

String _freshnessLabel(DateTime? checkedAtUtc) {
  if (checkedAtUtc == null) {
    return 'Свежесть: проверка еще не выполнена';
  }
  final local = checkedAtUtc.toLocal();
  final time =
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  return 'Свежесть: проверено в $time';
}

String _releaseHealthBaselineRu(PokrovDiagnosticsReport report) {
  final baseline = report.releaseHealthBaseline;
  if (!baseline.canCompare) {
    return 'Сравнение появится, когда накопится достаточная анонимная выборка этой же сборки.';
  }
  final local = report.summaryKey == PokrovDiagnosticMessageKey.verified
      ? 'На этом устройстве обязательные проверки пройдены.'
      : 'На этом устройстве одна или несколько проверок требуют внимания.';
  final metric = baseline.data!.connect.isAvailable
      ? baseline.data!.connect
      : baseline.data!.overall;
  final cohort = switch (metric.failureRateBand!) {
    ClientReleaseHealthFailureRateBand.noneObserved ||
    ClientReleaseHealthFailureRateBand.belowOnePercent =>
      'У большинства устройств этой же сборки подключения проходят стабильно.',
    ClientReleaseHealthFailureRateBand.oneToBelowFivePercent =>
      'У этой же сборки встречаются редкие сбои подключения.',
    ClientReleaseHealthFailureRateBand.fiveToBelowTwentyPercent =>
      'У части устройств этой же сборки встречаются сбои подключения.',
    ClientReleaseHealthFailureRateBand.twentyPercentOrMore =>
      'У этой же сборки заметно больше сбоев подключения.',
  };
  return '$local $cohort Точные проценты и число устройств не показываются.';
}

IconData _summaryIcon(PokrovDiagnosticMessageKey key) => switch (key) {
      PokrovDiagnosticMessageKey.verified => Icons.verified_user_outlined,
      PokrovDiagnosticMessageKey.attention ||
      PokrovDiagnosticMessageKey.blocked =>
        Icons.warning_amber_rounded,
      _ => Icons.shield_outlined,
    };

Color _summaryColor(ColorScheme colors, PokrovDiagnosticMessageKey key) =>
    switch (key) {
      PokrovDiagnosticMessageKey.verified => colors.primary,
      PokrovDiagnosticMessageKey.attention ||
      PokrovDiagnosticMessageKey.blocked =>
        colors.error,
      _ => colors.onSurfaceVariant,
    };

String _categoryRu(DiagnosticCategory category) => switch (category) {
      DiagnosticCategory.build => 'сборка',
      DiagnosticCategory.system => 'система',
      DiagnosticCategory.network => 'сеть',
      DiagnosticCategory.events => 'события',
      DiagnosticCategory.crashes => 'сбои',
      DiagnosticCategory.redaction => 'очистка',
    };

String? _safeActionRu(String key) => switch (key) {
      'retry_verification' => 'повторить проверку',
      'rotate_node' => 'сменить локацию',
      'send_bundle' => 'передать пакет диагностики',
      'run_visible_route_test' => 'проверить маршрут',
      'change_route_mode' => 'сменить режим маршрутизации',
      'send_summary' => 'передать безопасную сводку',
      'stop_connection' => 'остановить подключение',
      'repair_dns' => 'восстановить DNS',
      'open_android_guidance' => 'открыть подсказки Android',
      'retry_connect' => 'повторить подключение',
      'retry_update' => 'повторить обновление',
      'use_official_channel' => 'использовать официальный канал',
      'contact_support' => 'обратиться в поддержку',
      _ => null,
    };
