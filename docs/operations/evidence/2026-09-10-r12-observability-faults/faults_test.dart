import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/app_shell.dart';
import 'package:pokrov_app_shell/app_first_runtime_bootstrap.dart';
import 'package:pokrov_core_domain/core_domain.dart';
import 'package:pokrov_diagnostics_collectors/diagnostics_collectors.dart';
import 'package:pokrov_observability_contracts/observability_contracts.dart';
import 'package:pokrov_observability_runtime/observability_runtime.dart';
import 'package:pokrov_support_bundle/support_bundle.dart';

const outputRoot = 'E:/r12-observability-faults-20260910';
void retain(String name, Map<String, Object?> result) {
  File('$outputRoot/$name.json').writeAsStringSync('${const JsonEncoder.withIndent('  ').convert({
    'utc': DateTime.now().toUtc().toIso8601String(),
    'source': '6816aaba1e9526ba84182d8b13ecd20569e37d23',
    'scope': 'Current-source local Dart harness; not physical device acceptance',
    ...result,
  })}\n');
}

Future<Directory> ownedRoot() async {
  final root = await Directory.systemTemp.createTemp('r12-v03-fault-');
  addTearDown(() async {
    final temp = await Directory.systemTemp.resolveSymbolicLinks();
    final actual = await root.resolveSymbolicLinks();
    if (!actual.startsWith('$temp${Platform.pathSeparator}r12-v03-fault-')) {
      throw StateError('Cleanup target escaped the owned temporary directory');
    }
    await root.delete(recursive: true);
  });
  return root;
}

void main() {
  test('corrupt journal and unsupported exit marker do not block bootstrap', () async {
    final root = await ownedRoot();
    final directory = Directory('${root.path}/pokrov-observability');
    await directory.create();
    final journal = File('${directory.path}/operational-events.v1.0.jsonl');
    await journal.writeAsString('not-json\n{"schema_version":999}\n{"truncated":');
    await File('${directory.path}/previous-exit.v1.json').writeAsString('{"schema_version":999}');
    final client = await PokrovClientObservability.start(
      hostPlatform: HostPlatform.windows, directoryResolver: () async => root,
      buildIdentity: _build(),
    );
    client.markUiReady();
    final result = await client.runConnectionAction(() async => 42, beginsWithDisconnect: false);
    await client.flush();
    expect(result, 42);
    expect(client.connectionTimelineBreadcrumbs, isNotEmpty);
    expect(client.dispatcher.breadcrumbs.snapshot().map((e) => e.errorCode), contains('APP-BOOT-008'));
    final repaired = await RotatingOperationalJsonlStore.readValidRecords(journal);
    expect(repaired.truncatedTailIgnored, isFalse);
    expect(repaired.invalidLines, 1);
    expect(repaired.records.any((e) => e['name'] == 'app.bootstrap.ui_ready.finished'), isTrue);
    expect(client.dispatcher.snapshot().truncatedTailRecoveries, 1);
    retain('corrupt-schema', {'status':'PASS', 'connection_callback_completed':true,
      'unsupported_marker_error':'APP-BOOT-008', 'invalid_complete_lines':repaired.invalidLines,
      'partial_tail_repaired':true, 'ui_ready_persisted':true});
  });

  test('event storm and full queue cannot wait on stalled release-health transport', () async {
    final root = await ownedRoot();
    final service = _StalledHealth();
    final client = await PokrovClientObservability.start(
      hostPlatform: HostPlatform.windows, directoryResolver: () async => root,
      releaseHealthService: service, buildIdentity: _build(),
    );
    client.markUiReady();
    await service.entered.future.timeout(const Duration(seconds: 5));
    final storm = Stopwatch()..start();
    for (var i = 0; i < 20000; i++) {
      client.recordAuthRequestStarted();
      if (i % 256 == 0) await Future<void>.delayed(Duration.zero);
    }
    storm.stop();
    final pressure = client.dispatcher.snapshot();
    expect(pressure.queue.dropped, greaterThan(0));
    expect(pressure.queue.depth, lessThanOrEqualTo(4096));
    expect(pressure.queue.bytes, lessThanOrEqualTo(4 * 1024 * 1024));
    final action = Stopwatch()..start();
    expect(await client.runConnectionAction(() async => 'completed', beginsWithDisconnect: false)
      .timeout(const Duration(seconds: 2)), 'completed');
    action.stop();
    expect(service.gate.isCompleted, isFalse);
    expect(client.dispatcher.breadcrumbs.snapshot().length, lessThanOrEqualTo(256));
    service.gate.complete(false);
    await client.flush().timeout(const Duration(seconds: 10));
    final mirror = client.dispatcher.writer as ReleaseHealthMirrorWriter;
    expect(mirror.snapshot().rejectedBatches, greaterThan(0));
    expect(client.dispatcher.snapshot().queue.depth, 0);
    retain('queue-storm', {'status':'PASS', 'storm_events':20000,
      'storm_elapsed_ms':storm.elapsedMilliseconds, 'queue_depth':pressure.queue.depth,
      'queue_bytes':pressure.queue.bytes, 'dropped':pressure.queue.dropped,
      'dropped_by_severity':{for(final e in pressure.queue.droppedBySeverity.entries)e.key.name:e.value},
      'callback_elapsed_us':action.elapsedMicroseconds, 'callback_before_transport_release':true,
      'rejected_health_batches':mirror.snapshot().rejectedBatches, 'queue_drained_after_release':true});
  });

  test('backward and forward diagnostic clock jumps preserve ordered terminals', () async {
    final writer = _MemoryWriter();
    final dispatcher = OperationalEventDispatcher(writer: writer);
    var now = DateTime.utc(2026,9,10,12);
    final ids = OperationalIdFactory(random: Random(10));
    final timeline = OperationalAttemptTimeline(dispatcher: dispatcher, build: _build(),
      runId:ids.uuidV4(), attemptId:ids.uuidV4(), generation:1, ids:ids, clock:()=>now)..start();
    timeline.enter(OperationalTimelinePhase.profile);
    now = now.subtract(const Duration(days: 1));
    timeline.complete(OperationalTimelinePhase.profile, outcome: ObservabilityOutcome.succeeded);
    timeline.enter(OperationalTimelinePhase.core);
    now = now.add(const Duration(days: 365));
    timeline.finish(OperationalTerminalKind.failed, errorCode:'CORE-003');
    await dispatcher.flush();
    final phases = writer.events.where((e)=>e.name.endsWith('.finished')).toList();
    expect(phases.singleWhere((e)=>e.name=='app.connection.profile.finished').attributes['duration_ms'],0);
    expect(phases.singleWhere((e)=>e.name=='app.connection.core.finished').attributes['duration_ms'],86400000);
    expect(phases.last.name,'app.connection.attempt.finished');
    expect(phases.last.error?.code,'CORE-003');
    expect(dispatcher.snapshot().rejectedAsStale,0);
    retain('clock-jumps',{'status':'PASS','controlled_clock_offsets_days':[-1,365],
      'ordered_sequence':writer.events.map((e)=>e.correlation.sequence).toList(),
      'phase_durations_ms':[0,86400000],'terminal':'failed','terminal_error':'CORE-003',
      'system_clock_changed':false});
  });

  test('real HTTP chunk timeout preserves encrypted outbox and concurrent action', () async {
    final root = await ownedRoot();
    final now = DateTime.now().toUtc();
    final fixture = await _keySetFixture(now);
    FlutterSecureStorage.setMockInitialValues({
      'pokrov.app_first.session.windows.install-v03-http': 'fixture-session-only',
    });
    await File('${root.path}/app-first-session-windows.json').writeAsString(jsonEncode({
      'install_id':'install-v03-http','account_id':'fixture-account',
      'managed_manifest_path':'/api/client/profile/managed','profile_revision':'',
    }));
    final firstChunk = Completer<void>();
    final requests = <String>[];
    var chunkAttempts = 0;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4,0);
    addTearDown(()=>server.close(force:true));
    server.listen((request) async {
      requests.add('${request.method} ${request.uri.path}');
      await request.drain<void>();
      final path=request.uri.path;
      if(path.endsWith('/chunks')) {
        chunkAttempts++;
        if(!firstChunk.isCompleted) firstChunk.complete();
        return; // Deliberately never send response headers; production HTTP timeout owns recovery.
      }
      request.response.headers.contentType=ContentType.json;
      if(path.endsWith('/key-set')) {
        request.response.write(jsonEncode(fixture.envelope));
      } else if(path.endsWith('/upload-tickets')) {
        request.response.write(jsonEncode({'upload_id':'68c6aa53-55f0-4afe-9a80-b72f0cfdcc99',
          'upload_ticket':'fixture-ticket-only','ticket_id':1,'next_offset':0,'status':'issued'}));
      } else {request.response.statusCode=404;request.response.write('{}');}
      await request.response.close();
    });
    final service=AppFirstSupportTicketService(apiBaseUrl:'http://127.0.0.1:${server.port}',
      supportDirectoryResolver:()=>Future.value(root), supportSigningPublicKeysById:{'root-test':fixture.signingPublicKey},
      maxRequestAttempts:1, connectionTimeout:const Duration(milliseconds:500),
      requestTimeout:const Duration(milliseconds:100), delayScheduler:(_)async{});
    final prepared=const SupportBundleBuilder().prepare(snapshot:_snapshot(),
      profile:SupportDiagnosticProfile.summary,now:now);
    final client=await PokrovClientObservability.start(hostPlatform:HostPlatform.windows,
      directoryResolver:()=>Future.value(root),buildIdentity:_build());
    var finished=false;
    final pending=service.deliverSupportBundle(hostPlatform:HostPlatform.windows,
      prepared:prepared,caseSummary:'Owned timeout fixture').whenComplete(()=>finished=true);
    await firstChunk.future.timeout(const Duration(seconds:5));
    final watch=Stopwatch()..start();
    expect(await client.runConnectionAction(()async=>7,beginsWithDisconnect:false),7);
    watch.stop();
    expect(finished,isFalse);
    final result=await pending.timeout(const Duration(seconds:5));
    expect(result.state,SupportBundleDeliveryState.offlineEncrypted);
    expect(chunkAttempts,3);
    final outbox=PokrovFileSupportBundleOutbox(directoryResolver:()=>Future.value(root));
    final stored=await outbox.load(prepared.preview.diagnosticId);
    expect(stored,isNotNull);
    final envelope=jsonDecode(utf8.decode(stored!.bytes)) as Map;
    expect(envelope['ciphertext_b64'],isNotEmpty);
    expect(envelope.containsKey('files'),isFalse);
    expect(envelope.containsKey('connection_state'),isFalse);
    await client.flush();
    retain('http-upload-timeout',{'status':'PASS','http_chunk_timeouts':chunkAttempts,
      'requests':requests,'delivery_state':result.state.name,'failure_code':result.failureCode,
      'outbox_bytes':stored.bytes.length,'outbox_encrypted':true,
      'callback_before_upload_finished':true,'callback_elapsed_us':watch.elapsedMicroseconds,
      'session_store':'in-memory test plugin; no real credentials'});
  });
}

OperationalBuildIdentity _build()=>OperationalBuildIdentity(appVersion:'1.2.0',
  buildNumber:'4053',channel:'local',candidateLabel:'pokrov-1.2.0-local',
  gitRevision:'6816aaba1e9526ba84182d8b13ecd20569e37d23',coreVersion:'1.1.0',
  coreAbi:2,platform:'windows',architecture:'x64');

final class _MemoryWriter implements OperationalEventWriter {
  final events=<OperationalEvent>[];
  @override Future<void> appendBatch(List<SerializedOperationalEvent> records)async {
    events.addAll(records.map((e)=>e.event));
  }
}

final class _StalledHealth implements AppFirstReleaseHealthService {
  final entered=Completer<void>();
  final gate=Completer<bool>();
  @override Future<bool> submitReleaseHealthBatch({required HostPlatform hostPlatform,
    required Map<String,Object?> batch,required String correlationId})async {
    if(!entered.isCompleted)entered.complete();
    return gate.future;
  }
  @override Future<ClientReleaseHealthBaseline> fetchReleaseHealthBaseline({
    required HostPlatform hostPlatform,required OperationalBuildIdentity build})async=>
      const ClientReleaseHealthBaseline.unavailable();
}

Future<
    ({
      Map<String, Object?> envelope,
      String signingPublicKey,
      VerifiedSupportRecipient recipient,
    })> _keySetFixture(DateTime now) async {
  final signing = Ed25519();
  final signingPair = await signing.newKeyPair();
  final signingPublic = await signingPair.extractPublicKey();
  final recipientPair = await X25519().newKeyPair();
  final recipientPublic = await recipientPair.extractPublicKey();
  final payload = <String, Object?>{
    'expires_at': now.add(const Duration(days: 7)).toIso8601String(),
    'issued_at': now.subtract(const Duration(minutes: 1)).toIso8601String(),
    'keys': <Object?>[
      <String, Object?>{
        'algorithm': 'X25519-HKDF-SHA256-AES-256-GCM',
        'key_id': 'support-test-1',
        'not_after': now.add(const Duration(days: 6)).toIso8601String(),
        'public_key_b64': _b64(recipientPublic.bytes),
      },
    ],
    'schema_version': 1,
    'type': 'pokrov.support.key_set',
  };
  final payloadBytes = utf8.encode(jsonEncode(payload));
  final signature = await signing.sign(payloadBytes, keyPair: signingPair);
  final signingPublicKey = _b64(signingPublic.bytes);
  final envelope = <String, Object?>{
    'algorithm': 'Ed25519',
    'key_id': 'root-test',
    'payload_b64': _b64(payloadBytes),
    'schema_version': 1,
    'signature_b64': _b64(signature.bytes),
  };
  final keySet = await SupportSignedContractVerifier(
    signingPublicKeysById: <String, String>{
      'root-test': signingPublicKey,
    },
  ).verifyKeySet(
    envelope,
    now: now,
  );
  return (
    envelope: envelope,
    signingPublicKey: signingPublicKey,
    recipient: keySet.activeRecipient(now),
  );
}

DiagnosticSnapshot _snapshot() => DiagnosticSnapshot(
      build: DiagnosticBuildSummary(
        platform: 'windows',
        appVersion: '1.2.0',
        buildId: 'candidate-test',
        channel: 'stable',
      ),
      network: DiagnosticNetworkSummary(
        routeMode: 'all_except_ru',
        connectionState: 'degraded',
        hostHealth: 'healthy',
        dnsState: 'healthy',
        egressState: 'failed',
        warpState: 'fallback',
      ),
    );

String _b64(List<int> value) => base64UrlEncode(value).replaceAll('=', '');

