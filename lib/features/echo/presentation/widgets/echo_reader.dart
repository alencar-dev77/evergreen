import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/app_metrics.dart';
import '../../../../shared/utils/day_label.dart';
import '../../../../shared/utils/duration_format.dart';
import '../../../../shared/widgets/eg_confirm_dialog.dart';
import '../../../home/presentation/viewmodels/hub_detail_view_model.dart';
import '../../../home/presentation/widgets/hub_detail_region.dart';
import '../../../home/presentation/viewmodels/app_settings_view_model.dart';
import '../viewmodels/echo_library_view_model.dart';
import '../viewmodels/echo_playback_view_model.dart';
import 'echo_meeting_detail.dart';
import 'echo_player_bar.dart';
import '../../../../core/design/eg_tokens.dart';

/// A reunião aberta, na região dedicada do Hub.
///
/// É o que a janela cresce para mostrar: a reunião inteira, em largura de
/// documento e altura de janela, ao lado da lista que continua onde estava.
/// Antes disso a leitura dividia a área de conteúdo com a lista e ficava
/// espremida; antes ainda, vinha empilhada embaixo e empurrava a lista para
/// fora da tela.
class EchoReader extends ConsumerWidget {
  const EchoReader({super.key, this.width = HubDetailRegion.preferredWidth});

  /// Largura concedida pelo Hub — menor que a preferida enquanto a janela
  /// cresce, e em tela pequena demais para crescer o bastante.
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(echoLibraryViewModelProvider);
    final meeting = library.selected;

    // Sem reunião selecionada não há região: apagar a última reunião aberta
    // fecha a região junto, em vez de deixar uma coluna vazia na tela.
    if (meeting == null) return const SizedBox.shrink();

    final viewModel = ref.read(echoLibraryViewModelProvider.notifier);

    // Assistir o player é o que o mantém vivo: ele segue a seleção sozinho, e
    // só existe enquanto a leitura está na tela.
    final playback = ref.watch(echoPlaybackViewModelProvider);
    final player = ref.read(echoPlaybackViewModelProvider.notifier);
    final isPlayable = playback.meetingId == meeting.id;

    return HubDetailRegion(
      width: width,
      onClose: () => ref.read(hubDetailProvider.notifier).close(),
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            meeting.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.eg.text.panelTitle,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            [
              DayLabel.of(meeting.startedAt),
              DayLabel.time(meeting.startedAt),
              DurationFormat.compact(meeting.duration),
              // O que a gravação pegou. Não é "quantas vozes": o Echo separa
              // faixas, não pessoas, e dizer "3 vozes" prometeria um
              // reconhecimento que ele não faz — ver `Speaker`.
              if (!meeting.isEmpty)
                meeting.hasMyVoice ? 'sua voz e a reunião' : 'só a reunião',
            ].join(' · '),
            style: context.eg.text.footnote,
          ),
          // Sem áudio (reunião antiga, áudio vencido) a linha não existe — nem
          // um player desabilitado, que prometeria algo que não vai acontecer.
          if (isPlayable) ...[
            const SizedBox(height: AppSpacing.md),
            EchoPlayerBar(
              state: playback,
              onToggle: () => unawaited(player.toggle()),
              onSkip: (offset) => unawaited(player.skipBy(offset)),
              onSeek: (ms) => unawaited(player.seekTo(ms)),
              onCycleRate: () => unawaited(player.cycleRate()),
            ),
          ],
        ],
      ),
      child: EchoMeetingDetail(
        playback: isPlayable ? playback : null,
        onSeek: (ms) => unawaited(player.seekTo(ms)),
        onUserScroll: player.stopFollowing,
        meeting: meeting,
        userName: ref.watch(
          appSettingsViewModelProvider.select((settings) => settings.userName),
        ),
        summaries: library.summaries,
        isSummarizing: library.summarizingId == meeting.id,
        progress: library.progress,
        onSummarize: () => viewModel.summarize(meeting.id!),
        onCancelSummary: () => unawaited(viewModel.cancelSummary()),
        onCopy: (kind) => viewModel.copy(meeting.id!, kind),
        onExport: (kind) => viewModel.export(meeting.id!, kind),
        onDelete: () async {
          // Apagar é irreversível — pede confirmação, como o "Apagar tudo" e
          // como a sessão do Focus.
          final confirmed = await EgConfirmDialog.show(
            context,
            title: 'Apagar reunião?',
            message:
                'A reunião, a transcrição, o resumo e o áudio serão '
                'removidos. Não dá para desfazer.',
            confirmLabel: 'Apagar',
          );
          if (!confirmed) return;

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
