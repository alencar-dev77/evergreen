import 'dart:math' as math;

import 'package:evergreen/features/pin/models/clipboard_item_type.dart';
import 'package:evergreen/features/pin/models/tax_id.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TaxId.isValid', () {
    test('aceita um CPF de verdade e recusa o mesmo com um dígito trocado', () {
      expect(TaxId.isValid('52998224725'), isTrue);
      expect(TaxId.isValid('52998224726'), isFalse);
    });

    test('recusa dígitos repetidos, que fecham a conta mas não são de ninguém',
        () {
      expect(TaxId.isValid('11111111111'), isFalse);
      expect(TaxId.isValid('00000000000'), isFalse);
    });

    test('recusa o que não são onze dígitos', () {
      expect(TaxId.isValid('5299822472'), isFalse);
      expect(TaxId.isValid('529.982.247-25'), isFalse);
      expect(TaxId.isValid('5299822472a'), isFalse);
    });
  });

  group('TaxId.looksLike', () {
    test('reconhece as duas formas de escrever o mesmo número', () {
      expect(TaxId.looksLike('529.982.247-25'), isTrue);
      expect(TaxId.looksLike('52998224725'), isTrue);
    });

    test('recusa pontuação pela metade', () {
      expect(TaxId.looksLike('529.982.24725'), isFalse);
      expect(TaxId.looksLike('529982247-25'), isFalse);
    });
  });

  group('TaxId.generate', () {
    test('o gerado é sempre um CPF para o classificador', () {
      // O teste que amarra as duas pontas: gerador e classificador saem da
      // mesma conta, e é isto que garante que continuem saindo. Um gerador que
      // se desencontrasse produziria números que o próprio Pin guardaria como
      // texto — e a linha desapareceria do filtro que a desenhou.
      for (var i = 0; i < 1000; i++) {
        final generated = TaxId.generate();

        expect(
          ClipboardItemClassifier.classify(generated),
          ClipboardItemType.taxId,
          reason: '$generated não foi reconhecido como CPF',
        );
      }
    });

    test('sai pontuado, como a Receita escreve', () {
      expect(TaxId.generate(), matches(RegExp(r'^\d{3}\.\d{3}\.\d{3}-\d{2}$')));
    });

    test('nunca sai com os onze dígitos iguais', () {
      // Improvável por sorteio, garantido pelo laço de rejeição — e necessário,
      // porque um número assim é justamente o que `isValid` recusa.
      for (var i = 0; i < 1000; i++) {
        final digits = TaxId.generate().replaceAll(RegExp(r'\D'), '');
        expect(digits.split('').toSet().length, greaterThan(1));
      }
    });

    test('com a semente fixa, sorteia sempre o mesmo número', () {
      expect(
        TaxId.generate(random: math.Random(42)),
        TaxId.generate(random: math.Random(42)),
      );
    });

    test('sem semente, dois sorteios seguidos não repetem', () {
      // O que o ⌘G promete: apertar de novo traz outro número.
      final numbers = List.generate(20, (_) => TaxId.generate()).toSet();
      expect(numbers.length, greaterThan(1));
    });
  });
}
