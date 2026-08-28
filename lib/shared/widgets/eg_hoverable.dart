import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Estados de interação de um componente, entregues ao builder do
/// [EgHoverable].
///
/// Existe como objeto — em vez de três parâmetros posicionais — para que os
/// componentes leiam `state.isPressed` no lugar de decorar a ordem de bools, e
/// para que novos estados possam entrar sem tocar em todos os consumidores.
@immutable
class EgInteraction {
  const EgInteraction({
    this.isHovered = false,
    this.isPressed = false,
    this.isFocused = false,
  });

  /// O ponteiro está sobre o componente.
  final bool isHovered;

  /// O botão do mouse está pressionado sobre o componente.
  final bool isPressed;

  /// O componente tem o foco do teclado (só quando [EgHoverable.focusable]).
  final bool isFocused;
}

/// Detecta hover, clique e foco e entrega o estado ao [builder].
///
/// Centraliza o `MouseRegion` + `GestureDetector` + `Focus` que todo componente
/// interativo do Evergreen precisa, evitando repetir gerenciamento de estado em
/// cada botão, list item e entrada de menu.
class EgHoverable extends StatefulWidget {
  const EgHoverable({
    super.key,
    required this.builder,
    this.onTap,
    this.cursor = SystemMouseCursors.click,
    this.enabled = true,
    this.focusable = false,
    this.focusNode,
    this.autofocus = false,
    this.semanticLabel,
    this.selected,
    this.toggled,
    this.mergeDescendants = true,
  });

  final Widget Function(BuildContext context, EgInteraction state) builder;

  final VoidCallback? onTap;
  final MouseCursor cursor;
  final bool enabled;

  /// Entra na navegação por Tab e passa a reportar [EgInteraction.isFocused],
  /// aceitando Enter/Espaço como clique.
  ///
  /// É opt-in porque nem todo componente interativo deve ser um ponto de
  /// parada do Tab: linhas de lista do overlay, por exemplo, são navegadas
  /// pelas setas enquanto o foco fica no campo de busca.
  final bool focusable;

  final FocusNode? focusNode;

  /// Recebe o foco ao aparecer — usado no botão seguro de um diálogo, para que
  /// Enter e Espaço já funcionem sem exigir um Tab antes.
  final bool autofocus;

  /// Como o elemento se anuncia ao leitor de tela, quando o que está desenhado
  /// nele não basta.
  ///
  /// Dado, **substitui** o que os filhos diriam: uma linha do Pin precisa
  /// anunciar apelido, tipo, estado de fixado e atalho numa frase só, não a
  /// sequência de pedaços de texto que a compõem. Omitido, o que os filhos
  /// dizem é fundido numa etiqueta só — que é o certo para um botão, onde o
  /// rótulo visível já é o nome.
  final String? semanticLabel;

  /// O elemento está escolhido dentro de um grupo (linha de lista, item de
  /// barra lateral, opção de um seletor).
  ///
  /// Existe porque seleção no Evergreen é fundo accent mais aresta à esquerda —
  /// e o `accessibility.md` é explícito: estado nunca pode ser comunicado só
  /// por cor. Sem isto, a lista inteira soa igual para quem não vê a tela.
  final bool? selected;

  /// O elemento é um interruptor, e este é o estado dele.
  ///
  /// Quando informado, o elemento deixa de se anunciar como botão: um
  /// interruptor tem estado, e é o estado que precisa ser lido.
  final bool? toggled;

  /// Funde o que está dentro numa etiqueta só.
  ///
  /// Ligado é o certo para a esmagadora maioria: um botão com ícone e texto
  /// precisa ser um item, não dois. **Desligue quando houver outro elemento
  /// clicável aqui dentro** — a linha do Echo tem a estrela de "guardar" dentro
  /// dela, e fundir a linha inteira engoliria a estrela junto, deixando quem
  /// navega por leitor de tela sem alcance para ela.
  final bool mergeDescendants;

  @override
  State<EgHoverable> createState() => _EgHoverableState();
}

class _EgHoverableState extends State<EgHoverable> {
  var _state = const EgInteraction();

  bool get _isInteractive => widget.enabled && widget.onTap != null;

  void _update(EgInteraction next) {
    if (next.isHovered == _state.isHovered &&
        next.isPressed == _state.isPressed &&
        next.isFocused == _state.isFocused) {
      return;
    }

    setState(() => _state = next);
  }

  void _setHovered(bool value) => _update(
    EgInteraction(
      isHovered: value,
      isPressed: value && _state.isPressed,
      isFocused: _state.isFocused,
    ),
  );

  void _setPressed(bool value) => _update(
    EgInteraction(
      isHovered: _state.isHovered,
      isPressed: value,
      isFocused: _state.isFocused,
    ),
  );

  void _setFocused(bool value) => _update(
    EgInteraction(
      isHovered: _state.isHovered,
      isPressed: _state.isPressed,
      isFocused: value,
    ),
  );

  /// Enter e Espaço acionam o componente focado, como qualquer controle nativo
  /// — um anel de foco que não pode ser ativado pelo teclado não serve para
  /// nada.
  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (!_isInteractive) return KeyEventResult.ignored;
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final isActivation =
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter ||
        event.logicalKey == LogicalKeyboardKey.space;
    if (!isActivation) return KeyEventResult.ignored;

    widget.onTap!();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    Widget child = MouseRegion(
      cursor: _isInteractive ? widget.cursor : MouseCursor.defer,
      onEnter: (_) => _setHovered(widget.enabled),
      onExit: (_) => _setHovered(false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _isInteractive ? widget.onTap : null,
        onTapDown: _isInteractive ? (_) => _setPressed(true) : null,
        onTapUp: _isInteractive ? (_) => _setPressed(false) : null,
        onTapCancel: _isInteractive ? () => _setPressed(false) : null,
        child: widget.builder(context, _state),
      ),
    );

    if (widget.focusable) {
      child = Focus(
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        canRequestFocus: _isInteractive,
        skipTraversal: !_isInteractive,
        onFocusChange: _setFocused,
        onKeyEvent: _handleKey,
        child: child,
      );
    }

    return _announced(child);
  }

  /// Põe o elemento na árvore de acessibilidade do sistema.
  ///
  /// Aqui, e não em cada componente, pela mesma razão que a matriz de estados
  /// visuais mora num lugar só: este widget é o que sabe que algo é clicável,
  /// focável e ativável por Enter. Um rótulo escrito à mão em cada botão seria
  /// a mesma coisa que uma cadeia de `if`s de hover dentro de cada widget — e
  /// o que se esquece de escrever some em silêncio, porque não aparece na tela.
  ///
  /// Com [EgHoverable.semanticLabel] a frase substitui o que os filhos diriam;
  /// sem ele, o que eles dizem é fundido numa etiqueta só, para que um botão
  /// com ícone e texto seja um item, e não dois.
  Widget _announced(Widget child) {
    final label = widget.semanticLabel;

    final node = Semantics(
      // Nó próprio: cada elemento clicável é uma parada da navegação por leitor
      // de tela, e sem isto ele seria absorvido pelo que estiver em volta.
      container: true,
      label: label,
      // Interruptor não é botão: quem tem estado se anuncia pelo estado.
      button: widget.toggled == null && _isInteractive,
      enabled: _isInteractive,
      selected: widget.selected,
      toggled: widget.toggled,
      // Um rótulo próprio substitui o que os filhos diriam — menos quando há
      // outro clicável entre eles, que precisa continuar alcançável.
      excludeSemantics: label != null && widget.mergeDescendants,
      child: child,
    );

    // A fusão fica **por fora** do nó, e não por dentro: por dentro, ela criaria
    // um segundo nó com o texto e deixaria o de cima — o que diz "isto é um
    // botão" — sem rótulo nenhum. O botão sairia mudo com o texto do lado.
    if (label != null || !widget.mergeDescendants) return node;

    return MergeSemantics(child: node);
  }
}
