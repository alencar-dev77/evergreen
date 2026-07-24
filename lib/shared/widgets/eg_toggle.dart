import 'package:flutter/widgets.dart';

import '../../core/design/app_colors.dart';
import '../../core/design/app_metrics.dart';
import 'eg_hoverable.dart';

/// Switch pill do design system — trilho 36x21, bolinha 15px.
///
/// Ligado: trilho verde com bolinha escura à direita.
/// Desligado: trilho `border` com bolinha `textSecondary` à esquerda.
class EgToggle extends StatelessWidget {
  const EgToggle({
    super.key,
    required this.value,
    this.onChanged,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  static const _trackWidth = 36.0;
  static const _trackHeight = 21.0;
  static const _thumbSize = 15.0;
  static const _thumbInset = 3.0;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onChanged != null;

    return EgHoverable(
      enabled: isEnabled,
      onTap: isEnabled ? () => onChanged!(!value) : null,
      builder: (context, isHovered) => Opacity(
        opacity: isEnabled ? 1 : 0.5,
        child: AnimatedContainer(
          duration: AppDurations.fast,
          curve: AppDurations.curve,
          width: _trackWidth,
          height: _trackHeight,
          decoration: BoxDecoration(
            color: _trackColor(isHovered && isEnabled),
            borderRadius: BorderRadius.circular(_trackHeight / 2),
          ),
          child: AnimatedAlign(
            duration: AppDurations.fast,
            curve: AppDurations.curve,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: _thumbInset),
              child: Container(
                width: _thumbSize,
                height: _thumbSize,
                decoration: BoxDecoration(
                  color: value ? AppColors.background : AppColors.textSecondary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _trackColor(bool isHovered) {
    if (value) return isHovered ? AppColors.greenLight : AppColors.greenPrimary;
    return isHovered ? AppColors.hover : AppColors.border;
  }
}
