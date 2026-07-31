import 'package:flutter/material.dart';

import '../../core/design/app_colors.dart';
import '../../core/design/app_metrics.dart';
import '../../core/design/app_typography.dart';

/// Campo de texto de uma linha do design system.
///
/// Diferente do [EgSearchField](eg_search_field.dart), que existe para filtrar
/// uma lista enquanto se digita, este é para um texto que a pessoa escreve e
/// confirma — a atividade e o resumo de uma sessão do Focus.
///
/// Em repouso a borda é a sutil de 1px; com o foco ela vira accent. Não há anel
/// de foco por sombra aqui: num campo de texto a própria borda já é o
/// indicador, e um anel por fora dela seria redundância de affordance.
class EgTextField extends StatefulWidget {
  const EgTextField({
    super.key,
    required this.controller,
    this.focusNode,
    this.hintText,
    this.autofocus = false,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;

  /// Placeholder. Específico do contexto, nunca genérico (`components.md`).
  final String? hintText;

  final bool autofocus;
  final ValueChanged<String>? onChanged;

  /// Confirmação pelo Enter. Vem do canal de texto do sistema, e não de um
  /// atalho: um `Shortcuts` acima do campo pode nunca ver essa tecla.
  final ValueChanged<String>? onSubmitted;

  final bool enabled;

  @override
  State<EgTextField> createState() => _EgTextFieldState();
}

class _EgTextFieldState extends State<EgTextField> {
  FocusNode? _internalNode;
  bool _isFocused = false;

  FocusNode get _node => widget.focusNode ?? (_internalNode ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _node.addListener(_syncFocus);
  }

  @override
  void didUpdateWidget(EgTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode == widget.focusNode) return;

    oldWidget.focusNode?.removeListener(_syncFocus);
    _internalNode?.removeListener(_syncFocus);
    _node.addListener(_syncFocus);
    // Re-lê o estado do nó novo na hora: quando o Flutter reaproveita este
    // widget para outro campo (atividade → anotação), o `_isFocused` herdado
    // descreveria o nó antigo — e o campo novo nasceria com borda de focado.
    _syncFocus();
  }

  @override
  void dispose() {
    widget.focusNode?.removeListener(_syncFocus);
    _internalNode?.dispose();
    super.dispose();
  }

  void _syncFocus() {
    if (_node.hasFocus == _isFocused) return;
    setState(() => _isFocused = _node.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppDurations.instant,
      curve: AppDurations.curve,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: AppRadii.buttonAll,
        border: Border.all(
          color: _isFocused ? AppColors.greenPrimary : AppColors.border,
        ),
      ),
      child: Opacity(
        opacity: widget.enabled ? 1 : 0.4,
        child: TextField(
          controller: widget.controller,
          focusNode: _node,
          autofocus: widget.autofocus,
          enabled: widget.enabled,
          onChanged: widget.onChanged,
          onSubmitted: widget.onSubmitted,
          cursorColor: AppColors.greenPrimary,
          cursorWidth: 1.5,
          cursorHeight: 16,
          style: AppTypography.body,
          decoration: InputDecoration(
            isDense: true,
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            hintText: widget.hintText,
            hintStyle:
                AppTypography.body.copyWith(color: AppColors.textTertiary),
          ),
        ),
      ),
    );
  }
}
