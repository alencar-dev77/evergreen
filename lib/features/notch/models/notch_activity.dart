import 'package:flutter/foundation.dart';

import '../../../shared/utils/duration_format.dart';
import '../../echo/presentation/viewmodels/echo_recorder_state.dart';
import '../../focus/presentation/viewmodels/focus_timer_state.dart';
import '../../nest/presentation/viewmodels/nest_state.dart';
import 'notch_settings.dart';

/// Um botão da ilha do notch.
@immutable
class NotchAction {
  const NotchAction(this.id, this.label);

  static const pause = 'pause';
  static const resume = 'resume';
  static const stop = 'stop';

  /// Clicar na ilha fora dos botões: abre o painel do módulo.
  static const open = 'open';

  final String id;
  final String label;

  Map<String, Object?> toMap() => {'id': id, 'label': label};

  @override
  bool operator ==(Object other) =>
      other is NotchAction && other.id == id && other.label == label;

  @override
  int get hashCode => Object.hash(id, label);
}

/// O que a ilha do notch mostra de um módulo que está rodando.
///
/// **O Dart decide o quê; o Swift só desenha.** O rótulo, o relógio já
/// formatado e os botões saem daqui, prontos: o texto da interface continua
/// morando num lugar só, e o lado nativo (`NotchIsland.swift`) não sabe o que é
/// uma reunião nem uma sessão de foco.
///
/// Igualdade por valor de propósito: o Focus bate quatro vezes por segundo e o
/// Echo mede o som dez, e quem empurra para o canal só empurra o que mudou.
@immutable
class NotchActivity {
  const NotchActivity._({
    required this.module,
    required this.title,
    required this.clock,
    required this.actions,
    required this.isPaused,
    this.detail = '',
    this.isRecording = false,
    this.progress = 0,
    this.isRest = false,
    this.isShelf = false,
    this.mic = const [],
    this.system = const [],
    this.transcript,
  });

  /// Os rótulos do modo preso da ilha, que o lado nativo usa no botão que ele
  /// mesmo desenha.
  static const _transcriptLabels = {
    'show': 'Transcrição',
    'hide': 'Recolher',
    'empty': 'Ouvindo…',
  };

  /// Quantos trechos vão para a ilha presa. Três linhas cabem lá; um trecho a
  /// mais é o que sobe e se apaga no degradê do topo.
  static const transcriptSegments = 4;

  /// A reunião que está sendo gravada, ou `null` quando não há.
  ///
  /// Só gravando — pausada inclusive. Transcrevendo já não: a reunião acabou, e
  /// a ilha é sobre o que está acontecendo agora.
  static NotchActivity? echo(EchoRecorderState state) {
    if (!state.isRecording) return null;

    final paused = state.isPaused;
    final spectrum = paused ? null : state.spectrum;

    return NotchActivity._(
      module: NotchModule.echo,
      isRecording: true,
      isPaused: paused,
      title: paused ? 'Pausado' : 'Gravando',
      detail: 'Echo',
      clock: state.menuBarLabel ?? '',
      mic: _rounded(spectrum?.mic),
      system: _rounded(spectrum?.system),
      // Só quando a gravação transcreve ao vivo: sem isso a ilha não oferece
      // o botão, e não há o que prender.
      transcript: state.isTranscribingLive
          ? _latest(state.liveText, transcriptSegments)
          : null,
      actions: [
        paused
            ? const NotchAction(NotchAction.resume, 'Retomar')
            : const NotchAction(NotchAction.pause, 'Pausar'),
        const NotchAction(NotchAction.stop, 'Parar'),
      ],
    );
  }

  /// A sessão do Focus em andamento, ou `null` quando não há.
  ///
  /// Contando ou pausada. Concluída não: quem decide o que vem depois é o
  /// painel, e a notificação já avisou.
  static NotchActivity? focus(FocusTimerState state) {
    if (!state.isActive) return null;

    final paused = state.isPaused;
    final rest = !state.phase.isFocus;

    return NotchActivity._(
      module: NotchModule.focus,
      isPaused: paused,
      isRest: rest,
      title: paused ? 'Pausado' : (rest ? 'Pausa' : 'Foco'),
      detail: state.activity.trim(),
      clock: DurationFormat.countdown(state.remaining),
      // Em duzentos degraus: o anel da asa tem 12 pontos, e mais que isso é
      // mandar pelo canal uma mudança que não acende pixel nenhum.
      progress: (state.progress * 200).round() / 200,
      actions: [
        paused
            ? const NotchAction(NotchAction.resume, 'Retomar')
            : const NotchAction(NotchAction.pause, 'Pausar'),
        const NotchAction(NotchAction.stop, 'Encerrar'),
      ],
    );
  }

  /// A pilha do Nest esperando para ser mandada, ou `null` sem arquivo.
  ///
  /// [onScreen] é o painel do Nest à vista: com ele aberto, a ilha não repete
  /// o que está logo embaixo dela. Fechar o painel com arquivos é o que traz a
  /// pilha de volta para o notch — por qualquer caminho, Esc, mouse saindo ou
  /// atalho, sem caso especial para nenhum.
  static NotchActivity? nest(NestState state, {required bool onScreen}) {
    if (state.isEmpty || onScreen) return null;

    final count = state.items.length;

    return NotchActivity._(
      module: NotchModule.nest,
      isShelf: true,
      isPaused: false,
      title: 'Nest',
      detail: count == 1 ? '1 arquivo' : '$count arquivos',
      clock: '$count',
      actions: const [],
    );
  }

  /// Tudo o que está rodando, na ordem em que a ilha prefere mostrar.
  ///
  /// **A reunião ganha de tudo, e a pilha ganha do foco.** A ilha mostra uma
  /// coisa só — duas dividindo as asas não caberiam, e um relógio de cada lado
  /// não diria qual é qual. Uma gravação esquecida rodando é o erro que custa
  /// mais caro. A pilha vem antes do foco porque é curta (vai ser mandada em
  /// seguida) e precisa ser vista; a sessão de foco dura 25 minutos e aguenta
  /// ceder a vez.
  ///
  /// A lista vai inteira para o lado nativo, e não só o primeiro: quem
  /// desligou o Echo no notch ainda quer ver o resto quando tudo está de pé, e
  /// quem sabe o que está ligado no notch é o lado nativo (o Hub o avisa
  /// direto).
  static List<NotchActivity> running({
    required EchoRecorderState echo,
    required FocusTimerState focus,
    NestState? nest,
    bool nestOnScreen = false,
  }) => [
    ?NotchActivity.echo(echo),
    if (nest != null) ?NotchActivity.nest(nest, onScreen: nestOnScreen),
    ?NotchActivity.focus(focus),
  ];

  final NotchModule module;
  final String title;

  /// O que vem ao lado do título, mais apagado: o módulo, ou a atividade do
  /// foco.
  final String detail;
  final String clock;
  final List<NotchAction> actions;
  final bool isPaused;

  /// O ponto de gravação, em vez do anel de progresso.
  final bool isRecording;

  /// Quanto da fase do Focus já passou, de 0 a 1.
  final double progress;

  /// A fase é a pausa do ciclo, não o foco.
  final bool isRest;

  /// A bandeja do Nest, em vez do ponto ou do anel. O mouse em cima pede o
  /// painel do Nest, em vez de abrir a ilha (`opensOnHover`).
  final bool isShelf;

  /// As bandas do equalizador do Echo, uma lista por faixa.
  final List<double> mic;
  final List<double> system;

  /// O texto ao vivo da reunião, do trecho mais antigo ao mais novo, ou `null`
  /// quando a gravação não transcreve ao vivo.
  final List<String>? transcript;

  Map<String, Object?> toMap() => {
    'module': module.id,
    'indicator': isShelf
        ? 'shelf'
        : isRecording
        ? 'recording'
        : 'progress',
    'opensOnHover': isShelf,
    'paused': isPaused,
    'progress': progress,
    'rest': isRest,
    'title': title,
    'detail': detail,
    'clock': clock,
    'mic': mic,
    'system': system,
    'actions': [for (final action in actions) action.toMap()],
    'transcript': transcript,
    'transcriptLabels': _transcriptLabels,
  };

  static List<String> _latest(List<String> segments, int count) =>
      segments.length > count
      ? segments.sublist(segments.length - count)
      : segments;

  /// Duas casas bastam para uma barra de dezoito pontos, e mudar menos é
  /// mandar menos pelo canal.
  static List<double> _rounded(List<double>? bands) => [
    for (final band in bands ?? const <double>[]) (band * 100).round() / 100,
  ];

  @override
  bool operator ==(Object other) =>
      other is NotchActivity &&
      other.module == module &&
      other.title == title &&
      other.detail == detail &&
      other.clock == clock &&
      other.isPaused == isPaused &&
      other.isRecording == isRecording &&
      other.progress == progress &&
      other.isRest == isRest &&
      other.isShelf == isShelf &&
      listEquals(other.actions, actions) &&
      listEquals(other.mic, mic) &&
      listEquals(other.system, system) &&
      listEquals(other.transcript, transcript);

  @override
  int get hashCode => Object.hash(
    module,
    title,
    detail,
    clock,
    isPaused,
    isRecording,
    progress,
    isRest,
    isShelf,
    Object.hashAll(actions),
    Object.hashAll(mic),
    Object.hashAll(system),
    transcript == null ? null : Object.hashAll(transcript!),
  );
}
