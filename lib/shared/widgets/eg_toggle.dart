import 'package:flutter/widgets.dart';

import '../../core/design/app_colors.dart';
import '../../core/design/app_metrics.dart';
import 'eg_hoverable.dart';

/// Switch pill do design system — trilho 36x21, bolinha 15px.
///
/// Ligado: trilho verde com bolinha escura à direita.
/// Desligado: trilho `border` com bolinha `textSecondary` à esquerda.
///
/// É a única exceção deliberada à regra de "accent em baixa opacidade, nunca
/// preenchimento sólido": switch de macOS é verde chapado, e o usuário lê o
/// estado ligado/desligado por essa convenção antes de ler qualquer outra
/// pista. Registrada em `colors.md`.
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
      focusable: true,
      onTap: isEnabled ? () => onChanged!(!value) : null,
      builder: (context, state) => Opacity(
        opacity: isEnabled ? 1 : 0.5,
        child: AnimatedContainer(
          duration: AppDurations.instant,
          curve: AppDurations.curve,
          width: _trackWidth,
          height: _trackHeight,
          decoration: BoxDecoration(
            color: _trackColor(
              isActive: (state.isHovered || state.isFocused) && isEnabled,
            ),
            borderRadius: BorderRadius.circular(_trackHeight / 2),
            boxShadow:
                state.isFocused && isEnabled ? AppShadows.focusRing : null,
          ),
          child: AnimatedAlign(
            duration: AppDurations.instant,
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

  Color _trackColor({required bool isActive}) {
    if (value) return isActive ? AppColors.greenLight : AppColors.greenPrimary;
    return isActive ? AppColors.hover : AppColors.border;
  }
}
