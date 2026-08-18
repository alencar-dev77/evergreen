import 'package:flutter/widgets.dart';

import 'app_colors.dart';

/// Gradientes de profundidade do Evergreen.
///
/// A paleta é "Dark Premium" e majoritariamente chapada — estes gradientes
/// existem para evitar o "preto blocado": variações curtas de luminância que dão
/// volume à superfície sem virar gradiente decorativo (ver `colors.md`, seção
/// "Iluminação e profundidade"). Nada de multi-hue, nada de diagonal berrante.
abstract final class AppGradients {
  /// Fundo da janela principal (Hub): sobe de leve no topo e escurece na base,
  /// como uma vinheta muito discreta.
  static const windowBackground = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      AppColors.backgroundTop,
      AppColors.background,
      AppColors.backgroundDeep,
    ],
    stops: [0.0, 0.55, 1.0],
  );

  /// Brilho verde suave, ancorado acima do topo da janela. Simula uma luz
  /// difusa (o "blur por cima") sem custo de `BackdropFilter` — é só um
  /// gradiente radial com falloff largo, barato de renderizar a cada frame.
  ///
  /// A 6% ele existia mais na intenção que na tela; a 12%, com o falloff um
  /// pouco mais largo, a luz chega a ser vista sem nunca virar uma mancha
  /// verde — o fundo continua preto, só deixou de ser plano. É a única fonte de
  /// luz da janela, e é ela que a sidebar translúcida tem para atravessar.
  static final windowGlow = RadialGradient(
    center: const Alignment(-0.35, -1.15),
    radius: 1.45,
    colors: [
      AppColors.greenPrimary.withValues(alpha: 0.12),
      AppColors.greenPrimary.withValues(alpha: 0.0),
    ],
    stops: const [0.0, 1.0],
  );

  /// Superfície opaca do painel: iluminada de leve por cima, reforçando a
  /// leitura de "vidro" que a sombra e a borda já sugerem.
  ///
  /// É a gêmea opaca da [panelVibrancy], para painel que não pode borrar o que
  /// está atrás — porque não há nada atrás, ou porque a superfície fica visível
  /// o tempo todo e o blur sairia caro. O stop em 55% (e não 60%) é o que faz a
  /// transição ser percebida como material, e não como ruído de compressão.
  static const panelSurface = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [AppColors.surfaceTop, AppColors.surface],
    stops: [0.0, 0.55],
  );

  /// O vidro dos cinco painéis flutuantes: o mesmo material da [panelSurface],
  /// translúcido, para o `AppMaterials.panelVibrancy` borrar o que passa por
  /// baixo.
  ///
  /// Só painel flutuante usa: eles vivem alguns milissegundos por invocação, e
  /// é aí que o custo do blur cabe no orçamento (ver `colors.md`).
  static final panelVibrancy = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [AppColors.panelGlassTop, AppColors.panelGlass],
    stops: const [0.0, 0.6],
  );

  /// Superfície do card — hoje o cartão do Leaf.
  ///
  /// A [panelSurface] em escala de card: dois pontos de luminância no topo,
  /// suficientes para o cartão ter uma quina iluminada e uma base assentada em
  /// vez de nove quadrados idênticos na parede.
  static const cardSurface = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [AppColors.cardTop, AppColors.card],
    stops: [0.0, 0.55],
  );
}
