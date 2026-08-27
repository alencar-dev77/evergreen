import 'package:evergreen/features/pin/models/clipboard_item.dart';
import 'package:evergreen/features/pin/models/pin_search.dart';
import 'package:flutter_test/flutter_test.dart';

/// Nota de um item, ou `null` quando ele não casa.
int? scoreOf(ClipboardItem item, String query) =>
    PinSearch.match(item, query)?.score;

ClipboardItem itemWith(String content, {String? alias, DateTime? at}) =>
    ClipboardItem.capture(content, at: at).copyWith(alias: alias);

void main() {
  group('PinSearch — o que casa', () {
    test('query vazia casa com todo mundo, com nota zero', () {
      final item = itemWith('qualquer coisa');

      expect(scoreOf(item, ''), 0);
      expect(scoreOf(item, '   '), 0);
    });

    test('o literal de antes continua casando, ignorando caixa', () {
      final item = itemWith('Senha temporária: xK9#mPz2');

      expect(scoreOf(item, 'SENHA'), isNotNull);
      expect(scoreOf(item, 'xk9'), isNotNull);
      expect(scoreOf(item, 'inexistente'), isNull);
    });

    test('o literal alcança o conteúdo inteiro, não só a linha exibida', () {
      final item = itemWith('primeira linha\nsegunda linha com tesouro');

      expect(item.title, 'primeira linha');
      expect(scoreOf(item, 'tesouro'), isNotNull);
    });

    test('a subsequência acha o que a substring não achava', () {
      final item = itemWith('12345678900', alias: 'chave pix');

      // O caso da issue: as iniciais, com o espaço no meio da lembrança.
      expect(scoreOf(item, 'chv pix'), isNotNull);
      expect(scoreOf(item, 'chpix'), isNotNull);
      expect(scoreOf(item, 'chv'), isNotNull);
    });

    test('a subsequência exige a ordem das letras', () {
      final item = itemWith('12345678900', alias: 'chave pix');

      expect(scoreOf(item, 'xip'), isNull);
    });

    test('a subsequência não é solta sobre o conteúdo inteiro', () {
      // As letras existem espalhadas pelas linhas de baixo, e é exatamente isso
      // que não pode virar um resultado — senão qualquer coisa digitada casaria
      // com qualquer texto longo.
      final item = itemWith('cabeçalho\nzzz a zzz b zzz c zzz');

      expect(scoreOf(item, 'abc'), isNull);
    });

    test('o apelido também casa por subsequência', () {
      final item = itemWith('12345678900', alias: 'chave pix');

      expect(scoreOf(item, 'PIX'), isNotNull);
      expect(scoreOf(item, '123'), isNotNull);
      expect(scoreOf(item, 'inexistente'), isNull);
    });
  });

  group('PinSearch — o quanto casa', () {
    test('apelido ganha de conteúdo, por melhor que o conteúdo case', () {
      final noApelido = itemWith('nada a ver', alias: 'chave pix');
      final noConteudo = itemWith('chave pix');

      // No segundo o termo casa inteiro e no começo — o melhor casamento que
      // existe. Ainda assim o apelido do primeiro pesa mais.
      expect(
        scoreOf(noApelido, 'pix')!,
        greaterThan(scoreOf(noConteudo, 'pix')!),
      );
    });

    test('contíguo ganha de espalhado', () {
      final contiguo = itemWith('chave');
      final espalhado = itemWith('c-h-a-v-e');

      expect(
        scoreOf(contiguo, 'chave')!,
        greaterThan(scoreOf(espalhado, 'chave')!),
      );
    });

    test('começo do campo ganha de começo de palavra, que ganha do meio', () {
      final comeco = itemWith('pix da empresa');
      final palavra = itemWith('chave pix nova');
      final meio = itemWith('umpixqualquer');

      expect(scoreOf(comeco, 'pix')!, greaterThan(scoreOf(palavra, 'pix')!));
      expect(scoreOf(palavra, 'pix')!, greaterThan(scoreOf(meio, 'pix')!));
    });

    test('hífen e sublinhado também começam palavra', () {
      final hifen = itemWith('chave-pix');
      final meio = itemWith('umpixqualquer');

      expect(scoreOf(hifen, 'pix')!, greaterThan(scoreOf(meio, 'pix')!));
    });
  });

  group('PinSearch.spans — onde grifar', () {
    test('sem busca não grifa nada', () {
      expect(PinSearch.spans('chave pix', ''), isEmpty);
    });

    test('o termo contíguo vira um trecho só', () {
      expect(PinSearch.spans('a chave pix', 'chave'), [
        const PinSearchSpan(2, 7),
      ]);
    });

    test('o espalhado vira um trecho por pedaço', () {
      // `ch` no começo, `v` logo à frente, `pix` na segunda palavra.
      expect(PinSearch.spans('chave pix', 'chv pix'), [
        const PinSearchSpan(0, 2),
        const PinSearchSpan(3, 4),
        const PinSearchSpan(6, 9),
      ]);
    });

    test('grifa na caixa do texto, não na do que foi digitado', () {
      expect(PinSearch.spans('Chave PIX', 'pix'), [const PinSearchSpan(6, 9)]);
    });

    test('o que não casa não grifa', () {
      expect(PinSearch.spans('chave pix', 'inexistente'), isEmpty);
    });
  });
}
