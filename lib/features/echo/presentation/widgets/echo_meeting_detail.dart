import 'package:flutter/material.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_metrics.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../shared/widgets/eg_button.dart';
import '../../../../shared/widgets/eg_section_label.dart';
import '../../models/echo_capabilities.dart';
import '../../models/meeting.dart';
import '../../models/meeting_segment.dart';
import '../../models/meeting_turn.dart';

/// A reunião selecionada: o resumo, quando existe, e a transcrição inteira.
///
/// O resumo vem primeiro de propósito. Quem volta a uma reunião de semanas
/// atrás quer o que foi decidido, não reler trinta minutos de fala — e quem
/// quer reler tem a transcrição logo abaixo, sem precisar abrir nada.
class EchoMeetingDetail extends StatelessWidget {
  const EchoMeetingDetail({
    super.key,
    required this.meeting,
    required this.summaries,
    required this.isSummarizing,
    required this.progress,
    required this.onSummarize,
    required this.onDelete,
  });

  final Meeting meeting;
  final SummaryAvailability summaries;
  final bool isSummarizing;

  /// "bloco 2 de 4" enquanto o resumo acontece em partes.
  final (int, int)? progress;

  final VoidCallback onSummarize;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _summary(),
        const SizedBox(height: AppSpacing.xxl),
        const EgSectionLabel('Transcrição'),
        const SizedBox(height: AppSpacing.sm),
        _transcript(),
        const SizedBox(height: AppSpacing.xl),
        Align(
          alignment: Alignment.centerLeft,
          child: EgButton.destructive(
            label: 'Apagar reunião',
            onPressed: onDelete,
          ),
        ),
      ],
    );
  }

  Widget _summary() {
    if (meeting.hasSummary) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(child: EgSectionLabel('Resumo')),
              // Refazer é barato quando a instrução mudou — e é assim que a
              // pessoa experimenta formatos sem regravar nada.
              if (summaries.isAvailable && !isSummarizing)
                EgButton.secondary(label: 'Refazer', onPressed: onSummarize),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: const BoxDecoration(
              color: AppColors.card,
              borderRadius: AppRadii.cardAll,
            ),
            // Mesma fonte de leitura da transcrição: os dois são texto que
            // se lê em parágrafo, e alternar entre eles não pode parecer
            // trocar de documento.
            child: SelectableText(
              meeting.summary!,
              style: AppTypography.reading,
            ),
          ),
        ],
      );
    }

    if (isSummarizing) {
      final label = progress == null || progress!.$2 <= 1
          ? 'Resumindo…'
          : 'Resumindo — bloco ${progress!.$1} de ${progress!.$2}';

      return Text(label, style: AppTypography.captionSmall);
    }

    // Sem transcrição não há o que resumir, e um botão que não faz nada é pior
    // que botão nenhum: a pessoa clica, não acontece nada, e não fica sabendo
    // se o app travou ou se ela entendeu errado.
    if (meeting.isEmpty) {
      return Text(
        'Não há o que resumir: esta gravação não capturou nenhuma fala.',
        style: AppTypography.captionSmall,
      );
    }

    final explanation = summaries.explanation;
    if (explanation != null) {
      return Text(explanation, style: AppTypography.captionSmall);
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: EgButton(label: 'Resumir', onPressed: onSummarize),
    );
  }

  Widget _transcript() {
    if (meeting.isEmpty) {
      return Text(
        'Nenhuma fala foi reconhecida. As causas comuns: o microfone estava '
        'sem permissão, ninguém falou, ou o idioma da transcrição não era o '
        'idioma da reunião.',
        style: AppTypography.captionSmall,
      );
    }

    final turns = MeetingTurn.from(meeting.segments);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.lg,
      ),
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: AppRadii.cardAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final turn in turns) ...[
            _TurnBlock(turn: turn),
            if (turn != turns.last) const SizedBox(height: AppSpacing.xl),
          ],
        ],
      ),
    );
  }
}

/// Uma fala inteira: quem falou, quando, e o texto em parágrafo.
///
/// O cabeçalho é uma linha só e discreta; o peso visual fica no texto, que é o
/// que a pessoa veio ler. O nome vem antes do horário porque "quem falou" é a
/// pergunta que se faz ao percorrer a transcrição — o horário só interessa
/// quando já se achou o trecho.
///
/// Sem balões de conversa: isso é vocabulário de aplicativo de mensagem, e o
/// que está aqui é um documento para reler, não um bate-papo.
class _TurnBlock extends StatelessWidget {
  const _TurnBlock({required this.turn});

  final MeetingTurn turn;

  @override
  Widget build(BuildContext context) {
    final isMe = turn.speaker == Speaker.me;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              turn.speaker.label,
              // Verde para você, neutro para a reunião: é a única cor da tela e
              // carrega significado. Quem não distingue a cor lê o nome, que
              // está escrito do lado.
              style: AppTypography.overline.copyWith(
                color: isMe ? AppColors.greenPrimary : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(turn.timestamp, style: AppTypography.monoSmall),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        SelectableText(turn.text, style: AppTypography.reading),
      ],
    );
  }
}
