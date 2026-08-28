import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/app_shell.dart';
import 'package:pokrov_observability_runtime/observability_runtime.dart';

void main() {
  test('parses closed band-only baseline for the exact build scope', () {
    final baseline = ClientReleaseHealthBaseline.parse(
      _payload(),
      expectedBuild: _build(),
    );

    expect(baseline.state, ClientReleaseHealthBaselineState.available);
    expect(baseline.canCompare, isTrue);
    expect(
      baseline.data!.connect.failureRateBand,
      ClientReleaseHealthFailureRateBand.oneToBelowFivePercent,
    );
    expect(
      baseline.data!.connect.sampleBand,
      ClientReleaseHealthSampleBand.thirtyToNinetyNine,
    );
  });

  test('keeps subminimum cohort closed without data or observed count', () {
    final payload = _payload(
      state: 'insufficient_cohort',
      minimumSatisfied: false,
      includeBaseline: false,
    );

    final result = ClientReleaseHealthBaseline.parse(
      payload,
      expectedBuild: _build(),
    );

    expect(result.state, ClientReleaseHealthBaselineState.insufficientCohort);
    expect(result.canCompare, isFalse);
    expect(result.data, isNull);
  });

  test('rejects a response for another exact build scope', () {
    final payload = _payload();
    (payload['scope']! as Map<String, Object?>)['build_number'] = '31';

    expect(
      () => ClientReleaseHealthBaseline.parse(payload, expectedBuild: _build()),
      throwsFormatException,
    );
  });

  test('rejects identity, bucket, and exact-count fields', () {
    for (final field in <String>[
      'account_id',
      'contributor_hash',
      'bucket_index',
      'observed_count',
    ]) {
      final payload = _payload();
      (payload['privacy']! as Map<String, Object?>)[field] = 12;
      expect(
        () =>
            ClientReleaseHealthBaseline.parse(payload, expectedBuild: _build()),
        throwsFormatException,
        reason: field,
      );
    }
  });

  test('rejects malformed privacy, window, and metric bands', () {
    final wrongMinimum = _payload();
    (wrongMinimum['privacy']! as Map<String, Object?>)['minimum_contributors'] =
        9;
    final wrongWindow = _payload();
    (wrongWindow['window']! as Map<String, Object?>)['started_at'] =
        '2026-08-25T00:00:00Z';
    final wrongBand = _payload();
    final baseline = wrongBand['baseline']! as Map<String, Object?>;
    final families = baseline['families']! as Map<String, Object?>;
    final connect = families['connect']! as Map<String, Object?>;
    connect['failure_rate_band'] = 'exactly_3_percent';

    for (final payload in <Map<String, Object?>>[
      wrongMinimum,
      wrongWindow,
      wrongBand,
    ]) {
      expect(
        () =>
            ClientReleaseHealthBaseline.parse(payload, expectedBuild: _build()),
        throwsFormatException,
      );
    }
  });
}

OperationalBuildIdentity _build() => OperationalBuildIdentity(
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

Map<String, Object?> _payload({
  String state = 'available',
  bool minimumSatisfied = true,
  bool includeBaseline = true,
}) =>
    <String, Object?>{
      'schema_version': 1,
      'state': state,
      'scope': <String, Object?>{
        'app_version': '1.2.0',
        'build_number': '4046',
        'channel': 'local',
        'candidate_label': 'pokrov-1.2.0-local',
        'git_revision': '0123456789abcdef0123456789abcdef01234567',
        'core_abi': null,
        'platform': 'android',
        'architecture': 'arm64-v8a',
      },
      'window': <String, Object?>{
        'kind': 'utc_week',
        'started_at': '2026-08-24T00:00:00Z',
        'ends_at': '2026-08-31T00:00:00Z',
      },
      'privacy': <String, Object?>{
        'minimum_contributors': 10,
        'minimum_satisfied': minimumSatisfied,
        'contribution_cap_per_window': 64,
      },
      'baseline': includeBaseline ? _baseline() : null,
    };

Map<String, Object?> _baseline() => <String, Object?>{
      'overall': <String, Object?>{
        'state': 'available',
        'sample_band': '100_to_499',
        'failure_rate_band': 'below_1_percent',
      },
      'families': <String, Object?>{
        'crash': <String, Object?>{
          'state': 'insufficient_samples',
          'sample_band': null,
          'failure_rate_band': null,
        },
        'connect': <String, Object?>{
          'state': 'available',
          'sample_band': '30_to_99',
          'failure_rate_band': '1_to_below_5_percent',
        },
        'update': <String, Object?>{
          'state': 'insufficient_samples',
          'sample_band': null,
          'failure_rate_band': null,
        },
      },
    };
