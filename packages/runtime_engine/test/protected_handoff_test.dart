import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_core_domain/core_domain.dart';
import 'package:pokrov_runtime_engine/runtime_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final platform in [HostPlatform.android, HostPlatform.windows]) {
    test('protected replacement on ${platform.name} reuses staging transforms and keeps failure under its request owner', () async {
      const channel = MethodChannel('space.pokrov/runtime_engine');
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final calls = <String>[];
      Map<Object?, Object?>? staged;
      Map<Object?, Object?>? replaced;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        final arguments = Map<Object?, Object?>.from(call.arguments as Map? ?? {});
        if (call.method == 'runtimeEngine.cancelConnectRequest') {
          return {'schema': 1, 'requestId': arguments['requestId'], 'cancelled': true};
        }
        if (call.method == 'runtimeEngine.stageManagedProfile') staged = arguments;
        if (call.method == 'runtimeEngine.replaceManagedProfile') replaced = arguments;
        return {
          'phase': replaced == null ? 'configStaged' : 'running',
          'stagedConfigPath': '/host/runtime/materialized.json',
          'supportsLiveConnect': true, 'canInitialize': false, 'canConnect': true,
          'coreEgressValidated': false, 'coreEgressValidationRequired': true,
          if (replaced != null) 'lastFailureKind': 'protected_handoff_failed',
        };
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final engine = createRuntimeEngine(hostPlatform: platform);
      const payload = ManagedProfilePayload(
        profileName: 'materialized', materializedForRuntime: true,
        routeMode: RouteMode.allExceptRu, disableMemoryLimit: true,
        configPayload: '{"inbounds":[{"type":"tun"}],"outbounds":[{"type":"direct","tag":"direct"}],"route":{"rules":[{"ip_is_private":true,"outbound":"direct"}],"final":"direct"},"_meta":{"title":"display only"}}',
      );
      await engine.stageManagedProfile(payload);
      final result = await (engine as RuntimeProtectedHandoff).replaceManagedProfile(payload, operationIsCurrent: () => true);
      final cancellation = engine as RuntimeConnectCancellation;
      expect(replaced?['requestId'], cancellation.activeConnectRequestId);
      expect(replaced?['requiresBoundConnect'], isFalse);
      expect(replaced?['configPayload'], staged?['configPayload']);
      expect(jsonDecode(replaced!['configPayload'] as String), isNot(contains('_meta')));
      final inbound = (jsonDecode(replaced!['configPayload'] as String)['inbounds'] as List).single as Map;
      expect(inbound['interface_name'], platform == HostPlatform.windows ? 'POKROV' : isNull);
      expect(replaced?['routeMode'], RouteMode.allExceptRu.name);
      expect(replaced?['disableMemoryLimit'], isTrue);
      expect(result.phase, RuntimePhase.running);
      expect(result.lastFailureKind, 'protected_handoff_failed');
      await cancellation.cancelConnectRequest(cancellation.activeConnectRequestId!);
      expect(calls, isNot(contains('runtimeEngine.disconnect')));
    });
  }
}
