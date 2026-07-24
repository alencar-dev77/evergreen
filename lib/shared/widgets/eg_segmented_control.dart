import 'package:flutter/widgets.dart';

import '../../core/design/app_colors.dart';
import '../../core/design/app_metrics.dart';
import '../../core/design/app_typography.dart';
import 'eg_hoverable.dart';

/// Seletor de opção única em formato de pílulas.
///
/// Usado onde um toggle não basta mas um dropdown seria pesado demais — por
/// exemplo, o tamanho do histórico do Pin.
class EgSegmentedControl<T> extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: AppRadii.badgeAll,
        border: AppBorders.all,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final option in options)
            _Segment(
              label: labelOf(option),
              isSelected: option == value,
              onTap: () => onChanged(option),
            ),
        ],
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
      builder: (context, isHovered) => AnimatedContainer(
        duration: AppDurations.fast,
        curve: AppDurations.curve,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xxs,
        ),
        decoration: BoxDecoration(
          color: _background(isHovered),
          borderRadius: const BorderRadius.all(Radius.circular(5)),
        ),
        child: Text(
          label,
          style: AppTypography.captionSmall.copyWith(
            color: isSelected ? AppColors.background : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Color _background(bool isHovered) {
    if (isSelected) return AppColors.greenPrimary;
    return isHovered ? AppColors.hover : const Color(0x00000000);
  }
}
