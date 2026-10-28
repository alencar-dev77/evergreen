import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../core/design/app_metrics.dart';
import '../../../../core/design/eg_tokens.dart';
import '../../../../shared/widgets/eg_section_label.dart';
import '../../../../shared/widgets/eg_empty_state.dart';
import '../../../../shared/utils/day_label.dart';
import '../../../../shared/widgets/eg_button.dart';
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
      // O recorte é da **tela**, não de um cartão: ele muda os três números, a
      // faixa da semana e a lista de dias ao mesmo tempo. Morando no cartão,
      // ele mudava de lugar duas vezes — trocava de cartão ao trocar de recorte
      // (a faixa da semana não existe em "Hoje") e descia junto com a pilha ao
      // abrir a região de leitura. Um controle que se procura na tela é um
      // controle que não está fixo.
      //
      // E ele fica na tela mesmo com o recorte vazio: segunda-feira às oito
      // não tem nada nesta semana, e é justamente quando se quer voltar para a
      // anterior. Escondê-lo junto com os números deixaria a pessoa presa num
      // recorte vazio.
      banner: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(child: EgSectionLabel('Balanço')),
              if (state.range == TrackRange.week) ...[
                _WeekStepper(
                  label: state.weeksAgo == 0
                      ? 'Esta semana'
                      : DayLabel.week(state.weekStart(now)),
                  onPrevious: state.canGoBack
                      ? viewModel.showPreviousWeek
                      : null,
                  onNext: state.canGoForward ? viewModel.showNextWeek : null,
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              EgSegmentedControl<TrackRange>(
                value: state.range,
                options: TrackRange.values,
                labelOf: (range) => range.label,
                onChanged: viewModel.setRange,
              ),
            ],
          ),
          if (!state.isEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            _totals(state),
          ],
        ],
      ),
      children: [
        if (state.isEmpty)
          // "Dias", e não "Balanço": o rótulo do balanço já está no topo, junto
          // do recorte, e é a lista de dias que está vazia.
          EgSettingsCard(
            title: 'Dias',
            children: [
              state.isAtStart
                  ? const EgEmptyState(
                      icon: EgIconData.track,
                      title: 'Nada registrado ainda',
                      message:
                          'O Track lê o que os outros módulos gravam. Foque '
                          'uma sessão ou grave uma reunião.',
                    )
                  : EgEmptyState(
                      icon: EgIconData.track,
                      title: state.range == TrackRange.today
                          ? 'Nada registrado hoje'
                          : 'Nada registrado nesta semana',
                      message:
                          'Foco, reuniões, cópias e anotações do período '
                          'aparecem aqui.',
                    ),
            ],
          )
        else ...[
          // A faixa é da semana: no recorte de hoje ela teria uma barra só,
          // que não compara nada com nada.
          if (state.range == TrackRange.week)
            EgSettingsCard(
              title: 'Por dia',
              children: [
                TrackWeekStrip(
                  days: state.days,
                  weekStart: state.weekStart(now),
                  now: now,
                ),
              ],
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

/// Anda de semana em semana dentro do recorte de semana.
///
/// Setas e o nome da semana, e não um calendário: o Track fecha semanas, não
/// responde por datas soltas (ver `TrackRange`). Cada seta some do alcance —
/// desabilitada, não escondida — na ponta dela: para a frente não há semana
/// depois desta, e para trás o Focus já não guarda o foco.
class _WeekStepper extends StatelessWidget {
  const _WeekStepper({required this.label, this.onPrevious, this.onNext});

  final String label;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        EgIconButton(
          icon: EgIconData.chevronLeft,
          tooltip: 'Semana anterior',
          size: AppBadgeSizes.sm,
          iconSize: AppIconSizes.sm,
          onPressed: onPrevious,
          repeatable: true,
        ),
        // Largura fixa: "Esta semana" e "29 set – 5 out" têm tamanhos
        // diferentes, e as setas não podem fugir do cursor a cada clique.
        SizedBox(
          width: _labelWidth,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: context.eg.text.footnote,
          ),
        ),
        EgIconButton(
          icon: EgIconData.chevronRight,
          tooltip: 'Próxima semana',
          size: AppBadgeSizes.sm,
          iconSize: AppIconSizes.sm,
          onPressed: onNext,
          repeatable: true,
        ),
      ],
    );
  }

  static const _labelWidth = 104.0;
}
