import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final packageRoot = Directory.current;
  final rulesSurface =
      File('${packageRoot.path}/lib/src/features/rules/rules_surface.dart');
  final routeLabels =
      File('${packageRoot.path}/lib/src/features/rules/route_labels.dart');
  final locationsSurface = File(
      '${packageRoot.path}/lib/src/features/locations/locations_surface.dart');
  final locationLabels = File(
      '${packageRoot.path}/lib/src/features/locations/location_labels.dart');
  final homeSurface =
      File('${packageRoot.path}/lib/src/features/home/home_surface.dart');
  final onboardingFlow = File(
      '${packageRoot.path}/lib/src/features/onboarding/onboarding_flow.dart');
  final warpSheet =
      File('${packageRoot.path}/lib/src/features/warp/warp_sheet.dart');
  final profileSurface =
      File('${packageRoot.path}/lib/src/features/profile/profile_surface.dart');
  final profileSheets =
      File('${packageRoot.path}/lib/src/features/profile/profile_sheets.dart');
  final supportChat =
      File('${packageRoot.path}/lib/src/features/support/support_chat.dart');
  final rewardsHub =
      File('${packageRoot.path}/lib/src/features/rewards/rewards_hub.dart');
  final rulesHelpers =
      File('${packageRoot.path}/lib/src/features/rules/rules_helpers.dart');
  final seedShell = File('${packageRoot.path}/lib/src/shell/seed_shell.dart');

  test('rules normal UI copy uses final route labels and friendly app names',
      () {
    final rules = rulesSurface.readAsStringSync();
    final labels = routeLabels.readAsStringSync();
    final combined = '$rules\n$labels';

    expect(combined, contains('Умный режим'));
    expect(combined, contains('Всё устройство'));
    expect(combined, contains('Только выбранные'));
    expect(
      combined,
      contains(
        'Российские сервисы работают напрямую, остальное через POKROV VPN.',
      ),
    );
    expect(combined, contains('Весь трафик идет через POKROV VPN.'));
    expect(
      combined,
      contains('POKROV VPN работает только для выбранных приложений.'),
    );

    for (final forbidden in const <String>[
      'За рубеж',
      'Зарубежные сайты',
      'Весь трафик устройства идет через POKROV.',
      'POKROV используют только выбранные приложения или .exe.',
      'Выберите .exe или запущенный процесс.',
      "subtitle: 'telegram.exe'",
      "subtitle: 'org.telegram.messenger'",
      "hintText: hint",
      'split tunneling',
      'TUN',
      'CIDR',
      'regex',
      'domain editor',
      'Только выбранные приложения',
      'Техническое имя',
      'Технические сведения',
      'Файл',
      'Запущено',
      'Сейчас запущено',
      'Подсказка',
    ]) {
      expect(combined, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test(
      'locations normal UI copy keeps auto first and hides technical node data',
      () {
    final locations = locationsSurface.readAsStringSync();
    final labels = locationLabels.readAsStringSync();
    final combined = '$locations\n$labels';

    expect(combined, contains('Автоматически'));
    expect(combined, contains('Отлично'));
    expect(combined, contains('Хорошо'));
    expect(combined, contains('Стабильно'));
    expect(combined, contains('Медленно'));

    for (final forbidden in const <String>[
      'Автоматический выбор',
      ' ms',
      'ms ',
      ' мс',
      'мс ',
      'panelLatencyMs',
      'probeHost',
      'probe.host',
      'hostname',
      'node.code.trim().isEmpty ?',
      'сервер',
      'сервера',
      'профиля',
    ]) {
      expect(combined, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('normal UI copy has no dead placeholders for shipped app shell', () {
    final combined = <String>[
      homeSurface.readAsStringSync(),
      onboardingFlow.readAsStringSync(),
      warpSheet.readAsStringSync(),
      rulesSurface.readAsStringSync(),
      routeLabels.readAsStringSync(),
      locationsSurface.readAsStringSync(),
      locationLabels.readAsStringSync(),
      profileSurface.readAsStringSync(),
      profileSheets.readAsStringSync(),
      supportChat.readAsStringSync(),
      rewardsHub.readAsStringSync(),
      rulesHelpers.readAsStringSync(),
    ].join('\n');

    for (final forbidden in const <String>[
      'Скоро',
      'скоро',
      'Здесь будут',
      'Когда он будет',
      'будут доступны здесь',
      'после настройки внешнего вида',
      'feature flag',
      'client_local',
      'managed profile',
      'адреса серверов',
      'Ключи, ссылки, хосты',
      'Логи, ключи, ссылки',
      'Сейчас нет персональных акций',
      'Расширенная приватность',
      'Сервер еще готовит доступ',
      'Появится после подготовки',
      'появится после системной проверки',
      'Копия',
      'без срочности',
      'WARP · готовится',
      'WARP готовится',
      'Расширенная защита включится',
      'Расширенная защита выключена',
      'heavyImpact(',
    ]) {
      expect(combined, isNot(contains(forbidden)), reason: forbidden);
    }

    expect(
      seedShell.readAsStringSync(),
      isNot(contains('heavyImpact(')),
      reason: 'Rewards and bonus actions should stay calm, not casino-like.',
    );
  });
}
