import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_gradients.dart';
import '../../../../core/design/app_metrics.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/window/hub_window.dart';
import '../../../../core/window/overlay_window.dart';
import '../../../../shared/widgets/eg_button.dart';
import '../../../../shared/widgets/eg_countdown.dart';
import '../../../../shared/widgets/eg_hint_bar.dart';
import '../../../../shared/widgets/eg_panel.dart';
import '../../models/echo_capabilities.dart';
import '../viewmodels/echo_recorder_state.dart';
import '../viewmodels/echo_recorder_view_model.dart';
import 'echo_overlay_intents.dart';

/// Painel flutuante do Echo — a tela que o `⌘⇧E` abre.
///
/// Faz uma coisa só: começar e parar a gravação. Ler a transcrição e pedir o
/// resumo é no Hub, porque texto de meia hora de reunião não cabe num painel
/// estreito e o histórico das reuniões passadas menos ainda.
///
/// Fechar o painel **não** para a reunião. É o caso normal, inclusive: ninguém
/// fica olhando um painel por trinta minutos, e a contagem passa para a barra
/// de menus, que é onde o macOS espera encontrar um estado de segundo plano.
class EchoOverlayView extends ConsumerStatefulWidget {
  const EchoOverlayView({super.key});

  @override
  ConsumerState<EchoOverlayView> createState() => _EchoOverlayViewState();
}

class _EchoOverlayViewState extends ConsumerState<EchoOverlayView>
    with WindowListener, SingleTickerProviderStateMixin {
  final _panelFocusNode = FocusNode(debugLabel: 'echo-panel');

  late final _entrance = AnimationController(
    vsync: this,
    duration: AppDurations.entrance,
    value: 1,
  );

  late final _entranceOpacity =
      CurvedAnimation(parent: _entrance, curve: Curves.easeOut);

  /// Mesma largura do Focus e do Awake: os três mostram um número grande e uma
  /// ação, e larguras diferentes fariam a troca de painel parecer troca de app.
  static const _panelWidth = 380.0;

  static const _blurGracePeriod = Duration(milliseconds: 150);

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _panelFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _entranceOpacity.dispose();
    _entrance.dispose();
    _panelFocusNode.dispose();
    super.dispose();
  }

  @override
  void onWindowFocus() {
    _entrance.forward(from: 0);
    _panelFocusNode.requestFocus();
  }

  @override
  void onWindowBlur() => unawaited(_handleBlur());

  @override
  void onWindowClose() => _close();

  Future<void> _handleBlur() async {
    await Future<void>.delayed(_blurGracePeriod);
    if (!mounted) return;
    if (await windowManager.isFocused()) return;

    await _close();
  }

  EchoRecorderViewModel get _viewModel =>
      ref.read(echoRecorderViewModelProvider.notifier);

  Future<void> _close() => OverlayWindow.instance.hide();

  /// Enter: a ação principal daquele estado.
  ///
  /// Gravar e sair de cena, porque quem apertou o atalho antes da reunião quer
  /// voltar para a reunião. Parar não fecha: a transcrição começa na hora e o
  /// painel é onde ela aparece.
  Future<void> _primary() async {
    final state = ref.read(echoRecorderViewModelProvider);

    switch (state.phase) {
      case EchoPhase.idle:
        // Sem as duas permissões o Enter não tem o que fazer: a tela mostra uma
        // linha por permissão, e cada uma tem o seu botão. Um Enter que
        // "pedisse tudo" escolheria por conta própria qual das duas, e depois
        // de um "não" não abriria diálogo nenhum.
        if (!state.capabilities.canRecord) return;

        await _viewModel.start();
        await _close();

      case EchoPhase.recording:
        await _viewModel.stopAndTranscribe();

      case EchoPhase.done:
        await _openHub();

      case EchoPhase.failed:
        _viewModel.reset();

      case EchoPhase.transcribing:
        break;
    }
  }

  Future<void> _discard() async {
    await _viewModel.cancel();
  }

  Future<void> _openHub() async {
    await _close();
    await HubWindow.instance.open();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(echoRecorderViewModelProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Shortcuts(
        shortcuts: EchoOverlayIntents.shortcuts,
        child: Actions(
          actions: EchoOverlayIntents.actions(
            onPrimary: _primary,
            onDiscard: _discard,
            onClose: _close,
            onOpenSettings: _openHub,
          ),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _close,
            child: Align(
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {},
                  child: FadeTransition(
                    opacity: _entranceOpacity,
                    child: Focus(
                      focusNode: _panelFocusNode,
                      child: EgPanel(
                        width: _panelWidth,
                        gradient: AppGradients.panelSurface,
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
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(EchoRecorderState state) {
    if (!state.capabilities.canRecord && state.phase == EchoPhase.idle) {
      return _permissions(state);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EgCountdown(
          label: _statusLabel(state),
          value: _statusValue(state),
          detail: _statusDetail(state),
          // Parado, o zero é uma proposta, não um fato — mesmo tratamento da
          // tela de partida do Focus e do Awake.
          isMuted: !state.isRecording,
        ),
        if (state.liveText.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          _liveText(state),
        ],
        if (state.errorMessage != null) ...[
          const SizedBox(height: AppSpacing.lg),
          Text(state.errorMessage!, style: AppTypography.captionSmall),
        ],
        const SizedBox(height: AppSpacing.xxl),
        _primaryButton(state),
      ],
    );
  }

  /// A tela que aparece antes de o Echo poder existir.
  ///
  /// **Duas** permissões, uma linha para cada, e cada uma com o seu próprio
  /// botão. Não é preciosismo: elas são pedidas por APIs diferentes, com
  /// comportamentos diferentes, e uma pode estar concedida enquanto a outra
  /// não. Um botão só de "pedir tudo" mentia — depois de um "não", pedir de
  /// novo não abre diálogo nenhum, e a tela ficava sem responder ao clique.
  Widget _permissions(EchoRecorderState state) {
    final capabilities = state.capabilities;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Antes de gravar', style: AppTypography.panelTitle),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'O Echo grava duas faixas separadas — é o que faz ele saber quem '
          'falou sem depender de reconhecimento de voz.',
          style: AppTypography.captionSmall,
        ),
        const SizedBox(height: AppSpacing.xl),
        _PermissionRow(
          title: 'Microfone',
          detail: 'Grava a sua voz.',
          status: capabilities.microphone,
          onPressed: _viewModel.requestMicrophone,
        ),
        const SizedBox(height: AppSpacing.md),
        _PermissionRow(
          title: 'Gravação de Tela',
          detail: 'Dá acesso ao áudio da reunião — a fala das outras pessoas.',
          status: capabilities.screenRecording,
          onPressed: _viewModel.requestScreenRecording,
        ),
        // O macOS só entrega a captura de tela a um processo que subiu depois
        // da permissão. Sem este aviso, a pessoa liga a chave nos Ajustes,
        // volta, e encontra a mesma tela dizendo que falta permissão.
        if (capabilities.screenRecording == PermissionStatus.denied) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            'Depois de ligar a Gravação de Tela nos Ajustes, encerre e abra o '
            'Evergreen de novo — o macOS só libera a captura para um app que '
            'iniciou depois da permissão.',
            style: AppTypography.captionSmall,
          ),
        ],
      ],
    );
  }

  Widget _liveText(EchoRecorderState state) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: AppRadii.cardAll,
      ),
      child: Text(
        state.liveText.join(' '),
        style: AppTypography.captionSmall,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _primaryButton(EchoRecorderState state) => switch (state.phase) {
    EchoPhase.idle => EgButton(
      label: 'Gravar reunião',
      expand: true,
      onPressed: _primary,
    ),
    EchoPhase.recording => EgButton(
      label: 'Parar e transcrever',
      expand: true,
      onPressed: _primary,
    ),
    // Transcrevendo não há o que propor: a tela informa, e o botão que existe é
    // o de sair da frente.
    EchoPhase.transcribing => EgButton.secondary(
      label: 'Fechar',
      expand: true,
      onPressed: _close,
    ),
    EchoPhase.done => EgButton(
      label: 'Abrir no Hub',
      expand: true,
      onPressed: _primary,
    ),
    EchoPhase.failed => EgButton.secondary(
      label: 'Voltar',
      expand: true,
      onPressed: _primary,
    ),
  };

  String _statusLabel(EchoRecorderState state) => switch (state.phase) {
    EchoPhase.idle => 'Echo',
    EchoPhase.recording => 'Gravando',
    EchoPhase.transcribing => 'Transcrevendo',
    EchoPhase.done =>
      (state.lastMeeting?.isEmpty ?? false) ? 'Nenhuma fala' : 'Transcrição pronta',
    EchoPhase.failed => 'Não deu certo',
  };

  String _statusValue(EchoRecorderState state) {
    if (state.phase == EchoPhase.done) {
      final minutes = state.lastMeeting?.duration.inMinutes ?? 0;
      return '$minutes min';
    }

    final minutes = state.elapsed.inMinutes;
    final seconds = state.elapsed.inSeconds % 60;

    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  String? _statusDetail(EchoRecorderState state) => switch (state.phase) {
    EchoPhase.idle => 'Sua voz e o áudio da reunião, em faixas separadas',
    EchoPhase.recording => 'Fechar o painel não para a gravação',
    EchoPhase.transcribing => 'Pode levar alguns minutos',
    EchoPhase.done => (state.lastMeeting?.isEmpty ?? false)
        ? 'A gravação saiu muda — confira o microfone e a saída de áudio'
        : 'O resumo fica no Hub',
    EchoPhase.failed => null,
  };

  /// A barra mostra o que cabe naquele estado, não tudo que existe.
  ///
  /// `⌘. descartar` só aparece gravando, que é o único momento em que há o que
  /// descartar — e é onde a diferença entre ele e o `esc` precisa ficar clara.
  Widget _hintBar(EchoRecorderState state) => EgHintBar(
    hints: [
      if (state.phase != EchoPhase.transcribing &&
          (state.phase != EchoPhase.idle || state.capabilities.canRecord))
        EgHint(keys: const ['enter'], label: _primaryHint(state)),
      if (state.isRecording)
        const EgHint(keys: ['⌘', '.'], label: 'descartar'),
    ],
    // Sempre só "fechar". Gravando, quem explica que a reunião continua é a
    // linha logo acima do botão — repetir aqui estourava a largura do painel e
    // cortava o `⌘. descartar` ao lado, que é a dica que ninguém adivinha.
    trailing: const EgHint(keys: ['esc'], label: 'fechar'),
  );

  String _primaryHint(EchoRecorderState state) => switch (state.phase) {
    EchoPhase.idle => 'gravar',
    EchoPhase.recording => 'parar',
    EchoPhase.done => 'abrir no Hub',
    EchoPhase.failed => 'voltar',
    EchoPhase.transcribing => '',
  };
}

/// Uma permissão: o que ela traz, e o botão que resolve.
///
/// O verbo do botão muda com o estado — "Permitir" enquanto o sistema ainda vai
/// perguntar, "Abrir Ajustes" depois de um "não", porque aí pedir de novo não
/// faz nada. Concedida, some o botão e fica a confirmação.
class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.title,
    required this.detail,
    required this.status,
    required this.onPressed,
  });

  final String title;
  final String detail;
  final PermissionStatus status;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTypography.bodyCompactEmphasis),
              const SizedBox(height: AppSpacing.xxs),
              Text(detail, style: AppTypography.captionXS),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        if (status.isGranted)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xxs),
            child: Text(
              'liberado',
              style: AppTypography.captionXS.copyWith(
                color: AppColors.greenPrimary,
              ),
            ),
          )
        else
          EgButton.secondary(label: status.actionLabel, onPressed: onPressed),
      ],
    );
  }
}
