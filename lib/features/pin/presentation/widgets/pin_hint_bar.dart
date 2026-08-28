import 'package:flutter/widgets.dart';

import '../../../../shared/widgets/eg_hint_bar.dart';

/// Rodapé do overlay do Pin com os atalhos disponíveis.
///
/// O Pin é feito para ser usado sem o mouse; deixar as teclas à vista ensina a
/// navegação sem exigir que o usuário procure documentação.
class PinHintBar extends StatelessWidget {
  const PinHintBar({
    super.key,
    required this.isPreviewOpen,
    this.canMovePinned = false,
    this.isEditingAlias = false,
    this.isFiltered = false,
    this.hasTypes = false,
    this.isSelectedPinned = false,
    this.isGeneratorSelected = false,
  });

  final bool isPreviewOpen;

  /// A seleção está na linha "Gerar CPF".
  ///
  /// Ali o rodapé fala de outra coisa: fixar, renomear e reordenar não existem
  /// para uma linha que ainda não é um item, e o `⌘G` — que em qualquer outro
  /// lugar não faz nada — é justamente o que a linha tem de próprio.
  final bool isGeneratorSelected;

  /// O item selecionado já está fixado.
  ///
  /// Muda o verbo do `⌘P`: a tecla é a mesma nos dois sentidos, e um rodapé que
  /// diz "fixar" sobre um item já fixado ensina a metade errada do atalho.
  final bool isSelectedPinned;

  /// Há uma fila de tipos para percorrer com `←`/`→`.
  ///
  /// Com um tipo só no histórico a fila nem se desenha, e anunciar a tecla
  /// prometeria um movimento que não acontece.
  final bool hasTypes;

  /// Há um tipo escolhido na fila de pílulas.
  ///
  /// Muda o que o Esc promete: com um filtro ativo ele desfaz o recorte em vez
  /// de fechar o painel, e o rodapé é o único lugar onde isso se aprende sem
  /// tentar.
  final bool isFiltered;

  /// O cursor está no campo de apelido.
  ///
  /// Aí o rodapé fala de uma coisa só: enquanto se digita, todo o resto do
  /// teclado pertence ao texto, e anunciar atalhos que não respondem seria
  /// prometer o que a tecla não faz.
  final bool isEditingAlias;

  /// A seleção está num fixado que tem com quem trocar de lugar.
  ///
  /// A dica de reordenar aparece só aí — dentro dos recentes o atalho não faz
  /// nada, e anunciá-lo o tempo todo prometeria algo que a maior parte da lista
  /// não cumpre. É também onde a dúvida existe: a fronteira entre os dois
  /// grupos é justamente onde a capacidade muda.
  final bool canMovePinned;

  /// Quantas vagas a linha comporta.
  ///
  /// Vagas, e não pixels: uma dica com rótulo ocupa duas, uma sem rótulo ocupa
  /// uma. O número saiu de medição em teste — o grupo da esquerda vive num
  /// viewport que recorta em silêncio, e o excesso sai cortado no meio da
  /// palavra, encostando no `esc`. Mexeu nos rótulos, passa pela régua de novo.
  int get _budget => isPreviewOpen ? 6 : 5;

  /// As dicas em ordem de prioridade, com **variantes**.
  ///
  /// A mesma tecla pode aparecer duas vezes, primeiro com rótulo e depois sem:
  /// a segunda só entra se a primeira não tiver cabido. É assim que o `tab`
  /// sobrevive numa linha cheia — sem o verbo, mas presente, que é o que
  /// importa para uma tecla cujo trabalho é abrir e fechar o item.
  List<EgHint> get _candidates {
    if (isGeneratorSelected) return _generatorHints;

    return isPreviewOpen ? _itemHints : _listHints;
  }

  /// Na linha do gerador, três coisas: sortear outro, copiar este e sair dela.
  ///
  /// O `enter` ganha rótulo aqui, e não na lista: em cima de um item ele é o
  /// óbvio de um painel de área de transferência, mas em cima de uma linha que
  /// diz "Gerar CPF" a dúvida é real — se o Enter gera ou se copia o que já
  /// está escrito ali.
  List<EgHint> get _generatorHints => const [
        EgHint(keys: ['⌘G'], label: 'sortear'),
        EgHint(keys: ['enter'], label: 'copiar'),
        EgHint(keys: ['↑↓']),
      ];

  /// Com o item aberto, a linha fala **do item**: renomear, (des)fixar e
  /// voltar.
  ///
  /// Mover e filtrar são da lista, que continua ali ao lado — mas quem abriu um
  /// item está lendo o item, e é sobre ele que a dúvida aparece. Foi a régua
  /// que impôs a escolha: cinco dicas com rótulo não cabem em linha nenhuma.
  List<EgHint> get _itemHints => [
        EgHint(keys: const ['⌘P'], label: isSelectedPinned ? 'desfixar' : 'fixar'),
        const EgHint(keys: ['⌘R'], label: 'apelido'),
        const EgHint(keys: ['tab'], label: 'voltar'),
        const EgHint(keys: ['tab']),
      ];

  /// Na lista, a linha fala da navegação — e o que só existe num estado vem
  /// antes do que se adivinha olhando.
  List<EgHint> get _listHints => [
        if (canMovePinned) const EgHint(keys: ['⌥↑↓'], label: 'mover'),
        if (hasTypes) const EgHint(keys: ['←→'], label: 'filtro'),
        EgHint(keys: const ['⌘P'], label: isSelectedPinned ? 'desfixar' : 'fixar'),
        const EgHint(keys: ['tab'], label: 'ver'),
        // O par vertical só quando o ⌥↑↓ não o está desenhando ao lado.
        if (!canMovePinned) const EgHint(keys: ['↑↓']),
        // As variantes curtas, para o caso de a linha já estar cheia.
        const EgHint(keys: ['tab']),
        const EgHint(keys: ['⌘P']),
        const EgHint(keys: ['enter']),
      ];

  List<EgHint> _fitted() {
    var left = _budget;
    final line = <EgHint>[];

    for (final hint in _candidates) {
      // A variante curta de uma tecla que já entrou seria a mesma dica duas
      // vezes na linha.
      if (line.any((chosen) => chosen.keys.first == hint.keys.first)) continue;

      final cost = hint.label == null ? 1 : 2;
      if (cost > left) continue;

      line.add(hint);
      left -= cost;
    }

    return line;
  }

  @override
  Widget build(BuildContext context) {
    if (isEditingAlias) {
      return const EgHintBar(
        hints: [EgHint(keys: ['enter'], label: 'guardar apelido')],
        trailing: EgHint(keys: ['esc'], label: 'descartar'),
      );
    }

    return EgHintBar(
      hints: _fitted(),
      trailing: EgHint(
        keys: const ['esc'],
        // O Esc promete uma coisa só, e o preview não muda o que ela é: com
        // filtro ativo ele desfaz o recorte, e em qualquer outro caso fecha.
        label: isFiltered ? 'limpar filtro' : 'sair',
      ),
    );
  }
}
