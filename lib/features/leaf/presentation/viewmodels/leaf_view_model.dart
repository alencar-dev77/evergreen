import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../core/system/notification_service.dart';
import '../../data/leaf_repository.dart';
import '../../models/leaf_note.dart';
import '../../models/leaf_notifications.dart';
import '../../models/leaf_reminder.dart';
import 'leaf_state.dart';

final leafViewModelProvider = NotifierProvider<LeafViewModel, LeafState>(
  LeafViewModel.new,
);

/// A parede de anotações do Leaf.
///
/// Vive no engine da janela flutuante, como os outros módulos — mas aqui isso
/// vale menos que no Focus e no Awake: o Leaf não tem nada correndo em segundo
/// plano, e o que ele guarda está no banco antes de o painel fechar.
class LeafViewModel extends Notifier<LeafState> {
  late final LeafRepository _repository;
  late final DateTime Function() _now;

  @override
  LeafState build() {
    _repository = ref.watch(leafRepositoryProvider);
    _now = ref.watch(clockProvider);

    final notes = _loadNotes();
    return LeafState(notes: notes, selectedSlot: _firstSlotOf(notes));
  }

  /// Lido na hora, e não no `build`: o Leaf só fala com o centro de
  /// notificações quando alguém marca um lembrete.
  NotificationService get _notifications =>
      ref.read(notificationServiceProvider);

  /// A parede como está no banco, sem os lembretes que já tocaram.
  ///
  /// Um lembrete que passou cumpriu o papel dele: deixá-lo no cartão faria o
  /// rodapé mostrar uma hora que já foi, e a pessoa se perguntar se ele ainda
  /// vai tocar.
  List<LeafNote> _loadNotes() {
    final now = _now();

    return [
      for (final note in _repository.loadAll())
        if (note.remindAt != null && note.reminderAfter(now) == null)
          _withoutReminder(note)
        else
          note,
    ];
  }

  LeafNote _withoutReminder(LeafNote note) {
    _repository.setReminder(note.id, null);
    return note.copyWith(clearReminder: true);
  }

  /// Relê a parede antes de o painel aparecer.
  ///
  /// O Hub roda em outro engine e pode ter esvaziado o mural desde a última
  /// vez; e qualquer edição pendente morre aqui, porque o painel não deve
  /// reabrir dentro de um campo de texto que a pessoa já esqueceu que existia.
  ///
  /// **A pilha do desfazer atravessa.** Ela é a única coisa aqui que não está
  /// no banco, e fechar o painel é o gesto seguinte mais provável depois de
  /// apagar por engano — o Leaf some sozinho ao perder o foco. Perdê-la na
  /// reabertura transformava o `⌘Z` numa promessa que quase nunca dava tempo de
  /// cobrar. Ver [LeafState.undoableDeletes].
  Future<void> prepareForOpen() async {
    final notes = _loadNotes();

    state = LeafState(
      notes: notes,
      selectedSlot: _firstSlotOf(notes),
      undoableDeletes: state.undoableDeletes,
    );
  }

  /// `⌘+`: abre um cartão em branco na primeira vaga livre.
  ///
  /// Com a parede cheia não faz nada — e é a própria grade, com as nove vagas
  /// ocupadas e sem o cartão de "nova", que explica o silêncio.
  void startNote() {
    final slot = state.firstFreeSlot;
    if (slot == null) return;

    state = state.copyWith(
      selectedSlot: slot,
      editingSlot: slot,
      clearReminding: true,
    );
  }

  /// Enter sobre a seleção: edita a anotação, ou cria uma se a vaga é a vazia.
  void editSelected() {
    final slot = state.selectedSlot;
    if (slot == null) return;

    if (state.noteAt(slot) == null) {
      startNote();
      return;
    }

    state = state.copyWith(editingSlot: slot, clearReminding: true);
  }

  void editSlot(int slot) {
    if (state.noteAt(slot) == null) {
      // Vaga vazia que não é a próxima da fila não abre nada: a parede não tem
      // buraco, e `⌥8` com cinco cartões colados não pode fazer o sexto nascer
      // no oitavo lugar.
      if (slot != state.firstFreeSlot) return;

      state = state.copyWith(selectedSlot: slot, clearCopied: true);
      startNote();
      return;
    }

    state = state.copyWith(
      selectedSlot: slot,
      editingSlot: slot,
      clearCopied: true,
      clearReminding: true,
    );
  }

  /// `⌘L`: o cartão selecionado vira o seletor de lembrete.
  void remindSelected() {
    final slot = state.selectedSlot;
    if (slot != null) remindSlot(slot);
  }

  /// O sino do cartão: troca a face do cartão pelo seletor. Vaga vazia não
  /// tem o que lembrar.
  void remindSlot(int slot) {
    if (state.noteAt(slot) == null || state.isEditing) return;

    state = state.copyWith(
      selectedSlot: slot,
      remindingSlot: slot,
      clearCopied: true,
    );
  }

  /// `⌘B`: põe o cartão selecionado sob o vidro fosco, ou o tira de lá.
  void toggleHiddenSelected() {
    final slot = state.selectedSlot;
    if (slot != null) toggleHidden(slot);
  }

  /// O olho do cartão.
  ///
  /// Um lembrete marcado é reagendado junto: o texto que a notificação mostra
  /// depende de o cartão estar ou não sob o vidro.
  void toggleHidden(int slot) {
    final note = state.noteAt(slot);
    if (note == null) return;

    final hidden = !note.isHidden;
    _repository.setHidden(note.id, hidden: hidden);

    final updated = note.copyWith(isHidden: hidden);
    final reminder = updated.reminderAfter(_now());
    if (reminder != null) {
      unawaited(
        _notifications.schedule(LeafNotifications.of(updated), reminder),
      );
    }

    state = state.copyWith(
      selectedSlot: slot,
      notes: [
        for (final other in state.notes) other.id == note.id ? updated : other,
      ],
    );
  }

  /// Esc no seletor: o cartão volta a ser cartão, com o lembrete que já tinha.
  void cancelReminder() => state = state.copyWith(clearReminding: true);

  /// Marca o lembrete do cartão aberto no seletor e o agenda no sistema.
  void setReminder(DateTime at) {
    final note = state.noteAt(state.remindingSlot ?? -1);
    if (note == null || !at.isAfter(_now())) return;

    _applyReminder(note, at);
    state = state.copyWith(clearReminding: true);
  }

  /// Enter no seletor: só confirma o que o campo entendeu. O que ele não
  /// entendeu fica na tela, com a prévia dizendo isso — fechar em silêncio
  /// faria a pessoa achar que marcou.
  void setReminderFromText(String text) {
    final at = LeafReminder.parse(text, _now());
    if (at != null) setReminder(at);
  }

  /// Tira o lembrete do cartão aberto no seletor.
  void removeReminder() {
    final note = state.noteAt(state.remindingSlot ?? -1);
    if (note == null) return;

    _applyReminder(note, null);
    state = state.copyWith(clearReminding: true);
  }

  /// "Adiar 30 min", da notificação.
  void snooze(int noteId) {
    final note = _noteById(noteId);
    if (note == null) return;

    _applyReminder(note, _now().add(LeafNotifications.snoozeBy));
  }

  /// O clique na notificação: o painel abre com o cartão lembrado escolhido.
  void selectNote(int noteId) {
    final note = _noteById(noteId);
    if (note == null) return;

    state = state.copyWith(selectedSlot: note.slot, clearCopied: true);
  }

  /// Põe no sistema todo lembrete que ainda vai tocar.
  ///
  /// Chamado na abertura do app e quando o Leaf é religado: agendar de novo o
  /// que já está agendado é inofensivo (mesmo id substitui), e é o que traz de
  /// volta os lembretes que o desligar do módulo tirou.
  void scheduleReminders() {
    final now = _now();
    for (final note in state.notes) {
      final at = note.reminderAfter(now);
      if (at != null) {
        unawaited(_notifications.schedule(LeafNotifications.of(note), at));
      }
    }
  }

  /// Tira do sistema os lembretes da parede, **sem esquecê-los**: é o Leaf
  /// sendo desligado, e religá-lo devolve cada um ([scheduleReminders]).
  void unscheduleReminders() {
    unawaited(
      _notifications.cancel([
        for (final note in state.notes)
          if (note.remindAt != null) LeafNotifications.idOf(note.id),
      ]),
    );
  }

  /// Grava, agenda (ou cancela) e põe na parede o lembrete de [note].
  void _applyReminder(LeafNote note, DateTime? at) {
    _repository.setReminder(note.id, at);

    final updated = at == null
        ? note.copyWith(clearReminder: true)
        : note.copyWith(remindAt: at);

    unawaited(
      at == null
          ? _notifications.cancel([LeafNotifications.idOf(note.id)])
          : _notifications.schedule(LeafNotifications.of(updated), at),
    );

    state = state.copyWith(
      notes: [
        for (final other in state.notes) other.id == note.id ? updated : other,
      ],
    );
  }

  LeafNote? _noteById(int id) {
    for (final note in state.notes) {
      if (note.id == id) return note;
    }
    return null;
  }

  /// Guarda o que foi escrito e sai do campo.
  ///
  /// Texto em branco não vira anotação, e apaga a que existia: um cartão vazio
  /// na parede não diz nada a ninguém, e esvaziá-lo é a forma mais direta de
  /// dizer "isso aqui já era". Segue a convenção do apelido do Pin — sair do
  /// campo guarda, por qualquer caminho.
  void commitEdit(String raw) {
    final slot = state.editingSlot;
    if (slot == null) return;

    final content = LeafNote.sanitize(raw);
    final existing = state.noteAt(slot);

    if (content.isEmpty) {
      if (existing != null) _remove(existing);
      state = state.copyWith(clearEditing: true);
      return;
    }

    if (existing == null) {
      final created = _repository.create(
        slot: slot,
        content: content,
        createdAt: _now(),
      );
      // A oferta de desfazer sobrevive a isto: o cartão devolvido volta para a
      // vaga dele e empurra os outros para baixo, e escrever uma anotação nova
      // não é motivo para perder a que se apagou por engano. Quem encerra a
      // oferta é a parede cheia — ver [LeafState.canUndoDelete].
      state = state.copyWith(
        notes: _sorted([...state.notes, created]),
        clearEditing: true,
      );
      return;
    }

    // Sair do campo sem ter mudado uma letra não é uma edição — e datar como
    // tal envelheceria a parede inteira a cada abertura do painel, porque o
    // campo confirma sozinho ao perder o foco.
    if (existing.content == content) {
      state = state.copyWith(clearEditing: true);
      return;
    }

    final at = _now();
    _repository.updateContent(existing.id, content, at: at);

    // O lembrete leva o texto junto: reescrever o cartão e ser lembrado da
    // versão antiga seria receber o recado errado na hora certa.
    final reminder = existing.reminderAfter(at);
    if (reminder != null) {
      unawaited(
        _notifications.schedule(
          LeafNotifications.of(existing.copyWith(content: content)),
          reminder,
        ),
      );
    }

    state = state.copyWith(
      notes: _sorted([
        for (final note in state.notes)
          note.slot == slot
              ? note.copyWith(content: content, updatedAt: at)
              : note,
      ]),
      clearEditing: true,
    );
  }

  /// `⌘Z`: devolve à parede o último cartão apagado, na vaga em que ele estava.
  ///
  /// Um cartão por vez, e só enquanto o painel está aberto — ver
  /// [LeafState.undoableDelete]. É o que torna o apagar do Leaf uma ação sem
  /// pergunta: esvaziar o campo apaga a anotação, e essa é a forma mais direta
  /// de dizer "isso aqui já era", mas também a mais fácil de fazer sem querer.
  void undoDelete() {
    final note = state.undoableDelete;
    if (!state.canUndoDelete || note == null) return;

    // O que sobra da pilha depois de tirar este — os enganos anteriores a ele
    // continuam ao alcance de um `⌘Z` seguinte.
    final rest = state.undoableDeletes.sublist(
      0,
      state.undoableDeletes.length - 1,
    );

    // Nasce na primeira vaga livre porque a vaga é única no banco, e a de
    // origem está ocupada por quem subiu no lugar dele. O lugar certo vem da
    // renumeração, logo abaixo.
    final restored = _repository.create(
      slot: state.notes.length + 1,
      content: note.content,
      createdAt: note.createdAt,
      // A data volta como estava: um cartão devolvido à parede não é um cartão
      // novo, e apresentá-lo como "agora" apagaria a única pista de quando
      // aquele recado foi escrito.
      updatedAt: note.updatedAt,
      // O lembrete também — se ainda não passou da hora dele.
      remindAt: note.reminderAfter(_now()),
      // E o vidro: devolver à parede um segredo à vista seria o desfazer
      // criando um vazamento que o apagar não tinha.
      isHidden: note.isHidden,
    );

    final reminder = restored.remindAt;
    if (reminder != null) {
      unawaited(
        _notifications.schedule(LeafNotifications.of(restored), reminder),
      );
    }

    final ordered = [...state.notes]
      ..insert((note.slot - 1).clamp(0, state.notes.length), restored);

    final resettled = <LeafNote>[
      for (var i = 0; i < ordered.length; i++) ordered[i].copyWith(slot: i + 1),
    ];

    _repository.reassignSlots([for (final note in resettled) note.id]);

    state = LeafState(
      notes: resettled,
      // A seleção vai para o cartão que acabou de voltar: é onde o olho está.
      selectedSlot: note.slot.clamp(1, resettled.length),
      undoableDeletes: rest,
    );
  }

  /// Esc: desfaz o que foi digitado. Um rascunho simplesmente não chega a
  /// existir.
  void cancelEdit() => state = state.copyWith(clearEditing: true);

  /// `⌘⌫`: tira o cartão da parede, que encolhe junto.
  void deleteSelected() {
    final note = state.selectedNote;
    if (note == null) return;

    _remove(note);
  }

  /// Copia a anotação da vaga e diz se havia algo lá.
  ///
  /// **Não fecha o painel.** Quem copia da parede costuma copiar dois seguidos
  /// — o endereço e o telefone, o comando e a chave —, e fechar a cada tecla
  /// obrigava a reabrir o mural para a segunda. O que o sumiço do painel dizia
  /// ("copiei") passou a ser dito pelo aviso no cartão.
  ///
  /// A resposta continua existindo para o `7` numa vaga vazia não anunciar uma
  /// cópia que não houve.
  Future<bool> copySlot(int slot) async {
    final note = state.noteAt(slot);
    if (note == null) return false;

    await Clipboard.setData(ClipboardData(text: note.content));
    state = state.copyWith(selectedSlot: slot, copiedSlot: slot);

    return true;
  }

  Future<bool> copySelected() async {
    final slot = state.selectedSlot;
    return slot == null ? false : copySlot(slot);
  }

  void selectSlot(int slot) => state = state.copyWith(selectedSlot: slot);

  /// Move a seleção pela grade, em duas dimensões.
  ///
  /// Para nas bordas em vez de dar a volta: a parede é pequena e está inteira à
  /// vista, e uma seta que salta do primeiro cartão para o último faria a
  /// seleção passar direto pelo que a pessoa estava procurando.
  void moveSelection({int columns = 0, int rows = 0}) {
    final last = state.lastSelectableSlot;
    if (last == 0) return;

    final current = state.selectedSlot ?? 1;
    final index = current - 1;
    final column = index % LeafNote.columns;
    final row = index ~/ LeafNote.columns;

    final lastRow = (last / LeafNote.columns).ceil() - 1;
    final nextColumn = (column + columns).clamp(0, LeafNote.columns - 1);
    final nextRow = (row + rows).clamp(0, lastRow);

    // A última linha pode estar pela metade: descer para uma coluna que ainda
    // não existe encosta no último cartão dela, em vez de não fazer nada.
    final slot = (nextRow * LeafNote.columns + nextColumn + 1).clamp(1, last);

    state = state.copyWith(selectedSlot: slot);
  }

  /// Tira a anotação e fecha o buraco que ela deixou.
  ///
  /// As sobreviventes sobem uma vaga cada, e a parede diminui de tamanho — é o
  /// que se espera de um mural do qual se acabou de arrancar um papel. O preço
  /// é que os números depois da vaga apagada mudam; em uma parede de nove
  /// cartões, todos visíveis, é um preço barato.
  void _remove(LeafNote note) {
    _repository.delete(note.id);

    // Cartão arrancado não lembra de nada. Se o `⌘Z` o devolver, o lembrete
    // volta com ele.
    if (note.remindAt != null) {
      unawaited(_notifications.cancel([LeafNotifications.idOf(note.id)]));
    }

    final remaining = [
      for (final other in state.notes)
        if (other.id != note.id) other,
    ];

    final resettled = <LeafNote>[
      for (var i = 0; i < remaining.length; i++)
        remaining[i].copyWith(slot: i + 1),
    ];

    _repository.reassignSlots([for (final note in resettled) note.id]);

    state = LeafState(
      notes: resettled,
      // A seleção fica na vaga: quem estava na de baixo subiu para ela, que é o
      // cartão que o olho já está encarando. Na última vaga não há quem suba —
      // a seleção recua para o fim da parede.
      selectedSlot: resettled.isEmpty
          ? null
          : note.slot.clamp(1, resettled.length + 1),
      // O cartão vai para o topo da pilha do `⌘Z`. Empilhar, e não substituir:
      // apagar dois seguidos é justamente o caso que mais precisa de desfazer.
      undoableDeletes: _pushed(state.undoableDeletes, note),
    );
  }

  /// A pilha do desfazer com mais um cartão em cima, no teto de vagas da parede.
  ///
  /// O mais antigo é quem cai: uma pilha cheia significa que a pessoa apagou
  /// nove cartões desde que abriu o aplicativo, e o décimo `⌘Z` alcançaria algo
  /// de que ela não lembra mais.
  static List<LeafNote> _pushed(List<LeafNote> stack, LeafNote note) {
    final next = [...stack, note];

    return next.length <= LeafNote.maxNotes
        ? next
        : next.sublist(next.length - LeafNote.maxNotes);
  }

  static List<LeafNote> _sorted(List<LeafNote> notes) =>
      notes..sort((a, b) => a.slot.compareTo(b.slot));

  static int? _firstSlotOf(List<LeafNote> notes) =>
      notes.isEmpty ? 1 : notes.first.slot;
}
