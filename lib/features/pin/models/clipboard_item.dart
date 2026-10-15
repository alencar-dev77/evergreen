import 'clipboard_item_type.dart';
import 'pin_image.dart';

/// Um registro do histórico da área de transferência.
///
/// Imutável: alterações (fixar, atualizar timestamp) produzem uma nova
/// instância via [copyWith], mantendo a camada de estado previsível.
class ClipboardItem {
  const ClipboardItem({
    required this.id,
    required this.content,
    required this.type,
    required this.isPinned,
    required this.copiedAt,
    this.pinnedAt,
    this.alias,
    this.image,
  });

  /// Identificador no banco local. `null` enquanto o item não foi persistido.
  final int? id;

  /// Conteúdo integral copiado.
  final String content;

  final ClipboardItemType type;
  final bool isPinned;

  /// Momento da última vez que este conteúdo passou pela área de transferência.
  final DateTime copiedAt;

  /// Chave de ordenação dos fixados; `null` quando o item não está fixado.
  ///
  /// Nasce como o momento em que o item foi fixado, e é o que dá ordem estável
  /// ao grupo: recopiar um item fixado atualiza o [copiedAt] mas não mexe na
  /// posição dele — nem, portanto, no atalho ⌥N. Reordenar com `⌥↑`/`⌥↓` troca
  /// este valor entre dois itens, então ele não serve para exibir "fixado em".
  final DateTime? pinnedAt;

  /// Nome dado pela pessoa a este item ("chave pix"), ou `null` se ela não deu
  /// nenhum.
  ///
  /// Serve só para reencontrar o item na lista: o que vai para a área de
  /// transferência é sempre [content]. Texto em branco é o mesmo que não ter
  /// apelido — quem lê pergunta por [hasAlias], nunca por `alias != null`.
  final String? alias;

  /// A imagem, quando o item é uma — ver [PinImage].
  final PinImage? image;

  bool get isImage => image != null;

  /// O item tem um apelido para exibir.
  bool get hasAlias => alias != null && alias!.trim().isNotEmpty;

  /// Cria um item ainda não persistido a partir de um conteúdo capturado.
  factory ClipboardItem.capture(String content, {DateTime? at}) {
    return ClipboardItem(
      id: null,
      content: content,
      type: ClipboardItemClassifier.classify(content),
      isPinned: false,
      copiedAt: at ?? DateTime.now(),
    );
  }

  /// Cria a linha de uma imagem capturada.
  ///
  /// O [content] é a chave da linha — `imagem:<hash>.<ext>` —, e não algo a
  /// mostrar: é a coluna única do histórico que faz a mesma imagem copiada
  /// duas vezes subir para o topo em vez de virar duas linhas.
  factory ClipboardItem.fromImage(PinImage image, {DateTime? at}) {
    return ClipboardItem(
      id: null,
      content: '$imageKeyPrefix${image.fileName}',
      type: ClipboardItemType.image,
      isPinned: false,
      copiedAt: at ?? DateTime.now(),
      image: image,
    );
  }

  static const imageKeyPrefix = 'imagem:';

  /// O que a busca lê além do título: o texto inteiro, ou — numa imagem — o
  /// caminho e o site de onde ela veio. A chave `imagem:…` não é texto de
  /// ninguém, e casar "imagem" com todas elas seria ruído.
  String get searchableContent => image?.searchable ?? content;

  /// Texto exibido na lista: primeira linha não vazia, sem espaços nas pontas.
  ///
  /// A lista é de linha única com ellipsis, então quebras de linha só poluiriam
  /// a medição de texto.
  String get title {
    final image = this.image;
    if (image != null) return image.title;
    // Imagem cuja descrição não sobreviveu: a chave não é título de ninguém.
    if (type == ClipboardItemType.image) return 'Imagem';

    final firstLine = content
        .split('\n')
        .map((line) => line.trim())
        .firstWhere((line) => line.isNotEmpty, orElse: () => '');

    return firstLine.isEmpty ? content.trim() : firstLine;
  }

  /// Verdadeiro quando o conteúdo tem mais do que a linha exibida na lista.
  bool get hasMoreThanTitle => !isImage && content.trim() != title;

  /// O que a lista põe em primeiro plano: o apelido quando existe, o próprio
  /// conteúdo quando não.
  ///
  /// O apelido tem prioridade porque é justamente o nome que a pessoa escolheu
  /// para reconhecer o item de relance; o conteúdo continua visível ao lado,
  /// em segundo plano, para ninguém copiar às cegas.
  String get displayTitle => hasAlias ? alias!.trim() : title;

  ClipboardItem copyWith({
    int? id,
    String? content,
    ClipboardItemType? type,
    bool? isPinned,
    DateTime? copiedAt,
    DateTime? pinnedAt,
    String? alias,
    PinImage? image,
  }) {
    return ClipboardItem(
      id: id ?? this.id,
      content: content ?? this.content,
      type: type ?? this.type,
      isPinned: isPinned ?? this.isPinned,
      copiedAt: copiedAt ?? this.copiedAt,
      pinnedAt: pinnedAt ?? this.pinnedAt,
      // Passar `''` apaga o apelido: um apelido em branco não existe, e essa é
      // a única forma de tirá-lo por aqui — `null` significa "não mexe".
      alias: alias ?? this.alias,
      image: image ?? this.image,
    );
  }

  // Casar com a busca não mora mais aqui: com fuzzy e nota de relevância, "este
  // item casa?" e "o quanto ele casa?" são a mesma conta, e ela ficou inteira
  // em `PinSearch` — um lugar só, que a lista e a ordenação consultam.

  @override
  bool operator ==(Object other) =>
      other is ClipboardItem &&
      other.id == id &&
      other.isPinned == isPinned &&
      other.alias == alias;

  @override
  int get hashCode => Object.hash(id, isPinned, alias);
}
