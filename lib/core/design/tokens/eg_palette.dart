import 'package:flutter/widgets.dart';

/// Os papéis de cor do Evergreen.
///
/// Um papel não é uma cor: é **o que aquela cor significa**. `raised` não é
/// "cinza um pouco mais claro", é "esta superfície está acima da que está
/// atrás dela" — e é por isso que o mesmo valor pode servir a uma linha
/// selecionada e a uma faixa de estado sem que nenhuma das duas saiba da
/// outra.
///
/// A regra que sustenta a lista: **os degraus de neutro têm de se ver**. A
/// paleta anterior amontoava cinco papéis entre `#0B` e `#2E`, e o olho não
/// separava fundo de cartão. Aqui vizinhos guardam pelo menos cinco pontos de
/// luminância entre si.
///
/// A outra regra é sobre o verde: **`accent` tem dois papéis e só dois** —
/// ligado e ação primária. Seleção, foco e rótulo selecionado deixaram de ser
/// verdes de propósito; quando tudo se destaca, nada se destaca.
@immutable
class EgPalette {
  const EgPalette({
    required this.canvas,
    required this.canvasDeep,
    required this.surface,
    required this.surfaceTop,
    required this.raised,
    required this.control,
    required this.hover,
    required this.pressed,
    required this.line,
    required this.edge,
    required this.edgeLight,
    required this.sidebarTint,
    required this.glassPanel,
    required this.glassRow,
    required this.glassControl,
    required this.accent,
    required this.accentLight,
    required this.accentDeep,
    required this.accentHover,
    required this.accentPressed,
    required this.onAccent,
    required this.ember,
    required this.tide,
    required this.focusRing,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textQuaternary,
    required this.textDisabled,
    required this.textSelection,
    required this.error,
    required this.warning,
    required this.shadow,
    required this.shadowContact,
    required this.scrim,
  });

  /// O topo do degradê da janela — o "chão" de tudo que não é superfície.
  final Color canvas;

  /// A base do mesmo degradê. Sozinha, é o fundo mais fundo do app.
  final Color canvasDeep;

  /// Cartão de seção: a superfície que carrega conteúdo dentro do canvas.
  final Color surface;

  /// O topo do degradê de uma superfície destacada (o bloco-instrumento).
  final Color surfaceTop;

  /// **Acima** da superfície: linha selecionada, faixa de estado, hover de
  /// pílula. É o papel que substituiu o verde a 14% da seleção antiga.
  final Color raised;

  /// Botão secundário, campo, keycap — o material de um controle em repouso.
  final Color control;

  /// Hover de controle.
  final Color hover;

  /// Pressionado. **Mais escuro que o repouso, não mais claro**: um controle
  /// que clareia ao ser apertado parece acender; um que escurece parece
  /// afundar, que é o que o dedo acabou de fazer com ele.
  final Color pressed;

  /// Divisor visível — o que separa duas linhas dentro do mesmo cartão.
  final Color line;

  /// A borda de um cartão: branco a 7%, não um cinza opaco. Sobre qualquer
  /// superfície da escala ela lê como aresta iluminada, e não como moldura.
  final Color edge;

  /// A hairline interna de luz, no topo de um painel ou de uma pílula. É o
  /// que faz uma superfície parecer feita de material em vez de desenhada.
  final Color edgeLight;

  /// O véu da barra lateral: branco a 2,6% sobre o canvas.
  ///
  /// Chapado, e não vidro, por custo: a barra lateral fica na tela o tempo
  /// todo, e um `BackdropFilter` permanente recompõe tudo atrás dela a cada
  /// quadro. Visualmente paga o mesmo papel.
  final Color sidebarTint;

  /// O vidro do painel flutuante — translúcido, para o blur atravessar.
  final Color glassPanel;

  /// Linha selecionada **dentro do vidro**. Sobre translucidez a escala de
  /// neutros não vale: o que está atrás muda a leitura de qualquer cinza
  /// opaco, então ali a seleção é branco com alfa.
  final Color glassRow;

  /// Controle dentro do vidro, pela mesma razão de [glassRow].
  final Color glassControl;

  /// O verde da casa. **Ligado, ou ação primária. Mais nada.**
  final Color accent;

  /// O verde claro de rótulo e glifo sobre fundo escuro — nunca de fundo.
  final Color accentLight;

  final Color accentDeep;
  final Color accentHover;
  final Color accentPressed;

  /// A tinta que se escreve sobre [accent], [ember] e [tide].
  final Color onAccent;

  /// Tempo de reunião, trabalho em curso, "está processando".
  ///
  /// Existe para que um segundo significado quantitativo não precise pedir o
  /// verde emprestado — era o que fazia a semana do Track ser verde inteira e
  /// não dizer nada.
  final Color ember;

  /// Arquivo e sistema: informação neutra que ainda assim precisa de cor.
  final Color tide;

  /// O anel de foco — **branco**, não verde. Foco não é estado do produto, é
  /// onde o teclado está; pintá-lo de accent gastava a única cor que o app
  /// tem para dizer "ligado".
  final Color focusRing;

  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textQuaternary;
  final Color textDisabled;
  final Color textSelection;

  final Color error;
  final Color warning;

  final Color shadow;
  final Color shadowContact;
  final Color scrim;

  static EgPalette lerp(EgPalette a, EgPalette b, double t) => EgPalette(
    canvas: Color.lerp(a.canvas, b.canvas, t)!,
    canvasDeep: Color.lerp(a.canvasDeep, b.canvasDeep, t)!,
    surface: Color.lerp(a.surface, b.surface, t)!,
    surfaceTop: Color.lerp(a.surfaceTop, b.surfaceTop, t)!,
    raised: Color.lerp(a.raised, b.raised, t)!,
    control: Color.lerp(a.control, b.control, t)!,
    hover: Color.lerp(a.hover, b.hover, t)!,
    pressed: Color.lerp(a.pressed, b.pressed, t)!,
    line: Color.lerp(a.line, b.line, t)!,
    edge: Color.lerp(a.edge, b.edge, t)!,
    edgeLight: Color.lerp(a.edgeLight, b.edgeLight, t)!,
    sidebarTint: Color.lerp(a.sidebarTint, b.sidebarTint, t)!,
    glassPanel: Color.lerp(a.glassPanel, b.glassPanel, t)!,
    glassRow: Color.lerp(a.glassRow, b.glassRow, t)!,
    glassControl: Color.lerp(a.glassControl, b.glassControl, t)!,
    accent: Color.lerp(a.accent, b.accent, t)!,
    accentLight: Color.lerp(a.accentLight, b.accentLight, t)!,
    accentDeep: Color.lerp(a.accentDeep, b.accentDeep, t)!,
    accentHover: Color.lerp(a.accentHover, b.accentHover, t)!,
    accentPressed: Color.lerp(a.accentPressed, b.accentPressed, t)!,
    onAccent: Color.lerp(a.onAccent, b.onAccent, t)!,
    ember: Color.lerp(a.ember, b.ember, t)!,
    tide: Color.lerp(a.tide, b.tide, t)!,
    focusRing: Color.lerp(a.focusRing, b.focusRing, t)!,
    textPrimary: Color.lerp(a.textPrimary, b.textPrimary, t)!,
    textSecondary: Color.lerp(a.textSecondary, b.textSecondary, t)!,
    textTertiary: Color.lerp(a.textTertiary, b.textTertiary, t)!,
    textQuaternary: Color.lerp(a.textQuaternary, b.textQuaternary, t)!,
    textDisabled: Color.lerp(a.textDisabled, b.textDisabled, t)!,
    textSelection: Color.lerp(a.textSelection, b.textSelection, t)!,
    error: Color.lerp(a.error, b.error, t)!,
    warning: Color.lerp(a.warning, b.warning, t)!,
    shadow: Color.lerp(a.shadow, b.shadow, t)!,
    shadowContact: Color.lerp(a.shadowContact, b.shadowContact, t)!,
    scrim: Color.lerp(a.scrim, b.scrim, t)!,
  );
}
