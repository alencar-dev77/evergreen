import 'transcription_language.dart';

/// Preferências do módulo Echo.
class EchoSettings {
  const EchoSettings({
    this.liveTranscription = false,
    this.language = TranscriptionLanguage.ptBR,
    this.summaryInstructions = '',
    this.historyLimit = 100,
  });

  /// Mostrar o texto se formando enquanto a reunião acontece.
  ///
  /// Desligada por padrão, e não por gosto: transcrever ao vivo custa
  /// processador exatamente quando a chamada de vídeo já está consumindo a
  /// máquina, e num Mac de pouca memória isso engasga a reunião — que é o
  /// único momento em que o módulo não pode falhar. Quem tem folga liga.
  ///
  /// Ligada ou desligada, o áudio é gravado em arquivo do mesmo jeito: o texto
  /// ao vivo é um extra por cima, nunca o caminho principal. Se ele falhar, a
  /// transcrição final sai igual.
  final bool liveTranscription;

  final TranscriptionLanguage language;

  /// Como você quer o resumo, em texto livre.
  ///
  /// Vazio significa usar a instrução padrão do app, não mandar instrução
  /// nenhuma — um modelo sem instrução devolve um formato a cada vez.
  ///
  /// Vale curta e imperativa ("em tópicos", "liste decisões e responsáveis"):
  /// o modelo local é pequeno, e instrução longa e cheia de condições ele
  /// começa a ignorar no meio.
  final String summaryInstructions;

  /// Quantas reuniões o histórico mantém.
  ///
  /// Reunião marcada com "guardar" não entra nesta conta — o teto só alcança o
  /// que é ordinário.
  final int historyLimit;

  static const historyLimitOptions = <int>[25, 50, 75, 100];

  /// O que a interface mostra apagado no campo de instruções, para a pessoa ver
  /// o que acontece se ela não escrever nada.
  static const defaultInstructionsHint =
      'Escreva em tópicos curtos. Registre decisões, pendências e quem ficou '
      'responsável por cada coisa.';

  EchoSettings copyWith({
    bool? liveTranscription,
    TranscriptionLanguage? language,
    String? summaryInstructions,
    int? historyLimit,
  }) {
    return EchoSettings(
      liveTranscription: liveTranscription ?? this.liveTranscription,
      language: language ?? this.language,
      summaryInstructions: summaryInstructions ?? this.summaryInstructions,
      historyLimit: historyLimit ?? this.historyLimit,
    );
  }
}
