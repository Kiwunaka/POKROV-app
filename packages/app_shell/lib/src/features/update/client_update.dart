import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pokrov_core_domain/core_domain.dart';

import '../../../app_first_runtime_bootstrap.dart';
import '../../design_system/design_system.dart';

enum PokrovClientUpdateInstallStatus {
  installerOpened,
  storeOpened,
  permissionRequired,
  unsupported,
  failed,
}

typedef PokrovClientUpdateInstaller = Future<PokrovClientUpdateInstallStatus>
    Function(
  ClientAppUpdateInfo update,
);

enum PokrovClientUpdateProgressPhase {
  idle,
  preparing,
  downloading,
  verifying,
  installing,
  failed,
}

class PokrovClientUpdateProgress {
  const PokrovClientUpdateProgress({
    required this.phase,
    required this.downloadedBytes,
    required this.totalBytes,
  });

  const PokrovClientUpdateProgress.idle()
      : phase = PokrovClientUpdateProgressPhase.idle,
        downloadedBytes = 0,
        totalBytes = 0;

  final PokrovClientUpdateProgressPhase phase;
  final int downloadedBytes;
  final int totalBytes;

  double? get fraction {
    if (totalBytes <= 0) {
      return null;
    }
    return (downloadedBytes / totalBytes).clamp(0.0, 1.0);
  }

  int? get percent {
    final value = fraction;
    return value == null ? null : (value * 100).round().clamp(0, 100);
  }
}

typedef PokrovClientUpdateProgressReader = Future<PokrovClientUpdateProgress>
    Function();

typedef ClientUpdateMetadataLoader = Future<ClientAppsMetadata> Function();
typedef ClientUpdatePresenter = Future<void> Function(
  ClientAppUpdateInfo update,
);
typedef ClientUpdateFailureReporter = void Function(
  Object error,
  StackTrace stackTrace,
);

/// Owns update-check concurrency, prompt visibility and release deduplication.
///
/// The shell supplies data access and lifecycle reporting. This coordinator
/// keeps the release-critical state machine independent from shell rendering.
class ClientUpdateCoordinator {
  bool _checkBusy = false;
  bool _promptVisible = false;
  String _lastPromptedUpdateKey = '';

  Future<void> checkAndPresent({
    required ClientUpdateMetadataLoader loadMetadata,
    required HostPlatform hostPlatform,
    required bool Function() isActive,
    required VoidCallback onUpdateAvailable,
    required ClientUpdatePresenter presentUpdate,
    required ClientUpdateFailureReporter onFailure,
  }) async {
    if (_checkBusy || _promptVisible) {
      return;
    }
    _checkBusy = true;
    try {
      final metadata = await loadMetadata();
      if (!isActive() || metadata.silentUpdate) {
        return;
      }
      final update = metadata.updateFor(hostPlatform);
      final promptKey =
          '${update.platform}:${update.latestVersion}:${update.updatePolicy}';
      if (!update.shouldPrompt || promptKey == _lastPromptedUpdateKey) {
        return;
      }
      onUpdateAvailable();
      _lastPromptedUpdateKey = promptKey;
      _promptVisible = true;
      try {
        await presentUpdate(update);
      } finally {
        _promptVisible = false;
      }
    } on Object catch (error, stackTrace) {
      onFailure(error, stackTrace);
    } finally {
      _checkBusy = false;
    }
  }
}

Future<void> showPokrovClientUpdatePrompt({
  required BuildContext context,
  required ClientAppUpdateInfo update,
  required VoidCallback onUpdate,
  AnimationStyle? sheetAnimationStyle,
}) {
  final title =
      update.isRequired ? 'Нужно обновить POKROV' : 'Доступно обновление';
  final version = update.latestVersion.trim();
  final notes = update.releaseNotes.trim();
  final sizeLabel = formatPokrovClientUpdateSize(update.size);

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: !update.isRequired,
    isScrollControlled: true,
    isDismissible: !update.isRequired,
    enableDrag: !update.isRequired,
    sheetAnimationStyle: sheetAnimationStyle,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) {
      final p = PokrovPalette.of(sheetContext);
      final theme = Theme.of(sheetContext);
      return SafeArea(
        top: false,
        child: Container(
          key: const ValueKey('client-update-prompt'),
          width: double.infinity,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.82,
          ),
          padding: EdgeInsets.fromLTRB(
            22,
            update.isRequired ? 22 : 6,
            22,
            26,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: p.accent.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.system_update_alt_rounded,
                        color: p.accent,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Text(
                        title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: p.ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  version.isEmpty
                      ? 'Установите свежую версию, чтобы получить исправления и актуальные правила.'
                      : 'Свежая версия: $version.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: p.muted,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Официальный канал POKROV · $sizeLabel',
                  key: const ValueKey('client-update-source-size'),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: p.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    notes,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: p.muted,
                      height: 1.35,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: PokrovPressable(
                    child: FilledButton.icon(
                      key: const ValueKey('client-update-download'),
                      icon: const Icon(Icons.system_update_alt_rounded),
                      label: const Text('Обновить'),
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        onUpdate();
                      },
                    ),
                  ),
                ),
                if (!update.isRequired) ...[
                  const SizedBox(height: 10),
                  Center(
                    child: TextButton(
                      key: const ValueKey('client-update-later'),
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      child: const Text('Позже'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}

String formatPokrovClientUpdateSize(int bytes) {
  final safeBytes = bytes.clamp(1, 256 * 1024 * 1024);
  if (safeBytes < 1024 * 1024) {
    return '${(safeBytes / 1024).ceil()} КБ';
  }
  final megabytes = safeBytes / (1024 * 1024);
  final text = megabytes >= 10
      ? megabytes.toStringAsFixed(0)
      : megabytes.toStringAsFixed(1).replaceFirst('.', ',');
  return '$text МБ';
}

class PokrovClientUpdateProgressDialog extends StatelessWidget {
  const PokrovClientUpdateProgressDialog({
    required this.progress,
    super.key,
  });

  final ValueListenable<PokrovClientUpdateProgress> progress;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const ValueKey('client-update-download-progress'),
      title: const Text('Обновление POKROV'),
      content: SizedBox(
        width: 320,
        child: ValueListenableBuilder<PokrovClientUpdateProgress>(
          valueListenable: progress,
          builder: (context, value, _) {
            final percent = value.percent;
            final label = switch (value.phase) {
              PokrovClientUpdateProgressPhase.downloading =>
                percent == null ? 'Скачиваем обновление…' : 'Скачано $percent%',
              PokrovClientUpdateProgressPhase.verifying =>
                'Проверяем размер и целостность файла…',
              PokrovClientUpdateProgressPhase.installing =>
                'Открываем установку…',
              PokrovClientUpdateProgressPhase.failed =>
                'Не удалось завершить загрузку.',
              PokrovClientUpdateProgressPhase.idle ||
              PokrovClientUpdateProgressPhase.preparing =>
                'Подготавливаем защищённую загрузку…',
            };
            final barValue =
                value.phase == PokrovClientUpdateProgressPhase.downloading
                    ? value.fraction
                    : value.phase == PokrovClientUpdateProgressPhase.installing
                        ? 1.0
                        : null;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(
                  key: const ValueKey('client-update-progress-bar'),
                  value: barValue,
                  minHeight: 7,
                  borderRadius: BorderRadius.circular(999),
                ),
                const SizedBox(height: 12),
                Text(
                  label,
                  key: const ValueKey('client-update-progress-label'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
