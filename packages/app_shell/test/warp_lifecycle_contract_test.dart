import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/app_first_runtime_bootstrap.dart';
import 'package:pokrov_app_shell/src/warp/pokrov_warp_lifecycle.dart';
import 'package:pokrov_runtime_engine/runtime_engine.dart';

void main() {
  test('warp lifecycle resolves all user-facing phases', () {
    expect(
      PokrovWarpLifecycle.resolve(
        policy: WarpRuntimePolicy.disabled,
        consented: false,
        busy: false,
      ).phase,
      PokrovWarpPhase.notReady,
    );

    const readyPolicy = WarpRuntimePolicy(
      enabled: true,
      runtimeReady: true,
      state: 'ready_to_consent',
      wireguardConfigJson: '{"private_key":"redacted-test"}',
    );
    expect(
      PokrovWarpLifecycle.resolve(
        policy: readyPolicy,
        consented: false,
        busy: false,
      ).phase,
      PokrovWarpPhase.readyToConsent,
    );
    expect(
      PokrovWarpLifecycle.resolve(
        policy: readyPolicy,
        consented: true,
        busy: false,
      ).phase,
      PokrovWarpPhase.consented,
    );
    expect(
      PokrovWarpLifecycle.resolve(
        policy: readyPolicy.copyWith(state: 'active'),
        consented: true,
        busy: false,
      ).phase,
      PokrovWarpPhase.active,
    );
    expect(
      PokrovWarpLifecycle.resolve(
        policy: readyPolicy.copyWith(state: 'degraded'),
        consented: true,
        busy: false,
      ).phase,
      PokrovWarpPhase.degraded,
    );
    expect(
      PokrovWarpLifecycle.resolve(
        policy: readyPolicy.copyWith(state: 'fallback'),
        consented: true,
        busy: false,
      ).phase,
      PokrovWarpPhase.fallback,
    );
    expect(
      PokrovWarpLifecycle.resolve(
        policy: readyPolicy.copyWith(state: 'revoked'),
        consented: false,
        busy: false,
      ).phase,
      PokrovWarpPhase.revoked,
    );
    expect(
      PokrovWarpLifecycle.resolve(
        policy: readyPolicy.copyWith(state: 'error'),
        consented: false,
        busy: false,
      ).phase,
      PokrovWarpPhase.error,
    );
  });

  test('warp lifecycle keeps public copy product-first and WARP internal', () {
    final lifecycle = PokrovWarpLifecycle.resolve(
      policy: const WarpRuntimePolicy(
        enabled: true,
        runtimeReady: true,
        state: 'ready_to_consent',
        wireguardConfigJson: '{"private_key":"redacted-test"}',
      ),
      consented: false,
      busy: false,
    );

    expect(lifecycle.publicTitle, 'Расширенная приватность');
    expect(lifecycle.publicStatus, isNot(contains('WARP')));
    expect(lifecycle.publicActionLabel, isNot(contains('WARP')));
    expect(lifecycle.technicalLabel, 'WARP');
    expect(lifecycle.stateKey, 'home-warp-state-ready');
  });

  test('warp cache payload stores only safe consent status', () {
    final status = WarpControlStatus.fromPolicy(
      const WarpRuntimePolicy(
        enabled: true,
        runtimeReady: true,
        state: 'consented',
        userConsented: true,
        wireguardConfigJson: '{"private-key":"secret"}',
        accessToken: 'token-secret',
        accountId: 'account-secret',
      ),
    ).copyWith(
      consentedAt: '2026-06-05T12:00:00Z',
      lastEvent: const <String, Object?>{
        'event_name': 'runtime_fallback',
        'wireguard_config': <String, Object?>{'private-key': 'secret'},
      },
    );

    final cache = PokrovWarpConsentCacheEntry.fromStatus(status);
    final encoded = jsonEncode(cache.toJson());

    expect(cache.consented, isTrue);
    expect(cache.state, 'consented');
    expect(encoded, isNot(contains('private-key')));
    expect(encoded, isNot(contains('token-secret')));
    expect(encoded, isNot(contains('account-secret')));
    expect(encoded, isNot(contains('wireguard_config')));
  });

  test('warp diagnostics redact material and support only safe states', () {
    final diagnostics = PokrovWarpSupportDiagnostics.fromLifecycle(
      PokrovWarpLifecycle.resolve(
        policy: const WarpRuntimePolicy(
          enabled: true,
          runtimeReady: true,
          state: 'fallback',
          wireguardConfigJson: '{"private-key":"secret"}',
          accessToken: 'token-secret',
          accountId: 'account-secret',
        ),
        consented: true,
        busy: false,
        lastError: 'wireguard private-key failed',
      ),
    );

    final encoded = jsonEncode(diagnostics.toJson());
    expect(diagnostics.toJson()['enhanced_protection_state'], 'fallback');
    expect(encoded, isNot(contains('WARP')));
    expect(encoded, isNot(contains('wireguard')));
    expect(encoded, isNot(contains('private-key')));
    expect(encoded, isNot(contains('token-secret')));
    expect(encoded, contains('[redacted]'));
  });
}
