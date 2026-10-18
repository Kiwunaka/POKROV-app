import 'package:flutter/material.dart';

import 'models.dart';
import 'tokens.dart';
import 'widgets.dart';

/// «Для поддержки»: a human summary, four plain checks, the masked support
/// code and one send button. Raw evidence stays behind [onTechnical].
class DiagnosticsScreen extends StatelessWidget {
  const DiagnosticsScreen({super.key, required this.data, required this.onBack, required this.onSend, this.onCopyCode, this.onTechnical, this.onRefresh});

  final DiagnosticsViewData data;
  final VoidCallback onBack;
  final VoidCallback? onSend;
  final VoidCallback? onCopyCode;
  final VoidCallback? onTechnical;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            ScreenHeader(title: 'Для поддержки', onBack: onBack),
            if (onRefresh != null) Align(alignment: Alignment.centerRight, child: IconButton(key: ValueKey('diagnostics-refresh-action'), tooltip: 'Обновить проверку', onPressed: onRefresh, icon: Icon(Icons.refresh_rounded))),
            SizedBox(height: 14),
            data.healthy
                ? PokrovCard(
                    color: pokrovColor(context, PokrovColors.accentSoft),
                    borderColor: Colors.transparent,
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(data.headline, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: pokrovColor(context, PokrovColors.accentText))),
                        SizedBox(height: 6),
                        Text(data.body, style: TextStyle(fontSize: 14, height: 1.45, color: pokrovColor(context, PokrovColors.accentText))),
                      ],
                    ),
                  )
                : WarnCard(title: data.headline, body: data.body),
            SizedBox(height: 12),
            PokrovCard(
              child: Column(
                children: [
                  for (final (i, row) in data.rows.indexed)
                    Container(
                      constraints: BoxConstraints(minHeight: 52),
                      decoration: BoxDecoration(border: i < data.rows.length - 1 ? Border(bottom: BorderSide(color: pokrovColor(context, PokrovColors.line))) : null),
                      child: Row(
                        children: [
                          Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: switch (row.tone) {
                                DiagnosticTone.ok => pokrovColor(context, PokrovColors.connected),
                                DiagnosticTone.attention => pokrovColor(context, PokrovColors.warnDot),
                                DiagnosticTone.pending => Color(0xFFC9D0CC),
                              },
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(child: Text(row.title, style: TextStyle(fontSize: 16))),
                          Text(
                            row.value,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: row.tone == DiagnosticTone.attention ? pokrovColor(context, PokrovColors.warnStrong) : pokrovColor(context, PokrovColors.muted),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: 12),
            if (data.supportCode.isNotEmpty) PokrovCard(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Код для поддержки', style: pokrovTextStyle(context, PokrovText.caption)),
                        Text(data.supportCode, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
                      ],
                    ),
                  ),
                  if (onCopyCode != null) TextButton(
                    onPressed: onCopyCode,
                    style: TextButton.styleFrom(backgroundColor: pokrovColor(context, PokrovColors.chip), foregroundColor: pokrovColor(context, PokrovColors.ink), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: Text('Скопировать'),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            if (onSend != null) PrimaryButton(label: 'Отправить отчёт в поддержку', onPressed: onSend, height: 54),
            if (onTechnical != null) Center(child: LinkButton(key: ValueKey('diagnostics-technical-details'), label: 'Технические детали ›', onPressed: onTechnical, color: pokrovColor(context, PokrovColors.soft))),
          ],
        ),
      ),
    );
  }
}
