import 'package:flutter/material.dart';

import '../../core/design/app_metrics.dart';
import 'eg_icon.dart';
import 'eg_key_cap.dart';
import '../../core/design/eg_tokens.dart';

/// Campo de busca do design system: lupa + input, borda verde quando focado.
///
/// Em [bare] o campo perde fundo e borda próprios, virando apenas a linha de
/// busca do topo do overlay (onde a separação é feita pela borda do painel).
///
/// Fora dele o campo mora numa tela do Hub, ao lado de outros controles, e
/// segue a regra do `components.md`: borda neutra em repouso, verde só com o
/// foco. Era verde o tempo todo — o que dizia "estou com o teclado" sem estar.
class EgSearchField extends StatefulWidget {
  const EgSearchField({
    super.key,
    required this.controller,
    this.focusNode,
    this.onChanged,
    this.hintText = 'Pesquisar...',
    this.bare = false,
    this.autofocus = false,
    this.holdsFocus = false,
    this.shortcut,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final String hintText;
  final bool bare;
  final bool autofocus;

  /// Um clique em outro lugar do painel não tira o cursor daqui.
  ///
  /// Ligado onde o campo é o dono do teclado da tela inteira — o overlay do
  /// Pin. Ali as setas, o Enter, o `⌘P` e o Esc são atalhos do painel, mas só
  /// chegam até ele porque o campo de busca segura o foco: perdido o foco, o
  /// mapa inteiro emudece. O `TextField` no macOS desiste do foco a cada
  /// clique fora dele, e foi isso que deixou o painel sem teclado depois de um
  /// clique na lista.
  final bool holdsFocus;

  /// O atalho que traz o teclado até aqui (`['⌘', 'F']`), desenhado à direita.
  ///
  /// Só com o campo vazio e sem foco: é a única hora em que ele ensina alguma
  /// coisa. Com o cursor dentro, o atalho já foi usado; com texto, o espaço é
  /// do que se digitou.
  final List<String>? shortcut;

  @override
  State<EgSearchField> createState() => _EgSearchFieldState();
}

class _EgSearchFieldState extends State<EgSearchField> {
  FocusNode? _ownFocusNode;

  FocusNode get _focusNode =>
      widget.focusNode ?? (_ownFocusNode ??= FocusNode());

  /// O texto só importa para o desenho quando há atalho para esconder: sem
  /// ele, redesenhar o campo a cada tecla — o Pin, que não tem — seria
  /// trabalho à toa.
  bool get _watchesText => widget.shortcut != null;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_rebuild);
    if (_watchesText) widget.controller.addListener(_rebuild);
  }

  @override
  void didUpdateWidget(EgSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownFocusNode)?.removeListener(_rebuild);
      if (widget.focusNode != null) {
        _ownFocusNode?.dispose();
        _ownFocusNode = null;
      }
      _focusNode.addListener(_rebuild);
    }

    oldWidget.controller.removeListener(_rebuild);
    if (_watchesText) widget.controller.addListener(_rebuild);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_rebuild);
    widget.controller.removeListener(_rebuild);
    _ownFocusNode?.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final shortcut = widget.shortcut;
    final showsShortcut =
        shortcut != null &&
        !_focusNode.hasFocus &&
        widget.controller.text.isEmpty;

    final field = Row(
      children: [
        const EgIcon(
          EgIconData.search,
          size: AppIconSizes.md,
          strokeWidth: 1.5,
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            autofocus: widget.autofocus,
            onChanged: widget.onChanged,
            // Sem `onTapOutside` o campo se desfoca sozinho ao primeiro clique
            // em qualquer outro lugar — ver [holdsFocus].
            onTapOutside: widget.holdsFocus ? (_) {} : null,
            cursorColor: context.eg.colors.accent,
            cursorWidth: 1.5,
            cursorHeight: 16,
            style: context.eg.text.body,
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              hintText: widget.hintText,
              // Placeholder é texto de terceiro nível: precisa ser legível sem
              // competir com o que a pessoa digita.
              hintStyle: context.eg.text.body.copyWith(
                color: context.eg.colors.textTertiary,
              ),
            ),
          ),
        ),
        if (showsShortcut) ...[
          const SizedBox(width: AppSpacing.sm),
          ExcludeSemantics(child: EgShortcutDisplay(keys: shortcut)),
        ],
      ],
    );

    if (widget.bare) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.lg,
        ),
        child: field,
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        // O poço, como o `EgTextField`: escrito é conteúdo que entra na
        // superfície do cartão, não uma peça apoiada sobre ela — e um degrau
        // abaixo dela é o que separa o campo do cartão sem uma moldura.
        color: context.eg.colors.canvasDeep,
        borderRadius: context.eg.shapes.controlAll,
        border: Border.all(
          color: _focusNode.hasFocus
              ? context.eg.colors.accent
              : context.eg.colors.edge,
        ),
      ),
      child: field,
    );
  }
}
