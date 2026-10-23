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

  /// Alguma coisa falhou. O áudio cru não fica guardado: a varredura da
  /// abertura seguinte o apaga.
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
    this.isStarting = false,
    this.isSeparatingVoices = false,
    this.isTranscribingLive = false,
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

  /// O `start` foi pedido e o lado nativo ainda não respondeu.
  ///
  /// Uma bandeira, e não uma fase: quem lê a fase (o painel, a ilha do notch,
  /// a espera da atualização) não tem nada a mostrar de diferente nesse
  /// intervalo. Ela existe para o segundo pedido ser recusado — e conta como
  /// [isBusy].
  final bool isStarting;

  /// A transcrição saiu, e agora é a vez de separar as vozes do outro lado.
  ///
  /// É a etapa que pode surpreender: na primeira reunião ela baixa o modelo,
  /// e o painel parado em "Transcrevendo" por um minuto a mais pareceria
  /// travado. Dizer o que está acontecendo é o que faz a espera ser espera.
  final bool isSeparatingVoices;

  /// Esta gravação transcreve ao vivo.
  ///
  /// Decidido no começo da gravação, e não lido da preferência: quem liga
  /// "Transcrever ao vivo" no meio da reunião não ganha texto nela — o lado
  /// nativo só transcreve o que foi pedido no `start`. É o que a ilha do notch
  /// pergunta antes de oferecer a transcrição.
  final bool isTranscribingLive;

  /// A reunião recém-transcrita, para o painel oferecer o caminho até ela.
  final Meeting? lastMeeting;

  final String? errorMessage;

  bool get isRecording => phase == EchoPhase.recording;

  /// Gravando e correndo — o único estado em que o medidor diz alguma coisa.
  bool get isCapturing => isRecording && !isPaused;
  bool get isBusy => phase == EchoPhase.transcribing || isStarting;

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
    bool? isStarting,
    bool? isSeparatingVoices,
    bool? isTranscribingLive,
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
      isStarting: isStarting ?? this.isStarting,
      isSeparatingVoices: isSeparatingVoices ?? this.isSeparatingVoices,
      isTranscribingLive: isTranscribingLive ?? this.isTranscribingLive,
      lastMeeting: clearMeeting ? null : (lastMeeting ?? this.lastMeeting),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
