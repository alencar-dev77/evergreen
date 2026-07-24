import 'package:flutter/material.dart' show Tooltip;
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
/// As três variantes compartilham geometria (padding 16x8, radius 8) e só
/// divergem nas cores, mantendo o padrão único pedido no design. Todas cobrem
/// os cinco estados obrigatórios: repouso, hover, pressed, foco e disabled.
class EgButton extends StatelessWidget {
  const EgButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = EgButtonVariant.primary,
    this.icon,
    this.expand = false,
    this.autofocus = false,
  });

  const EgButton.secondary({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.expand = false,
    this.autofocus = false,
  }) : variant = EgButtonVariant.secondary;

  const EgButton.destructive({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.expand = false,
    this.autofocus = false,
  }) : variant = EgButtonVariant.destructive;

  final String label;
  final VoidCallback? onPressed;
  final EgButtonVariant variant;
  final EgIconData? icon;

  /// Ocupa toda a largura disponível — usado no botão "Copiar" do preview.
  final bool expand;

  /// Recebe o foco ao aparecer. Só faz sentido no botão seguro de um diálogo.
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;
    final palette = _EgButtonPalette.of(variant);

    final button = EgHoverable(
      onTap: onPressed,
      enabled: isEnabled,
      focusable: true,
      autofocus: autofocus,
      builder: (context, state) {
        final isPressed = state.isPressed && isEnabled;

        return AnimatedContainer(
          // Pressed entra sem transição: o feedback de "registrei seu clique"
          // precisa ser instantâneo. A volta ao repouso é que ganha o easing.
          duration: isPressed ? Duration.zero : AppDurations.instant,
          curve: AppDurations.curve,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: palette.backgroundFor(state, isEnabled: isEnabled),
            borderRadius: AppRadii.buttonAll,
            border: palette.borderColor == null
                ? null
                : Border.all(color: palette.borderColor!),
            boxShadow: state.isFocused && isEnabled ? AppShadows.focusRing : null,
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
    required this.pressedBackground,
    required this.foreground,
    this.borderColor,
  });

  final Color background;
  final Color hoverBackground;
  final Color pressedBackground;
  final Color foreground;
  final Color? borderColor;

  /// Pressed vence hover; foco reaproveita a superfície de hover para que o
  /// anel tenha o que contornar.
  Color backgroundFor(EgInteraction state, {required bool isEnabled}) {
    if (!isEnabled) return background;
    if (state.isPressed) return pressedBackground;
    if (state.isHovered || state.isFocused) return hoverBackground;
    return background;
  }

  static _EgButtonPalette of(EgButtonVariant variant) => switch (variant) {
        EgButtonVariant.primary => const _EgButtonPalette(
            background: AppColors.greenPrimary,
            hoverBackground: AppColors.greenLight,
            pressedBackground: AppColors.greenDeep,
            foreground: AppColors.background,
          ),
        EgButtonVariant.secondary => const _EgButtonPalette(
            background: AppColors.card,
            hoverBackground: AppColors.hover,
            pressedBackground: AppColors.pressed,
            foreground: AppColors.textPrimary,
            borderColor: AppColors.border,
          ),
        EgButtonVariant.destructive => const _EgButtonPalette(
            background: AppColors.card,
            hoverBackground: AppColors.hover,
            pressedBackground: AppColors.pressed,
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

  /// Legenda de ajuda ao repousar o mouse. Um botão só de ícone sem rótulo
  /// visível depende dela para ser descoberto.
  final String? tooltip;

  final double size;
  final double iconSize;
  final Color color;
  final Color hoverColor;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;

    final button = EgHoverable(
      onTap: onPressed,
      enabled: isEnabled,
      focusable: true,
      builder: (context, state) {
        final isActive = (state.isHovered || state.isFocused) && isEnabled;

        return AnimatedContainer(
          duration: state.isPressed ? Duration.zero : AppDurations.instant,
          curve: AppDurations.curve,
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: _background(state, isEnabled: isEnabled),
            borderRadius: AppRadii.listItemAll,
            boxShadow: state.isFocused && isEnabled ? AppShadows.focusRing : null,
          ),
          child: Center(
            child: EgIcon(
              icon,
              size: iconSize,
              color: isActive ? hoverColor : color,
              strokeWidth: 1.6,
            ),
          ),
        );
      },
    );

    if (tooltip == null) return button;

    return Tooltip(
      message: tooltip!,
      waitDuration: const Duration(milliseconds: 500),
      verticalOffset: size / 2 + AppSpacing.xxs,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs,
      ),
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: AppRadii.badgeAll,
        border: AppBorders.all,
        boxShadow: AppShadows.dropdown,
      ),
      textStyle: AppTypography.captionXS,
      child: button,
    );
  }

  /// O foco precisa de superfície opaca sob o anel — um botão de ícone em
  /// repouso é transparente, então focar já revela o fundo de hover.
  Color _background(EgInteraction state, {required bool isEnabled}) {
    if (!isEnabled) return AppColors.transparent;
    if (state.isPressed) return AppColors.pressed;
    if (state.isHovered || state.isFocused) return AppColors.hover;
    return AppColors.transparent;
  }
}
