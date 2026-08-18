import 'package:flutter/widgets.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_metrics.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../shared/utils/day_groups.dart';
import '../../../../shared/utils/day_label.dart';
import '../../../../shared/utils/duration_format.dart';
import '../../../../shared/widgets/eg_hoverable.dart';
import '../../../../shared/widgets/eg_icon.dart';
import '../../../../shared/widgets/eg_section_label.dart';
import '../../../../shared/widgets/eg_surface.dart';
import '../../models/meeting.dart';

/// As reuniões gravadas, da mais recente para a mais antiga.
///
/// Mesma gramática do histórico do Focus, e de propósito: dia no grupo, hora em
/// coluna fixa à esquerda, nome no meio, duração em coluna fixa à direita. São
/// duas listas do mesmo aplicativo respondendo à mesma pergunta ("o que
/// aconteceu e quando"), e ler uma já ensina a ler a outra.
///
/// A linha é uma só, de altura fixa: a reunião abre na região ao lado, então
/// aqui não há nada para adiantar do conteúdo — só o suficiente para escolher.
class EchoMeetingList extends StatelessWidget {
  const EchoMeetingList({
    super.key,
    required this.meetings,
    required this.selectedId,
    required this.onSelect,
    required this.onToggleKept,
    this.now,
  });

  final List<Meeting> meetings;
  final int? selectedId;
  final void Function(int id) onSelect;
  final void Function(int id) onToggleKept;

  /// Injetável para o teste e para os goldens não dependerem do relógio real.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final groups = DayGroups.of(
      meetings,
      (meeting) => meeting.startedAt,
      now: now,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final group in groups) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.xxs,
            ),
            child: EgSectionLabel(group.label),
          ),
          for (final meeting in group.items)
            _MeetingRow(
              meeting: meeting,
              isSelected: meeting.id == selectedId,
              onTap: () => onSelect(meeting.id!),
              onToggleKept: () => onToggleKept(meeting.id!),
            ),
        ],
      ],
    );
  }
}

class _MeetingRow extends StatelessWidget {
  const _MeetingRow({
    required this.meeting,
    required this.isSelected,
    required this.onTap,
    required this.onToggleKept,
  });

  final Meeting meeting;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onToggleKept;

  /// As mesmas medidas da linha do histórico do Focus.
  static const _height = 34.0;
  static const _timeColumn = 44.0;
  static const _durationColumn = 64.0;

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
            width: _timeColumn,
            child: Text(
              DayLabel.time(meeting.startedAt),
              style: AppTypography.monoSmall.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ),
          Expanded(child: _label()),
          const SizedBox(width: AppSpacing.md),
          SizedBox(
            width: _durationColumn,
            child: Text(
              DurationFormat.compact(meeting.duration),
              textAlign: TextAlign.right,
              style: AppTypography.bodyCompactEmphasis,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // A estrela é o "guardar": a reunião marcada não entra na conta da
          // limpeza automática. Mesma marca do item fixado no Pin, porque é
          // exatamente a mesma ideia.
          EgHoverable(
            onTap: onToggleKept,
            builder: (context, starState) => Padding(
              padding: const EdgeInsets.all(AppSpacing.xxs),
              child: EgIcon(
                EgIconData.star,
                size: AppIconSizes.xs,
                // Terceiro nível em repouso, como o badge de atalho do Pin: ela
                // aparece em toda linha, e um chip aceso por linha competiria
                // com o nome da reunião.
                color: meeting.isKept
                    ? AppColors.greenPrimary
                    : (starState.isHovered || starState.isPressed
                          ? AppColors.textSecondary
                          : AppColors.textTertiary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// O nome da reunião e, atrás dele, o aviso de que já existe resumo — que é o
  /// que decide se vale abrir. Num parágrafo só, como na linha do Focus: o
  /// corte por ellipsis come o aviso primeiro, nunca o nome.
  Widget _label() {
    final style = AppTypography.bodyCompactEmphasis.copyWith(
      color: isSelected ? AppColors.greenLight : AppColors.textPrimary,
    );

    if (!meeting.hasSummary) {
      return Text(
        meeting.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        softWrap: false,
        style: style,
      );
    }

    return Text.rich(
      TextSpan(
        text: meeting.title,
        children: [
          TextSpan(
            text: '   resumida',
            style: AppTypography.captionXS.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
      style: style,
    );
  }
}
