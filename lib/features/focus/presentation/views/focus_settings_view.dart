import '../../../../core/system/global_shortcut_slot.dart';
import '../../../home/presentation/widgets/global_shortcut_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/eg_button.dart';
import '../../../../shared/widgets/eg_confirm_dialog.dart';
import '../../../../shared/widgets/eg_segmented_control.dart';
import '../../../../shared/widgets/eg_settings_row.dart';
import '../../../../shared/widgets/eg_settings_card.dart';
import '../../../home/models/evergreen_module.dart';
import '../../../home/presentation/viewmodels/hub_detail_view_model.dart';
import '../../models/focus_settings.dart';
import '../viewmodels/focus_history_view_model.dart';
import '../viewmodels/focus_settings_view_model.dart';
import '../widgets/focus_history_list.dart';
import '../widgets/focus_summary.dart';
import '../../../notch/models/notch_settings.dart';
import '../../../notch/presentation/widgets/notch_toggle_row.dart';

/// Tela do Focus dentro do Hub.
///
/// O que aconteceu vem antes do que se pode ajustar: quem abre o módulo quer
/// saber em que trabalhou, não mexer na duração da pausa. As preferências ficam
/// logo abaixo, na mesma gramática de seções do Pin.
class FocusSettingsView extends ConsumerStatefulWidget {
  const FocusSettingsView({super.key, this.tab});

  /// A aba aberta. `null` mostra tudo — o caminho de quem monta esta tela fora
  /// do Hub.
  final String? tab;

  @override
  ConsumerState<FocusSettingsView> createState() => _FocusSettingsViewState();
}

class _FocusSettingsViewState extends ConsumerState<FocusSettingsView> {
  @override
  void initState() {
    super.initState();

    // O cronômetro roda no engine da janela flutuante e grava direto no banco;
    // esta janela não é avisada. Reler ao abrir a tela é o que faz a sessão
    // recém-concluída aparecer aqui.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(focusHistoryViewModelProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(focusHistoryViewModelProvider);
    final settings = ref.watch(focusSettingsViewModelProvider);
    final viewModel = ref.read(focusSettingsViewModelProvider.notifier);

    final tab = widget.tab;
    // As duas abas do Focus: o que já aconteceu e o que vai acontecer. Sem aba
    // escolhida (fora do Hub), a tela mostra as duas coisas na ordem de
    // sempre.
    final showHistory = tab == null || tab == 'Histórico';
    final showSettings = tab == null || tab == 'Ajustes';

    return EgSettingsPage(
      children: [
        // "Tempo focado", e não "Resumo": resumo já é o nome do texto que se
        // escreve ao fim de uma sessão, e a mesma palavra para duas coisas
        // diferentes na mesma tela confunde.
        if (showHistory) ...[
          EgSettingsCard(
            title: 'Tempo focado',
            children: [
              FocusSummary(stats: history.stats, sessions: history.sessions),
            ],
          ),
          EgSettingsCard(
            title: 'Histórico',
            children: [
              FocusHistoryList(
                sessions: history.sessions,
                selectedId: history.selectedId,
                onOpen: (id) {
                  ref.read(focusHistoryViewModelProvider.notifier).select(id);
                  // Escolher e abrir são o mesmo gesto: quem clica numa sessão
                  // quer relê-la, e a região ao lado é onde ela se lê.
                  ref
                      .read(hubDetailProvider.notifier)
                      .open(EvergreenModule.focus);
                },
              ),
            ],
          ),
          // Cartão próprio, com o tom do que ele faz. Encostada na lista, a
          // linha de apagar parecia mais uma sessão — a última da semana, com um
          // botão vermelho do lado.
          if (!history.isEmpty)
            EgSettingsCard(
              title: 'Sem volta',
              tone: EgCardTone.destructive,
              children: [
                EgSettingsRow(
                  label: 'Apagar o histórico',
                  description: 'Remove as sessões desta semana.',
                  // "Apagar tudo", e não "Apagar": a região de leitura ao lado
                  // tem um "Apagar" que leva **uma** sessão, e dois botões com o
                  // mesmo rótulo na mesma tela fazendo coisas de tamanhos
                  // diferentes é como se apaga a semana sem querer.
                  trailing: EgButton.destructive(
                    label: 'Apagar tudo',
                    onPressed: () => _clearHistory(context),
                  ),
                ),
              ],
            ),
        ],
        // Os interruptores no topo do tópico, e o tópico logo depois do
        // histórico: são eles que dizem o que uma sessão vai pedir, e as
        // durações só fazem sentido depois de se saber isso.
        if (showSettings) ...[
          EgSettingsCard(
            title: 'Funcionalidades',
            children: [
              EgSettingsRow.toggle(
                label: 'Utilizar apenas Pomodoro',
                description:
                    'Só o timer: sem atividade nem resumo. O histórico '
                    'registra as sessões mesmo assim.',
                value: settings.pomodoroOnly,
                onChanged: viewModel.setPomodoroOnly,
              ),
              // Ligadas ao modo Pomodoro puro, as duas perguntas continuam
              // visíveis e desabilitadas: sumir da tela esconderia que a opção
              // existe (`colors.md`, estado `disabled`).
              //
              // O valor exibido é o **efetivo** (`asksActivity`/`asksSummary`), e
              // não o guardado: um toggle ligado, ainda que apagadinho, prometeria
              // uma pergunta que o modo Pomodoro nunca vai fazer. Desligar o modo
              // devolve as escolhas guardadas.
              EgSettingsRow.toggle(
                label: 'Perguntar a atividade ao iniciar',
                description: 'Um campo de texto antes de começar. Opcional.',
                value: settings.asksActivity,
                onChanged: settings.pomodoroOnly
                    ? null
                    : viewModel.setAskActivity,
              ),
              EgSettingsRow.toggle(
                label: 'Pedir um resumo ao terminar',
                description: 'O que foi feito na sessão. Também opcional.',
                value: settings.asksSummary,
                onChanged: settings.pomodoroOnly
                    ? null
                    : viewModel.setAskSummary,
              ),
              EgSettingsRow.toggle(
                label: 'Tocar som ao finalizar',
                description: 'Vai junto com a notificação de fim de fase.',
                value: settings.playSound,
                onChanged: viewModel.setPlaySound,
              ),
              EgSettingsRow.toggle(
                label: 'Avisar na tela',
                description:
                    'O painel aparece por cima de tudo quando o tempo acaba.',
                value: settings.alertOnScreen,
                onChanged: viewModel.setAlertOnScreen,
              ),
              if (NotchToggleRow.isAvailable(ref))
                const NotchToggleRow(
                  module: NotchModule.focus,
                  label: 'Mostrar no notch',
                  description:
                      'O tempo que falta fica ao lado do notch enquanto a '
                      'sessão corre. Com o mouse em cima, ele abre para pausar '
                      'ou encerrar.',
                ),
            ],
          ),
          EgSettingsCard(
            title: 'Durações',
            children: [
              EgSettingsRow(
                label: 'Tempo de foco',
                // A unidade fica no rótulo, e não repetida em cada opção: cinco
                // "min" seguidos custam metade da largura do seletor e não
                // acrescentam nada — a segunda opção já disse qual é a unidade.
                // Era o que fazia as durações quebrarem em três fileiras.
                description: 'Duração de uma sessão, em minutos.',
                trailing: EgSegmentedControl<int>(
                  value: settings.focusMinutes,
                  options: FocusSettings.focusMinutesOptions,
                  labelOf: (option) => '$option',
                  onChanged: viewModel.setFocusMinutes,
                ),
              ),
              EgSettingsRow(
                label: 'Tempo da pausa',
                description: 'O descanso ao fim da sessão, em minutos.',
                trailing: EgSegmentedControl<int>(
                  value: settings.breakMinutes,
                  options: FocusSettings.breakMinutesOptions,
                  labelOf: (option) => '$option',
                  onChanged: viewModel.setBreakMinutes,
                ),
              ),
            ],
          ),
          GlobalShortcutSection(slot: GlobalShortcutSlot.focus),
        ],
      ],
    );
  }

  /// Apagar o histórico é irreversível — mesma barra do Pin: confirmação antes.
  Future<void> _clearHistory(BuildContext context) async {
    final confirmed = await EgConfirmDialog.show(
      context,
      title: 'Apagar histórico?',
      message:
          'Todas as sessões da semana serão removidas. Não dá para '
          'desfazer.',
      confirmLabel: 'Apagar',
    );
    if (!confirmed) return;

    ref.read(focusHistoryViewModelProvider.notifier).clear();
    // Sem sessão nenhuma não há o que ler ao lado: a região fecha junto, e a
    // janela volta ao tamanho de antes.
    ref.read(hubDetailProvider.notifier).close();
  }
}
