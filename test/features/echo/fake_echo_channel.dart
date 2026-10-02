import 'dart:async';

import 'package:evergreen/features/echo/data/echo_channel.dart';
import 'package:evergreen/features/echo/models/echo_capabilities.dart';
import 'package:evergreen/features/echo/models/echo_spectrum.dart';
import 'package:evergreen/features/echo/models/meeting_segment.dart';

/// Um Echo sem microfone, sem reunião e sem modelo.
///
/// O canal de verdade fala com o `ScreenCaptureKit`, com o transcritor do
/// sistema e com o Apple Intelligence — nada disso existe dentro de um teste,
/// e nenhuma dessas três coisas é o que se quer verificar aqui.
class FakeEchoChannel implements EchoChannel {
  FakeEchoChannel({
    this.capabilitiesValue = const EchoCapabilities(
      microphone: PermissionStatus.granted,
      screenRecording: PermissionStatus.granted,
      summaries: SummaryAvailability.available,
    ),
    this.segments = const [],
  });

  EchoCapabilities capabilitiesValue;
  List<MeetingSegment> segments;

  /// Resposta fixa do modelo, ou um erro para exercitar o caminho de falha.
  String summaryValue = 'resumo';
  EchoException? failWith;

  final _liveSegments = StreamController<String>.broadcast();
  final _levels = StreamController<EchoSpectrum>.broadcast();

  bool didStart = false;
  bool didCancel = false;
  bool didPause = false;
  bool didResume = false;

  /// Com que preferências a gravação foi pedida.
  ///
  /// São elas que decidem o modo lá no nativo — o ao vivo liga um segundo
  /// analisador, o idioma escolhe o modelo de fala. Ler a preferência errada
  /// não quebra nada visível no Dart: a gravação sai calada no modo de ontem.
  bool? startedWithLiveTranscription;
  String? startedWithLocale;
  List<String>? startedWithVocabulary;
  List<String>? transcribedWithVocabulary;

  /// Com que modelo o sistema atenderia cada idioma.
  ///
  /// Vazio por padrão, que é o mesmo que "não deu para perguntar" — numa
  /// máquina de teste não há transcritor nenhum, e a tela trata esse caso
  /// calando. Um teste que queira o aviso de idioma sem modelo preenche isto.
  Map<String, String> resolvedLocales = const {};
  List<String> deletedAudio = const [];
  List<String> summarizedTexts = [];
  List<String> summarizedInstructions = [];

  @override
  Stream<String> get onLiveSegment => _liveSegments.stream;

  void emitLive(String text) => _liveSegments.add(text);

  @override
  Stream<EchoSpectrum> get onLevels => _levels.stream;

  void emitLevels(List<double> mic, List<double> system) =>
      _levels.add(EchoSpectrum(mic: mic, system: system));

  @override
  Future<void> pauseRecording() async {
    if (failWith != null) throw failWith!;
    didPause = true;
  }

  @override
  Future<void> resumeRecording() async {
    if (failWith != null) throw failWith!;
    didResume = true;
  }

  @override
  void listen() {}

  @override
  Future<EchoCapabilities> capabilities() async => capabilitiesValue;

  /// Quais permissões foram pedidas, na ordem — é o que os testes verificam.
  List<String> requested = [];

  @override
  Future<EchoCapabilities> requestMicrophone() async {
    requested.add('microphone');
    capabilitiesValue = EchoCapabilities(
      microphone: PermissionStatus.granted,
      screenRecording: capabilitiesValue.screenRecording,
      summaries: capabilitiesValue.summaries,
    );
    return capabilitiesValue;
  }

  @override
  Future<EchoCapabilities> requestScreenRecording() async {
    requested.add('screenRecording');
    capabilitiesValue = EchoCapabilities(
      microphone: capabilitiesValue.microphone,
      screenRecording: PermissionStatus.granted,
      summaries: capabilitiesValue.summaries,
    );
    return capabilitiesValue;
  }

  @override
  Future<void> startRecording({
    required bool liveTranscription,
    required String locale,
    List<String> vocabulary = const [],
  }) async {
    if (failWith != null) throw failWith!;
    didStart = true;
    startedWithLiveTranscription = liveTranscription;
    startedWithLocale = locale;
    startedWithVocabulary = vocabulary;
  }

  @override
  Future<RecordingFiles> stopRecording() async => const RecordingFiles(
    micPath: '/tmp/mic.caf',
    systemPath: '/tmp/sistema.caf',
    durationMs: 90000,
  );

  @override
  Future<void> cancelRecording() async => didCancel = true;

  @override
  Future<List<MeetingSegment>> transcribe({
    required RecordingFiles files,
    required String locale,
    List<String> vocabulary = const [],
  }) async {
    if (failWith != null) throw failWith!;
    transcribedWithVocabulary = vocabulary;
    return segments;
  }

  /// Segura a resposta do modelo até o teste soltar.
  ///
  /// É o que permite olhar para o que acontece **durante** um resumo — que é
  /// justamente onde mora o caso interessante: a janela que pediu ser fechada
  /// no meio do trabalho.
  Completer<void>? summaryGate;

  @override
  Future<String> summarize({
    required String text,
    required String instructions,
  }) async {
    if (failWith != null) throw failWith!;

    summarizedTexts.add(text);
    summarizedInstructions.add(instructions);

    await summaryGate?.future;

    return summaryValue;
  }

  /// A janela do modelo, como o nativo responderia. `null` é o "não deu para
  /// perguntar" — o mesmo que acontece fora do macOS 26.
  int? contextSizeValue;

  @override
  Future<int?> summaryContextSize() async => contextSizeValue;

  @override
  Future<String?> installLanguage(String locale) async => locale;

  @override
  Future<Map<String, String>> resolveLocales(List<String> locales) async =>
      resolvedLocales;

  @override
  Future<void> deleteAudio(List<String> paths) async => deletedAudio = paths;

  @override
  Future<void> cleanOrphanAudio() async {}

  @override
  void dispose() {
    _liveSegments.close();
    _levels.close();
  }
}
