import 'package:flutter/widgets.dart';

/// As cores de um tema.
///
/// **Todos os campos são obrigatórios**, e é essa a regra que sustenta o
/// sistema: um tema novo não compila enquanto não responder a cada papel. Sem
/// isso, "tema faltando um token" seria um bug de tempo de execução, descoberto
/// numa tela que ninguém abriu essa semana.
///
/// Os nomes são **papéis**, nunca cores: `accent`, e não `green`. O tema Apple
/// também é verde, mas por coincidência — o dia em que um tema for azul, nada
/// aqui precisa ser renomeado.
@immutable
class EgPalette {
  const EgPalette({
    required this.background,
    required this.backgroundTop,
    required this.backgroundDeep,
    required this.surface,
    required this.surfaceTop,
    required this.surfaceFloating,
    required this.sidebar,
    required this.card,
    required this.cardTop,
    required this.control,
    required this.hover,
    required this.pressed,
    required this.border,
    required this.borderHighlight,
    required this.accent,
    required this.accentLight,
    required this.accentDeep,
    required this.accentShade,
    required this.accentGradient,
    required this.onAccent,
    required this.selection,
    required this.selectionGradient,
    required this.selectionLabel,
    required this.focusRing,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textQuaternary,
    required this.textSelection,
    required this.error,
    required this.warning,
    required this.shadow,
    required this.shadowContact,
    required this.scrim,
    required this.systemBlue,
    required this.systemIndigo,
    required this.systemTeal,
    required this.systemGray,
  });

  /// O fundo da janela, e o topo/base do gradiente sutil sobre ele.
  final Color background;
  final Color backgroundTop;
  final Color backgroundDeep;

  /// A superfície de um painel assentado, e o topo do gradiente dela.
  final Color surface;
  final Color surfaceTop;

  /// A superfície de um painel **flutuante** — o material do overlay.
  ///
  /// Separada da [surface] porque é ela que carrega a translucidez: no tema
  /// Apple ela é semitransparente e depende do blur atrás; no Evergreen é a
  /// mesma cor opaca da superfície assentada.
  final Color surfaceFloating;

  /// A superfície da barra lateral do Hub.
  ///
  /// Translúcida nos dois temas, por motivos diferentes: no Evergreen é o
  /// brilho verde do fundo que atravessa de leve e costura a sidebar com a área
  /// de conteúdo; no Apple é o que o sistema faz com toda sidebar, só que sem o
  /// custo de um blur permanente — um sólido com alfa sobre o fundo da janela.
  final Color sidebar;

  /// Cartão e campo — o degrau acima da superfície.
  final Color card;
  final Color cardTop;

  /// O fundo de um controle em repouso (botão secundário, pílula, trilho).
  final Color control;

  final Color hover;
  final Color pressed;

  /// A linha que separa. A **espessura** é do `EgShapes`, não daqui: no macOS
  /// ela tem meio pixel, e meio pixel é geometria.
  final Color border;

  /// O fio de luz no topo de uma superfície flutuante.
  final Color borderHighlight;

  /// A cor da ação e da seleção, e os três degraus dela.
  final Color accent;
  final Color accentLight;
  final Color accentDeep;
  final Color accentShade;

  /// O accent em degradê, quando o tema o usa em superfície preenchida.
  ///
  /// `null` diz "cor sólida" — não é ausência de valor, é a resposta do
  /// Evergreen, cuja linguagem não tem botão com degradê.
  final List<Color>? accentGradient;

  /// O texto que fica **em cima** do accent.
  final Color onAccent;

  /// O fundo de uma linha selecionada, e o degradê que o substitui quando o
  /// tema pinta seleção sólida (o padrão do `NSTableView`).
  final Color selection;
  final List<Color>? selectionGradient;

  /// O texto de uma linha selecionada.
  final Color selectionLabel;

  final Color focusRing;

  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  /// O texto mais apagado da interface — o que está desabilitado.
  final Color textQuaternary;

  /// O fundo do texto selecionado dentro de um campo.
  final Color textSelection;

  final Color error;
  final Color warning;

  final Color shadow;
  final Color shadowContact;

  /// O véu por trás de um diálogo.
  final Color scrim;

  /// As cores de sistema do macOS, para quando um significado pede uma cor que
  /// não é o accent. Existem nos dois temas: o Evergreen responde com o
  /// equivalente mais próximo da paleta dele.
  final Color systemBlue;
  final Color systemIndigo;
  final Color systemTeal;
  final Color systemGray;

  /// Interpola duas paletas, cor a cor.
  ///
  /// É o que faz a troca de tema atravessar como um cross-fade em vez de piscar
  /// de um lado para o outro. Os degradês são a exceção: um `null` no meio do
  /// caminho não tem como virar meia lista, então eles trocam na metade.
  static EgPalette lerp(EgPalette a, EgPalette b, double t) => EgPalette(
    background: Color.lerp(a.background, b.background, t)!,
    backgroundTop: Color.lerp(a.backgroundTop, b.backgroundTop, t)!,
    backgroundDeep: Color.lerp(a.backgroundDeep, b.backgroundDeep, t)!,
    surface: Color.lerp(a.surface, b.surface, t)!,
    surfaceTop: Color.lerp(a.surfaceTop, b.surfaceTop, t)!,
    surfaceFloating: Color.lerp(a.surfaceFloating, b.surfaceFloating, t)!,
    sidebar: Color.lerp(a.sidebar, b.sidebar, t)!,
    card: Color.lerp(a.card, b.card, t)!,
    cardTop: Color.lerp(a.cardTop, b.cardTop, t)!,
    control: Color.lerp(a.control, b.control, t)!,
    hover: Color.lerp(a.hover, b.hover, t)!,
    pressed: Color.lerp(a.pressed, b.pressed, t)!,
    border: Color.lerp(a.border, b.border, t)!,
    borderHighlight: Color.lerp(a.borderHighlight, b.borderHighlight, t)!,
    accent: Color.lerp(a.accent, b.accent, t)!,
    accentLight: Color.lerp(a.accentLight, b.accentLight, t)!,
    accentDeep: Color.lerp(a.accentDeep, b.accentDeep, t)!,
    accentShade: Color.lerp(a.accentShade, b.accentShade, t)!,
    accentGradient: t < 0.5 ? a.accentGradient : b.accentGradient,
    onAccent: Color.lerp(a.onAccent, b.onAccent, t)!,
    selection: Color.lerp(a.selection, b.selection, t)!,
    selectionGradient: t < 0.5 ? a.selectionGradient : b.selectionGradient,
    selectionLabel: Color.lerp(a.selectionLabel, b.selectionLabel, t)!,
    focusRing: Color.lerp(a.focusRing, b.focusRing, t)!,
    textPrimary: Color.lerp(a.textPrimary, b.textPrimary, t)!,
    textSecondary: Color.lerp(a.textSecondary, b.textSecondary, t)!,
    textTertiary: Color.lerp(a.textTertiary, b.textTertiary, t)!,
    textQuaternary: Color.lerp(a.textQuaternary, b.textQuaternary, t)!,
    textSelection: Color.lerp(a.textSelection, b.textSelection, t)!,
    error: Color.lerp(a.error, b.error, t)!,
    warning: Color.lerp(a.warning, b.warning, t)!,
    shadow: Color.lerp(a.shadow, b.shadow, t)!,
    shadowContact: Color.lerp(a.shadowContact, b.shadowContact, t)!,
    scrim: Color.lerp(a.scrim, b.scrim, t)!,
    systemBlue: Color.lerp(a.systemBlue, b.systemBlue, t)!,
    systemIndigo: Color.lerp(a.systemIndigo, b.systemIndigo, t)!,
    systemTeal: Color.lerp(a.systemTeal, b.systemTeal, t)!,
    systemGray: Color.lerp(a.systemGray, b.systemGray, t)!,
  );
}
