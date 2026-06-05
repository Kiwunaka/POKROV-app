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
  static const sweepDuration = Duration(milliseconds: 1250);
  static const pressScale = 0.97;
  static const busyScale = 0.985;
  static const breathAmplitude = 0.014;
  static const settleScaleBegin = 0.982;
  static const busySweepArcRadians = math.pi * 0.86;
  static const reducedMotionSweepStartAngle = -math.pi / 2;
  static const connectedArcStartAngle = -math.pi * 0.62;
  static const connectedArcSweepRadians = math.pi * 1.24;

  static double sweepStartAngle({
    required bool disableAnimations,
    required double sweepValue,
  }) {
    if (disableAnimations) {
      return reducedMotionSweepStartAngle;
    }
    return sweepValue * math.pi * 2;
  }

  static double scale({
    required bool pressed,
    required bool runsSweep,
    required double breathValue,
    required bool disableAnimations,
  }) {
    final pressedScale = pressed ? pressScale : 1.0;
    final sweepScale = runsSweep ? busyScale : 1.0;
    final breathScale = runsSweep || disableAnimations
        ? 1.0
        : 1.0 + breathValue * breathAmplitude;
    return pressedScale * sweepScale * breathScale;
  }
}
