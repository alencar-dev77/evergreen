import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../data/clipboard_repository.dart';
import '../../data/clipboard_watcher.dart';
import '../../data/pin_settings_repository.dart';
import '../../models/clipboard_item.dart';
import '../../models/pin_quick_shortcut.dart';
import 'pin_overlay_state.dart';

final pinOverlayViewModelProvider =
    NotifierProvider<PinOverlayViewModel, PinOverlayState>(
  PinOverlayViewModel.new,
);

/// Orquestra o histórico da área de transferência exibido no overlay.
///
/// Mantém a lista completa em memória e recalcula a filtragem localmente: com
/// algumas centenas de itens isso é instantâneo e evita ir ao banco a cada
/// tecla digitada.
class PinOverlayViewModel extends Notifier<PinOverlayState> {
  late final ClipboardRepository _repository;
  late final ClipboardWatcher _watcher;
  late final PinSettingsRepository _settings;

  StreamSubscription<String>? _watchSubscription;

  List<ClipboardItem> _allItems = const [];

  @override
  PinOverlayState build() {
    _repository = ref.watch(clipboardRepositoryProvider);
    _watcher = ref.watch(clipboardWatcherProvider);
    _settings = ref.watch(pinSettingsRepositoryProvider);

    ref.onDispose(() => _watchSubscription?.cancel());

    return PinOverlayState();
  }

  /// Liga a captura da área de transferência. Chamado uma única vez, na
  /// inicialização do app — a captura roda mesmo com o overlay fechado.
  void startWatching() {
    _watchSubscription ??= _watcher.onCopy.listen(_onClipboardChanged);
    _watcher.start();
    load();
  }

  /// Recarrega o histórico do banco.
  void load() {
    _allItems = _repository.loadAll();
    _emitResults(resetSelection: true);
  }

  /// Prepara o overlay para ser exibido: limpa a busca e recarrega a lista.
  void prepareForOpen() {
    state = state.copyWith(query: '');
    load();
  }

  void search(String query) {
    state = state.copyWith(query: query);
    _emitResults(resetSelection: true);
  }

  /// Move a seleção com ↑/↓, parando nas extremidades da lista.
  void moveSelection(int delta) {
    if (state.results.isEmpty) return;

    final next = (state.selectedIndex + delta).clamp(0, state.results.length - 1);
    if (next == state.selectedIndex) return;

    state = state.copyWith(selectedIndex: next);
  }

  /// Reordena o fixado selecionado dentro do grupo (`⌥↑` / `⌥↓`).
  ///
  /// Troca de lugar com o vizinho **visível**: com uma busca ativa o grupo está
  /// filtrado, e o que a pessoa vê acontecer é o item passar por cima de quem
  /// estava ao lado dele na tela. Nas pontas do grupo o atalho não faz nada —
  /// sair dos fixados por baixo significaria desafixar, que é trabalho do ⌘P.
  void movePinnedSelection(int delta) {
    if (!state.canMoveSelectedPinned) return;

    final item = state.selectedItem!;
    final pinned = state.pinned;
    final index = pinned.indexWhere((it) => it.id == item.id);
    if (index < 0) return;

    final target = index + delta;
    if (target < 0 || target >= pinned.length) return;

    final id = item.id;
    final targetId = pinned[target].id;
    if (id == null || targetId == null) return;

    _repository.swapPinnedOrder(id, targetId);
    _allItems = _repository.loadAll();

    // Sem `preferredIndex`: a seleção segue o item pelo id, que é o ponto —
    // quem se move é a linha, não o cursor.
    _emitResults();
  }

  void selectItem(ClipboardItem item) {
    final index = state.results.indexOf(item);
    if (index < 0) return;
    state = state.copyWith(selectedIndex: index);
  }

  /// Devolve o item selecionado à área de transferência.
  ///
  /// Retorna `false` se não havia seleção, para que a view saiba que não deve
  /// fechar o overlay.
  Future<bool> copySelected() async {
    final item = state.selectedItem;
    if (item == null) return false;

    await copyItem(item);
    return true;
  }

  /// Copia o item alcançado por `⌘N` / `⌥N`.
  ///
  /// Retorna `false` quando o slot está vazio — a view usa isso para não fechar
  /// o overlay à toa se o usuário apertar um número que não existe na lista.
  Future<bool> copyByShortcut(PinShortcutGroup group, int number) async {
    final item = state.itemForShortcut(group, number);
    if (item == null) return false;

    await copyItem(item);
    return true;
  }

  /// Fixa ou desafixa o item selecionado (`⌘P`).
  void togglePinSelected() {
    final item = state.selectedItem;
    if (item == null) return;

    togglePin(item);
  }

  /// Apaga o item selecionado (`⌘⌫`).
  void deleteSelected() {
    final item = state.selectedItem;
    if (item == null) return;

    delete(item);
  }

  /// Diz se o item selecionado deve ser colado automaticamente no app anterior.
  ///
  /// Relê as preferências do disco antes de responder: o toggle vive no Hub,
  /// que roda em outro engine, então o cache em memória deste engine pode estar
  /// defasado.
  Future<bool> shouldAutoPaste() async {
    await _settings.reload();
    return _settings.load().autoPaste;
  }

  Future<void> copyItem(ClipboardItem item) async {
    await Clipboard.setData(ClipboardData(text: item.content));

    // Sem isso a captura leria a nossa própria escrita como uma cópia nova.
    // Aguardado de propósito: é o que garante que a marcação chegue ao lado
    // nativo antes do próximo ciclo de leitura do pasteboard.
    await _watcher.acknowledge(item.content);

    _repository.upsert(item.copyWith(copiedAt: DateTime.now()));
    _allItems = _repository.loadAll();
    _emitResults();
  }

  void togglePin(ClipboardItem item) {
    final id = item.id;
    if (id == null) return;

    _repository.setPinned(id, isPinned: !item.isPinned);
    _allItems = _repository.loadAll();
    _emitResults();
  }

  /// Guarda o apelido do item — texto em branco tira o que havia.
  ///
  /// Só toca o banco quando o texto muda de verdade: o campo confirma sozinho
  /// ao perder o foco, então fechar o overlay sem editar nada passaria por aqui
  /// a cada abertura.
  void setAlias(ClipboardItem item, String alias) {
    final id = item.id;
    if (id == null) return;

    final trimmed = alias.trim();
    if (trimmed == (item.alias?.trim() ?? '')) return;

    _repository.setAlias(id, trimmed);
    _allItems = _repository.loadAll();
    _emitResults();
  }

  void delete(ClipboardItem item) {
    final id = item.id;
    if (id == null) return;

    _repository.delete(id);
    _allItems = _repository.loadAll();

    // Mantém a seleção na mesma posição da lista, que agora aponta para o item
    // seguinte — o comportamento esperado ao apagar vários itens em sequência.
    _emitResults(preferredIndex: state.selectedIndex);
  }

  void _onClipboardChanged(String content) {
    _repository.upsert(ClipboardItem.capture(content));
    _repository.trimHistory(_settings.load().historyLimit);

    _allItems = _repository.loadAll();
    _emitResults();
  }

  /// Reaplica o filtro sobre [_allItems] e ajusta a seleção.
  void _emitResults({bool resetSelection = false, int? preferredIndex}) {
    final results = _allItems
        .where((item) => item.matches(state.query))
        .toList(growable: false);

    state = state.copyWith(
      results: results,
      isLoading: false,
      selectedIndex: _resolveSelection(
        results,
        resetSelection: resetSelection,
        preferredIndex: preferredIndex,
      ),
    );
  }

  int _resolveSelection(
    List<ClipboardItem> results, {
    required bool resetSelection,
    int? preferredIndex,
  }) {
    if (results.isEmpty) return -1;
    if (resetSelection) return 0;

    if (preferredIndex != null) {
      return preferredIndex.clamp(0, results.length - 1);
    }

    // Preserva o item selecionado mesmo que ele tenha mudado de posição.
    final current = state.selectedItem;
    if (current != null) {
      final index = results.indexWhere((item) => item.id == current.id);
      if (index >= 0) return index;
    }

    return state.selectedIndex.clamp(0, results.length - 1);
  }
}
