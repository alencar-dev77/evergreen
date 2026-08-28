import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

/// O tempo de um tema.
///
/// As durações são as mesmas — a escala do `motion.md` é do produto, não da
/// pele, e um app que fica mais lento ao trocar de aparência estaria mentindo
/// sobre o que a troca faz. O que muda é a **curva**: o Evergreen desacelera
/// como toda interface web bem-feita (`easeOutCubic`), e o Apple freia mais
/// tarde e mais seco (`easeOutQuart`), que é o que mais se aproxima do spring
/// curto do AppKit sem trazer o quique junto.
@immutable
class EgMotion {
  const EgMotion({
    required this.instant,
    required this.fast,
    required this.entrance,
    required this.medium,
    required this.settle,
    required this.curve,
  });

  final Duration instant;
  final Duration fast;
  final Duration entrance;
  final Duration medium;
  final Duration settle;
  final Curve curve;

  static EgMotion lerp(EgMotion a, EgMotion b, double t) => t < 0.5 ? a : b;
}
