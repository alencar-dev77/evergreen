import 'package:flutter/widgets.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_metrics.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../shared/widgets/eg_icon.dart';
import '../../../pin/models/clipboard_item_type.dart';

/// A distribuição do que passou pela área de transferência no dia.
///
/// **Tipo e contagem, nunca conteúdo.** É a regra do módulo, e não uma escolha
/// desta tela: o Pin registra tudo que se copia, senha colada inclusive, e uma
/// tela que mostrasse "o que você copiou hoje" seria uma tela de senhas em
/// texto puro. Quem quiser ver o item vai ao Pin, que é onde já se espera isso.
///
/// A barrinha existe porque aqui a **proporção** é o conteúdo — "foi um dia de
/// links" é a leitura, e ela não sai de uma coluna de números. Neutra e de 4px:
/// é uma medida dentro de uma linha, não um gráfico.
class TrailCopiedBreakdown extends StatelessWidget {
  const TrailCopiedBreakdown({super.key, required this.copied});

  final Map<ClipboardItemType, int> copied;

  /// Coluna do rótulo. Cabe "Telefones", o mais longo dos tipos.
  static const _labelColumn = 88.0;

  /// Coluna da contagem, à direita — a que se compara correndo o olho.
  static const _countColumn = 32.0;

  static const _trackHeight = 4.0;

  @override
  Widget build(BuildContext context) {
    // Do mais copiado para o menos: a ordem do enum é a do filtro do Pin, que
    // ali serve para procurar um tipo conhecido. Aqui ninguém procura nada —
    // a lista está respondendo "o que dominou o dia".
    final entries = copied.entries.where((entry) => entry.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (entries.isEmpty) return const SizedBox.shrink();

    final largest = entries.first.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              children: [
                EgIcon(
                  entry.key.icon,
                  size: AppIconSizes.xs,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(width: AppSpacing.sm),
                SizedBox(
                  width: _labelColumn,
                  child: Text(
                    entry.key.filterLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: AppTypography.captionSmall,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: _track(entry.value / largest)),
                const SizedBox(width: AppSpacing.md),
                SizedBox(
                  width: _countColumn,
                  child: Text(
                    '${entry.value}',
                    textAlign: TextAlign.right,
                    style: AppTypography.bodyCompactEmphasis,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          'Só o tipo e a contagem — o Trail nunca lê o que foi copiado.',
          style: AppTypography.captionXS.copyWith(
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }

  /// O trilho e a parte preenchida dele.
  ///
  /// Proporcional ao tipo mais copiado do dia, e não ao total: com o total, um
  /// dia normal — em que "Textos" leva quase tudo — desenharia cinco fiapos
  /// idênticos, e a comparação entre os tipos menores sumiria.
  Widget _track(double ratio) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.border,
        borderRadius: AppRadii.badgeSmallAll,
      ),
      child: SizedBox(
        height: _trackHeight,
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: ratio.clamp(0.04, 1.0),
            heightFactor: 1,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.textTertiary,
                borderRadius: AppRadii.badgeSmallAll,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
