import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/app_metrics.dart';
import '../../../../shared/utils/day_label.dart';
import '../../../../shared/utils/duration_format.dart';
import '../../../../shared/widgets/eg_confirm_dialog.dart';
import '../../models/focus_session.dart';
import '../../../home/presentation/viewmodels/hub_detail_view_model.dart';
import '../../../home/presentation/widgets/hub_detail_region.dart';
import '../viewmodels/focus_history_view_model.dart';
import 'focus_session_detail.dart';
import '../../../../core/design/eg_tokens.dart';

/// A sessão aberta, na região dedicada do Hub.
///
/// Mesma forma da reunião do Echo, e de propósito: no Evergreen, conteúdo longo
/// para reler abre na coluna que a janela cresce para caber, nunca num diálogo
/// por cima da tela. Era um diálogo de 420px até aqui — e um diálogo modal
/// escurece o histórico atrás dele, prende o teclado e obriga a fechar para
/// olhar a sessão vizinha. A região deixa a lista à vista, e trocar de sessão é
/// um clique.
class FocusReader extends ConsumerWidget {
  const FocusReader({super.key, this.width = HubDetailRegion.preferredWidth});

  /// Largura concedida pelo Hub — menor que a preferida enquanto a janela
  /// cresce, e em tela pequena demais para crescer o bastante.
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(
      focusHistoryViewModelProvider.select((state) => state.selected),
    );

    // Sem sessão selecionada não há região: apagar a sessão aberta fecha a
    // região junto, em vez de deixar uma coluna vazia na tela.
    if (session == null) return const SizedBox.shrink();

    return HubDetailRegion(
      width: width,
      onClose: () => ref.read(hubDetailProvider.notifier).close(),
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            // O mesmo nome que a linha do histórico mostra: quem clicou numa
            // linha precisa reconhecer, no topo da região, que abriu aquela.
            session.hasActivity ? session.activity! : 'Sessão',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.eg.text.panelTitle,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            '${DayLabel.of(session.startedAt)} · '
            '${DayLabel.time(session.startedAt)} · '
            '${DurationFormat.compact(session.duration)}',
            style: context.eg.text.captionXS,
          ),
        ],
      ),
      child: FocusSessionDetail(
        session: session,
        onDelete: () => _delete(context, ref, session),
      ),
    );
  }

  /// Apagar é irreversível — pede confirmação, como o "Limpar histórico".
  ///
  /// A confirmação continua sendo um diálogo, e não uma pergunta na própria
  /// região: uma pergunta de sim ou não é exatamente o que um modal faz bem, e
  /// é o único caso em que o Evergreen escurece a tela atrás.
  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    FocusSession session,
  ) async {
    final confirmed = await EgConfirmDialog.show(
      context,
      title: 'Apagar sessão?',
      message:
          'A sessão e o que você anotou nela serão removidos. '
          'Não dá para desfazer.',
      confirmLabel: 'Apagar',
    );
    if (!confirmed) return;

    ref.read(focusHistoryViewModelProvider.notifier).delete(session);
    // A sessão apagada era a que estava aberta: a região se fecha junto, e a
    // janela volta ao tamanho de antes. Sem isto sobraria uma coluna vazia
    // encostada na tela de preferências.
    ref.read(hubDetailProvider.notifier).close();
  }
}
