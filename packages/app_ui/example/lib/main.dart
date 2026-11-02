import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pokrov_app_ui/pokrov_app_ui.dart';
import 'sample_data.dart';

/// Clickable dummy of the approved redesign. Everything here is fake:
/// the «connection» is a timer and every list is sample data. The real
/// app replaces [_PreviewState] with its own controllers.
void main() => runApp(const PokrovPreviewApp());

/// Theme and holiday of the preview; `--dart-define=POKROV_SEASON=<id>`
/// opens it on a holiday (`newYearNight` adds the fireworks).
class _Look {
  const _Look({this.dark = false, this.season, this.fireworks = false});

  final bool dark;
  final PokrovSeason? season;
  final bool fireworks;

  _Look copyWith({bool? dark, PokrovSeason? season, bool clearSeason = false, bool? fireworks}) => _Look(
        dark: dark ?? this.dark,
        season: clearSeason ? null : season ?? this.season,
        fireworks: fireworks ?? this.fireworks,
      );
}

const _seasonDefine = String.fromEnvironment('POKROV_SEASON');

final _look = ValueNotifier(_Look(
  season: _seasonDefine == 'newYearNight' ? PokrovSeason.newYear : PokrovSeason.values.asNameMap()[_seasonDefine],
  fireworks: _seasonDefine == 'newYearNight',
));

const _seasonNames = {
  PokrovSeason.halloween: 'Хэллоуин',
  PokrovSeason.newYear: 'Новый год',
  PokrovSeason.christmas: 'Рождество',
  PokrovSeason.valentine: '14 февраля',
  PokrovSeason.defender: '23 февраля',
  PokrovSeason.womensDay: '8 марта',
  PokrovSeason.aprilFools: '1 апреля',
  PokrovSeason.cosmonautics: 'День космонавтики',
  PokrovSeason.easter: 'Пасха',
  PokrovSeason.victoryDay: '9 мая',
};

class PokrovPreviewApp extends StatelessWidget {
  const PokrovPreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: _look,
      builder: (context, look, _) => MaterialApp(
        title: 'POKROV макет',
        debugShowCheckedModeBanner: false,
        theme: pokrovUiTheme(brightness: look.dark ? Brightness.dark : Brightness.light, season: look.season, fireworks: look.fireworks),
        home: const _Preview(),
      ),
    );
  }
}

class _Preview extends StatefulWidget {
  const _Preview();

  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> {
  bool _started = false;
  ConnectionPhase _phase = ConnectionPhase.off;
  PokrovTab _tab = PokrovTab.protection;
  String? _country;
  String _route = 'ru';
  String _appliedRoute = 'ru';
  bool _warp = false;
  bool _bypass = true;
  List<String> _tiles = PokrovSampleData.defaultTiles;
  int _attempts = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _countryName => _country == null ? 'Германия' : PokrovSampleData.countries.firstWhere((c) => c.code == _country).name;

  void _toggle() {
    switch (_phase) {
      case ConnectionPhase.on:
      case ConnectionPhase.connecting:
        _timer?.cancel();
        setState(() => _phase = ConnectionPhase.off);
      case ConnectionPhase.off:
      case ConnectionPhase.error:
        _connect();
    }
  }

  /// Every third attempt fails so the error state can be seen.
  void _connect() {
    _timer?.cancel();
    _attempts++;
    setState(() => _phase = ConnectionPhase.connecting);
    _timer = Timer(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      setState(() => _phase = _attempts % 3 == 0 ? ConnectionPhase.error : ConnectionPhase.on);
    });
  }

  void _openStatus() {
    showPokrovSheet<void>(
      context,
      (sheetContext) => StatusSheet(
        data: PokrovSampleData.status(phase: _phase == ConnectionPhase.on ? ConnectionPhase.on : ConnectionPhase.off, country: _countryName),
        onPrimary: () {
          Navigator.pop(sheetContext);
          if (_phase != ConnectionPhase.on) _toggle();
        },
        onDetails: () {
          Navigator.pop(sheetContext);
          _openDiagnostics();
        },
      ),
    );
  }

  void _openDiagnostics() => _push((context) => DiagnosticsScreen(
        data: PokrovSampleData.diagnostics(on: _phase == ConnectionPhase.on),
        onBack: () => Navigator.pop(context),
        onSend: () => _toast(context, 'Отчёт отправлен (макет)'),
        onCopyCode: () => _toast(context, 'Код скопирован (макет)'),
        onTechnical: () => _toast(context, 'Здесь будут технические детали (макет)'),
      ));

  void _push(WidgetBuilder builder) => Navigator.of(context).push(MaterialPageRoute<void>(builder: builder));

  void _toast(BuildContext context, String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), behavior: SnackBarBehavior.floating));
  }

  void _openRenew() {
    _push((context) => _RenewHost(onBack: () => Navigator.pop(context), toast: (t) => _toast(context, t)));
  }

  void _openSupport() {
    _push((context) => _SupportHost(onBack: () => Navigator.pop(context)));
  }

  void _openBonuses() {
    _push((context) => BonusesScreen(data: PokrovSampleData.bonuses, onBack: () => Navigator.pop(context)));
  }

  void _openLocations() {
    _push((context) => StatefulBuilder(builder: (context, setPage) => Scaffold(body: LocationsScreen(
      data: LocationsViewData(countries: PokrovSampleData.countries, selectedCode: _country),
      onAuto: () { setState(() => _country = null); setPage(() {}); },
      onSelect: (code) { setState(() => _country = code); setPage(() {}); },
      onRefresh: () => _toast(context, 'Список обновлён (макет)'),
      onBack: () => Navigator.pop(context),
    ))));
  }

  void _openRules() {
    _push((context) => StatefulBuilder(builder: (context, setPage) => Scaffold(body: RulesScreen(
      data: PokrovSampleData.rules(selected: _route, applied: _appliedRoute),
      onSelect: (id) { setState(() => _route = id); setPage(() {}); },
      onApply: () {
        setState(() => _appliedRoute = _route);
        setPage(() {});
        if (_phase == ConnectionPhase.on) _connect();
      },
      onWarning: () => _toast(context, 'Обновляем список… (макет)'),
      onBack: () => Navigator.pop(context),
    ))));
  }

  void _openTiles() {
    showPokrovSheet<void>(context, (context) => HomeTilesSheet(
      options: PokrovSampleData.tileOptions,
      selected: _tiles,
      defaults: PokrovSampleData.defaultTiles,
      onChanged: (tiles) => setState(() => _tiles = tiles),
    ));
  }

  void _openLook() {
    showPokrovSheet<void>(context, (context) => ValueListenableBuilder(
      valueListenable: _look,
      builder: (context, look, _) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Text('Тема и праздник', style: pokrovTextStyle(context, PokrovText.heading)),
          const SizedBox(height: 12),
          PokrovSegmented(
            labels: const ['Светлая', 'Тёмная'],
            index: look.dark ? 1 : 0,
            onChanged: (i) => _look.value = look.copyWith(dark: i == 1),
          ),
          for (final season in [null, ...PokrovSeason.values])
            PokrovRow(
              title: season == null ? 'Без праздника' : _seasonNames[season]!,
              value: season == look.season ? 'выбран' : null,
              onTap: () => _look.value = season == null ? look.copyWith(clearSeason: true) : look.copyWith(season: season),
            ),
          PokrovRow(
            title: 'Салют при подключении',
            value: look.fireworks ? 'вкл' : 'выкл',
            onTap: () => _look.value = look.copyWith(fireworks: !look.fireworks),
            divider: false,
          ),
        ],
      ),
    ));
  }

  HomeTile _tile(String id) {
    final option = PokrovSampleData.tileOptions.firstWhere((o) => o.id == id);
    return switch (id) {
      'country' => HomeTile(id: id, title: option.title, value: _country == null ? 'Авто' : _countryName, icon: option.icon, onTap: _openLocations),
      'route' => HomeTile(id: id, title: option.title, value: PokrovSampleData.routeModes.firstWhere((m) => m.id == _appliedRoute).title, icon: option.icon, onTap: _openRules),
      'warp' => HomeTile(id: id, title: option.title, value: option.hint, icon: option.icon, toggled: _warp, onTap: () => setState(() => _warp = !_warp)),
      'bypass' => HomeTile(id: id, title: option.title, value: _bypass ? 'Включён' : 'Выключен', icon: option.icon, onTap: () => setState(() => _bypass = !_bypass)),
      'access' => HomeTile(id: id, title: option.title, value: 'Ещё 29 дней', icon: option.icon, onTap: () => setState(() => _tab = PokrovTab.access)),
      'help' => HomeTile(id: id, title: option.title, value: option.hint, icon: option.icon, onTap: () => setState(() => _tab = PokrovTab.help)),
      _ => HomeTile(id: id, title: option.title, value: option.hint, icon: option.icon, onTap: () => _toast(context, '${option.title} (макет)')),
    };
  }

  Widget _body() {
    switch (_tab) {
      case PokrovTab.protection:
        return HomeScreen(
          data: PokrovSampleData.home(phase: _phase, country: _countryName, tiles: [for (final id in _tiles) _tile(id)]),
          adSlot: AdSlot(compact: true,
            child: const ColoredBox(color: Color(0xFFEAF0EC), child: Center(child: Text('Пример рекламного места')))),
          onNotifications: () => _toast(context, 'Уведомления (макет)'),
          onToggle: _toggle,
          onOpenStatus: _openStatus,
          onOpenAccess: () => setState(() => _tab = PokrovTab.access),
          onEditTiles: _openTiles,
          onTip: () => _toast(context, 'Откроется Telegram-канал (макет)'),
          onHelp: () => setState(() => _tab = PokrovTab.help),
        );
      case PokrovTab.access:
        return AccessScreen(
          data: PokrovSampleData.access,
          onRenew: _openRenew,
          steps: PokrovSampleData.accessSteps,
          onStep: (_) => _toast(context, 'Следующий шаг (макет)'),
          onDevices: () => _toast(context, 'Устройства (макет)'),
          onAddDevice: () => _toast(context, '«Код для входа» (макет)'),
          onActivate: () => _toast(context, 'Ввод кода (макет)'),
          onAccount: () => _toast(context, 'Telegram и почта (макет)'),
          onBonuses: _openBonuses,
          onTelegramProxy: () => _toast(context, 'Telegram-прокси (макет)'),
          onShare: () => _toast(context, 'Поделиться (макет)'),
        );
      case PokrovTab.help:
        return HelpScreen(
          phase: _phase,
          onCheck: _openStatus,
          onTopic: (_) => _openSupport(),
          onAssistant: _openSupport,
          onHuman: _openSupport,
          onReport: _openDiagnostics,
          onHistory: () => _toast(context, 'История и скорость (макет)'),
          onFeedback: () => _toast(context, 'Предложить идею (макет)'),
        );
      case PokrovTab.settings:
        return SettingsScreen(entries: [
          SettingsEntry(group: 'Подключение', title: 'Что идёт через POKROV', hint: 'Режим, приложения, сервисы', icon: Icons.alt_route_rounded, keywords: 'маршрут', onTap: _openRules),
          SettingsEntry(group: 'Подключение', title: 'Страна', hint: 'Авто или конкретная страна', icon: Icons.public_rounded, onTap: _openLocations),
          SettingsEntry(group: 'Подключение', title: 'WARP', hint: 'Запасной путь, если сайты не открываются', icon: Icons.cloud_outlined, toggled: _warp, onTap: () => setState(() => _warp = !_warp)),
          SettingsEntry(group: 'Подключение', title: 'Обход блокировок', hint: 'YouTube и похожее сначала напрямую', icon: Icons.turn_right_rounded, value: _bypass ? 'Включён' : 'Выключен', onTap: () => setState(() => _bypass = !_bypass)),
          SettingsEntry(group: 'Приложение', title: 'Виджеты на главной', hint: 'Что показывать на экране «Защита»', icon: Icons.dashboard_customize_outlined, onTap: _openTiles),
          SettingsEntry(group: 'Приложение', title: 'Тема', hint: 'Светлая, тёмная, праздники', icon: Icons.palette_outlined, onTap: _openLook),
          SettingsEntry(group: pokrovExpertGroup, title: 'DNS', hint: 'Защищённый DNS, SmartDNS', icon: Icons.dns_outlined, keywords: 'doh adguard', onTap: _openRules),
          SettingsEntry(group: pokrovExpertGroup, title: 'Доверенный Wi-Fi', hint: 'Пауза дома, защита в чужих сетях', icon: Icons.wifi_rounded, keywords: 'wifi сеть', onTap: _openRules),
        ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_started) {
      return Scaffold(
        body: StartScreen(
          onStart: () => setState(() => _started = true),
          onHaveCode: () => setState(() => _started = true),
        ),
      );
    }
    return Scaffold(
      extendBody: true,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: KeyedSubtree(key: ValueKey(_tab), child: _body()),
      ),
      bottomNavigationBar: PokrovTabBar(
        current: _tab,
        onSelect: (tab) => setState(() => _tab = tab),
      ),
    );
  }
}

class _RenewHost extends StatefulWidget {
  const _RenewHost({required this.onBack, required this.toast});

  final VoidCallback onBack;
  final ValueChanged<String> toast;

  @override
  State<_RenewHost> createState() => _RenewHostState();
}

class _RenewHostState extends State<_RenewHost> {
  String _plan = 'm12';

  @override
  Widget build(BuildContext context) {
    return RenewScreen(
      data: PokrovSampleData.renew(_plan),
      onSelect: (id) => setState(() => _plan = id),
      onPay: () => widget.toast('Здесь откроется страница оплаты (макет)'),
      onBack: widget.onBack,
      onIntroOffer: () => widget.toast('Первый месяц за 100 ₽ (макет)'),
      onActivationCode: () => widget.toast('Ввод кода активации (макет)'),
    );
  }
}

class _SupportHost extends StatefulWidget {
  const _SupportHost({required this.onBack});

  final VoidCallback onBack;

  @override
  State<_SupportHost> createState() => _SupportHostState();
}

class _SupportHostState extends State<_SupportHost> {
  final _messages = [...PokrovSampleData.support.messages];

  void _ask(String text) {
    setState(() => _messages.add(ChatMessage.user(text)));
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() => _messages.add(const ChatMessage.assistant(
            short: 'Это макет — настоящий помощник подключится позже.',
            steps: ['Попробуй переподключиться.', 'Если не поможет — позови человека.'],
          )));
    });
  }

  @override
  Widget build(BuildContext context) {
    return SupportScreen(
      data: SupportViewData(topics: PokrovSampleData.support.topics, messages: _messages),
      onSend: _ask,
      onTopic: _ask,
      onBack: widget.onBack,
      onHuman: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Передадим человеку (макет)'), behavior: SnackBarBehavior.floating)),
    );
  }
}
