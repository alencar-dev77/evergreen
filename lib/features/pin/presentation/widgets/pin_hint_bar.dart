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
  });

  final bool isPreviewOpen;

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
  /// uma. No painel estreito (420px) cabem quatro — a quinta era recortada no
  /// meio da palavra, encostando no `esc`. Com o preview aberto o painel é bem
  /// mais largo e cabem seis. O número saiu da régua do teste do rodapé, não de
  /// estimativa: qualquer mexida nos rótulos precisa passar por ele de novo.
  int get _budget => isPreviewOpen ? 6 : 4;

  /// As dicas em ordem de prioridade — o que é do momento primeiro, o que se
  /// adivinha por último.
  ///
  /// A ordem importa mais que a lista: quem não couber é descartado, e as
  /// curtas continuam sendo tentadas depois de uma longa ser recusada. É por
  /// isso que `↑↓` sobrevive numa linha em que `tab ver` já não cabe.
  List<EgHint> get _candidates => [
        // Só aparecem num estado, e é neles que a dúvida existe.
        if (canMovePinned) const EgHint(keys: ['⌥↑↓'], label: 'mover'),
        if (hasTypes) const EgHint(keys: ['←→'], label: 'filtro'),
        if (isPreviewOpen) const EgHint(keys: ['⌘R'], label: 'apelido'),
        // Com o preview aberto, o Tab é o único caminho de volta — nessa hora
        // ele vale mais que a ação de fixar.
        if (isPreviewOpen) const EgHint(keys: ['tab'], label: 'voltar'),
        const EgHint(keys: ['⌘P'], label: 'fixar'),
        // O par vertical só quando o ⌥↑↓ não o está desenhando ao lado.
        if (!canMovePinned) const EgHint(keys: ['↑↓']),
        if (!isPreviewOpen) const EgHint(keys: ['tab'], label: 'ver'),
        const EgHint(keys: ['enter']),
      ];

  List<EgHint> _fitted() {
    var left = _budget;
    final line = <EgHint>[];

    for (final hint in _candidates) {
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
