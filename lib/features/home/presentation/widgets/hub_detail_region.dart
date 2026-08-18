import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../../../core/design/app_metrics.dart';
import '../../../../shared/widgets/eg_button.dart';
import '../../../../shared/widgets/eg_icon.dart';

/// A terceira região do Hub: a coluna dedicada ao item que se está lendo.
///
/// Ela não divide a largura que já existe — a janela cresce para caber
/// (`HubWindowChannel.setDetailWidth`). Foi a diferença entre o desenho que
/// funcionou e o que não funcionou: dividida, a leitura ficava espremida em uns
/// 350px ao lado da lista, e uma transcrição nessa largura é pior que nenhuma.
/// Aqui o que já estava na tela não encolhe, e a região tem a largura de um
/// documento.
///
/// Altura inteira da janela, com o conteúdo rolando por dentro: é o que a faz
/// parecer uma parte do aplicativo, e não um cartão que apareceu no meio da
/// tela de preferências.
class HubDetailRegion extends StatelessWidget {
  const HubDetailRegion({
    super.key,
    required this.header,
    required this.child,
    required this.onClose,
    this.width = preferredWidth,
  });

  /// O que identifica o que está aberto — título e metadados. Fica ao lado do
  /// botão de fechar, no topo da região.
  final Widget header;

  final Widget child;
  final VoidCallback onClose;

  /// Largura desejada. Um documento se lê confortavelmente nessa medida: umas
  /// 70 colunas de texto no corpo de 13px, que é o alvo de legibilidade de
  /// qualquer texto corrido.
  static const preferredWidth = 480.0;

  /// A largura que a região realmente recebeu.
  ///
  /// Menor que a [preferredWidth] enquanto a janela ainda está crescendo (a
  /// animação nativa leva 220ms) e em tela pequena demais para crescer o
  /// bastante. Quem decide é o `HubView`, que é quem sabe quanto sobra — e a
  /// conta protege primeiro a área de conteúdo: uma tela de preferências
  /// espremida estoura o layout, uma região estreita só fica estreita.
  final double width;

  /// Abaixo disto o conteúdo da região não cabe de jeito nenhum: o seletor de
  /// abas tem largura própria e o botão de fechar precisa ficar ao lado do
  /// título. Recebendo menos que isto, a região desenha neste tamanho e é
  /// **recortada** — que é o que acontece nos 220ms em que a janela ainda está
  /// crescendo, e o que faz a região abrir deslizando em vez de piscar inteira
  /// por cima de um conteúdo espremido.
  static const _minLayoutWidth = 320.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: ClipRect(
        child: OverflowBox(
          // Ancorada à esquerda: a borda esquerda da região é a que fica parada
          // (ela encosta na área de conteúdo), e é a direita que acompanha a
          // janela crescendo.
          alignment: Alignment.centerLeft,
          minWidth: math.max(width, _minLayoutWidth),
          maxWidth: math.max(width, _minLayoutWidth),
          child: _content(),
        ),
      ),
    );
  }

  Widget _content() {
    return DecoratedBox(
      decoration: const BoxDecoration(border: Border(left: AppBorders.subtle)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xxl,
          AppSpacing.xxl,
          AppSpacing.xxl,
          AppSpacing.huge,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: header),
                const SizedBox(width: AppSpacing.sm),
                // Fechar tem atalho (`esc`) e alvo de mouse, como toda ação do
                // Evergreen. O ícone fica no topo da região, alinhado com o
                // título do que está aberto.
                EgIconButton(
                  icon: EgIconData.close,
                  tooltip: 'Fechar (esc)',
                  onPressed: onClose,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}
