import 'package:flutter/widgets.dart';

import '../../../../core/design/app_metrics.dart';
import '../../../../shared/utils/day_groups.dart';
import '../../../../shared/utils/day_label.dart';
import '../../../../shared/utils/duration_format.dart';
import '../../../../shared/widgets/eg_hoverable.dart';
import '../../../../shared/widgets/eg_icon.dart';
import '../../../../shared/widgets/eg_section_label.dart';
import '../../../../shared/widgets/eg_surface.dart';
import '../../models/meeting.dart';
import '../../../../core/design/eg_tokens.dart';

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
      // A estrela é clicável e mora dentro da linha: fundir a linha numa
      // etiqueta só a engoliria junto, e guardar uma reunião deixaria de ter
      // alcance por leitor de tela.
      mergeDescendants: false,
      child: Row(
        children: [
          SizedBox(
            width: _timeColumn,
            child: Text(
              DayLabel.time(meeting.startedAt),
              style: context.eg.text.monoSmall.copyWith(
                color: context.eg.colors.textTertiary,
              ),
            ),
          ),
          Expanded(child: _label(context)),
          const SizedBox(width: AppSpacing.md),
          SizedBox(
            width: _durationColumn,
            child: Text(
              DurationFormat.compact(meeting.duration),
              textAlign: TextAlign.right,
              style: context.eg.text.bodyEmphasis,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // A estrela é o "guardar": a reunião marcada não entra na conta da
          // limpeza automática. Mesma marca do item fixado no Pin, porque é
          // exatamente a mesma ideia.
          EgHoverable(
            onTap: onToggleKept,
            // Uma estrela desenhada não diz o que faz, e o que ela decide —
            // se a reunião escapa da limpeza automática — não está escrito em
            // lugar nenhum da linha.
            semanticLabel: meeting.isKept
                ? 'Guardada, deixar de guardar'
                : 'Guardar esta reunião',
            builder: (context, starState) => Padding(
              padding: const EdgeInsets.all(AppSpacing.xxs),
              child: EgIcon(
                EgIconData.star,
                size: AppIconSizes.xs,
                // Terceiro nível em repouso, como o badge de atalho do Pin: ela
                // aparece em toda linha, e um chip aceso por linha competiria
                // com o nome da reunião.
                color: meeting.isKept
                    ? context.eg.colors.accent
                    : (starState.isHovered || starState.isPressed
                          ? context.eg.colors.textSecondary
                          : context.eg.colors.textTertiary),
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
  Widget _label(BuildContext context) {
    final style = context.eg.text.bodyEmphasis.copyWith(
      color: isSelected
          ? context.eg.colors.accentLight
          : context.eg.colors.textPrimary,
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
            style: context.eg.text.footnote.copyWith(
              color: context.eg.colors.textTertiary,
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
