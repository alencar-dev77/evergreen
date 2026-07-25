import 'package:flutter/widgets.dart';

import '../../core/design/app_colors.dart';
import '../../core/design/app_metrics.dart';
import '../../core/design/app_typography.dart';
import 'eg_key_cap.dart';

/// Uma dica de atalho: as teclas e, quando não for óbvio, o que elas fazem.
@immutable
class EgHint {
  const EgHint({required this.keys, this.label});

  final List<String> keys;

  /// Teclas evidentes pelo contexto (setas, enter ao lado de uma lista) vão sem
  /// rótulo — o espaço vale mais para as que ninguém adivinha.
  final String? label;
}

/// Rodapé de painel com os atalhos disponíveis no estado atual.
///
/// Todo painel do Evergreen operado por teclado leva um. É documentação
/// embutida no lugar exato onde a dúvida aparece, e por isso mostra o
/// subconjunto relevante ao momento — não a lista completa de atalhos.
///
/// As dicas nunca podem quebrar o layout: o grupo da esquerda vive num
/// viewport, então em fonte ou largura apertada a última dica é recortada em
/// silêncio em vez de estourar a linha. [trailing] fica fora dele, ancorado à
/// direita, porque é a dica que não pode sumir (tipicamente o `esc`).
class EgHintBar extends StatelessWidget {
  const EgHintBar({super.key, required this.hints, this.trailing});

  final List<EgHint> hints;
  final EgHint? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: AppBorders.subtle),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final hint in hints) _HintLabel(hint: hint),
                ],
              ),
            ),
          ),
          if (trailing != null) _HintLabel(hint: trailing!, isLast: true),
        ],
      ),
    );
  }
}

class _HintLabel extends StatelessWidget {
  const _HintLabel({required this.hint, this.isLast = false});

  final EgHint hint;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(right: isLast ? 0 : AppSpacing.lg),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          EgShortcutDisplay(keys: hint.keys),
          if (hint.label != null) ...[
            const SizedBox(width: AppSpacing.xs),
            Text(
              hint.label!,
              maxLines: 1,
              softWrap: false,
              style: AppTypography.captionXS,
            ),
          ],
        ],
      ),
    );
  }
}
