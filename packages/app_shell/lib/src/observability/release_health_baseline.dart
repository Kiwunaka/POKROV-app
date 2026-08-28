import 'package:pokrov_observability_runtime/observability_runtime.dart';

enum ClientReleaseHealthBaselineState {
  available,
  insufficientCohort,
  insufficientSamples,
  unavailable,
}

enum ClientReleaseHealthMetricState { available, insufficientSamples }

enum ClientReleaseHealthSampleBand {
  tenToTwentyNine,
  thirtyToNinetyNine,
  oneHundredToFourHundredNinetyNine,
  fiveHundredPlus,
}

enum ClientReleaseHealthFailureRateBand {
  noneObserved,
  belowOnePercent,
  oneToBelowFivePercent,
  fiveToBelowTwentyPercent,
  twentyPercentOrMore,
}

final class ClientReleaseHealthMetric {
  const ClientReleaseHealthMetric({
    required this.state,
    required this.sampleBand,
    required this.failureRateBand,
  });

  final ClientReleaseHealthMetricState state;
  final ClientReleaseHealthSampleBand? sampleBand;
  final ClientReleaseHealthFailureRateBand? failureRateBand;

  bool get isAvailable => state == ClientReleaseHealthMetricState.available;

  static ClientReleaseHealthMetric parse(Object? value) {
    final map = _closedMap(value, const <String>{
      'state',
      'sample_band',
      'failure_rate_band',
    });
    final state = switch (map['state']) {
      'available' => ClientReleaseHealthMetricState.available,
      'insufficient_samples' =>
        ClientReleaseHealthMetricState.insufficientSamples,
      _ => throw const FormatException('Invalid baseline metric state.'),
    };
    if (state == ClientReleaseHealthMetricState.insufficientSamples) {
      if (map['sample_band'] != null || map['failure_rate_band'] != null) {
        throw const FormatException('Invalid hidden baseline metric.');
      }
      return const ClientReleaseHealthMetric(
        state: ClientReleaseHealthMetricState.insufficientSamples,
        sampleBand: null,
        failureRateBand: null,
      );
    }
    return ClientReleaseHealthMetric(
      state: state,
      sampleBand: _sampleBand(map['sample_band']),
      failureRateBand: _failureRateBand(map['failure_rate_band']),
    );
  }
}

final class ClientReleaseHealthBaselineData {
  const ClientReleaseHealthBaselineData({
    required this.overall,
    required this.crash,
    required this.connect,
    required this.update,
  });

  final ClientReleaseHealthMetric overall;
  final ClientReleaseHealthMetric crash;
  final ClientReleaseHealthMetric connect;
  final ClientReleaseHealthMetric update;

  static ClientReleaseHealthBaselineData parse(Object? value) {
    final map = _closedMap(value, const <String>{'overall', 'families'});
    final families = _closedMap(map['families'], const <String>{
      'crash',
      'connect',
      'update',
    });
    final overall = ClientReleaseHealthMetric.parse(map['overall']);
    if (!overall.isAvailable) {
      throw const FormatException('Overall baseline metric is unavailable.');
    }
    return ClientReleaseHealthBaselineData(
      overall: overall,
      crash: ClientReleaseHealthMetric.parse(families['crash']),
      connect: ClientReleaseHealthMetric.parse(families['connect']),
      update: ClientReleaseHealthMetric.parse(families['update']),
    );
  }
}

final class ClientReleaseHealthBaseline {
  const ClientReleaseHealthBaseline._({
    required this.state,
    required this.windowStartedAtUtc,
    required this.windowEndsAtUtc,
    required this.data,
  });

  const ClientReleaseHealthBaseline.unavailable()
      : this._(
          state: ClientReleaseHealthBaselineState.unavailable,
          windowStartedAtUtc: null,
          windowEndsAtUtc: null,
          data: null,
        );

  final ClientReleaseHealthBaselineState state;
  final DateTime? windowStartedAtUtc;
  final DateTime? windowEndsAtUtc;
  final ClientReleaseHealthBaselineData? data;

  bool get canCompare =>
      state == ClientReleaseHealthBaselineState.available && data != null;

  static ClientReleaseHealthBaseline parse(
    Map<String, Object?> payload, {
    required OperationalBuildIdentity expectedBuild,
  }) {
    final map = _closedMap(payload, const <String>{
      'schema_version',
      'state',
      'scope',
      'window',
      'privacy',
      'baseline',
    });
    if (map['schema_version'] != 1) {
      throw const FormatException('Unsupported baseline schema.');
    }
    _validateScope(map['scope'], expectedBuild: expectedBuild);
    final (startedAt, endsAt) = _window(map['window']);
    final privacy = _closedMap(map['privacy'], const <String>{
      'minimum_contributors',
      'minimum_satisfied',
      'contribution_cap_per_window',
    });
    if (privacy['minimum_contributors'] != 10 ||
        privacy['contribution_cap_per_window'] != 64 ||
        privacy['minimum_satisfied'] is! bool) {
      throw const FormatException('Invalid baseline privacy contract.');
    }

    final state = switch (map['state']) {
      'available' => ClientReleaseHealthBaselineState.available,
      'insufficient_cohort' =>
        ClientReleaseHealthBaselineState.insufficientCohort,
      'insufficient_samples' =>
        ClientReleaseHealthBaselineState.insufficientSamples,
      _ => throw const FormatException('Invalid baseline state.'),
    };
    final minimumSatisfied = privacy['minimum_satisfied'] as bool;
    if (state == ClientReleaseHealthBaselineState.insufficientCohort) {
      if (minimumSatisfied || map['baseline'] != null) {
        throw const FormatException('Invalid subminimum baseline response.');
      }
      return ClientReleaseHealthBaseline._(
        state: state,
        windowStartedAtUtc: startedAt,
        windowEndsAtUtc: endsAt,
        data: null,
      );
    }
    if (!minimumSatisfied) {
      throw const FormatException('Invalid baseline minimum state.');
    }
    if (state == ClientReleaseHealthBaselineState.insufficientSamples) {
      if (map['baseline'] != null) {
        throw const FormatException('Invalid insufficient baseline response.');
      }
      return ClientReleaseHealthBaseline._(
        state: state,
        windowStartedAtUtc: startedAt,
        windowEndsAtUtc: endsAt,
        data: null,
      );
    }
    return ClientReleaseHealthBaseline._(
      state: state,
      windowStartedAtUtc: startedAt,
      windowEndsAtUtc: endsAt,
      data: ClientReleaseHealthBaselineData.parse(map['baseline']),
    );
  }
}

Map<String, Object?> _closedMap(Object? value, Set<String> keys) {
  if (value is! Map) {
    throw const FormatException('Invalid baseline object.');
  }
  final map = value.map<String, Object?>(
    (key, item) => MapEntry(key.toString(), item),
  );
  if (map.keys.toSet().length != keys.length ||
      !map.keys.toSet().containsAll(keys)) {
    throw const FormatException('Invalid baseline object fields.');
  }
  return map;
}

void _validateScope(
  Object? value, {
  required OperationalBuildIdentity expectedBuild,
}) {
  final scope = _closedMap(value, const <String>{
    'app_version',
    'build_number',
    'channel',
    'candidate_label',
    'git_revision',
    'core_abi',
    'platform',
    'architecture',
  });
  final expected = <String, Object?>{
    'app_version': expectedBuild.appVersion,
    'build_number': expectedBuild.buildNumber,
    'channel': expectedBuild.channel,
    'candidate_label': expectedBuild.candidateLabel,
    'git_revision': expectedBuild.gitRevision,
    'core_abi': expectedBuild.coreAbi,
    'platform': expectedBuild.platform,
    'architecture': expectedBuild.architecture,
  };
  for (final entry in expected.entries) {
    if (scope[entry.key] != entry.value) {
      throw const FormatException('Baseline scope does not match this build.');
    }
  }
}

(DateTime, DateTime) _window(Object? value) {
  final window = _closedMap(value, const <String>{
    'kind',
    'started_at',
    'ends_at',
  });
  if (window['kind'] != 'utc_week') {
    throw const FormatException('Invalid baseline window kind.');
  }
  final startedAt = _strictUtc(window['started_at']);
  final endsAt = _strictUtc(window['ends_at']);
  if (startedAt.weekday != DateTime.monday ||
      startedAt.hour != 0 ||
      startedAt.minute != 0 ||
      startedAt.second != 0 ||
      startedAt.millisecond != 0 ||
      endsAt.difference(startedAt) != const Duration(days: 7)) {
    throw const FormatException('Invalid baseline week window.');
  }
  return (startedAt, endsAt);
}

DateTime _strictUtc(Object? value) {
  final text = value is String ? value : '';
  if (!text.endsWith('Z')) {
    throw const FormatException('Invalid baseline UTC timestamp.');
  }
  final parsed = DateTime.tryParse(text);
  if (parsed == null || !parsed.isUtc) {
    throw const FormatException('Invalid baseline UTC timestamp.');
  }
  return parsed;
}

ClientReleaseHealthSampleBand _sampleBand(Object? value) => switch (value) {
      '10_to_29' => ClientReleaseHealthSampleBand.tenToTwentyNine,
      '30_to_99' => ClientReleaseHealthSampleBand.thirtyToNinetyNine,
      '100_to_499' =>
        ClientReleaseHealthSampleBand.oneHundredToFourHundredNinetyNine,
      '500_plus' => ClientReleaseHealthSampleBand.fiveHundredPlus,
      _ => throw const FormatException('Invalid baseline sample band.'),
    };

ClientReleaseHealthFailureRateBand _failureRateBand(Object? value) =>
    switch (value) {
      'none_observed' => ClientReleaseHealthFailureRateBand.noneObserved,
      'below_1_percent' => ClientReleaseHealthFailureRateBand.belowOnePercent,
      '1_to_below_5_percent' =>
        ClientReleaseHealthFailureRateBand.oneToBelowFivePercent,
      '5_to_below_20_percent' =>
        ClientReleaseHealthFailureRateBand.fiveToBelowTwentyPercent,
      '20_percent_or_more' =>
        ClientReleaseHealthFailureRateBand.twentyPercentOrMore,
      _ => throw const FormatException('Invalid baseline failure-rate band.'),
    };
