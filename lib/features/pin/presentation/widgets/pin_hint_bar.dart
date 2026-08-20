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
  });

  final bool isPreviewOpen;

  /// Há um tipo escolhido na fila de pílulas.
  ///
  /// Muda o que o Esc promete: com um filtro ativo ele desfaz o recorte em vez
  /// de fechar o painel, e o rodapé é o único lugar onde isso se aprende sem
  /// tentar. É também o que dispensa uma dica nova só para o `⌘←→` — a fila de
  /// pílulas já está à vista, e a 420px não haveria largura para as duas.
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

  @override
  Widget build(BuildContext context) {
    if (isEditingAlias) {
      return const EgHintBar(
        hints: [EgHint(keys: ['enter'], label: 'guardar apelido')],
        trailing: EgHint(keys: ['esc'], label: 'descartar'),
      );
    }

    return EgHintBar(
      hints: [
        // Setas e Enter dispensam rótulo: ao lado de uma lista eles se
        // explicam, e o espaço vale mais para o ⌘P, que não.
        const EgHint(keys: ['↑', '↓']),
        // E por serem os mais evidentes da barra, são eles que cedem a largura
        // quando o ⌥↑↓ entra: a 420px as duas dicas não cabem juntas, e quem
        // acabou de chegar aos fixados duvida de como movê-los, não de que
        // Enter copia.
        if (!canMovePinned) const EgHint(keys: ['enter']),
        const EgHint(keys: ['⌘P'], label: 'fixar'),
        if (canMovePinned) const EgHint(keys: ['⌥↑↓'], label: 'mover'),
        // O ⌘R só é anunciado com o preview aberto, que é onde o campo de
        // apelido existe: quem está na lista descobre o recurso abrindo o
        // preview, e é lá que a dúvida "dá para fazer isso sem o mouse?"
        // aparece. Na lista de 420px ele também não caberia.
        if (isPreviewOpen) const EgHint(keys: ['⌘R'], label: 'apelido'),
        // O Tab é anunciado nos dois estados: ele abre o preview e é o único
        // caminho de volta dele, desde que o Esc parou de recolhê-lo. A largura
        // que ele ocupa aqui saiu do ⌘⌫ — apagar continua funcionando pela
        // tecla, mas com o preview aberto o botão "Excluir" está à vista dois
        // dedos ao lado, e o "como eu volto para a lista?" não tem resposta
        // visível nenhuma.
        EgHint(keys: const ['tab'], label: isPreviewOpen ? 'voltar' : 'ver'),
      ],
      trailing: EgHint(
        keys: const ['esc'],
        // O Esc promete uma coisa só, e o preview não muda o que ela é: com
        // filtro ativo ele desfaz o recorte, e em qualquer outro caso fecha.
        label: isFiltered ? 'limpar filtro' : 'sair',
      ),
    );
  }
}
