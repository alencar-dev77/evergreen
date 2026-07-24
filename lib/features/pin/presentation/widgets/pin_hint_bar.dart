import 'package:flutter/widgets.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_metrics.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../shared/widgets/eg_key_cap.dart';

/// Rodapé do overlay com os atalhos disponíveis.
///
/// O Pin é feito para ser usado sem o mouse; deixar as teclas à vista ensina a
/// navegação sem exigir que o usuário procure documentação.
///
/// As dicas nunca podem quebrar o layout do painel: o grupo da esquerda vive
/// num viewport, então em fonte ou largura apertada a última dica é recortada
/// em silêncio em vez de estourar a linha. O `esc` fica fora dele, ancorado à
/// direita, porque é a dica que não pode sumir.
class PinHintBar extends StatelessWidget {
  const PinHintBar({super.key, required this.isPreviewOpen});

  final bool isPreviewOpen;

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
                  // Setas e Enter dispensam rótulo: ao lado de uma lista eles se
                  // explicam, e o espaço vale mais para o ⌘P, que não.
                  const _Hint(keys: ['↑', '↓']),
                  const _Hint(keys: ['enter']),
                  const _Hint(keys: ['⌘P'], label: 'fixar'),
                  // Com o preview aberto, o Esc já é o caminho de volta —
                  // anunciar o Tab também só ofereceria duas formas de fazer a
                  // mesma coisa. A largura que ele libera é o que permite
                  // anunciar o ⌘⌫, que ninguém descobre por conta própria.
                  if (isPreviewOpen)
                    const _Hint(keys: ['⌘⌫'], label: 'excluir')
                  else
                    const _Hint(keys: ['tab'], label: 'ver'),
                ],
              ),
            ),
          ),
          _Hint(
            keys: const ['esc'],
            label: isPreviewOpen ? 'voltar' : 'sair',
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({
    required this.keys,
    this.label,
    this.isLast = false,
  });

  final List<String> keys;

  /// Teclas evidentes pelo contexto (setas, enter) vão sem rótulo.
  final String? label;

  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(right: isLast ? 0 : AppSpacing.lg),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          EgShortcutDisplay(keys: keys),
          if (label != null) ...[
            const SizedBox(width: AppSpacing.xs),
            Text(
              label!,
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
