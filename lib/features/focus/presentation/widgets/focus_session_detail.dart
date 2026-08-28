import 'package:flutter/widgets.dart';

import '../../../../core/design/app_metrics.dart';
import '../../../../shared/widgets/eg_button.dart';
import '../../../../shared/widgets/eg_section_label.dart';
import '../../models/focus_session.dart';
import 'focus_session_log.dart';
import '../../../../core/design/eg_tokens.dart';

/// O corpo da região de leitura do Focus: o que foi escrito numa sessão.
///
/// O título e os metadados ficam no cabeçalho da região (`HubDetailRegion`),
/// ao lado do botão de fechar — aqui fica só o que se lê e a única ação que a
/// sessão aceita.
///
/// É sobretudo consulta: a sessão já aconteceu, não há o que refazer nela. A
/// única ação é apagar aquele registro, para que corrigir um erro de anotação
/// não custe a semana inteira — e por isso ela fica sozinha no rodapé, no lugar
/// onde a reunião do Echo põe a dela.
class FocusSessionDetail extends StatelessWidget {
  const FocusSessionDetail({
    super.key,
    required this.session,
    required this.onDelete,
  });

  final FocusSession session;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // A leitura rola dentro da região, não na página: é o que mantém o
        // histórico ao lado sempre à vista.
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: _body(context),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            const Spacer(),
            EgButton.destructive(label: 'Apagar', onPressed: onDelete),
          ],
        ),
      ],
    );
  }

  Widget _body(BuildContext context) {
    if (!session.hasNotes && !session.hasSummary) {
      return Text(
        'Nenhuma anotação nesta sessão.',
        style: context.eg.text.captionSmall,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (session.hasNotes) ...[
          const EgSectionLabel(
            'Anotações',
            padding: EdgeInsets.only(bottom: AppSpacing.sm),
          ),
          // Sem a atividade: ela já é o título da região, e repeti-la aqui
          // seria a mesma frase duas vezes na mesma tela.
          //
          // E sem teto de altura, ao contrário do diálogo que esta região
          // substituiu: lá as anotações rolavam dentro de uma caixa de 220px
          // dentro de um diálogo; aqui a coluna inteira já é a área de leitura,
          // e uma segunda barra de rolagem dentro dela seria rolagem dentro de
          // rolagem.
          FocusSessionLog(activity: null, notes: session.notes),
        ],
        if (session.hasSummary) ...[
          if (session.hasNotes) const SizedBox(height: AppSpacing.xxl),
          const EgSectionLabel(
            'Resumo',
            padding: EdgeInsets.only(bottom: AppSpacing.sm),
          ),
          Text(session.summary!, style: context.eg.text.reading),
        ],
      ],
    );
  }
}
