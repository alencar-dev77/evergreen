import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../models/clipboard_item.dart';
import '../../models/clipboard_item_type.dart';
import '../../models/pin_quick_shortcut.dart';
import '../../models/tax_id.dart';

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
    required this.typeFilter,
    required this.availableTypes,
    required this.selectedIndex,
    required this.isLoading,
    required this.generatedTaxId,
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
    ClipboardItemType? typeFilter,
    List<ClipboardItemType> availableTypes = const [],
    int selectedIndex = -1,
    bool isLoading = true,
    String? generatedTaxId,
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
      typeFilter: typeFilter,
      availableTypes: List.unmodifiable(availableTypes),
      selectedIndex: selectedIndex,
      isLoading: isLoading,
      generatedTaxId: generatedTaxId,
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

  /// Tipo escolhido na fila de pílulas; `null` é "Tudo".
  final ClipboardItemType? typeFilter;

  /// Tipos que existem no histórico agora, na ordem do enum.
  ///
  /// A fila de pílulas sai daqui, e não de `ClipboardItemType.values`: um
  /// filtro que não tem o que mostrar é uma promessa vazia — e as sete pílulas
  /// de uma vez não caberiam nos 420px do painel.
  final List<ClipboardItemType> availableTypes;

  /// Índice da seleção dentro de [results].
  ///
  /// `-1` tem dois sentidos, e o que os separa é [hasGenerator]: com a linha do
  /// gerador na tela, `-1` **é** essa linha, que fica acima do primeiro item;
  /// sem ela, `-1` continua sendo "nada selecionado". Os dois convivem porque
  /// [selectedItem] devolve `null` nos dois casos — é o que faz `⌘P`, `⌘R`,
  /// `⌘⌫` e o `tab` saírem sozinhos, sem nenhum deles precisar saber que o
  /// gerador existe.
  final int selectedIndex;

  final bool isLoading;

  /// O documento sorteado que a linha do gerador exibe; `null` quando a linha
  /// não está na tela.
  ///
  /// Vive no estado, e não no widget, porque `⌘G` sorteia outro e a busca não
  /// pode sortear nenhum: quem decide quando o número muda é a ViewModel.
  final String? generatedTaxId;

  final Map<int, PinQuickShortcut> _shortcutsByItemId;

  ClipboardItem? get selectedItem {
    if (selectedIndex < 0 || selectedIndex >= results.length) return null;
    return results[selectedIndex];
  }

  /// O selecionado pode ser reordenado com `⌥↑`/`⌥↓`.
  ///
  /// Só os fixados têm ordem própria — os recentes seguem a data de cópia, e
  /// movê-los duraria até a cópia seguinte. Um fixado sozinho também não tem
  /// com quem trocar de lugar, e nesse caso o rodapé não anuncia o atalho.
  bool get canMoveSelectedPinned {
    final item = selectedItem;
    return item != null && item.isPinned && pinned.length > 1;
  }

  /// Qual documento a linha do gerador sorteia — o do filtro aberto.
  ///
  /// Sai do filtro, e não de um campo próprio, porque é o filtro que põe a
  /// linha ali: "Gerar CPF" dentro da pílula CPF, "Gerar CNPJ" dentro da de
  /// CNPJ, e nenhuma linha em nenhuma das outras.
  TaxIdKind? get generatorKind => typeFilter?.taxIdKind;

  /// A linha "Gerar CPF" (ou "Gerar CNPJ") está na lista.
  bool get hasGenerator => generatedTaxId != null;

  /// A seleção está na linha do gerador — ver [selectedIndex].
  bool get isGeneratorSelected => hasGenerator && selectedIndex == -1;

  /// Não há nada para mostrar — nem histórico, nem resultado de busca.
  ///
  /// A linha do gerador conta: com ela na tela há o que fazer ali, e um estado
  /// vazio por cima diria que não há.
  bool get isEmpty => !isLoading && results.isEmpty && !hasGenerator;

  /// A lista está vazia porque a busca ou o filtro não encontraram nada (e não
  /// porque o histórico está vazio). Muda a mensagem do estado vazio.
  bool get isEmptyBecauseOfSearch =>
      isEmpty && (query.isNotEmpty || typeFilter != null);

  /// A fila de pílulas tem o que oferecer.
  ///
  /// Era `availableTypes.length > 1`, com uma razão boa: com um tipo só no
  /// histórico, "Tudo | Textos" eram dois botões para a mesma lista. Deixou de
  /// valer quando o CPF ganhou o gerador dentro dele — a pílula do CPF nunca é
  /// a mesma coisa que "Tudo", nem quando é o único tipo guardado, porque atrás
  /// dela há um número que ainda não existe. E era exatamente esse o caso a
  /// resolver: quem acabou de gerar o primeiro CPF tem um histórico só de CPF,
  /// e a fila sumiria justamente ali, levando o gerador junto.
  bool get hasTypeFilter => availableTypes.isNotEmpty;

  /// As opções da fila, na ordem em que aparecem: "Tudo" e os tipos presentes.
  List<ClipboardItemType?> get typeFilterOptions =>
      <ClipboardItemType?>[null, ...availableTypes];

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

  /// Cópia com campos trocados.
  ///
  /// `typeFilter` e `generatedTaxId` são os dois que não seguem o `?? this`:
  /// `null` neles é um valor — "Tudo" e "sem linha de gerador" —, não "não
  /// mexe". Quem quer preservá-los passa `keepTypeFilter` / `keepGeneratedTaxId`
  /// — que é o padrão.
  PinOverlayState copyWith({
    List<ClipboardItem>? results,
    String? query,
    ClipboardItemType? typeFilter,
    bool keepTypeFilter = true,
    List<ClipboardItemType>? availableTypes,
    int? selectedIndex,
    bool? isLoading,
    String? generatedTaxId,
    bool keepGeneratedTaxId = true,
  }) {
    return PinOverlayState(
      results: results ?? this.results,
      query: query ?? this.query,
      typeFilter: keepTypeFilter ? (typeFilter ?? this.typeFilter) : typeFilter,
      availableTypes: availableTypes ?? this.availableTypes,
      selectedIndex: selectedIndex ?? this.selectedIndex,
      isLoading: isLoading ?? this.isLoading,
      generatedTaxId: keepGeneratedTaxId
          ? (generatedTaxId ?? this.generatedTaxId)
          : generatedTaxId,
    );
  }
}
