import 'dart:math' as math;

import 'package:flutter/foundation.dart';

enum PokrovConnectDiscPhase {
  idle,
  preparing,
  connecting,
  connected,
  disconnecting,
  reconnecting,
  error,
}

class PokrovConnectDiscState {
  const PokrovConnectDiscState._({
    required this.enabled,
    required this.phase,
  });

  factory PokrovConnectDiscState.resolve({
    required bool enabled,
    required bool running,
    required bool degraded,
    required bool error,
    required bool busy,
  }) {
    if (busy) {
      return PokrovConnectDiscState._(
        enabled: enabled,
        phase: running
            ? PokrovConnectDiscPhase.reconnecting
            : PokrovConnectDiscPhase.connecting,
      );
    }
    if (error || (degraded && !running)) {
      return PokrovConnectDiscState._(
        enabled: enabled,
        phase: PokrovConnectDiscPhase.error,
      );
    }
    if (running) {
      return PokrovConnectDiscState._(
        enabled: enabled,
        phase: PokrovConnectDiscPhase.connected,
      );
    }
    return PokrovConnectDiscState._(
      enabled: enabled,
      phase: PokrovConnectDiscPhase.idle,
    );
  }

  factory PokrovConnectDiscState.explicit({
    required bool enabled,
    required PokrovConnectDiscPhase phase,
  }) {
    return PokrovConnectDiscState._(
      enabled: enabled,
      phase: phase,
    );
  }

  final bool enabled;
  final PokrovConnectDiscPhase phase;

  bool get isError => phase == PokrovConnectDiscPhase.error;

  bool get isActive => phase != PokrovConnectDiscPhase.idle;

  bool get runsSweep =>
      enabled &&
      switch (phase) {
        PokrovConnectDiscPhase.preparing ||
        PokrovConnectDiscPhase.connecting ||
        PokrovConnectDiscPhase.disconnecting ||
        PokrovConnectDiscPhase.reconnecting =>
          true,
        PokrovConnectDiscPhase.idle ||
        PokrovConnectDiscPhase.connected ||
        PokrovConnectDiscPhase.error =>
          false,
      };

  ValueKey<String> get settleKey => ValueKey(
        switch (phase) {
          PokrovConnectDiscPhase.preparing ||
          PokrovConnectDiscPhase.connecting ||
          PokrovConnectDiscPhase.disconnecting ||
          PokrovConnectDiscPhase.reconnecting =>
            'connect-disc-busy-settle',
          PokrovConnectDiscPhase.error => 'connect-disc-error-settle',
          PokrovConnectDiscPhase.connected => 'connect-disc-connected-settle',
          PokrovConnectDiscPhase.idle => 'connect-disc-idle-settle',
        },
      );

  double get settleInset => switch (phase) {
        PokrovConnectDiscPhase.preparing ||
        PokrovConnectDiscPhase.connecting ||
        PokrovConnectDiscPhase.disconnecting ||
        PokrovConnectDiscPhase.reconnecting =>
          16,
        PokrovConnectDiscPhase.error => 13,
        PokrovConnectDiscPhase.connected => 12,
        PokrovConnectDiscPhase.idle => 20,
      };

  double get settleOpacity => switch (phase) {
        PokrovConnectDiscPhase.preparing ||
        PokrovConnectDiscPhase.connecting ||
        PokrovConnectDiscPhase.disconnecting ||
        PokrovConnectDiscPhase.reconnecting =>
          0.18,
        PokrovConnectDiscPhase.error => 0.22,
        PokrovConnectDiscPhase.connected => 0.20,
        PokrovConnectDiscPhase.idle => 0,
      };
}

class PokrovConnectDiscMotion {
  const PokrovConnectDiscMotion._();

  static const breathDuration = Duration(milliseconds: 900);

  /// One direction of the calm connected breath loop (repeat-reverse), so a
  /// full inhale/exhale cycle takes twice this period.
  static const breathPeriod = Duration(milliseconds: 1800);
  static const sweepDuration = Duration(milliseconds: 1250);
  static const pressScale = 0.97;
  static const busyScale = 0.985;
  static const breathAmplitude = 0.014;
  static const settleScaleBegin = 0.982;
  static const busySweepArcRadians = math.pi * 0.86;
  static const reducedMotionSweepStartAngle = -math.pi / 2;
  static const connectedArcStartAngle = -math.pi * 0.62;
  static const connectedArcSweepRadians = math.pi * 1.24;

  /// The busy sweep lands into the connected arc (and unwinds back into its
  /// tail on release) over one standard beat.
  static const arcSettleDuration = Duration(milliseconds: 240);

  /// Shortest signed angular distance from [from] to [to], so the landing
  /// morph never travels more than half a turn to reach its home angle.
  static double shortestAngleDelta(double from, double to) {
    const tau = math.pi * 2;
    var delta = (to - from) % tau;
    if (delta > math.pi) {
      delta -= tau;
    }
    return delta;
  }

  /// Start angle of the landing morph at progress [t]: the captured busy
  /// sweep angle at 0, the canonical connected arc angle at 1.
  static double settleStartAngle({
    required double fromAngle,
    required double t,
  }) {
    return fromAngle +
        shortestAngleDelta(fromAngle, connectedArcStartAngle) * t;
  }

  static double sweepStartAngle({
    required bool disableAnimations,
    required double sweepValue,
  }) {
    if (disableAnimations) {
      return reducedMotionSweepStartAngle;
    }
    return sweepValue * math.pi * 2;
  }

  /// The busy sweep repeats continuously while the disc runs a sweep and
  /// settles (stops) as soon as the phase leaves the busy family. Reduced
  /// motion and non-looping environments keep the finite single pass.
  static bool sweepRepeats({
    required bool runsSweep,
    required bool disableAnimations,
    bool loopingEnabled = true,
  }) {
    return runsSweep && !disableAnimations && loopingEnabled;
  }

  /// The calm breath loops (repeat-reverse) only while connected; every other
  /// phase keeps the finite single pass so settles stay deterministic.
  static bool breathRepeats({
    required PokrovConnectDiscPhase phase,
    required bool disableAnimations,
    bool loopingEnabled = true,
  }) {
    return phase == PokrovConnectDiscPhase.connected &&
        !disableAnimations &&
        loopingEnabled;
  }

  static double scale({
    required bool pressed,
    required bool runsSweep,
    required double breathValue,
    required bool disableAnimations,
  }) {
    if (disableAnimations) {
      return 1.0;
    }
    final pressedScale = pressed ? pressScale : 1.0;
    final sweepScale = runsSweep ? busyScale : 1.0;
    final breathScale = runsSweep ? 1.0 : 1.0 + breathValue * breathAmplitude;
    return pressedScale * sweepScale * breathScale;
  }
}
