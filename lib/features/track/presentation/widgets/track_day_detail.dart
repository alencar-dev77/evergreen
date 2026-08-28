import 'package:flutter/widgets.dart';

import '../../../../core/design/app_metrics.dart';
import '../../../../shared/utils/day_label.dart';
import '../../../../shared/utils/duration_format.dart';
import '../../../../shared/widgets/eg_section_label.dart';
import '../../models/track_day.dart';
import '../viewmodels/track_view_model.dart';
import 'track_copied_breakdown.dart';
import '../../../../core/design/eg_tokens.dart';

/// O corpo da região de leitura do Track: o dia inteiro, de cima a baixo.
///
/// O rótulo do dia e os números ficam no cabeçalho da região
/// (`HubDetailRegion`), ao lado do botão de fechar — aqui fica só o que se lê.
///
/// É consulta pura, sem nenhuma ação: o Track não escreve nada e não apaga
/// nada. Quem quiser mexer numa sessão vai ao Focus, numa reunião vai ao Echo,
/// num item copiado vai ao Pin — cada registro se edita no módulo que o criou,
/// e um botão de apagar aqui apagaria dado de outro módulo pelas costas dele.
class TrackDayDetail extends StatelessWidget {
  const TrackDayDetail({super.key, required this.day, required this.summary});

  final TrackDay day;

  /// O parágrafo do modelo local, quando existe. Nem toda máquina tem um —
  /// abaixo do macOS 26 ele simplesmente não aparece, e o resto da região fica
  /// igual.
  final TrackSummary summary;

  @override
  Widget build(BuildContext context) {
    // A leitura rola dentro da região, não na página: é o que mantém a lista de
    // dias ao lado sempre à vista.
    return SingleChildScrollView(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _blocks(context),
      ),
    );
  }

  List<Widget> _blocks(BuildContext context) {
    if (day.isEmpty) {
      return [
        Text(
          'Nada foi registrado neste dia.',
          style: context.eg.text.captionSmall,
        ),
      ];
    }

    return [
      ..._summary(context),
      if (day.focus.isNotEmpty) ...[
        const EgSectionLabel(
          'Foco',
          padding: EdgeInsets.only(bottom: AppSpacing.sm),
        ),
        for (final entry in day.focus)
          _EntryRow(entry: entry, fallbackLabel: 'Sessão'),
        const SizedBox(height: AppSpacing.xxl),
      ],
      if (day.meetings.isNotEmpty) ...[
        const EgSectionLabel(
          'Reuniões',
          padding: EdgeInsets.only(bottom: AppSpacing.sm),
        ),
        for (final entry in day.meetings)
          _EntryRow(entry: entry, fallbackLabel: 'Reunião'),
        const SizedBox(height: AppSpacing.xxl),
      ],
      if (day.awake.isNotEmpty) ...[
        const EgSectionLabel(
          'Acordado',
          padding: EdgeInsets.only(bottom: AppSpacing.sm),
        ),
        for (final entry in day.awake)
          _EntryRow(entry: entry, fallbackLabel: 'Tela acesa'),
        const SizedBox(height: AppSpacing.xxl),
      ],
      if (day.copiedTotal > 0) ...[
        const EgSectionLabel(
          'Copiado',
          padding: EdgeInsets.only(bottom: AppSpacing.sm),
        ),
        TrackCopiedBreakdown(copied: day.copied),
        const SizedBox(height: AppSpacing.xxl),
      ],
      if (day.notesWritten > 0)
        Text(
          '${TrackCounts.of(day.notesWritten, 'anotação escrita', 'anotações escritas')} no Leaf.',
          style: context.eg.text.captionSmall,
        ),
    ];
  }

  /// O parágrafo, quando há um — e nada quando não há.
  ///
  /// Sem aviso de "resumo indisponível" e sem espaço reservado: o resumo é
  /// enfeite, o dado é o produto, e uma tela que anuncia o que não tem só chama
  /// atenção para a falta.
  List<Widget> _summary(BuildContext context) {
    if (summary.isWriting) {
      return [
        Text(
          'Escrevendo o resumo do dia…',
          style: context.eg.text.captionSmall.copyWith(
            color: context.eg.colors.textTertiary,
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
      ];
    }

    if (!summary.hasText) return const [];

    return [
      Text(summary.text!, style: context.eg.text.reading),
      const SizedBox(height: AppSpacing.xxl),
    ];
  }
}

/// Uma sessão ou uma reunião: hora, nome e duração, nas mesmas colunas da lista
/// de dias — é o que deixa correr o olho por uma coluna só.
class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry, required this.fallbackLabel});

  final TrackEntry entry;

  /// Como chamar o registro que nasceu sem nome — uma sessão iniciada sem dizer
  /// em quê.
  final String fallbackLabel;

  static const _height = 28.0;
  static const _timeColumn = 44.0;
  static const _durationColumn = 60.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _height,
      child: Row(
        children: [
          SizedBox(
            width: _timeColumn,
            child: Text(
              DayLabel.time(entry.at),
              style: context.eg.text.monoSmall.copyWith(
                color: context.eg.colors.textTertiary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              entry.hasLabel ? entry.label!.trim() : fallbackLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: entry.hasLabel
                  ? context.eg.text.bodyCompact
                  : context.eg.text.bodyCompact.copyWith(
                      color: context.eg.colors.textSecondary,
                    ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: _durationColumn,
            child: Text(
              DurationFormat.compact(entry.duration),
              textAlign: TextAlign.right,
              style: context.eg.text.captionSmall,
            ),
          ),
        ],
      ),
    );
  }
}
