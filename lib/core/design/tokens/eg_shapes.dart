import 'package:flutter/widgets.dart';

/// A geometria de um tema: raio, espessura de linha, densidade de linha e o
/// tamanho dos controles.
///
/// É aqui que mora a maior diferença entre os dois temas depois da cor. O
/// Evergreen é mais alto e mais arredondado; o Apple é denso, com meio pixel de
/// linha e raio menor — a densidade do System Settings, não a de um app web.
@immutable
class EgShapes {
  const EgShapes({
    required this.radiusPanel,
    required this.radiusCard,
    required this.radiusControl,
    required this.radiusRow,
    required this.radiusSmall,
    required this.hairline,
    required this.rowPaddingV,
    required this.rowPaddingH,
    required this.panelPadding,
    required this.listPadding,
    required this.controlHeight,
    required this.switchWidth,
    required this.switchHeight,
    required this.switchKnob,
    required this.selectionEdge,
  });

  final double radiusPanel;
  final double radiusCard;
  final double radiusControl;
  final double radiusRow;
  final double radiusSmall;

  /// A espessura de uma linha divisória.
  ///
  /// Meio pixel no tema Apple — o `hairline` do macOS, que numa tela Retina é
  /// um pixel físico e por isso não some. É a diferença entre uma tabela do
  /// sistema e uma tabela desenhada por quem só teve pixels inteiros.
  final double hairline;

  /// O respiro de uma linha de lista ou de configuração.
  final double rowPaddingV;
  final double rowPaddingH;

  /// O respiro interno de um painel de conteúdo, e o de uma lista dentro dele.
  final double panelPadding;
  final double listPadding;

  /// A altura de um controle de tamanho normal — botão, campo, pílula.
  final double controlHeight;

  final double switchWidth;
  final double switchHeight;
  final double switchKnob;

  /// A aresta à esquerda de uma linha selecionada.
  ///
  /// Três pixels no Evergreen, e é assinatura dele: seleção é fundo accent
  /// suave **mais** a aresta. Zero no Apple, onde a linha selecionada é
  /// preenchida inteira pelo accent, como no `NSTableView` — os dois juntos
  /// seriam dizer a mesma coisa duas vezes.
  final double selectionEdge;

  BorderRadius get panelAll => BorderRadius.circular(radiusPanel);
  BorderRadius get cardAll => BorderRadius.circular(radiusCard);
  BorderRadius get controlAll => BorderRadius.circular(radiusControl);
  BorderRadius get rowAll => BorderRadius.circular(radiusRow);
  BorderRadius get smallAll => BorderRadius.circular(radiusSmall);

  static EgShapes lerp(EgShapes a, EgShapes b, double t) => EgShapes(
    radiusPanel: lerpDouble(a.radiusPanel, b.radiusPanel, t),
    radiusCard: lerpDouble(a.radiusCard, b.radiusCard, t),
    radiusControl: lerpDouble(a.radiusControl, b.radiusControl, t),
    radiusRow: lerpDouble(a.radiusRow, b.radiusRow, t),
    radiusSmall: lerpDouble(a.radiusSmall, b.radiusSmall, t),
    hairline: lerpDouble(a.hairline, b.hairline, t),
    rowPaddingV: lerpDouble(a.rowPaddingV, b.rowPaddingV, t),
    rowPaddingH: lerpDouble(a.rowPaddingH, b.rowPaddingH, t),
    panelPadding: lerpDouble(a.panelPadding, b.panelPadding, t),
    listPadding: lerpDouble(a.listPadding, b.listPadding, t),
    controlHeight: lerpDouble(a.controlHeight, b.controlHeight, t),
    switchWidth: lerpDouble(a.switchWidth, b.switchWidth, t),
    switchHeight: lerpDouble(a.switchHeight, b.switchHeight, t),
    switchKnob: lerpDouble(a.switchKnob, b.switchKnob, t),
    selectionEdge: lerpDouble(a.selectionEdge, b.selectionEdge, t),
  );

  static double lerpDouble(double a, double b, double t) => a + (b - a) * t;
}
