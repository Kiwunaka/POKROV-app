import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/src/shell/cached_profile_fallback_gate.dart';

void main() {
  test('cached profile refresh keeps a bounded mobile-network window', () {
    expect(
      CachedProfileFallbackGate.refreshDeadline(
        const Duration(seconds: 18),
      ),
      const Duration(seconds: 15),
    );
    expect(
      CachedProfileFallbackGate.refreshDeadline(
        const Duration(seconds: 8),
      ),
      const Duration(seconds: 8),
    );
  });

  test('fresh cache is available until the user changes profile inputs', () {
    final gate = CachedProfileFallbackGate();

    expect(gate.canFallback(cachedProfileAvailable: true), isTrue);
    expect(gate.canFallback(cachedProfileAvailable: false), isFalse);

    gate.markUserChange();
    expect(gate.canFallback(cachedProfileAvailable: true), isFalse);
  });

  test('staging a fresh managed profile re-enables later cache fallback', () {
    final gate = CachedProfileFallbackGate()..markUserChange();

    gate.markFreshProfileStaged();

    expect(gate.canFallback(cachedProfileAvailable: true), isTrue);
  });

  test('runtime authorization failure blocks the stale profile until restaged',
      () {
    final gate = CachedProfileFallbackGate();

    gate.markRuntimeProfileInvalid();
    expect(gate.canFallback(cachedProfileAvailable: true), isFalse);

    gate.markFreshProfileStaged();
    expect(gate.canFallback(cachedProfileAvailable: true), isTrue);
  });
}
