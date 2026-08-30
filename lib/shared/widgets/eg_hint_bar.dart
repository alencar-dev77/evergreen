import 'package:flutter/widgets.dart';

import '../../core/design/app_metrics.dart';
import 'eg_hoverable.dart';
import 'eg_key_cap.dart';
import '../../core/design/eg_tokens.dart';

/// Uma dica de atalho: as teclas e, quando não for óbvio, o que elas fazem.
@immutable
class EgHint {
  const EgHint({required this.keys, this.label, this.onTap});

  final List<String> keys;

  /// Teclas evidentes pelo contexto (setas, enter ao lado de uma lista) vão sem
  /// rótulo — o espaço vale mais para as que ninguém adivinha.
  final String? label;

  /// O que a dica faz quando alguém clica nela, quando a tecla que ela ensina
  /// não tem outro alvo de mouse na tela.
  ///
  /// Nenhuma ação do Evergreen é só de teclado, e há teclas que aparecem por um
  /// estado passageiro — o `⌘Z` do Leaf, que existe entre apagar um cartão e
  /// fechar o painel. Desenhar um botão para elas encheria a tela de affordance
  /// que some; a dica já está no lugar certo, dizendo a coisa certa, na hora
  /// certa. Sem [onTap] ela continua sendo só texto.
  final VoidCallback? onTap;
}

/// Rodapé de painel com os atalhos disponíveis no estado atual.
///
/// Todo painel do Evergreen operado por teclado leva um. É documentação
/// embutida no lugar exato onde a dúvida aparece, e por isso mostra o
/// subconjunto relevante ao momento — não a lista completa de atalhos.
///
/// As dicas nunca podem quebrar o layout: o grupo da esquerda vive num
/// viewport, então em fonte ou largura apertada a última dica é recortada em
/// silêncio em vez de estourar a linha. [trailing] fica fora dele, ancorado à
/// direita, porque é a dica que não pode sumir (tipicamente o `esc`).
class EgHintBar extends StatelessWidget {
  const EgHintBar({super.key, required this.hints, this.trailing});

  final List<EgHint> hints;

  /// O par que fica encostado à direita — sempre o `esc`.
  final EgHint? trailing;

  /// A altura da barra.
  static const _height = 34.0;

  @override
  Widget build(BuildContext context) {
    // No máximo quatro pares: se precisa de um quinto, a função não é
    // essencial o bastante para estar no rodapé — e a barra é a legenda do
    // painel, não o índice dele.
    assert(
      hints.length <= 4,
      'A barra de teclas comporta quatro pares; veio com ${hints.length}.',
    );

    // Preto a 18%, e não a superfície do canvas: a barra mora sobre o vidro,
    // e um cinza opaco ali vira uma tarja que não pertence ao painel. O preto
    // translúcido escurece o que já está atrás, que é o que uma faixa de
    // rodapé faz num material de verdade.
    return Container(
      height: _height,
      padding: EdgeInsets.symmetric(horizontal: context.eg.shapes.rowPaddingH),
      decoration: BoxDecoration(
        color: const Color(0x2E000000),
        border: Border(top: BorderSide(color: context.eg.colors.edge)),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [for (final hint in hints) _HintLabel(hint: hint)],
              ),
            ),
          ),
          if (trailing != null) _HintLabel(hint: trailing!, isLast: true),
        ],
      ),
    );
  }
}

class _HintLabel extends StatelessWidget {
  const _HintLabel({required this.hint, this.isLast = false});

  final EgHint hint;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Um degrau abaixo do respiro padrão: a barra ganhou dicas que aparecem
      // por estado — mover, filtrar, apelido — e nos painéis estreitos a
      // diferença entre 14 e 10 é a diferença entre a última dica caber e sair
      // cortada no meio da palavra. Densidade antes de respiro, que é a regra
      // da casa para linha de legenda.
      padding: EdgeInsets.only(right: isLast ? 0 : AppSpacing.lg),
      child: hint.onTap == null ? _content(context) : _clickable(context),
    );
  }

  /// A dica acionável se anuncia como botão e clareia sob o ponteiro.
  ///
  /// O realce é a cor do rótulo, não uma superfície nova: a barra é uma linha
  /// de legenda, e um fundo aparecendo atrás de uma dica no rodapé pesaria mais
  /// que a ação que ela oferece. Cor de texto é o único degrau de estado que um
  /// rótulo tem — o resto da matriz de superfícies não se aplica a ele.
  Widget _clickable(BuildContext context) {
    return EgHoverable(
      onTap: hint.onTap,
      builder: (context, state) => _content(
        context,
        color: state.isHovered ? context.eg.colors.textPrimary : null,
      ),
    );
  }

  Widget _content(BuildContext context, {Color? color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        EgShortcutDisplay(keys: hint.keys, onGlass: true),
        if (hint.label != null) ...[
          const SizedBox(width: AppSpacing.xs),
          Text(
            hint.label!,
            maxLines: 1,
            softWrap: false,
            style: color == null
                ? context.eg.text.footnote
                : context.eg.text.footnote.copyWith(color: color),
          ),
        ],
      ],
    );
  }
}
