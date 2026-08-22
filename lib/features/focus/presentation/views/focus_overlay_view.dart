import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/app_metrics.dart';
import '../../../../core/window/hub_window.dart';
import '../../../../core/window/overlay_window.dart';
import '../../../../shared/utils/duration_format.dart';
import '../../../../shared/widgets/eg_button.dart';
import '../../../../shared/widgets/eg_hint_bar.dart';
import '../../../../shared/widgets/eg_overlay_shell.dart';
import '../../../../shared/widgets/eg_panel.dart';
import '../../../../shared/widgets/eg_text_field.dart';
import '../viewmodels/focus_timer_state.dart';
import '../viewmodels/focus_timer_view_model.dart';
import '../../../../shared/widgets/eg_countdown.dart';
import '../widgets/focus_session_log.dart';
import 'focus_overlay_intents.dart';

/// Painel flutuante do Focus — a tela que o `⌘⇧F` abre.
///
/// Divide a janela com o overlay do Pin (ver `OverlayWindow`). Os três estados
/// — partida, contando e concluído — usam o mesmo esqueleto: rótulo da fase,
/// número grande, uma ação principal. É o que faz a sessão inteira acontecer
/// sem a tela nunca se reorganizar debaixo do olho de quem está lendo.
///
/// Fechar o painel não encerra a sessão: ela continua no engine desta janela, e
/// a contagem aparece na barra de menus.
class FocusOverlayView extends ConsumerStatefulWidget {
  const FocusOverlayView({super.key});

  @override
  ConsumerState<FocusOverlayView> createState() => _FocusOverlayViewState();
}

class _FocusOverlayViewState extends ConsumerState<FocusOverlayView> {
  final _activityController = TextEditingController();
  final _summaryController = TextEditingController();
  final _noteController = TextEditingController();

  /// Foco do campo de observação da sessão em andamento. Enquanto ele estiver
  /// focado, `space` deixa de pausar (espaço volta a ser espaço) e o Enter
  /// passa a anotar — daí o listener com setState.
  final _noteFocusNode = FocusNode(debugLabel: 'focus-note');

  /// Um nó só para os dois campos: eles nunca aparecem ao mesmo tempo, e assim
  /// o foco é decidido em um lugar só ([_syncFocus]).
  final _inputFocusNode = FocusNode(debugLabel: 'focus-input');

  /// Segura o foco quando não há campo de texto na tela — sem um nó focado
  /// dentro do painel, o `Shortcuts` não receberia tecla nenhuma.
  final _panelFocusNode = FocusNode(debugLabel: 'focus-panel');

  /// Largura do painel. Mais estreito que o do Pin porque não há lista para
  /// ler: o conteúdo é um número, um campo e uma ação.
  static const _panelWidth = 380.0;

  /// Teto do diário da sessão dentro do painel. Passando disso ele rola, para
  /// que uma sessão muito anotada não empurre os botões para fora da tela.
  static const _logMaxHeight = 96.0;

  @override
  void initState() {
    super.initState();
    _noteFocusNode.addListener(_onNoteFocusChanged);

    // Depois do primeiro quadro: o campo de texto do estado inicial ainda não
    // existe na árvore enquanto o `initState` roda.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncFocus(ref.read(focusTimerViewModelProvider));
    });
  }

  @override
  void dispose() {
    _activityController.dispose();
    _summaryController.dispose();
    _noteController.dispose();
    _noteFocusNode.removeListener(_onNoteFocusChanged);
    _noteFocusNode.dispose();
    _inputFocusNode.dispose();
    _panelFocusNode.dispose();
    super.dispose();
  }

  /// O mapa de atalhos depende de quem tem o foco — reconstruir aqui é o que
  /// devolve o espaço ao campo enquanto se digita.
  void _onNoteFocusChanged() {
    if (mounted) setState(() {});
  }

  /// Põe o foco onde a tela atual espera digitação — ou no painel, quando não
  /// há campo nenhum.
  ///
  /// Explícito, e não `autofocus`, porque o `autofocus` só vale para o primeiro
  /// nó de um escopo: o campo de resumo nasce depois, com o painel já focado, e
  /// nunca receberia o cursor sozinho.
  void _syncFocus(FocusTimerState state) {
    if (_wantsTextInput(state)) {
      _inputFocusNode.requestFocus();
      return;
    }

    _panelFocusNode.requestFocus();
  }

  bool _wantsTextInput(FocusTimerState state) {
    if (state.isIdle) return state.settings.asksActivity;
    if (state.isFinished) {
      return state.phase.isFocus && state.settings.asksSummary;
    }
    return false;
  }

  FocusTimerViewModel get _viewModel =>
      ref.read(focusTimerViewModelProvider.notifier);

  /// Cada abertura do painel começa do zero no que é rascunho: o campo de
  /// atividade de uma sessão que não começou, o resumo de uma que já terminou.
  void _onShow() {
    final state = ref.read(focusTimerViewModelProvider);
    if (state.isIdle) _activityController.clear();
    if (!state.isFinished) _summaryController.clear();

    _syncFocus(state);
  }

  /// Esconde o painel. A sessão em andamento não é afetada — é o comportamento
  /// que a dica do rodapé promete ao dizer "fechar", e não "sair".
  Future<void> _close() => OverlayWindow.instance.hide();

  /// A ação que o Enter executa, sempre a mesma que o botão primário da tela.
  void _primary() {
    final state = ref.read(focusTimerViewModelProvider);

    switch (state.status) {
      case FocusStatus.idle:
        _startFocus(_activityController.text);
      case FocusStatus.running:
      case FocusStatus.paused:
        // Contando, o Enter anota a observação digitada — se houver uma.
        final note = _noteController.text;
        if (note.trim().isEmpty) return;

        _viewModel.addNote(note);
        // O foco fica no campo: quem anota uma vez costuma anotar de novo.
        _noteController.clear();
      case FocusStatus.finished:
        if (state.phase.isFocus) {
          _viewModel.startRest(summary: _summaryController.text);
          _summaryController.clear();
        } else {
          // Fim da pausa: o ciclo continua no mesmo trabalho, então a atividade
          // da sessão anterior segue valendo.
          _startFocus(state.activity);
        }
    }
  }

  void _startFocus(String activity) {
    _viewModel.start(activity: activity);
    _activityController.clear();
  }

  /// Encerra o ciclo e sai de cena — o resumo digitado, se houver, é salvo.
  Future<void> _finishCycle() async {
    _viewModel.dismiss(summary: _summaryController.text);
    _summaryController.clear();
    await _close();
  }

  /// Esc: com o ciclo concluído, fecha o assunto; caso contrário só esconde o
  /// painel e deixa a sessão correndo.
  Future<void> _handleEscape() async {
    if (ref.read(focusTimerViewModelProvider).isFinished) {
      await _finishCycle();
      return;
    }

    await _close();
  }

  /// `⌘,`: sai de cena primeiro, depois abre o Hub — nessa ordem, um problema
  /// ao criar a janela nunca deixa o painel preso na tela.
  Future<void> _openSettings() async {
    await _close();
    await HubWindow.instance.open();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(focusTimerViewModelProvider);

    // O fim da fase chega pelo cronômetro, não por um clique: quando ele troca
    // o estado sozinho, o foco precisa acompanhar a tela nova.
    ref.listen(focusTimerViewModelProvider, (previous, next) {
      if (previous?.status == next.status) return;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncFocus(next);
      });
    });

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Shortcuts(
        shortcuts: FocusOverlayIntents.shortcuts(
          spaceTogglesPause: state.isActive && !_noteFocusNode.hasFocus,
          canExtend: state.canExtend,
        ),
        child: Actions(
          actions: FocusOverlayIntents.actions(
            onPrimary: _primary,
            onTogglePause: _viewModel.togglePause,
            onStop: _viewModel.stop,
            onExtend: _viewModel.extendFocus,
            onClose: _handleEscape,
            onOpenSettings: _openSettings,
          ),
          child: EgOverlayShell(
            onClose: () => unawaited(_close()),
            onShow: _onShow,
            focusNode: _panelFocusNode,
            child: EgPanel(
              width: _panelWidth,
              vibrant: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.xxl),
                    child: _body(state),
                  ),
                  _hintBar(state),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(FocusTimerState state) => switch (state.status) {
        FocusStatus.idle => _idle(state),
        FocusStatus.running || FocusStatus.paused => _active(state),
        FocusStatus.finished => _finished(state),
      };

  /// Partida. O número já mostra a duração configurada, esmaecida: a tela toda
  /// é uma proposta esperando um Enter.
  Widget _idle(FocusTimerState state) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EgCountdown(
          label: state.phase.label,
          value: DurationFormat.countdown(state.settings.focusDuration),
          isMuted: true,
        ),
        if (state.settings.asksActivity) ...[
          const SizedBox(height: AppSpacing.xxl),
          EgTextField(
            controller: _activityController,
            focusNode: _inputFocusNode,
            hintText: 'Em que você vai trabalhar?',
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        EgButton(
          label: 'Iniciar foco',
          expand: true,
          onPressed: () => _startFocus(_activityController.text),
        ),
      ],
    );
  }

  /// Contando (ou pausado). O diário da sessão fica acima do campo, que é onde
  /// a próxima linha entra — o que já foi escrito não pode ficar embaixo do
  /// lugar onde se escreve.
  Widget _active(FocusTimerState state) {
    final isPaused = state.isPaused;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EgCountdown(
          label: isPaused ? 'Pausado' : state.phase.label,
          value: DurationFormat.countdown(state.remaining),
          progress: state.progress,
          isMuted: isPaused,
        ),
        if (state.phase.isFocus && state.settings.asksNotes) ...[
          const SizedBox(height: AppSpacing.md),
          // Tudo vem do estado da ViewModel, não dos controladores: fechar e
          // reabrir o painel não perde nada do que já foi escrito.
          FocusSessionLog(
            activity: state.activity,
            notes: state.notes,
            maxHeight: _logMaxHeight,
          ),
          const SizedBox(height: AppSpacing.md),
          EgTextField(
            controller: _noteController,
            focusNode: _noteFocusNode,
            hintText: 'Anotar o que aconteceu',
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        Row(
          children: [
            Expanded(
              // Retomar é primário porque, com o cronômetro parado, voltar é a
              // única coisa que a tela está propondo. Contando, pausar é apenas
              // uma opção — e opção não é botão verde.
              child: isPaused
                  ? EgButton(
                      label: 'Retomar',
                      expand: true,
                      onPressed: _viewModel.resume,
                    )
                  : EgButton.secondary(
                      label: 'Pausar',
                      expand: true,
                      onPressed: _viewModel.pause,
                    ),
            ),
            if (state.canExtend) ...[
              const SizedBox(width: AppSpacing.sm),
              // Só na reta final e uma vez por sessão: é para terminar o que
              // está quase pronto, não para adiar a pausa.
              Expanded(
                child: EgButton.secondary(
                  label: '+5 min',
                  expand: true,
                  onPressed: _viewModel.extendFocus,
                ),
              ),
            ],
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: EgButton.destructive(
                label: 'Encerrar',
                expand: true,
                onPressed: _viewModel.stop,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Fim de fase. O número passa a ser o que foi feito, no mesmo lugar em que
  /// era o que faltava.
  Widget _finished(FocusTimerState state) {
    final isFocus = state.phase.isFocus;
    // O tempo que o cronômetro correu, não o que o relógio andou — é o mesmo
    // número que foi para o histórico (ver `FocusTimerState.focused`).
    final elapsed = state.focused;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EgCountdown(
          label: isFocus ? 'Sessão concluída' : 'Pausa concluída',
          value: DurationFormat.compact(elapsed),
          detail: isFocus ? state.activity : null,
        ),
        if (isFocus && state.settings.asksSummary) ...[
          const SizedBox(height: AppSpacing.xxl),
          EgTextField(
            controller: _summaryController,
            focusNode: _inputFocusNode,
            hintText: 'O que você fez?',
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        Row(
          children: [
            Expanded(
              child: EgButton(
                label: isFocus ? 'Iniciar pausa' : 'Iniciar foco',
                expand: true,
                onPressed: _primary,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            // "Encerrar", e não "Concluir": este botão fecha o ciclo, não
            // declara que a tarefa acabou. O verbo é o mesmo da sessão em
            // andamento porque o sentido é o mesmo — para por aqui.
            Expanded(
              child: EgButton.secondary(
                label: 'Encerrar',
                expand: true,
                onPressed: _finishCycle,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// As dicas mudam com o estado: cada tela anuncia o que dá para fazer nela,
  /// não o mapa inteiro de atalhos do módulo.
  Widget _hintBar(FocusTimerState state) => switch (state.status) {
        FocusStatus.idle => const EgHintBar(
            hints: [EgHint(keys: ['enter'], label: 'iniciar')],
            trailing: EgHint(keys: ['esc'], label: 'sair'),
          ),
        FocusStatus.running || FocusStatus.paused => EgHintBar(
            hints: [
              // Digitando, o espaço é do texto e o Enter é da anotação; as
              // dicas acompanham para não prometer um atalho desligado.
              if (_noteFocusNode.hasFocus)
                const EgHint(keys: ['enter'], label: 'anotar')
              else
                EgHint(
                  keys: const ['space'],
                  label: state.isPaused ? 'retomar' : 'pausar',
                ),
              const EgHint(keys: ['⌘.'], label: 'encerrar'),
              if (state.canExtend) const EgHint(keys: ['⌘+'], label: '+5 min'),
            ],
            trailing: const EgHint(keys: ['esc'], label: 'fechar'),
          ),
        FocusStatus.finished => EgHintBar(
            hints: [
              EgHint(
                keys: const ['enter'],
                label: state.phase.isFocus ? 'pausa' : 'foco',
              ),
            ],
            trailing: const EgHint(keys: ['esc'], label: 'encerrar'),
          ),
      };
}
