import 'package:flutter/widgets.dart';

import '../../core/design/app_metrics.dart';
import '../../core/design/eg_tokens.dart';
import 'eg_section_label.dart';

/// O cabeçalho de um dia numa lista de histórico: o dia à esquerda, o quanto
/// ele somou à direita.
///
/// O total é do **cabeçalho**, e não de uma linha extra no fim do grupo: quem
/// corre o olho por uma lista de dias está comparando dias, e a comparação
/// acontece na mesma altura em que o dia é nomeado. No pé do grupo, o número
/// de segunda-feira ficaria a doze linhas do de terça.
///
/// É o mesmo cabeçalho nas duas listas que agrupam por dia — as sessões do
/// Focus e as reuniões do Echo. Elas respondem à mesma pergunta ("o que
/// aconteceu e quando"), e ler uma já ensina a ler a outra; um total desenhado
/// de dois jeitos desfaz isso por nada.
class EgDayHeader extends StatelessWidget {
  const EgDayHeader({
    super.key,
    required this.label,
    this.total,
    this.trailingInset = 0,
  });

  /// "Hoje", "Ontem", "23 jul" — o que o `DayGroup` já traz pronto.
  final String label;

  /// O somado do dia. `null` numa lista em que somar não diz nada.
  final String? total;

  /// O que existe à direita da coluna de duração **na linha**, e que o total
  /// precisa pular para cair em cima dela.
  ///
  /// É a estrela de guardar da reunião do Echo: sem este recuo o total do dia
  /// fica 28 px à direita das durações que ele soma, e duas colunas de número
  /// quase alinhadas leem-se pior que uma só.
  final double trailingInset;

  @override
  Widget build(BuildContext context) {
    final total = this.total;

    return Padding(
      // O recuo lateral é o da linha, para o rótulo alinhar com o texto dela e
      // não com a borda do fundo de hover.
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.xxs,
      ),
      child: Row(
        children: [
          Expanded(child: EgSectionLabel(label)),
          if (total != null)
            Padding(
              padding: EdgeInsets.only(right: trailingInset),
              child: Text(
                total,
                // Em mono, como a duração da linha logo abaixo: é a mesma
                // grandeza, e as duas se leem na mesma coluna.
                style: context.eg.text.monoSmall.copyWith(
                  color: context.eg.colors.textTertiary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
