import 'package:pokrov_app_shell/app_first_runtime_bootstrap.dart';
import 'package:pokrov_runtime_engine/runtime_engine.dart';

enum PokrovWarpPhase {
  notReady,
  readyToConsent,
  consented,
  active,
  degraded,
  fallback,
  revoked,
  error,
}

class PokrovWarpLifecycle {
  const PokrovWarpLifecycle._({
    required this.phase,
    required this.canOffer,
    required this.consented,
    required this.busy,
    required this.lastError,
  });

  factory PokrovWarpLifecycle.resolve({
    required WarpRuntimePolicy policy,
    required bool consented,
    required bool busy,
    String lastError = '',
  }) {
    final state = policy.state.trim().toLowerCase();
    final canOffer = policy.canOfferRuntime;
    final phase = switch (state) {
      'active' || 'running' => PokrovWarpPhase.active,
      'degraded' => PokrovWarpPhase.degraded,
      'fallback' || 'baseline_fallback' => PokrovWarpPhase.fallback,
      'revoked' => PokrovWarpPhase.revoked,
      'error' || 'failed' || 'runtime_error' => PokrovWarpPhase.error,
      _ when canOffer && consented => PokrovWarpPhase.consented,
      _ when canOffer => PokrovWarpPhase.readyToConsent,
      _ => PokrovWarpPhase.notReady,
    };
    return PokrovWarpLifecycle._(
      phase: phase,
      canOffer: canOffer,
      consented: consented && canOffer,
      busy: busy,
      lastError: lastError.trim(),
    );
  }

  final PokrovWarpPhase phase;
  final bool canOffer;
  final bool consented;
  final bool busy;
  final String lastError;

  String get technicalLabel => 'WARP';

  String get publicTitle => 'Расширенная защита';

  String get publicSheetTitle => 'Расширенная защита';

  String get stateKey {
    if (busy) {
      return 'home-warp-state-loading';
    }
    return switch (phase) {
      PokrovWarpPhase.notReady => 'home-warp-state-disabled',
      PokrovWarpPhase.readyToConsent => 'home-warp-state-ready',
      PokrovWarpPhase.consented => 'home-warp-state-enabled',
      PokrovWarpPhase.active => 'home-warp-state-active',
      PokrovWarpPhase.degraded => 'home-warp-state-degraded',
      PokrovWarpPhase.fallback => 'home-warp-state-fallback',
      PokrovWarpPhase.revoked => 'home-warp-state-disabled',
      PokrovWarpPhase.error => 'home-warp-state-error',
    };
  }

  bool get highlightsEnabled =>
      phase == PokrovWarpPhase.consented || phase == PokrovWarpPhase.active;

  bool get isProblem =>
      phase == PokrovWarpPhase.degraded ||
      phase == PokrovWarpPhase.fallback ||
      phase == PokrovWarpPhase.error;

  String get publicStatus {
    if (busy) {
      return 'Проверяем доступность';
    }
    return switch (phase) {
      PokrovWarpPhase.notReady => 'Не включена',
      PokrovWarpPhase.readyToConsent => 'Доступна',
      PokrovWarpPhase.consented => 'Включится при подключении',
      PokrovWarpPhase.active => 'Активна',
      PokrovWarpPhase.degraded => 'Требует проверки',
      PokrovWarpPhase.fallback => 'Временно приостановлена',
      PokrovWarpPhase.revoked => 'Выключена',
      PokrovWarpPhase.error => 'Не удалось включить',
    };
  }

  String get publicSheetBody => switch (phase) {
        PokrovWarpPhase.notReady =>
          'POKROV не показывает этот режим, пока сервер не подтвердит готовность для устройства.',
        PokrovWarpPhase.readyToConsent =>
          'Дополнительный слой включается отдельно и может менять скорость.',
        PokrovWarpPhase.consented =>
          'Режим включится при следующем подключении и останется управляемым отсюда.',
        PokrovWarpPhase.active =>
          'Режим активен. Если сайты работают нестабильно, его можно выключить.',
        PokrovWarpPhase.degraded =>
          'Режим работает нестабильно. POKROV может временно вернуться к обычному подключению.',
        PokrovWarpPhase.fallback =>
          'POKROV временно вернулся к обычному подключению, чтобы сохранить доступ.',
        PokrovWarpPhase.revoked =>
          'Режим выключен. Его можно включить снова после проверки доступности.',
        PokrovWarpPhase.error =>
          'POKROV не смог включить дополнительный режим. Попробуйте позже или напишите в поддержку.',
      };

  String get publicActionLabel =>
      consented || phase == PokrovWarpPhase.active ? 'Выключить' : 'Включить';
}

class PokrovWarpConsentCacheEntry {
  const PokrovWarpConsentCacheEntry({
    required this.consented,
    required this.state,
    required this.publicLabel,
    required this.consentUpdatedAt,
  });

  factory PokrovWarpConsentCacheEntry.fromStatus(WarpControlStatus status) {
    return PokrovWarpConsentCacheEntry(
      consented: status.consented,
      state: _safeState(status.state),
      publicLabel: _safePublicLabel(status.publicLabel),
      consentUpdatedAt: status.consented
          ? status.consentedAt.trim()
          : status.revokedAt.trim(),
    );
  }

  final bool consented;
  final String state;
  final String publicLabel;
  final String consentUpdatedAt;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'feature': 'extended_protection',
      'public_label': publicLabel,
      'consented': consented,
      'state': state,
      if (consentUpdatedAt.isNotEmpty) 'consent_updated_at': consentUpdatedAt,
    };
  }

  static String _safePublicLabel(String value) {
    final text = value.trim();
    if (text.isEmpty || text.toLowerCase().contains('warp')) {
      return 'Расширенная защита';
    }
    return text.length > 80 ? text.substring(0, 80) : text;
  }

  static String _safeState(String value) {
    final text = value.trim().toLowerCase();
    if (RegExp(r'^[a-z0-9_:-]{2,64}$').hasMatch(text)) {
      return text;
    }
    return 'not_ready';
  }
}

class PokrovWarpSupportDiagnostics {
  const PokrovWarpSupportDiagnostics._(this._json);

  factory PokrovWarpSupportDiagnostics.fromLifecycle(
    PokrovWarpLifecycle lifecycle,
  ) {
    return PokrovWarpSupportDiagnostics._(
      <String, Object?>{
        'enhanced_protection_state': lifecycle.phase.name,
        'enhanced_protection_consent': lifecycle.consented,
        'enhanced_protection_available': lifecycle.canOffer,
        if (lifecycle.lastError.isNotEmpty)
          'enhanced_protection_error': _redact(lifecycle.lastError).isEmpty
              ? '[redacted]'
              : _redact(lifecycle.lastError),
      },
    );
  }

  final Map<String, Object?> _json;

  Map<String, Object?> toJson() => Map<String, Object?>.unmodifiable(_json);

  static String _redact(String value) {
    var next = value.trim();
    final patterns = <RegExp>[
      RegExp(r'\b(?:wireguard|warp|private-key|private_key)\b',
          caseSensitive: false),
      RegExp(r'\b(?:token|secret|access_key|uuid|server)[=:]\S+',
          caseSensitive: false),
      RegExp(r'https?://\S+', caseSensitive: false),
    ];
    for (final pattern in patterns) {
      next = next.replaceAll(pattern, '[redacted]');
    }
    return next;
  }
}
