import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/app_metrics.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../shared/utils/day_label.dart';
import '../../../../shared/utils/duration_format.dart';
import '../../../home/presentation/viewmodels/hub_detail_view_model.dart';
import '../../../home/presentation/widgets/hub_detail_region.dart';
import '../viewmodels/echo_library_view_model.dart';
import 'echo_meeting_detail.dart';

/// A reunião aberta, na região dedicada do Hub.
///
/// É o que a janela cresce para mostrar: a reunião inteira, em largura de
/// documento e altura de janela, ao lado da lista que continua onde estava.
/// Antes disso a leitura dividia a área de conteúdo com a lista e ficava
/// espremida; antes ainda, vinha empilhada embaixo e empurrava a lista para
/// fora da tela.
class EchoReader extends ConsumerWidget {
  const EchoReader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(echoLibraryViewModelProvider);
    final meeting = library.selected;

    // Sem reunião selecionada não há região: apagar a última reunião aberta
    // fecha a região junto, em vez de deixar uma coluna vazia na tela.
    if (meeting == null) return const SizedBox.shrink();

    final viewModel = ref.read(echoLibraryViewModelProvider.notifier);

    return HubDetailRegion(
      onClose: () => ref.read(hubDetailProvider.notifier).close(),
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            meeting.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.panelTitle,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            '${DayLabel.of(meeting.startedAt)} · '
            '${DayLabel.time(meeting.startedAt)} · '
            '${DurationFormat.compact(meeting.duration)}',
            style: AppTypography.captionXS,
          ),
        ],
      ),
      child: EchoMeetingDetail(
        meeting: meeting,
        summaries: library.summaries,
        isSummarizing: library.summarizingId == meeting.id,
        progress: library.progress,
        onSummarize: () => viewModel.summarize(meeting.id!),
        onDelete: () {
          viewModel.delete(meeting.id!);
          // Apagar a última reunião esvazia a biblioteca: a região se fecha
          // junto, e a janela volta ao tamanho de antes. Sem isto sobraria uma
          // coluna vazia de 480px encostada na tela de preferências.
          if (ref.read(echoLibraryViewModelProvider).selected == null) {
            ref.read(hubDetailProvider.notifier).close();
          }
        },
      ),
    );
  }
}
