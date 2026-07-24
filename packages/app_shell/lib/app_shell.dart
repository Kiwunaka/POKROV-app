library pokrov_app_shell;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart'
    show
        CupertinoActivityIndicator,
        CupertinoSliverRefreshControl,
        RefreshIndicatorMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pokrov_core_domain/core_domain.dart';
import 'package:pokrov_platform_contracts/platform_contracts.dart';
import 'package:pokrov_runtime_engine/runtime_engine.dart';
import 'package:pokrov_support_context/support_context.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_first_runtime_bootstrap.dart';
import 'client_routing_preferences.dart';
import 'src/assistant/pokrov_ai_assistant.dart';
import 'src/design_system/design_system.dart';
import 'src/warp/pokrov_warp_lifecycle.dart';
export 'app_first_runtime_bootstrap.dart';
export 'client_routing_preferences.dart';
part 'app_shell_ui_helpers.dart';

part 'src/seed/seed_context.dart';
part 'src/shell/seed_shell.dart';
part 'src/shell/navigation_shell.dart';
part 'src/shared/info_sheet.dart';
part 'src/features/support/support_chat.dart';
part 'src/shared/shell_widgets.dart';
part 'src/shared/ru_plural.dart';
part 'src/shared/pokrov_haptics.dart';
part 'src/shared/pokrov_snack.dart';
part 'src/shared/client_experience_store.dart';
part 'src/shared/system_network_controls.dart';

part 'src/features/onboarding/onboarding_flow.dart';
part 'src/features/home/home_surface.dart';
part 'src/features/home/protection_center.dart';
part 'src/features/locations/locations_surface.dart';
part 'src/features/locations/location_labels.dart';
part 'src/features/profile/profile_surface.dart';
part 'src/features/profile/profile_sheets.dart';
part 'src/features/profile/access_labels.dart';
part 'src/features/rewards/rewards_hub.dart';
part 'src/features/rules/rules_surface.dart';
part 'src/features/rules/routing_controls.dart';
part 'src/features/rules/rules_helpers.dart';
part 'src/features/rules/route_labels.dart';
part 'src/features/warp/warp_sheet.dart';

enum SeedTab {
  protection,
  locations,
  rules,
  profile,
}

class _SelectSeedTabIntent extends Intent {
  const _SelectSeedTabIntent(this.tab);

  final SeedTab tab;
}

class _FocusSupportComposerIntent extends Intent {
  const _FocusSupportComposerIntent();
}

class _SendSupportMessageIntent extends Intent {
  const _SendSupportMessageIntent();
}

enum _SectionTone {
  accent,
  muted,
  neutral,
  reward,
}

enum _FirstLaunchStep {
  choice,
  restore,
  ready,
}

typedef ExternalHandoffLauncher = Future<bool> Function(Uri uri);

abstract class PokrovFirstLaunchStore {
  Future<bool> isCompleted();
  Future<void> markCompleted();
}

class PokrovFileFirstLaunchStore implements PokrovFirstLaunchStore {
  const PokrovFileFirstLaunchStore();

  static const _fileName = 'pokrov-first-launch-state.txt';
  static const _completedMarker = 'completed';

  Future<File> _stateFile() async {
    final directory = await getApplicationSupportDirectory();
    await directory.create(recursive: true);
    return File('${directory.path}${Platform.pathSeparator}$_fileName');
  }

  @override
  Future<bool> isCompleted() async {
    final file = await _stateFile();
    if (!await file.exists()) {
      return false;
    }
    return (await file.readAsString()).trim() == _completedMarker;
  }

  @override
  Future<void> markCompleted() async {
    final file = await _stateFile();
    await file.writeAsString(_completedMarker, flush: true);
  }
}

/// Persists the explicit theme choice in app support (pokrov-clear wave 3).
/// Best-effort by design: storage failures never break the shell, and the
/// default stays [ThemeMode.system].
class PokrovFileThemeModeStore {
  const PokrovFileThemeModeStore();

  static const _fileName = 'pokrov-theme-mode.txt';

  Future<File> _stateFile() async {
    final directory = await getApplicationSupportDirectory();
    await directory.create(recursive: true);
    return File('${directory.path}${Platform.pathSeparator}$_fileName');
  }

  Future<ThemeMode> read() async {
    try {
      final file = await _stateFile();
      if (!await file.exists()) {
        return ThemeMode.system;
      }
      return switch ((await file.readAsString()).trim()) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
    } catch (_) {
      return ThemeMode.system;
    }
  }

  Future<void> write(ThemeMode mode) async {
    try {
      final file = await _stateFile();
      await file.writeAsString(mode.name, flush: true);
    } catch (_) {
      // Best-effort persistence only.
    }
  }
}

/// Persists the one-time "first connection" hint dismissal on the home disc.
/// Best-effort by design: storage failures never break the shell — the hint
/// simply shows again until the done marker can be written.
class PokrovFileConnectHintStore {
  const PokrovFileConnectHintStore();

  static const _fileName = 'pokrov-connect-hint-state.txt';
  static const _doneMarker = 'done';

  Future<File> _stateFile() async {
    final directory = await getApplicationSupportDirectory();
    await directory.create(recursive: true);
    return File('${directory.path}${Platform.pathSeparator}$_fileName');
  }

  Future<bool> isCompleted() async {
    try {
      final file = await _stateFile();
      if (!await file.exists()) {
        return false;
      }
      return (await file.readAsString()).trim() == _doneMarker;
    } catch (_) {
      return false;
    }
  }

  Future<void> markCompleted() async {
    try {
      final file = await _stateFile();
      await file.writeAsString(_doneMarker, flush: true);
    } catch (_) {
      // Best-effort persistence only.
    }
  }
}

const _pokrovBrandMarkAsset = PokrovBrandAssets.mark;
const _selectedAppsEnforcementReady = true;
const _pokrovAppVersion = '1.0.0-beta.4';
const _seedRulesetVersion = '2026-04-13';
const _seedPackageCatalogVersion = '2026-04-13';

abstract final class _MotionTokens {
  static const short = PokrovMotionTokens.short;
  static const standard = PokrovMotionTokens.standard;
  static const sheet = PokrovMotionTokens.sheet;
  static const homeReveal = PokrovMotionTokens.homeReveal;
  static const ease = PokrovMotionTokens.ease;
  static const emphasized = PokrovMotionTokens.emphasized;
}

// Class alias, not a subclass: `dependOnInheritedWidgetOfExactType` matches
// the widget's exact runtime type, so a private subclass would make
// `PokrovMotionScope.of` fall back to "animations enabled" and silently
// ignore the platform reduced-motion setting.
typedef _MotionScope = PokrovMotionScope;
