import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../core/design/app_colors.dart';
import '../../core/design/app_metrics.dart';
import '../../core/design/app_typography.dart';
import 'eg_hoverable.dart';

/// Seletor de opção única em formato de pílulas.
///
/// Usado onde um toggle não basta mas um dropdown seria pesado demais — por
/// exemplo, o tamanho do histórico do Pin.
///
/// O foco vive no controle inteiro, não em cada segmento: quando ele está
/// focado, ← e → trocam a opção. É como um segmented control nativo se comporta
/// e evita que o Tab pare em cada pílula.
class EgSegmentedControl<T> extends StatefulWidget {
  const EgSegmentedControl({
    super.key,
    required this.value,
    required this.options,
    required this.labelOf,
    required this.onChanged,
  });

  final T value;
  final List<T> options;
  final String Function(T option) labelOf;
  final ValueChanged<T> onChanged;

  @override
  State<EgSegmentedControl<T>> createState() => _EgSegmentedControlState<T>();
}

class _EgSegmentedControlState<T> extends State<EgSegmentedControl<T>> {
  bool _isFocused = false;

  void _setFocused(bool value) {
    if (_isFocused == value) return;
    setState(() => _isFocused = value);
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final delta = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowLeft => -1,
      LogicalKeyboardKey.arrowRight => 1,
      _ => 0,
    };
    if (delta == 0) return KeyEventResult.ignored;

    final current = widget.options.indexOf(widget.value);
    if (current < 0) return KeyEventResult.ignored;

    final next = (current + delta).clamp(0, widget.options.length - 1);
    if (next != current) widget.onChanged(widget.options[next]);

    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: _setFocused,
      onKeyEvent: _handleKey,
      child: AnimatedContainer(
        duration: AppDurations.instant,
        curve: AppDurations.curve,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: AppRadii.badgeAll,
          border: AppBorders.all,
          boxShadow: _isFocused ? AppShadows.focusRing : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in widget.options)
              _Segment(
                label: widget.labelOf(option),
                isSelected: option == widget.value,
                onTap: () => widget.onChanged(option),
              ),
          ],
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return EgHoverable(
      onTap: onTap,
      builder: (context, state) => AnimatedContainer(
        duration: state.isPressed ? Duration.zero : AppDurations.instant,
        curve: AppDurations.curve,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xxs,
        ),
        decoration: BoxDecoration(
          color: _background(state),
          // Concêntrico com o container: 6px do pai menos os 2px de padding.
          borderRadius: AppRadii.badgeSmallAll,
        ),
        child: Text(
          label,
          style: AppTypography.captionSmall.copyWith(
            color: isSelected ? AppColors.greenLight : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  /// A opção escolhida usa accent em baixa opacidade — o mesmo tratamento de
  /// seleção da lista e da sidebar. Preenchimento verde sólido puxaria o olho
  /// para uma preferência que não é a ação principal de tela nenhuma.
  Color _background(EgInteraction state) {
    if (isSelected) return AppColors.selection;
    if (state.isPressed) return AppColors.pressed;
    return state.isHovered ? AppColors.hover : AppColors.transparent;
  }
}
