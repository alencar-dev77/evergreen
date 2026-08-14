import 'package:flutter/material.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_metrics.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../shared/widgets/eg_button.dart';
import '../../../../shared/widgets/eg_section_label.dart';
import '../../models/echo_capabilities.dart';
import '../../models/meeting.dart';
import '../../models/meeting_segment.dart';

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
            child: SelectableText(
              meeting.summary!,
              style: AppTypography.bodyCompact,
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
        'Nenhuma fala foi reconhecida. As duas causas comuns: o microfone '
        'estava sem permissão, ou o áudio da reunião não estava saindo pelos '
        'alto-falantes — fone de ouvido Bluetooth, por exemplo, não passa pela '
        'captura do sistema.',
        style: AppTypography.captionSmall,
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: AppRadii.cardAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final segment in meeting.segments) ...[
            _SegmentLine(segment: segment),
            if (segment != meeting.segments.last)
              const SizedBox(height: AppSpacing.md),
          ],
        ],
      ),
    );
  }
}

/// Uma fala: o relógio, quem falou e o que foi dito.
///
/// "Você" fica em verde e o resto em neutro — é a única cor da tela, e ela
/// carrega significado (de quem é a fala), que é a regra do projeto para usar
/// cor. Como quem falou também aparece por escrito, quem não distingue a cor
/// não perde nada.
class _SegmentLine extends StatelessWidget {
  const _SegmentLine({required this.segment});

  final MeetingSegment segment;

  @override
  Widget build(BuildContext context) {
    final isMe = segment.speaker == Speaker.me;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 46,
          child: Text(segment.timestamp, style: AppTypography.monoSmall),
        ),
        SizedBox(
          width: 74,
          child: Text(
            segment.speaker.label,
            style: AppTypography.captionXS.copyWith(
              color: isMe ? AppColors.greenPrimary : AppColors.textTertiary,
            ),
          ),
        ),
        Expanded(
          child: SelectableText(
            segment.text,
            style: AppTypography.bodyCompact,
          ),
        ),
      ],
    );
  }
}
