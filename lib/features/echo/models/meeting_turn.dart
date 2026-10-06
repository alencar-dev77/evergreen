import 'meeting_segment.dart';

/// Uma fala inteira de uma pessoa, do jeito que se lê.
///
/// O modelo de fala não devolve frases: devolve pedaços, fechados onde ele
/// achou a pausa. Uma única frase sai assim —
///
/// ```
/// [0.0s] Bom dia pessoal, vamos fechar o escopo do projeto
/// [3.8s]  hoje.
/// [4.6s]  ficou
/// [5.0s]  decidido que o Lucas manda a proposta até
/// [7.8s]  sexta-feira.
/// ```
///
/// Mostrar isso linha a linha, cada uma com horário e nome de quem falou, é o
/// que fazia a transcrição parecer desorganizada: a mesma pessoa se repetindo
/// cinco vezes para dizer uma frase.
///
/// O turno junta os pedaços consecutivos da mesma pessoa em um parágrafo. Os
/// trechos originais continuam no banco, com o tempo exato de cada um — quem
/// agrupa é a leitura, não o armazenamento.
class MeetingTurn {
  const MeetingTurn({
    required this.speaker,
    required this.startMs,
    required this.text,
    this.endMs = 0,
    this.pieces = const [],
  });

  final Speaker speaker;

  /// Quando a fala começou — o horário do primeiro pedaço.
  final int startMs;

  /// Quando ela terminou — o fim do último pedaço.
  final int endMs;

  final String text;

  /// O mesmo [text], em pedaços com relógio — palavras, quando a transcrição
  /// as trouxe; trechos inteiros, quando é de antes disso.
  ///
  /// Juntos, eles dão exatamente o [text]: é o que deixa a tela desenhar o
  /// parágrafo pedaço por pedaço, destacando o que toca e levando o áudio
  /// até o pedaço clicado, sem que a leitura mude uma letra.
  final List<TimedPiece> pieces;

  /// Quantos pedaços desta fala já foram ditos em [positionMs] — os que já
  /// começaram.
  ///
  /// A conta é cumulativa: tudo o que ficou para trás continua aceso, e não
  /// só a palavra da vez. É o que mostra até onde a reunião já andou — e o
  /// que faz o clique numa palavra lá na frente acender todas as anteriores,
  /// porque o áudio saltou para depois delas.
  int spokenCount(int positionMs) {
    if (pieces.isEmpty || positionMs < pieces.first.startMs) return 0;
    if (positionMs >= pieces.last.startMs) return pieces.length;

    var count = 0;
    while (count < pieces.length && pieces[count].startMs <= positionMs) {
      count++;
    }
    return count;
  }

  /// Silêncio que encerra um turno mesmo sem trocar de pessoa.
  ///
  /// A mesma pessoa voltando a falar depois de meio minuto está dizendo outra
  /// coisa, não terminando a frase anterior. Sem este corte, uma reunião em que
  /// só uma pessoa fala viraria um parágrafo de meia hora.
  static const _gapMs = 30000;

  /// `12:03` — o relógio da fala dentro da reunião.
  String get timestamp {
    final totalSeconds = startMs ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;

    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  /// Agrupa os trechos em turnos de leitura.
  static List<MeetingTurn> from(List<MeetingSegment> segments) {
    final turns = <MeetingTurn>[];

    Speaker? speaker;
    var startMs = 0;
    var endMs = 0;
    final buffer = <String>[];
    final pieces = <TimedPiece>[];

    void flush() {
      final atual = speaker;
      if (atual == null || buffer.isEmpty) return;

      turns.add(
        MeetingTurn(
          speaker: atual,
          startMs: startMs,
          endMs: endMs,
          text: _join(buffer),
          pieces: List.unmodifiable(pieces),
        ),
      );
      buffer.clear();
      pieces.clear();
    }

    for (final segment in segments) {
      final text = segment.text.trim();
      if (text.isEmpty) continue;

      final trocouDePessoa = segment.speaker != speaker;
      final houveSilencio = segment.startMs - endMs > _gapMs;

      if (trocouDePessoa || houveSilencio) {
        flush();
        speaker = segment.speaker;
        startMs = segment.startMs;
      }

      // O espaço entre dois trechos vai no fim do pedaço anterior — a mesma
      // regra do `_join`, para os pedaços somarem o mesmo texto.
      if (buffer.isNotEmpty && !_startsWithPunctuation(text)) {
        final last = pieces.removeLast();
        pieces.add(last.withText('${last.text} '));
      }

      buffer.add(text);
      pieces.addAll(_piecesOf(segment, text));
      endMs = segment.endMs;
    }

    flush();
    return List.unmodifiable(turns);
  }

  /// Cola os pedaços num parágrafo.
  ///
  /// Sem espaço antes de pontuação: os pedaços chegam com o espaço na frente
  /// (`" hoje."`), e juntar cru produziria "projeto hoje ." em metade das
  /// frases.
  static String _join(List<String> parts) {
    final buffer = StringBuffer();

    for (final part in parts) {
      final precisaDeEspaco =
          buffer.isNotEmpty && !_startsWithPunctuation(part);

      if (precisaDeEspaco) buffer.write(' ');
      buffer.write(part);
    }

    return buffer.toString();
  }

  static bool _startsWithPunctuation(String text) =>
      text.isNotEmpty && ',.;:!?)]}'.contains(text[0]);

  /// Os pedaços de um trecho, já aparados como o [trimmed] dele.
  ///
  /// Palavras quando elas somam o trecho exato; o trecho inteiro, num pedaço
  /// só, quando não há palavras ou quando elas não batem — o destaque fica
  /// menos fino, mas o texto nunca sai diferente do que se lia antes.
  static List<TimedPiece> _piecesOf(MeetingSegment segment, String trimmed) {
    final whole = [
      TimedPiece(text: trimmed, startMs: segment.startMs, endMs: segment.endMs),
    ];

    final words = segment.words;
    if (words.isEmpty ||
        words.map((word) => word.text).join().trim() != trimmed) {
      return whole;
    }

    final pieces = [
      for (final word in words)
        TimedPiece(text: word.text, startMs: word.startMs, endMs: word.endMs),
    ];

    // Apara a ponta de fora: o espaço antes da primeira palavra e depois da
    // última. Uma palavra que vira vazio (só o espaço) sai da lista.
    pieces[0] = pieces[0].withText(pieces[0].text.trimLeft());
    pieces[pieces.length - 1] = pieces.last.withText(
      pieces.last.text.trimRight(),
    );

    final kept = pieces.where((piece) => piece.text.isNotEmpty).toList();
    return kept.isEmpty ? whole : kept;
  }
}

/// Um pedaço de fala com o relógio dele.
class TimedPiece {
  const TimedPiece({
    required this.text,
    required this.startMs,
    required this.endMs,
  });

  final String text;
  final int startMs;
  final int endMs;

  TimedPiece withText(String text) =>
      TimedPiece(text: text, startMs: startMs, endMs: endMs);
}
