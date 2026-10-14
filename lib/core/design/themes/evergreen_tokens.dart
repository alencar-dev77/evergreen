import 'package:flutter/material.dart';

import '../tokens/eg_elevations.dart';
import '../tokens/eg_motion.dart';
import '../tokens/eg_palette.dart';
import '../tokens/eg_shapes.dart';
import '../tokens/eg_type_scale.dart';

/// O tema do Evergreen — a paleta "Estufa".
///
/// **Os valores literais do produto vivem aqui, e em nenhum outro lugar.**
/// Widget que precisa de uma cor, de um raio, de uma sombra ou de uma duração
/// pede ao tema; papel que falta nasce nos tokens, com nome, e não num
/// `copyWith` no meio de uma tela.
///
/// O nome é a tese: um material em comum e sete formas diferentes. O vidro, a
/// luz, a tipografia e a matriz de estados são do sistema; o layout é do
/// módulo.
abstract final class EvergreenTokens {
  static const palette = EgPalette(
    // Neutros com amplitude de verdade: de #08 a #36, com pelo menos cinco
    // pontos de luminância entre vizinhos. A escala anterior amontoava cinco
    // papéis entre #0B e #2E, e o olho não separava fundo de cartão.
    //
    // O fundo é o mais fundo do app, e é assim que o cartão aparece. Com o
    // canvas em #14181A o cartão tinha cinco pontos de vantagem sobre ele —
    // no papel. Na tela não tinha nenhum: o halo verde da janela mora
    // justamente no alto, que é onde os cartões estão, e levantava o canal
    // verde do fundo até o do cartão. O cartão virava uma mancha cinza sobre
    // um campo esverdeado da mesma claridade. O halo baixou pela metade e o
    // fundo desceu com ele.
    canvas: Color(0xFF0F1315),
    canvasDeep: Color(0xFF08090A),
    surface: Color(0xFF191E20),
    surfaceTop: Color(0xFF1D2325),
    raised: Color(0xFF212729),
    control: Color(0xFF272E31),
    hover: Color(0xFF2E3639),
    // Afunda, não clareia.
    pressed: Color(0xFF1D2325),
    line: Color(0xFF363F42),
    // Bordas são luz com alfa, não cinza opaco: assim a mesma borda serve ao
    // cartão sobre o canvas e ao cartão sobre o vidro. A 7% ela existia só na
    // especificação; o contorno do cartão é a segunda coisa que o separa do
    // fundo, e precisa ser vista sem se procurar.
    edge: Color(0x1AFFFFFF),
    edgeLight: Color(0x24FFFFFF),
    sidebarTint: Color(0x07FFFFFF),

    // Vidro — só a janela flutuante e o dropdown chegam aqui.
    glassPanel: Color(0xA8161B1D),
    glassRow: Color(0x1AFFFFFF),
    glassControl: Color(0x17FFFFFF),

    // O verde, com dois papéis e só dois: ligado e ação primária.
    accent: Color(0xFF22C55E),
    accentLight: Color(0xFF6EE7A0),
    accentDeep: Color(0xFF15803D),
    accentHover: Color(0xFF2ED26B),
    accentPressed: Color(0xFF18A652),
    onAccent: Color(0xFF08090A),

    // As duas cores de dado. Sem elas, toda quantidade do app virava verde —
    // e a semana do Track, verde inteira, não dizia nada.
    ember: Color(0xFFE8B24A),
    tide: Color(0xFF5B9CF6),

    // Branco: foco é onde o teclado está, não um estado do produto.
    focusRing: Color(0x57FFFFFF),

    textPrimary: Color(0xFFEDF2F0),
    textSecondary: Color(0xFF9BA6A3),
    textTertiary: Color(0xFF6B7674),
    textQuaternary: Color(0xFF4C5457),
    textDisabled: Color(0xFF454E51),
    textSelection: Color(0x4022C55E),
    // Branco a 16%: um degrau acima de qualquer superfície da leitura, sem
    // cor própria — o termo se acende sem dizer nada além de "está aqui".
    findMark: Color(0x29FFFFFF),

    error: Color(0xFFEF4444),
    warning: Color(0xFFE8B24A),

    shadow: Color(0xC7000000),
    shadowContact: Color(0x73000000),
    scrim: Color(0x9E000000),
  );

  static const _fontFamily = 'Inter';

  static const _fallback = <String>[
    'SF Pro Display',
    'SF Pro Text',
    '.AppleSystemUIFont',
    'Helvetica Neue',
  ];

  static const _monoFamily = 'SF Mono';
  static const _monoFallback = <String>['Menlo', 'monospace'];

  static const _base = TextStyle(
    fontFamily: _fontFamily,
    fontFamilyFallback: _fallback,
    color: Color(0xFFEDF2F0),
    decoration: TextDecoration.none,
  );

  static const _secondary = TextStyle(
    fontFamily: _fontFamily,
    fontFamilyFallback: _fallback,
    color: Color(0xFF9BA6A3),
    decoration: TextDecoration.none,
  );

  static const _monoBase = TextStyle(
    fontFamily: _monoFamily,
    fontFamilyFallback: _monoFallback,
    color: Color(0xFFEDF2F0),
    decoration: TextDecoration.none,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static final type = EgTypeScale(
    // O ponto de entrada que não existia: o topo da escala era 17 pt, e toda
    // tela começava com o mesmo peso do que vinha depois dela.
    display: _base.copyWith(
      fontSize: 30,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.78,
      height: 1.0,
    ),
    title: _base.copyWith(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.28,
      height: 1.2,
    ),
    panelTitle: _base.copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      height: 1.2,
    ),
    body: _base.copyWith(
      fontSize: 13.5,
      fontWeight: FontWeight.w400,
      height: 1.4,
    ),
    bodyEmphasis: _base.copyWith(
      fontSize: 13.5,
      fontWeight: FontWeight.w500,
      height: 1.4,
    ),
    bodyStrong: _base.copyWith(
      fontSize: 13.5,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.1,
      height: 1.3,
    ),
    bodyCompact: _base.copyWith(
      fontSize: 12.5,
      fontWeight: FontWeight.w400,
      height: 1.4,
    ),
    reading: _base.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.65,
    ),
    footnote: _secondary.copyWith(
      fontSize: 11.5,
      fontWeight: FontWeight.w400,
      height: 1.35,
    ),
    caption: _secondary.copyWith(
      fontSize: 11.5,
      fontWeight: FontWeight.w400,
      height: 1.5,
    ),
    // Mono: rótulo de estrutura, não de conteúdo. Em mono com tracking largo o
    // olho o lê como etiqueta de gaveta e para de disputar com o corpo.
    overline: _monoBase.copyWith(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.99,
      height: 1.0,
      color: const Color(0xFF6B7674),
    ),
    keycap: _monoBase.copyWith(
      fontSize: 10.5,
      fontWeight: FontWeight.w600,
      height: 1.0,
    ),
    button: _base.copyWith(
      fontSize: 12.5,
      fontWeight: FontWeight.w600,
      height: 1.0,
    ),
    timer: _base.copyWith(
      fontSize: 48,
      fontWeight: FontWeight.w500,
      letterSpacing: -0.96,
      height: 1.0,
      fontFeatures: const [FontFeature.tabularFigures()],
    ),
    timerSmall: _base.copyWith(
      fontSize: 32,
      fontWeight: FontWeight.w500,
      letterSpacing: -0.64,
      height: 1.0,
      fontFeatures: const [FontFeature.tabularFigures()],
    ),
    mono: _monoBase.copyWith(fontSize: 12, height: 1.4),
    monoSmall: _monoBase.copyWith(
      fontSize: 10.5,
      fontWeight: FontWeight.w500,
      height: 1.4,
    ),
  );

  static const shapes = EgShapes(
    radiusWindow: 28,
    radiusPanel: 22,
    radiusStage: 20,
    radiusCard: 17,
    radiusRow: 13,
    radiusControl: 12,
    radiusSegment: 9,
    radiusChip: 999,
    hairline: 1,
    rowPaddingV: 9,
    rowPaddingH: 12,
    panelPadding: 16,
    listPadding: 16,
    controlHeight: 32,
    rowHeight: 38,
    rowHeightWithFootnote: 46,
    switchWidth: 34,
    switchHeight: 20,
    switchKnob: 15,
  );

  static const elevations = EgElevations(
    floatingPanel: [
      BoxShadow(
        color: Color(0xC7000000),
        blurRadius: 56,
        offset: Offset(0, 28),
        spreadRadius: -20,
      ),
      BoxShadow(
        color: Color(0x73000000),
        blurRadius: 12,
        offset: Offset(0, 4),
        spreadRadius: -6,
      ),
    ],
    // O cartão de seção: sombra de contato, e só. Ver `EgElevations.card`.
    card: [
      BoxShadow(
        color: Color(0x73000000),
        blurRadius: 12,
        offset: Offset(0, 4),
        spreadRadius: -6,
      ),
    ],
    dropdown: [
      BoxShadow(
        color: Color(0xB3000000),
        blurRadius: 24,
        offset: Offset(0, 8),
        spreadRadius: -8,
      ),
    ],
    control: [],
    focusRing: [
      BoxShadow(color: Color(0x57FFFFFF), blurRadius: 0, spreadRadius: 2),
    ],
    panelInnerHairline: Color(0x24FFFFFF),
    rowInnerHairline: Color(0x14FFFFFF),
  );

  static const motion = EgMotion(
    instant: Duration(milliseconds: 90),
    fast: Duration(milliseconds: 140),
    entrance: Duration(milliseconds: 120),
    medium: Duration(milliseconds: 220),
    stack: Duration(milliseconds: 160),
    settle: Duration(milliseconds: 60),
    // Chega mais rápido e assenta mais macio que o easeOutCubic anterior.
    curve: Curves.easeOutQuint,
  );
}
