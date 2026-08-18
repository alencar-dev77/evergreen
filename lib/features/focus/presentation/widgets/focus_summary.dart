import 'package:flutter/widgets.dart';

import '../../../../core/design/app_metrics.dart';
import '../../data/focus_session_repository.dart';
import '../../models/focus_session.dart';
import 'focus_week_strip.dart';

/// O bloco "Tempo focado": os dois números e a semana em barras.
///
/// Sem card, sem borda, sem ícone — o que estrutura o bloco é a hierarquia
/// entre o número de hoje, o da semana e a faixa, que é tudo de que uma
/// estatística de duas medidas precisa.
class FocusSummary extends StatelessWidget {
  const FocusSummary({
    super.key,
    required this.stats,
    required this.sessions,
    this.now,
  });

  final FocusStats stats;

  /// As sessões da semana, de onde saem as sete barras. Vêm prontas da tela —
  /// são as mesmas que a lista abaixo mostra, e reler o banco para desenhar a
  /// faixa daria duas leituras da mesma coisa.
  final List<FocusSession> sessions;

  /// Injetável para o teste e para os goldens não dependerem do relógio real.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FocusTotals(today: stats.today, week: stats.week),
        const SizedBox(height: AppSpacing.xl),
        FocusWeekStrip(sessions: sessions, now: now),
      ],
    );
  }
}
