import 'package:flutter/widgets.dart';

import '../../core/design/app_gradients.dart';

/// Fundo padrão das janelas do Evergreen.
///
/// Duas camadas baratas dão profundidade ao "Dark Premium" sem sair da paleta:
/// um gradiente vertical de vinheta muito sutil e, por cima, um brilho verde
/// difuso ancorado no topo — o "degrade com blur sutil" da identidade. Nenhuma
/// das camadas usa `BackdropFilter`, então é seguro mantê-las na tela o tempo
/// todo (ver `colors.md` sobre custo de blur permanente).
class EgBackground extends StatelessWidget {
  const EgBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppGradients.windowBackground),
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: AppGradients.windowGlow),
        child: child,
      ),
    );
  }
}
