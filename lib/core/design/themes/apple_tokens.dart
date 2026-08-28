import 'package:flutter/material.dart';

import '../tokens/eg_elevations.dart';
import '../tokens/eg_motion.dart';
import '../tokens/eg_palette.dart';
import '../tokens/eg_shapes.dart';
import '../tokens/eg_type_scale.dart';

/// O tema Apple — o escuro do macOS, nas medidas do HIG.
///
/// Três coisas o separam do tema da casa, e nenhuma é a cor: as superfícies
/// flutuantes são **translúcidas** (é o `usesVibrancy` que liga o blur), as
/// linhas têm **meio pixel**, e a densidade é a do System Settings — linha de
/// 26px de controle, não de 36.
///
/// Os cinzas de texto são o `#EBEBF5` da Apple com opacidade, e não cinzas
/// próprios: sobre fundo escuro ele puxa levemente para o azul, e é isso que
/// faz o texto secundário do macOS não parecer sujo.
abstract final class AppleTokens {
  static const palette = EgPalette(
    background: Color(0xFF161618),
    // O gradiente de fundo é quase nada aqui: o macOS escuro é chapado, e a
    // profundidade vem do material flutuante, não de uma luz pintada no fundo.
    backgroundTop: Color(0xFF1A1A1C),
    backgroundDeep: Color(0xFF121214),
    surface: Color(0xFF1E1E20),
    surfaceTop: Color(0xFF232326),
    // 72% — o resto é o que estiver atrás, borrado. Sem o blur do
    // `usesVibrancy` esta cor sozinha só pareceria um cinza mal escolhido.
    sidebar: Color(0xCC1E1E20),
    surfaceFloating: Color(0xB828282C),
    card: Color(0x12FFFFFF),
    cardTop: Color(0x16FFFFFF),
    control: Color(0x1CFFFFFF),
    hover: Color(0x17FFFFFF),
    pressed: Color(0x24FFFFFF),
    border: Color(0x1AFFFFFF),
    borderHighlight: Color(0x2EFFFFFF),
    accent: Color(0xFF30D158),
    accentLight: Color(0xFF3AD65F),
    accentDeep: Color(0xFF28B84D),
    accentShade: Color(0xFF1F8F3C),
    accentGradient: [Color(0xFF3AD65F), Color(0xFF28B84D)],
    onAccent: Color(0xFFFFFFFF),
    selection: Color(0xFF30D158),
    selectionGradient: [Color(0xFF3AD65F), Color(0xFF28B84D)],
    selectionLabel: Color(0xFFFFFFFF),
    focusRing: Color(0x4730D158),
    textPrimary: Color(0xEBFFFFFF),
    textSecondary: Color(0x99EBEBF5),
    textTertiary: Color(0x4DEBEBF5),
    textQuaternary: Color(0x2EEBEBF5),
    textSelection: Color(0x5930D158),
    error: Color(0xFFFF453A),
    warning: Color(0xFFFF9F0A),
    shadow: Color(0x80000000),
    shadowContact: Color(0x59000000),
    scrim: Color(0x8C000000),
    systemBlue: Color(0xFF0A84FF),
    systemIndigo: Color(0xFF5E5CE6),
    systemTeal: Color(0xFF40C8E0),
    systemGray: Color(0xFF98989D),
  );

  /// Família nula, com a fonte do sistema na lista de fallback.
  ///
  /// Nula é como se pede "a fonte do sistema" no macOS — a SF Pro que o Finder
  /// usa. A lista existe para os dois lugares em que ela não aparece: o
  /// `.AppleSystemUIFont` resolve quando a SF Pro não está instalada por nome,
  /// e o Inter no fim é o que salva os goldens — sob `flutter test` não há
  /// fonte de sistema nenhuma, e sem ele as imagens do tema Apple saem com
  /// caixinhas no lugar das letras.
  /// Nomeada, e não nula: `null` pede "a fonte padrão", e sob `flutter test` a
  /// padrão é a fonte de caixinhas — as imagens do tema Apple saíam sem uma
  /// letra sequer. Nomeando a SF Pro Text e deixando o `.AppleSystemUIFont`
  /// logo atrás, o macOS responde a mesma coisa nos dois casos: quem tem a SF
  /// Pro instalada pega ela, quem não tem pega a fonte de sistema, que é a
  /// mesma família.
  static const _family = 'SF Pro Text';

  static const _fallback = <String>[
    '.AppleSystemUIFont',
    'Helvetica Neue',
    'Inter',
  ];

  static const _base = TextStyle(
    fontFamily: _family,
    fontFamilyFallback: _fallback,
    color: Color(0xEBFFFFFF),
    decoration: TextDecoration.none,
  );

  static const _secondary = TextStyle(
    fontFamily: _family,
    fontFamilyFallback: _fallback,
    color: Color(0x99EBEBF5),
    decoration: TextDecoration.none,
  );

  /// O peso 590 não é engano: é o "Semibold" real da SF, entre o 500 e o 600 da
  /// escala variável. É o que o macOS usa em título de janela.
  static const _semibold = FontWeight.w600;

  static final type = EgTypeScale(
    screenTitle: _base.copyWith(
      fontSize: 15,
      fontWeight: _semibold,
      letterSpacing: -0.3,
      height: 1.3,
    ),
    sectionTitle: _base.copyWith(
      fontSize: 13,
      fontWeight: _semibold,
      letterSpacing: -0.08,
      height: 1.3,
    ),
    panelTitle: _base.copyWith(
      fontSize: 13,
      fontWeight: _semibold,
      letterSpacing: -0.08,
      height: 1.3,
    ),
    body: _base.copyWith(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      letterSpacing: -0.08,
      height: 1.4,
    ),
    bodyEmphasis: _base.copyWith(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      letterSpacing: -0.08,
      height: 1.4,
    ),
    bodyStrong: _base.copyWith(
      fontSize: 13,
      fontWeight: _semibold,
      letterSpacing: -0.08,
      height: 1.4,
    ),
    reading: _base.copyWith(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      letterSpacing: -0.08,
      height: 1.6,
    ),
    bodyCompact: _base.copyWith(
      fontSize: 12.5,
      fontWeight: FontWeight.w400,
      letterSpacing: -0.06,
      height: 1.4,
    ),
    bodyCompactEmphasis: _base.copyWith(
      fontSize: 12.5,
      fontWeight: FontWeight.w500,
      letterSpacing: -0.06,
      height: 1.4,
    ),
    caption: _secondary.copyWith(
      fontSize: 11.5,
      fontWeight: FontWeight.w400,
      height: 1.45,
    ),
    captionSmall: _secondary.copyWith(
      fontSize: 11,
      fontWeight: FontWeight.w400,
      height: 1.4,
    ),
    captionSmallEmphasis: _secondary.copyWith(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      height: 1.4,
    ),
    captionXS: _secondary.copyWith(
      fontSize: 10.5,
      fontWeight: FontWeight.w400,
      height: 1.35,
    ),
    // Tracking mais largo que o do Evergreen e peso menor: o header de grupo do
    // System Settings é discreto, quase um sussurro em cima da lista.
    overline: _secondary.copyWith(
      fontSize: 10.5,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.6,
      height: 1.3,
    ),
    button: _base.copyWith(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      letterSpacing: -0.08,
      height: 1.2,
    ),
    timer: _base.copyWith(
      fontSize: 34,
      fontWeight: FontWeight.w300,
      letterSpacing: -1,
      height: 1.1,
      fontFeatures: const [FontFeature.tabularFigures()],
    ),
    mono: const TextStyle(
      fontFamily: 'SF Mono',
      fontFamilyFallback: ['Menlo', 'monospace'],
      fontSize: 11,
      color: Color(0xEBFFFFFF),
      decoration: TextDecoration.none,
    ),
    monoSmall: const TextStyle(
      fontFamily: 'SF Mono',
      fontFamilyFallback: ['Menlo', 'monospace'],
      fontSize: 10.5,
      color: Color(0xEBFFFFFF),
      decoration: TextDecoration.none,
    ),
  );

  static const shapes = EgShapes(
    radiusPanel: 14,
    radiusCard: 9,
    radiusControl: 7,
    radiusRow: 6,
    radiusSmall: 5,
    // Meio pixel: o hairline do macOS.
    hairline: 0.5,
    rowPaddingV: 5,
    rowPaddingH: 8,
    panelPadding: 16,
    listPadding: 6,
    controlHeight: 26,
    switchWidth: 38,
    switchHeight: 22,
    switchKnob: 18,
    // A linha selecionada é preenchida inteira pelo accent; a aresta seria
    // dizer a mesma coisa duas vezes.
    selectionEdge: 0,
  );

  static const elevations = EgElevations(
    floatingPanel: [
      BoxShadow(
        color: Color(0x80000000),
        blurRadius: 60,
        offset: Offset(0, 24),
        spreadRadius: -14,
      ),
      BoxShadow(
        color: Color(0x40000000),
        blurRadius: 8,
        offset: Offset(0, 2),
        spreadRadius: -4,
      ),
    ],
    dropdown: [
      BoxShadow(
        color: Color(0x73000000),
        blurRadius: 40,
        offset: Offset(0, 14),
        spreadRadius: -10,
      ),
    ],
    control: [
      BoxShadow(
        color: Color(0x59000000),
        blurRadius: 1,
        offset: Offset(0, 0.5),
      ),
    ],
    // Glow largo em vez de borda: o foco do macOS é um halo, não um contorno.
    focusRing: [
      BoxShadow(color: Color(0x4730D158), blurRadius: 0, spreadRadius: 3.5),
    ],
    panelInnerHairline: Color(0x2EFFFFFF),
    controlHighlight: Color(0x40FFFFFF),
  );

  static const motion = EgMotion(
    instant: Duration(milliseconds: 90),
    fast: Duration(milliseconds: 150),
    entrance: Duration(milliseconds: 120),
    medium: Duration(milliseconds: 220),
    settle: Duration(milliseconds: 60),
    curve: Curves.easeOutQuart,
  );
}
