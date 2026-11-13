import 'package:flutter/gestures.dart';
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
/// A vaga é endereço: a anotação nasce em qualquer vaga livre e fica onde foi
/// posta. **Arrastar um cartão** o leva para outra vaga — livre, ele vai; com
/// outro cartão, os dois trocam de lugar (#174). A conta é do
/// `LeafViewModel.moveNote`; a grade só diz de onde para onde.
class LeafGrid extends StatelessWidget {
  const LeafGrid({
    super.key,
    required this.state,
    required this.editorController,
    required this.editorFocusNode,
    required this.reminderController,
    required this.reminderFocusNode,
    required this.onSelect,
    required this.onMove,
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

  /// Um cartão arrastado da vaga `from` e solto na vaga `to`.
  final void Function(int from, int to) onMove;

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

  /// A vaga, como destino de um cartão arrastado.
  ///
  /// Só enquanto a parede está sendo olhada: com um cartão em edição ou no
  /// seletor de lembrete, nada se move (ver `LeafViewModel.moveNote`).
  ///
  /// O alvo existe sempre, e só recusa enquanto nada pode se mover: trocar a
  /// árvore da vaga a cada edição remontaria as nove e perderia o hover.
  ///
  /// O que viaja no arraste é o **id** da anotação, e não a vaga: a vaga de
  /// origem é perguntada ao estado na hora de soltar, e um `⌘Z` no meio do
  /// arraste não faz o cartão errado mudar de lugar.
  Widget _cell(int slot) {
    final cell = _content(slot);
    final canMove = !state.isEditing && !state.isReminding;

    int? fromOf(int id) {
      for (final note in state.notes) {
        if (note.id == id) return note.slot;
      }
      return null;
    }

    return DragTarget<int>(
      onWillAcceptWithDetails: (details) {
        final from = fromOf(details.data);
        return canMove && from != null && from != slot;
      },
      onAcceptWithDetails: (details) {
        final from = fromOf(details.data);
        if (from != null) onMove(from, slot);
      },
      builder: (context, candidates, _) {
        if (candidates.isEmpty) return cell;

        final eg = context.eg;
        return DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: ShapeDecoration(
            shape: eg.shapes.cardShape,
            shadows: eg.elevations.focusRing,
          ),
          child: cell,
        );
      },
    );
  }

  Widget _content(int slot) {
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
      Widget card({bool isSelected = false}) => LeafNoteCard(
        note: note,
        isSelected: isSelected,
        isCopied: state.copiedSlot == slot,
        onTap: () => onSelect(slot),
        onDelete: () => onDelete(slot),
        onRemind: () => onRemind(slot),
        onToggleHidden: () => onToggleHidden(slot),
        isPeeking: peekSlot == slot,
        now: now,
      );

      return _CardDraggable(
        noteId: note.id,
        enabled: !state.isEditing && !state.isReminding,
        // Quem é arrastado é o cartão inteiro, levantado — o mesmo
        // "selecionado" da parede, que é elevação.
        feedback: card(isSelected: true),
        // A vaga de origem já parece livre durante o arraste: é o que ela vai
        // ser se o cartão for solto em outra.
        childWhenDragging: LeafEmptySlot(slot: slot, isSelected: false),
        child: card(isSelected: state.selectedSlot == slot),
      );
    }

    return LeafEmptySlot(
      slot: slot,
      isSelected: state.selectedSlot == slot,
      // A vaga livre só convida enquanto ninguém está escrevendo: com um
      // cartão em edição, um segundo convite ao lado prometeria duas
      // anotações ao mesmo tempo.
      onTap: state.isEditing ? null : () => onSelect(slot),
    );
  }
}

/// O cartão que se arrasta para outra vaga.
///
/// Um `Draggable` com o reconhecedor trocado: o de fábrica começa a arrastar
/// com 1 px de movimento do mouse, e a mão que treme um pouco ao clicar no
/// cartão perderia o clique — o cartão sairia do lugar em vez de abrir. Aqui o
/// arraste só começa onde o clique termina (`kTouchSlop`), a mesma régua do
/// arrasto da janela na `EgOverlayShell`; e, como o cartão está mais fundo na
/// árvore, ele recebe o movimento primeiro e ganha do arrasto da janela.
///
/// A régua mede o **caminho percorrido**, como o `PanGestureRecognizer` da
/// janela, e não a distância em linha reta: medindo diferente, um arraste em
/// curva passava da régua da janela antes da do cartão, e a janela saía do
/// lugar no lugar do cartão.
class _CardDraggable extends Draggable<int> {
  const _CardDraggable({
    required int noteId,
    required bool enabled,
    required super.feedback,
    required super.childWhenDragging,
    required super.child,
  }) : super(
         data: noteId,
         rootOverlay: true,
         maxSimultaneousDrags: enabled ? null : 0,
       );

  @override
  MultiDragGestureRecognizer createRecognizer(
    GestureMultiDragStartCallback onStart,
  ) => _SlopDragRecognizer()..onStart = onStart;
}

class _SlopDragRecognizer extends MultiDragGestureRecognizer {
  _SlopDragRecognizer() : super(debugOwner: null);

  @override
  MultiDragPointerState createNewPointerState(PointerDownEvent event) =>
      _SlopPointerState(event.position, event.kind, gestureSettings);

  @override
  String get debugDescription => 'leaf card drag';
}

class _SlopPointerState extends MultiDragPointerState {
  _SlopPointerState(super.initialPosition, super.kind, super.gestureSettings);

  Offset _lastDelta = Offset.zero;
  double _traveled = 0;

  @override
  void checkForResolutionAfterMove() {
    final delta = pendingDelta ?? Offset.zero;
    _traveled += (delta - _lastDelta).distance;
    _lastDelta = delta;

    if (_traveled > (gestureSettings?.touchSlop ?? kTouchSlop)) {
      resolve(GestureDisposition.accepted);
    }
  }

  @override
  void accepted(GestureMultiDragStartCallback starter) {
    starter(initialPosition);
  }
}
