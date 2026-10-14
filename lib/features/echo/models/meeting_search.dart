import '../../../shared/utils/text_fold.dart';
import 'meeting.dart';
import 'meeting_turn.dart';

/// Um trecho grifado de um texto: `[start, end)`, em posições do texto
/// original — o dobrado tem o mesmo comprimento (ver [TextFold]).
class MatchRange {
  const MatchRange(this.start, this.end);

  final int start;
  final int end;

  MatchRange shift(int by) => MatchRange(start + by, end + by);

  @override
  bool operator ==(Object other) =>
      other is MatchRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => '[$start, $end)';
}

/// O que foi digitado, já do jeito que se compara.
///
/// Palavras, e não a frase inteira: "orçamento sexta" acha a reunião em que
/// se falou do orçamento num minuto e da sexta no outro. Cada palavra casa
/// pelo **começo** de uma palavra do texto, sem ligar para acento nem
/// maiúscula — "orcam" acha "Orçamento", e "custo" não acha "acusto".
class MeetingQuery {
  MeetingQuery._(this.terms, this.phrase);

  /// Dobra e quebra [raw] em palavras.
  ///
  /// Palavra de uma letra só não entra: "a", "e" e "o" começam metade das
  /// palavras do português, e uma letra sozinha casaria com todas as reuniões
  /// — uma resposta que não responde nada, e a mais cara de calcular. A busca
  /// começa na segunda letra; até lá a lista continua a de sempre.
  factory MeetingQuery.parse(String raw) {
    final terms = <String>{
      for (final word in TextFold.fold(raw).split(_separator))
        if (word.length > 1) word,
    }.toList(growable: false);

    return MeetingQuery._(terms, terms.join(' '));
  }

  final List<String> terms;

  /// As palavras na ordem digitada, para o bônus de quem as diz juntas.
  final String phrase;

  bool get isEmpty => terms.isEmpty;

  static final _separator = RegExp(r'[^a-z0-9]+');
}

enum MeetingHitKind { summary, transcript }

/// Um trecho de uma reunião em que a busca casou.
class MeetingHit {
  const MeetingHit({
    required this.kind,
    required this.snippet,
    required this.marks,
    required this.coverage,
    this.atMs,
    this.turnStartMs,
    this.speaker,
  });

  final MeetingHitKind kind;

  /// O pedaço do texto em volta do que casou — com reticências quando foi
  /// cortado — e o que grifar nele.
  final String snippet;
  final List<MatchRange> marks;

  /// Quantas palavras da busca este trecho tem.
  final int coverage;

  /// Onde a primeira palavra casada soa — é para lá que o áudio vai. `null` no
  /// resumo, que não tem relógio.
  final int? atMs;

  /// O começo da fala inteira, para o relógio que a linha mostra e para a
  /// leitura achar o parágrafo.
  final int? turnStartMs;

  /// Quem falou, já com o nome — ver `Speaker.labelFor`.
  final String? speaker;

  /// `12:03` — o relógio da fala dentro da reunião.
  String? get timestamp {
    final ms = turnStartMs;
    if (ms == null) return null;

    final seconds = ms ~/ 1000;
    return '${(seconds ~/ 60).toString().padLeft(2, '0')}:'
        '${(seconds % 60).toString().padLeft(2, '0')}';
  }
}

/// Uma reunião que casou, com os trechos que valem a pena mostrar.
class MeetingSearchResult {
  const MeetingSearchResult({
    required this.meeting,
    required this.score,
    required this.titleMarks,
    required this.hits,
    required this.hitCount,
  });

  final Meeting meeting;
  final int score;
  final List<MatchRange> titleMarks;

  /// Os melhores trechos, no máximo [MeetingSearch.shownHits], na ordem em
  /// que aparecem na reunião — o resumo primeiro, depois a conversa.
  final List<MeetingHit> hits;

  /// Quantos trechos casaram ao todo, mostrados ou não.
  final int hitCount;
}

/// A busca em todas as reuniões de uma vez.
///
/// Mora fora de cada reunião porque quase nunca se sabe *em qual* delas algo
/// foi dito — a pergunta é "quando falamos do orçamento?", não "o que a
/// reunião de terça disse do orçamento?". Pelo mesmo motivo de o `PinSearch`
/// morar no domínio, casar e pontuar são uma conta só, e ela é testada sem
/// tela.
///
/// O índice dobra o texto uma vez por lista de reuniões; cada tecla só
/// compara. É o que deixa a busca andar junto com a digitação numa biblioteca
/// de horas de conversa.
class MeetingSearch {
  MeetingSearch._(this._entries);

  factory MeetingSearch.index(List<Meeting> meetings, {String userName = ''}) =>
      MeetingSearch._([
        for (final meeting in meetings) _Entry.of(meeting, userName),
      ]);

  /// Quantos trechos cada reunião mostra na lista de resultados.
  ///
  /// Três: o bastante para reconhecer a reunião pelo que foi dito, pouco o
  /// bastante para a segunda reunião ainda caber na tela. O resto está a um
  /// Enter de distância, grifado na leitura.
  static const shownHits = 3;

  /// Bônus por ter todas as palavras no título — maior que qualquer soma de
  /// trechos, como o apelido do Pin: quem lembra o nome da reunião já disse
  /// qual é.
  static const _titleWeight = 2000;

  /// Bônus por todas as palavras caberem num trecho só. Duas palavras ditas
  /// na mesma fala são quase sempre o assunto; ditas a vinte minutos uma da
  /// outra, coincidência.
  static const _togetherWeight = 600;

  /// Bônus por as palavras aparecerem juntas e na ordem — a frase lembrada.
  static const _phraseWeight = 300;

  /// Cada trecho a mais vale pouco, e só até [_hitCap]: a reunião que repete
  /// a palavra quarenta vezes não é quarenta vezes mais a resposta.
  static const _hitWeight = 10;
  static const _hitCap = 10;

  final List<_Entry> _entries;

  /// As reuniões que têm **todas** as palavras de [raw], da melhor para a
  /// pior; no empate, a mais recente primeiro.
  List<MeetingSearchResult> search(String raw) {
    final query = MeetingQuery.parse(raw);
    if (query.isEmpty) return const [];

    final results = <MeetingSearchResult>[];
    for (final entry in _entries) {
      final result = entry.match(query);
      if (result != null) results.add(result);
    }

    results.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      return byScore != 0
          ? byScore
          : b.meeting.startedAt.compareTo(a.meeting.startedAt);
    });

    return results;
  }

  /// O que grifar em [text] para [raw] — a leitura usa isto para marcar o
  /// termo no resumo e na transcrição enquanto a busca estiver de pé.
  static List<MatchRange> marksIn(String text, String raw) {
    final query = MeetingQuery.parse(raw);
    if (query.isEmpty) return const [];

    return _marks(TextFold.fold(text), query.terms);
  }

  /// Todas as ocorrências de todas as palavras, em ordem e sem sobreposição.
  static List<MatchRange> _marks(String folded, List<String> terms) =>
      _scan(folded, terms).$1;

  /// Os grifos e quais palavras apareceram — numa passada só pelo texto.
  ///
  /// Eram duas: uma para grifar e outra, igual, para contar quais palavras
  /// estavam lá. Numa biblioteca de horas de conversa, a segunda dobrava o
  /// custo de cada tecla.
  static (List<MatchRange>, Set<String>) _scan(
    String folded,
    List<String> terms,
  ) {
    final found = <MatchRange>[];
    final covered = <String>{};

    for (final term in terms) {
      var from = folded.indexOf(term);
      while (from >= 0) {
        if (_isWordStart(folded, from)) {
          found.add(MatchRange(from, from + term.length));
          covered.add(term);
        }
        from = folded.indexOf(term, from + 1);
      }
    }

    found.sort((a, b) {
      final byStart = a.start.compareTo(b.start);
      return byStart != 0 ? byStart : b.end.compareTo(a.end);
    });

    // "orç" e "orçamento" casando no mesmo lugar viram um grifo só.
    final merged = <MatchRange>[];
    for (final range in found) {
      final last = merged.isEmpty ? null : merged.last;
      if (last != null && range.start <= last.end) {
        if (range.end > last.end) {
          merged[merged.length - 1] = MatchRange(last.start, range.end);
        }
        continue;
      }
      merged.add(range);
    }

    return (merged, covered);
  }

  /// O caractere antes não é letra nem número — comparado pelo código, e não
  /// por expressão regular: é o teste que roda a cada ocorrência achada.
  static bool _isWordStart(String folded, int at) {
    if (at == 0) return true;

    final before = folded.codeUnitAt(at - 1);
    final isLetter = before >= 0x61 && before <= 0x7A;
    final isDigit = before >= 0x30 && before <= 0x39;
    return !isLetter && !isDigit;
  }
}

/// Uma reunião com os textos já dobrados.
class _Entry {
  _Entry(this.meeting, this.title, this.units)
    : everything = [title, for (final unit in units) unit.folded].join('\n');

  factory _Entry.of(Meeting meeting, String userName) {
    final summary = meeting.summary ?? '';

    return _Entry(meeting, TextFold.fold(meeting.title), [
      // O resumo em parágrafos: cada linha dele é um assunto, e grifar o
      // resumo inteiro como um trecho só não diria onde está o termo.
      for (final line in summary.split('\n'))
        if (_plain(line).isNotEmpty) _Unit.summary(_plain(line)),
      for (final turn in MeetingTurn.from(meeting.segments))
        _Unit.turn(turn, turn.labelFor(userName)),
    ]);
  }

  final Meeting meeting;
  final String title;
  final List<_Unit> units;

  /// A reunião inteira num texto só, para a recusa rápida: a palavra que não
  /// aparece em lugar nenhum dela dispensa olhar trecho por trecho — e é o
  /// caso da maioria das reuniões, para a maioria das buscas.
  final String everything;

  /// A linha do resumo sem a marca de lista ou de título que o modelo põe —
  /// "- ", "• ", "1. ", "## ". No resultado ela é um trecho, não um tópico, e
  /// o traço solto na frente parecia texto quebrado.
  static String _plain(String line) =>
      line.trim().replaceFirst(_listMarker, '').trim();

  static final _listMarker = RegExp(r'^(?:[-*•]|#{1,6}|\d+[.)])\s+');

  MeetingSearchResult? match(MeetingQuery query) {
    final terms = query.terms;
    if (!terms.every(everything.contains)) return null;

    final (titleMarks, inTitle) = MeetingSearch._scan(title, terms);

    final scored = <(_Unit, List<MatchRange>, int)>[];
    final seen = <String>{...inTitle};

    for (final unit in units) {
      final (marks, covered) = MeetingSearch._scan(unit.folded, terms);
      if (marks.isEmpty) continue;

      seen.addAll(covered);
      scored.add((unit, marks, covered.length));
    }

    // Todas as palavras precisam estar na reunião — em qualquer lugar dela.
    if (seen.length < terms.length) return null;

    final best = scored.fold(0, (top, hit) => hit.$3 > top ? hit.$3 : top);

    // Quando algum trecho tem tudo, só esses contam: os que têm uma palavra
    // solta seriam ruído ao lado deles. Sem nenhum completo, a reunião casou
    // pela soma, e cada trecho mostra a parte dele.
    final kept = best == terms.length
        ? scored.where((hit) => hit.$3 == best).toList()
        : scored;

    final phrase =
        terms.length > 1 &&
        (title.contains(query.phrase) ||
            kept.any((hit) => hit.$1.folded.contains(query.phrase)));

    final score =
        (inTitle.length == terms.length ? MeetingSearch._titleWeight : 0) +
        (best == terms.length && terms.length > 1
            ? MeetingSearch._togetherWeight
            : 0) +
        (phrase ? MeetingSearch._phraseWeight : 0) +
        MeetingSearch._hitWeight *
            (kept.length < MeetingSearch._hitCap
                ? kept.length
                : MeetingSearch._hitCap);

    // Os melhores primeiro, para escolher; depois na ordem da reunião, para
    // ler — o relógio de cada linha só faz sentido subindo.
    final chosen = [...kept]
      ..sort((a, b) => b.$3.compareTo(a.$3))
      ..length = kept.length < MeetingSearch.shownHits
          ? kept.length
          : MeetingSearch.shownHits;
    chosen.sort((a, b) => a.$1.order.compareTo(b.$1.order));

    return MeetingSearchResult(
      meeting: meeting,
      score: score,
      titleMarks: titleMarks,
      hits: [for (final hit in chosen) hit.$1.hit(hit.$2, hit.$3)],
      hitCount: kept.length,
    );
  }
}

/// Um trecho onde procurar: uma linha do resumo ou uma fala da conversa.
class _Unit {
  _Unit._(this.kind, this.text, this.order, {this.turn, this.speaker})
    : folded = TextFold.fold(text);

  _Unit.summary(String text) : this._(MeetingHitKind.summary, text, -1);

  _Unit.turn(MeetingTurn turn, String speaker)
    : this._(
        MeetingHitKind.transcript,
        turn.text,
        turn.startMs,
        turn: turn,
        speaker: speaker,
      );

  final MeetingHitKind kind;
  final String text;
  final String folded;

  /// A posição na reunião: o resumo antes de tudo, a fala pelo relógio.
  final int order;

  final MeetingTurn? turn;
  final String? speaker;

  /// Quanto texto vem antes do primeiro grifo no recorte.
  ///
  /// O bastante para a frase ter de onde começar, pouco o bastante para o
  /// termo ainda caber numa linha de lista.
  static const _lead = 48;

  /// O tamanho do recorte. Uma linha da lista corta antes disso; o resto é
  /// folga para a janela mais larga.
  static const _length = 220;

  MeetingHit hit(List<MatchRange> marks, int coverage) {
    final first = marks.first.start;

    var start = first <= _lead ? 0 : first - _lead;
    // Começa numa palavra inteira, e não no meio de uma.
    if (start > 0) {
      final space = text.indexOf(' ', start);
      start = space < 0 || space >= first ? start : space + 1;
    }
    var end = start + _length >= text.length ? text.length : start + _length;

    // Nunca no meio de um emoji: as posições são de UTF-16, e um emoji são
    // duas. Cortado ao meio, ele vira meio caractere — e o Flutter recusa
    // desenhar o texto inteiro por causa dele.
    if (start > 0 && _isLowSurrogate(text.codeUnitAt(start))) start++;
    if (end < text.length && _isHighSurrogate(text.codeUnitAt(end - 1))) end--;

    final prefix = start > 0 ? '…' : '';
    final suffix = end < text.length ? '…' : '';
    final shift = prefix.length - start;

    return MeetingHit(
      kind: kind,
      snippet: '$prefix${text.substring(start, end)}$suffix',
      marks: [
        for (final mark in marks)
          if (mark.start >= start && mark.end <= end) mark.shift(shift),
      ],
      coverage: coverage,
      atMs: _timeAt(first),
      turnStartMs: turn?.startMs,
      speaker: speaker,
    );
  }

  static bool _isHighSurrogate(int unit) => unit >= 0xD800 && unit <= 0xDBFF;
  static bool _isLowSurrogate(int unit) => unit >= 0xDC00 && unit <= 0xDFFF;

  /// Quando soa o caractere [offset] da fala — pelo pedaço que o contém.
  ///
  /// Os pedaços da fala somam exatamente o texto dela (ver
  /// `MeetingTurn.pieces`), então a posição no texto é uma posição na fila
  /// de pedaços.
  int? _timeAt(int offset) {
    final turn = this.turn;
    if (turn == null) return null;

    var cursor = 0;
    for (final piece in turn.pieces) {
      cursor += piece.text.length;
      if (offset < cursor) return piece.startMs;
    }

    return turn.startMs;
  }
}
