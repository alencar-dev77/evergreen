import 'dart:async';

import 'package:flutter/services.dart';

import '../models/echo_capabilities.dart';
import '../models/echo_spectrum.dart';
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
    this.micError,
  });

  final String? micPath;
  final String? systemPath;
  final int durationMs;

  /// Maior amplitude registrada em cada faixa. Zero é silêncio digital exato.
  final int micPeak;
  final int systemPeak;

  /// O que derrubou a captura no meio, quando o macOS parou a gravação sozinho.
  final String? streamError;

  /// Por que o microfone não subiu, quando não subiu.
  final String? micError;

  List<String> get paths => [?micPath, ?systemPath];

  bool get hasMic => micPath != null;
  bool get hasSystem => systemPath != null;

  /// Faixa que não trouxe som nenhum: ou não gravou, ou gravou só zeros.
  bool get isMicSilent => !hasMic || micPeak == 0;
  bool get isSystemSilent => !hasSystem || systemPeak == 0;

  /// O aviso de uma faixa que faltou, mesmo quando a outra transcreveu bem.
  ///
  /// Separado da [silenceExplanation] porque o caso é outro: ali a reunião saiu
  /// vazia e a gravação falhou; aqui saiu texto, e o que falta é **metade** da
  /// conversa. Sem dizer nada, a pessoa só descobre relendo a transcrição e
  /// notando que ela mesma não está lá.
  String? get halfSilenceWarning {
    if (isMicSilent && !isSystemSilent) {
      return micError != null
          ? 'A sua voz não entrou: $micError'
          : 'A sua voz não entrou: só o áudio do computador foi gravado. '
                'Confira a entrada em Ajustes do Sistema > Som.';
    }

    if (isSystemSilent && !isMicSilent) {
      return 'Só a sua voz entrou: o computador veio mudo. É o esperado se '
          'ninguém mais falou.';
    }

    return null;
  }

  /// O que dizer quando a transcrição sai vazia.
  ///
  /// `null` quando as duas faixas trouxeram som — aí o vazio é do
  /// reconhecimento, não da captura, e a tela não deve inventar uma causa.
  String? get silenceExplanation {
    if (streamError != null) {
      return 'O macOS interrompeu a captura durante a reunião: $streamError';
    }

    final micQuiet = isMicSilent;
    final systemQuiet = isSystemSilent;

    if (micQuiet && systemQuiet) {
      return 'Nenhuma das faixas gravou som. Confira a entrada em Ajustes '
          'do Sistema > Som.';
    }

    if (micQuiet) {
      return 'O microfone não gravou nada: entrou só o computador. Confira '
          'a entrada em Ajustes do Sistema > Som e a permissão do microfone.';
    }

    if (systemQuiet) {
      return 'O computador veio mudo: entrou só a sua voz. Se havia reunião '
          'tocando, confira a saída em Ajustes do Sistema > Som.';
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
  final _levels = StreamController<EchoSpectrum>.broadcast();

  /// Trechos que a transcrição ao vivo vai reconhecendo, quando ela está
  /// ligada. É enfeite: o resultado final vem do arquivo, depois.
  Stream<String> get onLiveSegment => _liveSegments.stream;

  /// O espectro de cada faixa enquanto a gravação corre — dez avisos por
  /// segundo.
  ///
  /// Diferente do texto ao vivo, este chega **sempre**: ele é o que responde
  /// "o Echo está ouvindo?", e essa pergunta existe em toda reunião, com ou sem
  /// transcrição ao vivo ligada.
  Stream<EchoSpectrum> get onLevels => _levels.stream;

  /// Liga a escuta dos avisos do lado nativo. Uma vez, na inicialização.
  void listen() {
    _channel.setMethodCallHandler((call) async {
      final arguments = call.arguments as Map<Object?, Object?>?;

      switch (call.method) {
        case 'onLiveSegment':
          final text = arguments?['text'] as String?;
          if (text != null &&
              text.trim().isNotEmpty &&
              !_liveSegments.isClosed) {
            _liveSegments.add(text);
          }
        case 'onLevels':
          if (arguments != null && !_levels.isClosed) {
            _levels.add(EchoSpectrum.fromMap(arguments));
          }
      }
    });
  }

  Future<EchoCapabilities> capabilities() async {
    final result = await _invoke<Map<Object?, Object?>>('capabilities');
    if (result == null) return const EchoCapabilities();

    return EchoCapabilities.fromMap(result);
  }

  /// Pede o microfone — ou abre os Ajustes, se já tiver sido negado.
  Future<EchoCapabilities> requestMicrophone() =>
      _requestPermission('requestMicrophone');

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
    List<String> vocabulary = const [],
  }) async {
    await _invoke<Object>('startRecording', {
      'liveTranscription': liveTranscription,
      'locale': locale,
      'vocabulary': vocabulary,
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
      micError: result?['micError'] as String?,
    );
  }

  /// Para a gravação e joga o áudio fora — a saída de quem desistiu no meio.
  /// Suspende a gravação sem encerrá-la: o trecho pausado não entra no arquivo
  /// nem na duração, e a captura continua de pé.
  Future<void> pauseRecording() => _invoke<Object>('pauseRecording');

  Future<void> resumeRecording() => _invoke<Object>('resumeRecording');

  Future<void> cancelRecording() => _invoke<Object>('cancelRecording');

  /// Transcreve as duas faixas e devolve os trechos já intercalados por tempo.
  Future<List<MeetingSegment>> transcribe({
    required RecordingFiles files,
    required String locale,
    List<String> vocabulary = const [],
  }) async {
    final result = await _invoke<List<Object?>>('transcribe', {
      'micPath': files.micPath,
      'systemPath': files.systemPath,
      'locale': locale,
      'vocabulary': vocabulary,
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

  /// Quantos tokens cabem numa chamada ao modelo, ou `null` se não deu para
  /// perguntar.
  ///
  /// `null` não é falha: quem corta os blocos cai no teto conservador de
  /// sempre, que foi medido para a janela menor e continua cabendo nela.
  Future<int?> summaryContextSize() async {
    try {
      return await _invoke<int>('summaryContextSize');
    } on EchoException {
      return null;
    }
  }

  /// Baixa o modelo de fala do idioma, se ele ainda não estiver na máquina.
  ///
  /// Devolve o idioma que o sistema vai usar de fato, que nem sempre é o
  /// pedido: uma variante regional pode ser atendida por outra. Lança
  /// `locale_unsupported` quando não existe modelo nenhum para ela — e essa é
  /// a resposta que faltava, porque antes o nativo dizia que tinha instalado
  /// mesmo quando não havia o que instalar.
  Future<String?> installLanguage(String locale) async {
    final result = await _invoke<Map<Object?, Object?>>('installLocale', {
      'locale': locale,
    });

    return result?['locale'] as String?;
  }

  /// Para cada idioma pedido, com qual modelo o sistema o atenderia.
  ///
  /// Idioma ausente do resultado é idioma que esta máquina não reconhece; um
  /// que apareça apontando para outro identificador é uma variante regional
  /// atendida por um modelo vizinho — as duas coisas a tela precisa poder
  /// dizer antes da reunião, e não depois.
  Future<Map<String, String>> resolveLocales(List<String> locales) async {
    final result = await _invoke<Map<Object?, Object?>>('resolveLocales', {
      'locales': locales,
    });

    return {
      for (final entry in (result ?? const {}).entries)
        if (entry.key is String && entry.value is String)
          entry.key as String: entry.value as String,
    };
  }

  /// Apaga o áudio. Chamado assim que a transcrição está salva — nunca antes.
  Future<void> deleteAudio(List<String> paths) =>
      _invoke<Object>('deleteAudio', {'paths': paths});

  /// Varre áudio que uma queda no meio de uma reunião deixou para trás.
  Future<void> cleanOrphanAudio() => _invoke<Object>('cleanOrphanAudio');

  Future<T?> _invoke<T>(
    String method, [
    Map<String, Object?>? arguments,
  ]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on PlatformException catch (error) {
      throw EchoException(
        error.code,
        error.message ?? 'Falha no canal do Echo.',
      );
    } on MissingPluginException {
      // Sem lado nativo — em teste, ou fora do macOS.
      throw const EchoException(
        'unsupported_os',
        'O Echo precisa do macOS 26 ou superior.',
      );
    }
  }

  void dispose() {
    _channel.setMethodCallHandler(null);
    _liveSegments.close();
    _levels.close();
  }
}
