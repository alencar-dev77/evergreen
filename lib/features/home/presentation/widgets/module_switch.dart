import 'package:flutter/widgets.dart';

import '../../../../core/design/app_metrics.dart';

/// O corpo de uma tela de módulo desligado: à vista, apagado e sem resposta.
///
/// Apagado e não escondido, pela mesma razão que um controle desabilitado do
/// Focus continua na tela: quem desligou precisa ver o que está deixando de
/// usar para decidir se quer de volta. Uma tela que ficasse em branco não
/// diria nem o que o módulo faz nem o que ele já guardou.
///
/// Três camadas, e cada uma responde por uma forma de alcançar o conteúdo: o
/// [Opacity] diz que está desligado, o [IgnorePointer] tira o mouse e o
/// [ExcludeFocus] tira o teclado — sem o terceiro, um Tab ainda entraria na
/// tela apagada e mexeria num controle invisível de tão claro.
class ModuleGate extends StatelessWidget {
  const ModuleGate({super.key, required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (enabled) return child;

    return ExcludeFocus(
      child: IgnorePointer(
        // A árvore de acessibilidade acompanha: sem isto o leitor de tela leria
        // uma tela inteira de controles que não respondem a nada.
        child: ExcludeSemantics(
          child: Opacity(opacity: AppOpacities.disabled, child: child),
        ),
      ),
    );
  }
}
