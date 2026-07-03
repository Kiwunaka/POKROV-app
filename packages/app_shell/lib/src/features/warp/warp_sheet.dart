part of pokrov_app_shell;

void _showWarpConsentSheet(
  BuildContext context, {
  required PokrovWarpLifecycle lifecycle,
  required bool enabled,
  required Future<void> Function(bool value) onChanged,
}) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    sheetAnimationStyle: _pokrovSheetAnimationStyle(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => _WarpConsentSheet(
      lifecycle: lifecycle,
      enabled: enabled,
      onChanged: onChanged,
    ),
  );
}

class _WarpConsentSheet extends StatelessWidget {
  const _WarpConsentSheet({
    required this.lifecycle,
    required this.enabled,
    required this.onChanged,
  });

  final PokrovWarpLifecycle lifecycle;
  final bool enabled;
  final Future<void> Function(bool value) onChanged;

  @override
  Widget build(BuildContext context) {
    final p = PokrovPalette.of(context);
    final nextValue = !enabled;
    final ready = lifecycle.canOffer;
    final active = enabled || lifecycle.phase == PokrovWarpPhase.active;
    final useDarkPanel =
        active && Theme.of(context).brightness == Brightness.dark;
    final foreground = useDarkPanel ? Colors.white : p.ink;
    final secondary =
        useDarkPanel ? Colors.white.withValues(alpha: 0.72) : p.muted;
    final panelColor = useDarkPanel ? const Color(0xFF0A1114) : p.surface;
    final lineColor =
        useDarkPanel ? Colors.white.withValues(alpha: 0.10) : p.line;
    return SafeArea(
      top: false,
      child: Container(
        key: const ValueKey('home-warp-sheet'),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.82,
        ),
        padding: const EdgeInsets.fromLTRB(22, 6, 22, 26),
        decoration: BoxDecoration(
          color: panelColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: active
                          ? p.accent.withValues(alpha: 0.14)
                          : p.accent.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                      border: Border.all(color: lineColor),
                    ),
                    child: const Center(child: _BrandMark(size: 42)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'WARP',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                color: foreground,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0,
                              ),
                        ),
                        Text(
                          'Дополнительная защита',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: secondary,
                                    height: 1.2,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    key: const ValueKey('home-warp-consent-switch'),
                    value: enabled,
                    activeThumbColor: Colors.white,
                    activeTrackColor: p.accentBright,
                    onChanged: ready
                        ? (value) {
                            unawaited(onChanged(value));
                            Navigator.of(context).pop();
                          }
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                ready
                    ? 'Помогает со сложными сайтами'
                    : 'Недоступно на этом устройстве',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: active ? p.accent : foreground,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Помогает, если сайт открывается нестабильно или обычного VPN недостаточно.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: secondary,
                      height: 1.34,
                    ),
              ),
              const SizedBox(height: 18),
              if (ready) ...[
                Divider(color: lineColor),
                const SizedBox(height: 6),
                _WarpInfoRow(
                  icon: Icons.bolt_rounded,
                  title: 'WARP включится при следующем подключении.',
                  value: '',
                  foreground: foreground,
                  muted: secondary,
                  line: lineColor,
                ),
                _WarpInfoRow(
                  icon: Icons.undo_rounded,
                  title: 'Его можно выключить в любой момент.',
                  value: '',
                  foreground: foreground,
                  muted: secondary,
                  line: lineColor,
                ),
                _WarpInfoRow(
                  icon: Icons.info_outline_rounded,
                  title:
                      'Если сайт не откроется, POKROV вернется к обычному VPN.',
                  value: '',
                  foreground: foreground,
                  muted: secondary,
                  line: lineColor,
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: PokrovPressable(
                  child: FilledButton.icon(
                    key: const ValueKey('home-warp-enable-action'),
                    icon: ready
                        ? enabled
                            ? const Icon(Icons.shield_outlined)
                            : const Icon(Icons.verified_user_rounded)
                        : const Icon(Icons.info_outline_rounded),
                    label: Text(
                      ready
                          ? enabled
                              ? 'Выключить WARP'
                              : 'Включить WARP'
                          : 'Понятно',
                    ),
                    onPressed: () {
                      if (ready) {
                        unawaited(onChanged(nextValue));
                      }
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ),
              if (ready) ...[
                const SizedBox(height: 10),
                Center(
                  child: TextButton(
                    key: const ValueKey('home-warp-dismiss-action'),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Не сейчас'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _WarpInfoRow extends StatelessWidget {
  const _WarpInfoRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.foreground,
    required this.muted,
    required this.line,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color foreground;
  final Color muted;
  final Color line;

  @override
  Widget build(BuildContext context) {
    final p = PokrovPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: p.accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: line),
            ),
            child: Icon(icon, size: 18, color: p.accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          if (value.isNotEmpty)
            Text(
              value,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: muted,
                    fontWeight: FontWeight.w600,
                  ),
            ),
        ],
      ),
    );
  }
}
