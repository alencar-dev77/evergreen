import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../models/clipboard_item.dart';
import '../../models/pin_quick_shortcut.dart';

/// Estado renderizável do overlay do Pin.
///
/// Contém apenas o que a view desenha: a lista já filtrada, dividida em grupos,
/// e a seleção. A lista completa vive na ViewModel — a view nunca precisa saber
/// que ela existe.
@immutable
class PinOverlayState {
  const PinOverlayState._({
    required this.results,
    required this.pinned,
    required this.recent,
    required this.query,
    required this.selectedIndex,
    required this.isLoading,
    required Map<int, PinQuickShortcut> shortcutsByItemId,
  }) : _shortcutsByItemId = shortcutsByItemId;

  /// Divide [results] em grupos e distribui os atalhos numéricos.
  ///
  /// Tudo é calculado uma única vez, aqui: a lista é reconstruída a cada tecla
  /// digitada na busca, e refazer esses recortes durante o `build` colocaria
  /// trabalho por item no caminho da renderização.
  factory PinOverlayState({
    List<ClipboardItem> results = const [],
    String query = '',
    int selectedIndex = -1,
    bool isLoading = true,
  }) {
    final pinned = <ClipboardItem>[];
    final recent = <ClipboardItem>[];

    for (final item in results) {
      (item.isPinned ? pinned : recent).add(item);
    }

    final shortcuts = <int, PinQuickShortcut>{};
    _assignShortcuts(pinned, PinShortcutGroup.pinned, shortcuts);
    _assignShortcuts(recent, PinShortcutGroup.recent, shortcuts);

    return PinOverlayState._(
      results: results,
      pinned: List.unmodifiable(pinned),
      recent: List.unmodifiable(recent),
      query: query,
      selectedIndex: selectedIndex,
      isLoading: isLoading,
      shortcutsByItemId: Map.unmodifiable(shortcuts),
    );
  }

  static void _assignShortcuts(
    List<ClipboardItem> group,
    PinShortcutGroup kind,
    Map<int, PinQuickShortcut> target,
  ) {
    final slots = math.min(group.length, PinQuickShortcut.slotsPerGroup);

    for (var index = 0; index < slots; index++) {
      final id = group[index].id;
      if (id == null) continue;

      target[id] = PinQuickShortcut(group: kind, number: index + 1);
    }
  }

  /// Itens que casam com [query], fixados primeiro.
  final List<ClipboardItem> results;

  /// Fixados, na ordem em que foram fixados.
  final List<ClipboardItem> pinned;

  /// Não fixados, do mais recente para o mais antigo.
  final List<ClipboardItem> recent;

  final String query;

  /// Índice da seleção dentro de [results]; -1 quando não há nada selecionado.
  final int selectedIndex;

  final bool isLoading;

  final Map<int, PinQuickShortcut> _shortcutsByItemId;

  ClipboardItem? get selectedItem {
    if (selectedIndex < 0 || selectedIndex >= results.length) return null;
    return results[selectedIndex];
  }

  /// Não há nada para mostrar — nem histórico, nem resultado de busca.
  bool get isEmpty => !isLoading && results.isEmpty;

  /// A lista está vazia porque a busca não encontrou nada (e não porque o
  /// histórico está vazio). Muda a mensagem do estado vazio.
  bool get isEmptyBecauseOfSearch => isEmpty && query.isNotEmpty;

  /// Atalho numérico do item, se ele estiver entre os primeiros do seu grupo.
  PinQuickShortcut? shortcutFor(ClipboardItem item) {
    final id = item.id;
    return id == null ? null : _shortcutsByItemId[id];
  }

  /// Item alcançado por um atalho numérico, ou `null` se o slot está vazio.
  ClipboardItem? itemForShortcut(PinShortcutGroup group, int number) {
    if (number < 1 || number > PinQuickShortcut.slotsPerGroup) return null;

    final items = group == PinShortcutGroup.pinned ? pinned : recent;
    return number > items.length ? null : items[number - 1];
  }

  PinOverlayState copyWith({
    List<ClipboardItem>? results,
    String? query,
    int? selectedIndex,
    bool? isLoading,
  }) {
    return PinOverlayState(
      results: results ?? this.results,
      query: query ?? this.query,
      selectedIndex: selectedIndex ?? this.selectedIndex,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}
