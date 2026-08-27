import 'dart:convert';

import 'meeting_segment.dart';
import 'transcription_language.dart';

/// Uma reunião gravada: a transcrição, e o resumo quando existe.
///
/// O áudio não está aqui, e nunca esteve — ele vive num arquivo temporário
/// entre gravar e transcrever, e é apagado assim que a transcrição entra no
/// banco. O que sobra é texto, que é barato e é o que a pessoa vai reler.
class Meeting {
  const Meeting({
    this.id,
    required this.title,
    required this.startedAt,
    required this.durationMs,
    required this.language,
    required this.segments,
    this.summary,
    this.summaryPrompt,
    this.isKept = false,
  });

  final int? id;

  /// Nome dado pela pessoa, ou a data por extenso enquanto ela não deu nenhum.
  final String title;

  final DateTime startedAt;
  final int durationMs;
  final TranscriptionLanguage language;

  final List<MeetingSegment> segments;

  /// `null` enquanto ninguém pediu o resumo. Resumir é sempre um ato
  /// deliberado: é o único momento em que o modelo de linguagem entra.
  final String? summary;

  /// A instrução que o modelo recebeu para escrever [summary].
  ///
  /// Guardada junto do texto porque ela é o que explica o formato dele — e
  /// porque refazer o resumo usa a instrução que estiver nas preferências
  /// **naquele momento**, não esta. Sem o registro, trocar a instrução e
  /// refazer deixava dois textos diferentes sem nada dizendo o que mudou entre
  /// eles.
  ///
  /// `null` em resumo feito antes de esta coluna existir. Nunca vazia: quando
  /// a pessoa não escreveu instrução nenhuma, o que fica gravado é a padrão do
  /// aplicativo, que foi a que de fato valeu.
  final String? summaryPrompt;

  /// Guardada contra a limpeza automática do histórico.
  ///
  /// Mesma ideia do item fixado no Pin: o teto de reuniões só come o que é
  /// ordinário, e o que você marcou fica independente do número.
  final bool isKept;

  Duration get duration => Duration(milliseconds: durationMs);

  bool get hasSummary => (summary ?? '').trim().isNotEmpty;

  /// Só quando há resumo **e** o registro da instrução dele: um prompt sem o
  /// texto que ele produziu não descreve nada.
  bool get hasSummaryPrompt =>
      hasSummary && (summaryPrompt ?? '').trim().isNotEmpty;

  bool get isEmpty => segments.isEmpty;

  /// A transcrição inteira como texto corrido, que é o que vai para o resumo.
  ///
  /// Com o rótulo de quem falou em cada linha: sem ele o modelo não teria como
  /// distinguir o que *você* disse do que te disseram, e essa é justamente a
  /// distinção que faz um resumo de reunião útil.
  String get plainText => segments
      .map((segment) => '${segment.speaker.label}: ${segment.text}')
      .join('\n');

  Meeting copyWith({
    int? id,
    String? title,
    String? summary,
    String? summaryPrompt,
    bool? isKept,
    List<MeetingSegment>? segments,
  }) {
    return Meeting(
      id: id ?? this.id,
      title: title ?? this.title,
      startedAt: startedAt,
      durationMs: durationMs,
      language: language,
      segments: segments ?? this.segments,
      summary: summary ?? this.summary,
      summaryPrompt: summaryPrompt ?? this.summaryPrompt,
      isKept: isKept ?? this.isKept,
    );
  }

  /// Os segmentos em JSON, como vão para a coluna `transcript`.
  ///
  /// JSON, e não o formato `campo|campo` que o Focus usa nas observações: ali o
  /// texto é escrito pela pessoa num campo de uma linha, aqui ele é fala
  /// transcrita — pode conter barra vertical, quebra de linha e qualquer outra
  /// coisa que um separador improvisado não sobreviveria.
  String encodeSegments() =>
      jsonEncode(segments.map((segment) => segment.toJson()).toList());

  static List<MeetingSegment> decodeSegments(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];

      return decoded
          .whereType<Map<Object?, Object?>>()
          .map(MeetingSegment.fromMap)
          .toList(growable: false);
    } on FormatException {
      // Transcrição ilegível não derruba a lista de reuniões: a linha continua
      // lá, com a data e a duração, e só o texto se perde.
      return const [];
    }
  }
}
