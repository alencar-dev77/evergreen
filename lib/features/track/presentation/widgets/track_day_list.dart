import 'package:flutter/widgets.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_metrics.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../shared/utils/day_label.dart';
import '../../../../shared/utils/duration_format.dart';
import '../../../../shared/widgets/eg_surface.dart';
import '../../models/track_day.dart';

/// Os dias do recorte, um por linha.
///
/// Uma lista, e não uma tabela: a dimensão principal é o dia, e o resto são
/// metadados ao redor. A linha responde "que dia, o que teve e quanto"; o dia
/// aberto se lê na região que abre ao lado, a um clique de distância — o mesmo
/// caminho do histórico do Focus e da biblioteca do Echo.
///
/// Sem rótulo de grupo por cima: aqui a linha **é** o dia, e um cabeçalho de
/// data acima de uma linha de data seria a mesma informação duas vezes.
class TrackDayList extends StatelessWidget {
  const TrackDayList({
    super.key,
    required this.days,
    required this.onOpen,
    this.selectedDate,
    this.now,
  });

  final List<TrackDay> days;

  /// Escolhe o dia e abre a região de leitura — as duas coisas são o mesmo
  /// gesto, porque um dia selecionado e fechado não serve para nada.
  final void Function(DateTime date) onOpen;

  /// O dia aberto na região, que a lista marca como selecionado: sem isso, a
  /// coluna ao lado mostra um conteúdo que nada na lista reivindica.
  final DateTime? selectedDate;

  /// Injetável para o teste e para os goldens não dependerem do relógio real.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final day in days)
          _DayRow(
            day: day,
            isSelected: day.date == selectedDate,
            now: now,
            onTap: () => onOpen(day.date),
          ),
      ],
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.day,
    required this.isSelected,
    required this.onTap,
    this.now,
  });

  final TrackDay day;
  final bool isSelected;
  final VoidCallback onTap;
  final DateTime? now;

  /// Altura fixa, como a linha do Pin e a do histórico do Focus: é o que mantém
  /// a coluna da direita legível quando se corre o olho por ela.
  static const _height = 34.0;

  /// Coluna do dia. Larga o bastante para `Ontem` e para `23 ago`.
  static const _dayColumn = 64.0;

  /// Coluna do tempo. Fixa, e não encolhida ao conteúdo, porque é ela que
  /// permite comparar os dias correndo o olho por uma coluna só.
  static const _timeColumn = 64.0;

  @override
  Widget build(BuildContext context) {
    return EgInteractiveSurface(
      onTap: onTap,
      isSelected: isSelected,
      height: _height,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Row(
        children: [
          SizedBox(
            width: _dayColumn,
            child: Text(
              DayLabel.of(day.date, now: now),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: day.isEmpty
                  ? AppTypography.bodyCompactEmphasis.copyWith(
                      color: AppColors.textSecondary,
                    )
                  : AppTypography.bodyCompactEmphasis,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              // Um dia vazio diz que está vazio, em vez de deixar a linha muda:
              // é a diferença entre "não houve nada" e "o módulo não leu nada".
              day.isEmpty ? 'Nada registrado' : day.highlights.join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: AppTypography.captionXS.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          // Tempo registrado à direita, sempre na mesma coluna — o mesmo número
          // que a altura da barra da semana desenha.
          SizedBox(
            width: _timeColumn,
            child: Text(
              day.registered == Duration.zero
                  ? '—'
                  : DurationFormat.compact(day.registered),
              textAlign: TextAlign.right,
              style: day.registered == Duration.zero
                  ? AppTypography.bodyCompactEmphasis.copyWith(
                      color: AppColors.textTertiary,
                    )
                  : AppTypography.bodyCompactEmphasis,
            ),
          ),
        ],
      ),
    );
  }
}
