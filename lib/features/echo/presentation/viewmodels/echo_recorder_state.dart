import '../../models/echo_capabilities.dart';
import '../../models/echo_spectrum.dart';
import '../../models/meeting.dart';

/// Em que ponto da reunião o painel está.
enum EchoPhase {
  /// Nada acontecendo — a tela de começar.
  idle,

  /// Gravando. É o estado que precisa sobreviver ao painel fechado.
  recording,

  /// Parou e está transcrevendo. Pode levar de segundos a alguns minutos.
  transcribing,

  /// Transcrição pronta e salva.
  done,

  /// Alguma coisa falhou. O áudio, quando existe, foi preservado.
  failed,
}

class EchoRecorderState {
  const EchoRecorderState({
    this.phase = EchoPhase.idle,
    this.capabilities = const EchoCapabilities(),
    this.elapsed = Duration.zero,
    this.liveText = const [],
    this.spectrum,
    this.isPaused = false,
    this.isSeparatingVoices = false,
    this.lastMeeting,
    this.errorMessage,
  });

  final EchoPhase phase;
  final EchoCapabilities capabilities;

  /// Quanto tempo de reunião já foi gravado.
  final Duration elapsed;

  /// O que a transcrição ao vivo reconheceu até agora, quando ela está ligada.
  ///
  /// Não é o resultado final e não é guardado: serve para a pessoa ver que o
  /// Echo está ouvindo. O texto que vale sai do arquivo, depois.
  final List<String> liveText;

  /// O que está entrando agora, por banda de frequência.
  ///
  /// Só o instante, e não uma fila de instantes: é um equalizador, e um
  /// equalizador mostra agora. `null` quando não há gravação correndo.
  final EchoSpectrum? spectrum;

  /// A gravação está de pé, porém suspensa: nada entra no arquivo enquanto
  /// isto valer, e o relógio não anda.
  final bool isPaused;

  /// A transcrição saiu, e agora é a vez de separar as vozes do outro lado.
  ///
  /// É a etapa que pode surpreender: na primeira reunião ela baixa o modelo,
  /// e o painel parado em "Transcrevendo" por um minuto a mais pareceria
  /// travado. Dizer o que está acontecendo é o que faz a espera ser espera.
  final bool isSeparatingVoices;

  /// A reunião recém-transcrita, para o painel oferecer o caminho até ela.
  final Meeting? lastMeeting;

  final String? errorMessage;

  bool get isRecording => phase == EchoPhase.recording;

  /// Gravando e correndo — o único estado em que o medidor diz alguma coisa.
  bool get isCapturing => isRecording && !isPaused;
  bool get isBusy => phase == EchoPhase.transcribing;

  /// O rótulo que a barra de menus mostra enquanto a reunião corre.
  ///
  /// `null` quando não há gravação — é onde o Echo some da barra.
  String? get menuBarLabel {
    if (!isRecording) return null;

    final minutes = elapsed.inMinutes;
    final seconds = elapsed.inSeconds % 60;

    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  EchoRecorderState copyWith({
    EchoPhase? phase,
    EchoCapabilities? capabilities,
    Duration? elapsed,
    List<String>? liveText,
    EchoSpectrum? spectrum,
    bool? isPaused,
    bool? isSeparatingVoices,
    bool clearSpectrum = false,
    Meeting? lastMeeting,
    String? errorMessage,
    bool clearError = false,
    bool clearMeeting = false,
  }) {
    return EchoRecorderState(
      phase: phase ?? this.phase,
      capabilities: capabilities ?? this.capabilities,
      elapsed: elapsed ?? this.elapsed,
      liveText: liveText ?? this.liveText,
      spectrum: clearSpectrum ? null : (spectrum ?? this.spectrum),
      isPaused: isPaused ?? this.isPaused,
      isSeparatingVoices: isSeparatingVoices ?? this.isSeparatingVoices,
      lastMeeting: clearMeeting ? null : (lastMeeting ?? this.lastMeeting),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
