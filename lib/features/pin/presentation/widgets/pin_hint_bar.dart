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
  });

  final bool isPreviewOpen;

  /// A seleção está num fixado que tem com quem trocar de lugar.
  ///
  /// A dica de reordenar aparece só aí — dentro dos recentes o atalho não faz
  /// nada, e anunciá-lo o tempo todo prometeria algo que a maior parte da lista
  /// não cumpre. É também onde a dúvida existe: a fronteira entre os dois
  /// grupos é justamente onde a capacidade muda.
  final bool canMovePinned;

  @override
  Widget build(BuildContext context) {
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
        // Com o preview aberto, o Esc já é o caminho de volta — anunciar o Tab
        // também só ofereceria duas formas de fazer a mesma coisa. A largura que
        // ele libera é o que permite anunciar o ⌘⌫, que ninguém descobre por
        // conta própria.
        if (isPreviewOpen)
          const EgHint(keys: ['⌘⌫'], label: 'excluir')
        else
          const EgHint(keys: ['tab'], label: 'ver'),
      ],
      trailing: EgHint(
        keys: const ['esc'],
        label: isPreviewOpen ? 'voltar' : 'sair',
      ),
    );
  }
}
