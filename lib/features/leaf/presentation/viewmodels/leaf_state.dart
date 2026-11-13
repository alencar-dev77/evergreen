import '../../models/leaf_note.dart';

/// Estado da parede: o que está colado nela, o que está selecionado e o que
/// está sendo escrito.
class LeafState {
  const LeafState({
    this.notes = const <LeafNote>[],
    this.selectedSlot,
    this.editingSlot,
    this.copiedSlot,
    this.remindingSlot,
    this.undoableDeletes = const <LeafNote>[],
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

  /// Vaga cujo cartão virou o seletor de lembrete.
  ///
  /// Como a edição, acontece **no lugar do cartão**: nada abre por cima da
  /// parede e nada muda de tamanho. Uma vaga por vez, e nunca junto com a
  /// edição — são dois usos diferentes do mesmo teclado.
  final int? remindingSlot;

  /// Os cartões arrancados da parede, do mais antigo para o mais recente —
  /// `⌘Z` devolve sempre o último.
  ///
  /// **Uma pilha, e não um cartão só.** Esvaziar o campo apaga a anotação, e é
  /// a forma mais fácil de apagar sem querer: quem faz isso duas vezes seguidas
  /// — o gesto que mais precisa de desfazer — perdia a primeira, porque a
  /// segunda tomava o lugar dela.
  ///
  /// **E sobrevive ao painel fechar.** Vive na memória do engine da janela 0,
  /// que é o app inteiro, não o painel: fechar o Leaf é a coisa mais natural a
  /// fazer depois de apagar por engano — o painel some ao perder o foco —, e
  /// era exatamente aí que a oferta morria. Reabrir devolve a pilha
  /// ([LeafViewModel.prepareForOpen] a preserva); sair do aplicativo, não, e
  /// aí é a mesma regra de antes: o desfazer é para o engano de um minuto
  /// atrás, não para ressuscitar o que se jogou fora ontem.
  ///
  /// Guarda no máximo [LeafNote.maxNotes]: nove é o que cabe na parede, e uma
  /// pilha sem teto seria uma lixeira que ninguém pediu.
  final List<LeafNote> undoableDeletes;

  /// O próximo a voltar, ou `null` se não há nenhum.
  LeafNote? get undoableDelete =>
      undoableDeletes.isEmpty ? null : undoableDeletes.last;

  bool get isEmpty => notes.isEmpty;

  bool get isFull => notes.length >= LeafNote.maxNotes;

  bool get isEditing => editingSlot != null;

  bool get isReminding => remindingSlot != null;

  /// A edição em curso é de uma anotação que ainda não existe no banco.
  bool get isDraft => editingSlot != null && noteAt(editingSlot!) == null;

  /// Há um cartão para devolver à parede, e vaga onde devolvê-lo.
  ///
  /// A parede cheia tira a oferta em vez de prometer o que não cabe: entre
  /// apagar e desfazer, a pessoa pode ter escrito outra anotação.
  bool get canUndoDelete => undoableDeletes.isNotEmpty && !isFull;

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

  /// A primeira vaga livre — onde o `⌘+` faz a anotação nascer —, ou `null`
  /// com a parede cheia.
  ///
  /// A parede pode ter buraco (ver [LeafNote.slot]): a livre não é mais a
  /// seguinte à última, e sim a de menor número que ninguém ocupa.
  int? get firstFreeSlot {
    for (final slot in LeafNote.slots) {
      if (noteAt(slot) == null) return slot;
    }
    return null;
  }

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

  /// A última vaga que o teclado alcança — a nona, sempre.
  ///
  /// Com a anotação podendo nascer em qualquer vaga livre (#174), toda vaga
  /// desenhada tem o que fazer com o Enter, e a seta anda pela parede inteira.
  int get lastSelectableSlot => LeafNote.maxNotes;

  LeafState copyWith({
    List<LeafNote>? notes,
    int? selectedSlot,
    int? editingSlot,
    int? copiedSlot,
    int? remindingSlot,
    List<LeafNote>? undoableDeletes,
    bool clearSelection = false,
    bool clearEditing = false,
    bool clearCopied = false,
    bool clearReminding = false,
  }) {
    return LeafState(
      notes: notes ?? this.notes,
      selectedSlot: clearSelection ? null : selectedSlot ?? this.selectedSlot,
      editingSlot: clearEditing ? null : editingSlot ?? this.editingSlot,
      // O aviso morre no gesto seguinte: escrever, apagar ou reabrir o painel
      // apaga o "copiado" — ele conta o que **acabou** de acontecer.
      copiedSlot: clearCopied ? null : copiedSlot ?? this.copiedSlot,
      remindingSlot: clearReminding
          ? null
          : remindingSlot ?? this.remindingSlot,
      undoableDeletes: undoableDeletes ?? this.undoableDeletes,
    );
  }
}
