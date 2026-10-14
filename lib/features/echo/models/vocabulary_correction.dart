import 'meeting_segment.dart';

/// "Quando sair isto, era aquilo": a troca que o vocabulário sozinho não faz.
///
/// O vocabulário (`contextualStrings`) só **inclina** o modelo de fala, e
/// perde quando o som tem uma leitura provável no idioma — "ASAP" dito no meio
/// do português sai "a zap", porque "a zap" é português e "ASAP" não é. A
/// troca é a outra metade: ela não pede nada ao modelo, só conserta o texto
/// que ele devolveu, sempre do mesmo jeito.
///
/// Escrita no mesmo campo do vocabulário, como `a zap -> ASAP`: o lado
/// esquerdo é o que sai errado, o direito o que era. O direito também vai ao
/// modelo como vocabulário — quem ensinou a troca quer a palavra.
class VocabularyCorrection {
  const VocabularyCorrection({required this.heard, required this.written});

  /// O que o reconhecimento entrega, uma ou mais palavras.
  final String heard;

  /// O que deveria estar escrito.
  final String written;

  /// As setas que separam os dois lados. `=` também, porque é o que se
  /// digita sem pensar quando não se lembra da seta.
  static final _arrow = RegExp(r'\s*(?:->|=>|→|=)\s*');

  /// Lê uma entrada do campo; `null` quando ela é só uma palavra.
  static VocabularyCorrection? parse(String entry) {
    final parts = entry.split(_arrow);
    if (parts.length != 2) return null;

    final heard = parts[0].trim();
    final written = parts[1].trim();
    if (heard.isEmpty || written.isEmpty) return null;

    return VocabularyCorrection(heard: heard, written: written);
  }

  /// Uma entrada do campo é uma troca?
  static bool isCorrection(String entry) => entry.contains(_arrow);

  /// O que sai errado, como palavra inteira e sem diferença de maiúscula:
  /// "zap -> ASAP" não pode mexer em "zapping", e "A zap" no começo da frase
  /// é o mesmo erro.
  RegExp get _pattern => RegExp(
    '(?<![\\p{L}\\p{N}])'
    '${heard.split(RegExp(r'\s+')).map(RegExp.escape).join(r'\s+')}'
    '(?![\\p{L}\\p{N}])',
    caseSensitive: false,
    unicode: true,
  );

  /// Aplica as trocas aos trechos de uma transcrição.
  ///
  /// As palavras com relógio vão junto: "a zap" são duas palavras que viram
  /// uma, do começo da primeira ao fim da segunda — senão o player acenderia
  /// metade de "ASAP" e o clique levaria a um pedaço dela. Trecho cujas
  /// palavras não somam o texto (não deveria acontecer) troca só o texto, e a
  /// tela já sabe desenhar esse caso sem relógio por palavra.
  static List<MeetingSegment> apply(
    List<MeetingSegment> segments,
    List<VocabularyCorrection> corrections,
  ) {
    if (corrections.isEmpty) return segments;

    // A mais longa primeiro, seja qual for a ordem do campo: com "zap" antes
    // de "a zap", o "a zap" viraria "a ASAP" e a troca maior nunca casaria.
    final ordered = [...corrections]
      ..sort((a, b) => b.heard.length.compareTo(a.heard.length));

    return [for (final segment in segments) _applyTo(segment, ordered)];
  }

  static MeetingSegment _applyTo(
    MeetingSegment segment,
    List<VocabularyCorrection> corrections,
  ) {
    final wordsMatch =
        segment.words.isNotEmpty &&
        segment.words.map((word) => word.text).join() == segment.text;

    if (!wordsMatch) {
      var text = segment.text;
      for (final correction in corrections) {
        text = text.replaceAll(correction._pattern, correction.written);
      }
      if (text == segment.text) return segment;
      return MeetingSegment(
        speaker: segment.speaker,
        startMs: segment.startMs,
        endMs: segment.endMs,
        text: text,
        words: segment.words,
      );
    }

    var words = segment.words;
    for (final correction in corrections) {
      words = correction._applyToWords(words);
    }
    if (identical(words, segment.words)) return segment;

    return MeetingSegment(
      speaker: segment.speaker,
      startMs: segment.startMs,
      endMs: segment.endMs,
      text: words.map((word) => word.text).join(),
      words: words,
    );
  }

  /// Troca dentro das palavras, fundindo as que o erro atravessa.
  List<MeetingWord> _applyToWords(List<MeetingWord> words) {
    final text = words.map((word) => word.text).join();
    final matches = _pattern.allMatches(text).toList();
    if (matches.isEmpty) return words;

    // Onde cada palavra começa no texto juntado.
    final starts = <int>[];
    var offset = 0;
    for (final word in words) {
      starts.add(offset);
      offset += word.text.length;
    }

    int wordAt(int position) {
      var index = 0;
      while (index + 1 < starts.length && starts[index + 1] <= position) {
        index++;
      }
      return index;
    }

    final result = [...words];
    // Do fim para o começo: fundir palavras não desloca o que vem antes.
    for (final match in matches.reversed) {
      final first = wordAt(match.start);
      final last = wordAt(match.end - 1);

      final before = words[first].text.substring(
        0,
        match.start - starts[first],
      );
      final after = words[last].text.substring(match.end - starts[last]);

      result.replaceRange(first, last + 1, [
        MeetingWord(
          startMs: words[first].startMs,
          endMs: words[last].endMs,
          text: '$before$written$after',
        ),
      ]);
    }

    return result;
  }
}
