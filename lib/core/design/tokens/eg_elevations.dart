import 'package:flutter/widgets.dart';

/// As sombras e as linhas de luz do Evergreen.
///
/// Sombra sozinha não faz material: o painel anterior tinha uma sombra grande e
/// escura embaixo e mesmo assim parecia desenhado, não feito de vidro. O que
/// faltava era a luz — no macOS a borda superior de uma superfície translúcida
/// recebe o ambiente, e é essa hairline de 1 px que o olho lê como espessura.
/// Por isso as duas coisas moram na mesma classe.
@immutable
class EgElevations {
  const EgElevations({
    required this.floatingPanel,
    required this.card,
    required this.dropdown,
    required this.control,
    required this.focusRing,
    required this.panelInnerHairline,
    required this.rowInnerHairline,
  });

  final List<BoxShadow> floatingPanel;

  /// A sombra de contato de um cartão de seção.
  ///
  /// Curta, escura e quase sem desfoque: ela não levanta o cartão do fundo —
  /// **assenta** ele. Um cartão do mesmo matiz do fundo, sem sombra nenhuma,
  /// não tem por que parecer estar em cima de coisa alguma: o que separava os
  /// dois era só o contorno, e contorno em tudo vira desenho de arame.
  final List<BoxShadow> card;

  final List<BoxShadow> dropdown;

  /// Botão do Evergreen não levanta do fundo — daí a lista vazia. Está aqui
  /// para que a decisão seja legível, e não para ser preenchida um dia.
  final List<BoxShadow> control;

  final List<BoxShadow> focusRing;

  /// A linha de luz no topo interno de um painel flutuante.
  final Color? panelInnerHairline;

  /// A mesma linha, no topo de uma linha selecionada ou de uma faixa de
  /// estado. É o que faz "selecionado" ser lido como elevação em vez de cor —
  /// o Flutter não tem sombra interna, então a elevação se desenha com luz.
  final Color? rowInnerHairline;

  static List<BoxShadow> _shadows(
    List<BoxShadow> a,
    List<BoxShadow> b,
    double t,
  ) => BoxShadow.lerpList(a, b, t) ?? (t < 0.5 ? a : b);

  static EgElevations lerp(EgElevations a, EgElevations b, double t) =>
      EgElevations(
        floatingPanel: _shadows(a.floatingPanel, b.floatingPanel, t),
        card: _shadows(a.card, b.card, t),
        dropdown: _shadows(a.dropdown, b.dropdown, t),
        control: _shadows(a.control, b.control, t),
        focusRing: _shadows(a.focusRing, b.focusRing, t),
        panelInnerHairline: Color.lerp(
          a.panelInnerHairline,
          b.panelInnerHairline,
          t,
        ),
        rowInnerHairline: Color.lerp(a.rowInnerHairline, b.rowInnerHairline, t),
      );
}
