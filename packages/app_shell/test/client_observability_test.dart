import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/app_shell.dart';
import 'package:pokrov_core_domain/core_domain.dart';
import 'package:pokrov_diagnostics_collectors/diagnostics_collectors.dart';
import 'package:pokrov_observability_contracts/observability_contracts.dart';
import 'package:pokrov_observability_runtime/observability_runtime.dart';
import 'package:pokrov_runtime_engine/runtime_engine.dart';
import 'package:pokrov_support_bundle/support_bundle.dart';

void main() {
  test('crash handlers retain safe markers without forwarding raw errors',
      () async {
    // Flutter 3.38's test dispatcher drops onError assignments; use the real one.
    WidgetsFlutterBinding.ensureInitialized();
    final root = await Directory.systemTemp.createTemp('pokrov-crash-sinks-');
    addTearDown(() => root.delete(recursive: true));
    final observability = await PokrovClientObservability.start(
      hostPlatform: HostPlatform.android,
      directoryResolver: () async => root,
      buildIdentity: _build(),
    );
    final dispatcher = WidgetsBinding.instance.platformDispatcher;
    final oldFlutterHandler = FlutterError.onError;
    final oldPlatformHandler = dispatcher.onError;
    final oldDebugPrint = debugPrint;
    addTearDown(() {
      FlutterError.onError = oldFlutterHandler;
      dispatcher.onError = oldPlatformHandler;
      debugPrint = oldDebugPrint;
    });
    final console = <String?>[];
    final platformForwarding = <String>[];
    debugPrint = (message, {wrapWidth}) => console.add(message);
    FlutterError.onError = FlutterError.dumpErrorToConsole;
    dispatcher.onError = (error, stack) {
      platformForwarding.add('$error\n$stack');
      return false;
    };
    installPokrovCrashHandlers(observability);
    const canary = 'R12_DART_CRASH_SECRET_20260912';
    final error = StateError('password=$canary https://example.invalid/$canary');
    final stack = StackTrace.fromString('/private/$canary.dart:1');
    FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack));
    final platformHandled = dispatcher.onError!(error, stack);
    await observability.flush();

    expect(console, isEmpty);
    expect(platformForwarding, isEmpty);
    expect(platformHandled, isTrue);
    expect(observability.crashDiagnostics.single.errorCode, 'CRASH-001');
    expect(observability.crashDiagnostics.single.signature, 'c101000000000000');
    expect(await observability.markerStore.file.readAsString(),
        isNot(contains(canary)));
  });

  test('crash signature retains only closed error and owned source location',
      () {
    const canary = 'R12_DART_CRASH_SECRET_20260912';
    final stack = StackTrace.fromString(
      '#0 private (file:///$canary.dart:123:45)\n'
      '#1 connect (package:pokrov_app_shell/app_first_runtime_bootstrap.dart:1263:7)\n'
      '#2 unknown (package:pokrov_app_shell/$canary.dart:4:2)',
    );
    expect(pokrovSafeCrashSignature(StateError('password=$canary'), stack),
        'c10101000004ef00');
    expect(pokrovSafeCrashSignature(ArgumentError(canary), null),
        'c103000000000000');
  });

  test('validated crash marker reaches diagnostics after restart', () async {
    final root = await Directory.systemTemp.createTemp('pokrov-crash-preview-');
    addTearDown(() => root.delete(recursive: true));
    Future<PokrovClientObservability> start() =>
        PokrovClientObservability.start(
          hostPlatform: HostPlatform.windows,
          directoryResolver: () async => root,
          buildIdentity: _build(),
        );
    final first = await start();
    expect(first.crashDiagnostics, isEmpty);
    first.markCrashSynchronously();
    final crash = first.crashDiagnostics.single;
    expect(crash.errorCode, 'CRASH-001');
    await first.flush();
    final restarted = await start();
    expect(restarted.crashDiagnostics.single.signature, crash.signature);
    expect(restarted.crashDiagnostics.single.toJson().keys,
        unorderedEquals(['occurred_at', 'error_code', 'signature']));
    await restarted.markCrash(errorCode: 'CRASH-003');
    expect(restarted.crashDiagnostics.map((record) => record.errorCode),
        ['CRASH-001', 'CRASH-003']);
    await restarted.markCrash(errorCode: 'CRASH-002');
    expect(restarted.crashDiagnostics.map((record) => record.errorCode),
        ['CRASH-001', 'CRASH-002']);
    await restarted.flush();
  });

  test('diagnostic storage failure preserves bootstrap and connection actions',
      () async {
    final root =
        await Directory.systemTemp.createTemp('pokrov-obs-unavailable-');
    addTearDown(() => root.delete(recursive: true));
    final blocked = File('${root.path}/pokrov-observability');
    await blocked.writeAsString('owned diagnostic path-conflict fixture');
    final observability = await PokrovClientObservability.start(
      hostPlatform: HostPlatform.windows,
      directoryResolver: () async => root,
      buildIdentity: _build(),
    );

    observability.markUiReady();
    var connectionActionRan = false;
    await observability.runConnectionAction(() async {
      connectionActionRan = true;
    }, beginsWithDisconnect: false);
    await observability.markCleanExit();
    await observability.markCrash();
    observability.markCrashSynchronously();
    await observability.flush();

    expect(connectionActionRan, isTrue);
    expect(observability.dispatcher.breadcrumbs.snapshot().map((e) => e.name),
        contains('app.bootstrap.ui_ready.finished'));
    expect(observability.dispatcher.snapshot().writerErrors, greaterThan(0));
    expect(observability.markerStore.writeErrors, 4);
    expect(
        await blocked.readAsString(), 'owned diagnostic path-conflict fixture');

    await blocked.delete();
    observability.recordAuthRequestStarted();
    await observability.flush();
    expect(await File('${blocked.path}/operational-events.v1.0.jsonl').exists(),
        isTrue);
    await observability.markCrash();
    expect(await observability.markerStore.file.exists(), isTrue);
    expect(observability.markerStore.writeErrors, 4);
  });

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
    observability.recordAndroidRoutingAppCount(3);
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

    final authorization = Completer<void>();
    final connection = observability.runConnectionAction(
      () async {
        await authorization.future;
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
    observability.observeConnection(const ConnectionIdle());
    await observability.flush();
    expect(
      observability.connectionTimelineBreadcrumbs
          .where((event) => event.name == 'app.connection.attempt.finished'),
      isEmpty,
      reason: 'initial Idle while permission is pending is not cancellation',
    );
    authorization.complete();
    await connection;
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
    final mirror = observability.dispatcher.writer as ReleaseHealthMirrorWriter;
    final store = mirror.localWriter as RotatingOperationalJsonlStore;
    final local = await store.readCurrent();
    expect(
      local.records
          .where((event) => event['name'] == 'app.connection.attempt.finished')
          .map((event) => event['outcome']),
      ['succeeded'],
    );
    expect(
      remoteEvents
          .where((event) => event['name'] == 'app.connection.attempt.finished')
          .map((event) => event['outcome']),
      ['succeeded'],
    );

    final staleRelease = Completer<void>();
    final staleAction = observability.runConnectionAction(
      () => staleRelease.future,
      beginsWithDisconnect: false,
    );
    observability.observeConnection(const ConnectionIdle());
    final currentRelease = Completer<void>();
    final currentAction = observability.runConnectionAction(
      () => currentRelease.future,
      beginsWithDisconnect: false,
    );
    observability.observeConnection(const ConnectionIdle());
    staleRelease.complete();
    await staleAction;
    await observability.flush();
    expect(
      (await store.readCurrent()).records
          .where((event) => event['name'] == 'app.connection.attempt.finished')
          .map((event) => event['outcome']),
      ['succeeded', 'superseded'],
      reason: 'an old completion cannot settle the current pending Idle',
    );
    currentRelease.complete();
    await currentAction;
    await observability.flush();
    expect(
      (await store.readCurrent()).records
          .where((event) => event['name'] == 'app.connection.attempt.finished')
          .map((event) => event['outcome']),
      ['succeeded', 'superseded', 'cancelled'],
      reason: 'settled Idle still completes cancellation without another frame',
    );
    expect(observability.dispatcher.snapshot().rejectedAsStale, 0);
  });

  test('connection failure survives interleaved account refresh events',
      () async {
    final directory = await Directory.systemTemp.createTemp('pokrov-obs-fail-');
    addTearDown(() => directory.delete(recursive: true));
    final releaseHealth = _ReleaseHealthCapture();
    final observability = await PokrovClientObservability.start(
      hostPlatform: HostPlatform.android,
      directoryResolver: () async => directory,
      buildIdentity: _build(),
      idFactory: OperationalIdFactory(random: Random(103)),
      releaseHealthService: releaseHealth,
    );

    const failure = BootstrapFailure(
      'vless://private-preparation-fixture',
      statusCode: 503,
      code: 'routing_catalog_unavailable',
      operation: 'GET https://private-operation.invalid/profile',
      apiFailureKind: 'origin_socket',
      observedHttpStatus: 200,
      osErrorCode: 10061,
    );

    await observability.runConnectionAction(
      () async {
        observability.recordAuthRequestStarted();
        observability.recordEntitlementRefreshStarted();
        observability.recordAuthRequestFinished(errorCode: failure.operationalErrorCode, failure: failure);
        observability.recordEntitlementRefreshFinished(errorCode: failure.operationalErrorCode, failure: failure);
        observability.recordConnectionFailure(
          stage: ConnectionStage.profile,
          errorCode: failure.operationalErrorCode,
          errorOrigin: ObservabilityErrorOrigin.portal,
          preparationFailure: failure,
        );
      },
      beginsWithDisconnect: false,
    );
    await observability.flush();

    final terminal = observability.dispatcher.breadcrumbs.snapshot().lastWhere(
          (event) => event.name == 'app.connection.attempt.finished',
        );
    expect(terminal.outcome.wireValue, 'failed');
    expect(terminal.errorCode, 'API-007');

    const unknown = BootstrapFailure(
      'Bearer private-preparation-message',
      code: 'catalog_signature_invalid/private-reason-fixture',
      statusCode: 700,
      operation: 'GET https://private-operation.invalid/profile',
      apiFailureKind: 'https://private-reason.invalid',
      observedHttpStatus: 700,
      osErrorCode: -1,
    );
    await observability.runConnectionAction(() async {
      observability.recordConnectionFailure(
        stage: ConnectionStage.profile,
        errorCode: unknown.operationalErrorCode,
        preparationFailure: unknown,
      );
    }, beginsWithDisconnect: false);
    await observability.flush();

    final mirror = observability.dispatcher.writer as ReleaseHealthMirrorWriter;
    final local = await (mirror.localWriter as RotatingOperationalJsonlStore)
        .readCurrent();
    final failures = local.records
        .where((event) => event['name'] == 'app.connection.profile.finished')
        .toList();
    expect(failures, hasLength(2));
    expect(failures.first['attributes'], containsPair('http_status', 200));
    expect(failures.first['attributes'], containsPair('api_failure_kind', 'origin_socket'));
    expect(failures.first['attributes'], containsPair('os_error_code', 10061));
    expect(failures.first['attributes'],
        containsPair('prepare_reason', 'routing_catalog_unavailable'));
    expect(failures.last['attributes'], isNot(contains('prepare_reason')));
    expect(failures.last['attributes'], isNot(contains('http_status')));
    expect(failures.last['attributes'], isNot(contains('api_failure_kind')));
    expect(failures.last['attributes'], isNot(contains('os_error_code')));
    final accountFailures = local.records.where((event) =>
        event['name'] == 'app.auth.request.finished' || event['name'] == 'app.entitlement.refresh.finished');
    expect(accountFailures, hasLength(2));
    for (final event in accountFailures) {
      expect(event['attributes'], containsPair('api_failure_kind', 'origin_socket'));
      expect(event['attributes'], containsPair('http_status', 200));
      expect(event['attributes'], containsPair('os_error_code', 10061));
    }
    expect(local.records.where(
        (event) => event['name'] == 'app.connection.attempt.finished'),
        hasLength(2));
    final serialized = jsonEncode(local.records);
    expect(serialized, isNot(contains(failure.message)));
    expect(serialized, isNot(contains(unknown.message)));
    expect(serialized, isNot(contains(unknown.code)));
    expect(serialized, isNot(contains(failure.operation!)));
    final remote = jsonEncode(releaseHealth.batches);
    expect(remote, isNot(contains('http_status')));
    expect(remote, isNot(contains('prepare_reason')));
    expect(remote, isNot(contains('api_failure_kind')));
    expect(remote, isNot(contains('os_error_code')));
    expect(observability.dispatcher.snapshot().rejectedByPrivacy, 0);
    expect(observability.dispatcher.snapshot().rejectedAsStale, 0);
  });

  test(
      'probe budget expiry and later success do not interrupt connection',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('pokrov-obs-probe-');
    addTearDown(() => directory.delete(recursive: true));
    final observability = await PokrovClientObservability.start(
      hostPlatform: HostPlatform.windows,
      directoryResolver: () async => directory,
      buildIdentity: _build(),
    );

    await observability.runConnectionAction(() async {
      observability.recordCandidateProbe(
        failureKind: 'probe_budget_expired',
        duration: const Duration(milliseconds: 134512),
      );
      observability.recordCandidateProbe(
        failureKind: 'data_stalled',
        duration: const Duration(milliseconds: 2000),
        probeStage: 'http_64k',
      );
      observability.recordCandidateProbe(
        failureKind: 'connect_failed',
        duration: const Duration(milliseconds: 777),
        probeStage: 'proxy_dial',
      );
      observability.recordCandidateProbe(
        failureKind: 'tls_failed',
        duration: const Duration(milliseconds: 888),
        probeStage: 'tls_read',
      );
      observability.recordCandidateProbe(
        failureKind: '',
        duration: const Duration(milliseconds: 737),
        probeStage: 'unknown_phase',
      );
    }, beginsWithDisconnect: false);
    observability.recordRuntimeStatsDeliveryFailure(errorCode: 'API-002');
    await observability.flush();

    final events = observability.dispatcher.breadcrumbs.snapshot()
        .where((value) => value.name == 'app.connection.candidate_probe.finished')
        .toList();
    expect(events, hasLength(5));
    expect(events.last.outcome.wireValue, 'succeeded');
    expect(events.last.errorCode, isNull);
    final recorded = await File(
      '${directory.path}/pokrov-observability/operational-events.v1.0.jsonl',
    ).readAsLines();
    final probes = recorded
        .map((line) => jsonDecode(line) as Map<String, dynamic>)
        .where((value) => value['name'] == 'app.connection.candidate_probe.finished')
        .toList();
    expect(probes.map((probe) =>
        (probe['attributes'] as Map<String, dynamic>)['failure_kind']),
        ['probe_budget_expired', 'data_stalled', 'connect_failed', 'tls_failed', 'none']);
    expect(probes.map((probe) => (probe['attributes'] as Map)['probe_stage']),
        [null, 'http_64k', 'proxy_dial', 'tls_read', null]);
    expect(observability.dispatcher.snapshot().rejectedByPrivacy, 0);
    expect((probes.first['attributes'] as Map<String, dynamic>)['duration_ms'],
        134512);
    expect(recorded.map((line) => jsonDecode(line) as Map<String, dynamic>)
        .where((value) => value['name'] == 'app.runtime.stats_delivery.finished')
        .single['stage'], 'complete');
    await observability.runConnectionAction(() async {
      observability.recordCandidateProbe(
        failureKind: 'unavailable', duration: Duration.zero,
      );
    }, beginsWithDisconnect: false);
    final stageLess = observability.dispatcher.breadcrumbs.snapshot()
        .lastWhere((event) => event.name == 'app.connection.candidate_probe.finished');
    expect(stageLess.failureKind, 'unavailable');
    expect(stageLess.probeStage, isNull);
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

  test(
      'release-health baseline is existing-session-only and exact-build scoped',
      () async {
    final directory = await Directory.systemTemp.createTemp('pokrov-obs-api-');
    addTearDown(() => directory.delete(recursive: true));
    final secrets = MemoryAppFirstSessionSecretStore();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    HttpRequest? captured;
    var requestCount = 0;
    server.listen((request) async {
      requestCount += 1;
      captured = request;
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(_releaseHealthBaselinePayload()));
      await request.response.close();
    });
    final bootstrapper = AppFirstRuntimeBootstrapper(
      apiBaseUrl: 'http://${server.address.host}:${server.port}',
      supportDirectoryResolver: () async => directory,
      sessionSecretStore: secrets,
      maxRequestAttempts: 1,
    );

    final unavailable = await bootstrapper.fetchReleaseHealthBaseline(
      hostPlatform: HostPlatform.android,
      build: _build(),
    );
    expect(unavailable.state, ClientReleaseHealthBaselineState.unavailable);
    expect(requestCount, 0, reason: 'baseline must not create a trial session');

    final stateFile = File(
      '${directory.path}${Platform.pathSeparator}'
      'app-first-session-android.json',
    );
    final state = jsonDecode(await stateFile.readAsString()) as Map;
    await secrets.writeSessionPair(
      hostPlatform: HostPlatform.android,
      installId: state['install_id'].toString(),
      pair: const AppFirstSessionCredentials(
        accessToken: 'test-session-token',
        refreshToken: 'test-refresh-token',
      ),
    );

    final baseline = await bootstrapper.fetchReleaseHealthBaseline(
      hostPlatform: HostPlatform.android,
      build: _build(),
    );

    expect(baseline.canCompare, isTrue);
    expect(requestCount, 1);
    expect(
      captured!.uri.path,
      '/api/client/observability/release-health/baseline',
    );
    expect(captured!.uri.queryParameters['build_number'], '30');
    expect(captured!.uri.queryParameters['platform'], 'android');
    expect(captured!.uri.queryParameters['core_abi'], '2');
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

Map<String, Object?> _releaseHealthBaselinePayload() => <String, Object?>{
      'schema_version': 1,
      'state': 'available',
      'scope': <String, Object?>{
        'app_version': '1.2.0',
        'build_number': '30',
        'channel': 'local',
        'candidate_label': 'pokrov-1.2.0-local',
        'git_revision': '0123456789abcdef0123456789abcdef01234567',
        'core_abi': 2,
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

  @override
  Future<ClientReleaseHealthBaseline> fetchReleaseHealthBaseline({
    required HostPlatform hostPlatform,
    required OperationalBuildIdentity build,
  }) async =>
      const ClientReleaseHealthBaseline.unavailable();
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
