import 'dart:ui' show lerpDouble;

import 'package:flutter/widgets.dart';

import '../../core/design/app_colors.dart';
import '../../core/design/app_metrics.dart';
import 'eg_hoverable.dart';
import '../../core/design/eg_tokens.dart';

/// A matriz de estado das superfícies interativas do Evergreen.
///
/// Todo elemento clicável do app — botão, linha de lista, item de sidebar,
/// pílula do segmented control, cartão do Leaf — resolve a própria aparência
/// por esta tabela, e não por um `if` escrito no widget. Antes desta classe a
/// mesma cadeia de `if`s existia copiada em seis arquivos, e as cópias já
/// tinham divergido: o cartão do Leaf não tinha `pressed`, a linha do Pin não
/// reagia ao foco, e a ordem entre "selecionado" e "pressionado" mudava de um
/// componente para o outro.
///
/// **Precedência, do mais forte para o mais fraco:**
///
/// | Estado | Vence quem | Por quê |
/// |---|---|---|
/// | `disabled` | todos | o controle não responde: nenhum outro estado é verdade |
/// | `selected` | pressed, hover, focus | é onde o teclado está — a informação mais durável da tela |
/// | `pressed` | hover, focus | feedback do clique acontecendo agora |
/// | `hover` = `focus` | rest | mesma superfície: o foco precisa de fundo opaco sob o anel |
/// | `rest` | — | repouso |
///
/// `hover` e `focus` compartilham a superfície de propósito: o que distingue um
/// do outro é o anel de foco ([context.eg.elevations.focusRing]), que só o teclado acende.
/// Já `selected` e `hover` **nunca** são a mesma cor — seleção é accent em
/// baixa opacidade, hover é neutro (ver `colors.md`).
@immutable
class EgSurfaceStyle {
  const EgSurfaceStyle({
    required this.rest,
    required this.hover,
    required this.pressed,
    required this.foreground,
    this.restGradient,
    this.selected,
    this.selectedGradient,
    this.hoverForeground,
    this.selectedForeground,
    this.border,
    this.selectedBorder,
    this.selectedEdge,
    this.disabledOpacity = AppOpacities.disabled,
  });

  /// Superfície em repouso.
  final Color rest;

  /// Gradiente da superfície em repouso, quando ela tem volume próprio.
  ///
  /// Vale **só** no repouso: assim que o mouse chega, quem responde é o [hover]
  /// chapado, porque o realce de interação precisa ser lido como uma cor a mais,
  /// não como outro material. `null` mantém o [rest] sólido — que é o caso da
  /// maioria das colunas, cuja superfície de repouso é transparente.
  final Gradient? restGradient;

  /// Mouse por cima — e também a superfície que o foco de teclado adota, para
  /// que o anel tenha o que contornar.
  final Color hover;

  /// Botão do mouse apertado. Um degrau acima do [hover].
  final Color pressed;

  /// Cor do conteúdo (texto e ícone) em repouso.
  final Color foreground;

  /// Superfície de "onde o teclado está". `null` em componentes que não têm
  /// noção de seleção (botão, botão de ícone).
  final Color? selected;

  /// O material do estado selecionado, quando o tema o pinta em degradê.
  ///
  /// É a seleção sólida do `NSTableView`: no tema Apple a linha escolhida é
  /// preenchida inteira pelo accent, e um degradê de dois passos é o que
  /// impede que esse preenchimento pareça um adesivo colado na lista.
  final Gradient? selectedGradient;

  /// Conteúdo sob o mouse, o foco ou o clique. `null` mantém [foreground] —
  /// que é o caso comum: quem acusa a interação é a superfície, não o texto.
  /// Só componentes sem superfície própria em repouso (o botão de ícone)
  /// precisam que o conteúdo também reaja.
  final Color? hoverForeground;

  /// Conteúdo do estado selecionado. `null` mantém [foreground].
  final Color? selectedForeground;

  /// Contorno de 1px, quando o componente tiver um.
  final Color? border;

  /// Contorno do estado selecionado. `null` mantém [border].
  final Color? selectedBorder;

  /// Aresta que corre pela lateral esquerda da superfície selecionada.
  ///
  /// É a assinatura de seleção do Evergreen: o fundo em accent a 14% diz "esta
  /// é a linha", e a aresta diz de onde ela começa — num painel escuro, uma
  /// superfície de baixo contraste sozinha se perde entre as vizinhas quando a
  /// lista rola. Vale para as colunas que ocupam a largura toda de um bloco
  /// ([row] e [card]); pílula de segmented control não tem, porque em 60px de
  /// largura a aresta viraria metade do componente.
  ///
  /// `null` em quem não tem noção de seleção — botão, botão de ícone.
  final Color? selectedEdge;

  /// Opacidade aplicada ao conteúdo quando o controle está indisponível.
  final double disabledOpacity;

  /// Uma cópia com um ou outro papel trocado.
  ///
  /// Para a coluna que é "a mesma daquela, menos isto" — o cartão em edição do
  /// Leaf, que é o cartão comum com a borda um degrau acima. Escrever a coluna
  /// inteira de novo só para trocar a borda é como as cópias divergiam antes
  /// desta classe existir.
  EgSurfaceStyle copyWith({Color? border, Color? selectedBorder}) =>
      EgSurfaceStyle(
        rest: rest,
        restGradient: restGradient,
        hover: hover,
        pressed: pressed,
        foreground: foreground,
        selected: selected,
        selectedGradient: selectedGradient,
        hoverForeground: hoverForeground,
        selectedForeground: selectedForeground,
        border: border ?? this.border,
        selectedBorder: selectedBorder ?? this.selectedBorder,
        selectedEdge: selectedEdge,
        disabledOpacity: disabledOpacity,
      );

  /// Fundo resolvido para um estado.
  /// Fundo resolvido para um estado.
  Color backgroundFor(
    EgInteraction state, {
    bool isSelected = false,
    bool isEnabled = true,
  }) {
    // Desabilitado fica na superfície de repouso: o que comunica a
    // indisponibilidade é a opacidade do conteúdo, não uma cor a mais na
    // paleta. Um controle que muda de superfície ao desabilitar parece outro
    // controle.
    if (!isEnabled) return rest;
    if (isSelected && selected != null) return selected!;
    if (state.isPressed) return pressed;
    if (state.isHovered || state.isFocused) return hover;
    return rest;
  }

  /// Gradiente resolvido, ou `null` quando a superfície do estado é sólida.
  ///
  /// Só o repouso tem material próprio — ver [restGradient].
  Gradient? gradientFor(
    EgInteraction state, {
    bool isSelected = false,
    bool isEnabled = true,
  }) {
    if (isSelected && selectedGradient != null && isEnabled) {
      return selectedGradient;
    }
    if (restGradient == null) return null;
    if (!isEnabled) return restGradient;
    if (isSelected && selected != null) return null;
    if (state.isPressed || state.isHovered || state.isFocused) return null;

    return restGradient;
  }

  /// Cor de texto e ícone resolvida para um estado.
  Color foregroundFor(
    EgInteraction state, {
    bool isSelected = false,
    bool isEnabled = true,
  }) {
    if (!isEnabled) return foreground;
    if (isSelected) return selectedForeground ?? foreground;
    if (state.isHovered || state.isFocused || state.isPressed) {
      return hoverForeground ?? foreground;
    }
    return foreground;
  }

  /// Contorno resolvido, ou `null` quando o componente não tem borda.
  Color? borderFor(EgInteraction state, {bool isSelected = false}) {
    if (isSelected && selectedBorder != null) return selectedBorder;
    return border;
  }

  /// Aresta de seleção resolvida, ou `null` quando não há o que desenhar.
  ///
  /// Só o estado selecionado a acende: ela responde "onde o teclado está", e um
  /// hover que a acendesse faria o mouse parecer mover a seleção sem clicar.
  Color? edgeFor(EgInteraction state, {bool isSelected = false}) =>
      isSelected ? selectedEdge : null;

  /// Anel de foco: só com o foco de teclado e só enquanto o controle responde.
  ///
  /// O anel vem de fora porque ele é do **tema**, não da coluna: no Evergreen é
  /// uma borda de 1px em accent, no Apple é um halo de 3,5px. A coluna decide
  /// *quando* mostrar; o tema decide como ele é.
  List<BoxShadow>? shadowFor(
    EgInteraction state,
    EgTokens eg, {
    bool isEnabled = true,
  }) => state.isFocused && isEnabled ? eg.elevations.focusRing : null;
}

/// A caixa de um componente interativo, já pintada pela matriz de estado.
///
/// É apresentação pura: recebe o [state] de fora em vez de detectá-lo. Serve
/// aos componentes cujo estado nasce em outro lugar — o cartão do Leaf, que
/// recebe o hover do painel; o segmented control, cujo foco vive no container e
/// não em cada pílula — e à galeria de estados dos goldens, que precisa
/// desenhar todos eles lado a lado sem um mouse de verdade.
///
/// Para o caso comum, use [EgInteractiveSurface], que junta esta caixa ao
/// [EgHoverable].
class EgSurface extends StatelessWidget {
  const EgSurface({
    super.key,
    required this.child,
    required this.state,
    this.style,
    this.isSelected = false,
    this.isEnabled = true,
    this.borderRadius,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.alignment,
  });

  final Widget child;
  final EgInteraction state;

  /// A coluna da matriz. `null` é a [EgSurfaces.row] do tema — a coluna do
  /// caso comum, e a razão de quase nenhum chamador precisar passar uma.
  final EgSurfaceStyle? style;
  final bool isSelected;
  final bool isEnabled;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final AlignmentGeometry? alignment;

  @override
  Widget build(BuildContext context) {
    final eg = context.eg;
    // O que o chamador não disse, o tema diz — inclusive a curva do movimento e
    // a espessura da borda, que mudam de uma aparência para a outra.
    final style = this.style ?? eg.surfaces.row;
    final radius = borderRadius ?? eg.shapes.rowAll;

    final borderColor = style.borderFor(state, isSelected: isSelected);
    final gradient = style.gradientFor(
      state,
      isSelected: isSelected,
      isEnabled: isEnabled,
    );

    final edgeColor = style.edgeFor(state, isSelected: isSelected);

    return AnimatedContainer(
      // Pressed entra sem transição: o feedback de "registrei seu clique"
      // precisa ser instantâneo. A volta ao repouso é que ganha o easing.
      duration: state.isPressed ? Duration.zero : eg.motion.instant,
      curve: eg.motion.curve,
      width: width,
      height: height,
      margin: margin,
      padding: padding,
      alignment: alignment,
      decoration: BoxDecoration(
        color: gradient != null
            ? null
            : style.backgroundFor(
                state,
                isSelected: isSelected,
                isEnabled: isEnabled,
              ),
        gradient: gradient,
        borderRadius: radius,
        border: borderColor == null
            ? null
            : Border.all(color: borderColor, width: eg.shapes.hairline),
        boxShadow: style.shadowFor(state, eg, isEnabled: isEnabled),
      ),
      // A aresta vai em primeiro plano, e não na `decoration`: o `Border` do
      // Flutter só aceita raio de canto quando os quatro lados são iguais, e
      // desenhá-la só à esquerda de uma caixa arredondada é justamente o caso
      // que a asserção proíbe.
      foregroundDecoration: edgeColor == null
          ? null
          : EgSelectionEdge(
              color: edgeColor,
              borderRadius: radius,
              width: eg.shapes.selectionEdge,
            ),
      child: child,
    );
  }
}

/// A caixa da [EgSurface] com a detecção de hover, clique e foco junto.
///
/// É o componente que todo elemento clicável do app deveria usar: garante que
/// hover, pressed, foco e seleção se comportem igual em qualquer canto, e que
/// um componente novo não precise reescrever a matriz para participar dela.
class EgInteractiveSurface extends StatelessWidget {
  const EgInteractiveSurface({
    super.key,
    this.child,
    this.onTap,
    this.style,
    this.isSelected = false,
    this.focusable = true,
    this.focusNode,
    this.autofocus = false,
    this.borderRadius,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.alignment,
    this.builder,
    this.semanticLabel,
    this.mergeDescendants = true,
  }) : assert(
         child != null || builder != null,
         'Informe child ou builder — a superfície precisa de conteúdo.',
       );

  /// Conteúdo fixo. Use [builder] quando o conteúdo também mudar de cor com o
  /// estado.
  final Widget? child;
  final VoidCallback? onTap;

  /// A coluna da matriz. `null` é a [EgSurfaces.row] do tema — a coluna do
  /// caso comum, e a razão de quase nenhum chamador precisar passar uma.
  final EgSurfaceStyle? style;
  final bool isSelected;

  /// Entra na navegação por Tab. Desligue em linhas navegadas pelas setas
  /// enquanto o foco fica no campo de busca (ver [EgHoverable.focusable]).
  final bool focusable;

  final FocusNode? focusNode;
  final bool autofocus;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final AlignmentGeometry? alignment;

  /// Reconstrói o conteúdo a cada mudança de estado — para quando o texto ou o
  /// ícone de dentro também mudam de cor. Sem ele, [child] é usado como está.
  ///
  /// Um dos dois é obrigatório.
  final Widget Function(BuildContext context, EgInteraction state)? builder;

  /// Como o elemento se anuncia quando o que está desenhado não basta — o caso
  /// do botão que é só um ícone. Ver [EgHoverable.semanticLabel].
  final String? semanticLabel;

  /// Funde o conteúdo numa etiqueta só. Ver [EgHoverable.mergeDescendants].
  final bool mergeDescendants;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onTap != null;

    return EgHoverable(
      onTap: onTap,
      enabled: isEnabled,
      focusable: focusable,
      focusNode: focusNode,
      autofocus: autofocus,
      semanticLabel: semanticLabel,
      mergeDescendants: mergeDescendants,
      // `true` ou nada, nunca `false`: quem está num grupo de escolha anuncia
      // que está escolhido, e quem não está fica calado. Passar `false` daria
      // a todo botão do aplicativo um "não selecionado" que ninguém pediu — o
      // padrão de lista do macOS é o leitor anunciar só o item escolhido.
      selected: isSelected ? true : null,
      builder: (context, state) => EgSurface(
        state: state,
        style: style,
        isSelected: isSelected,
        isEnabled: isEnabled,
        borderRadius: borderRadius,
        padding: padding,
        margin: margin,
        width: width,
        height: height,
        alignment: alignment,
        child: builder?.call(context, state) ?? child!,
      ),
    );
  }
}

/// A aresta accent da superfície selecionada, pintada por cima da caixa.
///
/// Uma decoração própria, e não um `Border` de um lado só, porque `BoxDecoration`
/// exige borda uniforme para aceitar raio de canto — e a aresta precisa
/// acompanhar o arredondamento da peça, senão ela vaza pelos cantos de cima e
/// de baixo.
///
/// O recorte é o mesmo `RRect` da caixa: as pontas da barra saem arredondadas
/// de graça, sem cálculo de canto.
@immutable
class EgSelectionEdge extends Decoration {
  const EgSelectionEdge({
    required this.color,
    required this.borderRadius,
    required this.width,
  });

  final Color color;
  final BorderRadius? borderRadius;
  final double width;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _EgSelectionEdgePainter(this);

  /// A aresta acende e apaga junto com a superfície — daí ela saber interpolar.
  /// Sem isso, a barra apareceria de uma vez enquanto o fundo ainda transita, e
  /// a linha selecionada piscaria a cada seta do teclado.
  @override
  EgSelectionEdge? lerpFrom(Decoration? a, double t) {
    if (a == null) return _fade(t);
    if (a is! EgSelectionEdge) return null;

    return EgSelectionEdge(
      color: Color.lerp(a.color, color, t)!,
      borderRadius: BorderRadius.lerp(a.borderRadius, borderRadius, t)!,
      width: lerpDouble(a.width, width, t)!,
    );
  }

  @override
  EgSelectionEdge? lerpTo(Decoration? b, double t) {
    if (b == null) return _fade(1 - t);
    if (b is! EgSelectionEdge) return null;

    return b.lerpFrom(this, t);
  }

  /// A mesma aresta com [t] da opacidade — o caminho de ida e volta entre "não
  /// há aresta" e a aresta cheia.
  EgSelectionEdge _fade(double t) => EgSelectionEdge(
    color: color.withValues(alpha: color.a * t.clamp(0.0, 1.0)),
    borderRadius: borderRadius,
    width: width,
  );

  @override
  bool operator ==(Object other) =>
      other is EgSelectionEdge &&
      other.color == color &&
      other.borderRadius == borderRadius &&
      other.width == width;

  @override
  int get hashCode => Object.hash(color, borderRadius, width);
}

class _EgSelectionEdgePainter extends BoxPainter {
  _EgSelectionEdgePainter(this.decoration);

  final EgSelectionEdge decoration;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null || size.isEmpty) return;

    final rect = offset & size;

    canvas.save();
    canvas.clipRRect(
      (decoration.borderRadius ?? BorderRadius.zero).toRRect(rect),
    );
    canvas.drawRect(
      Rect.fromLTWH(rect.left, rect.top, decoration.width, rect.height),
      Paint()..color = decoration.color,
    );
    canvas.restore();
  }
}

/// A matriz de estados resolvida para um tema.
///
/// As colunas são as mesmas nos dois temas — o que muda são as cores que cada
/// uma pede ao tema. Vive aqui, e não em `EgSurfaceStyle`, porque um estilo é
/// um punhado de cores e isto é a **tabela**: quem quiser uma combinação nova
/// compõe uma `EgSurfaceStyle` a partir dos tokens, e a ordem de precedência
/// continua a mesma para todo mundo.
@immutable
class EgSurfaces {
  const EgSurfaces(this._eg);

  final EgTokens _eg;

  /// O degradê de seleção do tema, quando ele pinta seleção sólida.
  Gradient? get _selectionGradient {
    final colors = _eg.colors.selectionGradient;
    if (colors == null) return null;

    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: colors,
    );
  }

  /// Linha de lista, item de sidebar, entrada de menu: sem superfície própria
  /// em repouso, seleção no tom de seleção do tema.
  EgSurfaceStyle get row => EgSurfaceStyle(
    rest: AppColors.transparent,
    hover: _eg.colors.hover,
    pressed: _eg.colors.pressed,
    selected: _eg.colors.selection,
    selectedGradient: _selectionGradient,
    foreground: _eg.colors.textPrimary,
    selectedForeground: _eg.colors.selectionLabel,
    selectedEdge: _eg.shapes.selectionEdge > 0 ? _eg.colors.accent : null,
  );

  /// Botão só de ícone e afordâncias que só aparecem sob o mouse: igual à
  /// [row], mas sem estado selecionado e com conteúdo de segundo nível.
  EgSurfaceStyle get ghost => EgSurfaceStyle(
    rest: AppColors.transparent,
    hover: _eg.colors.hover,
    pressed: _eg.colors.pressed,
    foreground: _eg.colors.textSecondary,
    hoverForeground: _eg.colors.textPrimary,
  );

  /// Pílula de um segmented control: a mesma [row], com o rótulo um nível
  /// atrás em repouso — são várias na tela ao mesmo tempo e só uma delas é a
  /// resposta.
  EgSurfaceStyle get segment => EgSurfaceStyle(
    rest: AppColors.transparent,
    hover: _eg.colors.hover,
    pressed: _eg.colors.pressed,
    selected: _eg.colors.selection,
    selectedGradient: _selectionGradient,
    foreground: _eg.colors.textSecondary,
    selectedForeground: _eg.colors.selectionLabel,
  );

  /// Cartão com superfície própria — o cartão do Leaf. Em repouso já tem fundo,
  /// então o hover precisa subir a partir dele, não do transparente.
  EgSurfaceStyle get card => EgSurfaceStyle(
    rest: _eg.colors.card,
    restGradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [_eg.colors.cardTop, _eg.colors.card],
    ),
    hover: _eg.colors.hover,
    pressed: _eg.colors.pressed,
    selected: _eg.colors.selection,
    selectedGradient: _selectionGradient,
    foreground: _eg.colors.textPrimary,
    selectedForeground: _eg.colors.selectionLabel,
    border: _eg.colors.border,
    selectedBorder: _eg.colors.accentDeep,
    selectedEdge: _eg.shapes.selectionEdge > 0 ? _eg.colors.accent : null,
  );

  /// Ação primária: o accent chapado — ou em degradê, no tema que tem um.
  EgSurfaceStyle get primary => EgSurfaceStyle(
    rest: _eg.colors.accent,
    restGradient: _eg.colors.accentGradient == null
        ? null
        : LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: _eg.colors.accentGradient!,
          ),
    hover: _eg.colors.accentLight,
    pressed: _eg.colors.accentDeep,
    foreground: _eg.colors.onAccent,
  );

  /// Ação secundária: superfície de controle com borda sutil.
  EgSurfaceStyle get secondary => EgSurfaceStyle(
    rest: _eg.colors.control,
    hover: _eg.colors.hover,
    pressed: _eg.colors.pressed,
    foreground: _eg.colors.textPrimary,
    border: _eg.colors.border,
  );

  /// Ação destrutiva: a mesma caixa da [secondary], só o texto em vermelho —
  /// vermelho chapado gritaria mais que a ação primária de qualquer tela.
  EgSurfaceStyle get destructive => EgSurfaceStyle(
    rest: _eg.colors.control,
    hover: _eg.colors.hover,
    pressed: _eg.colors.pressed,
    foreground: _eg.colors.error,
    border: _eg.colors.border,
  );
}
