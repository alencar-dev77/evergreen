import 'package:flutter/widgets.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_metrics.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../shared/utils/duration_format.dart';
import '../../models/focus_session.dart';

/// O foco de cada dia da semana, em sete barras.
///
/// Dois números dizem quanto; eles não dizem **se a semana está indo**. A faixa
/// responde de relance a pergunta que quem abre o módulo realmente tem — "estou
/// mantendo o ritmo?" — sem virar dashboard: são sete barras de 24px, sem eixo,
/// sem grade, sem legenda de valor. Quem quer precisão lê o número acima.
///
/// A semana começa na segunda porque é onde o histórico do Focus vira
/// (`trimToCurrentWeek`): uma faixa que mostrasse sete dias corridos exibiria
/// tempo que a lista abaixo já não tem mais.
///
/// Accent só no dia de hoje. É a única cor da faixa e ela significa uma coisa
/// só: onde você está na semana. Os outros dias são neutros — inclusive os
/// cheios, porque "quanto" já está na altura da barra.
class FocusWeekStrip extends StatelessWidget {
  const FocusWeekStrip({super.key, required this.sessions, this.now});

  final List<FocusSession> sessions;

  /// Injetável para o teste e para os goldens não dependerem do relógio real.
  final DateTime? now;

  /// Barra estreita de propósito: em 24px de largura por 32 de altura, um dia
  /// cheio sozinho na semana vira um quadrado verde, que se lê como bloco e
  /// não como barra.
  static const _barWidth = 14.0;
  static const _barGap = AppSpacing.md;
  static const _trackHeight = 32.0;

  /// O toco que um dia sem foco deixa. Sem ele o dia vazio some, e a faixa
  /// deixa de ser uma semana para virar um punhado de barras soltas.
  static const _emptyBarHeight = 3.0;

  static const _labels = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];

  @override
  Widget build(BuildContext context) {
    final today = now ?? DateTime.now();
    final totals = _totals(today);
    final longest = totals.fold(Duration.zero, _longer);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var day = 0; day < _labels.length; day++) ...[
          if (day > 0) const SizedBox(width: _barGap),
          _Day(
            label: _labels[day],
            total: totals[day],
            longest: longest,
            isToday: day == today.weekday - 1,
          ),
        ],
      ],
    );
  }

  /// Sete baldes de segunda a domingo, somando as sessões de cada dia.
  List<Duration> _totals(DateTime today) {
    final monday = DateTime(today.year, today.month, today.day)
        .subtract(Duration(days: today.weekday - 1));
    final totals = List.filled(_labels.length, Duration.zero);

    for (final session in sessions) {
      final start = session.startedAt;
      final day = DateTime(start.year, start.month, start.day)
          .difference(monday)
          .inDays;
      if (day < 0 || day >= totals.length) continue;

      totals[day] += session.duration;
    }

    return totals;
  }

  static Duration _longer(Duration a, Duration b) => a >= b ? a : b;
}

class _Day extends StatelessWidget {
  const _Day({
    required this.label,
    required this.total,
    required this.longest,
    required this.isToday,
  });

  final Duration total;
  final Duration longest;
  final String label;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // A altura é proporcional ao dia mais cheio da semana, e não a uma meta
        // fixa: o Focus não pergunta quanto você pretende focar, então não tem
        // como desenhar uma régua que signifique alguma coisa.
        SizedBox(
          width: FocusWeekStrip._barWidth,
          height: FocusWeekStrip._trackHeight,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: _height,
              decoration: BoxDecoration(
                color: _color,
                borderRadius: AppRadii.badgeSmallAll,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          label,
          style: AppTypography.captionXS.copyWith(
            color: isToday ? AppColors.textSecondary : AppColors.textTertiary,
          ),
        ),
      ],
    );
  }

  double get _height {
    if (total == Duration.zero || longest == Duration.zero) {
      return FocusWeekStrip._emptyBarHeight;
    }

    final ratio = total.inSeconds / longest.inSeconds;
    return (FocusWeekStrip._trackHeight * ratio)
        .clamp(FocusWeekStrip._emptyBarHeight, FocusWeekStrip._trackHeight);
  }

  Color get _color {
    if (isToday) return AppColors.greenPrimary;
    return total == Duration.zero ? AppColors.border : AppColors.textTertiary;
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
            style: AppTypography.screenTitle,
          ),
          TextSpan(text: '  hoje', style: AppTypography.captionXS),
          TextSpan(text: '   ·   ', style: AppTypography.captionXS),
          TextSpan(
            text: DurationFormat.compact(week),
            style: AppTypography.bodyEmphasis,
          ),
          TextSpan(text: '  na semana', style: AppTypography.captionXS),
        ],
      ),
    );
  }
}
