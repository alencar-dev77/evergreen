import 'clipboard_item.dart';

/// Um trecho que casou com a busca, em índices do texto original.
class PinSearchSpan {
  const PinSearchSpan(this.start, this.end);

  /// Índice do primeiro caractere, inclusivo.
  final int start;

  /// Índice logo depois do último caractere.
  final int end;

  int get length => end - start;

  @override
  bool operator ==(Object other) =>
      other is PinSearchSpan && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'PinSearchSpan($start, $end)';
}

/// O que a busca encontrou num item.
///
/// Só a nota: onde grifar sai de [PinSearch.spans], que a lista chama por linha
/// visível — carregar os trechos de todos os itens do histórico até o widget
/// seria pagar por uma conta que quase nunca chega à tela.
class PinSearchMatch {
  const PinSearchMatch({required this.score});

  /// Quanto este item combina com o que foi digitado. Maior é melhor.
  final int score;
}

/// A busca do Pin: se um item casa com o que foi digitado, e o quanto ele
/// combina.
///
/// Substituiu o `contains` de substring que existia antes, e a razão é o caso
/// que mais doía: `chv pix` não achava o item apelidado "chave pix", porque a
/// substring exigia as letras juntas e na ordem exata. Quem usa o Pin herdou do
/// Spotlight e do Raycast a expectativa de não precisar digitar o termo inteiro
/// desde o começo — é a regra de busca do `ux.md` da skill de design.
///
/// São dois casamentos, nesta ordem:
///
/// 1. **Substring**, do jeito de antes. Continua sendo o melhor casamento que
///    existe, e por isso vale mais nota que qualquer outro — quem digita o
///    termo inteiro está dizendo exatamente o que quer.
/// 2. **Subsequência**: as letras da query na ordem, não necessariamente
///    coladas. Os espaços do que foi digitado são ignorados, então `chv pix`
///    procura por `chvpix` e alcança "chave pix".
///
/// Onde cada um procura, e por quê:
///
/// | | apelido | primeira linha | conteúdo inteiro |
/// |---|---|---|---|
/// | substring | sim | sim | sim |
/// | subsequência | sim | sim | **não** |
///
/// A subsequência para na linha exibida de propósito. Ela é frouxa por
/// natureza — quase qualquer punhado de letras aparece espalhado num texto de
/// mil caracteres —, então soltá-la sobre o conteúdo inteiro faria a lista
/// devolver tudo para qualquer coisa digitada. Casar frouxo vale no que a
/// pessoa vê e lembra: o apelido que ela deu e a linha que a lista mostra. O
/// casamento literal continua alcançando o conteúdo inteiro, exatamente como
/// antes — nenhum item que a busca achava deixa de ser achado.
///
/// A nota existe porque casar deixou de ser sim ou não: com fuzzy, quase tudo
/// casa com quase todo mundo, e uma lista sem ordem de relevância seria pior
/// que a busca literal de antes. O que a nota premia, em ordem de peso:
///
/// - **apelido acima de conteúdo** — o apelido é o nome que a pessoa deu ao
///   item justamente para reencontrá-lo, então ele ganha de qualquer casamento
///   no conteúdo, por melhor que este seja;
/// - **substring acima de subsequência** — o casamento contíguo é o que a
///   pessoa provavelmente quis dizer;
/// - **começo acima de meio** — casar no início do campo, ou no início de uma
///   palavra dele, vale mais que casar no miolo;
/// - **junto acima de espalhado** — cada letra que continua a anterior soma.
///
/// Recência não entra na nota: ela é o critério de desempate, e quem desempata
/// é a ordenação da lista (`PinOverlayViewModel`), onde o `copiedAt` já manda.
abstract final class PinSearch {
  /// Quanto o apelido vale a mais que o conteúdo.
  ///
  /// Maior que a nota máxima possível de um casamento no conteúdo, de
  /// propósito: é o que faz "apelido acima de conteúdo" ser uma regra, e não uma
  /// tendência que uma sequência de bônus no conteúdo pudesse virar.
  static const _aliasWeight = 1000;

  /// Casamento contíguo — o que o `contains` de antes achava.
  static const _contiguousBonus = 400;

  /// O casamento começa no primeiro caractere do campo.
  static const _fieldStartBonus = 200;

  /// O casamento começa no início de uma palavra.
  static const _wordStartBonus = 80;

  /// Cada letra que continua a anterior, no casamento espalhado.
  static const _runBonus = 12;

  /// O quanto do trecho percorrido precisa ser das letras digitadas.
  ///
  /// Metade — e este número é o que separa a busca útil da busca que devolve o
  /// histórico inteiro. Subsequência solta acha demais: `pix` "casa" com
  /// "Senha tem**p**orár**i**a: **x**K9" porque as três letras estão lá, na
  /// ordem, separadas por seis que ninguém digitou. Exigir que ao menos metade
  /// do caminho entre a primeira e a última letra seja do que foi digitado
  /// derruba esse tipo de casamento e mantém os que a pessoa reconhece:
  /// `chv` → "chave" (3 de 4) e `chv pix` → "chave pix" (6 de 9).
  ///
  /// Vale só para o casamento espalhado. O literal não passa por aqui — quem
  /// digitou o termo inteiro já disse o que queria.
  static const _minDensity = 2;

  /// Casa [query] contra [item]. Devolve `null` quando não casa.
  ///
  /// Query vazia casa com todo mundo, com nota zero: é a lista em repouso, e
  /// nela quem ordena continua sendo o banco.
  static PinSearchMatch? match(ClipboardItem item, String query) {
    if (query.trim().isEmpty) return const PinSearchMatch(score: 0);

    if (item.hasAlias) {
      final alias = _score(item.alias!, query);
      if (alias != null) return PinSearchMatch(score: alias + _aliasWeight);
    }

    final title = _score(item.title, query);
    if (title != null) return PinSearchMatch(score: title);

    // Fora da linha exibida, só o literal — ver a tabela na classe.
    final rest = _scoreContiguous(
      item.searchableContent.toLowerCase(),
      query,
    );
    if (rest != null) return PinSearchMatch(score: rest);

    return null;
  }

  /// Os trechos grifados de um texto, para quem precisa desenhar.
  ///
  /// A lista chama isto por linha, com o texto que ela já tem na mão — mais
  /// barato do que carregar os trechos de cada item pelo estado até o widget, e
  /// mantém a nota, que é do domínio, fora do desenho.
  static List<PinSearchSpan> spans(String text, String query) {
    if (query.trim().isEmpty || text.isEmpty) return const [];

    final haystack = text.toLowerCase();

    return _contiguous(haystack, query)?.spans ??
        _scattered(haystack, query)?.spans ??
        const [];
  }

  /// A nota de um campo, pelos dois casamentos.
  static int? _score(String text, String query) {
    if (text.isEmpty) return null;

    final haystack = text.toLowerCase();

    return (_contiguous(haystack, query) ?? _scattered(haystack, query))?.score;
  }

  /// A nota de um campo, só pelo casamento literal.
  static int? _scoreContiguous(String haystack, String query) {
    return _contiguous(haystack, query)?.score;
  }

  /// O termo inteiro, colado, em algum lugar do texto.
  static _FieldMatch? _contiguous(String haystack, String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return null;

    final at = haystack.indexOf(needle);
    if (at < 0) return null;

    return _FieldMatch(
      score: _contiguousBonus + _positionBonus(haystack, at),
      spans: [PinSearchSpan(at, at + needle.length)],
    );
  }

  /// As letras da query na ordem, aceitando buracos entre elas.
  ///
  /// Guloso da esquerda para a direita: a primeira ocorrência de cada letra
  /// depois da anterior. Não é o casamento ótimo — um algoritmo tipo `fzf`
  /// tentaria as combinações e escolheria a mais compacta —, mas é linear e
  /// previsível, e num apelido de duas palavras ou numa linha de lista a
  /// diferença não chega à tela.
  static _FieldMatch? _scattered(String haystack, String query) {
    // Sem os espaços: quem digita `chv pix` está descrevendo "chave pix" pelas
    // iniciais, e o espaço ali separa as palavras da lembrança, não as do texto.
    final needle = query.replaceAll(RegExp(r'\s+'), '').toLowerCase();
    if (needle.isEmpty) return null;

    final spans = <PinSearchSpan>[];
    var runs = 0;
    var cursor = 0;
    var spanStart = -1;
    var previous = -2;

    for (var i = 0; i < needle.length; i++) {
      final at = haystack.indexOf(needle[i], cursor);
      if (at < 0) return null;

      if (at == previous + 1) {
        runs++;
      } else {
        if (spanStart >= 0) spans.add(PinSearchSpan(spanStart, previous + 1));
        spanStart = at;
      }

      previous = at;
      cursor = at + 1;
    }

    spans.add(PinSearchSpan(spanStart, previous + 1));

    // Denso o bastante para ser o que a pessoa quis dizer — ver [_minDensity].
    final region = previous + 1 - spans.first.start;
    if (needle.length * _minDensity < region) return null;

    return _FieldMatch(
      score: runs * _runBonus + _positionBonus(haystack, spans.first.start),
      spans: spans,
    );
  }

  /// O quanto começar ali vale.
  static int _positionBonus(String haystack, int at) {
    if (at == 0) return _fieldStartBonus;

    return _isWordBoundary(haystack, at) ? _wordStartBonus : 0;
  }

  /// O caractere anterior separa palavras?
  ///
  /// Tudo o que não é letra nem dígito: vale para `chave-pix` e `chave_pix` do
  /// mesmo jeito que para o espaço.
  static final _wordCharacter = RegExp(r'[a-z0-9]');

  static bool _isWordBoundary(String haystack, int at) =>
      !_wordCharacter.hasMatch(haystack[at - 1]);
}

/// O casamento dentro de um campo, antes de o apelido pesar.
class _FieldMatch {
  const _FieldMatch({required this.score, required this.spans});

  final int score;
  final List<PinSearchSpan> spans;
}
