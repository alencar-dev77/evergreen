import 'package:flutter/widgets.dart';

import '../../../../shared/utils/duration_format.dart';
import '../../models/track_day.dart';
import '../../../../core/design/eg_tokens.dart';

/// A manchete do período: o que aconteceu, numa frase.
///
/// Um parágrafo com pesos diferentes, e não uma fileira de cartõezinhos de
/// estatística — quatro números do mesmo tamanho lado a lado obrigam a ler os
/// quatro para achar o que se queria, e transformam a tela num dashboard.
/// Aqui o tempo focado é o número grande, o resto vem atrás dele, e numa janela
/// estreita a frase quebra em duas linhas em vez de estourar o layout (é a
/// mesma escolha do `FocusTotals`, pelo mesmo motivo).
///
/// O foco aparece sempre, mesmo zerado: um período sem foco nenhum é uma
/// informação, não um pedaço faltando. Os outros trechos só aparecem quando há
/// o que contar.
class TrackHeadline extends StatelessWidget {
  const TrackHeadline({super.key, required this.totals});

  final TrackTotals totals;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: DurationFormat.compact(totals.focus),
            style: context.eg.text.screenTitle,
          ),
          TextSpan(
            text: totals.focusSessions == 0
                ? '  focadas'
                : '  focadas em '
                      '${TrackCounts.of(totals.focusSessions, 'sessão', 'sessões')}',
            style: context.eg.text.captionXS,
          ),
          if (totals.meetingCount > 0) ...[
            _separator,
            TextSpan(
              text: DurationFormat.compact(totals.meetings),
              style: context.eg.text.bodyEmphasis,
            ),
            TextSpan(
              text:
                  '  em '
                  '${TrackCounts.of(totals.meetingCount, 'reunião', 'reuniões')}',
              style: context.eg.text.captionXS,
            ),
          ],
          if (totals.copied > 0) ...[
            _separator,
            TextSpan(
              text: '${totals.copied}',
              style: context.eg.text.bodyEmphasis,
            ),
            TextSpan(
              text: totals.copied == 1 ? '  item copiado' : '  itens copiados',
              style: context.eg.text.captionXS,
            ),
          ],
          if (totals.notesWritten > 0) ...[
            _separator,
            TextSpan(
              text: '${totals.notesWritten}',
              style: context.eg.text.bodyEmphasis,
            ),
            TextSpan(
              text: totals.notesWritten == 1 ? '  anotação' : '  anotações',
              style: context.eg.text.captionXS,
            ),
          ],
        ],
      ),
    );
  }

  static const _separator = TextSpan(text: '   ·   ');
}
