import 'package:flutter/material.dart';

import '../tokens/eg_elevations.dart';
import '../tokens/eg_motion.dart';
import '../tokens/eg_palette.dart';
import '../tokens/eg_shapes.dart';
import '../tokens/eg_type_scale.dart';

/// O tema da casa — a paleta "Dark Premium" com que o Evergreen nasceu.
///
/// **Os valores literais do produto vivem aqui e no `apple_tokens.dart`, e em
/// nenhum outro lugar.** Widget que precisa de uma cor, de um raio ou de um
/// tamanho o pede ao tema; se o papel não existe, ele nasce nos dois arquivos
/// ao mesmo tempo — é o compilador que cobra o segundo.
abstract final class EvergreenTokens {
  static const palette = EgPalette(
    background: Color(0xFF0B0B0B),
    backgroundTop: Color(0xFF12140F),
    backgroundDeep: Color(0xFF080808),
    surface: Color(0xFF141414),
    surfaceTop: Color(0xFF191B17),
    // Opaca: o painel do Evergreen é uma superfície, não um vidro.
    sidebar: Color(0xB8141414),
    surfaceFloating: Color(0xFF141414),
    card: Color(0xFF1A1A1A),
    cardTop: Color(0xFF1F1F1F),
    control: Color(0xFF1A1A1A),
    hover: Color(0xFF232323),
    pressed: Color(0xFF2E2E2E),
    border: Color(0xFF262626),
    borderHighlight: Color(0x0FFFFFFF),
    accent: Color(0xFF22C55E),
    accentLight: Color(0xFF4ADE80),
    accentDeep: Color(0xFF16A34A),
    accentShade: Color(0xFF15803D),
    // Sem degradê: a linguagem daqui não tem botão com gradiente.
    accentGradient: null,
    onAccent: Color(0xFF0B0B0B),
    // Accent a 14% — e a aresta de 3px do `EgShapes` junto. Os dois são a
    // seleção do Evergreen; nenhum dos dois sozinho é.
    selection: Color(0x2422C55E),
    selectionGradient: null,
    // O rótulo da linha selecionada é **verde** aqui, e não branco: sobre um
    // fundo accent a 14% é a cor do texto que confirma a seleção. No tema Apple
    // é branco, porque lá o fundo já é o accent inteiro.
    selectionLabel: Color(0xFF4ADE80),
    focusRing: Color(0x9922C55E),
    textPrimary: Color(0xFFF5F5F5),
    textSecondary: Color(0xFF9CA3AF),
    textTertiary: Color(0xFF6B7280),
    textQuaternary: Color(0x599CA3AF),
    textSelection: Color(0x4022C55E),
    error: Color(0xFFEF4444),
    warning: Color(0xFFF59E0B),
    shadow: Color(0x8C000000),
    shadowContact: Color(0x66000000),
    scrim: Color(0x99000000),
    // As cores de sistema, respondidas pela paleta da casa: aqui elas não são
    // as do macOS, são o equivalente mais próximo daqui — senão um significado
    // secundário chegaria mais vivo que o accent.
    systemBlue: Color(0xFF3B82F6),
    systemIndigo: Color(0xFF6366F1),
    systemTeal: Color(0xFF2DD4BF),
    systemGray: Color(0xFF6B7280),
  );

  static const _fontFamily = 'Inter';

  static const _fallback = <String>[
    'SF Pro Display',
    'SF Pro Text',
    '.AppleSystemUIFont',
    'Helvetica Neue',
  ];

  static const _base = TextStyle(
    fontFamily: _fontFamily,
    fontFamilyFallback: _fallback,
    color: Color(0xFFF5F5F5),
    decoration: TextDecoration.none,
  );

  static const _secondary = TextStyle(
    fontFamily: _fontFamily,
    fontFamilyFallback: _fallback,
    color: Color(0xFF9CA3AF),
    decoration: TextDecoration.none,
  );

  static final type = EgTypeScale(
    screenTitle: _base.copyWith(
      fontSize: 17,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
      height: 1.3,
    ),
    sectionTitle: _base.copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      height: 1.3,
    ),
    panelTitle: _base.copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      height: 1.3,
    ),
    body: _base.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.4,
    ),
    bodyEmphasis: _base.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      height: 1.4,
    ),
    bodyStrong: _base.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
      height: 1.4,
    ),
    reading: _base.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.65,
    ),
    bodyCompact: _base.copyWith(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      height: 1.4,
    ),
    bodyCompactEmphasis: _base.copyWith(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      height: 1.4,
    ),
    caption: _secondary.copyWith(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      height: 1.5,
    ),
    captionSmall: _secondary.copyWith(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.4,
    ),
    captionSmallEmphasis: _secondary.copyWith(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      height: 1.4,
    ),
    captionXS: _secondary.copyWith(
      fontSize: 11,
      fontWeight: FontWeight.w400,
      height: 1.4,
    ),
    overline: _secondary.copyWith(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.66,
      height: 1.3,
    ),
    button: _base.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      height: 1.2,
    ),
    timer: _base.copyWith(
      fontSize: 36,
      fontWeight: FontWeight.w500,
      letterSpacing: -0.5,
      height: 1.1,
      fontFeatures: const [FontFeature.tabularFigures()],
    ),
    mono: const TextStyle(
      fontFamily: 'SF Mono',
      fontFamilyFallback: ['Menlo', 'monospace'],
      fontSize: 12,
      color: Color(0xFFF5F5F5),
      decoration: TextDecoration.none,
    ),
    monoSmall: const TextStyle(
      fontFamily: 'SF Mono',
      fontFamilyFallback: ['Menlo', 'monospace'],
      fontSize: 11,
      color: Color(0xFFF5F5F5),
      decoration: TextDecoration.none,
    ),
  );

  static const shapes = EgShapes(
    radiusPanel: 12,
    radiusCard: 8,
    radiusControl: 8,
    radiusRow: 6,
    radiusSmall: 4,
    hairline: 1,
    rowPaddingV: 8,
    rowPaddingH: 10,
    panelPadding: 16,
    listPadding: 16,
    controlHeight: 36,
    switchWidth: 36,
    switchHeight: 21,
    switchKnob: 15,
    selectionEdge: 3,
  );

  static const elevations = EgElevations(
    floatingPanel: [
      BoxShadow(
        color: Color(0x8C000000),
        blurRadius: 60,
        offset: Offset(0, 24),
        spreadRadius: -12,
      ),
      BoxShadow(
        color: Color(0x66000000),
        blurRadius: 12,
        offset: Offset(0, 4),
        spreadRadius: -6,
      ),
    ],
    dropdown: [
      BoxShadow(
        color: Color(0x8C000000),
        blurRadius: 24,
        offset: Offset(0, 8),
        spreadRadius: -8,
      ),
    ],
    // Botão daqui não levanta do fundo.
    control: [],
    focusRing: [
      BoxShadow(color: Color(0x9922C55E), blurRadius: 0, spreadRadius: 1),
    ],
    panelInnerHairline: null,
    controlHighlight: null,
  );

  static const motion = EgMotion(
    instant: Duration(milliseconds: 90),
    fast: Duration(milliseconds: 150),
    entrance: Duration(milliseconds: 120),
    medium: Duration(milliseconds: 220),
    settle: Duration(milliseconds: 60),
    curve: Curves.easeOutCubic,
  );
}
