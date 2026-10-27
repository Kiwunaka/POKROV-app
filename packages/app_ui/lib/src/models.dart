import 'package:flutter/widgets.dart';

/// Plain view data for the screens. The runtime maps its own state onto
/// these classes; the widgets never read app state directly.

enum ConnectionPhase { off, connecting, on, error }

enum InterfaceMode { simple, advanced }

enum PokrovTab { protection, locations, rules, profile }

class ConnectionStats {
  const ConnectionStats({this.ping = '—', this.uptime = '—', this.download = '—', this.upload = '—'});

  final String ping;
  final String uptime;
  final String download;
  final String upload;
}

class HealthCheck {
  const HealthCheck(this.label, {required this.ok});

  final String label;
  final bool ok;
}

class NextStepTip {
  const NextStepTip({required this.title, required this.text, required this.icon});

  final String title;
  final String text;
  final IconData icon;
}

class HomeViewData {
  const HomeViewData({
    required this.phase,
    required this.mode,
    this.accessBadge = 'Доступ',
    this.countryCaption = 'Страна',
    this.countryLabel = 'Авто',
    this.countryCode,
    this.connectedCountry = '',
    this.uptime = '',
    this.routeValue = 'напрямую',
    this.warpEnabled = false,
    this.stats = const ConnectionStats(),
    this.checks = const <HealthCheck>[],
    this.tip,
    this.showAdSlot = false,
    this.notificationsUnread = 0,
    this.statusLabel,
    this.actionLabel,
    this.errorTitle = 'Не получилось подключиться',
    this.errorMessage,
  });

  final ConnectionPhase phase;
  final InterfaceMode mode;
  final String accessBadge;

  /// Small caption above the country: «Страна» or «Страна · авто».
  final String countryCaption;

  /// Country value: «Авто», «Германия», «Польша».
  final String countryLabel;

  /// ISO code for the flag; null shows the auto badge.
  final String? countryCode;
  final String connectedCountry;
  final String uptime;

  /// Short value under «Российские сайты».
  final String routeValue;
  final bool warpEnabled;
  final ConnectionStats stats;
  final List<HealthCheck> checks;
  final NextStepTip? tip;
  final bool showAdSlot;
  final int notificationsUnread;
  final String? statusLabel;
  final String? actionLabel;
  final String errorTitle;
  final String? errorMessage;
}

class StatusRow {
  const StatusRow({required this.title, required this.detail, required this.ok});

  final String title;
  final String detail;
  final bool ok;
}

class StatusViewData {
  const StatusViewData({required this.phase, required this.title, required this.subtitle, required this.rows});

  final ConnectionPhase phase;
  final String title;
  final String subtitle;
  final List<StatusRow> rows;
}

class CountryOption {
  const CountryOption({required this.code, required this.name, this.pingMs, this.available = true});

  final String code;
  final String name;
  final int? pingMs;
  final bool available;
}

class LocationsViewData {
  const LocationsViewData({
    required this.mode,
    required this.countries,
    this.selectedCode,
    this.notice,
  });

  final InterfaceMode mode;
  final List<CountryOption> countries;

  /// null means «Авто».
  final String? selectedCode;
  final String? notice;
}

class RouteModeOption {
  const RouteModeOption({required this.id, required this.title, required this.description, this.recommended = false});

  final String id;
  final String title;
  final String description;
  final bool recommended;
}

class RulesViewData {
  const RulesViewData({
    required this.modes,
    required this.selectedId,
    required this.appliedId,
    this.appsSummary = 'не выбраны',
    this.presetsSummary = 'видео, ИИ, соцсети',
    this.expertSummary = 'DNS, сеть',
    this.warning,
  });

  final List<RouteModeOption> modes;
  final String selectedId;
  final String appliedId;
  final String appsSummary;
  final String presetsSummary;
  final String expertSummary;

  /// One-line soft warning, e.g. «Список приложений не обновился».
  final String? warning;

  bool get hasPendingChange => selectedId != appliedId;
}

class ProfileViewData {
  const ProfileViewData({
    required this.mode,
    this.accessBadge = 'Доступ',
    this.accessTitle = 'Нет сведений о доступе',
    this.accessDetail = '',
    this.accessProgress,
    this.accountLinked = '',
    this.devices = '',
    this.theme = 'как в системе',
    this.bonuses = '',
    this.version = '1.5.0',
  });

  final InterfaceMode mode;
  final String accessBadge;
  final String accessTitle;
  final String accessDetail;
  final double? accessProgress;
  final String accountLinked;
  final String devices;
  final String theme;
  final String bonuses;
  final String version;
}

class PlanOption {
  const PlanOption({required this.id, required this.short, required this.title, required this.price, required this.perMonth, required this.saving});

  final String id;
  final String short;
  final String title;
  final String price;
  final String perMonth;
  final String saving;
}

class RenewViewData {
  const RenewViewData({required this.current, required this.plans, required this.selectedId, required this.introOffer});

  final String current;
  final List<PlanOption> plans;
  final String selectedId;
  final String introOffer;

  PlanOption? get selected => plans.isEmpty ? null : plans.firstWhere((p) => p.id == selectedId, orElse: () => plans.last);
}

class ChatMessage {
  const ChatMessage.user(this.text)
      : fromUser = true,
        short = null,
        steps = const <String>[],
        author = '', actions = const [];

  const ChatMessage.assistant({required String this.short, required this.steps, this.author = 'ИИ-помощник', this.actions = const []})
      : fromUser = false,
        text = '';

  final bool fromUser;
  final String text;
  final String? short;
  final List<String> steps;
  final String author;
  final List<({String id, String label})> actions;
}

class SupportViewData {
  const SupportViewData({required this.topics, required this.messages, this.busy = false, this.busyLabel = 'Готовим ответ…', this.notice, this.subtitle = 'Сначала ответит ИИ, потом человек'});

  final List<String> topics;
  final List<ChatMessage> messages;
  final bool busy;
  final String busyLabel;
  final String? notice;
  final String subtitle;
}

enum BonusState { done, locked, available }

class BonusItem {
  const BonusItem({required this.title, required this.subtitle, required this.state, this.id = '', this.actionable = true});

  final String title;
  final String subtitle;
  final BonusState state;
  final String id;
  final bool actionable;
}

class Achievement {
  const Achievement(this.label, {required this.earned});

  final String label;
  final bool earned;
}

class BonusesViewData {
  const BonusesViewData({required this.total, required this.totalCaption, required this.breakdown, required this.items, required this.achievements, this.notice});

  final String total;
  final String totalCaption;
  final String breakdown;
  final List<BonusItem> items;
  final List<Achievement> achievements;
  final String? notice;
}

enum DiagnosticTone { pending, attention, ok }

class DiagnosticRow {
  const DiagnosticRow({required this.title, required this.value, required this.tone});

  final String title;
  final String value;
  final DiagnosticTone tone;
}

class DiagnosticsViewData {
  const DiagnosticsViewData({required this.headline, required this.body, required this.rows, required this.supportCode, this.healthy = false});

  final String headline;
  final String body;
  final List<DiagnosticRow> rows;

  /// Already masked for display, e.g. «PSD2-••••-••••».
  final String supportCode;
  final bool healthy;
}
