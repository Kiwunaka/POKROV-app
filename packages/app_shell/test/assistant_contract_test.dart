import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/src/assistant/pokrov_ai_assistant.dart';

void main() {
  test('assistant contract is support scoped and ticket backed', () {
    final session = PokrovAssistantSession.support(
      sessionId: 'local-support',
      ticketId: 42,
      status: PokrovAssistantSessionStatus.ready,
    );

    expect(session.surface, PokrovAssistantSurface.support);
    expect(session.ticketId, 42);
    expect(session.isTopLevelDestination, isFalse);
    expect(session.escalation.mode, PokrovAssistantEscalationMode.ticketBacked);
    expect(session.escalation.operatorRequired, isTrue);

    final suggestions = PokrovAssistantContract.defaultSupportSuggestions;
    expect(suggestions, isNotEmpty);
    expect(
      suggestions.map((suggestion) => suggestion.key),
      containsAll(<String>[
        'support-ai-suggestion-connectivity',
        'support-ai-suggestion-speed',
        'support-ai-suggestion-bonus',
      ]),
    );
    expect(
      suggestions.every(
          (suggestion) => suggestion.surface == PokrovAssistantSurface.support),
      isTrue,
    );
  });

  test('assistant redaction removes raw configs keys and topology', () {
    final attachment = PokrovAssistantDiagnosticAttachment.fromDiagnostics(
      <String, Object?>{
        'platform': 'windows',
        'route_mode': 'all_except_ru',
        'connection_status': 'ready',
        'raw_config': '{"outbounds":[{"server":"10.0.0.1"}]}',
        'subscription_url': 'vless://secret@example',
        'token': 'token=abc',
        'host': 'https://api.example.test',
      },
    );

    expect(attachment.safeDiagnostics['platform'], 'windows');
    expect(attachment.safeDiagnostics['route_mode'], 'all_except_ru');
    expect(attachment.safeDiagnostics.containsKey('raw_config'), isFalse);
    expect(
      attachment.safeDiagnostics.containsKey('subscription_url'),
      isFalse,
    );
    expect(attachment.safeDiagnostics.containsKey('token'), isFalse);
    expect(attachment.safeDiagnostics.containsKey('host'), isFalse);

    final redacted = PokrovAssistantRedactor.redactText(
      'vless://secret token=abc wireguard server=10.0.0.1 обычный текст',
    );

    expect(redacted, contains('[redacted]'));
    expect(redacted, isNot(contains('vless://')));
    expect(redacted, isNot(contains('token=abc')));
    expect(redacted, isNot(contains('wireguard')));
    expect(redacted, isNot(contains('server=10.0.0.1')));
    expect(redacted, contains('обычный текст'));
  });

  test('assistant diagnostics allow safe enhanced protection state only', () {
    final attachment = PokrovAssistantDiagnosticAttachment.fromDiagnostics(
      <String, Object?>{
        'platform': 'windows',
        'enhanced_protection_state': 'fallback',
        'enhanced_protection_consent': true,
        'enhanced_protection_available': true,
        'enhanced_protection_error': 'wireguard private-key failed',
        'warp_private_key': 'secret',
      },
    );

    expect(
      attachment.safeDiagnostics['enhanced_protection_state'],
      'fallback',
    );
    expect(attachment.safeDiagnostics['enhanced_protection_consent'], isTrue);
    expect(attachment.safeDiagnostics['enhanced_protection_available'], isTrue);
    expect(
      attachment.safeDiagnostics['enhanced_protection_error'],
      '[redacted] failed',
    );
    expect(attachment.safeDiagnostics.containsKey('warp_private_key'), isFalse);
  });

  test('assistant actions require explicit confirmation before app changes',
      () {
    const action = PokrovAssistantSafeAction(
      key: 'open-rules',
      label: 'Открыть правила',
      effect: PokrovAssistantSafeActionEffect.navigate,
      requiresConfirmation: true,
    );

    expect(action.requiresConfirmation, isTrue);
    expect(action.canRunAutomatically, isFalse);

    final message = PokrovAssistantMessage.assistant(
      id: 'm1',
      body: 'Могу открыть экран правил.',
      suggestions: PokrovAssistantContract.defaultSupportSuggestions.take(1),
      actions: const <PokrovAssistantSafeAction>[action],
    );

    expect(message.role, PokrovAssistantRole.assistant);
    expect(message.actions.single.canRunAutomatically, isFalse);
    expect(message.safeBody, message.body);
  });

  test('assistant api plan stays session scoped and escalation aware', () {
    const plan = PokrovAssistantApiPlan.defaultPlan;

    expect(plan.createSessionPath, '/api/assistant/sessions');
    expect(plan.messagesPathTemplate, '/api/assistant/sessions/{id}/messages');
    expect(plan.streamPathTemplate, '/api/assistant/sessions/{id}/stream');
    expect(plan.statusPathTemplate, '/api/assistant/sessions/{id}/status');
    expect(plan.escalatePathTemplate, '/api/assistant/sessions/{id}/escalate');
    expect(plan.confirmActionPath, '/api/assistant/actions/confirm');
    expect(plan.ticketFallbackPath, '/api/tickets');
    expect(plan.requiresSessionToken, isTrue);
  });
}
