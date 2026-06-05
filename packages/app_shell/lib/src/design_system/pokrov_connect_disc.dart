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
