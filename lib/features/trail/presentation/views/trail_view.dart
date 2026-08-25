import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../core/design/app_metrics.dart';
import '../../../../shared/widgets/eg_empty_state.dart';
import '../../../../shared/widgets/eg_icon.dart';
import '../../../../shared/widgets/eg_segmented_control.dart';
import '../../../../shared/widgets/eg_settings_section.dart';
import '../../../home/models/evergreen_module.dart';
import '../../../home/presentation/viewmodels/hub_detail_view_model.dart';
import '../../models/trail_range.dart';
import '../viewmodels/trail_view_model.dart';
import '../widgets/trail_day_list.dart';
import '../widgets/trail_headline.dart';
import '../widgets/trail_week_strip.dart';

/// Tela do Trail dentro do Hub.
///
/// Duas seções e nada de preferência: o Trail não captura nada, não guarda nada
/// e não tem o que ajustar. Ele é uma consulta sobre o que os outros módulos já
/// gravaram — o balanço do período em cima, os dias embaixo, e o dia aberto na
/// região de leitura ao lado.
class TrailView extends ConsumerStatefulWidget {
  const TrailView({super.key});

  @override
  ConsumerState<TrailView> createState() => _TrailViewState();
}

class _TrailViewState extends ConsumerState<TrailView> {
  @override
  void initState() {
    super.initState();

    // Foco, reunião, cópia e anotação são gravados no engine da janela
    // flutuante; este é o do Hub, que só descobre o que existe indo ao banco.
    // Reler ao abrir a tela é o que faz a sessão recém-concluída aparecer aqui.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(trailViewModelProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(trailViewModelProvider);
    final viewModel = ref.read(trailViewModelProvider.notifier);
    final now = ref.watch(clockProvider)();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // "Balanço", e não "Resumo": resumo já é o nome do parágrafo que o
        // modelo escreve dentro do dia, e a mesma palavra para duas coisas
        // diferentes na mesma tela confunde.
        EgSettingsSection(
          title: 'Balanço',
          trailing: EgSegmentedControl<TrailRange>(
            value: state.range,
            options: TrailRange.values,
            labelOf: (range) => range.label,
            onChanged: viewModel.setRange,
          ),
          children: [
            if (state.isEmpty)
              const EgEmptyState(
                icon: EgIconData.trail,
                title: 'Nada registrado ainda',
                message: 'O Trail lê o que os outros módulos gravam. Foque uma '
                    'sessão, grave uma reunião ou copie alguma coisa — o dia '
                    'aparece aqui sozinho.',
              )
            else ...[
              TrailHeadline(totals: state.totals),
              // A faixa é da semana: no recorte de hoje ela teria uma barra só,
              // que não compara nada com nada.
              if (state.range == TrailRange.week) ...[
                const SizedBox(height: AppSpacing.xl),
                TrailWeekStrip(days: state.days, now: now),
              ],
            ],
          ],
        ),
        if (!state.isEmpty)
          EgSettingsSection(
            title: 'Dias',
            children: [
              TrailDayList(
                days: state.days,
                selectedDate: state.selectedDate,
                now: now,
                onOpen: (date) {
                  viewModel.select(date);
                  // Escolher e abrir são o mesmo gesto: quem clica num dia quer
                  // relê-lo, e a região ao lado é onde ele se lê.
                  ref
                      .read(hubDetailProvider.notifier)
                      .open(EvergreenModule.trail);
                },
              ),
            ],
          ),
      ],
    );
  }
}
