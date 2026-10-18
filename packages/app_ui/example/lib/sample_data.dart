import 'package:flutter/material.dart';

import 'package:pokrov_app_ui/pokrov_app_ui.dart';

/// Fake data for the preview app and tests, never a production catalog.
abstract final class PokrovSampleData {
  static const countries = <CountryOption>[
    CountryOption(code: 'CH', name: 'Швейцария', pingMs: 41),
    CountryOption(code: 'DE', name: 'Германия', pingMs: 38),
    CountryOption(code: 'PL', name: 'Польша', pingMs: 46),
    CountryOption(code: 'RU', name: 'Россия', pingMs: 12),
    CountryOption(code: 'US', name: 'США', pingMs: 118),
  ];

  static const routeModes = <RouteModeOption>[
    RouteModeOption(id: 'ru', title: 'Россия напрямую', recommended: true, description: 'Российские сайты и банки работают как обычно, всё остальное — через POKROV.'),
    RouteModeOption(id: 'all', title: 'Всё через POKROV', description: 'Весь трафик идёт через POKROV, даже российские сайты.'),
    RouteModeOption(id: 'services', title: 'Только выбранные сервисы', description: 'Через POKROV — только сервисы из готовых наборов. Остальное напрямую.'),
    RouteModeOption(id: 'only_apps', title: 'Только выбранные приложения', description: 'POKROV работает только для отмеченных приложений.'),
    RouteModeOption(id: 'except_apps', title: 'Все, кроме выбранных приложений', description: 'Отмеченные приложения — напрямую, остальные через POKROV.'),
  ];

  static const plans = <PlanOption>[
    PlanOption(id: 'm1', short: '1 мес', title: '1 месяц', price: '250 ₽', perMonth: '30 дней', saving: ''),
    PlanOption(id: 'm3', short: '3 мес', title: '3 месяца', price: '700 ₽', perMonth: '≈ 233 ₽ в месяц', saving: '−7%'),
    PlanOption(id: 'm6', short: '6 мес', title: '6 месяцев', price: '1 200 ₽', perMonth: '≈ 200 ₽ в месяц', saving: '−20%'),
    PlanOption(id: 'm9', short: '9 мес', title: '9 месяцев', price: '1 700 ₽', perMonth: '≈ 189 ₽ в месяц', saving: '−24%'),
    PlanOption(id: 'm12', short: '12 мес', title: '12 месяцев', price: '2 000 ₽', perMonth: '≈ 167 ₽ в месяц', saving: '−33%'),
  ];

  static HomeViewData home({required ConnectionPhase phase, required InterfaceMode mode, String? countryCode, bool warp = false, String routeValue = 'напрямую'}) {
    final on = phase == ConnectionPhase.on;
    final name = countryCode == null ? 'Германия' : countries.firstWhere((c) => c.code == countryCode).name;
    return HomeViewData(
      phase: phase,
      mode: mode,
      accessBadge: 'Премиум',
      showAdSlot: true,
      countryCaption: countryCode == null && on ? 'Страна · авто' : 'Страна',
      countryLabel: countryCode == null && !on ? 'Авто' : name,
      countryCode: countryCode ?? (on ? 'DE' : null),
      connectedCountry: name,
      uptime: '00:12:48',
      routeValue: routeValue,
      warpEnabled: warp,
      stats: on ? const ConnectionStats(ping: '38', uptime: '12:48', download: '12,4', upload: '1,8') : const ConnectionStats(),
      checks: [
        HealthCheck('Интернет', ok: on),
        HealthCheck('Сайты', ok: on),
        HealthCheck('Telegram', ok: on),
      ],
      tip: on
          ? const NextStepTip(title: 'Подключи второе устройство', text: 'До 5 устройств на одном доступе', icon: Icons.devices_rounded)
          : const NextStepTip(title: 'Забери +5 дней', text: 'Подпишись на наш Telegram-канал', icon: Icons.send_rounded),
    );
  }

  static StatusViewData status({required ConnectionPhase phase, String country = 'Германия'}) {
    if (phase == ConnectionPhase.on) {
      return StatusViewData(
        phase: phase,
        title: 'Всё работает',
        subtitle: 'Ты под защитой · $country',
        rows: [
          StatusRow(title: 'Подключено', detail: 'страна — $country', ok: true),
          const StatusRow(title: 'Сайты открываются', detail: 'проверили только что', ok: true),
          const StatusRow(title: 'Telegram работает', detail: 'сообщения проходят', ok: true),
        ],
      );
    }
    return const StatusViewData(
      phase: ConnectionPhase.off,
      title: 'Защита выключена',
      subtitle: 'Включи — и проверим, всё ли работает',
      rows: [
        StatusRow(title: 'Подключение', detail: 'выключено', ok: false),
        StatusRow(title: 'Сайты', detail: 'проверим после включения', ok: false),
        StatusRow(title: 'Telegram', detail: 'проверим после включения', ok: false),
      ],
    );
  }

  static RulesViewData rules({String selected = 'ru', String applied = 'ru'}) => RulesViewData(
        modes: routeModes,
        selectedId: selected,
        appliedId: applied,
        warning: 'Список приложений не обновился',
      );

  static ProfileViewData profile(InterfaceMode mode) => ProfileViewData(
    mode: mode, accessBadge: 'Премиум', accessTitle: 'Доступ активен',
    accessDetail: 'Ещё 29 дней · до 5 устройств', accessProgress: 0.72,
    accountLinked: 'привязаны ✓', devices: '2 из 5', bonuses: '+24 дня',
  );

  static RenewViewData renew([String selected = 'm12']) => RenewViewData(
        current: 'Сейчас: Премиум, ещё 29 дней',
        plans: plans,
        selectedId: selected,
        introOffer: 'Первый месяц — 100 ₽, один раз',
      );

  static const support = SupportViewData(
    topics: ['Не подключается', 'Медленно', 'Сайт не открывается'],
    messages: [
      ChatMessage.user('Включил, но YouTube не грузится'),
      ChatMessage.assistant(
        short: 'Скорее всего, сменилась сеть, а соединение осталось старым.',
        steps: ['Нажми «Переподключить».', 'Не помогло — выбери другую страну.'],
      ),
    ],
  );

  static const bonuses = BonusesViewData(
    total: '+24',
    totalCaption: 'дня уже получено',
    breakdown: 'Старт +14 · Telegram +10',
    items: [
      BonusItem(title: 'Подписка на Telegram-канал', subtitle: 'Получено', state: BonusState.done),
      BonusItem(title: 'Пригласить друга', subtitle: 'Откроется после первой оплаты', state: BonusState.locked),
      BonusItem(title: 'Рулетка и календарь', subtitle: 'Откроются после первой оплаты', state: BonusState.locked),
    ],
    achievements: [
      Achievement('Добро пожаловать', earned: true),
      Achievement('Свои устройства', earned: true),
      Achievement('Под защитой', earned: false),
      Achievement('Вместе с POKROV', earned: false),
      Achievement('Первая удача', earned: false),
      Achievement('Первая отметка', earned: false),
      Achievement('7 отметок', earned: false),
      Achievement('Первый друг', earned: false),
    ],
  );

  static DiagnosticsViewData diagnostics({required bool on}) => on
      ? const DiagnosticsViewData(
          healthy: true,
          headline: 'Всё в порядке',
          body: 'Проверили соединение — проблем не видно. Если что-то не так, отправь отчёт: поддержка увидит то же, что и мы.',
          supportCode: 'PSD2-••••-••••',
          rows: [
            DiagnosticRow(title: 'Подключение', value: 'работает', tone: DiagnosticTone.ok),
            DiagnosticRow(title: 'Маршруты', value: 'в порядке', tone: DiagnosticTone.ok),
            DiagnosticRow(title: 'Адреса сайтов (DNS)', value: 'в порядке', tone: DiagnosticTone.ok),
            DiagnosticRow(title: 'Выход через VPN', value: 'Германия', tone: DiagnosticTone.ok),
          ],
        )
      : const DiagnosticsViewData(
          headline: 'Проверка ещё не прошла',
          body: 'Включи защиту — проверим соединение. Если что-то не так, отправь отчёт: поддержка увидит то же, что и мы.',
          supportCode: 'PSD2-••••-••••',
          rows: [
            DiagnosticRow(title: 'Подключение', value: 'после включения', tone: DiagnosticTone.pending),
            DiagnosticRow(title: 'Маршруты', value: 'после включения', tone: DiagnosticTone.pending),
            DiagnosticRow(title: 'Адреса сайтов (DNS)', value: 'нужна проверка', tone: DiagnosticTone.attention),
            DiagnosticRow(title: 'Выход через VPN', value: 'после включения', tone: DiagnosticTone.pending),
          ],
        );
}
