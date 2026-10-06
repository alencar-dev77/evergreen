import 'package:flutter/widgets.dart';

import '../../../../core/design/app_metrics.dart';
import '../../models/leaf_note.dart';
import '../viewmodels/leaf_state.dart';
import 'leaf_note_card.dart';
import '../../../../core/design/eg_tokens.dart';

/// A parede: as nove vagas, em três colunas, sempre.
///
/// Ela desenhava só o que existia mais a vaga seguinte, e o painel encolhia a
/// cada cartão jogado fora. O que se ganhava em "o mural diminuiu" se perdia em
/// duas coisas maiores: a parede mudava de tamanho a cada gesto, e o número de
/// uma vaga só passava a existir quando ela era ocupada — então `7` não queria
/// dizer nada antes de haver sete cartões. Com as nove desenhadas, a vaga é um
/// **endereço fixo**, que é o que faz o atalho de número ser decorável.
///
/// As vagas ocupadas continuam contíguas: a parede não tem buraco, e a livre é
/// sempre a seguinte à última.
class LeafGrid extends StatelessWidget {
  const LeafGrid({
    super.key,
    required this.state,
    required this.editorController,
    required this.editorFocusNode,
    required this.reminderController,
    required this.reminderFocusNode,
    required this.onSelect,
    required this.onDelete,
    required this.onRemind,
    required this.onPickReminder,
    required this.onRemoveReminder,
    required this.onToggleHidden,
    this.peekSlot,
    this.now,
  });

  final LeafState state;

  final TextEditingController editorController;
  final FocusNode editorFocusNode;

  final TextEditingController reminderController;
  final FocusNode reminderFocusNode;

  /// Clique numa vaga: seleciona e abre (anotação existente entra em edição,
  /// vaga livre nasce em branco).
  final ValueChanged<int> onSelect;

  final ValueChanged<int> onDelete;

  /// O sino de uma vaga: o cartão vira o seletor de lembrete.
  final ValueChanged<int> onRemind;

  final ValueChanged<DateTime> onPickReminder;
  final VoidCallback onRemoveReminder;

  /// O olho de uma vaga: põe o cartão sob o vidro, ou o tira.
  final ValueChanged<int> onToggleHidden;

  /// A vaga sendo espiada com o espaço apertado, se houver.
  final int? peekSlot;

  final DateTime? now;

  /// Colunas da parede — as três, sempre.
  ///
  /// Recebe o estado porque quem chama não precisa saber que a resposta deixou
  /// de depender dele.
  static int columnsFor(LeafState state) => LeafNote.columns;

  /// Largura de uma parede com [columns] colunas, já com o respiro do painel.
  ///
  /// A borda do `EgPanel` entra na conta porque é desenhada por dentro da caixa:
  /// ela reduz a largura que sobra para os cartões. Sem esses 2px a última
  /// coluna passava do painel por um fio, e o viewport sem rolagem a recortava
  /// em silêncio — os cartões 3, 6 e 9 ficavam sem a borda direita.
  static double widthFor(BuildContext context, int columns) =>
      columns * LeafCardMetrics.width +
      (columns - 1) * LeafCardMetrics.gap +
      AppSpacing.xxl * 2 +
      context.eg.hairline.width * 2;

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
    if (state.editingSlot == slot) {
      return LeafNoteEditor(
        slot: slot,
        controller: editorController,
        focusNode: editorFocusNode,
      );
    }

    final note = state.noteAt(slot);
    if (note != null && state.remindingSlot == slot) {
      return LeafReminderPicker(
        note: note,
        controller: reminderController,
        focusNode: reminderFocusNode,
        onPick: onPickReminder,
        onRemove: onRemoveReminder,
        now: now,
      );
    }

    if (note != null) {
      return LeafNoteCard(
        note: note,
        isSelected: state.selectedSlot == slot,
        isCopied: state.copiedSlot == slot,
        onTap: () => onSelect(slot),
        onDelete: () => onDelete(slot),
        onRemind: () => onRemind(slot),
        onToggleHidden: () => onToggleHidden(slot),
        isPeeking: peekSlot == slot,
        now: now,
      );
    }

    // A vaga livre só convida enquanto ninguém está escrevendo: com um cartão
    // em edição, um segundo convite ao lado prometeria duas anotações ao mesmo
    // tempo.
    final isNext = slot == state.firstFreeSlot && !state.isEditing;

    return LeafEmptySlot(
      slot: slot,
      isNext: isNext,
      isSelected: state.selectedSlot == slot,
      onTap: isNext ? () => onSelect(slot) : null,
    );
  }
}
