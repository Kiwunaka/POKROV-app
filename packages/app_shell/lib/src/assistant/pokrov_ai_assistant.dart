enum PokrovAssistantSurface {
  support,
}

enum PokrovAssistantSessionStatus {
  ready,
  streaming,
  waitingForOperator,
  escalated,
  unavailable,
}

enum PokrovAssistantRole {
  user,
  assistant,
  operator,
  system,
}

enum PokrovAssistantEscalationMode {
  ticketBacked,
}

enum PokrovAssistantSafeActionEffect {
  none,
  navigate,
  attachDiagnostics,
  openHandoff,
}

class PokrovAssistantSession {
  const PokrovAssistantSession._({
    required this.sessionId,
    required this.surface,
    required this.status,
    required this.escalation,
    this.ticketId,
  });

  factory PokrovAssistantSession.support({
    required String sessionId,
    required PokrovAssistantSessionStatus status,
    int? ticketId,
  }) {
    return PokrovAssistantSession._(
      sessionId: sessionId,
      surface: PokrovAssistantSurface.support,
      status: status,
      ticketId: ticketId,
      escalation: const PokrovAssistantEscalation.ticketBacked(),
    );
  }

  final String sessionId;
  final PokrovAssistantSurface surface;
  final PokrovAssistantSessionStatus status;
  final int? ticketId;
  final PokrovAssistantEscalation escalation;

  bool get isTopLevelDestination => false;
}

class PokrovAssistantEscalation {
  const PokrovAssistantEscalation.ticketBacked()
      : mode = PokrovAssistantEscalationMode.ticketBacked,
        operatorRequired = true;

  final PokrovAssistantEscalationMode mode;
  final bool operatorRequired;
}

class PokrovAssistantSuggestion {
  const PokrovAssistantSuggestion({
    required this.key,
    required this.title,
    required this.prompt,
    this.surface = PokrovAssistantSurface.support,
  });

  final String key;
  final String title;
  final String prompt;
  final PokrovAssistantSurface surface;
}

class PokrovAssistantSafeAction {
  const PokrovAssistantSafeAction({
    required this.key,
    required this.label,
    required this.effect,
    this.requiresConfirmation = true,
  });

  final String key;
  final String label;
  final PokrovAssistantSafeActionEffect effect;
  final bool requiresConfirmation;

  bool get canRunAutomatically =>
      !requiresConfirmation && effect == PokrovAssistantSafeActionEffect.none;
}

class PokrovAssistantMessage {
  PokrovAssistantMessage({
    required this.id,
    required this.role,
    required this.body,
    Iterable<PokrovAssistantSuggestion> suggestions =
        const <PokrovAssistantSuggestion>[],
    Iterable<PokrovAssistantSafeAction> actions =
        const <PokrovAssistantSafeAction>[],
  })  : suggestions = List<PokrovAssistantSuggestion>.unmodifiable(suggestions),
        actions = List<PokrovAssistantSafeAction>.unmodifiable(actions);

  factory PokrovAssistantMessage.assistant({
    required String id,
    required String body,
    Iterable<PokrovAssistantSuggestion> suggestions =
        const <PokrovAssistantSuggestion>[],
    Iterable<PokrovAssistantSafeAction> actions =
        const <PokrovAssistantSafeAction>[],
  }) {
    return PokrovAssistantMessage(
      id: id,
      role: PokrovAssistantRole.assistant,
      body: body,
      suggestions: suggestions,
      actions: actions,
    );
  }

  final String id;
  final PokrovAssistantRole role;
  final String body;
  final List<PokrovAssistantSuggestion> suggestions;
  final List<PokrovAssistantSafeAction> actions;

  String get safeBody => PokrovAssistantRedactor.redactText(body);
}

class PokrovAssistantDiagnosticAttachment {
  PokrovAssistantDiagnosticAttachment._(this.safeDiagnostics);

  factory PokrovAssistantDiagnosticAttachment.fromDiagnostics(
    Map<String, Object?> diagnostics,
  ) {
    final safe = <String, Object?>{};
    for (final entry in diagnostics.entries) {
      final key = entry.key.trim();
      if (!PokrovAssistantRedactor.allowedDiagnosticKeys.contains(key) ||
          PokrovAssistantRedactor.isSensitiveKey(key)) {
        continue;
      }
      if (key == 'enhanced_protection_error') {
        final value =
            PokrovAssistantRedactor.safeRedactedDiagnosticValue(entry.value);
        if (value != null) {
          safe[key] = value;
        }
        continue;
      }
      final value = PokrovAssistantRedactor.safeDiagnosticValue(entry.value);
      if (value != null) {
        safe[key] = value;
      }
    }
    return PokrovAssistantDiagnosticAttachment._(
      Map<String, Object?>.unmodifiable(safe),
    );
  }

  final Map<String, Object?> safeDiagnostics;
}

class PokrovAssistantContract {
  const PokrovAssistantContract._();

  static const defaultSupportSuggestions = <PokrovAssistantSuggestion>[
    PokrovAssistantSuggestion(
      key: 'support-ai-suggestion-connectivity',
      title: 'Не подключается',
      prompt: 'Не подключается. Проверьте безопасный контекст и подскажите '
          'следующий шаг без сырых настроек.',
    ),
    PokrovAssistantSuggestion(
      key: 'support-ai-suggestion-speed',
      title: 'Медленно',
      prompt: 'Работает медленно. Подскажите, что проверить в приложении '
          'без смены скрытых параметров вручную.',
    ),
    PokrovAssistantSuggestion(
      key: 'support-ai-suggestion-bonus',
      title: 'Бонусы',
      prompt: 'Нужно разобраться с бонусом или подпиской. Проверьте общий '
          'сценарий без персональных данных.',
    ),
  ];
}

class PokrovAssistantApiPlan {
  const PokrovAssistantApiPlan({
    required this.createSessionPath,
    required this.messagesPathTemplate,
    required this.streamPathTemplate,
    required this.statusPathTemplate,
    required this.escalatePathTemplate,
    required this.confirmActionPath,
    required this.ticketFallbackPath,
    required this.requiresSessionToken,
  });

  static const defaultPlan = PokrovAssistantApiPlan(
    createSessionPath: '/api/assistant/sessions',
    messagesPathTemplate: '/api/assistant/sessions/{id}/messages',
    streamPathTemplate: '/api/assistant/sessions/{id}/stream',
    statusPathTemplate: '/api/assistant/sessions/{id}/status',
    escalatePathTemplate: '/api/assistant/sessions/{id}/escalate',
    confirmActionPath: '/api/assistant/actions/confirm',
    ticketFallbackPath: '/api/tickets',
    requiresSessionToken: true,
  );

  final String createSessionPath;
  final String messagesPathTemplate;
  final String streamPathTemplate;
  final String statusPathTemplate;
  final String escalatePathTemplate;
  final String confirmActionPath;
  final String ticketFallbackPath;
  final bool requiresSessionToken;
}

class PokrovAssistantRedactor {
  const PokrovAssistantRedactor._();

  static const allowedDiagnosticKeys = <String>{
    'app_version',
    'platform',
    'os_version',
    'route_mode',
    'connection_status',
    'entitlement_state',
    'recent_error_category',
    'selected_region',
    'selected_country',
    'dns_health',
    'uplink_health',
    'device_name',
    'app_build',
    'enhanced_protection_state',
    'enhanced_protection_consent',
    'enhanced_protection_available',
    'enhanced_protection_error',
  };

  static const _sensitiveKeyFragments = <String>{
    'raw',
    'config',
    'subscription',
    'token',
    'secret',
    'key',
    'host',
    'server',
    'url',
    'uuid',
  };

  static final _sensitiveTextPatterns = <RegExp>[
    RegExp(r'\b(?:vless|vmess|trojan)://\S+', caseSensitive: false),
    RegExp(r'https?://\S+', caseSensitive: false),
    RegExp(
      r'\b(?:token|secret|access_key|uuid|server|subscription)[=:]\S+',
      caseSensitive: false,
    ),
    RegExp(r'\b(?:wireguard|warp|private-key|private_key|vless|vmess|trojan)\b',
        caseSensitive: false),
  ];

  static bool isSensitiveKey(String key) {
    final normalized = key.trim().toLowerCase();
    return _sensitiveKeyFragments.any(normalized.contains);
  }

  static Object? safeDiagnosticValue(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is bool || value is int || value is double) {
      return value;
    }
    final text = value.toString().trim();
    if (text.isEmpty || text.length > 160 || text != redactText(text)) {
      return null;
    }
    return text;
  }

  static Object? safeRedactedDiagnosticValue(Object? value) {
    if (value == null) {
      return null;
    }
    final text = value.toString().trim();
    if (text.isEmpty || text.length > 160) {
      return null;
    }
    final redacted = redactText(text).trim();
    return redacted.isEmpty ? null : redacted;
  }

  static String redactText(String value) {
    var next = value;
    for (final pattern in _sensitiveTextPatterns) {
      next = next.replaceAll(pattern, '[redacted]');
    }
    return next.replaceAll(RegExp(r'(?:\[redacted\]\s*){2,}'), '[redacted] ');
  }
}
