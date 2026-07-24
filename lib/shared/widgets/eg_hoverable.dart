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

    final isActivation = event.logicalKey == LogicalKeyboardKey.enter ||
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

    return child;
  }
}
