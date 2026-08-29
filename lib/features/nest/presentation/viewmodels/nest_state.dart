import '../../models/nest_destination.dart';
import '../../models/nest_item.dart';
import '../../models/nest_transfer.dart';
import '../../models/nest_transfer_mode.dart';

/// Estado da prateleira: o que está esperando, para onde dá para mandar e o que
/// acabou de acontecer.
class NestState {
  const NestState({
    this.items = const <NestItem>[],
    this.destinations = const <NestDestination>[],
    this.selection = const <int>{},
    this.cursor,
    this.defaultMode = NestTransferMode.copy,
    this.isInvertHeld = false,
    this.isDragOver = false,
    this.lastTransfer,
    this.lastTransferId,
    this.notice,
  });

  /// Os arquivos e pastas na ordem em que chegaram. Quem chegou por último fica
  /// no fim: a prateleira é uma pilha de coisas juntadas, e reordenar por nome
  /// faria o item recém-solto sumir no meio dela.
  final List<NestItem> items;

  /// As pastas favoritas, na ordem dos atalhos `⌘1..⌘9`.
  final List<NestDestination> destinations;

  /// Os itens escolhidos, por posição. **Vazio é o normal.**
  ///
  /// Escolher aqui serve para *estreitar* — levar dois dos cinco para uma pasta
  /// e o resto para outra —, e por isso a prateleira recém-cheia não vem com
  /// nada escolhido: sem escolha, vai a prateleira inteira, que é a promessa do
  /// módulo e o que a barra de dicas diz ("copiar tudo").
  ///
  /// A alternativa — nascer com tudo escolhido — foi desenhada e descartada ao
  /// ver a tela: com todas as linhas em accent, o realce de escolha para de
  /// significar alguma coisa, porque não sobra nada para contrastar com ele. A
  /// lista vira um bloco verde só.
  final Set<int> selection;

  /// Onde o teclado está, e a âncora do `⇧`. `null` com a prateleira vazia.
  final int? cursor;

  /// O que as preferências dizem que acontece ao enviar.
  final NestTransferMode defaultMode;

  /// A modificadora que inverte o modo está pressionada agora.
  ///
  /// É o `⌥`, e não o `⌘` do Finder, porque aqui o `⌘` já é a tecla que escolhe
  /// o destino (`⌘1..⌘9`): a mesma modificadora significando "para onde" e
  /// "de que jeito" no mesmo painel seria uma tecla fazendo duas coisas. O `⌥`
  /// está livre nos dois caminhos — teclado e mouse — e já é, no Pin, a
  /// modificadora que muda o que um número quer dizer.
  final bool isInvertHeld;

  /// Há um arraste pairando sobre o painel.
  final bool isDragOver;

  /// A última transferência, enquanto o `⌘Z` ainda pode desfazê-la.
  ///
  /// Vive só na memória e só enquanto o painel não é reaberto — mesma medida do
  /// cartão arrancado do Leaf. Desfazer é para o engano de um segundo atrás.
  final NestTransfer? lastTransfer;

  /// A linha que a [lastTransfer] escreveu para o Track, para o desfazer poder
  /// apagá-la: desfeita, ela não organizou nada.
  final int? lastTransferId;

  /// O que acabou de acontecer, em uma frase — "12 arquivos copiados para
  /// Recibos". Some na próxima coisa que a pessoa fizer.
  final String? notice;

  bool get isEmpty => items.isEmpty;

  /// O que vai acontecer se algo for enviado agora.
  NestTransferMode get effectiveMode =>
      isInvertHeld ? defaultMode.inverted : defaultMode;

  bool get canUndo => lastTransfer != null && !lastTransfer!.isEmpty;

  bool get hasDestinations => destinations.isNotEmpty;

  /// O item sob o cursor — o que o `⌘R` revela no Finder.
  NestItem? get cursorItem {
    final index = cursor;
    if (index == null || index < 0 || index >= items.length) return null;

    return items[index];
  }

  /// O que sai daqui numa transferência, na ordem da prateleira: o que estiver
  /// escolhido — ou tudo, quando não há escolha nenhuma.
  List<NestItem> get outgoing {
    if (selection.isEmpty) return items;

    return [
      for (var index = 0; index < items.length; index++)
        if (selection.contains(index)) items[index],
    ];
  }

  bool get canSend => items.isNotEmpty;

  /// A escolha estreitou o que vai sair — é quando a tela precisa dizer
  /// **quantos** em vez de "tudo".
  bool get isNarrowed =>
      selection.isNotEmpty && selection.length < items.length;

  NestState copyWith({
    List<NestItem>? items,
    List<NestDestination>? destinations,
    Set<int>? selection,
    int? cursor,
    NestTransferMode? defaultMode,
    bool? isInvertHeld,
    bool? isDragOver,
    NestTransfer? lastTransfer,
    int? lastTransferId,
    String? notice,
    bool clearSelection = false,
    bool clearUndo = false,
    bool clearNotice = false,
  }) => NestState(
    items: items ?? this.items,
    destinations: destinations ?? this.destinations,
    selection: clearSelection ? const <int>{} : selection ?? this.selection,
    cursor: clearSelection ? null : cursor ?? this.cursor,
    defaultMode: defaultMode ?? this.defaultMode,
    isInvertHeld: isInvertHeld ?? this.isInvertHeld,
    isDragOver: isDragOver ?? this.isDragOver,
    lastTransfer: clearUndo ? null : lastTransfer ?? this.lastTransfer,
    lastTransferId: clearUndo ? null : lastTransferId ?? this.lastTransferId,
    notice: clearNotice ? null : notice ?? this.notice,
  );
}
