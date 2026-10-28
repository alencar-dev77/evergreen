import '../../../shared/utils/text_fold.dart';
import 'meeting_segment.dart';

/// Tira da sua faixa o que na verdade era a caixa de som.
///
/// Com a reunião saindo por alto-falante, o microfone escuta de volta o que o
/// computador está tocando. A mesma fala entra nas duas faixas, e o Echo passa
/// a mostrar a fala dos outros duas vezes — uma como "Reunião" e outra como
/// "Você". Isso destrói exatamente aquilo que o módulo promete: saber quem
/// falou.
///
/// Desde outubro de 2026 o eco sai antes, no som (`EchoCanceller.swift`). Este
/// filtro ficou de rede para o que escapar de lá — a fala por cima de alguém,
/// em que o som não dá para separar, e as reuniões gravadas antes disso.
///
/// Quem manda é a faixa do sistema: ela vem do fluxo de áudio antes de virar
/// som no ar, sem passar por caixa nem por microfone nenhum. Se as palavras de
/// um trecho seu coincidem no tempo **e** no texto com palavras da reunião,
/// elas são eco — e saem.
///
/// A comparação é palavra a palavra, pelo relógio de cada uma, contra tudo o
/// que a reunião disse naquele instante. Comparar um trecho com outro trecho,
/// e palavra exata com palavra exata, deixava passar quase tudo: o
/// reconhecimento fecha os trechos em lugares diferentes nas duas faixas, e
/// ouve a mesma fala de jeitos diferentes — "Interno" de um lado e "Interna"
/// do outro, um número inteiro de um e partido em três do outro.
///
/// Fica em Dart, e não no Swift, porque é a única parte disso que é decisão
/// sobre texto: dá para testar sem microfone, sem caixa de som e sem reunião.
abstract final class CrossTalkFilter {
  /// Folga entre uma palavra sua e a mesma palavra na reunião.
  ///
  /// O eco chega uns 50 ms depois, e o reconhecimento marca o começo de cada
  /// palavra com o erro dele, diferente em cada faixa. Um segundo cobre os
  /// dois com sobra; responder com a mesma palavra que acabou de ouvir leva
  /// mais que isso.
  static const _wordToleranceMs = 1000;

  /// A mesma folga, para reuniões sem o relógio de cada palavra: lá só se
  /// sabe onde o trecho começa e termina.
  static const _segmentToleranceMs = 2000;

  /// Quanto do trecho — em letras, não em palavras — precisa ser eco para o
  /// trecho inteiro sair.
  ///
  /// Não é 1.0 porque o eco chega degradado: o reconhecimento erra palavras no
  /// que voltou pela sala que acertou no áudio limpo. Também não é baixo demais
  /// — duas pessoas concordando ("isso, exatamente") diriam palavras iguais sem
  /// que uma fosse eco da outra.
  static const _echoShare = 0.6;

  /// Menos letras que isso não é prova de nada: "é", "o", "que" aparecem em
  /// toda fala, e um "é" seu dito junto com um "é" da reunião é conversa.
  ///
  /// E o trecho só sai inteiro se pelo menos uma das palavras que casaram
  /// tiver esse tamanho, ou for um número: "bom dia" ou "isso mesmo" ditos
  /// junto com alguém somam letras de sobra e são cumprimento, não eco.
  static const _minimumEchoLetters = 4;

  /// Quantas palavras seguidas precisam ser eco para saírem do meio de um
  /// trecho que, no conjunto, é seu.
  static const _minimumEchoRun = 3;

  /// Quanto duas palavras precisam se parecer para serem a mesma ouvida duas
  /// vezes: "interno" e "interna", "direta" e "dieta".
  static const _wordSimilarity = 0.7;

  /// Quanto dos algarismos de um número seu precisa estar, na mesma ordem,
  /// nos algarismos que a reunião disse naquele instante.
  static const _digitSimilarity = 0.75;

  /// Devolve os trechos sem o eco da caixa de som.
  static List<MeetingSegment> clean(List<MeetingSegment> segments) {
    // Em ordem de início, para cada palavra sua olhar só a vizinhança dela —
    // numa reunião de duas horas são dezenas de milhares de palavras de cada
    // lado, e a conta corre na janela 0.
    final others = _Timeline([
      for (final segment in segments)
        if (segment.speaker == Speaker.others) ..._timedTokens(segment),
    ]);

    if (others.tokens.isEmpty) return segments;

    return [
      for (final segment in segments)
        if (segment.speaker != Speaker.me)
          segment
        else
          ?_withoutEcho(segment, others),
    ];
  }

  /// O trecho sem o eco: inteiro, partido, ou `null` quando era todo eco.
  static MeetingSegment? _withoutEcho(
    MeetingSegment segment,
    _Timeline others,
  ) {
    final pieces = segment.words.isEmpty
        ? [_Piece.whole(segment)]
        : [for (final word in segment.words) _Piece.word(word)];

    final tolerance = segment.words.isEmpty
        ? _segmentToleranceMs
        : _wordToleranceMs;

    for (final piece in pieces) {
      piece.echo = _isEcho(piece, others, tolerance);
    }

    final letters = pieces.fold(0, (sum, piece) => sum + piece.letters);
    final echoLetters = pieces
        .where((piece) => piece.echo)
        .fold(0, (sum, piece) => sum + piece.letters);
    final hasStrongEcho = pieces.any(
      (piece) => piece.echo && piece.tokens.any(_isStrong),
    );

    if (hasStrongEcho &&
        echoLetters >= _minimumEchoLetters &&
        echoLetters >= letters * _echoShare) {
      return null;
    }

    if (segment.words.isEmpty) return segment;

    // Um trecho seu com eco dentro: saem só as sequências longas de eco. Uma
    // palavra solta que casou é mais provável que seja sua.
    final kept = <MeetingWord>[];
    var start = 0;
    while (start < pieces.length) {
      var end = start;
      while (end < pieces.length && pieces[end].echo == pieces[start].echo) {
        end++;
      }

      final run = pieces.sublist(start, end);
      final echoRun =
          run.first.echo &&
          run.where((piece) => piece.letters > 0).length >= _minimumEchoRun &&
          run.any((piece) => piece.tokens.any(_isStrong));
      if (!echoRun) kept.addAll(run.map((piece) => piece.word!));
      start = end;
    }

    if (kept.length == segment.words.length) return segment;
    if (kept.every((word) => _tokens(word.text).isEmpty)) return null;

    return MeetingSegment(
      speaker: segment.speaker,
      startMs: kept.first.startMs,
      endMs: kept.last.endMs,
      text: kept.map((word) => word.text).join().trim(),
      words: kept,
      voice: segment.voice,
    );
  }

  /// Um pedaço do trecho é eco quando cada palavra dele aparece na reunião,
  /// perto o bastante no tempo.
  ///
  /// Pedaço sem palavra (pontuação solta) não decide nada: herda "eco", para
  /// não partir uma sequência de eco em duas.
  static bool _isEcho(_Piece piece, _Timeline others, int tolerance) {
    if (piece.tokens.isEmpty) return true;

    // A primeira palavra da reunião que pode estar perto: as que começam
    // antes disso terminaram antes também, porque nenhuma dura mais que o
    // trecho dela.
    final tokens = others.tokens;
    final from = piece.startMs - tolerance - others.longest;
    var low = 0, high = tokens.length;
    while (low < high) {
      final middle = (low + high) ~/ 2;
      if (tokens[middle].startMs < from) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }

    final near = <String>[];
    for (var index = low; index < tokens.length; index++) {
      final other = tokens[index];
      if (other.startMs - tolerance >= piece.endMs) break;
      if (piece.startMs - tolerance < other.endMs) near.add(other.token);
    }
    if (near.isEmpty) return false;

    // Os algarismos que a reunião disse ali, juntos e em ordem: "1234 5678
    // 90" de um lado é "1234567890" do outro.
    final digits = near.where(_isNumber).join();

    var matched = 0;
    for (final token in piece.tokens) {
      if (_isNumber(token)) {
        if (digits.isNotEmpty &&
            _commonSubsequence(token, digits) >=
                token.length * _digitSimilarity) {
          matched += token.length;
        }
      } else if (near.any((other) => _sameWord(token, other))) {
        matched += token.length;
      }
    }

    return matched >= piece.letters * _echoShare;
  }

  /// A palavra que, sozinha, já diz alguma coisa: quatro letras ou mais, ou
  /// um número.
  static bool _isStrong(String token) =>
      token.length >= _minimumEchoLetters || _isNumber(token);

  static bool _sameWord(String a, String b) {
    if (a == b) return true;
    if (a.length < 4 || b.length < 4) return false;

    final longest = a.length > b.length ? a.length : b.length;
    return 1 - _editDistance(a, b) / longest >= _wordSimilarity;
  }

  static bool _isNumber(String token) => _digit.hasMatch(token);

  static final _digit = RegExp(r'^[0-9]+$');

  static int _editDistance(String a, String b) {
    var previous = List<int>.generate(b.length + 1, (index) => index);

    for (var i = 1; i <= a.length; i++) {
      final current = List<int>.filled(b.length + 1, 0)..[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        final deletion = previous[j] + 1;
        final insertion = current[j - 1] + 1;
        final substitution = previous[j - 1] + cost;
        current[j] = deletion < insertion
            ? (deletion < substitution ? deletion : substitution)
            : (insertion < substitution ? insertion : substitution);
      }
      previous = current;
    }

    return previous[b.length];
  }

  /// O tamanho da maior sequência de algarismos de `a` que aparece, na mesma
  /// ordem, em `b`.
  static int _commonSubsequence(String a, String b) {
    var previous = List<int>.filled(b.length + 1, 0);

    for (var i = 1; i <= a.length; i++) {
      final current = List<int>.filled(b.length + 1, 0);
      for (var j = 1; j <= b.length; j++) {
        current[j] = a[i - 1] == b[j - 1]
            ? previous[j - 1] + 1
            : (previous[j] > current[j - 1] ? previous[j] : current[j - 1]);
      }
      previous = current;
    }

    return previous[b.length];
  }

  /// As palavras de um trecho da reunião, cada uma com o relógio dela.
  ///
  /// Sem o relógio das palavras (reunião antiga), cada uma ganha a fatia do
  /// trecho que lhe cabe — o que basta, porque aí a folga é a do trecho.
  static List<_TimedToken> _timedTokens(MeetingSegment segment) {
    if (segment.words.isNotEmpty) {
      return [
        for (final word in segment.words)
          for (final token in _tokens(word.text))
            _TimedToken(word.startMs, word.endMs, token),
      ];
    }

    final tokens = _tokens(segment.text);
    if (tokens.isEmpty) return const [];

    final slice = (segment.endMs - segment.startMs) / tokens.length;
    return [
      for (var index = 0; index < tokens.length; index++)
        _TimedToken(
          segment.startMs + (slice * index).round(),
          segment.startMs + (slice * (index + 1)).round(),
          tokens[index],
        ),
    ];
  }

  static final _nonWord = RegExp(r'[^\p{L}\p{N}]+', unicode: true);

  static List<String> _tokens(String text) => TextFold.fold(
    text,
  ).split(_nonWord).where((token) => token.isNotEmpty).toList(growable: false);
}

/// As palavras da reunião em ordem de início, e a duração da mais longa —
/// o que deixa cada palavra sua olhar só a vizinhança dela.
class _Timeline {
  _Timeline(List<_TimedToken> tokens)
    : tokens = tokens..sort((a, b) => a.startMs.compareTo(b.startMs)),
      longest = tokens.fold(0, (longest, token) {
        final length = token.endMs - token.startMs;
        return length > longest ? length : longest;
      });

  final List<_TimedToken> tokens;
  final int longest;
}

class _TimedToken {
  const _TimedToken(this.startMs, this.endMs, this.token);

  final int startMs;
  final int endMs;
  final String token;
}

/// Um pedaço de um trecho seu sob julgamento: uma palavra, ou o trecho
/// inteiro quando não há relógio das palavras.
class _Piece {
  _Piece.word(MeetingWord this.word)
    : startMs = word.startMs,
      endMs = word.endMs,
      tokens = CrossTalkFilter._tokens(word.text);

  _Piece.whole(MeetingSegment segment)
    : word = null,
      startMs = segment.startMs,
      endMs = segment.endMs,
      tokens = CrossTalkFilter._tokens(segment.text);

  final MeetingWord? word;
  final int startMs;
  final int endMs;
  final List<String> tokens;
  bool echo = false;

  int get letters => tokens.fold(0, (sum, token) => sum + token.length);
}
