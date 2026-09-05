import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/src/shell/managed_profile_lifecycle.dart';
import 'package:pokrov_core_domain/core_domain.dart';
import 'package:pokrov_runtime_engine/runtime_engine.dart';

const _invalidated = RuntimeSnapshot(
  hostPlatform: HostPlatform.android,
  lane: RuntimeLane.mobileArtifact,
  phase: RuntimePhase.initialized,
  artifactDirectory: null,
  coreBinaryPath: null,
  helperBinaryPath: null,
  stagedConfigPath: null,
  supportsLiveConnect: true,
  canInitialize: true,
  canConnect: false,
  message: 'synthetic invalidation',
);

void main() {
  testWidgets(
      'held edits coalesce and connect waits for the latest invalidation',
      (tester) async {
    final first = Completer<RuntimeSnapshot>();
    final second = Completer<RuntimeSnapshot>();
    var calls = 0;
    var snapshots = 0;
    final lifecycle = ManagedProfileLifecycle(
      invalidateProfile: () => ++calls == 1 ? first.future : second.future,
      invalidateOnHost: () => true,
      timeout: () => const Duration(seconds: 5),
      onInvalidated: (_) => snapshots++,
    );
    addTearDown(lifecycle.dispose);
    lifecycle.invalidate();
    lifecycle.invalidate();
    lifecycle.invalidate();
    expect(calls, 1);
    bool? ready;
    lifecycle
        .waitForInvalidation(lifecycle.revision)
        .then((value) => ready = value);
    first.complete(_invalidated);
    await tester.pump();
    expect(calls, 2);
    expect(ready, isNull);
    second.complete(_invalidated);
    await tester.pump();
    expect(ready, isTrue);
    expect(snapshots, 2);
  });

  testWidgets('timeout and disposal reject late host acknowledgements',
      (tester) async {
    final first = Completer<RuntimeSnapshot>();
    final second = Completer<RuntimeSnapshot>();
    var calls = 0;
    var snapshots = 0;
    final lifecycle = ManagedProfileLifecycle(
      invalidateProfile: () => ++calls == 1 ? first.future : second.future,
      invalidateOnHost: () => true,
      timeout: () => const Duration(milliseconds: 10),
      onInvalidated: (_) => snapshots++,
    );
    lifecycle.invalidate();
    bool? ready;
    lifecycle
        .waitForInvalidation(lifecycle.revision)
        .then((value) => ready = value);
    await tester.pump(const Duration(milliseconds: 11));
    expect(ready, isFalse);
    ready = null;
    lifecycle
        .waitForInvalidation(lifecycle.revision)
        .then((value) => ready = value);
    expect(calls, 2);
    first.complete(_invalidated);
    await tester.pump();
    expect(ready, isNull);
    expect(snapshots, 0);
    lifecycle.dispose();
    await tester.pump();
    expect(ready, isFalse);
    second.complete(_invalidated);
    await tester.pump();
    expect(snapshots, 0);
  });

  test('non-Android input revisions advance without host invalidation',
      () async {
    var calls = 0;
    final lifecycle = ManagedProfileLifecycle(
      invalidateProfile: () async {
        calls++;
        return _invalidated;
      },
      invalidateOnHost: () => false,
      timeout: () => const Duration(seconds: 5),
      onInvalidated: (_) {},
    );
    addTearDown(lifecycle.dispose);
    final previousRevision = lifecycle.revision;
    lifecycle.invalidate();
    expect(lifecycle.revision, greaterThan(previousRevision));
    expect(await lifecycle.waitForInvalidation(lifecycle.revision), isTrue);
    expect(calls, 0);
  });
}
