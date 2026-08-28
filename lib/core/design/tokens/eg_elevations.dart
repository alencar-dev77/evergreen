import 'package:flutter/widgets.dart';

/// As sombras de um tema — e, no Apple, os fios de luz que fazem as vezes de
/// relevo.
///
/// O Evergreen resolve profundidade só com sombra: superfície opaca, sombra
/// larga embaixo. O Apple soma a isso o que o AppKit faz há anos — uma linha
/// interna clara na borda do painel e um brilho no topo do controle, que é o
/// que dá a impressão de vidro em vez de retângulo pintado.
@immutable
class EgElevations {
  const EgElevations({
    required this.floatingPanel,
    required this.dropdown,
    required this.control,
    required this.focusRing,
    required this.panelInnerHairline,
    required this.controlHighlight,
  });

  /// A sombra do painel flutuante.
  final List<BoxShadow> floatingPanel;

  /// A sombra de um menu ou popover.
  final List<BoxShadow> dropdown;

  /// A sombra de contato de um controle. Vazia no Evergreen, onde botão não
  /// levanta do fundo.
  final List<BoxShadow> control;

  /// O anel de foco de teclado.
  final List<BoxShadow> focusRing;

  /// A linha clara **por dentro** da borda do painel. `null` diz "este tema não
  /// usa" — é a resposta do Evergreen, não a falta de uma.
  final Color? panelInnerHairline;

  /// O fio de luz no topo de um controle preenchido.
  final Color? controlHighlight;

  static List<BoxShadow> _lerpShadows(
    List<BoxShadow> a,
    List<BoxShadow> b,
    double t,
  ) => BoxShadow.lerpList(a, b, t) ?? (t < 0.5 ? a : b);

  static EgElevations lerp(EgElevations a, EgElevations b, double t) =>
      EgElevations(
        floatingPanel: _lerpShadows(a.floatingPanel, b.floatingPanel, t),
        dropdown: _lerpShadows(a.dropdown, b.dropdown, t),
        control: _lerpShadows(a.control, b.control, t),
        focusRing: _lerpShadows(a.focusRing, b.focusRing, t),
        panelInnerHairline: Color.lerp(
          a.panelInnerHairline,
          b.panelInnerHairline,
          t,
        ),
        controlHighlight: Color.lerp(a.controlHighlight, b.controlHighlight, t),
      );
}
