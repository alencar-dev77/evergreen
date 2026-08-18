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
  });

  /// O que identifica o que está aberto — título e metadados. Fica ao lado do
  /// botão de fechar, no topo da região.
  final Widget header;

  final Widget child;
  final VoidCallback onClose;

  /// Largura da região. Um documento se lê confortavelmente nessa medida: umas
  /// 70 colunas de texto no corpo de 13px, que é o alvo de legibilidade de
  /// qualquer texto corrido.
  static const width = 480.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: DecoratedBox(
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
                  // Fechar tem atalho (`esc`) e alvo de mouse, como toda ação
                  // do Evergreen. O ícone fica no topo da região, alinhado com
                  // o título do que está aberto.
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
      ),
    );
  }
}
