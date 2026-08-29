import 'package:evergreen/app/providers.dart';
import 'package:evergreen/core/design/app_theme.dart';
import 'package:evergreen/core/window/overlay_window.dart';
import 'package:evergreen/features/nest/data/nest_transfer_repository.dart';
import 'package:evergreen/features/nest/models/nest_destination.dart';
import 'package:evergreen/features/nest/models/nest_settings.dart';
import 'package:evergreen/features/nest/models/nest_transfer.dart';
import 'package:evergreen/features/nest/models/nest_transfer_mode.dart';
import 'package:evergreen/features/nest/presentation/viewmodels/nest_state.dart';
import 'package:evergreen/features/nest/presentation/viewmodels/nest_view_model.dart';
import 'package:evergreen/features/nest/presentation/views/nest_overlay_view.dart';
import 'package:evergreen/features/nest/presentation/widgets/nest_item_card.dart';
import 'package:evergreen/shared/widgets/eg_overlay_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_nest_channel.dart';
import 'fake_nest_file_service.dart';

/// O painel do Nest, com um sistema de arquivos de mentira por baixo.
///
/// De mentira porque este teste roda no relógio falso do binding de widgets, e
/// nele a resposta de uma leitura de disco de verdade nunca chega — quem
/// verifica o disco é `nest_file_service_test.dart`. Aqui o assunto é a tela: o
/// que ela mostra, o que o teclado faz e quando o painel fecha.
void main() {
  const origin = '/Users/eu/origem';
  const target = '/Users/eu/destino';

  late FakeNestChannel channel;
  late FakeNestFileService files;

  setUp(() {
    channel = FakeNestChannel();
    files = FakeNestFileService();
    SharedPreferences.setMockInitialValues({});
    // O overlay é um singleton, e cada Esc deixa nele o rastro de um fechamento
    // que o ambiente de teste não tem como terminar — ver `resetForTest`.
    OverlayWindow.instance.resetForTest();
  });

  tearDown(() => channel.dispose());

  String writeFile(String name) {
    final path = '$origin/$name';
    files.addFile(path);
    return path;
  }

  /// Observa o fechamento do painel — `OverlayWindow.hide` avisa o lado nativo
  /// antes de qualquer coisa, e é essa chamada que diz "está indo embora".
  List<String> watchClosing() {
    final calls = <String>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const nativeChannel = MethodChannel('previous_app_focus');

    messenger.setMockMethodCallHandler(nativeChannel, (call) async {
      calls.add(call.method);
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(nativeChannel, null));

    return calls;
  }

  Future<ProviderContainer> pumpPanel(
    WidgetTester tester, {
    List<String> items = const [],
    NestTransferMode mode = NestTransferMode.copy,
    bool withDestination = true,
  }) async {
    tester.view.physicalSize = const Size(1600, 1600);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final prefs = await SharedPreferences.getInstance();
    final overrides = [
      sharedPreferencesProvider.overrideWithValue(prefs),
      nestChannelProvider.overrideWithValue(channel),
      nestTransferRepositoryProvider.overrideWithValue(_NullTransfers()),
      nestFileServiceProvider.overrideWithValue(files),
    ];

    final setup = ProviderContainer(overrides: overrides);
    await setup
        .read(nestSettingsRepositoryProvider)
        .save(
          NestSettings(
            defaultMode: mode,
            destinations: withDestination
                ? [const NestDestination(path: target, alias: 'Recibos')]
                : const [],
          ),
        );
    setup.dispose();

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          theme: AppTheme.build(),
          home: const NestOverlayView(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(NestOverlayView)),
    );

    if (items.isNotEmpty) {
      await container.read(nestViewModelProvider.notifier).addPaths(items);
      await tester.pumpAndSettle();
    }

    return container;
  }

  NestState stateOf(ProviderContainer container) =>
      container.read(nestViewModelProvider);

  testWidgets('vazia, o painel convida em vez de mostrar lista', (
    tester,
  ) async {
    await pumpPanel(tester);

    expect(find.text('A prateleira está vazia'), findsOneWidget);
    expect(find.byType(NestItemCard), findsNothing);
  });

  testWidgets('cada arquivo solto vira uma linha com o nome dele', (
    tester,
  ) async {
    await pumpPanel(tester, items: [writeFile('contrato.pdf')]);

    expect(find.byType(NestItemCard), findsOneWidget);
    expect(find.text('contrato.pdf'), findsOneWidget);
  });

  testWidgets('⌘1 manda tudo para a primeira pasta', (tester) async {
    await pumpPanel(tester, items: [writeFile('a.txt'), writeFile('b.txt')]);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
    await tester.pumpAndSettle();

    expect(files.entries.containsKey('$target/a.txt'), isTrue);
    expect(files.entries.containsKey('$target/b.txt'), isTrue);
  });

  testWidgets('o envio deixa na tela o que acabou de acontecer', (
    tester,
  ) async {
    await pumpPanel(tester, items: [writeFile('a.txt')]);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
    await tester.pumpAndSettle();

    expect(find.text('1 arquivo copiado para Recibos.'), findsOneWidget);
    expect(find.text('⌘Z desfaz.'), findsOneWidget);
  });

  testWidgets('o ⌥ segurado troca o que o painel promete fazer', (
    tester,
  ) async {
    await pumpPanel(tester, items: [writeFile('a.txt')]);

    expect(find.text('COPIAR PARA'), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.alt);
    await tester.pumpAndSettle();

    expect(find.text('MOVER PARA'), findsOneWidget);

    await tester.sendKeyUpEvent(LogicalKeyboardKey.alt);
    await tester.pumpAndSettle();

    expect(find.text('COPIAR PARA'), findsOneWidget);
  });

  testWidgets('com ⌥ segurado, o envio move em vez de copiar', (tester) async {
    final path = writeFile('a.txt');
    await pumpPanel(tester, items: [path]);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.alt);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.alt);
    await tester.pumpAndSettle();

    expect(files.entries.containsKey(path), isFalse);
    expect(files.entries.containsKey('$target/a.txt'), isTrue);
  });

  testWidgets('⌫ tira o item escolhido da prateleira', (tester) async {
    final path = writeFile('a.txt');
    final container = await pumpPanel(tester, items: [path]);

    await tester.tap(find.byType(NestItemCard).first);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pumpAndSettle();

    expect(stateOf(container).isEmpty, isTrue);
    // Tirar da prateleira não é apagar: o original continua onde estava.
    expect(files.entries.containsKey(path), isTrue);
  });

  testWidgets('⌘Z desfaz o envio', (tester) async {
    final path = writeFile('a.txt');
    final container = await pumpPanel(
      tester,
      items: [path],
      mode: NestTransferMode.move,
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
    await tester.pumpAndSettle();

    expect(files.entries.containsKey(path), isTrue);
    expect(stateOf(container).items.single.path, path);
  });

  testWidgets('puxar a lista arrasta a prateleira inteira para fora', (
    tester,
  ) async {
    final first = writeFile('a.txt');
    final second = writeFile('b.txt');
    await pumpPanel(tester, items: [first, second]);

    await tester.drag(find.byType(NestItemCard).first, const Offset(0, 120));
    await tester.pumpAndSettle();

    expect(channel.draggedOut, [first, second]);
  });

  testWidgets('o toque na linha continua selecionando, não arrastando', (
    tester,
  ) async {
    await pumpPanel(tester, items: [writeFile('a.txt'), writeFile('b.txt')]);

    await tester.tap(find.byType(NestItemCard).last);
    await tester.pumpAndSettle();

    expect(channel.draggedOut, isNull);
  });

  testWidgets('⌘ clicando escolhe um a um', (tester) async {
    final container = await pumpPanel(
      tester,
      items: [writeFile('a.txt'), writeFile('b.txt'), writeFile('c.txt')],
    );

    await tester.tap(find.byType(NestItemCard).first);
    await tester.pumpAndSettle();
    expect(stateOf(container).selection, {0});

    await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
    await tester.tap(find.byType(NestItemCard).last);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
    await tester.pumpAndSettle();

    expect(stateOf(container).selection, {0, 2});
  });

  testWidgets('⇧ clicando escolhe da origem ao destino', (tester) async {
    final container = await pumpPanel(
      tester,
      items: [writeFile('a.txt'), writeFile('b.txt'), writeFile('c.txt')],
    );

    await tester.tap(find.byType(NestItemCard).first);
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
    await tester.tap(find.byType(NestItemCard).last);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
    await tester.pumpAndSettle();

    expect(stateOf(container).selection, {0, 1, 2});
  });

  testWidgets('a dica diz quantos vão quando não são todos', (tester) async {
    await pumpPanel(tester, items: [writeFile('a.txt'), writeFile('b.txt')]);

    expect(find.text('copiar tudo'), findsOneWidget);

    await tester.tap(find.byType(NestItemCard).first);
    await tester.pumpAndSettle();

    expect(find.text('copiar 1'), findsOneWidget);
  });

  testWidgets('puxar leva só o escolhido', (tester) async {
    final first = writeFile('a.txt');
    await pumpPanel(tester, items: [first, writeFile('b.txt')]);

    await tester.tap(find.byType(NestItemCard).first);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(NestItemCard).first, const Offset(0, 120));
    await tester.pumpAndSettle();

    expect(channel.draggedOut, [first]);
  });

  testWidgets('sem nada escolhido, o ⌫ não tira nada — nem a dica aparece', (
    tester,
  ) async {
    final container = await pumpPanel(tester, items: [writeFile('a.txt')]);

    expect(find.text('tirar'), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pumpAndSettle();

    expect(stateOf(container).items, hasLength(1));
  });

  testWidgets('Esc fecha', (tester) async {
    final closing = watchClosing();
    await pumpPanel(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(closing, contains('beginHide'));
  });

  testWidgets('a prateleira não some ao perder o foco, nem vazia', (
    tester,
  ) async {
    // Clicar fora é o gesto de ir buscar os arquivos: fechar ali seria fechar
    // no meio da tarefa. Vale com a prateleira vazia, que é justamente o estado
    // de quem vai pegar o primeiro.
    await pumpPanel(tester);

    expect(
      tester.widget<EgOverlayShell>(find.byType(EgOverlayShell)).dismissOnBlur,
      isFalse,
    );
  });

  testWidgets('o painel diz onde está, para o clique passar em volta dele', (
    tester,
  ) async {
    await pumpPanel(tester, items: [writeFile('a.txt')]);

    // Sem isto a janela 0 captura o clique em toda a sua área, e não dá para
    // clicar na janela do Finder de onde os arquivos viriam.
    expect(channel.interactiveRect, isNotNull);
    expect(channel.interactiveRect!.width, 420);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    // E a janela volta ao comportamento que os outros painéis esperam dela.
    expect(channel.interactiveRect, isNull);
  });

  testWidgets('a janela 0 só aceita arquivos com este painel na tela', (
    tester,
  ) async {
    await pumpPanel(tester);
    expect(channel.isDropEnabled, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    expect(channel.isDropEnabled, isFalse);
  });

  testWidgets('sem pasta cadastrada, o painel diz onde cadastrar', (
    tester,
  ) async {
    await pumpPanel(
      tester,
      items: [writeFile('a.txt')],
      withDestination: false,
    );

    expect(find.textContaining('Nenhuma pasta cadastrada'), findsOneWidget);
  });
}

/// O Track não é o assunto destes testes.
class _NullTransfers implements NestTransferRepository {
  @override
  int insert(NestTransfer transfer) => 1;

  @override
  void delete(int id) {}
}
