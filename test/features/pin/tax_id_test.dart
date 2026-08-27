import 'dart:math' as math;

import 'package:evergreen/features/pin/models/clipboard_item_type.dart';
import 'package:evergreen/features/pin/models/tax_id.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TaxId.isValid', () {
    test('aceita um CPF de verdade e recusa o mesmo com um dígito trocado', () {
      expect(TaxId.isValid('52998224725', TaxIdKind.cpf), isTrue);
      expect(TaxId.isValid('52998224726', TaxIdKind.cpf), isFalse);
    });

    test('aceita um CNPJ de verdade e recusa o mesmo com um dígito trocado', () {
      expect(TaxId.isValid('11222333000181', TaxIdKind.cnpj), isTrue);
      expect(TaxId.isValid('11222333000182', TaxIdKind.cnpj), isFalse);
    });

    test('recusa dígitos repetidos, que fecham a conta mas não são de ninguém',
        () {
      expect(TaxId.isValid('11111111111', TaxIdKind.cpf), isFalse);
      expect(TaxId.isValid('00000000000', TaxIdKind.cpf), isFalse);
      expect(TaxId.isValid('11111111111111', TaxIdKind.cnpj), isFalse);
      expect(TaxId.isValid('00000000000000', TaxIdKind.cnpj), isFalse);
    });

    test('recusa o que não tem o tamanho do documento', () {
      expect(TaxId.isValid('5299822472', TaxIdKind.cpf), isFalse);
      expect(TaxId.isValid('529.982.247-25', TaxIdKind.cpf), isFalse);
      expect(TaxId.isValid('5299822472a', TaxIdKind.cpf), isFalse);
      expect(TaxId.isValid('1122233300018', TaxIdKind.cnpj), isFalse);
      expect(TaxId.isValid('11.222.333/0001-81', TaxIdKind.cnpj), isFalse);
    });

    test('um documento não vale pela régua do outro', () {
      // As duas contas partilham o `_checkDigit` e discordam só nos pesos: é
      // esta a asserção que prova que os pesos de fato chegaram lá dentro.
      expect(TaxId.isValid('52998224725', TaxIdKind.cnpj), isFalse);
      expect(TaxId.isValid('11222333000181', TaxIdKind.cpf), isFalse);
    });
  });

  group('TaxId.looksLike', () {
    test('reconhece as duas formas de escrever o mesmo CPF', () {
      expect(TaxId.looksLike('529.982.247-25'), TaxIdKind.cpf);
      expect(TaxId.looksLike('52998224725'), TaxIdKind.cpf);
    });

    test('reconhece as duas formas de escrever o mesmo CNPJ', () {
      expect(TaxId.looksLike('11.222.333/0001-81'), TaxIdKind.cnpj);
      expect(TaxId.looksLike('11222333000181'), TaxIdKind.cnpj);
    });

    test('recusa pontuação pela metade', () {
      expect(TaxId.looksLike('529.982.24725'), isNull);
      expect(TaxId.looksLike('529982247-25'), isNull);
      expect(TaxId.looksLike('11.222.3330001-81'), isNull);
      expect(TaxId.looksLike('11222333/0001-81'), isNull);
    });

    test('a barra é do CNPJ e o hífen sozinho não faz um', () {
      expect(TaxId.looksLike('11.222.333-0001/81'), isNull);
    });
  });

  for (final kind in TaxIdKind.values) {
    group('TaxId.generate — ${kind.label}', () {
      test('o gerado é sempre um ${kind.label} para o classificador', () {
        // O teste que amarra as duas pontas: gerador e classificador saem da
        // mesma conta, e é isto que garante que continuem saindo. Um gerador
        // que se desencontrasse produziria números que o próprio Pin guardaria
        // como texto — e a linha desapareceria do filtro que a desenhou.
        for (var i = 0; i < 1000; i++) {
          final generated = TaxId.generate(kind);

          expect(
            ClipboardItemClassifier.classify(generated),
            kind.itemType,
            reason: '$generated não foi reconhecido como ${kind.label}',
          );
        }
      });

      test('sai pontuado, como a Receita escreve', () {
        final pattern = kind == TaxIdKind.cpf
            ? RegExp(r'^\d{3}\.\d{3}\.\d{3}-\d{2}$')
            : RegExp(r'^\d{2}\.\d{3}\.\d{3}/\d{4}-\d{2}$');

        expect(TaxId.generate(kind), matches(pattern));
      });

      test('nunca sai com todos os dígitos iguais', () {
        // Improvável por sorteio, garantido pelo laço de rejeição — e
        // necessário, porque um número assim é justamente o que `isValid`
        // recusa.
        for (var i = 0; i < 1000; i++) {
          final digits = TaxId.generate(kind).replaceAll(RegExp(r'\D'), '');
          expect(digits.split('').toSet().length, greaterThan(1));
        }
      });

      test('com a semente fixa, sorteia sempre o mesmo número', () {
        expect(
          TaxId.generate(kind, random: math.Random(42)),
          TaxId.generate(kind, random: math.Random(42)),
        );
      });

      test('sem semente, dois sorteios seguidos não repetem', () {
        // O que o ⌘G promete: apertar de novo traz outro número.
        final numbers = List.generate(20, (_) => TaxId.generate(kind)).toSet();
        expect(numbers.length, greaterThan(1));
      });
    });
  }
}
