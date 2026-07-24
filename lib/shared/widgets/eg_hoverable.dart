import 'package:flutter/widgets.dart';

/// Detecta hover e clique e entrega o estado ao [builder].
///
/// Centraliza o par `MouseRegion` + `GestureDetector` que quase todo componente
/// interativo do Evergreen precisa, evitando repetir gerenciamento de estado em
/// cada botão, list item e entrada de menu.
class EgHoverable extends StatefulWidget {
  const EgHoverable({
    super.key,
    required this.builder,
    this.onTap,
    this.cursor = SystemMouseCursors.click,
    this.enabled = true,
  });

  /// Recebe `true` enquanto o ponteiro estiver sobre o componente.
  final Widget Function(BuildContext context, bool isHovered) builder;

  final VoidCallback? onTap;
  final MouseCursor cursor;
  final bool enabled;

  @override
  State<EgHoverable> createState() => _EgHoverableState();
}

class _EgHoverableState extends State<EgHoverable> {
  bool _isHovered = false;

  void _setHovered(bool value) {
    if (_isHovered == value) return;
    setState(() => _isHovered = value);
  }

  @override
  Widget build(BuildContext context) {
    final isInteractive = widget.enabled && widget.onTap != null;

    return MouseRegion(
      cursor: isInteractive ? widget.cursor : MouseCursor.defer,
      onEnter: (_) => _setHovered(widget.enabled),
      onExit: (_) => _setHovered(false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: isInteractive ? widget.onTap : null,
        child: widget.builder(context, _isHovered),
      ),
    );
  }
}
