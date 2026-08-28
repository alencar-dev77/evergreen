import 'package:flutter/widgets.dart';

import '../../core/design/app_metrics.dart';
import '../../core/design/eg_tokens.dart';

/// Uma faixa de barras, uma por dia, com o rótulo do dia embaixo.
///
/// Dois números dizem *quanto*; eles não dizem **se a semana está indo**. A
/// faixa responde de relance a pergunta que quem abre o módulo realmente tem —
/// "estou mantendo o ritmo?" — sem virar dashboard: barras estreitas, sem eixo,
/// sem grade, sem legenda de valor. Quem quer precisão lê o número acima.
///
/// A altura é proporcional ao **dia mais cheio da faixa**, e não a uma meta
/// fixa: nem o Focus nem o Track perguntam quanto você pretende trabalhar,
/// então não há régua que signifique alguma coisa.
///
/// Accent só no dia destacado ([highlight], que é sempre hoje em quem a usa).
/// É a única cor da faixa e ela significa uma coisa só: onde você está na
/// semana. Os outros dias são neutros — inclusive os cheios, porque "quanto" já
/// está na altura da barra.
///
/// Vive em `shared/` porque a mesma faixa é a semana do Focus e a semana do
/// Track, medindo coisas diferentes: duas cópias divergiriam na primeira vez
/// que alguém acertasse a altura de uma delas.
class EgDayBars extends StatelessWidget {
  const EgDayBars({
    super.key,
    required this.values,
    required this.labels,
    this.highlight,
  }) : assert(values.length == labels.length, 'Um rótulo por barra.');

  /// O total de cada dia, na ordem em que as barras são desenhadas.
  final List<Duration> values;

  /// O rótulo sob cada barra — `seg`, `ter`, `qua`…
  final List<String> labels;

  /// Índice do dia em accent, ou `null` quando nenhum deles é hoje.
  final int? highlight;

  /// Barra estreita de propósito: em 24px de largura por 32 de altura, um dia
  /// cheio sozinho na semana vira um quadrado verde, que se lê como bloco e
  /// não como barra.
  static const barWidth = 14.0;
  static const barGap = AppSpacing.md;
  static const trackHeight = 32.0;

  /// O toco que um dia sem nada deixa. Sem ele o dia vazio some, e a faixa
  /// deixa de ser uma semana para virar um punhado de barras soltas.
  static const emptyBarHeight = 3.0;

  @override
  Widget build(BuildContext context) {
    final longest = values.fold(Duration.zero, _longer);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var day = 0; day < labels.length; day++) ...[
          if (day > 0) const SizedBox(width: barGap),
          _Bar(
            label: labels[day],
            total: values[day],
            longest: longest,
            isHighlighted: day == highlight,
          ),
        ],
      ],
    );
  }

  static Duration _longer(Duration a, Duration b) => a >= b ? a : b;
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.label,
    required this.total,
    required this.longest,
    required this.isHighlighted,
  });

  final Duration total;
  final Duration longest;
  final String label;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: EgDayBars.barWidth,
          height: EgDayBars.trackHeight,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: _height,
              decoration: BoxDecoration(
                color: _colorOf(context),
                borderRadius: context.eg.shapes.smallAll,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          label,
          style: context.eg.text.captionXS.copyWith(
            color: isHighlighted
                ? context.eg.colors.textSecondary
                : context.eg.colors.textTertiary,
          ),
        ),
      ],
    );
  }

  double get _height {
    if (total == Duration.zero || longest == Duration.zero) {
      return EgDayBars.emptyBarHeight;
    }

    final ratio = total.inSeconds / longest.inSeconds;
    return (EgDayBars.trackHeight * ratio).clamp(
      EgDayBars.emptyBarHeight,
      EgDayBars.trackHeight,
    );
  }

  Color _colorOf(BuildContext context) {
    if (isHighlighted) return context.eg.colors.accent;

    return total == Duration.zero
        ? context.eg.colors.border
        : context.eg.colors.textTertiary;
  }
}
