import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/app_shell.dart';
import 'package:pokrov_core_domain/core_domain.dart';
import 'package:pokrov_diagnostics_collectors/diagnostics_collectors.dart';
import 'package:pokrov_observability_runtime/observability_runtime.dart';
import 'package:pokrov_runtime_engine/runtime_engine.dart';
import 'package:pokrov_support_bundle/support_bundle.dart';

void main() {
  test('client observability follows reducer proof and mirrors safe aggregate',
      () async {
    final directory = await Directory.systemTemp.createTemp('pokrov-obs-app-');
    addTearDown(() => directory.delete(recursive: true));
    final releaseHealth = _ReleaseHealthCapture();
    final ids = OperationalIdFactory(random: Random(101));
    final observability = await PokrovClientObservability.start(
      hostPlatform: HostPlatform.android,
      releaseHealthService: releaseHealth,
      directoryResolver: () async => directory,
      buildIdentity: _build(),
      idFactory: ids,
    );
    observability.markUiReady();
    observability.recordUpdateInstallStarted(
      channel: PokrovOperationalUpdateChannel.direct,
    );
    observability.recordUpdateInstallFinished(
      channel: PokrovOperationalUpdateChannel.direct,
      failure: ClientUpdateFailure.identity,
    );
    observability.recordAuthRequestStarted();
    observability.recordAuthRequestFinished();
    observability.recordEntitlementRefreshStarted();
    observability.recordEntitlementRefreshFinished();
    observability.recordPerformanceSampleStarted();
    observability.recordPerformanceSampleFinished(
      stats: const RuntimeLiveStats(
        available: true,
        counterState: RuntimeTrafficCounterState.available,
        downlinkBps: 24000,
        uplinkBps: 12000,
      ),
    );
    final prepared = const SupportBundleBuilder().prepare(
      snapshot: _diagnosticSnapshot(),
      profile: SupportDiagnosticProfile.summary,
      now: DateTime.utc(2026, 8, 21, 12),
    );
    observability.recordSupportBundleStarted();
    observability.recordSupportBundleFinished(prepared: prepared);
    observability.recordAndroidRoutingAppCount(3);
    observability.recordAndroidRoutingAppCount(3);

    await observability.runConnectionAction(
      () async {
        observability.observeConnection(
          const ConnectionPreparing(stage: ConnectionStage.profile),
        );
        observability.observeConnection(
          ConnectionExperienceReducer.reduce(
            snapshot: _verifiedSnapshot(),
            intent: ConnectionTransitionIntent.none,
            actionInFlight: false,
          ),
        );
      },
      beginsWithDisconnect: false,
    );
    await observability.flush();

    final breadcrumbs = observability.dispatcher.breadcrumbs.snapshot();
    expect(
      breadcrumbs.map((item) => item.name),
      containsAll(<String>[
        'app.bootstrap.initialize.finished',
        'app.bootstrap.ui_ready.finished',
        'app.connection.profile.started',
        'app.connection.verified.finished',
        'app.connection.attempt.finished',
        'app.update.install.finished',
        'app.auth.request.finished',
        'app.entitlement.refresh.finished',
        'app.performance.sample.finished',
        'app.support.bundle.finished',
        'app.routing.selection.finished',
      ]),
    );
    expect(releaseHealth.batches, isNotEmpty);
    for (final batch in releaseHealth.batches) {
      final serialized = jsonEncode(batch);
      expect(serialized, isNot(contains('correlation')));
    }
    expect(
      releaseHealth.correlations,
      everyElement(matches(RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      ))),
    );
    final remoteEvents = releaseHealth.batches
        .expand((batch) => batch['events']! as List<Object?>)
        .whereType<Map<String, Object?>>();
    final routing = remoteEvents.singleWhere(
      (event) => event['name'] == 'app.routing.selection.finished',
    );
    expect(
      remoteEvents.where((event) => !identical(event, routing)),
      everyElement(isNot(contains('attributes'))),
    );
    expect(
      routing['attributes'],
      <String, Object?>{'selected_app_count': 3},
    );
    final remote = jsonEncode(releaseHealth.batches);
    expect(remote, isNot(contains('org.telegram.messenger')));
    expect(remote, isNot(contains('package_name')));
  });

  test('caught connection failure remains failed instead of cancelled',
      () async {
    final directory = await Directory.systemTemp.createTemp('pokrov-obs-fail-');
    addTearDown(() => directory.delete(recursive: true));
    final observability = await PokrovClientObservability.start(
      hostPlatform: HostPlatform.android,
      directoryResolver: () async => directory,
      buildIdentity: _build(),
      idFactory: OperationalIdFactory(random: Random(103)),
    );

    await observability.runConnectionAction(
      () async {
        observability.recordConnectionFailure(
          stage: ConnectionStage.profile,
          errorCode: 'CONN-005',
        );
      },
      beginsWithDisconnect: false,
    );
    await observability.flush();

    final terminal = observability.dispatcher.breadcrumbs.snapshot().lastWhere(
          (event) => event.name == 'app.connection.attempt.finished',
        );
    expect(terminal.outcome.wireValue, 'failed');
    expect(terminal.errorCode, 'CONN-005');
  });

  test('active app-first client emits correlation header and aggregate batch',
      () async {
    final directory = await Directory.systemTemp.createTemp('pokrov-obs-api-');
    addTearDown(() => directory.delete(recursive: true));
    final secrets = MemoryAppFirstSessionSecretStore();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    HttpRequest? captured;
    Map<String, dynamic>? capturedBody;
    final responseDone = Completer<void>();
    server.listen((request) async {
      captured = request;
      capturedBody = jsonDecode(await utf8.decoder.bind(request).join())
          as Map<String, dynamic>;
      request.response
        ..statusCode = HttpStatus.accepted
        ..headers.contentType = ContentType.json
        ..write('{"accepted":1,"duplicates":0}');
      await request.response.close();
      responseDone.complete();
    });
    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://${server.address.host}:${server.port}',
      supportDirectoryResolver: () async => directory,
      sessionSecretStore: secrets,
      maxRequestAttempts: 1,
    );
    final ids = OperationalIdFactory(random: Random(102));
    final correlationId = ids.uuidV4();
    final batch = _releaseHealthBatch(ids);

    expect(
      await bootstrapper.submitReleaseHealthBatch(
        hostPlatform: HostPlatform.android,
        batch: batch,
        correlationId: correlationId,
      ),
      isFalse,
      reason: 'telemetry must not create a trial/session identity',
    );
    final stateFile = File(
      '${directory.path}${Platform.pathSeparator}'
      'app-first-session-android.json',
    );
    final state = jsonDecode(await stateFile.readAsString()) as Map;
    final installId = state['install_id'].toString();
    await secrets.writeSessionPair(
      hostPlatform: HostPlatform.android,
      installId: installId,
      pair: const AppFirstSessionCredentials(
        accessToken: 'test-session-token',
        refreshToken: 'test-refresh-token',
      ),
    );

    expect(
      await bootstrapper.submitReleaseHealthBatch(
        hostPlatform: HostPlatform.android,
        batch: batch,
        correlationId: correlationId,
      ),
      isTrue,
    );
    await responseDone.future;
    expect(
      captured!.uri.path,
      '/api/client/observability/release-health/batches',
    );
    expect(captured!.headers.value('X-Correlation-ID'), correlationId);
    expect(capturedBody!['schema_version'], 1);
    expect((capturedBody!['events'] as List).length, 1);
    expect(jsonEncode(capturedBody), isNot(contains('correlation')));
    expect(
      captured!.headers.value(HttpHeaders.authorizationHeader),
      'Bearer test-session-token',
    );
  });

  test('bootstrap failures expose stable closed portal codes', () {
    expect(
      const BootstrapFailure('safe', statusCode: 401).operationalErrorCode,
      'API-004',
    );
    expect(
      const BootstrapFailure(
        'safe',
        operationalCode: 'API-003',
      ).operationalErrorCode,
      'API-003',
    );
    expect(
      const BootstrapFailure(
        'safe',
        code: 'device_limit_exceeded',
      ).operationalErrorCode,
      'AUTH-004',
    );
  });
}

OperationalBuildIdentity _build() => OperationalBuildIdentity(
      appVersion: '1.2.0',
      buildNumber: '30',
      channel: 'local',
      candidateLabel: 'pokrov-1.2.0-local',
      gitRevision: '0123456789abcdef0123456789abcdef01234567',
      coreVersion: '1.2.0',
      coreAbi: 2,
      platform: 'android',
      architecture: 'arm64-v8a',
    );

RuntimeSnapshot _verifiedSnapshot() => const RuntimeSnapshot(
      hostPlatform: HostPlatform.android,
      lane: RuntimeLane.mobileArtifact,
      phase: RuntimePhase.running,
      artifactDirectory: null,
      coreBinaryPath: null,
      helperBinaryPath: null,
      stagedConfigPath: null,
      supportsLiveConnect: true,
      canInitialize: false,
      canConnect: true,
      message: 'verified',
      hostHealth: RuntimeHostHealth.healthy,
      dnsState: RuntimeDiagnosticState.healthy,
      uplinkState: RuntimeDiagnosticState.healthy,
      dnsReady: true,
      coreEgressValidated: true,
      coreEgressValidationRequired: true,
    );

Map<String, Object?> _releaseHealthBatch(OperationalIdFactory ids) =>
    <String, Object?>{
      'schema_version': 1,
      'events': <Object?>[
        <String, Object?>{
          'schema_version': 1,
          'event_id': ids.uuidV4(),
          'occurred_at_utc': '2026-08-21T10:00:00.000Z',
          'component': 'app',
          'subsystem': 'connection',
          'stage': 'complete',
          'name': 'app.connection.attempt.finished',
          'severity': 'info',
          'outcome': 'succeeded',
          'privacy_class': 'release_health',
          'build': _build().toJson(),
          'error': null,
        },
      ],
    };

final class _ReleaseHealthCapture implements AppFirstReleaseHealthService {
  final List<Map<String, Object?>> batches = <Map<String, Object?>>[];
  final List<String> correlations = <String>[];

  @override
  Future<bool> submitReleaseHealthBatch({
    required HostPlatform hostPlatform,
    required Map<String, Object?> batch,
    required String correlationId,
  }) async {
    batches.add(batch);
    correlations.add(correlationId);
    return true;
  }
}

DiagnosticSnapshot _diagnosticSnapshot() => DiagnosticSnapshot(
      build: DiagnosticBuildSummary(
        platform: 'android',
        appVersion: '1.2.0',
        buildId: 'candidate-test',
        channel: 'direct',
      ),
      network: DiagnosticNetworkSummary(
        routeMode: 'selected_apps',
        connectionState: 'verified',
        hostHealth: 'healthy',
        dnsState: 'healthy',
        egressState: 'healthy',
        warpState: 'disabled',
      ),
    );
