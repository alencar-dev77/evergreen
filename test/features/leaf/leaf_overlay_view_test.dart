import 'package:evergreen/app/providers.dart';
import 'package:evergreen/core/design/app_theme.dart';
import 'package:evergreen/core/window/overlay_window.dart';
import 'package:evergreen/features/leaf/models/leaf_note.dart';
import 'package:evergreen/features/leaf/presentation/viewmodels/leaf_state.dart';
import 'package:evergreen/features/leaf/presentation/viewmodels/leaf_view_model.dart';
import 'package:evergreen/features/leaf/presentation/views/leaf_overlay_view.dart';
import 'package:evergreen/features/leaf/presentation/widgets/leaf_note_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_leaf_repository.dart';

void main() {
  late FakeLeafRepository repository;

  final clock = DateTime(2026, 8, 4, 10);

  setUp(() {
    repository = FakeLeafRepository();
    // O overlay é um singleton, e cada Esc deixa nele o rastro de um fechamento
    // que o ambiente de teste não tem como terminar — ver `resetForTest`.
    OverlayWindow.instance.resetForTest();
  });

  /// Observa o fechamento do painel.
  ///
  /// `OverlayWindow.hide` começa avisando o lado nativo (`beginHide`), então é
  /// essa chamada que diz "o painel está indo embora" sem precisar de janela de
  /// verdade no ambiente de teste.
  List<String> watchClosing() {
    final calls = <String>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const channel = MethodChannel('previous_app_focus');

    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    return calls;
  }

  Future<ProviderContainer> pumpPanel(WidgetTester tester) async {
    // A parede cheia tem 3 linhas de 164px mais o rodapé: a janela padrão do
    // teste (800x600) é menor que o painel e acusaria estouro de layout no que
    // no aplicativo real cabe folgado.
    tester.view.physicalSize = const Size(1600, 1600);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          leafRepositoryProvider.overrideWithValue(repository),
          clockProvider.overrideWithValue(() => clock),
        ],
        child: MaterialApp(
          theme: AppTheme.build(),
          home: const LeafOverlayView(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    return ProviderScope.containerOf(
      tester.element(find.byType(LeafOverlayView)),
    );
  }

  LeafState stateOf(ProviderContainer container) =>
      container.read(leafViewModelProvider);

  LeafViewModel viewModelOf(ProviderContainer container) =>
      container.read(leafViewModelProvider.notifier);

  testWidgets('a parede vazia mostra as nove vagas, e só uma convida', (
    tester,
  ) async {
    await pumpPanel(tester);

    // As nove desenhadas: a vaga é um endereço fixo, e o número dela precisa
    // querer dizer alguma coisa antes de existir cartão.
    expect(find.byType(LeafEmptySlot), findsNWidgets(LeafNote.maxNotes));
    expect(find.byType(LeafNoteCard), findsNothing);
    // Mas o convite é um só — repetido em nove, a parede vazia viraria cartaz.
    expect(find.text('enter pra criar'), findsOneWidget);
    // O rodapé fala do que a vaga selecionada faz — nela, o Enter anota.
    expect(find.text('anotar'), findsOneWidget);
    expect(find.text('fechar'), findsOneWidget);
  });

  testWidgets('escrever no cartão e confirmar cola a anotação na parede', (
    tester,
  ) async {
    final container = await pumpPanel(tester);

    viewModelOf(container).startNote();
    await tester.pumpAndSettle();

    expect(find.byType(LeafNoteEditor), findsOneWidget);
    // Com o cartão em edição sobram duas teclas no rodapé.
    expect(find.text('guardar'), findsOneWidget);
    expect(find.text('descartar'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'ligar pro contador');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.byType(LeafNoteEditor), findsNothing);
    expect(find.text('ligar pro contador'), findsOneWidget);
    expect(stateOf(container).noteAt(1)?.content, 'ligar pro contador');
  });

  testWidgets('o cartão abre com o teclado dentro dele, sem precisar clicar', (
    tester,
  ) async {
    final container = await pumpPanel(tester);

    viewModelOf(container).startNote();
    await tester.pumpAndSettle();

    // O `autofocus` do campo não bastaria: ele só vale quando nada no escopo
    // tem o foco, e o painel sempre tem.
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.focusNode?.hasFocus, isTrue);
  });

  testWidgets('⇧⏎ não guarda a anotação — a tecla pertence ao texto', (
    tester,
  ) async {
    final container = await pumpPanel(tester);

    viewModelOf(container).startNote();
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'primeira linha');

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();

    // O cartão continua em edição: com o Shift junto, o Enter desce até o campo
    // em vez de ser consumido pelo mapa de atalhos do painel.
    expect(find.byType(LeafNoteEditor), findsOneWidget);
    expect(stateOf(container).isEditing, isTrue);
  });

  testWidgets('o campo abre com o texto que já existia', (tester) async {
    repository.create(slot: 1, content: 'comprar café', createdAt: clock);
    final container = await pumpPanel(tester);

    viewModelOf(container).editSlot(1);
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text, 'comprar café');
    // O cursor vai para o fim: editar é continuar a frase.
    expect(field.controller?.selection.baseOffset, 'comprar café'.length);
  });

  testWidgets('o cartão mostra o número da vaga, que é a tecla que o copia', (
    tester,
  ) async {
    repository.create(slot: 1, content: 'primeira', createdAt: clock);
    repository.create(slot: 2, content: 'segunda', createdAt: clock);
    await pumpPanel(tester);

    // Toda vaga mostra o número dela, ocupada ou não: ele é o endereço, e é a
    // tecla que copia. As vazias mostram o mesmo número em traço apagado.
    for (final slot in LeafNote.slots) {
      expect(find.text('$slot'), findsOneWidget, reason: 'vaga $slot');
    }
    // E as duas primeiras são cartão, não vaga.
    expect(find.byType(LeafNoteCard), findsNWidgets(2));
    expect(find.byType(LeafEmptySlot), findsNWidgets(LeafNote.maxNotes - 2));
  });

  testWidgets('apagar não deixa buraco, e a parede continua inteira', (
    tester,
  ) async {
    for (var slot = 1; slot <= 4; slot++) {
      repository.create(slot: slot, content: 'nota $slot', createdAt: clock);
    }
    final container = await pumpPanel(tester);

    // A parede é sempre a parede: quatro cartões e cinco vagas vazias.
    expect(find.byType(LeafNoteCard), findsNWidgets(4));
    expect(stateOf(container).rows, 3);

    viewModelOf(container).selectSlot(2);
    viewModelOf(container).deleteSelected();
    await tester.pumpAndSettle();

    expect(find.byType(LeafNoteCard), findsNWidgets(3));
    expect(find.text('nota 2'), findsNothing);
    // A que estava embaixo subiu: nada de buraco no meio da parede.
    expect(stateOf(container).noteAt(2)?.content, 'nota 3');
    expect(stateOf(container).rows, 3);

    viewModelOf(container).deleteSelected();
    viewModelOf(container).deleteSelected();
    await tester.pumpAndSettle();

    // A parede não encolheu — o que encolheu foi o que o teclado alcança.
    expect(stateOf(container).rows, 3);
    expect(stateOf(container).lastSelectableSlot, 2);
  });

  testWidgets('apagar oferece o desfazer, e o ⌘Z devolve o cartão', (
    tester,
  ) async {
    for (var slot = 1; slot <= 3; slot++) {
      repository.create(slot: slot, content: 'nota $slot', createdAt: clock);
    }
    final container = await pumpPanel(tester);

    // Em repouso o rodapé não fala de desfazer: não há o que desfazer.
    expect(find.text('desfazer'), findsNothing);

    viewModelOf(container)
      ..selectSlot(2)
      ..deleteSelected();
    await tester.pumpAndSettle();

    expect(find.text('nota 2'), findsNothing);
    // A dica aparece onde a dúvida nasce — "cadê o cartão que eu arranquei?".
    expect(find.text('desfazer'), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pumpAndSettle();

    expect(find.text('nota 2'), findsOneWidget);
    expect(stateOf(container).noteAt(2)?.content, 'nota 2');
    // Cumprida a oferta, ela sai do rodapé.
    expect(find.text('desfazer'), findsNothing);
  });

  testWidgets('a dica de desfazer também é o alvo de mouse do ⌘Z', (
    tester,
  ) async {
    repository.create(slot: 1, content: 'única', createdAt: clock);
    final container = await pumpPanel(tester);

    viewModelOf(container)
      ..selectSlot(1)
      ..deleteSelected();
    await tester.pumpAndSettle();

    // Nenhuma ação do Evergreen é só de teclado — e com a parede vazia não
    // sobrou nem cartão onde clicar.
    await tester.tap(find.text('desfazer'));
    await tester.pumpAndSettle();

    expect(find.text('única'), findsOneWidget);
  });

  testWidgets('o cartão editado mostra a data da edição', (tester) async {
    // Contra o relógio real: a idade de um cartão é contada a partir de agora,
    // e é `RelativeTime` quem a lê — o `clockProvider` do painel não chega até
    // o rodapé do cartão.
    final agora = DateTime.now();

    repository.create(
      slot: 1,
      content: 'reescrita hoje',
      createdAt: agora.subtract(const Duration(days: 21)),
      updatedAt: agora.subtract(const Duration(minutes: 5)),
    );
    repository.create(
      slot: 2,
      content: 'nunca tocada',
      createdAt: agora.subtract(const Duration(days: 21)),
    );
    await pumpPanel(tester);

    // O rodapé do cartão mostra a idade do recado, não a do papel: antes, a
    // anotação reescrita há cinco minutos dizia "há 3 semanas" como a outra.
    expect(find.text('há 5 min'), findsOneWidget);
    expect(find.text('há 3 semanas'), findsOneWidget);
  });

  testWidgets('a parede cheia deixa de convidar', (tester) async {
    for (final slot in LeafNote.slots) {
      repository.create(slot: slot, content: 'nota $slot', createdAt: clock);
    }
    await pumpPanel(tester);

    expect(find.byType(LeafNoteCard), findsNWidgets(LeafNote.maxNotes));
    expect(find.byType(LeafEmptySlot), findsNothing);
    // Sem vaga livre, o rodapé não promete uma anotação nova.
    expect(find.text('enter pra criar'), findsNothing);
  });

  /// O que um clique dentro do painel faz com o teclado.
  ///
  /// Só no macOS, e é por isso que o grupo declara a plataforma: lá o
  /// `TextField` larga o foco a cada clique fora dele, e o foco largado ia
  /// parar no escopo da rota — acima do `Shortcuts` do painel, de onde tecla
  /// nenhuma volta a descer. O painel ficava só de mouse, e o Esc era o
  /// sintoma que se notava primeiro. Nas outras plataformas o campo não larga
  /// nada, e o teste passaria sem testar.
  group('o clique não leva o teclado embora', () {
    final macOS = TargetPlatformVariant.only(TargetPlatform.macOS);

    testWidgets('clicar no painel guarda o cartão e devolve o teclado', (
      tester,
    ) async {
      final container = await pumpPanel(tester);

      viewModelOf(container).startNote();
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'comprar café');

      // Um clique dentro do painel, fora do cartão: o rodapé de dicas.
      await tester.tapAt(tester.getCenter(find.text('guardar')));
      await tester.pumpAndSettle();

      // Sair do campo guarda, por qualquer caminho — a convenção do produto.
      expect(repository.loadAll().single.content, 'comprar café');
      expect(stateOf(container).isEditing, isFalse);
    }, variant: macOS);

    testWidgets('depois do clique, um Esc só fecha o painel', (tester) async {
      final closing = watchClosing();
      final container = await pumpPanel(tester);

      viewModelOf(container).startNote();
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'comprar café');

      await tester.tapAt(tester.getCenter(find.text('guardar')));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(closing, contains('beginHide'));
    }, variant: macOS);
  });

  testWidgets('fechar o painel guarda o que estava sendo escrito', (
    tester,
  ) async {
    final container = await pumpPanel(tester);

    viewModelOf(container).startNote();
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'não pode sumir');

    // Clicar fora do painel é um dos caminhos de fechamento.
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(repository.loadAll().single.content, 'não pode sumir');
  });

  testWidgets('o cartão oculto fica sob o vidro, e o espaço espia', (
    tester,
  ) async {
    final container = await pumpPanel(tester);
    viewModelOf(container)
      ..startNote()
      ..commitEdit('senha do wi-fi');
    await tester.pumpAndSettle();

    Finder glass() => find.descendant(
      of: find.byType(LeafNoteCard),
      matching: find.byType(ImageFiltered),
    );
    expect(glass(), findsNothing);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pumpAndSettle();

    expect(stateOf(container).noteAt(1)?.isHidden, isTrue);
    expect(glass(), findsOneWidget);
    expect(find.bySemanticsLabel('Vaga 1, oculta'), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(glass(), findsNothing);

    await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(glass(), findsOneWidget);
  });
}
