/// Os dois grupos da lista, cada um com sua própria camada de atalhos.
///
/// Manter camadas separadas é o que faz `⌘1` significar sempre "a última coisa
/// que copiei", independente de quantos itens estejam fixados no topo.
enum PinShortcutGroup {
  /// Itens fixados — camada `⌥`.
  pinned('⌥'),

  /// Itens recentes — camada `⌘`.
  recent('⌘');

  const PinShortcutGroup(this.symbol);

  /// Símbolo do modificador, exibido no badge do item.
  final String symbol;
}

/// Atalho numérico de acesso rápido a um item da lista.
class PinQuickShortcut {
  const PinQuickShortcut({required this.group, required this.number});

  final PinShortcutGroup group;

  /// Posição dentro do grupo, de 1 a [PinQuickShortcut.slotsPerGroup].
  final int number;

  /// Quantos itens de cada grupo recebem atalho.
  ///
  /// Cinco cobre o uso real sem encher a lista de badges — o resto se alcança
  /// pelas setas ou pela busca.
  static const slotsPerGroup = 5;

  /// Rótulo exibido no badge: `⌘1`, `⌥3`.
  String get label => '${group.symbol}$number';

  @override
  bool operator ==(Object other) =>
      other is PinQuickShortcut &&
      other.group == group &&
      other.number == number;

  @override
  int get hashCode => Object.hash(group, number);
}
