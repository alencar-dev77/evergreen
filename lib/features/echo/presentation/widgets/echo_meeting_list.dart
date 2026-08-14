import 'package:flutter/widgets.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_metrics.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../shared/utils/day_label.dart';
import '../../../../shared/utils/duration_format.dart';
import '../../../../shared/widgets/eg_empty_state.dart';
import '../../../../shared/widgets/eg_hoverable.dart';
import '../../../../shared/widgets/eg_icon.dart';
import '../../models/meeting.dart';

/// As reuniões gravadas, da mais recente para a mais antiga.
///
/// Lista, e não tabela: a dimensão principal é o assunto da reunião, e o resto
/// (quando, quanto tempo) são metadados ao redor dela. A transcrição fica no
/// detalhe, logo abaixo — não numa janela à parte, porque ler a transcrição é
/// o motivo de a pessoa estar nesta tela.
class EchoMeetingList extends StatelessWidget {
  const EchoMeetingList({
    super.key,
    required this.meetings,
    required this.selectedId,
    required this.onSelect,
    required this.onToggleKept,
  });

  final List<Meeting> meetings;
  final int? selectedId;
  final void Function(int id) onSelect;
  final void Function(int id) onToggleKept;

  @override
  Widget build(BuildContext context) {
    if (meetings.isEmpty) {
      return const EgEmptyState(
        icon: EgIconData.microphone,
        title: 'Nenhuma reunião gravada',
        message:
            'Aperte ⌘⇧E antes da próxima reunião. A transcrição aparece aqui '
            'quando ela terminar.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final meeting in meetings)
          _MeetingRow(
            meeting: meeting,
            isSelected: meeting.id == selectedId,
            onTap: () => onSelect(meeting.id!),
            onToggleKept: () => onToggleKept(meeting.id!),
          ),
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

  @override
  Widget build(BuildContext context) {
    return EgHoverable(
      focusable: true,
      onTap: onTap,
      builder: (context, state) => AnimatedContainer(
        duration: AppDurations.instant,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.selection
              : (state.isHovered ? AppColors.hover : AppColors.transparent),
          borderRadius: AppRadii.listItemAll,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meeting.title,
                    style: AppTypography.bodyCompact,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    '${DayLabel.of(meeting.startedAt)}, ${DayLabel.time(meeting.startedAt)} · '
                    '${DurationFormat.compact(meeting.duration)}'
                    '${meeting.hasSummary ? ' · resumida' : ''}',
                    style: AppTypography.captionXS,
                  ),
                ],
              ),
            ),
            // A estrela é o "guardar": a reunião marcada não entra na conta da
            // limpeza automática. Mesma marca do item fixado no Pin, porque é
            // exatamente a mesma ideia.
            EgHoverable(
              onTap: onToggleKept,
              builder: (context, starState) => Padding(
                padding: const EdgeInsets.all(AppSpacing.xs),
                child: EgIcon(
                  EgIconData.star,
                  size: 13,
                  color: meeting.isKept
                      ? AppColors.greenPrimary
                      : (starState.isHovered
                            ? AppColors.textSecondary
                            : AppColors.textTertiary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
