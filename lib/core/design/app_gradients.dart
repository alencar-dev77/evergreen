import 'package:flutter/widgets.dart';

import 'app_colors.dart';

/// Gradientes de profundidade do Evergreen.
///
/// A paleta é "Dark Premium" e majoritariamente chapada — estes gradientes
/// existem só para evitar o "preto blocado": variações de 3–4% de luminância
/// que dão profundidade à superfície sem serem lidas como gradiente decorativo
/// (ver `colors.md`, seção "Iluminação e profundidade"). Nada de multi-hue,
/// nada de diagonal berrante.
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
  static final windowGlow = RadialGradient(
    center: const Alignment(-0.35, -1.15),
    radius: 1.25,
    colors: [
      AppColors.greenPrimary.withValues(alpha: 0.06),
      AppColors.greenPrimary.withValues(alpha: 0.0),
    ],
    stops: const [0.0, 1.0],
  );

  /// Superfície do painel flutuante (overlay do Pin): iluminada de leve por
  /// cima, reforçando a leitura de "vidro" que a sombra e a borda já sugerem.
  static const panelSurface = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [AppColors.surfaceTop, AppColors.surface],
    stops: [0.0, 0.6],
  );
}
