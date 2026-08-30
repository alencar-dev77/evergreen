import 'package:flutter/widgets.dart';

/// As durações e a curva do Evergreen.
///
/// Curtas, e é decisão de produto: um app chamado por atalho e usado por
/// segundos não pode fazer ninguém esperar a interface terminar de se
/// acomodar. **A saída não tem duração** — fechar é instantâneo, sempre.
///
/// O invariante que vale mais que qualquer número aqui: **nenhuma animação
/// bloqueia o teclado**. O painel aceita tecla no primeiro quadro da entrada;
/// se a animação atrasa a primeira tecla, a animação está errada.
@immutable
class EgMotion {
  const EgMotion({
    required this.instant,
    required this.fast,
    required this.entrance,
    required this.medium,
    required this.stack,
    required this.settle,
    required this.curve,
  });

  /// Hover, pressed, anel de foco. Imperceptível como animação — o que ela
  /// evita é a interface *piscar*.
  final Duration instant;

  /// Troca de estado pequena, troca de aba.
  final Duration fast;

  /// Entrada de painel flutuante.
  final Duration entrance;

  /// Layout, e o crescimento da janela do Hub.
  final Duration medium;

  /// O cartão do topo da pilha do Nest subindo e sumindo.
  ///
  /// É a única animação decorativa do app, e existe por uma razão funcional:
  /// ela confirma que **exatamente um** arquivo saiu.
  final Duration stack;

  /// O assentamento no fim de um movimento que trava — o único spring daqui.
  final Duration settle;

  final Curve curve;

  static EgMotion lerp(EgMotion a, EgMotion b, double t) => EgMotion(
    instant: t < 0.5 ? a.instant : b.instant,
    fast: t < 0.5 ? a.fast : b.fast,
    entrance: t < 0.5 ? a.entrance : b.entrance,
    medium: t < 0.5 ? a.medium : b.medium,
    stack: t < 0.5 ? a.stack : b.stack,
    settle: t < 0.5 ? a.settle : b.settle,
    curve: t < 0.5 ? a.curve : b.curve,
  );
}
