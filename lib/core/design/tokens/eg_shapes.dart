import 'package:flutter/widgets.dart';

import 'eg_squircle.dart';

/// Raios, alturas e paddings do Evergreen.
///
/// O raio subiu em toda a escala e passou a ser **contínuo** acima de
/// [EgSquircle.threshold] — era a causa do "tudo muito quadrado": um arco
/// circular de 6 a 12 pt contra um macOS que arredonda com curvatura contínua
/// e raio maior. Abaixo do limiar o arco circular fica, porque ali os dois são
/// indistinguíveis e o circular é mais barato de desenhar.
@immutable
class EgShapes {
  const EgShapes({
    required this.radiusWindow,
    required this.radiusPanel,
    required this.radiusStage,
    required this.radiusCard,
    required this.radiusRow,
    required this.radiusControl,
    required this.radiusSegment,
    required this.radiusChip,
    required this.radiusThumb,
    required this.hairline,
    required this.rowPaddingV,
    required this.rowPaddingH,
    required this.panelPadding,
    required this.listPadding,
    required this.controlHeight,
    required this.rowHeight,
    required this.rowHeightWithFootnote,
    required this.switchWidth,
    required this.switchHeight,
    required this.switchKnob,
  });

  /// A janela do Hub.
  final double radiusWindow;

  /// O painel flutuante.
  final double radiusPanel;

  /// O bloco-instrumento: o anel do Focus, a pilha do Nest, a bancada do
  /// gerador. É a superfície que não é cartão de ajuste nem painel.
  final double radiusStage;

  /// Cartão de seção.
  final double radiusCard;

  /// Linha de lista e item da barra lateral.
  final double radiusRow;

  /// Botão e campo.
  final double radiusControl;

  /// O segmento dentro do trilho de um segmented control.
  final double radiusSegment;

  /// A pílula: interruptor mestre, filtro, prazo. Grande o bastante para o
  /// raio bater na metade da altura em qualquer tamanho de pílula.
  final double radiusChip;

  /// A miniatura de imagem na linha de lista, do tamanho de um ícone. O raio
  /// de qualquer controle, num quadrado de 16 pontos, viraria um círculo.
  final double radiusThumb;

  final double hairline;

  final double rowPaddingV;
  final double rowPaddingH;
  final double panelPadding;
  final double listPadding;

  final double controlHeight;

  /// Linha de configuração sem explicação embaixo.
  final double rowHeight;

  /// Linha de configuração com a explicação de uma linha embaixo.
  final double rowHeightWithFootnote;

  final double switchWidth;
  final double switchHeight;
  final double switchKnob;

  ShapeBorder get windowShape => EgSquircle.shape(radiusWindow);
  ShapeBorder get panelShape => EgSquircle.shape(radiusPanel);
  ShapeBorder get stageShape => EgSquircle.shape(radiusStage);
  ShapeBorder get cardShape => EgSquircle.shape(radiusCard);

  BorderRadius get panelAll => EgSquircle.radius(radiusPanel);
  BorderRadius get stageAll => EgSquircle.radius(radiusStage);
  BorderRadius get cardAll => EgSquircle.radius(radiusCard);
  BorderRadius get rowAll => EgSquircle.radius(radiusRow);
  BorderRadius get controlAll => EgSquircle.radius(radiusControl);
  BorderRadius get segmentAll => EgSquircle.radius(radiusSegment);
  BorderRadius get chipAll => BorderRadius.circular(radiusChip);

  static EgShapes lerp(EgShapes a, EgShapes b, double t) => EgShapes(
    radiusWindow: _d(a.radiusWindow, b.radiusWindow, t),
    radiusPanel: _d(a.radiusPanel, b.radiusPanel, t),
    radiusStage: _d(a.radiusStage, b.radiusStage, t),
    radiusCard: _d(a.radiusCard, b.radiusCard, t),
    radiusRow: _d(a.radiusRow, b.radiusRow, t),
    radiusControl: _d(a.radiusControl, b.radiusControl, t),
    radiusSegment: _d(a.radiusSegment, b.radiusSegment, t),
    radiusChip: _d(a.radiusChip, b.radiusChip, t),
    radiusThumb: _d(a.radiusThumb, b.radiusThumb, t),
    hairline: _d(a.hairline, b.hairline, t),
    rowPaddingV: _d(a.rowPaddingV, b.rowPaddingV, t),
    rowPaddingH: _d(a.rowPaddingH, b.rowPaddingH, t),
    panelPadding: _d(a.panelPadding, b.panelPadding, t),
    listPadding: _d(a.listPadding, b.listPadding, t),
    controlHeight: _d(a.controlHeight, b.controlHeight, t),
    rowHeight: _d(a.rowHeight, b.rowHeight, t),
    rowHeightWithFootnote: _d(
      a.rowHeightWithFootnote,
      b.rowHeightWithFootnote,
      t,
    ),
    switchWidth: _d(a.switchWidth, b.switchWidth, t),
    switchHeight: _d(a.switchHeight, b.switchHeight, t),
    switchKnob: _d(a.switchKnob, b.switchKnob, t),
  );

  static double _d(double a, double b, double t) => a + (b - a) * t;
}
