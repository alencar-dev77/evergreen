import 'package:flutter/widgets.dart';

import '../../../../core/design/app_metrics.dart';
import '../../models/leaf_note.dart';
import '../viewmodels/leaf_state.dart';
import 'leaf_note_card.dart';

/// A parede: até nove vagas em três colunas.
///
/// A grade nunca tem buraco. As vagas ocupadas são contíguas, então ela desenha
/// exatamente os cartões que existem mais a vaga que convida o próximo — e
/// encolhe a cada cartão jogado fora, que é o que se espera de um mural do qual
/// se acabou de arrancar um papel.
class LeafGrid extends StatelessWidget {
  const LeafGrid({
    super.key,
    required this.state,
    required this.editorController,
    required this.editorFocusNode,
    required this.onSelect,
    required this.onDelete,
    this.now,
  });

  final LeafState state;

  final TextEditingController editorController;
  final FocusNode editorFocusNode;

  /// Clique numa vaga: seleciona e abre (anotação existente entra em edição,
  /// vaga livre nasce em branco).
  final ValueChanged<int> onSelect;

  final ValueChanged<int> onDelete;

  final DateTime? now;

  /// Colunas que a parede ocupa agora.
  ///
  /// Duas no mínimo: com uma só o painel ficaria mais estreito que a barra de
  /// dicas do rodapé, e o rodapé passaria a mandar na largura de tudo.
  static int columnsFor(LeafState state) {
    final used = state.lastVisibleSlot;
    if (used >= LeafNote.columns) return LeafNote.columns;
    return used < 2 ? 2 : used;
  }

  /// Largura de uma parede com [columns] colunas, já com o respiro do painel.
  ///
  /// A borda do `EgPanel` entra na conta porque é desenhada por dentro da caixa:
  /// ela reduz a largura que sobra para os cartões. Sem esses 2px a última
  /// coluna passava do painel por um fio, e o viewport sem rolagem a recortava
  /// em silêncio — os cartões 3, 6 e 9 ficavam sem a borda direita.
  static double widthFor(int columns) =>
      columns * LeafCardMetrics.width +
      (columns - 1) * LeafCardMetrics.gap +
      AppSpacing.xxl * 2 +
      AppBorders.subtle.width * 2;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var row = 0; row < state.rows; row++) ...[
          if (row > 0) const SizedBox(height: LeafCardMetrics.gap),
          _row(row),
        ],
      ],
    );
  }

  Widget _row(int row) {
    final columns = columnsFor(state);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var column = 0; column < columns; column++) ...[
          if (column > 0) const SizedBox(width: LeafCardMetrics.gap),
          _cell(row * LeafNote.columns + column + 1),
        ],
      ],
    );
  }

  Widget _cell(int slot) {
    if (slot > state.lastVisibleSlot) return const _EmptySlot();

    if (state.editingSlot == slot) {
      return LeafNoteEditor(
        slot: slot,
        controller: editorController,
        focusNode: editorFocusNode,
      );
    }

    final note = state.noteAt(slot);
    if (note != null) {
      return LeafNoteCard(
        note: note,
        isSelected: state.selectedSlot == slot,
        onTap: () => onSelect(slot),
        onDelete: () => onDelete(slot),
        now: now,
      );
    }

    // A vaga livre só convida enquanto ninguém está escrevendo: com um cartão
    // em edição, um segundo convite ao lado prometeria duas anotações ao mesmo
    // tempo.
    if (slot == state.firstFreeSlot && !state.isEditing) {
      return LeafNewNoteCell(
        isSelected: state.selectedSlot == slot,
        onTap: () => onSelect(slot),
      );
    }

    return const _EmptySlot();
  }
}

/// Uma vaga que não tem nada — nem cartão, nem contorno, nem convite.
class _EmptySlot extends StatelessWidget {
  const _EmptySlot();

  @override
  Widget build(BuildContext context) => const SizedBox(
        width: LeafCardMetrics.width,
        height: LeafCardMetrics.height,
      );
}
