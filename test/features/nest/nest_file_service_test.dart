import 'dart:io';

import 'package:evergreen/features/nest/data/nest_file_service.dart';
import 'package:evergreen/features/nest/models/nest_destination.dart';
import 'package:evergreen/features/nest/models/nest_item.dart';
import 'package:evergreen/features/nest/models/nest_transfer_mode.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// O disco de verdade, numa pasta temporária.
///
/// Sem imitação aqui de propósito: o que este serviço faz de interessante é
/// justamente o que o sistema de arquivos responde — nome ocupado, pasta com
/// conteúdo, original que sumiu enquanto esperava na prateleira.
void main() {
  late Directory root;
  late Directory origin;
  late Directory target;
  late LocalNestFileService service;
  late NestDestination destination;

  final now = DateTime(2026, 8, 28, 14, 30);

  setUp(() {
    root = Directory.systemTemp.createTempSync('nest_test');
    origin = Directory(p.join(root.path, 'origem'))..createSync();
    target = Directory(p.join(root.path, 'destino'))..createSync();
    service = LocalNestFileService(clock: () => now);
    destination = NestDestination(path: target.path);
  });

  tearDown(() => root.deleteSync(recursive: true));

  Future<NestItem> writeFile(String name, [String content = 'conteúdo']) async {
    File(p.join(origin.path, name)).writeAsStringSync(content);
    return (await service.inspect(p.join(origin.path, name)))!;
  }

  group('inspect', () {
    test('devolve nulo quando não há nada no caminho', () async {
      expect(await service.inspect(p.join(origin.path, 'fantasma')), isNull);
    });

    test(
      'pasta não é medida — o cartão mostra "Pasta", não um número',
      () async {
        final path = p.join(origin.path, 'álbum');
        Directory(path).createSync();
        File(p.join(path, 'foto.jpg')).writeAsStringSync('12345');

        final item = await service.inspect(path);

        expect(item!.isDirectory, isTrue);
        expect(item.sizeInBytes, 0);
      },
    );
  });

  group('copiar', () {
    test('deixa o original onde estava', () async {
      final item = await writeFile('nota.txt');

      final transfer = await service.send(
        items: [item],
        destination: destination,
        mode: NestTransferMode.copy,
      );

      expect(transfer.fileCount, 1);
      expect(File(item.path).existsSync(), isTrue);
      expect(File(p.join(target.path, 'nota.txt')).existsSync(), isTrue);
    });

    test('pasta com conteúdo vai inteira', () async {
      final folder = Directory(p.join(origin.path, 'álbum'))..createSync();
      Directory(p.join(folder.path, 'dentro')).createSync();
      File(p.join(folder.path, 'dentro', 'foto.jpg')).writeAsStringSync('img');

      final item = (await service.inspect(folder.path))!;

      await service.send(
        items: [item],
        destination: destination,
        mode: NestTransferMode.copy,
      );

      expect(
        File(p.join(target.path, 'álbum', 'dentro', 'foto.jpg')).existsSync(),
        isTrue,
      );
    });
  });

  group('mover', () {
    test('leva o original junto', () async {
      final item = await writeFile('nota.txt');

      await service.send(
        items: [item],
        destination: destination,
        mode: NestTransferMode.move,
      );

      expect(File(item.path).existsSync(), isFalse);
      expect(File(p.join(target.path, 'nota.txt')).existsSync(), isTrue);
    });
  });

  group('nome já ocupado', () {
    test('vira "nome 2", como no Finder — nada é sobrescrito', () async {
      File(
        p.join(target.path, 'nota.txt'),
      ).writeAsStringSync('o que já estava');
      final item = await writeFile('nota.txt', 'o que chegou');

      final transfer = await service.send(
        items: [item],
        destination: destination,
        mode: NestTransferMode.copy,
      );

      expect(
        File(p.join(target.path, 'nota.txt')).readAsStringSync(),
        'o que já estava',
      );
      expect(
        File(p.join(target.path, 'nota 2.txt')).readAsStringSync(),
        'o que chegou',
      );
      expect(transfer.movements.single.destination, endsWith('nota 2.txt'));
    });

    test('sem extensão o sufixo vai no fim mesmo assim', () async {
      Directory(p.join(target.path, 'pasta')).createSync();
      final folder = Directory(p.join(origin.path, 'pasta'))..createSync();

      await service.send(
        items: [(await service.inspect(folder.path))!],
        destination: destination,
        mode: NestTransferMode.copy,
      );

      expect(Directory(p.join(target.path, 'pasta 2')).existsSync(), isTrue);
    });
  });

  group('o que dá errado', () {
    test('item que sumiu enquanto esperava não derruba os outros', () async {
      final vanished = await writeFile('sumido.txt');
      final kept = await writeFile('ficou.txt');
      File(vanished.path).deleteSync();

      final transfer = await service.send(
        items: [vanished, kept],
        destination: destination,
        mode: NestTransferMode.copy,
      );

      expect(transfer.fileCount, 1);
      expect(transfer.failures.single.path, vanished.path);
      expect(transfer.failures.single.reason, 'não está mais no lugar');
      expect(File(p.join(target.path, 'ficou.txt')).existsSync(), isTrue);
    });

    test('pasta de destino que sumiu falha tudo, sem exceção', () async {
      final item = await writeFile('nota.txt');
      target.deleteSync();

      final transfer = await service.send(
        items: [item],
        destination: destination,
        mode: NestTransferMode.copy,
      );

      expect(transfer.isEmpty, isTrue);
      expect(transfer.failures.single.reason, 'a pasta de destino sumiu');
    });
  });

  group('desfazer', () {
    test('o que foi movido volta para a origem', () async {
      final item = await writeFile('nota.txt', 'texto');

      final transfer = await service.send(
        items: [item],
        destination: destination,
        mode: NestTransferMode.move,
      );

      expect(await service.undo(transfer), 1);
      expect(File(item.path).readAsStringSync(), 'texto');
      expect(File(p.join(target.path, 'nota.txt')).existsSync(), isFalse);
    });

    test('o que foi copiado tem a cópia apagada, e só ela', () async {
      final item = await writeFile('nota.txt');

      final transfer = await service.send(
        items: [item],
        destination: destination,
        mode: NestTransferMode.copy,
      );

      expect(await service.undo(transfer), 1);
      expect(File(p.join(target.path, 'nota.txt')).existsSync(), isFalse);
      expect(File(item.path).existsSync(), isTrue);
    });

    test('dois arquivos de mesmo nome voltam cada um ao seu lugar', () async {
      final outra = Directory(p.join(root.path, 'outra'))..createSync();
      File(p.join(outra.path, 'nota.txt')).writeAsStringSync('da outra pasta');
      final first = await writeFile('nota.txt', 'da origem');
      final second = (await service.inspect(p.join(outra.path, 'nota.txt')))!;

      final transfer = await service.send(
        items: [first, second],
        destination: destination,
        mode: NestTransferMode.move,
      );

      expect(await service.undo(transfer), 2);
      expect(File(first.path).readAsStringSync(), 'da origem');
      expect(File(second.path).readAsStringSync(), 'da outra pasta');
    });

    test('volta ao lado do impostor quando a origem foi ocupada', () async {
      final item = await writeFile('nota.txt', 'a original');

      final transfer = await service.send(
        items: [item],
        destination: destination,
        mode: NestTransferMode.move,
      );
      File(item.path).writeAsStringSync('a que ocupou o lugar');

      expect(await service.undo(transfer), 1);
      expect(File(item.path).readAsStringSync(), 'a que ocupou o lugar');
      expect(
        File(p.join(origin.path, 'nota 2.txt')).readAsStringSync(),
        'a original',
      );
    });

    test('desfazer o que já foi mexido por fora não explode', () async {
      final item = await writeFile('nota.txt');

      final transfer = await service.send(
        items: [item],
        destination: destination,
        mode: NestTransferMode.copy,
      );
      File(p.join(target.path, 'nota.txt')).deleteSync();

      expect(await service.undo(transfer), 1);
    });
  });
}
