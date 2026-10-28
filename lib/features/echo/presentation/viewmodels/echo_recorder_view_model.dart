import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../core/diagnostics/app_log.dart';
import '../../data/echo_audio_store.dart';
import '../../data/echo_channel.dart';
import '../../data/echo_repository.dart';
import '../../data/echo_settings_repository.dart';
import '../../models/cross_talk_filter.dart';
import '../../models/echo_capabilities.dart';
import '../../models/echo_spectrum.dart';
import '../../models/meeting.dart';
import '../../models/meeting_segment.dart';
import '../../models/vocabulary_correction.dart';
import '../../models/voice_separation.dart';
import 'echo_recorder_state.dart';

final echoRecorderViewModelProvider =
    NotifierProvider<EchoRecorderViewModel, EchoRecorderState>(
      EchoRecorderViewModel.new,
    );

/// A gravação da reunião.
///
/// Vive no engine da janela flutuante, como o cronômetro do Focus e a trava do
/// Awake — e aqui isso é essencial, não conveniente: a reunião continua sendo
/// gravada com o painel fechado, que é o caso normal. Ninguém fica olhando um
/// painel por trinta minutos.
class EchoRecorderViewModel extends Notifier<EchoRecorderState> {
  late final EchoChannel _channel;
  late final EchoRepository _repository;
  late final EchoSettingsRepository _settings;
  late final EchoAudioStore _audio;
  late final EchoAudioJanitor _janitor;
  late final DateTime Function() _now;

  Timer? _ticker;
  StreamSubscription<String>? _liveSubscription;
  StreamSubscription<EchoSpectrum>? _levelSubscription;
  DateTime? _startedAt;

  /// Quanto tempo esta gravação passou pausada — sai da conta do relógio, como
  /// sai da conta do arquivo do lado nativo.
  Duration _paused = Duration.zero;
  DateTime? _pausedAt;

  /// Um `pause` ou `resume` já foi pedido ao lado nativo e ainda não voltou.
  ///
  /// Síncrono pelo mesmo motivo do [EchoRecorderState.isStarting]: o
  /// `isPaused` só vira depois do `await`, e um segundo clique nesse intervalo
  /// pedia de novo a pausa que já estava valendo — e voltava com "nenhuma
  /// gravação em andamento para pausar" por cima de uma gravação viva.
  bool _toggling = false;

  /// O `start` em curso, para quem precisa parar uma gravação que ainda está
  /// subindo — desligar o Echo no Hub enquanto o macOS pergunta pela Gravação
  /// de Tela, por exemplo. Sem esperar, a reunião começava depois com o
  /// módulo já desligado.
  Completer<void>? _starting;

  @override
  EchoRecorderState build() {
    _channel = ref.watch(echoChannelProvider);
    _repository = ref.watch(echoRepositoryProvider);
    _settings = ref.watch(echoSettingsRepositoryProvider);
    _audio = ref.watch(echoAudioStoreProvider);
    _janitor = ref.watch(echoAudioJanitorProvider);
    _now = ref.watch(clockProvider);

    ref.onDispose(() {
      _ticker?.cancel();
      _liveSubscription?.cancel();
      _levelSubscription?.cancel();
    });

    return const EchoRecorderState();
  }

  /// Limpa áudio órfão de uma queda anterior, apaga o áudio de reunião que
  /// venceu e liga a escuta do ao vivo. Chamado uma vez, na inicialização do
  /// app.
  Future<void> initialize() async {
    _channel.listen();
    _liveSubscription ??= _channel.onLiveSegment.listen(_onLiveSegment);
    _levelSubscription ??= _channel.onLevels.listen(_onSpectrum);

    // Aqui, e não num relógio de fundo: o Evergreen abre todo dia, e um áudio
    // que vence às três da tarde pode muito bem sair na abertura seguinte.
    _sweepAudio();

    try {
      await _channel.cleanOrphanAudio();
    } on EchoException {
      // Sem lado nativo (ou macOS antigo): não há áudio órfão para varrer.
    }
  }

  /// Relê o que a máquina permite antes de o painel aparecer.
  ///
  /// As permissões podem ter sido concedidas ou revogadas nos Ajustes desde a
  /// última vez, e o painel não pode oferecer gravar o que o sistema recusa.
  Future<void> prepareForOpen() async {
    if (state.isRecording || state.isBusy) return;

    // Uma reunião já encerrada não pode continuar ocupando o painel: quem
    // aperta `⌘⇧E` de novo está pedindo a próxima gravação, não relendo o
    // desfecho da anterior — esse mora no Hub. Sem isto o painel virava um beco
    // sem saída, e a única forma de gravar de novo era reiniciar o app.
    if (state.phase == EchoPhase.done || state.phase == EchoPhase.failed) {
      reset();
    }

    await _refreshCapabilities();
  }

  Future<void> _refreshCapabilities() async {
    try {
      state = state.copyWith(capabilities: await _channel.capabilities());
    } on EchoException catch (error) {
      state = state.copyWith(errorMessage: error.message);
    }
  }

  Future<void> requestMicrophone() => _request(_channel.requestMicrophone);

  Future<void> requestScreenRecording() =>
      _request(_channel.requestScreenRecording);

  Future<void> _request(Future<EchoCapabilities> Function() ask) async {
    try {
      state = state.copyWith(capabilities: await ask(), clearError: true);
    } on EchoException catch (error) {
      state = state.copyWith(errorMessage: error.message);
    }
  }

  /// Começa a gravar.
  ///
  /// O [EchoRecorderState.isStarting] é marcado **antes do primeiro `await`**:
  /// a fase só vira `recording` depois de o lado nativo responder, e um Enter
  /// repetido nesse intervalo pedia uma segunda gravação — que voltava
  /// `already_recording` e jogava a fase para `failed` por cima da primeira,
  /// ainda viva.
  Future<void> start() async {
    if (state.isRecording || state.isBusy) return;

    state = state.copyWith(isStarting: true);
    final starting = _starting = Completer<void>();

    try {
      // As preferências vivem no Hub, em outro engine: sem reler, a gravação
      // sai com o idioma e o modo de ontem.
      await _settings.reload();
      final settings = _settings.load();

      try {
        await _channel.startRecording(
          liveTranscription: settings.liveTranscription,
          locale: settings.language.locale,
          vocabulary: settings.vocabularyTerms,
        );
      } on EchoException catch (error) {
        state = state.copyWith(
          phase: EchoPhase.failed,
          errorMessage: error.message,
          isStarting: false,
        );
        return;
      }

      _begin(settings.liveTranscription);
    } finally {
      if (state.isStarting) state = state.copyWith(isStarting: false);
      _starting = null;
      starting.complete();
    }
  }

  void _begin(bool liveTranscription) {
    _startedAt = _now();
    _paused = Duration.zero;
    _pausedAt = null;
    state = state.copyWith(
      phase: EchoPhase.recording,
      elapsed: Duration.zero,
      liveText: const [],
      isTranscribingLive: liveTranscription,
      isPaused: false,
      isStarting: false,
      clearSpectrum: true,
      clearError: true,
      clearMeeting: true,
    );

    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final startedAt = _startedAt;
    if (startedAt == null || !state.isCapturing) return;

    state = state.copyWith(elapsed: _now().difference(startedAt) - _paused);
  }

  /// Suspende a gravação. O que passa daqui até o `resume` não entra no
  /// arquivo, não entra na duração e não move o relógio do painel.
  Future<void> pause() async {
    if (!state.isCapturing || _toggling) return;

    _toggling = true;
    try {
      await _channel.pauseRecording();
    } on EchoException catch (error) {
      state = state.copyWith(errorMessage: error.message);
      return;
    } finally {
      _toggling = false;
    }

    // A gravação pode ter terminado durante a espera.
    if (!state.isRecording) return;

    _pausedAt = _now();
    // O equalizador zera junto: parado, ele não tem o que medir, e barras
    // congeladas na última medida diriam que ainda está entrando som.
    state = state.copyWith(isPaused: true, clearSpectrum: true);
  }

  Future<void> resume() async {
    if (!state.isRecording || !state.isPaused || _toggling) return;

    _toggling = true;
    try {
      await _channel.resumeRecording();
    } on EchoException catch (error) {
      state = state.copyWith(errorMessage: error.message);
      return;
    } finally {
      _toggling = false;
    }

    if (!state.isRecording) return;

    final since = _pausedAt;
    if (since != null) _paused += _now().difference(since);
    _pausedAt = null;
    state = state.copyWith(isPaused: false);
  }

  void _onSpectrum(EchoSpectrum spectrum) {
    if (!state.isCapturing) return;

    state = state.copyWith(spectrum: spectrum);
  }

  void _onLiveSegment(String text) {
    if (!state.isRecording) return;

    // Só os últimos trechos: o painel é pequeno, e o texto ao vivo é sinal de
    // que o Echo está ouvindo, não um documento para ler ali.
    final updated = [...state.liveText, text];
    state = state.copyWith(
      liveText: updated.length > 6
          ? updated.sublist(updated.length - 6)
          : updated,
    );
  }

  /// Para de gravar, transcreve e guarda.
  ///
  /// O áudio só é apagado depois de a transcrição estar no banco. Se qualquer
  /// coisa falhar antes disso, ele fica onde está — apagar aqui transformaria
  /// "a transcrição deu errado" em "a reunião se perdeu".
  ///
  /// Com um início ainda sem resposta, espera por ele: é o que faz desligar o
  /// módulo nesse intervalo parar a gravação que estava subindo.
  Future<void> stopAndTranscribe() async {
    await _starting?.future;
    if (!state.isRecording) return;

    _ticker?.cancel();
    _ticker = null;

    state = state.copyWith(phase: EchoPhase.transcribing);

    final settings = _settings.load();
    RecordingFiles? files;

    // A reunião já no banco. O que falhar depois dela — aparar o histórico,
    // arquivar o áudio, apagar as faixas cruas — não desfaz a reunião, e a
    // tela não pode dizer que ela não saiu.
    Meeting? inserted;

    try {
      files = await _channel.stopRecording();

      // Com a reunião saindo por alto-falante, o microfone escuta de volta o
      // que o computador toca, e a mesma fala aparece nas duas faixas. O filtro
      // devolve a separação de quem falou, que é a razão de existir do módulo.
      //
      // As trocas do vocabulário vêm depois do filtro: ele compara o texto
      // das duas faixas como o modelo o ouviu, e uma troca aplicada só de um
      // lado esconderia o eco dele.
      //
      // As vozes entram entre os dois: depois do filtro, para não pintar um
      // eco que vai sair; antes do vocabulário, porque partir um trecho no
      // meio de uma troca de pessoa é decisão do relógio das palavras, e a
      // troca do vocabulário pode fundir duas delas numa.
      //
      // O eco já saiu do som no `stop` (`EchoCanceller`); o filtro de texto é
      // a rede para o que escapou. Quando o som respondeu que não havia eco,
      // não há o que procurar.
      final heard = await _channel.transcribe(
        files: files,
        locale: settings.language.locale,
        vocabulary: settings.vocabularyTerms,
      );
      final transcribed = files.echoFound == false
          ? heard
          : CrossTalkFilter.clean(heard);
      final segments = VocabularyCorrection.apply(
        await _separateVoices(transcribed, files),
        settings.vocabularyCorrections,
      );

      final startedAt = _startedAt ?? _now();
      final meeting = inserted = _repository.insert(
        Meeting(
          title: Meeting.defaultTitle(startedAt),
          startedAt: startedAt,
          durationMs: files.durationMs,
          language: settings.language,
          segments: segments,
        ),
      );

      _repository.trimHistory(settings.historyLimit);

      // Só agora: o texto está salvo, e as faixas cruas viram andaime — o que
      // fica para ouvir é a cópia comprimida, com 1/15 do tamanho.
      //
      // Menos quando não saiu texto nenhum. Transcrição vazia é falha na
      // prática — apagar o áudio ali seria jogar fora a única cópia do que foi
      // dito, por causa de um problema que pode ser de permissão, de saída de
      // som ou do próprio reconhecimento. Fica em disco até a varredura do
      // próximo início — e só até lá: não há retranscrição, então a tela não
      // pode prometer que ele foi guardado.
      var saved = meeting;
      if (segments.isNotEmpty) {
        saved = await _archive(meeting, files, startedAt);
        await _channel.deleteAudio(files.paths);
      }

      // A limpeza do teto pode ter levado uma reunião antiga, e o áudio dela
      // ficou sem dono.
      _sweepAudio();

      _startedAt = null;

      // Reunião vazia não é sucesso silencioso. Quando dá para dizer o que
      // faltou — uma faixa que não gravou, a captura interrompida pelo sistema
      // — a tela diz, em vez de mostrar uma transcrição muda e deixar a pessoa
      // adivinhar entre permissão, entrada de som e reconhecimento.
      final explanation = segments.isEmpty ? files.silenceExplanation : null;

      // Transcreveu, mas faltou uma das faixas: a reunião valeu, e ainda assim
      // a tela precisa dizer que metade da conversa não está ali.
      final warning = explanation ?? files.halfSilenceWarning;

      state = state.copyWith(
        phase: explanation == null ? EchoPhase.done : EchoPhase.failed,
        lastMeeting: saved,
        // `clearError`, e não `errorMessage: null`: o `copyWith` trata `null`
        // como "não mexe", então a explicação da reunião anterior sobreviveria
        // a uma gravação que deu certo.
        clearError: warning == null,
        errorMessage: warning,
      );
    } on EchoException catch (error) {
      _startedAt = null;
      if (inserted != null) return _savedDespite(inserted);
      state = state.copyWith(
        phase: EchoPhase.failed,
        // Dizia "o áudio foi preservado em disco", e não era verdade: a
        // varredura da abertura seguinte apaga as faixas cruas, e nenhum
        // caminho as transcreve de novo.
        errorMessage: files == null ? error.message : '${error.message}$_lost',
      );
    } on Object catch (error, stack) {
      // Qualquer outra coisa — o banco, o disco, um formato inesperado do
      // canal — prendia a fase em `transcribing`: o painel girando para
      // sempre, e o `⌘⇧E` sem gravar de novo porque `isBusy` continuava de pé.
      // O registro leva só o tipo do erro, pelo `AppLog.describe`.
      AppLog.error('echo.stop', error, stack);
      _startedAt = null;
      if (inserted != null) return _savedDespite(inserted);
      state = state.copyWith(
        phase: EchoPhase.failed,
        errorMessage: 'Não foi possível transcrever esta reunião.$_lost',
      );
    }
  }

  /// A reunião foi guardada, e o que falhou foi a arrumação depois dela.
  void _savedDespite(Meeting meeting) {
    state = state.copyWith(
      phase: EchoPhase.done,
      lastMeeting: _repository.findById(meeting.id!) ?? meeting,
      clearError: true,
    );
  }

  /// O que a tela diz do áudio quando a reunião não saiu: a verdade.
  static const _lost = ' O áudio desta gravação não fica guardado.';

  /// As vozes do outro lado, separadas — ou a transcrição como veio.
  ///
  /// Separar é enfeite sobre um texto que já está pronto, e por isso nunca
  /// derruba a reunião: sem rede para baixar o modelo na primeira vez, ou com
  /// o modelo falhando, a transcrição é guardada exatamente como era antes de
  /// o Echo separar vozes, com o outro lado inteiro em "Reunião". Não há aviso
  /// — a reunião deu certo, e um erro de um detalhe dela não é notícia.
  ///
  /// Não pergunta quando não há o que separar: sem faixa do computador, ou
  /// sem fala nela.
  ///
  /// E não espera para sempre. Sem rede, o download do modelo desiste em
  /// segundos; com uma rede que responde devagar, ele pode ficar minutos
  /// tentando, e a reunião não pode ficar presa em "Transcrevendo" por isso.
  /// Passado o [_voicesTimeout], a reunião sai sem vozes. O lado nativo
  /// continua baixando, e a próxima reunião já encontra o modelo pronto.
  static const _voicesTimeout = Duration(minutes: 3);

  Future<List<MeetingSegment>> _separateVoices(
    List<MeetingSegment> segments,
    RecordingFiles files,
  ) async {
    final systemPath = files.systemPath;
    final hasOthers = segments.any(
      (segment) => segment.speaker == Speaker.others,
    );
    if (systemPath == null || !hasOthers) return segments;

    state = state.copyWith(isSeparatingVoices: true);
    try {
      return VoiceSeparation.apply(
        segments,
        await _channel.diarize(systemPath).timeout(_voicesTimeout),
      );
    } on EchoException {
      return segments;
    } on TimeoutException {
      return segments;
    } finally {
      state = state.copyWith(isSeparatingVoices: false);
    }
  }

  /// Guarda a cópia para ouvir e liga a reunião a ela.
  ///
  /// Falhar aqui não é falhar a reunião: o texto já está salvo, e uma reunião
  /// sem player é o que todas eram até esta versão. A tela só não oferece o
  /// play.
  Future<Meeting> _archive(
    Meeting meeting,
    RecordingFiles files,
    DateTime startedAt,
  ) async {
    final fileName = 'reuniao-${startedAt.millisecondsSinceEpoch}.m4a';

    try {
      final durationMs = await _channel.archiveAudio(
        files: files,
        destination: _audio.pathOf(fileName),
      );
      if (durationMs == null) return meeting;
    } on EchoException {
      return meeting;
    }

    _repository.setAudioFile(meeting.id!, fileName);
    return meeting.copyWith(audioFile: fileName);
  }

  /// O disco é enfeite aqui também: uma varredura que falha não pode derrubar
  /// a abertura do app nem a reunião que acabou de ser salva.
  void _sweepAudio() {
    try {
      _janitor.sweep(_now());
    } on FileSystemException {
      // Tenta de novo na próxima.
    }
  }

  /// Desiste da gravação e joga o áudio fora.
  Future<void> cancel() async {
    if (!state.isRecording) return;

    _ticker?.cancel();
    _ticker = null;
    _startedAt = null;

    try {
      await _channel.cancelRecording();
    } on EchoException {
      // Nada a fazer: já estamos desistindo.
    }

    state = state.copyWith(
      phase: EchoPhase.idle,
      elapsed: Duration.zero,
      liveText: const [],
      clearError: true,
    );
  }

  /// Volta o painel para o começo depois de uma reunião concluída.
  void reset() {
    state = state.copyWith(
      phase: EchoPhase.idle,
      elapsed: Duration.zero,
      liveText: const [],
      clearError: true,
      clearMeeting: true,
    );
  }
}
