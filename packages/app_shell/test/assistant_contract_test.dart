import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/src/assistant/pokrov_ai_assistant.dart';

void main() {

  test('assistant redaction removes raw configs keys and topology', () {
    final attachment = PokrovAssistantDiagnosticAttachment.fromDiagnostics(
      <String, Object?>{
        'platform': 'windows',
        'route_mode': 'all_except_ru',
        'connection_status': 'ready',
        'connection_active': true,
        'current_location_label': 'Франкфурт · Белые списки',
        'raw_config': '{"outbounds":[{"server":"10.0.0.1"}]}',
        'subscription_url': 'vless://secret@example',
        'token': 'token=abc',
        'host': 'https://api.example.test',
      },
    );

    expect(attachment.safeDiagnostics['platform'], 'windows');
    expect(attachment.safeDiagnostics['route_mode'], 'all_except_ru');
    expect(attachment.safeDiagnostics['connection_active'], isTrue);
    expect(
      attachment.safeDiagnostics['current_location_label'],
      'Франкфурт · Белые списки',
    );
    expect(attachment.safeDiagnostics.containsKey('raw_config'), isFalse);
    expect(
      attachment.safeDiagnostics.containsKey('subscription_url'),
      isFalse,
    );
    expect(attachment.safeDiagnostics.containsKey('token'), isFalse);
    expect(attachment.safeDiagnostics.containsKey('host'), isFalse);

    final redacted = PokrovAssistantRedactor.redactText(
      'vless://secret token=abc WARP WireGuard server=10.0.0.1 обычный текст',
    );

    expect(redacted, contains('[redacted]'));
    expect(redacted, isNot(contains('vless://')));
    expect(redacted, isNot(contains('token=abc')));
    expect(redacted, contains('WARP WireGuard'));
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
      'wireguard [redacted] failed',
    );
    expect(attachment.safeDiagnostics.containsKey('warp_private_key'), isFalse);
  });

}
