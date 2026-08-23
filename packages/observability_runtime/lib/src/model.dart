import 'package:pokrov_observability_contracts/observability_contracts.dart';

import 'privacy.dart';

final class OperationalCorrelation {
  OperationalCorrelation({
    required this.traceId,
    required this.spanId,
    required this.parentSpanId,
    required this.runId,
    required this.attemptId,
    required this.generation,
    required this.sequence,
  }) {
    _requirePattern(traceId, _tracePattern, 'trace_id');
    _requirePattern(spanId, _spanPattern, 'span_id');
    if (parentSpanId != null) {
      _requirePattern(parentSpanId!, _spanPattern, 'parent_span_id');
    }
    if (runId != null) {
      _requirePattern(runId!, _uuidPattern, 'run_id');
    }
    if (attemptId != null) {
      _requirePattern(attemptId!, _uuidPattern, 'attempt_id');
    }
    if (generation < 0 || generation > 0x7fffffff) {
      throw ArgumentError.value(generation, 'generation');
    }
    if (sequence < 0) {
      throw ArgumentError.value(sequence, 'sequence');
    }
  }

  static final _tracePattern = RegExp(r'^[0-9a-f]{32}$');
  static final _spanPattern = RegExp(r'^[0-9a-f]{16}$');
  static final _uuidPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  final String traceId;
  final String spanId;
  final String? parentSpanId;
  final String? runId;
  final String? attemptId;
  final int generation;
  final int sequence;

  Map<String, Object?> toJson() => <String, Object?>{
        'trace_id': traceId,
        'span_id': spanId,
        'parent_span_id': parentSpanId,
        'run_id': runId,
        'attempt_id': attemptId,
        'generation': generation,
        'sequence': sequence,
      };
}

final class OperationalBuildIdentity {
  OperationalBuildIdentity({
    required this.appVersion,
    required this.buildNumber,
    required this.channel,
    required this.candidateLabel,
    required this.gitRevision,
    required this.coreVersion,
    required this.coreAbi,
    required this.platform,
    required this.architecture,
  }) {
    _requirePattern(appVersion, _versionPattern, 'app_version');
    _requirePattern(buildNumber, _tokenPattern, 'build_number');
    if (!_channels.contains(channel)) {
      throw ArgumentError.value(channel, 'channel');
    }
    _requirePattern(candidateLabel, _candidatePattern, 'candidate_label');
    _requirePattern(gitRevision, _gitPattern, 'git_revision');
    if (coreVersion != null) {
      _requirePattern(coreVersion!, _versionPattern, 'core_version');
    }
    if (coreAbi != null && coreAbi! < 1) {
      throw ArgumentError.value(coreAbi, 'core_abi');
    }
    if (!_platforms.contains(platform)) {
      throw ArgumentError.value(platform, 'platform');
    }
    _requirePattern(architecture, _architecturePattern, 'architecture');
  }

  static final _versionPattern = RegExp(
    r'^[0-9]+\.[0-9]+\.[0-9]+(?:[-+][A-Za-z0-9.-]+)?$',
  );
  static final _tokenPattern = RegExp(r'^[A-Za-z0-9._+-]{1,32}$');
  static final _candidatePattern = RegExp(
    r'^pokrov-[A-Za-z0-9][A-Za-z0-9._+-]{1,63}$',
  );
  static final _gitPattern = RegExp(r'^[0-9a-f]{40}$');
  static final _architecturePattern = RegExp(
    r'^[A-Za-z0-9][A-Za-z0-9._+-]{0,31}$',
  );
  static const _channels = <String>{'alpha', 'beta', 'rc', 'stable', 'local'};
  static const _platforms = <String>{'android', 'windows', 'server'};

  final String appVersion;
  final String buildNumber;
  final String channel;
  final String candidateLabel;
  final String gitRevision;
  final String? coreVersion;
  final int? coreAbi;
  final String platform;
  final String architecture;

  Map<String, Object?> toJson() => <String, Object?>{
        'app_version': appVersion,
        'build_number': buildNumber,
        'channel': channel,
        'candidate_label': candidateLabel,
        'git_revision': gitRevision,
        'core_version': coreVersion,
        'core_abi': coreAbi,
        'platform': platform,
        'architecture': architecture,
      };
}

final class OperationalErrorIdentity {
  OperationalErrorIdentity({required this.code, required this.origin}) {
    if (!KnownOperationalErrorCodes.contains(code)) {
      throw ArgumentError.value(code, 'code', 'Unknown operational error code');
    }
  }

  final String code;
  final ObservabilityErrorOrigin origin;

  Map<String, Object> toJson() => <String, Object>{
        'code': code,
        'origin': origin.name,
      };
}

final class OperationalEvent {
  OperationalEvent({
    required this.eventId,
    required DateTime occurredAtUtc,
    required this.component,
    required this.subsystem,
    required this.stage,
    required this.name,
    required this.severity,
    required this.outcome,
    required this.privacyClass,
    required this.correlation,
    required this.build,
    required this.error,
    Map<String, Object?> attributes = const <String, Object?>{},
  })  : occurredAtUtc = occurredAtUtc.toUtc(),
        attributes = Map<String, Object?>.unmodifiable(attributes) {
    _requirePattern(eventId, _uuidPattern, 'event_id');
    if (!_components.contains(component)) {
      throw ArgumentError.value(component, 'component');
    }
    if (!_subsystems.contains(subsystem)) {
      throw ArgumentError.value(subsystem, 'subsystem');
    }
    if (!_stages.contains(stage)) {
      throw ArgumentError.value(stage, 'stage');
    }
    _requirePattern(name, _eventNamePattern, 'name');
    if (error == null &&
        (outcome == ObservabilityOutcome.failed ||
            outcome == ObservabilityOutcome.blocked)) {
      throw ArgumentError('failed/blocked events require a catalog error');
    }
    if (error != null &&
        outcome != ObservabilityOutcome.failed &&
        outcome != ObservabilityOutcome.blocked &&
        outcome != ObservabilityOutcome.degraded) {
      throw ArgumentError(
        'catalog errors require failed/blocked/degraded outcome',
      );
    }
    OperationalAttributePolicy.validate(attributes, privacyClass);
  }

  static final _uuidPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );
  static final _eventNamePattern = RegExp(
    r'^[a-z][a-z0-9_]*(?:\.[a-z][a-z0-9_]*){2,5}$',
  );
  static const _components = <String>{
    'app',
    'android_host',
    'windows_host',
    'windows_service',
    'core',
    'portal',
    'worker',
  };
  static const _subsystems = <String>{
    'bootstrap',
    'auth',
    'api',
    'entitlement',
    'connection',
    'core',
    'tun',
    'routing',
    'dns',
    'egress',
    'recovery',
    'update',
    'windows_service',
    'android_host',
    'crash',
    'performance',
    'support',
    'security',
  };
  static const _stages = <String>{
    'request',
    'initialize',
    'validate',
    'prepare',
    'start',
    'apply',
    'verify',
    'commit',
    'run',
    'retry',
    'stop',
    'rollback',
    'recover',
    'build',
    'preview',
    'upload',
    'complete',
  };

  final String eventId;
  final DateTime occurredAtUtc;
  final String component;
  final String subsystem;
  final String stage;
  final String name;
  final ObservabilitySeverity severity;
  final ObservabilityOutcome outcome;
  final ObservabilityPrivacyClass privacyClass;
  final OperationalCorrelation correlation;
  final OperationalBuildIdentity build;
  final OperationalErrorIdentity? error;
  final Map<String, Object?> attributes;

  bool get isSecurity => subsystem == 'security';

  int get priority {
    if (isSecurity || severity == ObservabilitySeverity.fatal) {
      return 5;
    }
    return switch (severity) {
      ObservabilitySeverity.error => 4,
      ObservabilitySeverity.warn => 3,
      ObservabilitySeverity.info => 2,
      ObservabilitySeverity.debug => 1,
      ObservabilitySeverity.trace => 0,
      ObservabilitySeverity.fatal => 5,
    };
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'schema_version': 1,
        'event_id': eventId,
        'occurred_at_utc': _formatUtc(occurredAtUtc),
        'component': component,
        'subsystem': subsystem,
        'stage': stage,
        'name': name,
        'severity': severity.name,
        'outcome': outcome.wireValue,
        'privacy_class': privacyClass.wireValue,
        'correlation': correlation.toJson(),
        'build': build.toJson(),
        'error': error?.toJson(),
        'attributes': attributes,
      };
}

String _formatUtc(DateTime value) {
  final formatted = value.toUtc().toIso8601String();
  return formatted.endsWith('Z') ? formatted : '${formatted}Z';
}

void _requirePattern(String value, RegExp pattern, String field) {
  if (!pattern.hasMatch(value)) {
    throw ArgumentError.value(value, field);
  }
}
