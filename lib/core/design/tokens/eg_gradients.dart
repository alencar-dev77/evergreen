import 'package:flutter/widgets.dart';

import '../eg_tokens.dart';

/// Os degradês do Evergreen.
///
/// Regra única: **degradê serve à profundidade ou ao material, nunca à
/// decoração.** Os anteriores tinham dois a cinco pontos de luminância de
/// amplitude — não se viam, e o que não se vê é custo sem efeito. Os que
/// ficaram sobem o suficiente para o olho registrar de onde vem a luz; os que
/// não tinham o que dizer saíram, e o botão primário e o cartão de seção
/// passaram a ser chapados.
@immutable
class EgGradients {
  const EgGradients(this._eg);

  final EgTokens _eg;

  /// O fundo da janela: a luz entra por cima e o pé é o mais fundo do app.
  LinearGradient get windowBackground => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [_eg.colors.canvas, _eg.colors.canvasDeep],
  );

  /// O halo de accent no alto da janela do Hub.
  ///
  /// Fraco de propósito: é o que dá a impressão de que a janela tem uma fonte
  /// de luz, sem que nada dentro dela fique verde.
  RadialGradient get windowGlow => RadialGradient(
    center: const Alignment(-0.35, -1.15),
    radius: 1.45,
    colors: [
      _eg.colors.accent.withValues(alpha: 0.07),
      _eg.colors.accent.withValues(alpha: 0.0),
    ],
  );

  /// A superfície de um bloco-instrumento — o anel do Focus, a bancada do
  /// gerador, a pilha do Nest.
  LinearGradient get stageSurface => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [_eg.colors.surfaceTop, _eg.colors.surface],
  );

  /// O vidro do painel flutuante, por baixo do blur.
  ///
  /// Um degradê, e não uma cor chapada, porque o topo do painel recebe mais
  /// luz que o pé — é a mesma razão da hairline interna, e as duas juntas são
  /// o que faz o painel parecer material.
  LinearGradient get panelVibrancy => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      _eg.colors.glassPanel.withValues(
        alpha: (_eg.colors.glassPanel.a + 0.07).clamp(0.0, 1.0),
      ),
      _eg.colors.glassPanel,
    ],
    stops: const [0.0, 0.6],
  );

  /// O fundo da pilha do Nest: o verde vem do canto de onde o arquivo entra.
  RadialGradient get nestStage => RadialGradient(
    center: const Alignment(-0.6, -1.0),
    radius: 1.2,
    colors: [
      _eg.colors.accent.withValues(alpha: 0.09),
      _eg.colors.accent.withValues(alpha: 0.0),
    ],
  );

  /// O palco da apresentação de boas-vindas.
  LinearGradient get onboardingStage => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [_eg.colors.canvasDeep, _eg.colors.canvas, _eg.colors.accentDeep],
    stops: const [0.0, 0.42, 1.0],
  );
}
