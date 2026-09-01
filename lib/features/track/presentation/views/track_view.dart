import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../core/design/app_metrics.dart';
import '../../../../shared/widgets/eg_section_label.dart';
import '../../../../shared/widgets/eg_empty_state.dart';
import '../../../../shared/widgets/eg_icon.dart';
import '../../../../shared/widgets/eg_segmented_control.dart';
import '../../../../shared/widgets/eg_settings_card.dart';
import '../../../home/models/evergreen_module.dart';
import '../../../home/presentation/viewmodels/hub_detail_view_model.dart';
import '../../../../shared/utils/duration_format.dart';
import '../../../../shared/widgets/eg_pill.dart';
import '../../../../shared/widgets/eg_stat_card.dart';
import '../../models/track_day.dart';
import '../../models/track_range.dart';
import '../viewmodels/track_view_model.dart';
import '../widgets/track_day_list.dart';
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
      banner: state.isEmpty
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // O recorte é da **tela**, não de um cartão: ele muda os três
                // números, a faixa da semana e a lista de dias ao mesmo tempo.
                // Morando no cartão, ele mudava de lugar duas vezes — trocava
                // de cartão ao trocar de recorte (a faixa da semana não existe
                // em "Hoje") e trocava de x ao abrir a região de leitura, que
                // desmancha as duas colunas. Um controle que se procura na tela
                // é um controle que não está fixo.
                Row(
                  children: [
                    const Expanded(child: EgSectionLabel('Balanço')),
                    EgSegmentedControl<TrackRange>(
                      value: state.range,
                      options: TrackRange.values,
                      labelOf: (range) => range.label,
                      onChanged: viewModel.setRange,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                _totals(state),
              ],
            ),
      children: [
        if (state.isEmpty)
          const EgSettingsCard(
            title: 'Balanço',
            children: [
              EgEmptyState(
                icon: EgIconData.track,
                title: 'Nada registrado ainda',
                message:
                    'O Track lê o que os outros módulos gravam. Foque uma '
                    'sessão ou grave uma reunião.',
              ),
            ],
          )
        else ...[
          // A faixa é da semana: no recorte de hoje ela teria uma barra só,
          // que não compara nada com nada.
          if (state.range == TrackRange.week)
            EgSettingsCard(
              title: 'Últimos 7 dias',
              children: [TrackWeekStrip(days: state.days, now: now)],
            ),
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
      ],
    );
  }

  /// Os três números do período, soltos acima da grade.
  ///
  /// Eles são o balanço do recorte inteiro, não um dos assuntos dele — dentro
  /// de um cartão virariam cartão-dentro-de-cartão, que é uma moldura a mais
  /// sem nada a mais para emoldurar.
  Widget _totals(TrackState state) {
    return EgStatRow(
      children: [
        EgStatCard(
          label: 'Foco',
          value: DurationFormat.compact(state.totals.focus),
          detail: TrackCounts.of(
            state.totals.focusSessions,
            'sessão',
            'sessões',
          ),
          tone: EgPillTone.positive,
        ),
        EgStatCard(
          label: 'Reunião',
          value: state.totals.meetingCount == 0
              ? '—'
              : DurationFormat.compact(state.totals.meetings),
          detail: TrackCounts.of(
            state.totals.meetingCount,
            'reunião',
            'reuniões',
          ),
          tone: EgPillTone.ember,
        ),
        EgStatCard(
          label: 'Copiado',
          value: '${state.totals.copied}',
          detail: TrackCounts.of(
            state.totals.notesWritten,
            'anotação',
            'anotações',
          ),
          tone: EgPillTone.tide,
        ),
      ],
    );
  }
}
