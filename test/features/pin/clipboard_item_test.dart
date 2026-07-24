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
  });
}
