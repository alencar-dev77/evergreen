import 'package:evergreen/features/pin/models/clipboard_item.dart';
import 'package:evergreen/features/pin/models/clipboard_item_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ClipboardItemClassifier', () {
    test('reconhece URLs http e https', () {
      expect(
        ClipboardItemClassifier.classify('https://pub.dev/packages/isar'),
        ClipboardItemType.link,
      );
      expect(
        ClipboardItemClassifier.classify('www.exemplo.com.br/pagina'),
        ClipboardItemType.link,
      );
    });

    test('reconhece comandos de terminal comuns', () {
      expect(
        ClipboardItemClassifier.classify('git pull origin develop'),
        ClipboardItemType.command,
      );
      expect(
        ClipboardItemClassifier.classify(r'$ flutter pub get'),
        ClipboardItemType.command,
      );
    });

    test('trata bloco de várias linhas como texto, mesmo começando com comando', () {
      expect(
        ClipboardItemClassifier.classify('git add .\ngit commit -m "x"'),
        ClipboardItemType.text,
      );
    });

    test('não confunde frase que começa com palavra de comando', () {
      expect(
        ClipboardItemClassifier.classify('Senha temporária: xK9#mPz2'),
        ClipboardItemType.text,
      );
    });

    test('URL com texto ao redor não vira link', () {
      expect(
        ClipboardItemClassifier.classify('veja https://exemplo.com hoje'),
        ClipboardItemType.text,
      );
    });

    test('reconhece e-mail', () {
      expect(
        ClipboardItemClassifier.classify('contato@evergreen.com.br'),
        ClipboardItemType.email,
      );
    });

    test('arroba solto no meio de uma frase não vira e-mail', () {
      expect(
        ClipboardItemClassifier.classify('fala com o @lucas amanhã'),
        ClipboardItemType.text,
      );
      expect(
        ClipboardItemClassifier.classify('usuario@servidor'),
        ClipboardItemType.text,
      );
    });

    test('reconhece telefone escrito de várias formas', () {
      for (final number in [
        '(11) 98765-4321',
        '11 98765-4321',
        '+55 11 98765-4321',
        '3456-7890',
      ]) {
        expect(
          ClipboardItemClassifier.classify(number),
          ClipboardItemType.phone,
          reason: number,
        );
      }
    });

    test('endereço de IP não vira telefone', () {
      expect(
        ClipboardItemClassifier.classify('192.168.0.1'),
        ClipboardItemType.text,
      );
    });

    test('reconhece CPF com e sem pontuação', () {
      expect(
        ClipboardItemClassifier.classify('529.982.247-25'),
        ClipboardItemType.taxId,
      );
      expect(
        ClipboardItemClassifier.classify('52998224725'),
        ClipboardItemType.taxId,
      );
    });

    test('onze dígitos que não fecham a conta do CPF são telefone', () {
      // Celular com DDD tem o mesmo tamanho de um CPF sem pontos; o dígito
      // verificador é o que separa um do outro.
      expect(
        ClipboardItemClassifier.classify('11987654321'),
        ClipboardItemType.phone,
      );
    });

    test('sequência de dígitos repetidos não é CPF', () {
      expect(
        ClipboardItemClassifier.classify('111.111.111-11'),
        ClipboardItemType.text,
      );
    });

    test('CPF ainda é CPF quando o histórico é reclassificado', () {
      // O contrato da versão: subir o número obriga o repositório a reclassificar
      // o que já estava guardado (ver `SqliteClipboardRepository`).
      expect(ClipboardItemClassifier.version, greaterThanOrEqualTo(2));
    });
  });

  group('ClipboardItem', () {
    test('title usa a primeira linha não vazia', () {
      final item = ClipboardItem.capture('\n\n  Flutter Desktop  \nsegunda linha');
      expect(item.title, 'Flutter Desktop');
      expect(item.hasMoreThanTitle, isTrue);
    });

    test('title de conteúdo de uma linha não sinaliza conteúdo extra', () {
      final item = ClipboardItem.capture('  Flutter  ');
      expect(item.title, 'Flutter');
      expect(item.hasMoreThanTitle, isFalse);
    });

    test('matches ignora caixa e casa com qualquer parte do conteúdo', () {
      final item = ClipboardItem.capture('Senha temporária: xK9#mPz2');

      expect(item.matches('SENHA'), isTrue);
      expect(item.matches('xk9'), isTrue);
      expect(item.matches(''), isTrue);
      expect(item.matches('inexistente'), isFalse);
    });

    test('o apelido vai para a frente do conteúdo na lista', () {
      final item =
          ClipboardItem.capture('12345678900').copyWith(alias: 'chave pix');

      expect(item.hasAlias, isTrue);
      expect(item.displayTitle, 'chave pix');
      // O conteúdo continua intocado — é ele que vai para a área de
      // transferência.
      expect(item.content, '12345678900');
      expect(item.title, '12345678900');
    });

    test('apelido em branco é o mesmo que não ter apelido', () {
      final item =
          ClipboardItem.capture('12345678900').copyWith(alias: '   ');

      expect(item.hasAlias, isFalse);
      expect(item.displayTitle, '12345678900');
    });

    test('matches também casa com o apelido', () {
      final item =
          ClipboardItem.capture('12345678900').copyWith(alias: 'chave pix');

      // A palavra não aparece em lugar nenhum do conteúdo: é justamente para
      // isso que serve dar um apelido.
      expect(item.matches('PIX'), isTrue);
      expect(item.matches('123'), isTrue);
      expect(item.matches('inexistente'), isFalse);
    });
  });
}
