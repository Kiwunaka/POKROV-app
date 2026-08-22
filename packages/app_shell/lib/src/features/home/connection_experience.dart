part of pokrov_app_shell;

enum ConnectionExperiencePhase {
  idle,
  permissionRequired,
  preparing,
  connecting,
  connectedUnverified,
  connectedVerified,
  disconnecting,
  reconnecting,
  blocked,
  failed,
}

enum ConnectionStage {
  idle,
  permission,
  profile,
  coreStart,
  tunnel,
  network,
  dns,
  egress,
  complete,
}

enum ConnectionTransitionIntent {
  none,
  permission,
  prepare,
  connect,
  disconnect,
  reconnect,
  recover,
}

enum ConnectionBlockReason {
  runtimeArtifactMissing,
  permissionRequired,
  unavailable,
}

enum ConnectionTone { muted, success, warning, danger }

enum ConnectionDiscPhase {
  idle,
  preparing,
  connecting,
  connected,
  disconnecting,
  reconnecting,
  error,
}

enum ConnectionHapticIntent { none, tap, success, error }

sealed class ConnectionExperienceState {
  const ConnectionExperienceState({
    required this.phase,
    required this.stage,
    this.snapshot,
  });

  final ConnectionExperiencePhase phase;
  final ConnectionStage stage;
  final RuntimeSnapshot? snapshot;
}

final class ConnectionIdle extends ConnectionExperienceState {
  const ConnectionIdle({super.snapshot})
      : super(
          phase: ConnectionExperiencePhase.idle,
          stage: ConnectionStage.idle,
        );
}

final class ConnectionPermissionRequired extends ConnectionExperienceState {
  const ConnectionPermissionRequired({super.snapshot})
      : super(
          phase: ConnectionExperiencePhase.permissionRequired,
          stage: ConnectionStage.permission,
        );
}

final class ConnectionPreparing extends ConnectionExperienceState {
  const ConnectionPreparing({
    required super.stage,
    super.snapshot,
  }) : super(phase: ConnectionExperiencePhase.preparing);
}

final class ConnectionConnecting extends ConnectionExperienceState {
  const ConnectionConnecting({
    required super.stage,
    required this.attempt,
    super.snapshot,
  }) : super(phase: ConnectionExperiencePhase.connecting);

  final int attempt;
}

final class ConnectionConnectedUnverified extends ConnectionExperienceState {
  const ConnectionConnectedUnverified({
    required super.stage,
    required RuntimeSnapshot super.snapshot,
  }) : super(phase: ConnectionExperiencePhase.connectedUnverified);
}

final class ConnectionConnectedVerified extends ConnectionExperienceState {
  const ConnectionConnectedVerified({
    required RuntimeSnapshot super.snapshot,
  }) : super(
          phase: ConnectionExperiencePhase.connectedVerified,
          stage: ConnectionStage.complete,
        );
}

final class ConnectionDisconnecting extends ConnectionExperienceState {
  const ConnectionDisconnecting({super.snapshot})
      : super(
          phase: ConnectionExperiencePhase.disconnecting,
          stage: ConnectionStage.tunnel,
        );
}

final class ConnectionReconnecting extends ConnectionExperienceState {
  const ConnectionReconnecting({
    required super.stage,
    required this.attempt,
    super.snapshot,
  }) : super(phase: ConnectionExperiencePhase.reconnecting);

  final int attempt;
}

final class ConnectionBlocked extends ConnectionExperienceState {
  const ConnectionBlocked({
    required this.reason,
    super.snapshot,
  }) : super(
          phase: ConnectionExperiencePhase.blocked,
          stage: ConnectionStage.idle,
        );

  final ConnectionBlockReason reason;
}

final class ConnectionFailed extends ConnectionExperienceState {
  const ConnectionFailed({
    required this.reasonCode,
    required super.stage,
    required this.retryable,
    super.snapshot,
  }) : super(phase: ConnectionExperiencePhase.failed);

  final String reasonCode;
  final bool retryable;
}

class ConnectionExperienceReducer {
  const ConnectionExperienceReducer._();

  static ConnectionExperienceState reduce({
    required RuntimeSnapshot? snapshot,
    required ConnectionTransitionIntent intent,
    required bool actionInFlight,
    int attempt = 1,
  }) {
    if (actionInFlight) {
      return switch (intent) {
        ConnectionTransitionIntent.permission =>
          ConnectionPermissionRequired(snapshot: snapshot),
        ConnectionTransitionIntent.disconnect =>
          ConnectionDisconnecting(snapshot: snapshot),
        ConnectionTransitionIntent.reconnect ||
        ConnectionTransitionIntent.recover =>
          ConnectionReconnecting(
            stage: _stageFor(snapshot),
            attempt: attempt,
            snapshot: snapshot,
          ),
        ConnectionTransitionIntent.prepare => ConnectionPreparing(
            stage: _stageFor(snapshot),
            snapshot: snapshot,
          ),
        ConnectionTransitionIntent.connect => ConnectionConnecting(
            stage: _stageFor(snapshot),
            attempt: attempt,
            snapshot: snapshot,
          ),
        ConnectionTransitionIntent.none => ConnectionPreparing(
            stage: _stageFor(snapshot),
            snapshot: snapshot,
          ),
      };
    }

    if (snapshot == null) {
      return const ConnectionIdle();
    }
    if (snapshot.phase == RuntimePhase.running) {
      if (snapshot.isCleanlyHealthy) {
        return ConnectionConnectedVerified(snapshot: snapshot);
      }
      return ConnectionConnectedUnverified(
        stage: _verificationStageFor(snapshot),
        snapshot: snapshot,
      );
    }
    final reasonCode = snapshot.lastFailureKind?.trim();
    if (reasonCode != null && reasonCode.isNotEmpty) {
      return ConnectionFailed(
        reasonCode: reasonCode,
        stage: _stageFor(snapshot),
        retryable: true,
        snapshot: snapshot,
      );
    }
    if (snapshot.phase == RuntimePhase.artifactMissing) {
      return ConnectionBlocked(
        reason: ConnectionBlockReason.runtimeArtifactMissing,
        snapshot: snapshot,
      );
    }
    if (snapshot.connectionPending) {
      return ConnectionPermissionRequired(snapshot: snapshot);
    }
    return ConnectionIdle(snapshot: snapshot);
  }

  static ConnectionStage _stageFor(RuntimeSnapshot? snapshot) {
    if (snapshot == null) {
      return ConnectionStage.profile;
    }
    if (snapshot.phase == RuntimePhase.artifactReady) {
      return ConnectionStage.coreStart;
    }
    if (snapshot.phase == RuntimePhase.initialized ||
        snapshot.phase == RuntimePhase.configStaged) {
      return ConnectionStage.tunnel;
    }
    return _verificationStageFor(snapshot);
  }

  static ConnectionStage _verificationStageFor(RuntimeSnapshot snapshot) {
    if (snapshot.dnsReady != true ||
        snapshot.dnsState != RuntimeDiagnosticState.healthy) {
      return ConnectionStage.dns;
    }
    if (snapshot.coreEgressValidated != true) {
      return ConnectionStage.egress;
    }
    return ConnectionStage.network;
  }
}

class ConnectionPresentation {
  const ConnectionPresentation({
    required this.experience,
    required this.title,
    required this.subtitle,
    required this.primaryActionLabel,
    required this.primaryActionEnabled,
    required this.discPhase,
    required this.tone,
    required this.semanticLabel,
    required this.showsTunnelActive,
    required this.showsConnectedVisual,
    required this.isVerified,
    required this.isDegraded,
    required this.discMotionBusy,
  });

  factory ConnectionPresentation.fromExperience(
    ConnectionExperienceState experience, {
    required bool primaryConnectEnabled,
  }) {
    final phase = experience.phase;
    final snapshot = experience.snapshot;
    final tunnelActive = snapshot?.phase == RuntimePhase.running;
    final awaitingVerification = experience is ConnectionConnectedUnverified &&
        !snapshot!.hasDegradedHostDiagnostics &&
        snapshot.dnsReady != false &&
        snapshot.coreEgressValidated != false;
    final verified = experience is ConnectionConnectedVerified;
    final degraded =
        experience is ConnectionConnectedUnverified && !awaitingVerification;
    final transitioning = const <ConnectionExperiencePhase>{
      ConnectionExperiencePhase.preparing,
      ConnectionExperiencePhase.connecting,
      ConnectionExperiencePhase.disconnecting,
      ConnectionExperiencePhase.reconnecting,
    }.contains(phase);

    final title = switch (phase) {
      ConnectionExperiencePhase.idle => 'Не защищено',
      ConnectionExperiencePhase.permissionRequired => 'Нужен доступ к VPN',
      ConnectionExperiencePhase.preparing => 'Подготавливаем профиль',
      ConnectionExperiencePhase.connecting => _stageTitle(experience.stage),
      ConnectionExperiencePhase.connectedUnverified =>
        awaitingVerification ? 'Проверяем…' : 'Нужно внимание',
      ConnectionExperiencePhase.connectedVerified => 'Подключено',
      ConnectionExperiencePhase.disconnecting => 'Завершаем соединение',
      ConnectionExperiencePhase.reconnecting => 'Восстанавливаем соединение',
      ConnectionExperiencePhase.blocked => 'Не получилось подключиться',
      ConnectionExperiencePhase.failed => 'Не удалось подключиться',
    };
    final actionLabel = switch (phase) {
      ConnectionExperiencePhase.idle =>
        primaryConnectEnabled ? 'Подключить' : 'Пока недоступно',
      ConnectionExperiencePhase.permissionRequired => 'Разрешить',
      ConnectionExperiencePhase.preparing ||
      ConnectionExperiencePhase.connecting =>
        'Подключаемся…',
      ConnectionExperiencePhase.connectedUnverified ||
      ConnectionExperiencePhase.connectedVerified =>
        'Отключить',
      ConnectionExperiencePhase.disconnecting => 'Отключаем…',
      ConnectionExperiencePhase.reconnecting => 'Переподключаем…',
      ConnectionExperiencePhase.blocked => 'Пока недоступно',
      ConnectionExperiencePhase.failed => 'Повторить',
    };
    final actionEnabled = switch (phase) {
      ConnectionExperiencePhase.idle ||
      ConnectionExperiencePhase.permissionRequired ||
      ConnectionExperiencePhase.failed =>
        primaryConnectEnabled,
      ConnectionExperiencePhase.connectedUnverified ||
      ConnectionExperiencePhase.connectedVerified =>
        true,
      ConnectionExperiencePhase.preparing ||
      ConnectionExperiencePhase.connecting ||
      ConnectionExperiencePhase.disconnecting ||
      ConnectionExperiencePhase.reconnecting ||
      ConnectionExperiencePhase.blocked =>
        false,
    };
    final discPhase = switch (phase) {
      ConnectionExperiencePhase.idle ||
      ConnectionExperiencePhase.permissionRequired =>
        ConnectionDiscPhase.idle,
      ConnectionExperiencePhase.preparing => ConnectionDiscPhase.preparing,
      ConnectionExperiencePhase.connecting => ConnectionDiscPhase.connecting,
      ConnectionExperiencePhase.connectedUnverified => awaitingVerification
          ? ConnectionDiscPhase.connecting
          : ConnectionDiscPhase.error,
      ConnectionExperiencePhase.connectedVerified =>
        ConnectionDiscPhase.connected,
      ConnectionExperiencePhase.disconnecting =>
        ConnectionDiscPhase.disconnecting,
      ConnectionExperiencePhase.reconnecting =>
        ConnectionDiscPhase.reconnecting,
      ConnectionExperiencePhase.blocked ||
      ConnectionExperiencePhase.failed =>
        ConnectionDiscPhase.error,
    };
    final tone = switch (phase) {
      ConnectionExperiencePhase.connectedVerified => ConnectionTone.success,
      ConnectionExperiencePhase.connectedUnverified => ConnectionTone.warning,
      ConnectionExperiencePhase.failed => ConnectionTone.danger,
      ConnectionExperiencePhase.blocked => ConnectionTone.warning,
      ConnectionExperiencePhase.idle ||
      ConnectionExperiencePhase.permissionRequired ||
      ConnectionExperiencePhase.preparing ||
      ConnectionExperiencePhase.connecting ||
      ConnectionExperiencePhase.disconnecting ||
      ConnectionExperiencePhase.reconnecting =>
        ConnectionTone.muted,
    };
    final subtitle = switch (phase) {
      ConnectionExperiencePhase.connectedVerified =>
        'DNS и выход через VPN подтверждены',
      ConnectionExperiencePhase.connectedUnverified => awaitingVerification
          ? 'Туннель запущен, подтверждаем DNS и выход'
          : 'Туннель работает, одна из проверок требует внимания',
      ConnectionExperiencePhase.disconnecting => 'Останавливаем туннель',
      ConnectionExperiencePhase.reconnecting =>
        'Повторно проверяем защищённый маршрут',
      ConnectionExperiencePhase.failed => 'Можно безопасно повторить попытку',
      ConnectionExperiencePhase.blocked =>
        'На этом устройстве не завершена подготовка',
      ConnectionExperiencePhase.permissionRequired =>
        'Разрешение нужно для системного VPN',
      ConnectionExperiencePhase.preparing ||
      ConnectionExperiencePhase.connecting =>
        _stageSubtitle(experience.stage),
      ConnectionExperiencePhase.idle => 'Защита выключена',
    };

    return ConnectionPresentation(
      experience: experience,
      title: title,
      subtitle: subtitle,
      primaryActionLabel: actionLabel,
      primaryActionEnabled: actionEnabled,
      discPhase: discPhase,
      tone: tone,
      // The action owns only its action name. Connection state is announced
      // by the dedicated status live region, so assistive technology does not
      // hear the same transition from both the CTA and status control.
      semanticLabel: actionLabel,
      showsTunnelActive: tunnelActive,
      showsConnectedVisual: verified || degraded,
      isVerified: verified,
      isDegraded: degraded,
      discMotionBusy: transitioning || awaitingVerification,
    );
  }

  final ConnectionExperienceState experience;
  final String title;
  final String subtitle;
  final String primaryActionLabel;
  final bool primaryActionEnabled;
  final ConnectionDiscPhase discPhase;
  final ConnectionTone tone;
  final String semanticLabel;
  final bool showsTunnelActive;
  final bool showsConnectedVisual;
  final bool isVerified;
  final bool isDegraded;
  final bool discMotionBusy;

  static String _stageTitle(ConnectionStage stage) => switch (stage) {
        ConnectionStage.permission => 'Нужен доступ к VPN',
        ConnectionStage.profile => 'Подготавливаем профиль',
        ConnectionStage.coreStart => 'Запускаем защиту',
        ConnectionStage.tunnel => 'Создаём защищённое соединение',
        ConnectionStage.network => 'Проверяем интернет',
        ConnectionStage.dns => 'Проверяем DNS',
        ConnectionStage.egress => 'Подтверждаем защиту',
        ConnectionStage.idle || ConnectionStage.complete => 'Подключаемся…',
      };

  static String _stageSubtitle(ConnectionStage stage) => switch (stage) {
        ConnectionStage.permission => 'Ждём системное разрешение',
        ConnectionStage.profile => 'Получаем и проверяем настройки',
        ConnectionStage.coreStart => 'Готовим POKROV Core',
        ConnectionStage.tunnel => 'Запускаем системный туннель',
        ConnectionStage.network => 'Проверяем доступность сети',
        ConnectionStage.dns => 'Проверяем защищённый DNS',
        ConnectionStage.egress => 'Проверяем выбранный выход через VPN',
        ConnectionStage.idle ||
        ConnectionStage.complete =>
          'Настраиваем защищённое соединение',
      };
}

/// Immutable state consumed by the Home protection block.
///
/// [connection] remains the only owner of connection copy, CTA, semantics and
/// connect-disc visuals. The remaining fields are presentation context for the
/// same protection surface, not a second connection state machine.
class ProtectionViewState {
  const ProtectionViewState({
    required this.connection,
    required this.routeMode,
    required this.locationLabel,
    required this.emergencyRuntimeActive,
    required this.emergencyChainMode,
    required this.connectHintVisible,
    required this.whitelistRecoverySuggested,
    this.slowConnectionVisible = false,
    this.vpnPermissionRecoveryVisible = false,
    this.runtimeNotice,
  });

  final ConnectionPresentation connection;
  final RouteMode routeMode;
  final String locationLabel;
  final bool emergencyRuntimeActive;
  final EmergencyChainMode emergencyChainMode;
  final bool connectHintVisible;
  final bool whitelistRecoverySuggested;
  final bool slowConnectionVisible;
  final bool vpnPermissionRecoveryVisible;

  /// Secondary recovery/info copy. It never replaces connection status or CTA
  /// copy owned by [connection].
  final String? runtimeNotice;
}

/// User intents exposed by the Home protection block.
///
/// Keeping callbacks together makes the composition root pass one explicit
/// protection boundary instead of leaking individual feature actions through
/// the screen tree.
class ProtectionIntents {
  const ProtectionIntents({
    required this.toggleConnection,
    required this.openConnectionDetails,
    required this.openLocations,
    required this.openRules,
    required this.openRecovery,
  });

  final Future<void> Function() toggleConnection;
  final VoidCallback openConnectionDetails;
  final VoidCallback openLocations;
  final VoidCallback openRules;
  final VoidCallback openRecovery;
}

/// Owns mutable connection orchestration state for the shell.
///
/// Host actions and product decisions remain injected by the composition root;
/// this coordinator owns only the snapshot/intent/action/attempt lifecycle and
/// derives the existing reducer and presenter from that one state.
class ConnectionCoordinator {
  ConnectionCoordinator({
    required this.primaryConnectEnabled,
    required this.actionTimeout,
    this.slowStageThreshold = const Duration(seconds: 10),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final bool Function(RuntimeSnapshot? snapshot) primaryConnectEnabled;
  final Duration actionTimeout;
  final Duration slowStageThreshold;
  final DateTime Function() _now;

  RuntimeSnapshot? _snapshot;
  bool _actionInFlight = false;
  ConnectionTransitionIntent _intent = ConnectionTransitionIntent.none;
  DateTime? _attemptStartedAt;
  int _attemptNumber = 0;
  Timer? _slowStageTimer;
  VoidCallback? _onSlowStage;
  bool _slowStageVisible = false;

  RuntimeSnapshot? get snapshot => _snapshot;
  bool get actionInFlight => _actionInFlight;
  ConnectionTransitionIntent get intent => _intent;
  DateTime? get attemptStartedAt => _attemptStartedAt;
  int get attemptNumber => _attemptNumber;
  bool get slowStageVisible => _slowStageVisible;

  ConnectionExperienceState get experience =>
      ConnectionExperienceReducer.reduce(
        snapshot: _snapshot,
        intent: _intent,
        actionInFlight: _actionInFlight,
        attempt: _attemptNumber < 1 ? 1 : _attemptNumber,
      );

  ConnectionPresentation get presentation =>
      ConnectionPresentation.fromExperience(
        experience,
        primaryConnectEnabled: primaryConnectEnabled(_snapshot),
      );

  void updateSnapshot(RuntimeSnapshot? snapshot) {
    final previousStage = experience.stage;
    _snapshot = snapshot;
    if (_tracksSlowStage && experience.stage != previousStage) {
      _scheduleSlowStage();
    }
  }

  void updateActionInFlight(bool value) {
    _actionInFlight = value;
    if (!value) {
      _cancelSlowStage();
    } else if (_tracksSlowStage && _slowStageTimer == null) {
      _scheduleSlowStage();
    }
  }

  void updateIntent(ConnectionTransitionIntent intent) {
    _intent = intent;
    if (!_tracksSlowStage) {
      _cancelSlowStage();
    } else {
      _scheduleSlowStage();
    }
  }

  void updateAttemptStartedAt(DateTime? value) {
    _attemptStartedAt = value;
  }

  void updateAttemptNumber(int value) {
    _attemptNumber = value < 0 ? 0 : value;
  }

  void beginAction(
    ConnectionTransitionIntent intent, {
    bool recordAttempt = false,
    VoidCallback? onSlowStage,
  }) {
    _actionInFlight = true;
    _intent = intent;
    _onSlowStage = onSlowStage;
    if (recordAttempt) {
      _attemptStartedAt = _now().toUtc();
      _attemptNumber += 1;
    }
    if (_tracksSlowStage) {
      _scheduleSlowStage();
    }
  }

  void finishAction({bool clearAttempt = false}) {
    _cancelSlowStage();
    _actionInFlight = false;
    _intent = ConnectionTransitionIntent.none;
    if (clearAttempt) {
      _attemptStartedAt = null;
    }
  }

  void clearAttempt() {
    _attemptStartedAt = null;
  }

  bool get _tracksSlowStage =>
      _actionInFlight &&
      const <ConnectionTransitionIntent>{
        ConnectionTransitionIntent.connect,
        ConnectionTransitionIntent.reconnect,
        ConnectionTransitionIntent.recover,
      }.contains(_intent);

  void _scheduleSlowStage() {
    _slowStageTimer?.cancel();
    _slowStageVisible = false;
    _slowStageTimer = Timer(slowStageThreshold, () {
      if (!_tracksSlowStage) {
        return;
      }
      _slowStageVisible = true;
      _onSlowStage?.call();
    });
  }

  void _cancelSlowStage() {
    _slowStageTimer?.cancel();
    _slowStageTimer = null;
    _slowStageVisible = false;
    _onSlowStage = null;
  }

  void dispose() {
    _cancelSlowStage();
  }

  int? get attemptDurationMs {
    final startedAt = _attemptStartedAt;
    if (startedAt == null) {
      return null;
    }
    final duration = _now().toUtc().difference(startedAt).inMilliseconds;
    return duration < 0 ? 0 : duration;
  }

  Future<T> runWithTimeout<T>(
    String operation,
    Future<T> Function() action,
  ) {
    return action().timeout(
      actionTimeout,
      onTimeout: () => throw TimeoutException(
        'runtime action timed out: $operation',
        actionTimeout,
      ),
    );
  }
}

class ConnectionExperienceTransitionMatrix {
  const ConnectionExperienceTransitionMatrix._();

  static bool isLegal(
    ConnectionExperiencePhase from,
    ConnectionExperiencePhase to,
  ) {
    if (from == to) {
      return true;
    }
    return (_legal[from] ?? const <ConnectionExperiencePhase>{}).contains(to);
  }

  static const Map<ConnectionExperiencePhase, Set<ConnectionExperiencePhase>>
      _legal = {
    ConnectionExperiencePhase.idle: {
      ConnectionExperiencePhase.permissionRequired,
      ConnectionExperiencePhase.preparing,
      ConnectionExperiencePhase.connecting,
      ConnectionExperiencePhase.blocked,
      ConnectionExperiencePhase.failed,
    },
    ConnectionExperiencePhase.permissionRequired: {
      ConnectionExperiencePhase.idle,
      ConnectionExperiencePhase.preparing,
      ConnectionExperiencePhase.blocked,
      ConnectionExperiencePhase.failed,
    },
    ConnectionExperiencePhase.preparing: {
      ConnectionExperiencePhase.idle,
      ConnectionExperiencePhase.connecting,
      ConnectionExperiencePhase.blocked,
      ConnectionExperiencePhase.failed,
    },
    ConnectionExperiencePhase.connecting: {
      ConnectionExperiencePhase.idle,
      ConnectionExperiencePhase.connectedUnverified,
      ConnectionExperiencePhase.connectedVerified,
      ConnectionExperiencePhase.blocked,
      ConnectionExperiencePhase.failed,
    },
    ConnectionExperiencePhase.connectedUnverified: {
      ConnectionExperiencePhase.idle,
      ConnectionExperiencePhase.connectedVerified,
      ConnectionExperiencePhase.disconnecting,
      ConnectionExperiencePhase.reconnecting,
      ConnectionExperiencePhase.blocked,
      ConnectionExperiencePhase.failed,
    },
    ConnectionExperiencePhase.connectedVerified: {
      ConnectionExperiencePhase.idle,
      ConnectionExperiencePhase.connectedUnverified,
      ConnectionExperiencePhase.disconnecting,
      ConnectionExperiencePhase.reconnecting,
      ConnectionExperiencePhase.blocked,
      ConnectionExperiencePhase.failed,
    },
    ConnectionExperiencePhase.disconnecting: {
      ConnectionExperiencePhase.idle,
      ConnectionExperiencePhase.failed,
    },
    ConnectionExperiencePhase.reconnecting: {
      ConnectionExperiencePhase.idle,
      ConnectionExperiencePhase.connectedUnverified,
      ConnectionExperiencePhase.connectedVerified,
      ConnectionExperiencePhase.blocked,
      ConnectionExperiencePhase.failed,
    },
    ConnectionExperiencePhase.blocked: {
      ConnectionExperiencePhase.idle,
      ConnectionExperiencePhase.permissionRequired,
      ConnectionExperiencePhase.preparing,
      ConnectionExperiencePhase.failed,
    },
    ConnectionExperiencePhase.failed: {
      ConnectionExperiencePhase.idle,
      ConnectionExperiencePhase.preparing,
      ConnectionExperiencePhase.connecting,
      ConnectionExperiencePhase.blocked,
    },
  };
}

class ConnectionHapticCoordinator {
  const ConnectionHapticCoordinator._();

  static ConnectionHapticIntent action(ConnectionPresentation presentation) =>
      presentation.primaryActionEnabled
          ? ConnectionHapticIntent.tap
          : ConnectionHapticIntent.none;

  static ConnectionHapticIntent outcome(
    ConnectionExperiencePhase from,
    ConnectionExperiencePhase to,
  ) {
    if (from == to) {
      return ConnectionHapticIntent.none;
    }
    if (to == ConnectionExperiencePhase.connectedVerified) {
      return ConnectionHapticIntent.success;
    }
    if (to == ConnectionExperiencePhase.failed) {
      return ConnectionHapticIntent.error;
    }
    return ConnectionHapticIntent.none;
  }
}
