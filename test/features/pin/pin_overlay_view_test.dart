import 'package:evergreen/app/providers.dart';
import 'package:evergreen/core/window/overlay_window.dart';
import 'package:evergreen/core/design/app_theme.dart';
import 'package:evergreen/features/pin/models/clipboard_item.dart';
import 'package:evergreen/features/pin/models/clipboard_item_type.dart';
import 'package:evergreen/features/pin/presentation/viewmodels/pin_overlay_view_model.dart';
import 'package:evergreen/features/pin/presentation/views/pin_overlay_view.dart';
import 'package:evergreen/features/pin/presentation/widgets/pin_generator_row.dart';
import 'package:evergreen/features/pin/presentation/widgets/pin_list_item.dart';
import 'package:evergreen/features/pin/presentation/widgets/pin_preview_pane.dart';
import 'package:evergreen/shared/widgets/eg_key_cap.dart';
import 'package:evergreen/shared/widgets/eg_search_field.dart';
import 'package:evergreen/shared/widgets/eg_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_clipboard_repository.dart';

void main() {
  late FakeClipboardRepository repository;
  late SharedPreferences preferences;

  final base = DateTime(2026, 7, 23, 12);

  ClipboardItem item(int id, String content, {bool isPinned = false}) {
    return ClipboardItem(
      id: id,
      content: content,
      type: ClipboardItemClassifier.classify(content),
      isPinned: isPinned,
      copiedAt: base.subtract(Duration(minutes: id)),
      pinnedAt: isPinned ? base.subtract(Duration(hours: id)) : null,
    );
  }

  setUp(() async {
    // O overlay é um singleton, e cada Esc deixa nele o rastro de um fechamento
    // que o ambiente de teste não tem como terminar — ver `resetForTest`.
    OverlayWindow.instance.resetForTest();

    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();

    repository = FakeClipboardRepository([
      item(1, 'Flutter', isPinned: true),
      item(2, 'https://pub.dev/packages/sqlite3'),
      item(3, 'Senha temporária: xK9#mPz2'),
    ]);
  });

  /// Observa o fechamento do overlay.
  ///
  /// `OverlayWindow.hide` começa avisando o lado nativo (`beginHide`), então é
  /// essa chamada que diz "o painel está indo embora" sem precisar de janela de
  /// verdade no ambiente de teste.
  List<String> watchClosing() {
    final calls = <String>[];

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('previous_app_focus'), (
          call,
        ) async {
          calls.add(call.method);
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('previous_app_focus'),
            null,
          ),
    );

    return calls;
  }

  Future<void> pumpOverlay(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          clipboardRepositoryProvider.overrideWithValue(repository),
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
        child: MaterialApp(
          theme: AppTheme.build(),
          home: const PinOverlayView(),
        ),
      ),
    );

    // A ViewModel carrega o histórico sob demanda; o overlay real faz isso ao
    // abrir a janela, que não existe no ambiente de teste.
    final element = tester.element(find.byType(PinOverlayView));
    ProviderScope.containerOf(
      element,
    ).read(pinOverlayViewModelProvider.notifier).load();

    await tester.pumpAndSettle();
  }

  testWidgets('separa fixados de recentes e seleciona o primeiro item', (
    tester,
  ) async {
    await pumpOverlay(tester);

    expect(find.text('FIXADOS'), findsOneWidget);
    expect(find.text('RECENTES'), findsOneWidget);
    expect(find.text('Flutter'), findsOneWidget);
    expect(find.text('https://pub.dev/packages/sqlite3'), findsOneWidget);

    final selected = tester
        .widgetList<PinListItem>(find.byType(PinListItem))
        .where((widget) => widget.isSelected);

    expect(selected.single.item.content, 'Flutter');
  });

  testWidgets(
    'seta para baixo move a seleção mesmo com foco no campo de busca',
    (tester) async {
      await pumpOverlay(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();

      final selected = tester
          .widgetList<PinListItem>(find.byType(PinListItem))
          .firstWhere((widget) => widget.isSelected);

      expect(selected.item.content, 'https://pub.dev/packages/sqlite3');
    },
  );

  testWidgets('busca filtra a lista em tempo real', (tester) async {
    await pumpOverlay(tester);

    await tester.enterText(find.byType(TextField), 'senha');
    await tester.pumpAndSettle();

    expect(find.text('Senha temporária: xK9#mPz2'), findsOneWidget);
    expect(find.text('Flutter'), findsNothing);
    expect(find.text('FIXADOS'), findsNothing);
  });

  testWidgets('a busca acha pelas iniciais, sem o termo exato', (tester) async {
    repository.setAlias(1, 'chave pix');
    await pumpOverlay(tester);

    // Nem "chv" nem "chvpix" aparecem em lugar nenhum: o que casa é a
    // subsequência, que era exatamente o que a substring de antes não fazia.
    await tester.enterText(find.byType(TextField), 'chv pix');
    await tester.pumpAndSettle();

    expect(find.byType(PinListItem), findsOneWidget);
  });

  testWidgets('o apelido ranqueia acima de um conteúdo mais recente', (
    tester,
  ) async {
    repository = FakeClipboardRepository([
      // O mais novo, e o termo casa inteiro no conteúdo dele.
      item(1, 'pix copia e cola'),
      item(2, 'nada a ver'),
    ]);
    repository.setAlias(2, 'chave pix');

    await pumpOverlay(tester);

    await tester.enterText(find.byType(TextField), 'pix');
    await tester.pumpAndSettle();

    final rows = tester
        .widgetList<PinListItem>(find.byType(PinListItem))
        .toList();

    // Recência decide empate, não a ordem: o apelido é o nome que a pessoa deu
    // ao item justamente para reencontrá-lo.
    expect(rows.first.item.content, 'nada a ver');
    expect(rows.last.item.content, 'pix copia e cola');
  });

  testWidgets('buscar não reordena os fixados', (tester) async {
    repository = FakeClipboardRepository([
      item(1, 'segundo pix', isPinned: true),
      item(2, 'pix primeiro', isPinned: true),
    ]);

    await pumpOverlay(tester);
    final antes = tester
        .widgetList<PinListItem>(find.byType(PinListItem))
        .map((row) => row.item.content)
        .toList();

    // O segundo casa melhor (começo do campo), e mesmo assim não sobe: `⌥1`
    // precisa continuar apontando para o mesmo item enquanto se digita.
    await tester.enterText(find.byType(TextField), 'pix');
    await tester.pumpAndSettle();

    final depois = tester
        .widgetList<PinListItem>(find.byType(PinListItem))
        .map((row) => row.item.content)
        .toList();

    expect(depois, antes);
  });

  testWidgets('busca sem resultado mostra estado vazio próprio', (
    tester,
  ) async {
    await pumpOverlay(tester);

    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pumpAndSettle();

    expect(find.text('Nenhum resultado'), findsOneWidget);
    expect(find.byType(PinListItem), findsNothing);
  });

  testWidgets('Tab abre o preview do item selecionado', (tester) async {
    await pumpOverlay(tester);

    expect(find.byType(PinPreviewPane), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();

    expect(find.byType(PinPreviewPane), findsOneWidget);
    expect(find.text('Copiar'), findsOneWidget);
  });

  testWidgets('Esc fecha o overlay mesmo com o preview aberto', (tester) async {
    final closing = watchClosing();
    await pumpOverlay(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(find.byType(PinPreviewPane), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    // O preview não come o Esc: quem fecha o preview é o Tab, e o Esc vale
    // sempre a mesma coisa — sair.
    expect(closing, contains('beginHide'));
  });

  testWidgets('Tab volta do preview mantendo o texto buscado', (tester) async {
    await pumpOverlay(tester);

    await tester.enterText(find.byType(TextField), 'senha');
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();

    expect(find.text('Senha temporária: xK9#mPz2'), findsOneWidget);
    expect(find.byType(PinPreviewPane), findsNothing);
  });

  group('filtro por tipo', () {
    testWidgets('a fila mostra só os tipos que existem no histórico', (
      tester,
    ) async {
      await pumpOverlay(tester);

      expect(find.text('Tudo'), findsOneWidget);
      expect(find.text('Textos'), findsOneWidget);
      expect(find.text('Links'), findsOneWidget);
      // Nenhum comando no histórico do fixture — a pílula não existe.
      expect(find.text('Comandos'), findsNothing);
      // Menos o CPF, que está sempre: é atrás dele que mora o gerador.
      expect(find.text('CPF'), findsOneWidget);
    });

    testWidgets('a fila fica de pé mesmo com um tipo só no histórico', (
      tester,
    ) async {
      // Antes, com um tipo só, "Tudo | Textos" eram dois botões para a mesma
      // lista e a fila não se desenhava. O CPF quebrou o empate: a pílula dele
      // leva a um lugar que "Tudo" não tem — o gerador.
      repository = FakeClipboardRepository([
        item(1, 'Flutter'),
        item(2, 'Senha temporária: xK9#mPz2'),
      ]);

      await pumpOverlay(tester);

      expect(find.text('Tudo'), findsOneWidget);
      expect(find.text('CPF'), findsOneWidget);
    });

    testWidgets('escolher um tipo recorta a lista', (tester) async {
      await pumpOverlay(tester);

      await tester.tap(find.text('Links'));
      await tester.pumpAndSettle();

      expect(find.text('https://pub.dev/packages/sqlite3'), findsOneWidget);
      expect(find.text('Flutter'), findsNothing);
      expect(find.text('Senha temporária: xK9#mPz2'), findsNothing);
    });

    testWidgets('→ e ← andam pela fila, sem modificadora', (tester) async {
      await pumpOverlay(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();

      // As setas são os dois eixos da tela: ↑↓ pela lista, ←→ pela fila de
      // tipos logo acima dela. Da esquerda para a direita, "Tudo" dá lugar a
      // "Textos".
      expect(find.text('https://pub.dev/packages/sqlite3'), findsNothing);
      expect(find.text('Flutter'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();

      // E de volta a "Tudo", com o histórico inteiro.
      expect(find.text('https://pub.dev/packages/sqlite3'), findsOneWidget);
      expect(find.text('Flutter'), findsOneWidget);
    });

    testWidgets('as setas não tiram o teclado da busca', (tester) async {
      await pumpOverlay(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();

      // Trocar de filtro pela tecla não pode custar o cursor: quem filtra
      // costuma digitar em seguida.
      await tester.enterText(find.byType(EgSearchField), 'flut');
      await tester.pumpAndSettle();

      expect(find.text('Flutter'), findsOneWidget);
    });

    testWidgets('o rodapé ensina as setas do filtro', (tester) async {
      await pumpOverlay(tester);

      expect(find.text('filtro'), findsOneWidget);
    });

    // O caso "sem fila, o rodapé não promete o movimento" saiu junto com o
    // "sem fila": desde que o CPF passou a estar sempre na fila, não há
    // histórico que a faça sumir. O que resta guardado é o contrário — que a
    // dica só desapareça quando o rodapé estiver falando de outra coisa, o que
    // o teste do gerador cobre.

    testWidgets('Esc limpa o filtro antes de fechar o overlay', (tester) async {
      await pumpOverlay(tester);

      await tester.tap(find.text('Links'));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      // O histórico inteiro volta, e o painel continua aberto.
      expect(find.text('Flutter'), findsOneWidget);
      expect(find.byType(PinListItem), findsNWidgets(3));
    });

    testWidgets('o rodapé anuncia que o Esc limpa o filtro', (tester) async {
      await pumpOverlay(tester);
      expect(find.text('sair'), findsOneWidget);

      await tester.tap(find.text('Links'));
      await tester.pumpAndSettle();

      expect(find.text('limpar filtro'), findsOneWidget);
      expect(find.text('sair'), findsNothing);
    });

    testWidgets('com o preview aberto, o Esc ainda desfaz o filtro primeiro', (
      tester,
    ) async {
      final closing = watchClosing();
      await pumpOverlay(tester);

      await tester.tap(find.text('Links'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      // O filtro esconde itens, e é ele que o Esc desfaz antes de ir embora —
      // o preview, que não esconde nada, continua onde estava.
      expect(find.byType(PinListItem), findsNWidgets(3));
      expect(closing, isEmpty);
    });

    testWidgets('a busca corre dentro do tipo escolhido', (tester) async {
      await pumpOverlay(tester);

      await tester.tap(find.text('Links'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EgSearchField), 'senha');
      await tester.pumpAndSettle();

      expect(find.text('Nenhum resultado'), findsOneWidget);
      expect(
        find.text('Nada em Links corresponde à sua busca.'),
        findsOneWidget,
      );
    });

    testWidgets('apagar o último item de um tipo tira a pílula e o filtro', (
      tester,
    ) async {
      await pumpOverlay(tester);

      await tester.tap(find.text('Links'));
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
      await tester.pumpAndSettle();

      // Sem link nenhum, a fila deixa de fazer sentido — e a lista não pode
      // ficar vazia apontando para um filtro que não existe mais.
      expect(find.text('Links'), findsNothing);
      expect(find.byType(PinListItem), findsNWidgets(2));
    });
  });

  group('clique do mouse', () {
    testWidgets('clicar numa linha abre o preview dela', (tester) async {
      await pumpOverlay(tester);
      expect(find.byType(PinPreviewPane), findsNothing);

      await tester.tap(find.text('https://pub.dev/packages/sqlite3'));
      await tester.pumpAndSettle();

      expect(find.byType(PinPreviewPane), findsOneWidget);
      expect(find.text('Copiar'), findsOneWidget);
    });

    testWidgets('clicar num item e apertar Esc fecha o overlay', (
      tester,
    ) async {
      final closing = watchClosing();
      await pumpOverlay(tester);

      await tester.tap(find.text('https://pub.dev/packages/sqlite3'));
      await tester.pumpAndSettle();
      expect(find.byType(PinPreviewPane), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      // Um Esc só: o preview que o clique abriu não pode custar uma tecla a
      // mais para sair de um painel de acesso rápido.
      expect(closing, contains('beginHide'));
    });

    testWidgets('clicar não copia nada — quem copia é o botão', (tester) async {
      String? copiedText;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              copiedText = (call.arguments as Map)['text'] as String?;
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );

      await pumpOverlay(tester);

      await tester.tap(find.text('Senha temporária: xK9#mPz2'));
      await tester.pumpAndSettle();
      expect(copiedText, isNull);

      await tester.tap(find.text('Copiar'));
      await tester.pumpAndSettle();

      expect(copiedText, 'Senha temporária: xK9#mPz2');
    });

    testWidgets('clicar traz o apelido do item para o campo', (tester) async {
      repository.setAlias(2, 'sqlite');
      await pumpOverlay(tester);

      await tester.tap(find.textContaining('sqlite'));
      await tester.pumpAndSettle();

      final field = find.descendant(
        of: find.byType(EgTextField),
        matching: find.byType(TextField),
      );
      expect(tester.widget<TextField>(field).controller?.text, 'sqlite');
    });
  });

  group('apelido', () {
    /// O campo do preview, distinguido do campo de busca do topo.
    Finder aliasField() => find.byType(EgTextField);

    /// Lê o item do fixture direto do repositório — é lá que o apelido é
    /// gravado, e é isso que precisa sobreviver ao fechamento do overlay.
    ClipboardItem stored(int id) =>
        repository.loadAll().firstWhere((item) => item.id == id);

    testWidgets('⌘R abre o preview e leva o cursor ao apelido', (tester) async {
      await pumpOverlay(tester);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
      await tester.pumpAndSettle();

      expect(find.byType(PinPreviewPane), findsOneWidget);
      expect(aliasField(), findsOneWidget);
      expect(find.text('Apelido para achar depois'), findsOneWidget);

      // Com o cursor no campo, o rodapé fala só do que a tecla faz ali.
      expect(find.text('guardar apelido'), findsOneWidget);
      expect(find.text('descartar'), findsOneWidget);
    });

    testWidgets('Enter guarda o apelido e ele aparece na lista', (
      tester,
    ) async {
      await pumpOverlay(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      await tester.enterText(aliasField(), 'chave pix');
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(stored(1).alias, 'chave pix');
      // O conteúdo não é tocado: o apelido só muda o que se lê na lista.
      expect(stored(1).content, 'Flutter');
      expect(find.textContaining('chave pix'), findsWidgets);

      // O Enter guardou em vez de copiar e fechar: a lista continua ali.
      expect(find.byType(PinListItem), findsWidgets);
    });

    testWidgets('Esc descarta o que foi digitado sem fechar o preview', (
      tester,
    ) async {
      await pumpOverlay(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.enterText(aliasField(), 'chave pix');
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(stored(1).alias, isNull);
      expect(find.byType(PinPreviewPane), findsOneWidget);
    });

    /// Só no macOS, que é onde o `TextField` larga o foco a cada clique fora
    /// dele. O campo de busca já se defende disso (`holdsFocus`), mas o do
    /// apelido não: sem o escopo da casca, o foco largado por ele ia parar
    /// acima do `Shortcuts` do painel e levava o teclado inteiro junto — ver
    /// `EgOverlayShell`.
    testWidgets(
      'clicar fora do apelido não emudece o Esc do painel',
      (tester) async {
        final closing = watchClosing();
        await pumpOverlay(tester);

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        await tester.enterText(aliasField(), 'chave pix');
        await tester.pumpAndSettle();

        // Um clique no rodapé de dicas: dentro do painel, fora de qualquer campo
        // e fora da lista.
        await tester.tapAt(tester.getCenter(find.text('guardar apelido')));
        await tester.pumpAndSettle();

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();

        expect(closing, contains('beginHide'));
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );

    testWidgets('trocar de item guarda o apelido do anterior', (tester) async {
      await pumpOverlay(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.enterText(aliasField(), 'chave pix');
      await tester.pumpAndSettle();

      // Clicar em outra linha troca a seleção sem tirar o foco do campo — é o
      // caminho em que o texto digitado poderia acabar no item errado. A espera
      // é o tempo do duplo clique: até ele passar, a linha ainda não sabe se o
      // clique foi simples (selecionar) ou duplo (copiar).
      await tester.tap(find.byType(PinListItem).at(1));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(stored(1).alias, 'chave pix');
      // O campo recarrega para o item da vez, que não tem apelido nenhum.
      expect(tester.widget<EgTextField>(aliasField()).controller.text, isEmpty);
    });

    testWidgets('copiar um item apelidado copia o conteúdo original', (
      tester,
    ) async {
      String? copiedText;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              copiedText = (call.arguments as Map)['text'] as String?;
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );

      repository.setAlias(1, 'chave pix');
      await pumpOverlay(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(copiedText, 'Flutter');
    });

    testWidgets('a busca acha o item pelo apelido', (tester) async {
      repository.setAlias(1, 'chave pix');
      await pumpOverlay(tester);

      // "pix" não aparece em lugar nenhum do conteúdo dos itens.
      await tester.enterText(find.byType(EgSearchField), 'pix');
      await tester.pumpAndSettle();

      expect(find.byType(PinListItem), findsOneWidget);
      expect(find.textContaining('chave pix'), findsOneWidget);
    });
  });

  group('atalhos rápidos', () {
    /// Lê o que foi parar na área de transferência do sistema.
    String? copiedText;

    setUp(() {
      copiedText = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              copiedText = (call.arguments as Map)['text'] as String?;
            }
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    testWidgets('badges numeram cada grupo a partir de 1', (tester) async {
      await pumpOverlay(tester);

      // Fixado no topo e primeiro recente convivem com o número 1, em camadas
      // diferentes — é o ponto do esquema de dois grupos.
      expect(find.text('⌥1'), findsOneWidget);
      expect(find.text('⌘1'), findsOneWidget);
      expect(find.text('⌘2'), findsOneWidget);
    });

    testWidgets('⌘1 copia o recente mais novo, não o primeiro da lista', (
      tester,
    ) async {
      await pumpOverlay(tester);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
      await tester.pumpAndSettle();

      expect(copiedText, 'https://pub.dev/packages/sqlite3');
    });

    testWidgets('⌥1 copia o primeiro fixado', (tester) async {
      await pumpOverlay(tester);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.alt);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.alt);
      await tester.pumpAndSettle();

      expect(copiedText, 'Flutter');
    });

    testWidgets('slot vazio não copia nada', (tester) async {
      await pumpOverlay(tester);

      // Só existe um item fixado, então ⌥4 não aponta para lugar nenhum.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.alt);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit4);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.alt);
      await tester.pumpAndSettle();

      expect(copiedText, isNull);
    });

    testWidgets('⌘P fixa o item selecionado e o move para o topo', (
      tester,
    ) async {
      await pumpOverlay(tester);

      // Seleciona o primeiro recente.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
      await tester.pumpAndSettle();

      final pinned = tester
          .widgetList<PinListItem>(find.byType(PinListItem))
          .where((widget) => widget.item.isPinned)
          .map((widget) => widget.item.content);

      expect(pinned, contains('https://pub.dev/packages/sqlite3'));
      // Fixado depois do 'Flutter', então herda o segundo slot da camada ⌥.
      expect(find.text('⌥2'), findsOneWidget);
    });
  });

  group('reordenar fixados', () {
    /// Fixado com posição explícita no grupo — `pinned_at` crescente, como o
    /// `ORDER BY pinned_at ASC` do banco.
    ClipboardItem pinnedAt(int id, String content, {required int position}) {
      return ClipboardItem(
        id: id,
        content: content,
        type: ClipboardItemClassifier.classify(content),
        isPinned: true,
        copiedAt: base.subtract(Duration(minutes: id)),
        pinnedAt: base.add(Duration(minutes: position)),
      );
    }

    List<String> pinnedOrder(WidgetTester tester) => tester
        .widgetList<PinListItem>(find.byType(PinListItem))
        .where((widget) => widget.item.isPinned)
        .map((widget) => widget.item.content)
        .toList();

    String selectedOf(WidgetTester tester) => tester
        .widgetList<PinListItem>(find.byType(PinListItem))
        .firstWhere((widget) => widget.isSelected)
        .item
        .content;

    Future<void> pressOption(
      WidgetTester tester,
      LogicalKeyboardKey key,
    ) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.alt);
      await tester.sendKeyEvent(key);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.alt);
      await tester.pumpAndSettle();
    }

    setUp(() {
      repository = FakeClipboardRepository([
        pinnedAt(1, 'Alfa', position: 0),
        pinnedAt(2, 'Beta', position: 1),
        pinnedAt(3, 'Gama', position: 2),
        item(4, 'recente'),
      ]);
    });

    testWidgets('⌥↓ desce o fixado e leva a seleção junto', (tester) async {
      await pumpOverlay(tester);
      expect(pinnedOrder(tester), ['Alfa', 'Beta', 'Gama']);

      await pressOption(tester, LogicalKeyboardKey.arrowDown);

      expect(pinnedOrder(tester), ['Beta', 'Alfa', 'Gama']);
      // Quem se move é a linha, não o cursor.
      expect(selectedOf(tester), 'Alfa');
    });

    testWidgets('⌥↑ sobe o fixado', (tester) async {
      await pumpOverlay(tester);

      // Desce a seleção até 'Gama', o último fixado.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();

      await pressOption(tester, LogicalKeyboardKey.arrowUp);

      expect(pinnedOrder(tester), ['Alfa', 'Gama', 'Beta']);
      expect(selectedOf(tester), 'Gama');
    });

    testWidgets('reordenar renumera os atalhos ⌥N', (tester) async {
      await pumpOverlay(tester);

      // 'Alfa' é o ⌥1 antes da troca.
      expect(
        tester
            .widgetList<PinListItem>(find.byType(PinListItem))
            .firstWhere((widget) => widget.item.content == 'Alfa')
            .shortcut
            ?.number,
        1,
      );

      await pressOption(tester, LogicalKeyboardKey.arrowDown);

      expect(
        tester
            .widgetList<PinListItem>(find.byType(PinListItem))
            .firstWhere((widget) => widget.item.content == 'Alfa')
            .shortcut
            ?.number,
        2,
      );
    });

    testWidgets('⌥↓ no último fixado não o joga para os recentes', (
      tester,
    ) async {
      await pumpOverlay(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();

      await pressOption(tester, LogicalKeyboardKey.arrowDown);

      expect(pinnedOrder(tester), ['Alfa', 'Beta', 'Gama']);
      expect(selectedOf(tester), 'Gama');
    });

    testWidgets('⌥↑ num recente não mexe em nada', (tester) async {
      await pumpOverlay(tester);

      // Quarta linha: o único item não fixado.
      for (var i = 0; i < 3; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      }
      await tester.pumpAndSettle();
      expect(selectedOf(tester), 'recente');

      await pressOption(tester, LogicalKeyboardKey.arrowUp);

      expect(pinnedOrder(tester), ['Alfa', 'Beta', 'Gama']);
      expect(selectedOf(tester), 'recente');
    });

    testWidgets('o rodapé só anuncia ⌥↑↓ dentro dos fixados', (tester) async {
      await pumpOverlay(tester);
      expect(find.text('mover'), findsOneWidget);

      for (var i = 0; i < 3; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      }
      await tester.pumpAndSettle();

      expect(find.text('mover'), findsNothing);
    });

    testWidgets('com o ⌥↑↓ na linha, o ↑↓ sozinho sai', (tester) async {
      await pumpOverlay(tester);

      // O ⌥↑↓ já desenha as setas verticais ao lado: repetir o par sozinho
      // gastaria largura para dizer duas vezes a mesma coisa.
      expect(find.text('mover'), findsOneWidget);
      expect(find.text('↑↓'), findsNothing);
      expect(find.text('⌥↑↓'), findsOneWidget);

      for (var i = 0; i < 3; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      }
      await tester.pumpAndSettle();

      // Fora dos fixados o par volta, porque não há mais quem o represente.
      expect(find.text('↑↓'), findsOneWidget);
    });

    /// Nenhuma dica do grupo da esquerda pode invadir o `esc`.
    ///
    /// O grupo vive num viewport que recorta em silêncio: o que não cabe é
    /// cortado no meio da palavra, e era isso que encostava um `tab` pela
    /// metade no `esc`. Medir é a única forma de prender — não há exceção de
    /// estouro para o teste pegar.
    void expectCabeNaLinha(WidgetTester tester) {
      final caps = find.byType(EgShortcutDisplay);
      final total = caps.evaluate().length;
      final saida = tester.getRect(caps.at(total - 1));

      for (var i = 0; i < total - 1; i++) {
        expect(
          tester.getRect(caps.at(i)).right,
          lessThan(saida.left),
          reason: 'a dica ${i + 1} de $total invade a saída',
        );
      }
    }

    testWidgets('o tab está na linha nos dois estados', (tester) async {
      repository = FakeClipboardRepository([
        item(1, 'Flutter', isPinned: true),
        item(2, 'https://pub.dev/packages/sqlite3', isPinned: true),
        item(3, 'Senha temporária: xK9#mPz2'),
      ]);
      await pumpOverlay(tester);

      // Na lista cheia ele entra sem o verbo: a tecla que abre e fecha o item
      // vale mais presente e muda do que ausente e explicada.
      expect(find.text('tab'), findsOneWidget);
      expect(find.text('ver'), findsNothing);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      // Com o item aberto ele é o caminho de volta, e aí o verbo cabe.
      expect(find.text('tab'), findsOneWidget);
      expect(find.text('voltar'), findsOneWidget);
    });

    testWidgets('com o item aberto, o ⌘P diz o que vai acontecer', (
      tester,
    ) async {
      repository = FakeClipboardRepository([
        item(1, 'Flutter', isPinned: true),
        item(2, 'https://pub.dev/packages/sqlite3'),
      ]);
      await pumpOverlay(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      // A seleção abre no primeiro fixado: ali a tecla desfixa.
      expect(find.text('desfixar'), findsOneWidget);
      expect(find.text('fixar'), findsNothing);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();

      // Um recente: a mesma tecla, o verbo contrário.
      expect(find.text('fixar'), findsOneWidget);
      expect(find.text('desfixar'), findsNothing);
    });

    testWidgets('o rodapé cabe na linha com fila e fixados', (tester) async {
      // O pior caso do painel estreito: dois fixados (para o ⌥↑↓) de tipos
      // diferentes (para a fila), com o preview fechado.
      repository = FakeClipboardRepository([
        item(1, 'Flutter', isPinned: true),
        item(2, 'https://pub.dev/packages/sqlite3', isPinned: true),
        item(3, 'Senha temporária: xK9#mPz2'),
      ]);
      await pumpOverlay(tester);

      expect(find.text('mover'), findsOneWidget);
      expect(find.text('filtro'), findsOneWidget);
      expectCabeNaLinha(tester);
    });

    testWidgets('cabe também com a fila e sem fixado selecionado', (
      tester,
    ) async {
      await pumpOverlay(tester);
      for (var i = 0; i < 3; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      }
      await tester.pumpAndSettle();

      expectCabeNaLinha(tester);
    });

    testWidgets('e com o preview aberto, onde o painel é mais largo', (
      tester,
    ) async {
      await pumpOverlay(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      expect(find.text('apelido'), findsOneWidget);
      expect(find.text('voltar'), findsOneWidget);
      expectCabeNaLinha(tester);
    });

    testWidgets('um fixado sozinho não anuncia ⌥↑↓', (tester) async {
      repository = FakeClipboardRepository([
        pinnedAt(1, 'Alfa', position: 0),
        item(4, 'recente'),
      ]);
      await pumpOverlay(tester);

      expect(selectedOf(tester), 'Alfa');
      expect(find.text('mover'), findsNothing);
    });
  });

  testWidgets('⌘⌫ apaga o selecionado e mantém a seleção no vizinho', (
    tester,
  ) async {
    await pumpOverlay(tester);

    // Vai para o primeiro recente, que tem um item logo abaixo.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
    await tester.pumpAndSettle();

    expect(find.text('https://pub.dev/packages/sqlite3'), findsNothing);

    // O overlay continua aberto e a seleção caiu sobre quem tomou o lugar.
    final selected = tester
        .widgetList<PinListItem>(find.byType(PinListItem))
        .firstWhere((widget) => widget.isSelected);

    expect(selected.item.content, 'Senha temporária: xK9#mPz2');
  });

  testWidgets('linha sem atalho mostra o horário relativo', (tester) async {
    // Com seis recentes, o último fica fora dos cinco slots de ⌘N — é a linha
    // que exibe o tempo em vez do badge de atalho. Os instantes são relativos a
    // agora porque é isso que o texto formata.
    final now = DateTime.now();
    repository = FakeClipboardRepository([
      for (var minutes = 1; minutes <= 6; minutes++)
        ClipboardItem.capture(
          'item $minutes',
          at: now.subtract(Duration(minutes: minutes)),
        ).copyWith(id: minutes),
    ]);
    await pumpOverlay(tester);

    expect(find.text('⌘5'), findsOneWidget);
    expect(find.text('⌘6'), findsNothing);
    expect(find.text('há 6 min'), findsOneWidget);
  });

  testWidgets('histórico vazio mostra a mensagem de boas-vindas', (
    tester,
  ) async {
    repository = FakeClipboardRepository();
    await pumpOverlay(tester);

    expect(find.text('Nenhum item ainda'), findsOneWidget);
  });

  group('gerador de CPF', () {
    /// Um CPF de verdade no histórico, para o filtro ter uma lista embaixo da
    /// linha do gerador — é o que faz a navegação por setas ter dois degraus.
    const storedTaxId = '529.982.247-25';

    /// Lê o que foi parar na área de transferência do sistema.
    String? copiedText;

    /// Canais que o caminho de cópia atravessa até o fim.
    ///
    /// Os outros testes de cópia deste arquivo param no `copiedText`: sob o
    /// relógio falso a espera pela resposta do canal da área de transferência
    /// não retoma, e nada do que vem depois dela acontece. Aqui o que interessa
    /// é justamente o depois — gravar e fechar —, então os testes que precisam
    /// disso rodam dentro de `runAsync`, e aí o `window_manager` também precisa
    /// responder, senão o `hide` estoura no meio.
    setUp(() {
      copiedText = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              copiedText = (call.arguments as Map)['text'] as String?;
            }
            return null;
          });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('window_manager'),
            (call) async => null,
          );

      repository = FakeClipboardRepository([
        item(1, 'Flutter', isPinned: true),
        item(2, storedTaxId),
      ]);
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('window_manager'),
            null,
          );
    });

    /// O número que a linha está exibindo agora.
    String shownTaxId(WidgetTester tester) =>
        tester.widget<PinGeneratorRow>(find.byType(PinGeneratorRow)).taxId;

    Future<void> openTaxIdFilter(WidgetTester tester) async {
      await tester.tap(find.text('CPF'));
      await tester.pumpAndSettle();
    }

    testWidgets('a linha só existe dentro do filtro de CPF', (tester) async {
      await pumpOverlay(tester);

      expect(find.byType(PinGeneratorRow), findsNothing);

      await openTaxIdFilter(tester);

      expect(find.byType(PinGeneratorRow), findsOneWidget);
      // `textContaining` porque rótulo e número dividem o mesmo parágrafo, para
      // o corte por ellipsis comer o número antes do que a linha é.
      expect(find.textContaining('Gerar CPF'), findsOneWidget);
      expect(
        shownTaxId(tester),
        matches(RegExp(r'^\d{3}\.\d{3}\.\d{3}-\d{2}$')),
      );
    });

    testWidgets('sair do filtro leva a linha junto', (tester) async {
      await pumpOverlay(tester);
      await openTaxIdFilter(tester);

      await tester.tap(find.text('Tudo'));
      await tester.pumpAndSettle();

      expect(find.byType(PinGeneratorRow), findsNothing);
    });

    testWidgets('a linha aparece mesmo sem nenhum CPF no histórico', (
      tester,
    ) async {
      // O caso que decidiu a pílula fixa: sem isto, o gerador só apareceria
      // para quem já tem um CPF guardado — e ele existe justamente para quem
      // não tem.
      repository = FakeClipboardRepository();
      await pumpOverlay(tester);
      await openTaxIdFilter(tester);

      expect(find.byType(PinGeneratorRow), findsOneWidget);
      // E o estado vazio não cobre a linha: há o que fazer ali.
      expect(find.text('Nenhum item ainda'), findsNothing);
      expect(find.text('Nenhum resultado'), findsNothing);
    });

    testWidgets('digitar na busca não sorteia outro número', (tester) async {
      await pumpOverlay(tester);
      await openTaxIdFilter(tester);

      final before = shownTaxId(tester);

      await tester.enterText(find.byType(EgSearchField), 'a');
      await tester.pumpAndSettle();

      // Um número que trocasse a cada tecla seria ilegível justamente para quem
      // está conferindo dígito a dígito.
      expect(shownTaxId(tester), before);
    });

    testWidgets('↑ a partir do primeiro item alcança a linha', (tester) async {
      await pumpOverlay(tester);
      await openTaxIdFilter(tester);

      // A seleção começa no primeiro item da lista; o gerador fica um degrau
      // acima dele.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();

      final row = tester.widget<PinGeneratorRow>(find.byType(PinGeneratorRow));
      expect(row.isSelected, isTrue);
    });

    testWidgets('com a linha selecionada o rodapé fala dela', (tester) async {
      await pumpOverlay(tester);
      await openTaxIdFilter(tester);

      // Com o CPF do histórico selecionado, o rodapé ainda é o da lista.
      expect(find.text('sortear'), findsNothing);
      expect(find.text('fixar'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();

      expect(find.text('sortear'), findsOneWidget);
      // "copiar" ganha rótulo aqui porque em cima de "Gerar CPF" a dúvida é
      // real: se o Enter gera ou se copia o que já está escrito.
      expect(find.text('copiar'), findsOneWidget);
      // Fixar e reordenar não existem para uma linha que ainda não é um item.
      expect(find.text('fixar'), findsNothing);
    });

    testWidgets('⌘G sorteia outro sem fechar o painel', (tester) async {
      final closing = watchClosing();
      await pumpOverlay(tester);
      await openTaxIdFilter(tester);

      final before = shownTaxId(tester);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
      await tester.pumpAndSettle();

      expect(shownTaxId(tester), isNot(before));
      expect(closing, isEmpty);
    });

    testWidgets('Enter na linha copia o número e fecha', (tester) async {
      final closing = watchClosing();
      await pumpOverlay(tester);
      await openTaxIdFilter(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();

      final generated = shownTaxId(tester);

      // Dentro de `runAsync` porque copiar atravessa o canal da área de
      // transferência: sob o relógio falso do teste a espera pela resposta não
      // retoma, e o que vem depois dela — gravar e fechar — nunca acontece.
      await tester.runAsync(() async {
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        // A cópia continua em outra volta do laço de eventos — sem esperar por
        // ela, o teste olharia para o meio do caminho.
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();

      expect(copiedText, generated);
      expect(closing, contains('beginHide'));

      // O gerado entra no histórico como qualquer cópia — é o que o faz voltar
      // depois em ⌘1, e já classificado como CPF.
      final stored = repository.loadAll().where(
        (item) => item.content == generated,
      );
      expect(stored, hasLength(1));
      expect(stored.single.type, ClipboardItemType.cpf);
    });

    testWidgets('clicar na linha copia e fecha, sem abrir preview', (
      tester,
    ) async {
      final closing = watchClosing();
      await pumpOverlay(tester);
      await openTaxIdFilter(tester);

      final generated = shownTaxId(tester);

      await tester.runAsync(() async {
        await tester.tap(find.textContaining('Gerar CPF'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();

      // A exceção à regra "clique abre o preview": esta linha não tem um
      // dentro para mostrar — o conteúdo inteiro já está escrito nela.
      expect(copiedText, generated);
      expect(find.byType(PinPreviewPane), findsNothing);
      expect(closing, contains('beginHide'));
    });

    testWidgets('o botão de sortear troca o número e fica', (tester) async {
      final closing = watchClosing();
      await pumpOverlay(tester);
      await openTaxIdFilter(tester);

      final before = shownTaxId(tester);

      await tester.tap(find.bySemanticsLabel('Sortear outro CPF'));
      await tester.pumpAndSettle();

      expect(shownTaxId(tester), isNot(before));
      expect(closing, isEmpty);
    });

    /// O CNPJ é o mesmo gerador, na pílula ao lado.
    ///
    /// O que estes testes prendem não é a conta — essa é do `tax_id_test.dart`,
    /// que gera mil de cada e confere pelo classificador. É a **troca**: a
    /// linha, o rótulo e o número têm de acompanhar o filtro, e nenhum pedaço
    /// pode sobrar do documento anterior.
    group('e de CNPJ', () {
      Future<void> openCnpjFilter(WidgetTester tester) async {
        await tester.tap(find.text('CNPJ'));
        await tester.pumpAndSettle();
      }

      testWidgets('a pílula existe mesmo sem nenhum CNPJ no histórico', (
        tester,
      ) async {
        repository = FakeClipboardRepository();
        await pumpOverlay(tester);

        expect(find.text('CNPJ'), findsOneWidget);
      });

      testWidgets('o filtro de CNPJ gera um CNPJ, não um CPF', (tester) async {
        await pumpOverlay(tester);
        await openCnpjFilter(tester);

        expect(find.textContaining('Gerar CNPJ'), findsOneWidget);
        expect(find.textContaining('Gerar CPF'), findsNothing);
        expect(
          shownTaxId(tester),
          matches(RegExp(r'^\d{2}\.\d{3}\.\d{3}/\d{4}-\d{2}$')),
        );
      });

      testWidgets('trocar de documento troca o número junto', (tester) async {
        // O caso que o campo `_generatedKind` existe para resolver: o número é
        // preservado *dentro* de um filtro, e preservá-lo entre filtros
        // deixaria um CPF escrito na linha "Gerar CNPJ".
        await pumpOverlay(tester);
        await openTaxIdFilter(tester);

        final cpf = shownTaxId(tester);

        await openCnpjFilter(tester);
        final cnpj = shownTaxId(tester);

        expect(cnpj, isNot(cpf));
        expect(cnpj, contains('/'));

        // E a volta também: o CPF de antes não precisa ser o mesmo, mas o que
        // está na linha tem de ser um CPF.
        await openTaxIdFilter(tester);
        expect(shownTaxId(tester), isNot(contains('/')));
      });

      testWidgets('⌘G sorteia outro CNPJ sem sair', (tester) async {
        final closing = watchClosing();
        await pumpOverlay(tester);
        await openCnpjFilter(tester);

        final before = shownTaxId(tester);

        await tester.tap(find.bySemanticsLabel('Sortear outro CNPJ'));
        await tester.pumpAndSettle();

        expect(shownTaxId(tester), isNot(before));
        expect(shownTaxId(tester), contains('/'));
        expect(closing, isEmpty);
      });

      testWidgets('o CNPJ copiado volta ao histórico já classificado', (
        tester,
      ) async {
        // O caminho de cópia vai até o fim (gravar e fechar), e por isso
        // precisa dos canais que ele atravessa — ver `watchClosing`.
        watchClosing();
        await pumpOverlay(tester);
        await openCnpjFilter(tester);

        final generated = shownTaxId(tester);

        await tester.runAsync(() async {
          await tester.tap(find.textContaining('Gerar CNPJ'));
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pumpAndSettle();

        expect(copiedText, generated);

        final stored = repository.loadAll().where(
          (item) => item.content == generated,
        );
        expect(stored, hasLength(1));
        expect(stored.single.type, ClipboardItemType.cnpj);
      });
    });
  });
}
