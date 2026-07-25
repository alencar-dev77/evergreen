import 'package:flutter/widgets.dart';

import '../../../../shared/widgets/eg_hint_bar.dart';

/// Rodapé do overlay do Pin com os atalhos disponíveis.
///
/// O Pin é feito para ser usado sem o mouse; deixar as teclas à vista ensina a
/// navegação sem exigir que o usuário procure documentação.
class PinHintBar extends StatelessWidget {
  const PinHintBar({super.key, required this.isPreviewOpen});

  final bool isPreviewOpen;

  @override
  Widget build(BuildContext context) {
    return EgHintBar(
      hints: [
        // Setas e Enter dispensam rótulo: ao lado de uma lista eles se
        // explicam, e o espaço vale mais para o ⌘P, que não.
        const EgHint(keys: ['↑', '↓']),
        const EgHint(keys: ['enter']),
        const EgHint(keys: ['⌘P'], label: 'fixar'),
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
