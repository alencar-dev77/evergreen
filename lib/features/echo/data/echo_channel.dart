import 'dart:async';

import 'package:flutter/services.dart';

import '../models/echo_capabilities.dart';
import '../models/meeting_segment.dart';

/// O que sobrou da gravação: os arquivos de áudio, quanto tempo durou e como
/// cada faixa se saiu.
///
/// O caminho vem `null` quando aquela faixa não gravou nada — e as duas
/// maneiras de sair muda ficam distinguíveis: uma faixa que **não recebeu bloco
/// nenhum** (a captura não veio) e uma que recebeu só zeros (o som não estava
/// lá) davam exatamente a mesma reunião vazia, sem nada que dissesse qual das
/// duas foi.
class RecordingFiles {
  const RecordingFiles({
    this.micPath,
    this.systemPath,
    required this.durationMs,
    this.micPeak = 0,
    this.systemPeak = 0,
    this.streamError,
  });

  final String? micPath;
  final String? systemPath;
  final int durationMs;

  /// Maior amplitude registrada em cada faixa. Zero é silêncio digital exato.
  final int micPeak;
  final int systemPeak;

  /// O que derrubou a captura no meio, quando o macOS parou a gravação sozinho.
  final String? streamError;

  List<String> get paths => [?micPath, ?systemPath];

  bool get hasMic => micPath != null;
  bool get hasSystem => systemPath != null;

  /// O que dizer quando a transcrição sai vazia.
  ///
  /// `null` quando as duas faixas trouxeram som — aí o vazio é do
  /// reconhecimento, não da captura, e a tela não deve inventar uma causa.
  String? get silenceExplanation {
    if (streamError != null) {
      return 'O macOS interrompeu a captura durante a reunião: $streamError';
    }

    final micQuiet = !hasMic || micPeak == 0;
    final systemQuiet = !hasSystem || systemPeak == 0;

    if (micQuiet && systemQuiet) {
      return 'Nenhuma das duas faixas gravou som. Verifique a entrada de áudio '
          'em Ajustes do Sistema > Som e tente de novo.';
    }

    if (micQuiet) {
      return 'O microfone não gravou nada nesta reunião — só o áudio do '
          'computador entrou. Confira qual é a entrada de som em Ajustes do '
          'Sistema > Som, e se o Evergreen tem o microfone liberado.';
    }

    if (systemQuiet) {
      return 'O áudio do computador veio mudo — entrou só a sua voz. É o '
          'esperado quando ninguém mais falou; se havia reunião tocando, '
          'confira a saída de som em Ajustes do Sistema > Som.';
    }

    return null;
  }
}

/// Erro que o lado nativo devolveu e que a interface precisa explicar.
class EchoException implements Exception {
  const EchoException(this.code, this.message);

  final String code;
  final String message;

  /// O texto estourou a janela do modelo — o chamador reparte e tenta de novo.
  bool get isContextWindowExceeded => code == 'context_window_exceeded';

  @override
  String toString() => 'EchoException($code): $message';
}

/// Canal nativo do Echo — grava, transcreve e resume.
///
/// Cada uma das três coisas é nativa por um motivo diferente: capturar o áudio
/// que sai do computador é `ScreenCaptureKit`, transcrever é o modelo de fala
/// do sistema e resumir é o modelo do Apple Intelligence. Nenhuma delas tem
/// equivalente em Flutter puro. A implementação está em
/// `macos/Runner/EchoChannel.swift`.
class EchoChannel {
  EchoChannel({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(_channelName);

  static const _channelName = 'echo';

  final MethodChannel _channel;
  final _liveSegments = StreamController<String>.broadcast();

  /// Trechos que a transcrição ao vivo vai reconhecendo, quando ela está
  /// ligada. É enfeite: o resultado final vem do arquivo, depois.
  Stream<String> get onLiveSegment => _liveSegments.stream;

  /// Liga a escuta dos avisos do lado nativo. Uma vez, na inicialização.
  void listen() {
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'onLiveSegment') return;

      final arguments = call.arguments as Map<Object?, Object?>?;
      final text = arguments?['text'] as String?;
      if (text != null && text.trim().isNotEmpty && !_liveSegments.isClosed) {
        _liveSegments.add(text);
      }
    });
  }

  Future<EchoCapabilities> capabilities() async {
    final result = await _invoke<Map<Object?, Object?>>('capabilities');
    if (result == null) return const EchoCapabilities();

    return EchoCapabilities.fromMap(result);
  }

  /// Pede o microfone — ou abre os Ajustes, se já tiver sido negado.
  Future<EchoCapabilities> requestMicrophone() => _requestPermission('requestMicrophone');

  /// Pede a gravação de tela — ou abre os Ajustes, se já tiver sido negada.
  Future<EchoCapabilities> requestScreenRecording() =>
      _requestPermission('requestScreenRecording');

  Future<EchoCapabilities> _requestPermission(String method) async {
    final result = await _invoke<Map<Object?, Object?>>(method);
    if (result == null) return const EchoCapabilities();

    return EchoCapabilities.fromMap(result);
  }

  Future<void> startRecording({
    required bool liveTranscription,
    required String locale,
  }) async {
    await _invoke<Object>('startRecording', {
      'liveTranscription': liveTranscription,
      'locale': locale,
    });
  }

  Future<RecordingFiles> stopRecording() async {
    final result = await _invoke<Map<Object?, Object?>>('stopRecording');

    return RecordingFiles(
      micPath: result?['micPath'] as String?,
      systemPath: result?['systemPath'] as String?,
      durationMs: (result?['durationMs'] as num?)?.toInt() ?? 0,
      micPeak: (result?['micPeak'] as num?)?.toInt() ?? 0,
      systemPeak: (result?['systemPeak'] as num?)?.toInt() ?? 0,
      streamError: result?['streamError'] as String?,
    );
  }

  /// Para a gravação e joga o áudio fora — a saída de quem desistiu no meio.
  Future<void> cancelRecording() => _invoke<Object>('cancelRecording');

  /// Transcreve as duas faixas e devolve os trechos já intercalados por tempo.
  Future<List<MeetingSegment>> transcribe({
    required RecordingFiles files,
    required String locale,
  }) async {
    final result = await _invoke<List<Object?>>('transcribe', {
      'micPath': files.micPath,
      'systemPath': files.systemPath,
      'locale': locale,
    });

    return (result ?? const [])
        .whereType<Map<Object?, Object?>>()
        .map(MeetingSegment.fromMap)
        .toList(growable: false);
  }

  /// Resume **um** bloco de texto. Quem corta em blocos é o Dart.
  Future<String> summarize({
    required String text,
    required String instructions,
  }) async {
    final result = await _invoke<String>('summarize', {
      'text': text,
      'instructions': instructions,
    });

    return result ?? '';
  }

  /// Baixa o modelo de fala do idioma, se ele ainda não estiver na máquina.
  Future<void> installLanguage(String locale) =>
      _invoke<Object>('installLocale', {'locale': locale});

  /// Apaga o áudio. Chamado assim que a transcrição está salva — nunca antes.
  Future<void> deleteAudio(List<String> paths) =>
      _invoke<Object>('deleteAudio', {'paths': paths});

  /// Varre áudio que uma queda no meio de uma reunião deixou para trás.
  Future<void> cleanOrphanAudio() => _invoke<Object>('cleanOrphanAudio');

  Future<T?> _invoke<T>(String method, [Map<String, Object?>? arguments]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on PlatformException catch (error) {
      throw EchoException(error.code, error.message ?? 'Falha no canal do Echo.');
    } on MissingPluginException {
      // Sem lado nativo — em teste, ou fora do macOS.
      throw const EchoException('unsupported_os', 'O Echo precisa do macOS 26 ou superior.');
    }
  }

  void dispose() {
    _channel.setMethodCallHandler(null);
    _liveSegments.close();
  }
}
