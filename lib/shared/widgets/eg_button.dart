import 'package:flutter/material.dart' show Tooltip;
import 'package:flutter/widgets.dart';

import '../../core/design/app_colors.dart';
import '../../core/design/app_metrics.dart';
import '../../core/design/app_typography.dart';
import 'eg_icon.dart';
import 'eg_spinner.dart';
import 'eg_surface.dart';

/// Variantes de botão previstas no design system.
enum EgButtonVariant {
  /// Ação primária: fundo verde, texto escuro.
  primary,

  /// Ação secundária: fundo card com borda sutil.
  secondary,

  /// Ação destrutiva: texto e borda em vermelho.
  destructive;

  /// A coluna desta variante na matriz de estado compartilhada.
  EgSurfaceStyle get style => switch (this) {
        EgButtonVariant.primary => EgSurfaceStyle.primary,
        EgButtonVariant.secondary => EgSurfaceStyle.secondary,
        EgButtonVariant.destructive => EgSurfaceStyle.destructive,
      };
}

/// Botão padrão do Evergreen.
///
/// As três variantes compartilham geometria (padding 16x8, radius 8) e só
/// divergem na coluna da matriz de estado ([EgSurfaceStyle]), mantendo o padrão
/// único pedido no design. Todas cobrem os cinco estados obrigatórios: repouso,
/// hover, pressed, foco e disabled — mais [isLoading], que é o sexto e não se
/// confunde com nenhum deles: o botão está trabalhando, não indisponível.
class EgButton extends StatelessWidget {
  const EgButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = EgButtonVariant.primary,
    this.icon,
    this.expand = false,
    this.autofocus = false,
    this.isLoading = false,
  });

  const EgButton.secondary({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.expand = false,
    this.autofocus = false,
    this.isLoading = false,
  }) : variant = EgButtonVariant.secondary;

  const EgButton.destructive({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.expand = false,
    this.autofocus = false,
    this.isLoading = false,
  }) : variant = EgButtonVariant.destructive;

  final String label;
  final VoidCallback? onPressed;
  final EgButtonVariant variant;
  final EgIconData? icon;

  /// Ocupa toda a largura disponível — usado no botão "Copiar" do preview.
  final bool expand;

  /// Recebe o foco ao aparecer. Só faz sentido no botão seguro de um diálogo.
  final bool autofocus;

  /// O botão está executando a própria ação.
  ///
  /// O rótulo dá lugar a um spinner **sem o botão mudar de tamanho** — o
  /// rótulo continua ocupando o lugar dele, invisível, porque um botão que
  /// encolhe ao ser apertado empurra o que está ao lado e faz a tela pular
  /// justamente no instante em que a pessoa olha para ela.
  ///
  /// Enquanto carrega, o toque não passa: a ação já está em curso, e um
  /// segundo disparo faria o mesmo trabalho duas vezes. Isso é diferente de
  /// desabilitar — o botão **não** esmaece, porque ele não está indisponível.
  ///
  /// Quem chama continua responsável por não sumir com o botão: trocar
  /// `if (podeAgir)` por este sinalizador é o que faz a espera ter onde
  /// aparecer. Ver `EchoMeetingDetail`, que era exatamente esse caso.
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    // Só o desabilitado de verdade esmaece; carregando, o botão segue inteiro.
    final isDisabled = onPressed == null;
    final style = variant.style;

    final button = EgInteractiveSurface(
      onTap: isLoading ? null : onPressed,
      style: style,
      borderRadius: AppRadii.buttonAll,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.sm,
      ),
      builder: (context, state) => Opacity(
        opacity: isDisabled ? style.disabledOpacity : 1,
        child: _content(style),
      ),
      autofocus: autofocus,
    );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }

  /// O miolo do botão. Carregando, o rótulo vira o molde que segura a largura
  /// e o spinner ocupa o centro dele.
  Widget _content(EgSurfaceStyle style) {
    final label = _label(style);

    if (!isLoading) return label;

    return Stack(
      alignment: Alignment.center,
      children: [
        Opacity(opacity: 0, child: label),
        EgSpinner(size: AppIconSizes.sm, color: style.foreground),
      ],
    );
  }

  Widget _label(EgSurfaceStyle style) => Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            EgIcon(icon!, size: AppIconSizes.sm, color: style.foreground),
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
              style: AppTypography.button.copyWith(color: style.foreground),
            ),
          ),
        ],
      );
}

/// Botão apenas de ícone: 36x36, transparente, com hover discreto.
class EgIconButton extends StatelessWidget {
  const EgIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.size = AppBadgeSizes.md,
    this.iconSize = AppIconSizes.lg,
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

    // O foco precisa de superfície opaca sob o anel — um botão de ícone em
    // repouso é transparente, então focar já revela o fundo de hover, que é
    // exatamente o que a coluna `ghost` da matriz faz.
    final button = EgInteractiveSurface(
      onTap: onPressed,
      style: EgSurfaceStyle.ghost,
      borderRadius: AppRadii.listItemAll,
      width: size,
      height: size,
      alignment: Alignment.center,
      builder: (context, state) => EgIcon(
        icon,
        size: iconSize,
        color: (state.isHovered || state.isFocused) && isEnabled
            ? hoverColor
            : color,
        strokeWidth: 1.6,
      ),
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
}
