import 'dart:io';

import 'package:evergreen/app/providers.dart';
import 'package:evergreen/features/nest/data/nest_file_service.dart';
import 'package:evergreen/features/nest/data/nest_transfer_repository.dart';
import 'package:evergreen/features/nest/models/nest_destination.dart';
import 'package:evergreen/features/nest/models/nest_settings.dart';
import 'package:evergreen/features/nest/models/nest_transfer.dart';
import 'package:evergreen/features/nest/models/nest_transfer_mode.dart';
import 'package:evergreen/features/nest/presentation/viewmodels/nest_state.dart';
import 'package:evergreen/features/nest/presentation/viewmodels/nest_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_nest_channel.dart';

/// A prateleira do lado do Dart: o que entra, o que sai e o que o `⌘Z` devolve.
///
/// O disco é de verdade (uma pasta temporária) porque é ele que dita metade das
/// respostas — o que muda de lugar quando se move, o que sobra quando se copia.
/// O que é imitado é só o que exigiria o Finder: o arraste, a miniatura e o
/// seletor de pasta.
void main() {
  late Directory root;
  late Directory origin;
  late Directory target;
  late FakeNestChannel channel;
  late _FakeTransferRepository transfers;

  final clock = DateTime(2026, 8, 28, 14, 30);

  setUp(() {
    root = Directory.systemTemp.createTempSync('nest_vm');
    origin = Directory(p.join(root.path, 'origem'))..createSync();
    target = Directory(p.join(root.path, 'destino'))..createSync();
    channel = FakeNestChannel();
    transfers = _FakeTransferRepository();
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    channel.dispose();
    root.deleteSync(recursive: true);
  });

  String writeFile(String name, [String content = 'conteúdo']) {
    final path = p.join(origin.path, name);
    File(path).writeAsStringSync(content);
    return path;
  }

  Future<ProviderContainer> makeContainer({
    NestTransferMode mode = NestTransferMode.copy,
    bool withDestination = true,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        nestChannelProvider.overrideWithValue(channel),
        nestTransferRepositoryProvider.overrideWithValue(transfers),
        nestFileServiceProvider.overrideWithValue(
          LocalNestFileService(clock: () => clock),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(nestSettingsRepositoryProvider)
        .save(
          NestSettings(
            defaultMode: mode,
            destinations: withDestination
                ? [NestDestination(path: target.path, alias: 'Recibos')]
                : const [],
          ),
        );
    // Como o `EvergreenBootstrap` faz: é a assinatura que liga os avisos do
    // lado nativo — o arquivo solto e o fim do arraste para fora.
    container.read(nestViewModelProvider.notifier).startListening();
    await container.read(nestViewModelProvider.notifier).prepareForOpen();

    return container;
  }

  NestState stateOf(ProviderContainer container) =>
      container.read(nestViewModelProvider);

  NestViewModel viewModelOf(ProviderContainer container) =>
      container.read(nestViewModelProvider.notifier);

  group('encher a prateleira', () {
    test('o que é solto entra na ordem em que chegou', () async {
      final container = await makeContainer();
      final first = writeFile('a.txt');
      final second = writeFile('b.txt');

      await viewModelOf(container).addPaths([first, second]);

      expect(stateOf(container).items.map((item) => item.path), [
        first,
        second,
      ]);
      // Sem escolha nenhuma: sem ela sai a prateleira inteira, que é o que
      // quem acabou de soltar dois arquivos quer.
      expect(stateOf(container).selection, isEmpty);
      expect(stateOf(container).outgoing, hasLength(2));
    });

    test('o mesmo arquivo solto duas vezes não vira duas linhas', () async {
      final container = await makeContainer();
      final path = writeFile('a.txt');

      await viewModelOf(container).addPaths([path]);
      await viewModelOf(container).addPaths([path]);

      expect(stateOf(container).items, hasLength(1));
    });

    test('caminho que não existe não entra', () async {
      final container = await makeContainer();

      await viewModelOf(container).addPaths([p.join(origin.path, 'fantasma')]);

      expect(stateOf(container).isEmpty, isTrue);
    });

    test('cada item entrando pede a miniatura dele', () async {
      final container = await makeContainer();
      final path = writeFile('a.txt');

      await viewModelOf(container).addPaths([path]);

      expect(channel.thumbnailsRequested, [path]);
    });

    test('tirar um item não toca no arquivo', () async {
      final container = await makeContainer();
      final path = writeFile('a.txt');
      await viewModelOf(container).addPaths([path]);

      viewModelOf(container).select(0);
      viewModelOf(container).removeSelected();

      expect(stateOf(container).isEmpty, isTrue);
      expect(File(path).existsSync(), isTrue);
    });
  });

  group('enviar', () {
    test('manda a prateleira inteira, não só o selecionado', () async {
      final container = await makeContainer();
      await viewModelOf(
        container,
      ).addPaths([writeFile('a.txt'), writeFile('b.txt')]);

      await viewModelOf(container).sendToIndex(0);

      expect(File(p.join(target.path, 'a.txt')).existsSync(), isTrue);
      expect(File(p.join(target.path, 'b.txt')).existsSync(), isTrue);
      expect(stateOf(container).isEmpty, isTrue);
    });

    test('o ⌥ segurado inverte o modo das preferências', () async {
      final container = await makeContainer();
      final path = writeFile('a.txt');
      await viewModelOf(container).addPaths([path]);

      viewModelOf(container).setInvertHeld(isHeld: true);
      expect(stateOf(container).effectiveMode, NestTransferMode.move);

      await viewModelOf(container).sendToIndex(0);

      expect(File(path).existsSync(), isFalse);
    });

    test('o que falhou fica na prateleira, marcado', () async {
      final container = await makeContainer();
      final vanished = writeFile('sumido.txt');
      final kept = writeFile('ficou.txt');
      await viewModelOf(container).addPaths([vanished, kept]);
      File(vanished).deleteSync();

      await viewModelOf(container).sendToIndex(0);

      expect(stateOf(container).items, hasLength(1));
      expect(stateOf(container).items.single.path, vanished);
      expect(stateOf(container).items.single.isMissing, isTrue);
    });

    test('a linha do Track conta os arquivos, e nada mais', () async {
      final container = await makeContainer();
      await viewModelOf(
        container,
      ).addPaths([writeFile('a.txt'), writeFile('b.txt')]);

      await viewModelOf(container).sendToIndex(0);

      expect(transfers.rows.single.fileCount, 2);
      expect(transfers.rows.single.at, clock);
    });

    test('sem destino nenhum, enviar não faz nada', () async {
      final container = await makeContainer(withDestination: false);
      await viewModelOf(container).addPaths([writeFile('a.txt')]);

      await viewModelOf(container).sendToIndex(0);

      expect(stateOf(container).items, hasLength(1));
      expect(transfers.rows, isEmpty);
    });
  });

  group('escolher', () {
    test('o clique troca a escolha por uma linha só', () async {
      final container = await makeContainer();
      await viewModelOf(
        container,
      ).addPaths([writeFile('a.txt'), writeFile('b.txt')]);

      viewModelOf(container).select(1);

      expect(stateOf(container).selection, {1});
    });

    test('o ⌘ acrescenta e tira um a um', () async {
      final container = await makeContainer();
      await viewModelOf(container).addPaths([
        writeFile('a.txt'),
        writeFile('b.txt'),
        writeFile('c.txt'),
      ]);

      viewModelOf(container).select(0);
      viewModelOf(container).select(2, toggle: true);
      expect(stateOf(container).selection, {0, 2});

      viewModelOf(container).select(0, toggle: true);
      expect(stateOf(container).selection, {2});
    });

    test('o ⇧ vai do cursor até onde se clicou', () async {
      final container = await makeContainer();
      await viewModelOf(container).addPaths([
        writeFile('a.txt'),
        writeFile('b.txt'),
        writeFile('c.txt'),
      ]);

      viewModelOf(container).select(0);
      viewModelOf(container).select(2, extend: true);

      expect(stateOf(container).selection, {0, 1, 2});
    });

    test('só o escolhido é enviado; o resto fica na prateleira', () async {
      final container = await makeContainer();
      final first = writeFile('a.txt');
      final second = writeFile('b.txt');
      await viewModelOf(container).addPaths([first, second]);

      viewModelOf(container).select(0);
      await viewModelOf(container).sendToIndex(0);

      expect(File(p.join(target.path, 'a.txt')).existsSync(), isTrue);
      expect(File(p.join(target.path, 'b.txt')).existsSync(), isFalse);
      expect(stateOf(container).items.single.path, second);
    });

    test('o ⌫ tira todos os escolhidos de uma vez', () async {
      final container = await makeContainer();
      await viewModelOf(container).addPaths([
        writeFile('a.txt'),
        writeFile('b.txt'),
        writeFile('c.txt'),
      ]);

      viewModelOf(container).select(0);
      viewModelOf(container).select(1, extend: true);
      viewModelOf(container).removeSelected();

      expect(stateOf(container).items.single.name, 'c.txt');
      expect(stateOf(container).selection, {0});
    });
  });

  group('arrastar para fora', () {
    test('leva a prateleira inteira, e não só o selecionado', () async {
      final container = await makeContainer();
      final first = writeFile('a.txt');
      final second = writeFile('b.txt');
      await viewModelOf(container).addPaths([first, second]);

      await viewModelOf(container).beginDragOut();

      expect(channel.draggedOut, [first, second]);
      expect(channel.draggedOutAsMove, isFalse);
    });

    test('o ⌥ segurado declara "mover" ao sistema', () async {
      final container = await makeContainer();
      await viewModelOf(container).addPaths([writeFile('a.txt')]);
      viewModelOf(container).setInvertHeld(isHeld: true);

      await viewModelOf(container).beginDragOut();

      expect(channel.draggedOutAsMove, isTrue);
    });

    test('o destino aceitou: a prateleira esvazia e o Track conta', () async {
      final container = await makeContainer();
      await viewModelOf(
        container,
      ).addPaths([writeFile('a.txt'), writeFile('b.txt')]);

      await viewModelOf(container).beginDragOut();
      channel.endDragOut(NestTransferMode.move);
      await Future<void>.delayed(Duration.zero);

      expect(stateOf(container).isEmpty, isTrue);
      expect(transfers.rows.single.fileCount, 2);
      expect(transfers.rows.single.mode, NestTransferMode.move);
    });

    test('soltar em lugar nenhum não mexe em nada', () async {
      final container = await makeContainer();
      await viewModelOf(container).addPaths([writeFile('a.txt')]);

      await viewModelOf(container).beginDragOut();
      channel.endDragOut(null);
      await Future<void>.delayed(Duration.zero);

      expect(stateOf(container).items, hasLength(1));
      expect(transfers.rows, isEmpty);
    });

    test('não oferece desfazer — o destino é do sistema, não nosso', () async {
      final container = await makeContainer();
      await viewModelOf(container).addPaths([writeFile('a.txt')]);

      await viewModelOf(container).beginDragOut();
      channel.endDragOut(NestTransferMode.copy);
      await Future<void>.delayed(Duration.zero);

      expect(stateOf(container).canUndo, isFalse);
    });

    test('leva só o que estiver escolhido', () async {
      final container = await makeContainer();
      final first = writeFile('a.txt');
      await viewModelOf(container).addPaths([first, writeFile('b.txt')]);

      viewModelOf(container).select(0);
      await viewModelOf(container).beginDragOut();

      expect(channel.draggedOut, [first]);
    });

    test('o que não foi levado continua na prateleira', () async {
      final container = await makeContainer();
      final second = writeFile('b.txt');
      await viewModelOf(container).addPaths([writeFile('a.txt'), second]);

      viewModelOf(container).select(0);
      await viewModelOf(container).beginDragOut();
      channel.endDragOut(NestTransferMode.move);
      await Future<void>.delayed(Duration.zero);

      expect(stateOf(container).items.single.path, second);
    });

    test('com a prateleira vazia não começa arraste nenhum', () async {
      final container = await makeContainer();

      await viewModelOf(container).beginDragOut();

      expect(channel.draggedOut, isNull);
    });
  });

  group('desfazer', () {
    test('devolve os arquivos movidos e a prateleira', () async {
      final container = await makeContainer(mode: NestTransferMode.move);
      final path = writeFile('a.txt', 'texto');
      await viewModelOf(container).addPaths([path]);
      await viewModelOf(container).sendToIndex(0);

      await viewModelOf(container).undo();

      expect(File(path).readAsStringSync(), 'texto');
      expect(stateOf(container).items.single.path, path);
      expect(stateOf(container).canUndo, isFalse);
    });

    test('apaga a linha do Track: desfeita, ela não organizou nada', () async {
      final container = await makeContainer();
      await viewModelOf(container).addPaths([writeFile('a.txt')]);
      await viewModelOf(container).sendToIndex(0);

      await viewModelOf(container).undo();

      expect(transfers.rows, isEmpty);
    });

    test('a oferta não atravessa uma reabertura do painel', () async {
      final container = await makeContainer();
      await viewModelOf(container).addPaths([writeFile('a.txt')]);
      await viewModelOf(container).sendToIndex(0);

      expect(stateOf(container).canUndo, isTrue);
      await viewModelOf(container).prepareForOpen();

      expect(stateOf(container).canUndo, isFalse);
    });
  });

  group('reabrir o painel', () {
    test('marca o que sumiu do disco desde a última vez', () async {
      final container = await makeContainer();
      final path = writeFile('a.txt');
      await viewModelOf(container).addPaths([path]);

      File(path).deleteSync();
      await viewModelOf(container).prepareForOpen();

      expect(stateOf(container).items.single.isMissing, isTrue);
    });

    test('relê as pastas que o Hub pode ter mudado', () async {
      final container = await makeContainer(withDestination: false);
      expect(stateOf(container).hasDestinations, isFalse);

      await container
          .read(nestSettingsRepositoryProvider)
          .save(NestSettings(destinations: [NestDestination(path: target.path)]));
      await viewModelOf(container).prepareForOpen();

      expect(stateOf(container).destinations.single.path, target.path);
    });
  });
}

/// Guarda as linhas em memória, com o mesmo contrato do banco: `insert` devolve
/// um número, `delete` o consome.
class _FakeTransferRepository implements NestTransferRepository {
  final rows = <NestTransfer>[];
  final _ids = <int, NestTransfer>{};
  int _nextId = 1;

  @override
  int insert(NestTransfer transfer) {
    if (transfer.isEmpty) return 0;

    final id = _nextId++;
    rows.add(transfer);
    _ids[id] = transfer;

    return id;
  }

  @override
  void delete(int id) {
    final transfer = _ids.remove(id);
    if (transfer != null) rows.remove(transfer);
  }
}
