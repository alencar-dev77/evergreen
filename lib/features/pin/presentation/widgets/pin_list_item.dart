import 'package:flutter/widgets.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_metrics.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../shared/utils/relative_time.dart';
import '../../../../shared/widgets/eg_hoverable.dart';
import '../../../../shared/widgets/eg_icon.dart';
import '../../models/clipboard_item.dart';
import '../../models/pin_quick_shortcut.dart';

/// Uma linha da lista do overlay: ícone de tipo, título e um metadado à direita.
///
/// Densidade compacta (34px de altura), como no Maccy — o objetivo é caber o
/// máximo de itens sem que a lista pareça apertada. A altura é fixa e pública
/// porque a lista rola por cálculo de offset, não por medição de widget.
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

  /// Altura da linha em qualquer um dos dois modos.
  static const height = 34.0;

  @override
  Widget build(BuildContext context) {
    return EgHoverable(
      onTap: onTap,
      builder: (context, state) {
        return GestureDetector(
          onDoubleTap: onDoubleTap,
          child: AnimatedContainer(
            duration: AppDurations.instant,
            curve: AppDurations.curve,
            height: height,
            padding: EdgeInsets.symmetric(
              horizontal: compact ? AppSpacing.sm : AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: _backgroundColor(state),
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
                    style: AppTypography.bodyCompactEmphasis,
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(width: AppSpacing.sm),
                  _trailing(),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// À direita da linha vai o metadado mais útil daquele item: o atalho, quando
  /// ele existe (ensina algo que o texto não diz), e o horário quando não —
  /// nunca os dois, para a linha não virar uma tabela.
  Widget _trailing() {
    final shortcut = this.shortcut;
    if (shortcut != null) {
      return _ShortcutBadge(label: shortcut.label, isActive: isSelected);
    }

    return Text(
      RelativeTime.format(item.copiedAt),
      maxLines: 1,
      softWrap: false,
      style: AppTypography.captionXS.copyWith(color: AppColors.textTertiary),
    );
  }

  /// Selecionado ganha a cor de destaque em baixa opacidade — distinto do
  /// hover neutro, para que a posição do teclado nunca se confunda com o
  /// mouse só passando por cima.
  Color _backgroundColor(EgInteraction state) {
    if (isSelected) return AppColors.selection;
    if (state.isPressed) return AppColors.pressed;
    if (state.isHovered) return AppColors.hover;
    return AppColors.transparent;
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
      style: AppTypography.monoSmall.copyWith(
        // Recuado, mas ainda legível: em `border` o badge some no fundo do
        // painel e deixa de ensinar o atalho, que é a razão de ele existir.
        color: isActive ? AppColors.textSecondary : AppColors.textTertiary,
      ),
      child: Text(label),
    );
  }
}
