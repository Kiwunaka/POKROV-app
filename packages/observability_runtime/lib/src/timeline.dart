import 'package:pokrov_observability_contracts/observability_contracts.dart';

import 'correlation_scope.dart';
import 'dispatcher.dart';
import 'ids.dart';
import 'model.dart';

enum OperationalTimelinePhase {
  bootstrap,
  profile,
  core,
  tun,
  routes,
  dns,
  egress,
  verified,
  rollback,
  stopped,
}

enum OperationalTerminalKind {
  succeeded,
  cancelled,
  superseded,
  timeout,
  crash,
  failed,
}

final class OperationalProofSnapshot {
  const OperationalProofSnapshot({
    required this.interfaceReady,
    required this.routesReady,
    required this.dnsReady,
    required this.egressReady,
  });

  final bool interfaceReady;
  final bool routesReady;
  final bool dnsReady;
  final bool egressReady;

  bool get isVerified =>
      interfaceReady && routesReady && dnsReady && egressReady;

  List<String> get missingProofs => <String>[
        if (!interfaceReady) 'interface',
        if (!routesReady) 'routes',
        if (!dnsReady) 'dns',
        if (!egressReady) 'egress',
      ];

  Map<String, Object?> toAttributes() => <String, Object?>{
        'interface_ready': interfaceReady,
        'routes_ready': routesReady,
        'dns_ready': dnsReady,
        'egress_ready': egressReady,
      };
}

final class OperationalAttemptTimeline {
  OperationalAttemptTimeline({
    required this.dispatcher,
    required this.build,
    required this.runId,
    required this.attemptId,
    required this.generation,
    OperationalIdFactory? ids,
    DateTime Function()? clock,
  })  : ids = ids ?? OperationalIdFactory(),
        clock = clock ?? (() => DateTime.now().toUtc()) {
    traceId = this.ids.traceId();
    dispatcher.sequenceFence.activateGeneration(generation);
  }

  final OperationalEventDispatcher dispatcher;
  final OperationalBuildIdentity build;
  final String runId;
  final String attemptId;
  final int generation;
  final OperationalIdFactory ids;
  final DateTime Function() clock;
  late final String traceId;
  _OpenOperationalPhase? _open;
  bool _started = false;
  bool _terminal = false;
  bool _verified = false;

  bool get isTerminal => _terminal;
  bool get isVerified => _verified;
  OperationalTimelinePhase? get activePhase => _open?.phase;

  Future<T> runCorrelated<T>(Future<T> Function() body) =>
      PortalCorrelationScope.run(attemptId, body);

  void start() {
    if (_started) {
      throw StateError('Operational attempt already started');
    }
    _started = true;
    _emit(
      phase: OperationalTimelinePhase.bootstrap,
      name: 'app.connection.intent.received',
      outcome: ObservabilityOutcome.started,
      severity: ObservabilitySeverity.info,
      stageOverride: 'request',
    );
  }

  void enter(OperationalTimelinePhase phase) {
    _requireActive();
    if (_open?.phase == phase) {
      return;
    }
    if (_open != null) {
      complete(_open!.phase, outcome: ObservabilityOutcome.succeeded);
    }
    final startedAt = clock().toUtc();
    final spanId = ids.spanId();
    _open = _OpenOperationalPhase(
      phase: phase,
      startedAtUtc: startedAt,
      spanId: spanId,
    );
    _emit(
      phase: phase,
      name: 'app.connection.${phase.name}.started',
      outcome: ObservabilityOutcome.started,
      severity: ObservabilitySeverity.info,
      occurredAtUtc: startedAt,
      spanId: spanId,
    );
  }

  void complete(
    OperationalTimelinePhase phase, {
    required ObservabilityOutcome outcome,
    String? errorCode,
    ObservabilityErrorOrigin errorOrigin = ObservabilityErrorOrigin.client,
    OperationalProofSnapshot? proofs,
  }) {
    _requireActive();
    final open = _open;
    if (open == null || open.phase != phase) {
      throw StateError('Operational phase is not active: ${phase.name}');
    }
    final now = clock().toUtc();
    final attributes = <String, Object?>{
      'phase': _phaseAttribute(phase),
      'duration_ms': _boundedDuration(open.startedAtUtc, now),
      ...?proofs?.toAttributes(),
    };
    _emit(
      phase: phase,
      name: 'app.connection.${phase.name}.finished',
      outcome: outcome,
      severity: _severityFor(outcome),
      errorCode: errorCode,
      errorOrigin: errorOrigin,
      attributes: attributes,
      occurredAtUtc: now,
      spanId: open.spanId,
    );
    _open = null;
  }

  void markVerified(OperationalProofSnapshot proofs) {
    _requireActive();
    if (!proofs.isVerified) {
      throw StateError(
        'Current proof is incomplete: ${proofs.missingProofs.join(',')}',
      );
    }
    enter(OperationalTimelinePhase.verified);
    complete(
      OperationalTimelinePhase.verified,
      outcome: ObservabilityOutcome.succeeded,
      proofs: proofs,
    );
    _verified = true;
  }

  void observeProof(OperationalProofSnapshot proofs) {
    _requireActive();
    if (proofs.isVerified) {
      throw ArgumentError('Verified proof must use markVerified');
    }
    final phase = _open?.phase ?? OperationalTimelinePhase.egress;
    _emit(
      phase: phase,
      name: 'app.connection.proof.observed',
      outcome: ObservabilityOutcome.degraded,
      severity: ObservabilitySeverity.warn,
      attributes: <String, Object?>{
        'phase': _phaseAttribute(phase),
        ...proofs.toAttributes(),
      },
    );
  }

  void finish(
    OperationalTerminalKind kind, {
    String? errorCode,
    ObservabilityErrorOrigin errorOrigin = ObservabilityErrorOrigin.client,
  }) {
    _requireActive();
    if (kind == OperationalTerminalKind.succeeded && !_verified) {
      throw StateError('A successful connection requires current proof');
    }
    final resolvedCode = switch (kind) {
      OperationalTerminalKind.timeout => 'CONN-008',
      OperationalTerminalKind.crash => 'CRASH-001',
      OperationalTerminalKind.failed => errorCode,
      _ => null,
    };
    if (kind == OperationalTerminalKind.failed && resolvedCode == null) {
      throw ArgumentError('Failed terminal outcome requires an error code');
    }
    final outcome = switch (kind) {
      OperationalTerminalKind.succeeded => ObservabilityOutcome.succeeded,
      OperationalTerminalKind.cancelled => ObservabilityOutcome.cancelled,
      OperationalTerminalKind.superseded => ObservabilityOutcome.superseded,
      OperationalTerminalKind.timeout ||
      OperationalTerminalKind.crash ||
      OperationalTerminalKind.failed =>
        ObservabilityOutcome.failed,
    };
    if (_open != null) {
      complete(
        _open!.phase,
        outcome: outcome,
        errorCode: resolvedCode,
        errorOrigin: errorOrigin,
      );
    }
    _emit(
      phase: _verified
          ? OperationalTimelinePhase.verified
          : OperationalTimelinePhase.stopped,
      name: 'app.connection.attempt.finished',
      outcome: outcome,
      severity: _severityFor(outcome),
      errorCode: resolvedCode,
      errorOrigin: errorOrigin,
      attributes: <String, Object?>{
        'phase': _verified ? 'egress' : 'stop',
        if (kind == OperationalTerminalKind.timeout) 'status_class': 'timeout',
        if (kind == OperationalTerminalKind.cancelled)
          'status_class': 'cancelled',
        if (kind == OperationalTerminalKind.superseded)
          'reason_class': 'superseded',
      },
    );
    _terminal = true;
  }

  void _requireActive() {
    if (!_started || _terminal) {
      throw StateError('Operational attempt is not active');
    }
  }

  void _emit({
    required OperationalTimelinePhase phase,
    required String name,
    required ObservabilityOutcome outcome,
    required ObservabilitySeverity severity,
    String? errorCode,
    ObservabilityErrorOrigin errorOrigin = ObservabilityErrorOrigin.client,
    Map<String, Object?> attributes = const <String, Object?>{},
    DateTime? occurredAtUtc,
    String? spanId,
    String? stageOverride,
  }) {
    // Other app events share this generation and may have advanced the fence.
    final sequence = dispatcher.sequenceFence.lastSequence + 1;
    dispatcher.emit(
      OperationalEvent(
        eventId: ids.uuidV4(),
        occurredAtUtc: occurredAtUtc ?? clock(),
        component: 'app',
        subsystem: _subsystem(phase),
        stage: stageOverride ?? _stage(phase),
        name: name,
        severity: severity,
        outcome: outcome,
        privacyClass: ObservabilityPrivacyClass.localOperational,
        correlation: OperationalCorrelation(
          traceId: traceId,
          spanId: spanId ?? ids.spanId(),
          parentSpanId: null,
          runId: runId,
          attemptId: attemptId,
          generation: generation,
          sequence: sequence,
        ),
        build: build,
        error: errorCode == null
            ? null
            : OperationalErrorIdentity(
                code: errorCode,
                origin: errorOrigin,
              ),
        attributes: attributes,
      ),
    );
  }

  static int _boundedDuration(DateTime started, DateTime finished) =>
      finished.difference(started).inMilliseconds.clamp(0, 86400000).toInt();

  static ObservabilitySeverity _severityFor(ObservabilityOutcome outcome) =>
      switch (outcome) {
        ObservabilityOutcome.failed ||
        ObservabilityOutcome.blocked =>
          ObservabilitySeverity.error,
        ObservabilityOutcome.degraded => ObservabilitySeverity.warn,
        _ => ObservabilitySeverity.info,
      };

  static String _phaseAttribute(OperationalTimelinePhase phase) =>
      switch (phase) {
        OperationalTimelinePhase.verified => 'egress',
        OperationalTimelinePhase.rollback => 'recovery',
        OperationalTimelinePhase.stopped => 'stop',
        _ => phase.name,
      };

  static String _subsystem(OperationalTimelinePhase phase) => switch (phase) {
        OperationalTimelinePhase.bootstrap => 'bootstrap',
        OperationalTimelinePhase.profile => 'connection',
        OperationalTimelinePhase.core => 'core',
        OperationalTimelinePhase.tun => 'tun',
        OperationalTimelinePhase.routes => 'routing',
        OperationalTimelinePhase.dns => 'dns',
        OperationalTimelinePhase.egress ||
        OperationalTimelinePhase.verified =>
          'egress',
        OperationalTimelinePhase.rollback ||
        OperationalTimelinePhase.stopped =>
          'recovery',
      };

  static String _stage(OperationalTimelinePhase phase) => switch (phase) {
        OperationalTimelinePhase.bootstrap => 'initialize',
        OperationalTimelinePhase.profile => 'prepare',
        OperationalTimelinePhase.core => 'start',
        OperationalTimelinePhase.tun ||
        OperationalTimelinePhase.routes =>
          'apply',
        OperationalTimelinePhase.dns ||
        OperationalTimelinePhase.egress ||
        OperationalTimelinePhase.verified =>
          'verify',
        OperationalTimelinePhase.rollback => 'rollback',
        OperationalTimelinePhase.stopped => 'stop',
      };
}

final class _OpenOperationalPhase {
  const _OpenOperationalPhase({
    required this.phase,
    required this.startedAtUtc,
    required this.spanId,
  });

  final OperationalTimelinePhase phase;
  final DateTime startedAtUtc;
  final String spanId;
}
