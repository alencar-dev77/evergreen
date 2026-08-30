import 'package:flutter/widgets.dart';

import '../../../../shared/utils/day_bounds.dart';
import '../../../../shared/utils/day_label.dart';
import '../../../../shared/utils/duration_format.dart';
import '../../../../shared/widgets/eg_day_bars.dart';
import '../../models/focus_session.dart';
import '../../../../core/design/eg_tokens.dart';

/// O foco de cada dia da semana, em sete barras.
///
/// A faixa em si é a [EgDayBars] — o que este widget faz é a conta que só o
/// Focus sabe fazer: somar as sessões dia a dia.
///
/// A semana começa na segunda porque é onde o histórico do Focus vira
/// (`trimToCurrentWeek`): uma faixa que mostrasse sete dias corridos exibiria
/// tempo que a lista abaixo já não tem mais.
class FocusWeekStrip extends StatelessWidget {
  const FocusWeekStrip({super.key, required this.sessions, this.now});

  final List<FocusSession> sessions;

  /// Injetável para o teste e para os goldens não dependerem do relógio real.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final today = now ?? DateTime.now();

    return EgDayBars(
      values: _totals(today),
      labels: DayLabel.weekdays,
      highlight: today.weekday - 1,
    );
  }

  /// Sete baldes de segunda a domingo, somando as sessões de cada dia.
  List<Duration> _totals(DateTime today) {
    final monday = DayBounds.startOfWeek(today);
    final totals = List.filled(DayLabel.weekdays.length, Duration.zero);

    for (final session in sessions) {
      final day = DayBounds.daysBetween(monday, session.startedAt);
      if (day < 0 || day >= totals.length) continue;

      totals[day] += session.duration;
    }

    return totals;
  }
}

/// O rótulo da faixa: o número de hoje em destaque e o da semana ao lado.
///
/// Numa linha só, e não em duas colunas de números do mesmo tamanho: os dois
/// respondem perguntas diferentes ("como está hoje" e "como está a semana"), e
/// dar o mesmo peso aos dois obriga a ler os dois para achar o que se queria.
///
/// Um parágrafo, e não um `Row` de textos: assim os tamanhos diferentes se
/// alinham pela linha de base sozinhos, e numa janela estreita a frase **quebra
/// em duas linhas** em vez de estourar o layout — foi exatamente o que
/// aconteceu com a versão em `Row` na largura mínima da janela.
class FocusTotals extends StatelessWidget {
  const FocusTotals({super.key, required this.today, required this.week});

  final Duration today;
  final Duration week;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: DurationFormat.compact(today),
            style: context.eg.text.display,
          ),
          TextSpan(text: '  hoje', style: context.eg.text.footnote),
          TextSpan(text: '   ·   ', style: context.eg.text.footnote),
          TextSpan(
            text: DurationFormat.compact(week),
            style: context.eg.text.bodyEmphasis,
          ),
          TextSpan(text: '  na semana', style: context.eg.text.footnote),
        ],
      ),
    );
  }
}
