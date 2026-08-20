import 'package:flutter/widgets.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_metrics.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../shared/utils/relative_time.dart';
import '../../../../shared/widgets/eg_hoverable.dart';
import '../../../../shared/widgets/eg_icon.dart';
import '../../../../shared/widgets/eg_surface.dart';
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
    this.compact = false,
  });

  final ClipboardItem item;
  final bool isSelected;

  /// Atalho de cópia rápida do item, quando ele tem um.
  final PinQuickShortcut? shortcut;

  final VoidCallback? onTap;

  /// Variante usada na coluna estreita, quando o preview está aberto.
  final bool compact;

  /// Altura da linha em qualquer um dos dois modos.
  static const height = 34.0;

  /// Coluna fixa do ícone de tipo — o glifo mais o respiro que alinha todos os
  /// títulos no mesmo x, em cada um dos dois modos.
  static const _iconColumn = 18.0;
  static const _compactIconColumn = 16.0;

  @override
  Widget build(BuildContext context) {
    // Sem duplo clique para copiar: o clique simples abre o preview, e o painel
    // muda de largura ao abrir. O segundo toque cairia numa linha que já saiu de
    // baixo do cursor — ou, pior, no botão de excluir do preview que acabou de
    // aparecer ali. Copiar pelo mouse é o botão "Copiar" do preview; pelo
    // teclado, o Enter.
    return EgHoverable(
      onTap: onTap,
      builder: (context, state) {
        // Selecionado ganha a cor de destaque em baixa opacidade e a aresta
        // accent à esquerda — distinto do hover neutro, para que a posição do
        // teclado nunca se confunda com o mouse só passando por cima. Quem
        // resolve isso é a matriz de estado compartilhada
        // (`EgSurfaceStyle.row`), a mesma da sidebar e do segmented control.
        return EgSurface(
          state: state,
          isSelected: isSelected,
          height: height,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? AppSpacing.sm : AppSpacing.md,
          ),
          child: Row(
            children: [
              // Ícone de tipo alinhado numa coluna fixa, sem o chip de fundo: o
              // glifo já distingue texto/link/comando de relance, e um container
              // cinza por linha só somaria ruído. Recua no repouso e acompanha o
              // texto quando a linha está selecionada.
              SizedBox(
                width: compact ? _compactIconColumn : _iconColumn,
                child: EgIcon(
                  item.type.icon,
                  size: compact ? AppIconSizes.xs : AppIconSizes.md,
                  color: isSelected
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
              SizedBox(width: compact ? AppSpacing.sm : AppSpacing.md),
              Expanded(child: _label()),
              if (!compact) ...[
                const SizedBox(width: AppSpacing.sm),
                _trailing(),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Texto da linha: o apelido à frente e, atrás dele, o começo do conteúdo em
  /// segundo plano.
  ///
  /// Os dois num parágrafo só, e não em dois `Text` lado a lado: assim o corte
  /// por ellipsis come primeiro o conteúdo, que é o que sobra de contexto, e
  /// nunca o apelido — que é o nome pelo qual a pessoa procura a linha. O
  /// contraste de peso e tamanho já separa um do outro, sem precisar de
  /// divisor. Na coluna estreita ao lado do preview só cabe o apelido.
  Widget _label() {
    if (!item.hasAlias || compact) {
      return Text(
        item.displayTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        softWrap: false,
        style: AppTypography.bodyCompactEmphasis,
      );
    }

    return Text.rich(
      TextSpan(
        text: item.displayTitle,
        children: [
          TextSpan(
            text: '   ${item.title}',
            style: AppTypography.captionXS.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
      style: AppTypography.bodyCompactEmphasis,
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
