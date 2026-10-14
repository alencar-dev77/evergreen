import 'meeting_segment.dart';

/// Um intervalo em que uma voz falou, do jeito que a diarização devolve.
///
/// [voice] é só um identificador: diz que dois intervalos são da mesma pessoa,
/// e mais nada. Não é nome e não sobrevive à reunião — a "S2" de hoje não é a
/// "S2" de amanhã.
class VoiceTurn {
  const VoiceTurn({
    required this.voice,
    required this.startMs,
    required this.endMs,
  });

  final String voice;
  final int startMs;
  final int endMs;

  int get durationMs => endMs - startMs;

  static VoiceTurn? fromMap(Map<Object?, Object?> map) {
    final voice = map['voice'];
    final start = map['startMs'];
    final end = map['endMs'];
    if (voice is! String || start is! num || end is! num) return null;

    return VoiceTurn(voice: voice, startMs: start.toInt(), endMs: end.toInt());
  }
}

/// Pinta as vozes da diarização por cima da transcrição.
///
/// São duas respostas de dois modelos que não se conhecem: o de fala diz *o
/// que* foi dito e quando cada palavra começou; o de diarização diz *quem*
/// falava em cada intervalo, sem saber uma palavra. O que as junta é o
/// relógio — cada palavra é de quem estava falando enquanto ela soava.
///
/// A decisão é por palavra, e não por trecho, porque o trecho do modelo de
/// fala fecha onde ele achou a pausa, não onde a pessoa trocou: "pode ser na
/// sexta? Sexta eu consigo." chega como um trecho só, e são duas pessoas. A
/// palavra é o que deixa partir o trecho no ponto certo.
///
/// Fica em Dart, como o `CrossTalkFilter`, pelo mesmo motivo: o Swift só
/// ouve, e a decisão dá para testar sem microfone, sem reunião e sem modelo.
///
/// Só a faixa do computador é tocada. O microfone é você, e isso não é
/// palpite de modelo nenhum.
abstract final class VoiceSeparation {
  /// Trecho de voz mais curto que se aceita entre duas falas da mesma pessoa.
  ///
  /// A diarização erra nas bordas — uma tosse, uma risada, uma palavra dita
  /// junto com a outra pessoa — e sem este piso uma frase sairia partida em
  /// três parágrafos por causa de uma palavra que "trocou de dono" no meio. É
  /// curto o bastante para não engolir um "sim" de verdade: uma resposta de
  /// outra pessoa quase sempre é um trecho próprio do modelo de fala, e aí ela
  /// não está *entre* duas falas da mesma voz dentro de um trecho só.
  static const islandMs = 700;

  /// Os trechos com a voz de cada um, partidos onde a voz troca.
  ///
  /// Sem efeito quando a diarização achou menos de duas vozes: numerar uma
  /// pessoa só como "Pessoa 1" não diz nada que "Reunião" já não dissesse.
  static List<MeetingSegment> apply(
    List<MeetingSegment> segments,
    List<VoiceTurn> turns,
  ) {
    final valid = turns.where((turn) => turn.durationMs > 0).toList()
      ..sort((a, b) => a.startMs.compareTo(b.startMs));

    if (valid.map((turn) => turn.voice).toSet().length < 2) return segments;

    final assigned = <(MeetingSegment, String?)>[
      for (final segment in segments)
        if (segment.speaker == Speaker.others)
          ..._split(segment, valid)
        else
          (segment, null),
    ];

    // Numeradas na ordem em que aparecem na transcrição, que é a ordem em que
    // se lê: "Pessoa 1" é quem falou primeiro do outro lado.
    final numbers = <String, int>{};
    for (final (_, voice) in assigned) {
      if (voice != null) numbers.putIfAbsent(voice, () => numbers.length + 1);
    }

    // Duas vozes no modelo, uma só nas palavras: a outra era ruído, ou falou
    // só onde o modelo de fala não ouviu nada. Para a leitura, é uma pessoa.
    if (numbers.length < 2) return segments;

    final separated = [
      for (final (segment, voice) in assigned)
        voice == null ? segment : segment.withVoice(numbers[voice]),
    ];

    // Partir um trecho cria pedaços que começam no meio dele, e uma fala sua
    // que começou ali no meio fica, na lista, depois de um pedaço que começa
    // mais tarde que ela. A leitura, o documento e o texto do resumo seguem a
    // ordem da lista — e o player acende o turno pela ordem também. O empate
    // fica na ordem em que veio: `List.sort` não é estável, e a mesma
    // reunião sairia em ordens diferentes de uma abertura para outra.
    final order = List.generate(separated.length, (index) => index)
      ..sort((a, b) {
        final byTime = separated[a].startMs.compareTo(separated[b].startMs);
        return byTime != 0 ? byTime : a.compareTo(b);
      });

    return [for (final index in order) separated[index]];
  }

  /// O trecho em pedaços de uma voz só cada um.
  static List<(MeetingSegment, String)> _split(
    MeetingSegment segment,
    List<VoiceTurn> turns,
  ) {
    final words = segment.words;
    final wordsMatch =
        words.isNotEmpty &&
        words.map((word) => word.text).join() == segment.text;

    // Sem relógio por palavra, o trecho inteiro vai para quem mais falou
    // durante ele. Perde o ponto da troca, nunca o texto.
    if (!wordsMatch) {
      return [(segment, _voiceAt(segment.startMs, segment.endMs, turns))];
    }

    final voices = [
      for (final word in words) _voiceAt(word.startMs, word.endMs, turns),
    ];
    _absorbIslands(words, voices);

    final pieces = <(MeetingSegment, String)>[];
    var from = 0;

    for (var index = 1; index <= words.length; index++) {
      if (index < words.length && voices[index] == voices[from]) continue;

      final group = words.sublist(from, index);
      pieces.add((
        MeetingSegment(
          speaker: segment.speaker,
          // As pontas do trecho continuam as do trecho: a borda que o modelo
          // de fala marcou vale mais que o começo da primeira palavra.
          startMs: from == 0 ? segment.startMs : group.first.startMs,
          endMs: index == words.length ? segment.endMs : group.last.endMs,
          text: group.map((word) => word.text).join(),
          words: group,
        ),
        voices[from],
      ));
      from = index;
    }

    return pieces;
  }

  /// A voz que mais soou entre [startMs] e [endMs].
  ///
  /// Sem ninguém no intervalo — a diarização é mais exigente que o modelo de
  /// fala para chamar algo de voz, e um murmúrio passa por um e não pelo
  /// outro —, fica com a voz mais próxima no tempo. Tudo o que foi transcrito
  /// foi dito por alguém, e um "Reunião" solto no meio de "Pessoa 1" e
  /// "Pessoa 2" seria uma terceira pessoa inventada.
  static String _voiceAt(int startMs, int endMs, List<VoiceTurn> turns) {
    final overlap = <String, int>{};
    VoiceTurn? nearest;
    var nearestGap = 1 << 62;

    for (final turn in turns) {
      // A palavra sem duração (o modelo às vezes fecha uma no mesmo instante
      // em que a abre) não dividiria tempo com ninguém: dentro de uma voz,
      // ela conta um milissegundo, em vez de cair na conta da mais próxima.
      final inside =
          startMs == endMs && startMs >= turn.startMs && startMs < turn.endMs;
      final shared = inside
          ? 1
          : (endMs < turn.endMs ? endMs : turn.endMs) -
                (startMs > turn.startMs ? startMs : turn.startMs);

      if (shared > 0) {
        overlap.update(turn.voice, (ms) => ms + shared, ifAbsent: () => shared);
        continue;
      }

      final gap = turn.startMs >= endMs
          ? turn.startMs - endMs
          : startMs - turn.endMs;
      if (gap < nearestGap) {
        nearestGap = gap;
        nearest = turn;
      }
    }

    if (overlap.isEmpty) return nearest!.voice;

    return overlap.entries
        .reduce((best, entry) => entry.value > best.value ? entry : best)
        .key;
  }

  /// Devolve à voz de fora as ilhas curtas cercadas por ela dos dois lados.
  static void _absorbIslands(List<MeetingWord> words, List<String> voices) {
    var from = 0;

    while (from < words.length) {
      var to = from;
      while (to + 1 < words.length && voices[to + 1] == voices[from]) {
        to++;
      }

      final hasBothSides = from > 0 && to < words.length - 1;
      final surroundedBySame =
          hasBothSides && voices[from - 1] == voices[to + 1];
      final isShort = words[to].endMs - words[from].startMs < islandMs;

      if (surroundedBySame && isShort) {
        for (var index = from; index <= to; index++) {
          voices[index] = voices[from - 1];
        }
      }

      from = to + 1;
    }
  }
}
