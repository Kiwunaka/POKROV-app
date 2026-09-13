import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

/// Covers hidden startup before Windows delivers a Flutter lifecycle event.
class PokrovWindowsActivityGate extends StatefulWidget {
  const PokrovWindowsActivityGate({required this.child, super.key});

  final Widget child;

  @override
  State<PokrovWindowsActivityGate> createState() =>
      _PokrovWindowsActivityGateState();
}

class _PokrovWindowsActivityGateState extends State<PokrovWindowsActivityGate>
    with WindowListener {
  bool _active = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    unawaited(_refreshActivity());
  }

  Future<void> _refreshActivity() async {
    final generation = ++_generation;
    final active =
        await windowManager.isVisible() && await windowManager.isFocused();
    if (mounted && generation == _generation) {
      _setActive(active);
    }
  }

  void _setActive(bool active) {
    if (_active != active) setState(() => _active = active);
  }

  @override
  void onWindowEvent(String eventName) {
    switch (eventName) {
      case 'show':
      case kWindowEventFocus:
      case kWindowEventRestore:
        unawaited(_refreshActivity());
        break;
      case 'hide':
      case kWindowEventBlur:
      case kWindowEventMinimize:
        // A late native query must not reactivate an already hidden window.
        _generation++;
        _setActive(false);
        break;
    }
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      TickerMode(enabled: _active, child: widget.child);
}
