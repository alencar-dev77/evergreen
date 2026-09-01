import 'package:flutter/widgets.dart';

import '../../../../core/design/app_metrics.dart';
import '../../../../shared/utils/day_groups.dart';
import '../../../../shared/utils/day_label.dart';
import '../../../../shared/utils/duration_format.dart';
import '../../../../shared/widgets/eg_hoverable.dart';
import '../../../../shared/widgets/eg_icon.dart';
import '../../../../shared/widgets/eg_day_header.dart';
import '../../../../shared/widgets/eg_surface.dart';
import '../../models/meeting.dart';
import '../../../../core/design/eg_tokens.dart';

/// As reuniões gravadas, da mais recente para a mais antiga.
///
/// Mesma gramática do histórico do Focus, e de propósito: dia no grupo (com o
/// total do dia à direita), nome da linha no meio, duração em coluna fixa à
/// direita. São duas listas do mesmo aplicativo respondendo à mesma pergunta
/// ("o que aconteceu e quando"), e ler uma já ensina a ler a outra.
///
/// **A linha do Echo tem duas alturas, a do Focus tem uma**, e a diferença não
/// é estética: uma reunião tem um estado que uma sessão não tem. Ela chega
/// transcrita, pode estar sendo resumida agora e pode nunca ter ganhado
/// resumo — e é isso que decide se vale abrir. Isso não cabia atrás do nome,
/// onde vivia como um "resumida" cinza que o corte por ellipsis comia primeiro.
/// Na segunda linha ele fica ao lado da hora, que desceu junto: hora e estado
/// são as duas coisas que distinguem duas reuniões do mesmo dia.
class EchoMeetingList extends StatelessWidget {
  const EchoMeetingList({
    super.key,
    required this.meetings,
    required this.selectedId,
    this.summarizingId,
    required this.onSelect,
    required this.onToggleKept,
    this.now,
  });

  final List<Meeting> meetings;
  final int? selectedId;

  /// A reunião cujo resumo está sendo escrito agora, se houver.
  final int? summarizingId;

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
          EgDayHeader(
            label: group.label,
            total: _totalOf(group.items),
            trailingInset: _MeetingRow.starColumn,
          ),
          for (final meeting in group.items)
            _MeetingRow(
              meeting: meeting,
              isSelected: meeting.id == selectedId,
              isSummarizing: meeting.id != null && meeting.id == summarizingId,
              onTap: () => onSelect(meeting.id!),
              onToggleKept: () => onToggleKept(meeting.id!),
            ),
        ],
      ],
    );
  }

  /// O quanto de reunião aquele dia teve — a soma das durações, não a contagem.
  static String _totalOf(List<Meeting> meetings) => DurationFormat.compact(
    meetings.fold(Duration.zero, (total, meeting) => total + meeting.duration),
  );
}

class _MeetingRow extends StatelessWidget {
  const _MeetingRow({
    required this.meeting,
    required this.isSelected,
    required this.isSummarizing,
    required this.onTap,
    required this.onToggleKept,
  });

  final Meeting meeting;
  final bool isSelected;
  final bool isSummarizing;
  final VoidCallback onTap;
  final VoidCallback onToggleKept;

  /// Duas linhas de texto e o respiro delas. Fixa, como a linha do Focus e a do
  /// Pin: é a altura constante que deixa correr o olho pela coluna da direita.
  static const _height = 52.0;

  /// Coluna da duração. Fixa, e não encolhida ao conteúdo, porque é ela que
  /// permite comparar as reuniões correndo o olho por uma coluna só.
  static const _durationColumn = 64.0;

  /// O que a estrela ocupa à direita da duração — o vão mais o alvo de clique.
  /// É o que o total do dia recua para cair em cima da coluna que ele soma.
  static const starColumn =
      AppSpacing.sm + AppIconSizes.xs + AppSpacing.xxs * 2;

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
          // O glifo do módulo, decorativo: quem nomeia a linha é o texto ao
          // lado. Ele existe para a linha de duas alturas ter onde começar —
          // sem ele o título e o estado ficam boiando na borda do cartão.
          EgIcon(
            EgIconData.microphone,
            size: AppIconSizes.sm,
            color: context.eg.colors.textTertiary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meeting.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: context.eg.text.bodyEmphasis,
                ),
                const SizedBox(height: AppSpacing.xxxs),
                _status(context),
              ],
            ),
          ),
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

  /// A hora e o que já existe da reunião — a segunda linha.
  ///
  /// Em que pé está: transcrita e sem resumo, resumindo agora, ou com o resumo
  /// pronto. É o que decide se vale abrir, e é a única coisa da linha que muda
  /// sozinha depois de a reunião ter acabado.
  Widget _status(BuildContext context) {
    final eg = context.eg;
    final (label, color) = _stateOf(eg);

    return Text(
      '${DayLabel.time(meeting.startedAt)}  ·  $label',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
      style: eg.text.footnote.copyWith(color: color),
    );
  }

  (String, Color) _stateOf(EgTokens eg) {
    if (meeting.isEmpty) {
      return ('sem falas reconhecidas', eg.colors.textQuaternary);
    }
    // Em curso é âmbar, como todo "processando" do aplicativo — nunca verde,
    // que aqui diria "ligado".
    if (isSummarizing) return ('resumindo…', eg.colors.ember);
    if (meeting.hasSummary) return ('resumo pronto', eg.colors.textTertiary);

    return ('só transcrição', eg.colors.textTertiary);
  }
}
