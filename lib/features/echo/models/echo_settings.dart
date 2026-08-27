import 'transcription_language.dart';

/// Preferências do módulo Echo.
class EchoSettings {
  const EchoSettings({
    this.liveTranscription = false,
    this.language = TranscriptionLanguage.ptBR,
    this.summaryInstructions = '',
    this.vocabulary = '',
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

  /// Palavras que o reconhecimento deve esperar ouvir, uma por linha.
  ///
  /// Nome de pessoa, de empresa, de produto e jargão são exatamente o que um
  /// modelo de fala erra: ele encaixa o som na palavra mais provável do
  /// idioma, e "Riverpod" não é provável em português nenhum. Esta lista
  /// inclina a decisão sem travar nada — o que não está aqui continua sendo
  /// reconhecido como sempre.
  ///
  /// Vale para a transcrição, nunca para o resumo: o resumo já lê o texto
  /// pronto, com os nomes escritos certos.
  final String vocabulary;

  /// A mesma lista em termos, do jeito que o canal nativo recebe.
  ///
  /// Aceita uma por linha **e** separadas por vírgula, porque as duas maneiras
  /// são o que a pessoa faz sem pensar — e nenhuma das duas é mais certa que a
  /// outra.
  List<String> get vocabularyTerms => vocabulary
      .split(RegExp(r'[\n,;]'))
      .map((term) => term.trim())
      .where((term) => term.isNotEmpty)
      .toList(growable: false);

  /// Quantas reuniões o histórico mantém.
  ///
  /// Reunião marcada com "guardar" não entra nesta conta — o teto só alcança o
  /// que é ordinário.
  final int historyLimit;

  static const historyLimitOptions = <int>[25, 50, 75, 100];

  /// A instrução que vale quando [summaryInstructions] está vazia.
  ///
  /// Mora aqui, e não só no lado nativo, porque o Evergreen **grava com cada
  /// resumo a instrução que o produziu** (ver `Meeting.summaryPrompt`) — e não
  /// dá para registrar o que o modelo recebeu se quem escolheu foi o Swift. O
  /// canal continua tendo a mesma frase como rede, para o caso de alguém
  /// chamá-lo sem instrução nenhuma; daqui ela vai sempre explícita.
  static const defaultInstructions =
      'Você resume reuniões em português do Brasil. Escreva em tópicos curtos. '
      'Registre decisões, pendências e quem ficou responsável por cada coisa. '
      'Não invente nada que não esteja no texto.';

  /// A instrução que de fato vai para o modelo — a escrita, ou a padrão.
  ///
  /// É também a que fica gravada na reunião, e por isso ela é resolvida aqui
  /// em vez de "manda vazio e deixa o nativo decidir": o registro precisa ser
  /// da frase que o modelo leu.
  String get resolvedSummaryInstructions {
    final written = summaryInstructions.trim();
    return written.isEmpty ? defaultInstructions : written;
  }

  /// O que a interface mostra apagado no campo de instruções, para a pessoa ver
  /// o que acontece se ela não escrever nada.
  ///
  /// Mais curta que [defaultInstructions] de propósito: a primeira frase da
  /// padrão diz ao modelo qual é o papel dele, e um exemplo apagado dentro do
  /// campo é para mostrar **o que se escreve ali**, não para ser copiado
  /// inteiro.
  static const defaultInstructionsHint =
      'Escreva em tópicos curtos. Registre decisões, pendências e quem ficou '
      'responsável por cada coisa.';

  /// O exemplo apagado do campo de vocabulário — nomes, não frases.
  static const vocabularyHint = 'Evergreen, Riverpod, Diletta, Lucas Alencar';

  EchoSettings copyWith({
    bool? liveTranscription,
    TranscriptionLanguage? language,
    String? summaryInstructions,
    String? vocabulary,
    int? historyLimit,
  }) {
    return EchoSettings(
      liveTranscription: liveTranscription ?? this.liveTranscription,
      language: language ?? this.language,
      summaryInstructions: summaryInstructions ?? this.summaryInstructions,
      vocabulary: vocabulary ?? this.vocabulary,
      historyLimit: historyLimit ?? this.historyLimit,
    );
  }
}
