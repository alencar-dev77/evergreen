import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/app_metrics.dart';
import '../../../../core/window/hub_destination.dart';
import '../../../../core/window/hub_window.dart';
import '../../../home/models/evergreen_module.dart';
import '../../../../core/window/overlay_window.dart';
import '../../../../shared/widgets/eg_button.dart';
import '../../../../core/design/tokens/eg_squircle.dart';
import '../../../../shared/widgets/eg_countdown.dart';
import '../../../../shared/widgets/eg_icon.dart';
import '../../../../shared/widgets/eg_section_label.dart';
import '../widgets/echo_level_track.dart';
import '../../../../shared/widgets/eg_hint_bar.dart';
import '../../../../shared/widgets/eg_overlay_shell.dart';
import '../../../../shared/widgets/eg_panel.dart';
import '../../models/echo_capabilities.dart';
import '../viewmodels/echo_recorder_state.dart';
import '../viewmodels/echo_recorder_view_model.dart';
import '../widgets/echo_permission_row.dart';
import 'echo_overlay_intents.dart';
import '../../../../core/design/eg_tokens.dart';

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

class _EchoOverlayViewState extends ConsumerState<EchoOverlayView> {
  final _panelFocusNode = FocusNode(debugLabel: 'echo-panel');

  /// Mesma largura do Focus e do Awake: os três mostram um número grande e uma
  /// ação, e larguras diferentes fariam a troca de painel parecer troca de app.
  static const _panelWidth = 380.0;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _panelFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _panelFocusNode.dispose();
    super.dispose();
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
        // Gravação muda não tem o que ser lido no Hub; a proposta ali é tentar
        // de novo. Com transcrição, é o contrário.
        if (state.lastMeeting?.isEmpty ?? false) {
          _viewModel.reset();
          return;
        }
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

  /// Abre o Hub **no Echo**.
  ///
  /// Quem acabou de gravar e aperta "Abrir no Hub" quer ver a reunião, não a
  /// tela em que o Hub por acaso parou da última vez. O destino é pedido antes
  /// de a janela aparecer, porque é ela que o lê ao nascer — ver
  /// [HubDestination].
  Future<void> _openHub() async {
    await _close();
    await HubDestination.request(EvergreenModule.echo.id);
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
          child: EgOverlayShell(
            onClose: () => unawaited(_close()),
            onShow: _panelFocusNode.requestFocus,
            focusNode: _panelFocusNode,
            // O único painel que se arrasta. Os outros quatro se resolvem em
            // segundos e no centro da tela; este fica na frente da reunião
            // enquanto ela acontece, e é a reunião que estava ali primeiro.
            draggable: true,
            // Gravando ou transcrevendo, clicar na reunião não fecha o painel —
            // é justamente aí que se quer os dois à vista. Ver
            // `EgOverlayShell.dismissOnBlur`.
            dismissOnBlur: !state.isRecording && !state.isBusy,
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

  Widget _body(EchoRecorderState state) {
    if (!state.capabilities.canRecord && state.phase == EchoPhase.idle) {
      return _permissions(state);
    }

    if (state.isRecording) return _recording(state);

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
          Text(state.errorMessage!, style: context.eg.text.caption),
        ],
        const SizedBox(height: AppSpacing.xxl),
        _primaryButton(state),
      ],
    );
  }

  /// Gravando: o painel deixa de ser um cronômetro e vira um **gravador**.
  ///
  /// A pergunta de quem abre o painel no meio de uma reunião não é "quanto
  /// tempo já deu" — é "está entrando som?", e por faixa, porque faixa muda é o
  /// defeito mais caro do módulo: ele só aparece no fim, quando o áudio já foi.
  /// O relógio continua ali, do tamanho de um relógio, no canto onde se olha
  /// quando a pergunta é outra.
  Widget _recording(EchoRecorderState state) {
    final eg = context.eg;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            // O ponto é o vocabulário universal de "gravando", e é a única
            // coisa vermelha do painel: aqui ele não avisa perigo, avisa que a
            // máquina está registrando.
            _RecordingDot(isPaused: state.isPaused),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                state.isPaused ? 'Pausado' : 'Gravando',
                style: eg.text.panelTitle,
              ),
            ),
            Text(
              _statusValue(state),
              style: eg.text.mono.copyWith(color: eg.colors.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        EchoLevelTrack(
          label: 'Você',
          bands: state.spectrum?.mic ?? const [],
          color: eg.colors.accent,
        ),
        const SizedBox(height: AppSpacing.sm),
        EchoLevelTrack(
          label: 'Sistema',
          bands: state.spectrum?.system ?? const [],
          // Azul, e não um segundo verde: as duas faixas existem para serem
          // distinguidas de relance, e o accent já quer dizer outra coisa em
          // toda a suíte. É a cor de dado neutro do tema.
          color: eg.colors.tide,
        ),
        if (state.liveText.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          _lastHeard(state),
        ],
        if (state.errorMessage != null) ...[
          const SizedBox(height: AppSpacing.lg),
          Text(state.errorMessage!, style: eg.text.caption),
        ],
        const SizedBox(height: AppSpacing.xl),
        Row(
          children: [
            Expanded(
              // Branco, não verde: parar é a ação mais importante da tela sem
              // ser uma afirmação — e o verde aqui já está falando pela faixa
              // do microfone, dois centímetros acima.
              child: EgButton.neutralStrong(
                label: 'Parar e transcrever',
                expand: true,
                onPressed: _primary,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            EgIconButton(
              icon: state.isPaused ? EgIconData.play : EgIconData.pause,
              tooltip: state.isPaused ? 'Retomar' : 'Pausar',
              onPressed: state.isPaused ? _viewModel.resume : _viewModel.pause,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        // A promessa da casa, no único lugar do app em que o microfone está
        // ligado. É onde a dúvida existe.
        Text(
          'tudo processado neste Mac',
          textAlign: TextAlign.center,
          style: eg.text.footnote.copyWith(color: eg.colors.textQuaternary),
        ),
      ],
    );
  }

  /// A última frase que a transcrição ao vivo reconheceu.
  ///
  /// **A última, e não o que já se acumulou.** Ela é a prova de que o Echo está
  /// entendendo, e não um documento para acompanhar: ler a reunião enquanto ela
  /// acontece é o oposto de estar nela. O texto que vale sai do arquivo,
  /// depois.
  Widget _lastHeard(EchoRecorderState state) {
    final eg = context.eg;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: ShapeDecoration(
        color: eg.colors.surface,
        shape: EgSquircle.shape(eg.shapes.radiusCard, side: eg.edge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const EgSectionLabel('Última fala'),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '"${state.liveText.last}"',
            style: eg.text.bodyCompact,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
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
        Text('Antes de gravar', style: context.eg.text.panelTitle),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'O Echo grava duas faixas separadas: é assim que ele sabe quem '
          'falou.',
          style: context.eg.text.caption,
        ),
        const SizedBox(height: AppSpacing.xl),
        EchoPermissionRow(
          title: 'Microfone',
          detail: 'Grava a sua voz.',
          status: capabilities.microphone,
          onPressed: _viewModel.requestMicrophone,
        ),
        const SizedBox(height: AppSpacing.md),
        EchoPermissionRow(
          title: 'Gravação de Tela',
          detail: 'Dá acesso à fala das outras pessoas.',
          status: capabilities.screenRecording,
          onPressed: _viewModel.requestScreenRecording,
        ),
        // O macOS só entrega a captura de tela a um processo que subiu depois
        // da permissão. Sem este aviso, a pessoa liga a chave nos Ajustes,
        // volta, e encontra a mesma tela dizendo que falta permissão.
        if (capabilities.screenRecording == PermissionStatus.denied) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            'Depois de liberar nos Ajustes, encerre e abra o Evergreen: o '
            'macOS só entrega a captura a quem iniciou depois.',
            style: context.eg.text.caption,
          ),
        ],
      ],
    );
  }

  Widget _liveText(EchoRecorderState state) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.eg.colors.surface,
        borderRadius: context.eg.shapes.cardAll,
      ),
      child: Text(
        state.liveText.join(' '),
        style: context.eg.text.caption,
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
    EchoPhase.done => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: (state.lastMeeting?.isEmpty ?? false)
          ? [
              EgButton(
                label: 'Gravar de novo',
                expand: true,
                onPressed: _primary,
              ),
              const SizedBox(height: AppSpacing.sm),
              EgButton.secondary(
                label: 'Abrir no Hub',
                expand: true,
                onPressed: _openHub,
              ),
            ]
          : [
              EgButton(
                label: 'Abrir no Hub',
                expand: true,
                onPressed: _primary,
              ),
              const SizedBox(height: AppSpacing.sm),
              EgButton.secondary(
                label: 'Gravar de novo',
                expand: true,
                onPressed: _viewModel.reset,
              ),
            ],
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
      (state.lastMeeting?.isEmpty ?? false)
          ? 'Nenhuma fala'
          : 'Transcrição pronta',
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
    EchoPhase.idle => 'Sua voz e a reunião, em faixas separadas',
    EchoPhase.recording => 'Fechar o painel não para a gravação',
    EchoPhase.transcribing => 'Pode levar alguns minutos',
    EchoPhase.done =>
      (state.lastMeeting?.isEmpty ?? false)
          ? 'A gravação saiu muda — confira o microfone e a saída'
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
      if (state.isRecording) const EgHint(keys: ['⌘', '.'], label: 'descartar'),
    ],
    // Sempre só "fechar". Gravando, quem explica que a reunião continua é a
    // linha logo acima do botão — repetir aqui estourava a largura do painel e
    // cortava o `⌘. descartar` ao lado, que é a dica que ninguém adivinha.
    trailing: const EgHint(keys: ['esc'], label: 'fechar'),
  );

  String _primaryHint(EchoRecorderState state) => switch (state.phase) {
    EchoPhase.idle => 'gravar',
    EchoPhase.recording => 'parar',
    EchoPhase.done =>
      (state.lastMeeting?.isEmpty ?? false) ? 'gravar de novo' : 'abrir no Hub',
    EchoPhase.failed => 'voltar',
    EchoPhase.transcribing => '',
  };
}

/// O ponto de "gravando".
///
/// Não pisca: um ponto piscando num painel que fica aberto ao lado de uma
/// reunião é movimento periférico permanente, que é a coisa que mais tira a
/// atenção de quem está tentando prestar atenção em outra pessoa. Ele muda de
/// estado, não de brilho — cheio enquanto grava, vazado quando pausa.
class _RecordingDot extends StatelessWidget {
  const _RecordingDot({required this.isPaused});

  final bool isPaused;

  static const _size = 9.0;

  @override
  Widget build(BuildContext context) {
    final color = context.eg.colors.error;

    return SizedBox.square(
      dimension: _size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isPaused ? null : color,
          border: isPaused ? Border.all(color: color, width: 1.5) : null,
        ),
      ),
    );
  }
}
