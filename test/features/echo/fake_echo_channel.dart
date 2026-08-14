import 'dart:async';

import 'package:evergreen/features/echo/data/echo_channel.dart';
import 'package:evergreen/features/echo/models/echo_capabilities.dart';
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

  bool didStart = false;
  bool didCancel = false;
  List<String> deletedAudio = const [];
  List<String> summarizedTexts = [];
  List<String> summarizedInstructions = [];

  @override
  Stream<String> get onLiveSegment => _liveSegments.stream;

  void emitLive(String text) => _liveSegments.add(text);

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
  }) async {
    if (failWith != null) throw failWith!;
    didStart = true;
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
  }) async {
    if (failWith != null) throw failWith!;
    return segments;
  }

  @override
  Future<String> summarize({
    required String text,
    required String instructions,
  }) async {
    if (failWith != null) throw failWith!;

    summarizedTexts.add(text);
    summarizedInstructions.add(instructions);
    return summaryValue;
  }

  @override
  Future<void> installLanguage(String locale) async {}

  @override
  Future<void> deleteAudio(List<String> paths) async => deletedAudio = paths;

  @override
  Future<void> cleanOrphanAudio() async {}

  @override
  void dispose() => _liveSegments.close();
}
