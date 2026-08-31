import '../../models/leaf_note.dart';

/// Estado da parede: o que está colado nela, o que está selecionado e o que
/// está sendo escrito.
class LeafState {
  const LeafState({
    this.notes = const <LeafNote>[],
    this.selectedSlot,
    this.editingSlot,
    this.copiedSlot,
    this.undoableDelete,
  });

  /// Anotações em ordem de vaga.
  final List<LeafNote> notes;

  /// Vaga onde o teclado está. `null` com a parede vazia.
  final int? selectedSlot;

  /// Vaga em edição. Pode ser uma anotação existente ou uma vaga ainda vazia —
  /// nesse caso é um rascunho, e desistir dele não deixa rastro.
  final int? editingSlot;

  /// A vaga que acabou de ser copiada, enquanto o painel continuar aberto.
  ///
  /// Copiar deixou de fechar o painel — quem copia da parede costuma copiar
  /// dois seguidos —, e sem o painel sumindo não sobrava nenhum sinal de que a
  /// tecla funcionou. É o aviso no lugar do sumiço.
  final int? copiedSlot;

  /// O último cartão arrancado da parede, enquanto ainda dá para colá-lo de
  /// volta.
  ///
  /// Vive só na memória e só enquanto o painel está aberto: o desfazer existe
  /// para o engano de um segundo atrás — apagar o cartão errado, ou esvaziar o
  /// campo sem querer, que também apaga —, não para ressuscitar o que se jogou
  /// fora ontem. Fechar o painel encerra a oferta, como encerra a edição.
  final LeafNote? undoableDelete;

  bool get isEmpty => notes.isEmpty;

  bool get isFull => notes.length >= LeafNote.maxNotes;

  bool get isEditing => editingSlot != null;

  /// A edição em curso é de uma anotação que ainda não existe no banco.
  bool get isDraft => editingSlot != null && noteAt(editingSlot!) == null;

  /// Há um cartão para devolver à parede, e vaga onde devolvê-lo.
  ///
  /// A parede cheia tira a oferta em vez de prometer o que não cabe: entre
  /// apagar e desfazer, a pessoa pode ter escrito outra anotação.
  bool get canUndoDelete => undoableDelete != null && !isFull;

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
  int? get firstFreeSlot => isFull ? null : notes.length + 1;

  /// A parede é sempre a parede inteira: nove vagas, três por linha.
  ///
  /// Ela desenhava só o que existia mais a vaga seguinte, e encolhia a cada
  /// cartão jogado fora. O mural cheio e o mural com dois cartões eram duas
  /// telas de tamanhos diferentes, e a vaga em que um cartão *ia* nascer não
  /// existia até ele nascer — então "o quatro" não queria dizer nada antes de
  /// haver quatro. Com as nove sempre desenhadas, a vaga é um **endereço
  /// fixo**: o número do cartão é o mesmo lugar da parede hoje e amanhã, que é
  /// o que faz `1`–`9` ser um atalho e não uma adivinhação.
  int get lastVisibleSlot => LeafNote.maxNotes;

  /// Quantas linhas a grade ocupa — sempre as três.
  int get rows => (LeafNote.maxNotes / LeafNote.columns).ceil();

  /// A última vaga que o teclado alcança.
  ///
  /// **Desenhar as nove não é poder escolher as nove.** A vaga vazia lá do fim
  /// não faz nada: a parede não tem buraco, então a próxima anotação nasce na
  /// primeira livre, e uma seta que parasse na nona deixaria o Enter sem
  /// resposta. O olho vê o endereço; o teclado anda até onde há o que fazer.
  int get lastSelectableSlot => isFull ? notes.length : notes.length + 1;

  LeafState copyWith({
    List<LeafNote>? notes,
    int? selectedSlot,
    int? editingSlot,
    int? copiedSlot,
    bool clearSelection = false,
    bool clearEditing = false,
    bool clearCopied = false,
  }) {
    return LeafState(
      notes: notes ?? this.notes,
      selectedSlot: clearSelection ? null : selectedSlot ?? this.selectedSlot,
      editingSlot: clearEditing ? null : editingSlot ?? this.editingSlot,
      // O aviso morre no gesto seguinte: escrever, apagar ou reabrir o painel
      // apaga o "copiado" — ele conta o que **acabou** de acontecer.
      copiedSlot: clearCopied ? null : copiedSlot ?? this.copiedSlot,
      undoableDelete: undoableDelete,
    );
  }
}
