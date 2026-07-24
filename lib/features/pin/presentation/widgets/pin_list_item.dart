import 'package:flutter/widgets.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_metrics.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../shared/widgets/eg_hoverable.dart';
import '../../../../shared/widgets/eg_icon.dart';
import '../../models/clipboard_item.dart';
import '../../models/pin_quick_shortcut.dart';

/// Uma linha da lista do overlay: badge de tipo, título e estrela de fixado.
///
/// Densidade compacta (padding vertical de 8px), como no Maccy — o objetivo é
/// caber o máximo de itens sem que a lista pareça apertada.
class PinListItem extends StatelessWidget {
  const PinListItem({
    super.key,
    required this.item,
    required this.isSelected,
    this.shortcut,
    this.onTap,
    this.onDoubleTap,
    this.compact = false,
  });

  final ClipboardItem item;
  final bool isSelected;

  /// Atalho de cópia rápida do item, quando ele tem um.
  final PinQuickShortcut? shortcut;

  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;

  /// Variante usada na coluna estreita, quando o preview está aberto.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return EgHoverable(
      onTap: onTap,
      builder: (context, isHovered) {
        return GestureDetector(
          onDoubleTap: onDoubleTap,
          child: AnimatedContainer(
            duration: AppDurations.fast,
            curve: AppDurations.curve,
            padding: EdgeInsets.symmetric(
              horizontal: compact ? AppSpacing.sm : AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: _backgroundColor(isHovered),
              borderRadius: AppRadii.listItemAll,
            ),
            child: Row(
              children: [
                // Ícone de tipo alinhado numa coluna fixa, sem o chip de fundo:
                // o glifo já distingue texto/link/comando de relance, e um
                // container cinza por linha só somaria ruído. Recua no repouso e
                // acompanha o texto quando a linha está selecionada.
                SizedBox(
                  width: compact ? 16 : 18,
                  child: EgIcon(
                    item.type.icon,
                    size: compact ? 13 : 15,
                    color: isSelected
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
                SizedBox(width: compact ? AppSpacing.sm : AppSpacing.md),
                Expanded(
                  child: Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: compact
                        ? AppTypography.bodyCompact.copyWith(fontSize: 12.5)
                        : AppTypography.bodyCompact,
                  ),
                ),
                // O atalho de cópia rápida é o único adorno da linha — ele ensina
                // algo que o texto não diz. A estrela de fixado saiu: sob a seção
                // "Fixados" ela repetia uma informação que o agrupamento já dá.
                if (shortcut != null && !compact) ...[
                  const SizedBox(width: AppSpacing.sm),
                  _ShortcutBadge(label: shortcut!.label, isActive: isSelected),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// Selecionado ganha a cor de destaque em baixa opacidade — distinto do
  /// hover neutro, para que a posição do teclado nunca se confunda com o
  /// mouse só passando por cima.
  Color _backgroundColor(bool isHovered) {
    if (isSelected) return AppColors.greenPrimary.withValues(alpha: 0.14);
    if (isHovered) return AppColors.hover;
    return const Color(0x00000000);
  }
}

/// Badge discreto com o atalho do item (`⌘1`, `⌥2`).
///
/// Fica sem contorno de propósito: ele aparece em várias linhas ao mesmo tempo
/// e um chip completo por linha competiria com o conteúdo. Ganha destaque
/// apenas na linha selecionada.
class _ShortcutBadge extends StatelessWidget {
  const _ShortcutBadge({required this.label, required this.isActive});

  final String label;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return AnimatedDefaultTextStyle(
      duration: AppDurations.fast,
      curve: AppDurations.curve,
      style: AppTypography.mono.copyWith(
        fontSize: 11,
        // Recuado, mas ainda legível: em `border` o badge some no fundo do
        // painel e deixa de ensinar o atalho, que é a razão de ele existir.
        color: isActive
            ? AppColors.textSecondary
            : AppColors.textSecondary.withValues(alpha: 0.45),
      ),
      child: Text(label),
    );
  }
}
