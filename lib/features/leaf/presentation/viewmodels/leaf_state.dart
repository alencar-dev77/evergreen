import '../../models/leaf_note.dart';

/// Estado da parede: o que está colado nela, o que está selecionado e o que
/// está sendo escrito.
class LeafState {
  const LeafState({
    this.notes = const <LeafNote>[],
    this.selectedSlot,
    this.editingSlot,
  });

  /// Anotações em ordem de vaga.
  final List<LeafNote> notes;

  /// Vaga onde o teclado está. `null` com a parede vazia.
  final int? selectedSlot;

  /// Vaga em edição. Pode ser uma anotação existente ou uma vaga ainda vazia —
  /// nesse caso é um rascunho, e desistir dele não deixa rastro.
  final int? editingSlot;

  bool get isEmpty => notes.isEmpty;

  bool get isFull => notes.length >= LeafNote.maxNotes;

  bool get isEditing => editingSlot != null;

  /// A edição em curso é de uma anotação que ainda não existe no banco.
  bool get isDraft => editingSlot != null && noteAt(editingSlot!) == null;

  LeafNote? noteAt(int slot) {
    for (final note in notes) {
      if (note.slot == slot) return note;
    }
    return null;
  }

  LeafNote? get selectedNote {
    final slot = selectedSlot;
    return slot == null ? null : noteAt(slot);
  }

  /// A vaga onde a próxima anotação nasce, ou `null` com a parede cheia.
  ///
  /// As vagas ocupadas são sempre contíguas (ver [LeafNote.slot]), então a
  /// livre é sempre a seguinte à última.
  int? get firstFreeSlot =>
      isFull ? null : notes.length + 1;

  /// Última vaga que a grade precisa desenhar.
  ///
  /// Cobre as anotações, o rascunho em curso e a vaga vazia que convida a
  /// próxima — abaixo disso a grade não desenha linha nenhuma, para a parede
  /// não abrir com espaço reservado que ninguém pediu. É daqui que sai o
  /// encolhimento do painel a cada cartão jogado fora.
  int get lastVisibleSlot {
    final occupied = notes.length;
    if (isEditing) return editingSlot!.clamp(occupied, LeafNote.maxNotes);

    return isFull ? occupied : occupied + 1;
  }

  /// Quantas linhas a grade ocupa agora.
  int get rows => (lastVisibleSlot / LeafNote.columns).ceil();

  LeafState copyWith({
    List<LeafNote>? notes,
    int? selectedSlot,
    int? editingSlot,
    bool clearSelection = false,
    bool clearEditing = false,
  }) {
    return LeafState(
      notes: notes ?? this.notes,
      selectedSlot: clearSelection ? null : selectedSlot ?? this.selectedSlot,
      editingSlot: clearEditing ? null : editingSlot ?? this.editingSlot,
    );
  }
}
