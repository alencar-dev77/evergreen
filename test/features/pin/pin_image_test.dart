import 'dart:convert';

import 'package:evergreen/app/providers.dart';
import 'package:evergreen/core/storage/app_database.dart';
import 'package:evergreen/features/pin/data/clipboard_repository.dart';
import 'package:evergreen/features/pin/data/clipboard_watcher.dart';
import 'package:evergreen/features/pin/data/pin_image_store.dart';
import 'package:evergreen/features/pin/models/clipboard_item.dart';
import 'package:evergreen/features/pin/models/clipboard_item_type.dart';
import 'package:evergreen/features/pin/models/pin_image.dart';
import 'package:evergreen/features/pin/models/pin_search.dart';
import 'package:evergreen/features/pin/presentation/viewmodels/pin_overlay_view_model.dart';
import 'package:evergreen/core/design/app_theme.dart';
import 'package:evergreen/features/pin/presentation/widgets/pin_preview_pane.dart';
import 'package:evergreen/shared/widgets/eg_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';

import 'fake_pin_image_store.dart';

/// Um PNG de verdade, de 1×1 — o menor que decodifica.
final onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);

CapturedImage captured({
  String hash = 'abc123',
  String? name,
  String? path,
  String? source,
}) => CapturedImage(
  bytes: Uint8List.fromList(onePixelPng),
  hash: hash,
  extension: 'png',
  width: 1280,
  height: 720,
  name: name,
  path: path,
  source: source,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PinImage', () {
    test('sem nome, o título diz que é uma imagem e o tamanho dela', () {
      expect(captured().toImage().title, 'Imagem 1280×720');
      expect(
        captured(name: 'captura 2026-10-14.png').toImage().title,
        'captura 2026-10-14.png',
      );
    });

    test('sobrevive ao banco, e linha corrompida não é imagem', () {
      final image = captured(
        name: 'logo.png',
        path: '/Users/lucas/Desktop/logo.png',
        source: 'https://exemplo.com/marca',
      ).toImage();

      final back = PinImage.fromJson(image.toJson())!;
      expect(back.fileName, 'abc123.png');
      expect(back.path, '/Users/lucas/Desktop/logo.png');
      expect(back.source, 'https://exemplo.com/marca');
      expect(back.byteSize, onePixelPng.length);

      expect(PinImage.fromJson('{quebrado'), isNull);
      // JSON válido com o tipo errado num campo: lido do jeito que der, sem
      // derrubar a lista.
      expect(PinImage.fromJson('{"file": "a.png", "width": "10"}')?.width, 0);
      expect(PinImage.fromJson('{"width": 10}'), isNull);
      expect(PinImage.fromJson(null), isNull);
    });
  });

  group('ClipboardItem de imagem', () {
    test('a chave é o arquivo, e a busca lê o caminho e o site', () {
      final item = ClipboardItem.fromImage(
        captured(path: '/Users/lucas/Desktop/logo.png').toImage(),
      );

      expect(item.content, 'imagem:abc123.png');
      expect(item.type, ClipboardItemType.image);
      expect(item.isImage, isTrue);
      expect(item.hasMoreThanTitle, isFalse);
      expect(item.searchableContent, '/Users/lucas/Desktop/logo.png\n1280x720');

      // A chave não é texto de ninguém: "imagem" não casa com toda imagem.
      final semNome = ClipboardItem.fromImage(captured().toImage());
      expect(PinSearch.match(semNome.copyWith(id: 1), 'abc123'), isNull);
      expect(PinSearch.match(item.copyWith(id: 2), 'desktop'), isNotNull);
      // Ninguém digita o "×" do título: as dimensões casam com um x comum.
      expect(PinSearch.match(semNome.copyWith(id: 3), '1280x720'), isNotNull);
    });

    test('o leitor de tela diz as dimensões por extenso', () {
      expect(captured().toImage().spokenTitle, 'Imagem de 1280 por 720');
      expect(captured(name: 'logo.png').toImage().spokenTitle, 'logo.png');
    });

    test('a imagem é "copiada", e não "copiado"', () {
      expect(ClipboardItemType.image.copied, 'copiada');
      expect(ClipboardItemType.link.copied, 'copiado');
    });

    test('Imagens tem pílula; Comandos não tem mais', () {
      expect(ClipboardItemType.image.hasFilter, isTrue);
      expect(ClipboardItemType.command.hasFilter, isFalse);
      expect(ClipboardItemType.text.hasFilter, isTrue);
    });
  });

  group('SqliteClipboardRepository', () {
    late Database db;
    late SqliteClipboardRepository repository;

    setUp(() {
      db = sqlite3.openInMemory();
      AppDatabase.migrate(db);
      repository = SqliteClipboardRepository(db);
    });

    tearDown(() => db.close());

    test('guarda a imagem e a devolve com o que se sabe dela', () {
      repository.upsert(
        ClipboardItem.fromImage(
          captured(name: 'logo.png').toImage(),
          at: DateTime(2026, 10, 14, 9),
        ),
      );

      final stored = repository.loadAll().single;
      expect(stored.type, ClipboardItemType.image);
      expect(stored.image?.fileName, 'abc123.png');
      expect(stored.title, 'logo.png');
      expect(repository.imageFiles(), {'abc123.png'});
    });

    test('a mesma imagem copiada de novo sobe, e não vira outra linha', () {
      final image = captured().toImage();
      repository
        ..upsert(ClipboardItem.fromImage(image, at: DateTime(2026, 10, 14, 9)))
        ..upsert(ClipboardItem.capture('um texto', at: DateTime(2026, 10, 14)))
        ..upsert(
          ClipboardItem.fromImage(image, at: DateTime(2026, 10, 14, 10)),
        );

      final items = repository.loadAll();
      expect(items, hasLength(2));
      expect(items.first.isImage, isTrue);
    });

    test('copiada de outro lugar, vale a origem mais recente', () {
      // Primeiro do navegador, sem nome; depois do Finder, com nome e
      // caminho. Os mesmos bytes, a mesma linha — e o nome passa a valer.
      repository
        ..upsert(ClipboardItem.fromImage(captured().toImage()))
        ..upsert(
          ClipboardItem.fromImage(
            captured(name: 'logo.png', path: '/tmp/logo.png').toImage(),
          ),
        );

      final stored = repository.loadAll().single;
      expect(stored.title, 'logo.png');
      expect(stored.image?.path, '/tmp/logo.png');
    });

    test('linha de imagem sem descrição não mostra a chave', () {
      repository.upsert(ClipboardItem.fromImage(captured().toImage()));
      db.execute('UPDATE clipboard_items SET image = NULL;');

      expect(repository.loadAll().single.title, 'Imagem');
    });

    test('a reclassificação não transforma imagem em texto', () {
      repository.upsert(ClipboardItem.fromImage(captured().toImage()));
      // Como se a imagem tivesse sido guardada por um classificador antigo.
      db.execute('UPDATE clipboard_items SET classifier_version = 0;');

      expect(repository.reclassifyOutdated(), 0);
      expect(repository.loadAll().single.type, ClipboardItemType.image);
    });
  });

  group('PinImageJanitor', () {
    test('apaga o arquivo que nenhuma linha quer', () {
      final db = sqlite3.openInMemory();
      addTearDown(db.close);
      AppDatabase.migrate(db);
      final repository = SqliteClipboardRepository(db);
      final store = FakePinImageStore();

      final kept = store.save(captured(hash: 'fica'));
      store.save(captured(hash: 'orfa'));
      repository.upsert(ClipboardItem.fromImage(kept));

      PinImageJanitor(repository: repository, store: store).sweep();

      expect(store.list(), ['fica.png']);
    });
  });

  group('ClipboardWatcher', () {
    const channel = MethodChannel('pasteboard_watcher');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    test('repassa a imagem que o nativo avisa, com a origem', () async {
      messenger.setMockMethodCallHandler(channel, (_) async => null);
      final watcher = ClipboardWatcher();
      addTearDown(watcher.dispose);
      await watcher.start();

      final images = <CapturedImage>[];
      watcher.onImage.listen(images.add);

      await messenger.handlePlatformMessage(
        channel.name,
        channel.codec.encodeMethodCall(
          MethodCall('onCopyImage', {
            'bytes': Uint8List.fromList(onePixelPng),
            'hash': 'abc123',
            'extension': 'png',
            'width': 1280,
            'height': 720,
            'source': 'https://exemplo.com',
          }),
        ),
        (_) {},
      );
      await Future<void>.delayed(Duration.zero);

      expect(images.single.fileName, 'abc123.png');
      expect(images.single.source, 'https://exemplo.com');
      expect(images.single.name, isNull);
    });
  });

  group('PinOverlayViewModel', () {
    const channel = MethodChannel('pasteboard_watcher');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    late Database db;
    late FakePinImageStore store;
    late ProviderContainer container;
    late List<MethodCall> nativeCalls;

    Future<ProviderContainer> start({List<String> ignored = const []}) async {
      SharedPreferences.setMockInitialValues({'pin.ignored_types': ignored});
      final preferences = await SharedPreferences.getInstance();

      container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          clipboardRepositoryProvider.overrideWithValue(
            SqliteClipboardRepository(db),
          ),
          pinImageStoreProvider.overrideWithValue(store),
        ],
      );
      addTearDown(container.dispose);

      container.read(pinOverlayViewModelProvider.notifier).startWatching();
      await Future<void>.delayed(Duration.zero);
      return container;
    }

    Future<void> copyImageInAnotherApp(CapturedImage image) async {
      await messenger.handlePlatformMessage(
        channel.name,
        channel.codec.encodeMethodCall(
          MethodCall('onCopyImage', {
            'bytes': image.bytes,
            'hash': image.hash,
            'extension': image.extension,
            'width': image.width,
            'height': image.height,
            'name': ?image.name,
            'path': ?image.path,
          }),
        ),
        (_) {},
      );
      await Future<void>.delayed(Duration.zero);
    }

    setUp(() {
      db = sqlite3.openInMemory();
      AppDatabase.migrate(db);
      store = FakePinImageStore();
      nativeCalls = [];
      messenger.setMockMethodCallHandler(channel, (call) async {
        nativeCalls.add(call);
        return null;
      });
    });

    tearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      db.close();
    });

    test('a imagem copiada vira arquivo e linha, com a pílula dela', () async {
      await start();

      await copyImageInAnotherApp(
        captured(name: 'captura.png', path: '/Users/lucas/captura.png'),
      );

      final state = container.read(pinOverlayViewModelProvider);
      expect(state.results.single.title, 'captura.png');
      expect(store.list(), ['abc123.png']);
      expect(state.availableTypes, contains(ClipboardItemType.image));
    });

    test('com Imagens desligado, nada é registrado — nem o arquivo', () async {
      await start(ignored: ['image']);

      await copyImageInAnotherApp(captured());

      expect(container.read(pinOverlayViewModelProvider).results, isEmpty);
      expect(store.list(), isEmpty);
    });

    test(
      'Comandos não aparece na fila, mesmo com comando no histórico',
      () async {
        SqliteClipboardRepository(
          db,
        ).upsert(ClipboardItem.capture('git status'));
        await start();

        final types = container
            .read(pinOverlayViewModelProvider)
            .availableTypes;
        expect(types, isNot(contains(ClipboardItemType.command)));
      },
    );

    test('copiar a imagem escreve a imagem, e não o texto da chave', () async {
      await start();
      await copyImageInAnotherApp(captured());
      nativeCalls.clear();

      final viewModel = container.read(pinOverlayViewModelProvider.notifier);
      await viewModel.copyItem(
        container.read(pinOverlayViewModelProvider).results.single,
      );

      expect(nativeCalls.map((call) => call.method), ['writeImage']);
      expect(nativeCalls.single.arguments, '/tmp/pin-imagens/abc123.png');
    });

    test(
      'sem o arquivo, copiar não escreve nada — e diz que não copiou',
      () async {
        await start();
        await copyImageInAnotherApp(captured());
        store.files.clear();
        nativeCalls.clear();

        // `false` é o que segura o painel aberto: fechar e auto-colar
        // despejaria no outro app o que estava na área de transferência antes.
        final viewModel = container.read(pinOverlayViewModelProvider.notifier);
        expect(await viewModel.copySelected(), isFalse);
        expect(nativeCalls, isEmpty);
      },
    );

    test(
      'sabe quando há o que copiar — e a descrição perdida não copia',
      () async {
        await start();
        await copyImageInAnotherApp(captured());
        final viewModel = container.read(pinOverlayViewModelProvider.notifier);
        final image = container
            .read(pinOverlayViewModelProvider)
            .results
            .single;

        expect(viewModel.canCopy(image), isTrue);
        expect(viewModel.canCopy(ClipboardItem.capture('texto')), isTrue);

        store.files.clear();
        expect(viewModel.canCopy(image), isFalse);

        // A linha cuja descrição não sobreviveu: nem a chave vai para a área de
        // transferência, nem o painel fecha.
        final semDescricao = ClipboardItem(
          id: 99,
          content: 'imagem:perdida.png',
          type: ClipboardItemType.image,
          isPinned: false,
          copiedAt: DateTime(2026, 10, 15),
        );
        nativeCalls.clear();
        expect(viewModel.canCopy(semDescricao), isFalse);
        expect(await viewModel.copyItem(semDescricao), isFalse);
        expect(nativeCalls, isEmpty);
      },
    );

    test('apagar a imagem leva o arquivo junto', () async {
      await start();
      await copyImageInAnotherApp(captured());

      final viewModel = container.read(pinOverlayViewModelProvider.notifier);
      viewModel.delete(
        container.read(pinOverlayViewModelProvider).results.single,
      );

      expect(store.list(), isEmpty);
    });

    test(
      'o teto do histórico leva a imagem mais antiga, e o arquivo',
      () async {
        // A de ontem, guardada antes de o painel subir: duas cópias no mesmo
        // milissegundo não têm "mais antiga" para o teto escolher.
        SqliteClipboardRepository(db).upsert(
          ClipboardItem.fromImage(
            store.save(captured(hash: 'antiga')),
            at: DateTime.now().subtract(const Duration(days: 1)),
          ),
        );
        await start();
        await (await SharedPreferences.getInstance()).setInt(
          'pin.history_limit',
          1,
        );

        await copyImageInAnotherApp(captured(hash: 'nova'));

        expect(store.list(), ['nova.png']);
      },
    );
  });

  group('PinPreviewPane', () {
    testWidgets('sem o arquivo, Copiar desliga e Excluir continua', (
      tester,
    ) async {
      final item = ClipboardItem.fromImage(
        captured(path: '/Users/lucas/Desktop/logo.png').toImage(),
      ).copyWith(id: 1);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pinImageStoreProvider.overrideWithValue(FakePinImageStore()),
          ],
          child: MaterialApp(
            theme: AppTheme.build(),
            home: Scaffold(
              body: SizedBox(
                width: 420,
                height: 560,
                child: PinPreviewPane(
                  item: item,
                  aliasController: TextEditingController(),
                  aliasFocusNode: FocusNode(),
                  onAliasSubmitted: (_) {},
                  onCopy: () {},
                  onTogglePin: () {},
                  onDelete: () {},
                  canCopy: false,
                ),
              ),
            ),
          ),
        ),
      );

      final copy = tester.widget<EgButton>(
        find.widgetWithText(EgButton, 'Copiar'),
      );
      final delete = tester.widget<EgButton>(
        find.widgetWithText(EgButton, 'Excluir'),
      );
      expect(copy.onPressed, isNull);
      expect(delete.onPressed, isNotNull);
      expect(find.text('A imagem não está mais no disco.'), findsOneWidget);
      // O caminho continua à vista, inteiro: é o que diz onde procurar.
      expect(find.text('/Users/lucas/Desktop/logo.png'), findsOneWidget);
      expect(find.textContaining('copiada'), findsOneWidget);
    });
  });
}
