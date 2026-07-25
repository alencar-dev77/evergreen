import 'package:flutter/widgets.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_metrics.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../shared/utils/day_label.dart';
import '../../../../shared/utils/duration_format.dart';
import '../../../../shared/widgets/eg_empty_state.dart';
import '../../../../shared/widgets/eg_hoverable.dart';
import '../../../../shared/widgets/eg_icon.dart';
import '../../models/focus_session.dart';
import 'focus_session_dialog.dart';

/// Histórico simples das sessões de foco da semana.
///
/// Uma lista, não uma tabela: os dados têm uma dimensão principal (o que foi
/// feito) e metadados ao redor dela — exatamente o caso em que `components.md`
/// manda usar lista. A linha responde "quando, quanto e em quê"; o resto
/// (anotações, resumo) mora no detalhe, a um clique ou um Enter de distância.
class FocusHistoryList extends StatelessWidget {
  const FocusHistoryList({
    super.key,
    required this.sessions,
    this.showLastDivider = false,
  });

  final List<FocusSession> sessions;

  /// Mantém o divisor na última linha quando algo vem logo abaixo da lista —
  /// sem ele, a linha seguinte pareceria mais uma sessão.
  final bool showLastDivider;

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return const EgEmptyState(
        icon: EgIconData.timer,
        title: 'Nenhuma sessão esta semana',
        message: 'As sessões concluídas aparecem aqui, com o que você anotou.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final session in sessions) ...[
          _SessionRow(session: session),
          if (showLastDivider || session != sessions.last) const _Divider(),
        ],
      ],
    );
  }
}

/// Divisor entre linhas. Separado da linha porque o fundo de hover dela tem
/// cantos arredondados — uma borda dentro dele acompanharia a curva e ficaria
/// torta sob o mouse.
class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(border: AppBorders.bottom),
      child: SizedBox(height: 0, width: double.infinity),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session});

  final FocusSession session;

  @override
  Widget build(BuildContext context) {
    return EgHoverable(
      focusable: true,
      onTap: () => FocusSessionDialog.show(context, session),
      builder: (context, state) => AnimatedContainer(
        duration: AppDurations.instant,
        curve: AppDurations.curve,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: _background(state),
          borderRadius: AppRadii.listItemAll,
          boxShadow: state.isFocused ? AppShadows.focusRing : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _title()),
                const SizedBox(width: AppSpacing.xl),
                // Duração à direita, sempre na mesma coluna: é o número que se
                // compara entre linhas ao correr o olho pela lista.
                Text(
                  DurationFormat.compact(session.duration),
                  style: AppTypography.bodyCompactEmphasis,
                ),
              ],
            ),
            if (_metadata() case final metadata?) ...[
              const SizedBox(height: AppSpacing.xxs),
              Text(
                metadata,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.captionXS.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _title() {
    return Text(
      FocusSessionDialog.titleOf(session),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: session.hasActivity
          ? AppTypography.bodyCompactEmphasis
          // Sem atividade escrita, o título é a própria data — e ela se
          // apresenta como o metadado que é.
          : AppTypography.bodyCompactEmphasis.copyWith(
              color: AppColors.textSecondary,
            ),
    );
  }

  /// A segunda linha só existe quando tem o que dizer: quando e o que mais há
  /// para ver lá dentro.
  String? _metadata() {
    final parts = <String>[
      if (session.hasActivity)
        '${DayLabel.of(session.startedAt)} · '
            '${DayLabel.time(session.startedAt)}',
      if (session.notes.isNotEmpty)
        '${session.notes.length} '
            '${session.notes.length == 1 ? 'anotação' : 'anotações'}',
      if (session.hasSummary) 'resumo',
    ];

    return parts.isEmpty ? null : parts.join(' · ');
  }

  Color _background(EgInteraction state) {
    if (state.isPressed) return AppColors.pressed;
    if (state.isHovered || state.isFocused) return AppColors.hover;
    return AppColors.transparent;
  }
}
