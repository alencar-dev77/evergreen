import 'package:flutter/widgets.dart';

import '../../core/design/app_colors.dart';
import '../../core/design/app_metrics.dart';
import '../../core/design/app_typography.dart';
import 'eg_hoverable.dart';
import 'eg_icon.dart';

/// Variantes de botão previstas no design system.
enum EgButtonVariant {
  /// Ação primária: fundo verde, texto escuro.
  primary,

  /// Ação secundária: fundo card com borda sutil.
  secondary,

  /// Ação destrutiva: texto e borda em vermelho.
  destructive,
}

/// Botão padrão do Evergreen.
///
/// As três variantes compartilham geometria (padding 10x18, radius 10) e só
/// divergem nas cores, mantendo o padrão único pedido no design.
class EgButton extends StatelessWidget {
  const EgButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = EgButtonVariant.primary,
    this.icon,
    this.expand = false,
  });

  const EgButton.secondary({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.expand = false,
  }) : variant = EgButtonVariant.secondary;

  const EgButton.destructive({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.expand = false,
  }) : variant = EgButtonVariant.destructive;

  final String label;
  final VoidCallback? onPressed;
  final EgButtonVariant variant;
  final EgIconData? icon;

  /// Ocupa toda a largura disponível — usado no botão "Colar novamente".
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;
    final palette = _EgButtonPalette.of(variant);

    final button = EgHoverable(
      onTap: onPressed,
      enabled: isEnabled,
      builder: (context, isHovered) {
        final active = isHovered && isEnabled;

        return AnimatedContainer(
          duration: AppDurations.fast,
          curve: AppDurations.curve,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: active ? palette.hoverBackground : palette.background,
            borderRadius: AppRadii.buttonAll,
            border: palette.borderColor == null
                ? null
                : Border.all(color: palette.borderColor!),
          ),
          child: Opacity(
            opacity: isEnabled ? 1 : 0.4,
            child: Row(
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  EgIcon(icon!, size: 14, color: palette.foreground),
                  const SizedBox(width: AppSpacing.sm),
                ],
                // Sob largura apertada o rótulo trunca em vez de estourar o
                // layout do painel que contém o botão.
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style:
                        AppTypography.button.copyWith(color: palette.foreground),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Cores de cada variante, extraídas para manter o `build` legível.
class _EgButtonPalette {
  const _EgButtonPalette({
    required this.background,
    required this.hoverBackground,
    required this.foreground,
    this.borderColor,
  });

  final Color background;
  final Color hoverBackground;
  final Color foreground;
  final Color? borderColor;

  static _EgButtonPalette of(EgButtonVariant variant) => switch (variant) {
        EgButtonVariant.primary => const _EgButtonPalette(
            background: AppColors.greenPrimary,
            hoverBackground: AppColors.greenLight,
            foreground: AppColors.background,
          ),
        EgButtonVariant.secondary => const _EgButtonPalette(
            background: AppColors.card,
            hoverBackground: AppColors.hover,
            foreground: AppColors.textPrimary,
            borderColor: AppColors.border,
          ),
        EgButtonVariant.destructive => const _EgButtonPalette(
            background: AppColors.card,
            hoverBackground: AppColors.hover,
            foreground: AppColors.error,
            borderColor: AppColors.border,
          ),
      };
}

/// Botão apenas de ícone: 36x36, transparente, com hover discreto.
class EgIconButton extends StatelessWidget {
  const EgIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.size = 36,
    this.iconSize = 16,
    this.color = AppColors.textSecondary,
    this.hoverColor = AppColors.textPrimary,
  });

  final EgIconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final double iconSize;
  final Color color;
  final Color hoverColor;

  @override
  Widget build(BuildContext context) {
    return EgHoverable(
      onTap: onPressed,
      enabled: onPressed != null,
      builder: (context, isHovered) => AnimatedContainer(
        duration: AppDurations.fast,
        curve: AppDurations.curve,
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isHovered ? AppColors.hover : const Color(0x00000000),
          borderRadius: AppRadii.listItemAll,
        ),
        child: Center(
          child: EgIcon(
            icon,
            size: iconSize,
            color: isHovered ? hoverColor : color,
            strokeWidth: 1.6,
          ),
        ),
      ),
    );
  }
}
