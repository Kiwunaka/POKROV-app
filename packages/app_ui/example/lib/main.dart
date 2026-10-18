import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pokrov_app_ui/pokrov_app_ui.dart';
import 'sample_data.dart';

/// Clickable dummy of the approved redesign. Everything here is fake:
/// the «connection» is a timer and every list is sample data. The real
/// app replaces [_PreviewState] with its own controllers.
void main() => runApp(const PokrovPreviewApp());

class PokrovPreviewApp extends StatelessWidget {
  const PokrovPreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'POKROV макет',
      debugShowCheckedModeBanner: false,
      theme: pokrovUiTheme(),
      home: const _Preview(),
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
  bool _firstConnectDone = false;
  ConnectionPhase _phase = ConnectionPhase.off;
  InterfaceMode _mode = InterfaceMode.simple;
  PokrovTab _tab = PokrovTab.protection;
  String? _country;
  String _route = 'ru';
  String _appliedRoute = 'ru';
  bool _warp = false;
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
        if (!_firstConnectDone) {
          _askFirstConnect();
        } else {
          _connect();
        }
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

  Future<void> _askFirstConnect() async {
    var choice = FirstRouteChoice.wholePhone;
    final go = await showPokrovSheet<bool>(
      context,
      (context) => StatefulBuilder(
        builder: (context, setSheet) => FirstConnectSheet(
          choice: choice,
          onChanged: (c) => setSheet(() => choice = c),
          onContinue: () => Navigator.pop(context, true),
        ),
      ),
    );
    if (go == true) {
      _firstConnectDone = true;
      _connect();
    }
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
          _push((context) => DiagnosticsScreen(
                data: PokrovSampleData.diagnostics(on: _phase == ConnectionPhase.on),
                onBack: () => Navigator.pop(context),
                onSend: () => _toast(context, 'Отчёт отправлен (макет)'),
                onCopyCode: () => _toast(context, 'Код скопирован (макет)'),
                onTechnical: () => _toast(context, 'Здесь будут технические детали (макет)'),
              ));
        },
      ),
    );
  }

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

  void _setMode(InterfaceMode mode) {
    setState(() {
      _mode = mode;
      if (mode == InterfaceMode.simple && _tab == PokrovTab.rules) _tab = PokrovTab.protection;
    });
  }

  Widget _body() {
    switch (_tab) {
      case PokrovTab.protection:
        return HomeScreen(
          data: PokrovSampleData.home(
            phase: _phase,
            mode: _mode,
            countryCode: _country,
            warp: _warp,
            routeValue: switch (_appliedRoute) { 'ru' => 'напрямую', 'all' => 'через POKROV', _ => 'по выбору' },
          ),
          adSlot: AdSlot(compact: _mode == InterfaceMode.advanced,
            child: const ColoredBox(color: Color(0xFFEAF0EC), child: Center(child: Text('Пример рекламного места')))),
          onNotifications: () => _toast(context, 'Уведомления (макет)'),
          onToggle: _toggle,
          onOpenStatus: _openStatus,
          onOpenCountry: () => setState(() => _tab = PokrovTab.locations),
          onOpenRoute: () => _mode == InterfaceMode.advanced ? setState(() => _tab = PokrovTab.rules) : _askFirstConnect(),
          onOpenAccess: _openRenew,
          onWarpChanged: (v) => setState(() => _warp = v),
          onTip: () => _toast(context, 'Откроется Telegram-канал (макет)'),
          onHelp: _openSupport,
        );
      case PokrovTab.locations:
        return LocationsScreen(
          data: LocationsViewData(mode: _mode, countries: PokrovSampleData.countries, selectedCode: _country),
          onAuto: () => setState(() => _country = null),
          onSelect: (code) => setState(() => _country = code),
          onRefresh: () => _toast(context, 'Список обновлён (макет)'),
        );
      case PokrovTab.rules:
        return RulesScreen(
          data: PokrovSampleData.rules(selected: _route, applied: _appliedRoute),
          onSelect: (id) => setState(() => _route = id),
          onApply: () {
            setState(() => _appliedRoute = _route);
            if (_phase == ConnectionPhase.on) _connect();
          },
          onWarning: () => _toast(context, 'Обновляем список… (макет)'),
        );
      case PokrovTab.profile:
        return ProfileScreen(
          data: PokrovSampleData.profile(_mode),
          onRenew: _openRenew,
          onModeChanged: _setMode,
          onHelp: _openSupport,
          onBonuses: _openBonuses,
        );
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
        mode: _mode,
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
