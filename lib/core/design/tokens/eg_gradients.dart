import 'package:flutter/widgets.dart';

import '../eg_tokens.dart';

/// Os gradientes de profundidade, resolvidos para um tema.
///
/// Existem para evitar o "preto blocado": variações curtas de luminância que
/// dão volume a uma superfície sem virar gradiente decorativo. Saem dos mesmos
/// tokens de cor, e por isso trocam de pele junto com o resto — no tema Apple,
/// onde o fundo é chapado e a profundidade vem do material, eles quase somem
/// sozinhos, porque as cores de origem estão a um grau de distância uma da
/// outra.
@immutable
class EgGradients {
  const EgGradients(this._eg);

  final EgTokens _eg;

  /// Fundo da janela principal: sobe de leve no topo e escurece na base.
  LinearGradient get windowBackground => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      _eg.colors.backgroundTop,
      _eg.colors.background,
      _eg.colors.backgroundDeep,
    ],
    stops: const [0.0, 0.55, 1.0],
  );

  /// A luz difusa ancorada acima do topo da janela — a única fonte de luz dela,
  /// e o que a sidebar translúcida tem para atravessar.
  RadialGradient get windowGlow => RadialGradient(
    center: const Alignment(-0.35, -1.15),
    radius: 1.45,
    colors: [
      _eg.colors.accent.withValues(alpha: _eg.usesVibrancy ? 0.05 : 0.12),
      _eg.colors.accent.withValues(alpha: 0.0),
    ],
    stops: const [0.0, 1.0],
  );

  /// Superfície opaca de painel: iluminada de leve por cima.
  LinearGradient get panelSurface => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [_eg.colors.surfaceTop, _eg.colors.surface],
    stops: const [0.0, 0.55],
  );

  /// O vidro do painel flutuante — a gêmea translúcida da [panelSurface].
  LinearGradient get panelVibrancy => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      _eg.colors.surfaceFloating.withValues(
        alpha: (_eg.colors.surfaceFloating.a + 0.06).clamp(0.0, 1.0),
      ),
      _eg.colors.surfaceFloating,
    ],
    stops: const [0.0, 0.6],
  );

  /// O palco da apresentação de boas-vindas: do fundo ao accent, na diagonal.
  ///
  /// É o único gradiente do app que a pessoa deve **ver** como gradiente, e ele
  /// custa uma justificativa: o `colors.md` proíbe gradiente decorativo porque
  /// ferramenta de trabalho não decora. Isto não é tela de trabalho — é a única
  /// vez em que o Evergreen se apresenta, e nela a cor da marca é o assunto,
  /// não um estado. A regra continua valendo para todo o resto.
  ///
  /// Mesmo aqui ele é contido: parte do fundo, chega no [EgPalette.accentShade]
  /// e para antes do accent, para o print que fica em cima continuar sendo a
  /// coisa mais clara da composição. Chegando no accent cheio, o fundo
  /// competiria com o botão verde que aparece dentro do próprio print.
  LinearGradient get onboardingStage => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      _eg.colors.backgroundDeep,
      _eg.colors.background,
      _eg.colors.accentShade,
    ],
    stops: const [0.0, 0.42, 1.0],
  );

  /// Superfície do cartão — hoje o cartão do Leaf.
  LinearGradient get cardSurface => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [_eg.colors.cardTop, _eg.colors.card],
    stops: const [0.0, 0.55],
  );
}
