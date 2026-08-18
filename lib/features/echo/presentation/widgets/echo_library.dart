import 'package:flutter/widgets.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_metrics.dart';
import '../../../../shared/widgets/eg_empty_state.dart';
import '../../../../shared/widgets/eg_icon.dart';
import '../viewmodels/echo_library_view_model.dart';
import 'echo_meeting_detail.dart';
import 'echo_meeting_list.dart';

/// A biblioteca de reuniões: escolher à esquerda, ler à direita.
///
/// Duas regiões lado a lado, e não uma coluna só, porque o conteúdo daqui é um
/// documento: empilhado sob a lista, meia hora de transcrição empurrava as
/// reuniões para fora da tela e obrigava a rolar de volta ao topo para trocar
/// de reunião. É a composição-padrão de `spacing.md` — lista + detalhe — e a
/// mesma de qualquer app de macOS onde se escolhe uma coisa para ler.
///
/// O bloco tem altura fixa e cada lado rola por dentro. É o que impede a tela
/// do Hub de crescer com o tamanho da transcrição: as preferências abaixo ficam
/// sempre à mesma distância, seja a reunião de cinco minutos ou de duas horas.
class EchoLibrary extends StatelessWidget {
  const EchoLibrary({
    super.key,
    required this.state,
    required this.onSelect,
    required this.onToggleKept,
    required this.onSummarize,
    required this.onDelete,
    this.now,
  });

  final EchoLibraryState state;
  final void Function(int id) onSelect;
  final void Function(int id) onToggleKept;
  final void Function(int id) onSummarize;
  final void Function(int id) onDelete;

  /// Injetável para o teste e para os goldens não dependerem do relógio real.
  final DateTime? now;

  /// Teto de altura do bloco: cabem umas oito reuniões na coluna da esquerda e
  /// uns quinze parágrafos na da direita. Passando disso, cada lado rola por
  /// dentro em vez de esticar a página.
  static const _maxHeight = 420.0;

  /// Piso. Abaixo disto o painel de leitura fica apertado demais para um
  /// resumo de três linhas parecer um documento.
  static const _minHeight = 260.0;

  /// Estimativa da altura da lista, para o bloco não abrir com um vão embaixo
  /// quando há duas reuniões guardadas.
  ///
  /// Estimativa, e não medição: medir exigiria um passe de layout a mais por
  /// quadro para escolher uma altura que, dentro do piso e do teto, ninguém
  /// consegue apontar como errada.
  static const _rowHeight = 48.0;
  static const _dayLabelHeight = 28.0;

  /// Largura da coluna das reuniões. Um pouco mais estreita que a barra lateral
  /// do Hub: são duas listas de navegação na mesma tela, e a de dentro não pode
  /// competir com a que manda.
  static const _listWidth = 240.0;

  @override
  Widget build(BuildContext context) {
    if (state.isEmpty) {
      return const EgEmptyState(
        icon: EgIconData.microphone,
        title: 'Nenhuma reunião gravada',
        message:
            'Aperte ⌘⇧E antes da próxima reunião. A transcrição aparece aqui '
            'quando ela terminar.',
      );
    }

    final selected = state.selected;

    return SizedBox(
      height: _heightFor(state),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: _listWidth,
            child: Padding(
              padding: const EdgeInsets.only(right: AppSpacing.lg),
              child: EchoMeetingList(
                meetings: state.meetings,
                selectedId: state.selectedId,
                onSelect: onSelect,
                onToggleKept: onToggleKept,
                now: now,
              ),
            ),
          ),
          // Fio de 1px entre as duas regiões: é o que separa "onde se escolhe"
          // de "onde se lê" sem gastar uma superfície inteira para isso.
          const _Rule(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: AppSpacing.xxl),
              child: selected == null
                  ? const SizedBox.shrink()
                  : EchoMeetingDetail(
                      meeting: selected,
                      summaries: state.summaries,
                      isSummarizing: state.summarizingId == selected.id,
                      progress: state.progress,
                      onSummarize: () => onSummarize(selected.id!),
                      onDelete: () => onDelete(selected.id!),
                      now: now,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

double _heightFor(EchoLibraryState state) {
  final days = <DateTime>{
    for (final meeting in state.meetings)
      DateTime(
        meeting.startedAt.year,
        meeting.startedAt.month,
        meeting.startedAt.day,
      ),
  }.length;

  final estimate = state.meetings.length * EchoLibrary._rowHeight +
      days * EchoLibrary._dayLabelHeight;

  return estimate.clamp(EchoLibrary._minHeight, EchoLibrary._maxHeight);
}

class _Rule extends StatelessWidget {
  const _Rule();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 1,
      child: DecoratedBox(decoration: BoxDecoration(color: AppColors.border)),
    );
  }
}
