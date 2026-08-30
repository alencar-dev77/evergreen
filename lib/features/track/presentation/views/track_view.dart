import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../core/design/app_metrics.dart';
import '../../../../shared/widgets/eg_empty_state.dart';
import '../../../../shared/widgets/eg_icon.dart';
import '../../../../shared/widgets/eg_segmented_control.dart';
import '../../../../shared/widgets/eg_settings_card.dart';
import '../../../home/models/evergreen_module.dart';
import '../../../home/presentation/viewmodels/hub_detail_view_model.dart';
import '../../models/track_range.dart';
import '../viewmodels/track_view_model.dart';
import '../widgets/track_day_list.dart';
import '../widgets/track_headline.dart';
import '../widgets/track_week_strip.dart';

/// Tela do Track dentro do Hub.
///
/// Duas seções e nada de preferência: o Track não captura nada, não guarda nada
/// e não tem o que ajustar. Ele é uma consulta sobre o que os outros módulos já
/// gravaram — o balanço do período em cima, os dias embaixo, e o dia aberto na
/// região de leitura ao lado.
class TrackView extends ConsumerStatefulWidget {
  const TrackView({super.key});

  @override
  ConsumerState<TrackView> createState() => _TrackViewState();
}

class _TrackViewState extends ConsumerState<TrackView> {
  @override
  void initState() {
    super.initState();

    // Foco, reunião, cópia e anotação são gravados no engine da janela
    // flutuante; este é o do Hub, que só descobre o que existe indo ao banco.
    // Reler ao abrir a tela é o que faz a sessão recém-concluída aparecer aqui.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(trackViewModelProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(trackViewModelProvider);
    final viewModel = ref.read(trackViewModelProvider.notifier);
    final now = ref.watch(clockProvider)();

    return EgSettingsPage(
      children: [
        // "Balanço", e não "Resumo": resumo já é o nome do parágrafo que o
        // modelo escreve dentro do dia, e a mesma palavra para duas coisas
        // diferentes na mesma tela confunde.
        EgSettingsCard(
          title: 'Balanço',
          trailing: EgSegmentedControl<TrackRange>(
            value: state.range,
            options: TrackRange.values,
            labelOf: (range) => range.label,
            onChanged: viewModel.setRange,
          ),
          children: [
            if (state.isEmpty)
              const EgEmptyState(
                icon: EgIconData.track,
                title: 'Nada registrado ainda',
                message:
                    'O Track lê o que os outros módulos gravam. Foque uma '
                    'sessão ou grave uma reunião.',
              )
            else ...[
              TrackHeadline(totals: state.totals),
              // A faixa é da semana: no recorte de hoje ela teria uma barra só,
              // que não compara nada com nada.
              if (state.range == TrackRange.week) ...[
                const SizedBox(height: AppSpacing.xl),
                TrackWeekStrip(days: state.days, now: now),
              ],
            ],
          ],
        ),
        if (!state.isEmpty)
          EgSettingsCard(
            title: 'Dias',
            children: [
              TrackDayList(
                days: state.days,
                selectedDate: state.selectedDate,
                now: now,
                onOpen: (date) {
                  viewModel.select(date);
                  // Escolher e abrir são o mesmo gesto: quem clica num dia quer
                  // relê-lo, e a região ao lado é onde ele se lê.
                  ref
                      .read(hubDetailProvider.notifier)
                      .open(EvergreenModule.track);
                },
              ),
            ],
          ),
      ],
    );
  }
}
