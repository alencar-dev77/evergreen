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

/// A coluna das reuniões gravadas, da mais recente para a mais antiga.
///
/// É a metade esquerda da biblioteca: aqui se escolhe, e ao lado se lê. Linha
/// de duas linhas — título e metadado — porque numa coluna estreita o nome da
/// reunião já ocupa a largura toda, e espremer hora e duração na mesma linha
/// deixaria as três coisas ilegíveis.
///
/// O dia é do grupo, não da linha: a linha fica com a hora, que é o que
/// distingue uma reunião da outra dentro do mesmo dia.
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

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        for (final group in groups) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
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

  @override
  Widget build(BuildContext context) {
    return EgInteractiveSurface(
      onTap: onTap,
      isSelected: isSelected,
      margin: const EdgeInsets.only(bottom: AppSpacing.xxs),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meeting.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyCompactEmphasis.copyWith(
                    color: isSelected
                        ? AppColors.greenLight
                        : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.hairline),
                Text(
                  _metadata(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.captionXS,
                ),
              ],
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
                // Terceiro nível em repouso, como o badge de atalho do Pin:
                // ela aparece em toda linha, e um chip aceso por linha
                // competiria com o título.
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

  /// Hora e duração, que é o que distingue duas reuniões do mesmo dia — mais o
  /// aviso de que já existe resumo, que é o que decide se vale abrir.
  String _metadata() {
    final parts = <String>[
      DayLabel.time(meeting.startedAt),
      DurationFormat.compact(meeting.duration),
      if (meeting.hasSummary) 'resumida',
    ];

    return parts.join(' · ');
  }
}
