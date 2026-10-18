import 'package:flutter/material.dart';

import 'models.dart';
import 'tokens.dart';
import 'widgets.dart';

/// «Для поддержки»: a human summary, four plain checks, the masked support
/// code and one send button. Raw evidence stays behind [onTechnical].
class DiagnosticsScreen extends StatelessWidget {
  const DiagnosticsScreen({super.key, required this.data, required this.onBack, required this.onSend, this.onCopyCode, this.onTechnical});

  final DiagnosticsViewData data;
  final VoidCallback onBack;
  final VoidCallback onSend;
  final VoidCallback? onCopyCode;
  final VoidCallback? onTechnical;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            ScreenHeader(title: 'Для поддержки', onBack: onBack),
            const SizedBox(height: 14),
            data.healthy
                ? PokrovCard(
                    color: PokrovColors.accentSoft,
                    borderColor: Colors.transparent,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(data.headline, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: PokrovColors.accentText)),
                        const SizedBox(height: 6),
                        Text(data.body, style: const TextStyle(fontSize: 14, height: 1.45, color: PokrovColors.accentText)),
                      ],
                    ),
                  )
                : WarnCard(title: data.headline, body: data.body),
            const SizedBox(height: 12),
            PokrovCard(
              child: Column(
                children: [
                  for (final (i, row) in data.rows.indexed)
                    Container(
                      constraints: const BoxConstraints(minHeight: 52),
                      decoration: BoxDecoration(border: i < data.rows.length - 1 ? const Border(bottom: BorderSide(color: PokrovColors.line)) : null),
                      child: Row(
                        children: [
                          Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: switch (row.tone) {
                                DiagnosticTone.ok => PokrovColors.connected,
                                DiagnosticTone.attention => PokrovColors.warnDot,
                                DiagnosticTone.pending => const Color(0xFFC9D0CC),
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Text(row.title, style: const TextStyle(fontSize: 16))),
                          Text(
                            row.value,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: row.tone == DiagnosticTone.attention ? PokrovColors.warnStrong : PokrovColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            PokrovCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Код для поддержки', style: PokrovText.caption),
                        Text(data.supportCode, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: onCopyCode,
                    style: TextButton.styleFrom(backgroundColor: PokrovColors.chip, foregroundColor: PokrovColors.ink, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: const Text('Скопировать'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            PrimaryButton(label: 'Отправить отчёт в поддержку', onPressed: onSend, height: 54),
            Center(child: LinkButton(label: 'Технические детали ›', onPressed: onTechnical, color: PokrovColors.soft)),
          ],
        ),
      ),
    );
  }
}
