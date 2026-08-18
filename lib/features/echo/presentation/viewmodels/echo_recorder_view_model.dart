import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../data/echo_channel.dart';
import '../../data/echo_repository.dart';
import '../../data/echo_settings_repository.dart';
import '../../models/cross_talk_filter.dart';
import '../../models/echo_capabilities.dart';
import '../../models/meeting.dart';
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
  late final DateTime Function() _now;

  Timer? _ticker;
  StreamSubscription<String>? _liveSubscription;
  DateTime? _startedAt;

  @override
  EchoRecorderState build() {
    _channel = ref.watch(echoChannelProvider);
    _repository = ref.watch(echoRepositoryProvider);
    _settings = ref.watch(echoSettingsRepositoryProvider);
    _now = ref.watch(clockProvider);

    ref.onDispose(() {
      _ticker?.cancel();
      _liveSubscription?.cancel();
    });

    return const EchoRecorderState();
  }

  /// Limpa áudio órfão de uma queda anterior e liga a escuta do ao vivo.
  /// Chamado uma vez, na inicialização do app.
  Future<void> initialize() async {
    _channel.listen();
    _liveSubscription ??= _channel.onLiveSegment.listen(_onLiveSegment);

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
  Future<void> start() async {
    if (state.isRecording || state.isBusy) return;

    // As preferências vivem no Hub, em outro engine: sem reler, a gravação sai
    // com o idioma e o modo de ontem.
    await _settings.reload();
    final settings = _settings.load();

    try {
      await _channel.startRecording(
        liveTranscription: settings.liveTranscription,
        locale: settings.language.locale,
      );
    } on EchoException catch (error) {
      state = state.copyWith(phase: EchoPhase.failed, errorMessage: error.message);
      return;
    }

    _startedAt = _now();
    state = state.copyWith(
      phase: EchoPhase.recording,
      elapsed: Duration.zero,
      liveText: const [],
      clearError: true,
      clearMeeting: true,
    );

    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final startedAt = _startedAt;
    if (startedAt == null || !state.isRecording) return;

    state = state.copyWith(elapsed: _now().difference(startedAt));
  }

  void _onLiveSegment(String text) {
    if (!state.isRecording) return;

    // Só os últimos trechos: o painel é pequeno, e o texto ao vivo é sinal de
    // que o Echo está ouvindo, não um documento para ler ali.
    final updated = [...state.liveText, text];
    state = state.copyWith(
      liveText: updated.length > 6 ? updated.sublist(updated.length - 6) : updated,
    );
  }

  /// Para de gravar, transcreve e guarda.
  ///
  /// O áudio só é apagado depois de a transcrição estar no banco. Se qualquer
  /// coisa falhar antes disso, ele fica onde está — apagar aqui transformaria
  /// "a transcrição deu errado" em "a reunião se perdeu".
  Future<void> stopAndTranscribe() async {
    if (!state.isRecording) return;

    _ticker?.cancel();
    _ticker = null;

    state = state.copyWith(phase: EchoPhase.transcribing);

    final settings = _settings.load();
    RecordingFiles? files;

    try {
      files = await _channel.stopRecording();

      // Com a reunião saindo por alto-falante, o microfone escuta de volta o
      // que o computador toca, e a mesma fala aparece nas duas faixas. O filtro
      // devolve a separação de quem falou, que é a razão de existir do módulo.
      final segments = CrossTalkFilter.clean(
        await _channel.transcribe(
          files: files,
          locale: settings.language.locale,
        ),
      );

      final startedAt = _startedAt ?? _now();
      final meeting = _repository.insert(
        Meeting(
          title: _defaultTitle(startedAt),
          startedAt: startedAt,
          durationMs: files.durationMs,
          language: settings.language,
          segments: segments,
        ),
      );

      _repository.trimHistory(settings.historyLimit);

      // Só agora: o texto está salvo, o áudio virou andaime.
      //
      // Menos quando não saiu texto nenhum. Transcrição vazia é falha na
      // prática — apagar o áudio ali seria jogar fora a única cópia do que foi
      // dito, por causa de um problema que pode ser de permissão, de saída de
      // som ou do próprio reconhecimento. Fica em disco, e a varredura do
      // próximo início limpa se a pessoa não fizer nada.
      if (segments.isNotEmpty) await _channel.deleteAudio(files.paths);

      _startedAt = null;

      // Reunião vazia não é sucesso silencioso. Quando dá para dizer o que
      // faltou — uma faixa que não gravou, a captura interrompida pelo sistema
      // — a tela diz, em vez de mostrar uma transcrição muda e deixar a pessoa
      // adivinhar entre permissão, entrada de som e reconhecimento.
      final explanation =
          segments.isEmpty ? files.silenceExplanation : null;

      // Transcreveu, mas faltou uma das faixas: a reunião valeu, e ainda assim
      // a tela precisa dizer que metade da conversa não está ali.
      final warning = explanation ?? files.halfSilenceWarning;

      state = state.copyWith(
        phase: explanation == null ? EchoPhase.done : EchoPhase.failed,
        lastMeeting: meeting,
        // `clearError`, e não `errorMessage: null`: o `copyWith` trata `null`
        // como "não mexe", então a explicação da reunião anterior sobreviveria
        // a uma gravação que deu certo.
        clearError: warning == null,
        errorMessage: switch (warning) {
          null => null,
          // Só o caso de falha guarda o áudio; o aviso de meia faixa não, e
          // prometer um arquivo que já foi apagado seria pior que não avisar.
          _ when explanation != null =>
            '$warning O áudio foi preservado em disco.',
          _ => warning,
        },
      );
    } on EchoException catch (error) {
      _startedAt = null;
      state = state.copyWith(
        phase: EchoPhase.failed,
        errorMessage: files == null
            ? error.message
            : '${error.message} O áudio foi preservado em disco.',
      );
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

  /// "Reunião de 14 de agosto, 15:30" — trocável na tela do Hub.
  String _defaultTitle(DateTime startedAt) {
    const months = [
      'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho',
      'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro',
    ];

    final hour = startedAt.hour.toString().padLeft(2, '0');
    final minute = startedAt.minute.toString().padLeft(2, '0');

    return 'Reunião de ${startedAt.day} de ${months[startedAt.month - 1]}, '
        '$hour:$minute';
  }
}
