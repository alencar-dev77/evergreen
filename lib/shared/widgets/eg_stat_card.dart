import 'package:flutter/widgets.dart';

import '../../core/design/app_metrics.dart';
import '../../core/design/eg_tokens.dart';
import '../../core/design/tokens/eg_squircle.dart';
import 'eg_pill.dart';

/// Um número grande com o nome em cima e uma linha de contexto embaixo.
///
/// **O número é o conteúdo, e por isso ele é o maior tipo do bloco.** Uma
/// tabela de rótulos e valores do mesmo tamanho obriga a ler tudo para achar o
/// que importa; aqui o olho pousa no número e só depois lê o resto, que é a
/// ordem em que a pergunta foi feita ("quanto?", e então "de quê?").
///
/// A linha de baixo é onde a cor entra, e só ali: ela compara — "+1 h 05 vs. a
/// semana passada", "40% do tempo ativo" —, e comparação é a única coisa
/// naquele bloco que tem um sentido bom ou ruim.
class EgStatCard extends StatelessWidget {
  const EgStatCard({
    super.key,
    required this.label,
    required this.value,
    this.detail,
    this.tone = EgPillTone.neutral,
  });

  /// O nome, em caixa alta e mono: etiqueta de gaveta, não título.
  final String label;

  /// O número. Já formatado por quem chama — formatar duração é do domínio.
  final String value;

  /// A comparação, ou o que qualifica o número.
  final String? detail;

  /// A cor da linha de baixo. [EgPillTone.neutral] deixa em texto secundário —
  /// o certo quando não há nada a comparar.
  final EgPillTone tone;

  @override
  Widget build(BuildContext context) {
    final eg = context.eg;

    return DecoratedBox(
      decoration: ShapeDecoration(
        color: eg.colors.surface,
        shape: EgSquircle.shape(eg.shapes.radiusCard, side: eg.edge),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: eg.shapes.rowPaddingH,
          vertical: eg.shapes.rowPaddingV + AppSpacing.xxs,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label.toUpperCase(), style: eg.text.overline),
            const SizedBox(height: AppSpacing.sm),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: eg.text.title),
            ),
            if (detail != null) ...[
              const SizedBox(height: AppSpacing.xxs),
              Text(
                detail!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: eg.text.footnote.copyWith(
                  color: tone == EgPillTone.neutral
                      ? eg.colors.textTertiary
                      : tone.labelOf(eg),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A fileira de [EgStatCard], em partes iguais.
///
/// Iguais mesmo quando um número é mais curto: larguras diferentes fariam o
/// bloco parecer uma classificação, e três medidas de coisas diferentes não se
/// classificam entre si.
class EgStatRow extends StatelessWidget {
  const EgStatRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    // `stretch` sozinho pede altura infinita quando a fileira mora numa coluna
    // que rola. O `IntrinsicHeight` mede o mais alto dos três e dá essa altura
    // aos outros — caro em geral, barato aqui, onde são três caixas de texto.
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.md),
          Expanded(child: children[i]),
        ],
      ],
    ),
  );
}
