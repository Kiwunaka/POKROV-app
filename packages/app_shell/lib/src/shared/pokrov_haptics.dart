import 'dart:async';

import 'package:flutter/services.dart';

/// Tiered, try/catch-guarded haptic feedback for the POKROV shell.
///
/// Haptics are best-effort: platform channels may be unavailable (desktop,
/// tests, headless hosts) and must never break a user flow.
class PokrovHaptics {
  const PokrovHaptics._();

  /// Light selection tick for small, frequent interactions.
  static void tap() => _run(HapticFeedback.selectionClick);

  /// Soft impact for deliberate primary actions (e.g. the connect orb).
  static void impact() => _run(HapticFeedback.lightImpact);

  /// Medium impact for positive confirmations (connected, claimed, saved).
  static void success() => _run(HapticFeedback.mediumImpact);

  /// Heavy impact for failures that need the user's attention.
  static void error() => _run(HapticFeedback.heavyImpact);

  static void _run(Future<void> Function() feedback) {
    try {
      unawaited(feedback().catchError((Object _) {}));
    } catch (_) {
      // Haptics are decorative; swallow platform failures silently.
    }
  }
}
