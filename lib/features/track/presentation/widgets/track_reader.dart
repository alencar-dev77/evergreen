import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../core/design/app_metrics.dart';
import '../../../../shared/utils/day_label.dart';
import '../../../home/presentation/viewmodels/hub_detail_view_model.dart';
import '../../../home/presentation/widgets/hub_detail_region.dart';
import '../viewmodels/track_view_model.dart';
import 'track_day_detail.dart';
import '../../../../core/design/eg_tokens.dart';

/// O dia aberto, na região dedicada do Hub.
///
/// Mesma forma da reunião do Echo e da sessão do Focus, e de propósito: no
/// Evergreen, conteúdo longo para reler abre na coluna que a janela cresce para
/// caber, nunca num diálogo por cima da tela — assim a lista de dias continua à
/// vista e trocar de dia é um clique.
class TrackReader extends ConsumerWidget {
  const TrackReader({super.key, this.width = HubDetailRegion.preferredWidth});

  /// Largura concedida pelo Hub — menor que a preferida enquanto a janela
  /// cresce, e em tela pequena demais para crescer o bastante.
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(trackViewModelProvider);
    final day = state.selected;
    // O mesmo relógio da lista: sem ele o cabeçalho diria "23 jul" ao lado de
    // uma linha marcada como "Hoje".
    final now = ref.watch(clockProvider)();

    // Sem dia selecionado não há região: trocar o recorte e perder o dia
    // aberto fecha a coluna, em vez de deixá-la vazia na tela.
    if (day == null) return const SizedBox.shrink();

    return HubDetailRegion(
      width: width,
      onClose: () {
        ref.read(trackViewModelProvider.notifier).closeSelection();
        ref.read(hubDetailProvider.notifier).close();
      },
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            // O mesmo rótulo que a linha da lista mostra: quem clicou numa
            // linha precisa reconhecer, no topo da região, que abriu aquela.
            DayLabel.of(day.date, now: now),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.eg.text.panelTitle,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            day.isEmpty ? 'Nada registrado' : day.highlights.join(' · '),
            style: context.eg.text.captionXS,
          ),
        ],
      ),
      child: TrackDayDetail(day: day, summary: state.selectedSummary),
    );
  }
}
