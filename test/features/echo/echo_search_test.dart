import 'package:evergreen/app/providers.dart';
import 'package:evergreen/core/app_info.dart';
import 'package:evergreen/core/design/app_theme.dart';
import 'package:evergreen/core/design/eg_tokens.dart';
import 'package:evergreen/core/storage/app_database.dart';
import 'package:evergreen/features/echo/data/echo_repository.dart';
import 'package:evergreen/features/echo/models/meeting.dart';
import 'package:evergreen/features/echo/models/meeting_segment.dart';
import 'package:evergreen/features/echo/models/transcription_language.dart';
import 'package:evergreen/features/echo/presentation/viewmodels/echo_library_view_model.dart';
import 'package:evergreen/features/echo/presentation/widgets/echo_search_results.dart';
import 'package:evergreen/features/home/models/evergreen_module.dart';
import 'package:evergreen/features/home/presentation/views/hub_view.dart';
import 'package:evergreen/features/home/presentation/widgets/hub_detail_region.dart';
import 'package:evergreen/shared/widgets/eg_search_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';

import '../pin/fake_clipboard_repository.dart';
import 'fake_echo_audio.dart';
import 'fake_echo_channel.dart';
import 'fake_export_service.dart';
import '../pin/fake_pin_image_store.dart';

/// A busca das reuniões, de ponta a ponta no Hub.
///
/// O que estes testes prendem é a promessa dela: digitar acha o trecho em
/// qualquer reunião, o teclado anda pelos resultados sem sair do campo, e
/// abrir leva a leitura — e o áudio — até onde a palavra foi dita.
void main() {
  late SharedPreferences preferences;
  late Database db;
  late SqliteEchoRepository repository;
  late FakeEchoAudioStore audio;
  late FakeEchoPlayer player;
  late int planningId;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'app.onboarding_seen_build': AppInfo.readBuildStamp(),
      'app.user_name': 'Lucas',
    });
    preferences = await SharedPreferences.getInstance();

    db = sqlite3.openInMemory();
    AppDatabase.migrate(db);
    repository = SqliteEchoRepository(db);
    audio = FakeEchoAudioStore();
    player = FakeEchoPlayer(
      durationMs: const Duration(minutes: 30).inMilliseconds,
    );

    final now = DateTime.now();
    repository.insert(
      Meeting(
        title: 'Daily do time',
        startedAt: now.subtract(const Duration(days: 2)),
        durationMs: const Duration(minutes: 15).inMilliseconds,
        language: TranscriptionLanguage.ptBR,
        summary: '- Ninguém bloqueado.',
        segments: const [
          MeetingSegment(
            speaker: Speaker.others,
            startMs: 1000,
            endMs: 4000,
            text: 'Ontem terminei a tela de login.',
          ),
        ],
      ),
    );
    planningId = repository
        .insert(
          Meeting(
            title: 'Planejamento do trimestre',
            startedAt: now.subtract(const Duration(hours: 3)),
            durationMs: const Duration(minutes: 30).inMilliseconds,
            language: TranscriptionLanguage.ptBR,
            summary: '- O orçamento fecha na sexta.',
            segments: const [
              MeetingSegment(
                speaker: Speaker.others,
                startMs: 2000,
                endMs: 5000,
                text: 'Vamos começar pelo roadmap.',
                voice: 1,
              ),
              MeetingSegment(
                speaker: Speaker.others,
                startMs: 62000,
                endMs: 66000,
                text: 'O orçamento ainda está aberto.',
                voice: 2,
                words: [
                  MeetingWord(startMs: 62000, endMs: 62200, text: 'O'),
                  MeetingWord(startMs: 62300, endMs: 63000, text: ' orçamento'),
                  MeetingWord(startMs: 63100, endMs: 63600, text: ' ainda'),
                  MeetingWord(startMs: 63700, endMs: 64000, text: ' está'),
                  MeetingWord(startMs: 64100, endMs: 66000, text: ' aberto.'),
                ],
              ),
              MeetingSegment(
                speaker: Speaker.me,
                startMs: 70000,
                endMs: 73000,
                text: 'Eu mando a planilha até sexta.',
              ),
            ],
          ),
        )
        .id!;
  });

  tearDown(() => db.close());

  Future<ProviderContainer> pumpHub(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          pinImageStoreProvider.overrideWithValue(FakePinImageStore()),
          clipboardRepositoryProvider.overrideWithValue(
            FakeClipboardRepository(),
          ),
          echoAudioStoreProvider.overrideWithValue(audio),
          echoPlayerProvider.overrideWithValue(player),
          echoRepositoryProvider.overrideWithValue(repository),
          echoChannelProvider.overrideWithValue(FakeEchoChannel()),
          exportServiceProvider.overrideWithValue(FakeExportService()),
        ],
        child: MaterialApp(theme: AppTheme.build(), home: const HubView()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(EvergreenModule.echo.name));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reuniões'));
    await tester.pumpAndSettle();

    return ProviderScope.containerOf(tester.element(find.byType(HubView)));
  }

  Finder searchField() => find.descendant(
    of: find.byType(EgSearchField),
    matching: find.byType(TextField),
  );

  Future<void> pressCommandF(WidgetTester tester) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(searchField(), text);
    await tester.pumpAndSettle();
  }

  /// O texto inteiro de cada `RichText` da tela — os resultados e a leitura
  /// são desenhados em pedaços, e `find.text` não os vê juntos.
  Finder richText(String contains) => find.byWidgetPredicate(
    (widget) =>
        widget is RichText && widget.text.toPlainText().contains(contains),
  );

  /// O texto na região de leitura — com áudio a fala é um `RichText` em
  /// pedaços clicáveis; sem, um `SelectableText`.
  InlineSpan? spanOf(Widget widget) => switch (widget) {
    RichText(:final text) => text,
    SelectableText(:final textSpan) => textSpan,
    _ => null,
  };

  Finder inReader(String contains) => find.descendant(
    of: find.byType(HubDetailRegion),
    matching: find.byWidgetPredicate(
      (widget) =>
          spanOf(widget)?.toPlainText().contains(contains) ??
          (widget is SelectableText && (widget.data ?? '').contains(contains)),
    ),
  );

  /// Os trechos de [found] com o fundo de "achado".
  List<String> findMarks(WidgetTester tester, Finder found, Color mark) {
    final marks = <String>[];
    for (final widget in tester.widgetList(found)) {
      spanOf(widget)?.visitChildren((span) {
        if (span is TextSpan && span.style?.backgroundColor == mark) {
          marks.add(span.text ?? '');
        }
        return true;
      });
    }
    return marks;
  }

  testWidgets('acha o trecho em qualquer reunião, sem acento', (tester) async {
    await pumpHub(tester);

    await type(tester, 'orcamento');

    expect(find.byType(EchoSearchResults), findsOneWidget);
    // A lista de reuniões sai: a daily não fala de orçamento.
    expect(find.textContaining('Daily do time'), findsNothing);
    expect(find.text('2 trechos em 1 reunião'), findsOneWidget);

    // O trecho diz quem falou e quando — a resposta sem abrir nada.
    expect(find.text('Pessoa 2'), findsOneWidget);
    expect(find.text('01:02'), findsOneWidget);
    expect(richText('O orçamento ainda está aberto.'), findsOneWidget);

    // O resumo também é procurado, e se anuncia como tal.
    expect(find.text('Resumo'), findsWidgets);
  });

  testWidgets('todas as palavras precisam estar na reunião', (tester) async {
    await pumpHub(tester);

    await type(tester, 'login sexta');

    expect(find.byType(EchoSearchResults), findsOneWidget);
    expect(find.textContaining('Nada sobre “login sexta”'), findsOneWidget);
  });

  testWidgets('Enter abre o primeiro resultado no trecho, com o termo '
      'marcado e o áudio parado ali', (tester) async {
    audio.files.add('planejamento.m4a');
    repository.setAudioFile(planningId, 'planejamento.m4a');
    await pumpHub(tester);

    await type(tester, 'orçamento aberto');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.byType(HubDetailRegion), findsOneWidget);
    // A transcrição já aberta, e não o resumo de sempre: o trecho é de lá.
    final speech = inReader('ainda está aberto');
    expect(speech, findsOneWidget);

    final mark = tester
        .element(find.byType(HubDetailRegion))
        .eg
        .colors
        .findMark;
    expect(findMarks(tester, speech, mark), ['orçamento', 'aberto']);

    // Parado na palavra, pronto para o espaço tocar dali.
    expect(player.positionMs, 62300);
    expect(player.isPlaying, isFalse);
  });

  testWidgets('o salto é de um gesto só: pela lista, a reunião abre no '
      'resumo', (tester) async {
    audio.files.add('planejamento.m4a');
    repository.setAudioFile(planningId, 'planejamento.m4a');
    final container = await pumpHub(tester);

    await type(tester, 'orçamento aberto');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(player.positionMs, 62300);

    // Abrir tirou o cursor da busca: o Esc fecha a leitura. Depois, ⌘F
    // volta à busca e o Esc seguinte a apaga.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(HubDetailRegion), findsNothing);

    await pressCommandF(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(EchoSearchResults), findsNothing);

    await tester.tap(find.textContaining('Planejamento do trimestre'));
    await tester.pumpAndSettle();

    // O áudio fica onde parou, como em qualquer reunião reaberta; o que não
    // volta é o pedido da busca.
    expect(container.read(echoLibraryViewModelProvider).jump, isNull);
    // O resumo, como toda reunião aberta pela lista.
    expect(inReader('Vamos começar pelo roadmap'), findsNothing);
  });

  testWidgets('as setas andam pelos resultados sem sair do campo', (
    tester,
  ) async {
    final container = await pumpHub(tester);

    await type(tester, 'sexta');
    final library = container.read(echoLibraryViewModelProvider);
    // A reunião, o resumo e a fala — três linhas, a primeira apontada.
    expect(library.entries, hasLength(3));
    expect(library.activeEntry, 0);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    // Sem dar a volta: a lista tem fim.
    expect(container.read(echoLibraryViewModelProvider).activeEntry, 2);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    final jump = container.read(echoLibraryViewModelProvider).jump!;
    expect(jump.turnStartMs, 70000);
    expect(inReader('Eu mando a planilha'), findsOneWidget);
  });

  testWidgets('abrir entrega o teclado à leitura; ⌘F devolve à busca', (
    tester,
  ) async {
    audio.files.add('planejamento.m4a');
    repository.setAudioFile(planningId, 'planejamento.m4a');
    final container = await pumpHub(tester);

    await type(tester, 'orçamento');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    // Fora do campo: o espaço toca o trecho, em vez de entrar na busca.
    expect(FocusManager.instance.primaryFocus?.debugLabel, isNot('echo-busca'));
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(player.isPlaying, isTrue);
    expect(
      tester.widget<TextField>(searchField()).controller!.text,
      'orçamento',
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();

    // ⌘F volta com o texto selecionado e a linha apontada onde estava.
    await pressCommandF(tester);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'echo-busca');
    final controller = tester.widget<TextField>(searchField()).controller!;
    expect(controller.selection.textInside(controller.text), 'orçamento');
    expect(container.read(echoLibraryViewModelProvider).activeEntry, 2);
  });

  testWidgets('o clique num trecho abre a reunião nele', (tester) async {
    await pumpHub(tester);

    await type(tester, 'roadmap');
    await tester.tap(richText('Vamos começar pelo roadmap.'));
    await tester.pumpAndSettle();

    expect(find.byType(HubDetailRegion), findsOneWidget);
    expect(inReader('Vamos começar pelo roadmap.'), findsOneWidget);
  });

  testWidgets('um resultado do resumo abre o resumo', (tester) async {
    await pumpHub(tester);

    await type(tester, 'bloqueado');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.byType(HubDetailRegion), findsOneWidget);
    expect(inReader('Ninguém bloqueado'), findsOneWidget);
    // O resumo marca o termo também, e não só a transcrição.
    final mark = tester
        .element(find.byType(HubDetailRegion))
        .eg
        .colors
        .findMark;
    expect(findMarks(tester, inReader('Ninguém bloqueado'), mark), [
      'bloqueado',
    ]);
  });

  testWidgets('Esc apaga a busca; o seguinte é do Hub', (tester) async {
    await pumpHub(tester);

    await type(tester, 'roadmap');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    // A lista volta, e o cursor fica para uma busca nova.
    expect(find.byType(EchoSearchResults), findsNothing);
    expect(find.textContaining('Daily do time'), findsOneWidget);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'echo-busca');

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(FocusManager.instance.primaryFocus?.debugLabel, isNot('echo-busca'));
  });

  testWidgets('⌘F leva à busca, mesmo de outra aba', (tester) async {
    await pumpHub(tester);

    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();
    expect(find.byType(EgSearchField), findsNothing);

    await pressCommandF(tester);

    expect(find.byType(EgSearchField), findsOneWidget);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'echo-busca');
  });

  testWidgets('⌘F não perde o que estava sendo escrito em outro campo', (
    tester,
  ) async {
    await pumpHub(tester);
    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();

    // O vocabulário se guarda ao perder o foco — e trocar de aba com o
    // cursor nele tirava o campo da árvore sem esse "perder" acontecer.
    final vocabulary = find.byType(TextField).first;
    await tester.tap(vocabulary);
    await tester.enterText(vocabulary, 'Riverpod');
    await pressCommandF(tester);

    expect(preferences.getString('echo.vocabulary'), 'Riverpod');
  });

  testWidgets('uma letra só ainda não busca, e o Esc a apaga', (tester) async {
    await pumpHub(tester);

    await type(tester, 'p');
    expect(find.byType(EchoSearchResults), findsNothing);
    expect(find.textContaining('Daily do time'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(searchField()).controller!.text, isEmpty);
  });

  testWidgets('a busca continua de pé ao trocar de aba e voltar', (
    tester,
  ) async {
    await pumpHub(tester);

    await type(tester, 'roadmap');
    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reuniões'));
    await tester.pumpAndSettle();

    expect(find.byType(EchoSearchResults), findsOneWidget);
    expect(tester.widget<TextField>(searchField()).controller!.text, 'roadmap');
  });

  testWidgets('apagar a reunião aberta pela busca tira ela dos resultados', (
    tester,
  ) async {
    final container = await pumpHub(tester);

    await type(tester, 'roadmap');
    expect(container.read(echoLibraryViewModelProvider).results, hasLength(1));

    container.read(echoLibraryViewModelProvider.notifier).delete(planningId);
    await tester.pumpAndSettle();

    expect(container.read(echoLibraryViewModelProvider).results, isEmpty);
    expect(container.read(echoLibraryViewModelProvider).activeEntry, isNull);
    expect(find.textContaining('Nada sobre “roadmap”'), findsOneWidget);
  });

  testWidgets('sem reunião nenhuma, não há busca', (tester) async {
    repository.clearAll();
    await pumpHub(tester);

    expect(find.byType(EgSearchField), findsNothing);
  });
}
