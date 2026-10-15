import 'package:evergreen/app/providers.dart';
import 'package:evergreen/core/app_info.dart';
import 'package:evergreen/core/design/app_theme.dart';
import 'package:evergreen/core/storage/app_database.dart';
import 'package:evergreen/features/echo/data/echo_repository.dart';
import 'package:evergreen/features/echo/models/meeting.dart';
import 'package:evergreen/features/echo/models/echo_settings.dart';
import 'package:evergreen/features/echo/models/meeting_segment.dart';
import 'package:evergreen/features/echo/models/transcription_language.dart';
import 'package:evergreen/features/home/models/evergreen_module.dart';
import 'package:evergreen/features/home/presentation/views/hub_view.dart';
import 'package:evergreen/features/home/presentation/widgets/hub_detail_region.dart';
import 'package:evergreen/shared/widgets/eg_button.dart';
import 'package:evergreen/shared/widgets/eg_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:evergreen/shared/widgets/eg_confirm_dialog.dart';
import 'package:flutter_test/flutter_test.dart';

import '../pin/fake_clipboard_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';

import 'fake_echo_channel.dart';
import 'fake_export_service.dart';
import 'fake_echo_audio.dart';
import '../pin/fake_pin_image_store.dart';

/// A região de leitura do Hub — a coluna que a janela cresce para mostrar.
///
/// O que estes testes prendem é o ciclo dela: abre no clique, fecha por `esc`,
/// fecha ao trocar de módulo e fecha quando não sobra reunião nenhuma. Uma
/// região que fica aberta sozinha é uma coluna de 480px encostada na tela
/// errada — e a janela, que cresceu para caber nela, não volta.
void main() {
  late SharedPreferences preferences;
  late Database db;
  late FakeExportService exports;
  late SqliteEchoRepository repository;
  late FakeEchoAudioStore audio;
  late FakeEchoPlayer player;
  late int meetingId;

  setUp(() async {
    // Duas chaves, dois caminhos de primeira vez que este teste não quer: a
    // apresentação de boas-vindas (que espera seis cliques em "Próximo") e a
    // pergunta do nome (que leva o Hub para a tela do aplicativo). Aqui o app
    // já foi apresentado nesta build e já sabe com quem fala.
    SharedPreferences.setMockInitialValues({
      'app.onboarding_seen_build': AppInfo.readBuildStamp(),
      'app.user_name': 'Lucas',
    });
    preferences = await SharedPreferences.getInstance();

    db = sqlite3.openInMemory();
    AppDatabase.migrate(db);
    exports = FakeExportService();

    audio = FakeEchoAudioStore();
    player = FakeEchoPlayer(
      durationMs: const Duration(minutes: 32).inMilliseconds,
    );
    repository = SqliteEchoRepository(db);
    meetingId = repository
        .insert(
          Meeting(
            title: 'Alinhamento de escopo',
            startedAt: DateTime.now().subtract(const Duration(hours: 3)),
            durationMs: const Duration(minutes: 32).inMilliseconds,
            language: TranscriptionLanguage.ptBR,
            segments: const [
              MeetingSegment(
                speaker: Speaker.others,
                startMs: 4000,
                endMs: 9000,
                text: 'Então, a ideia é fechar o escopo hoje.',
                words: [
                  MeetingWord(startMs: 4000, endMs: 4400, text: 'Então,'),
                  MeetingWord(startMs: 4500, endMs: 4700, text: ' a'),
                  MeetingWord(startMs: 4800, endMs: 5200, text: ' ideia'),
                  MeetingWord(startMs: 5300, endMs: 5400, text: ' é'),
                  MeetingWord(startMs: 5500, endMs: 6000, text: ' fechar'),
                  MeetingWord(startMs: 6100, endMs: 6200, text: ' o'),
                  MeetingWord(startMs: 6300, endMs: 7000, text: ' escopo'),
                  MeetingWord(startMs: 7100, endMs: 9000, text: ' hoje.'),
                ],
              ),
            ],
          ),
        )
        .id!;
  });

  tearDown(() => db.close());

  Future<void> pumpHub(WidgetTester tester) async {
    // Larga o bastante para a janela "já expandida": sob `flutter test` não há
    // janela nativa para crescer de verdade.
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          // O Hub abre no Pin, e a tela dele conta os itens por tipo.
          pinImageStoreProvider.overrideWithValue(FakePinImageStore()),
          clipboardRepositoryProvider.overrideWithValue(
            FakeClipboardRepository(),
          ),
          echoAudioStoreProvider.overrideWithValue(audio),
          echoPlayerProvider.overrideWithValue(player),
          echoRepositoryProvider.overrideWithValue(SqliteEchoRepository(db)),
          echoChannelProvider.overrideWithValue(FakeEchoChannel()),
          exportServiceProvider.overrideWithValue(exports),
        ],
        child: MaterialApp(theme: AppTheme.build(), home: const HubView()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(EvergreenModule.echo.name));
    await tester.pumpAndSettle();

    // A tela abre em "Ajustes", que é a aba padrão de todo módulo. A lista
    // mora na outra.
    await tester.tap(find.text('Reuniões'));
    await tester.pumpAndSettle();
  }

  Future<void> openMeeting(WidgetTester tester) async {
    await tester.tap(find.textContaining('Alinhamento de escopo'));
    await tester.pumpAndSettle();
  }

  testWidgets('a reunião só abre quando se clica nela', (tester) async {
    await pumpHub(tester);

    // A lista já vem com uma reunião selecionada, mas a região não se abre
    // sozinha: abrir é um gesto, e a janela cresce junto.
    expect(find.byType(HubDetailRegion), findsNothing);

    await openMeeting(tester);

    expect(find.byType(HubDetailRegion), findsOneWidget);
    expect(find.text('Resumo'), findsOneWidget);
    expect(find.text('Transcrição'), findsOneWidget);
  });

  testWidgets('a transcrição e o resumo se alternam, um de cada vez', (
    tester,
  ) async {
    await pumpHub(tester);
    await openMeeting(tester);

    expect(find.textContaining('Então, a ideia'), findsNothing);

    await tester.tap(find.text('Transcrição'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Então, a ideia'), findsOneWidget);
  });

  testWidgets('esc fecha a região', (tester) async {
    await pumpHub(tester);
    await openMeeting(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byType(HubDetailRegion), findsNothing);
  });

  testWidgets('trocar de módulo fecha a região', (tester) async {
    await pumpHub(tester);
    await openMeeting(tester);

    // Awake, e não Focus: a tela do Focus lê o banco, e o que este teste quer
    // saber é o que acontece com a região ao trocar de módulo.
    await tester.tap(find.text(EvergreenModule.awake.name));
    await tester.pumpAndSettle();

    // Uma reunião aberta ao lado das preferências de outro módulo seria a
    // leitura de um módulo dentro de outro.
    expect(find.byType(HubDetailRegion), findsNothing);
  });

  /// A janela cresce para caber a região, mas a resposta do lado nativo é
  /// animada — e num monitor pequeno ela pode nem crescer o bastante. Nesses
  /// quadros o Hub tem menos largura do que a região gostaria, e quem precisa
  /// ceder é a região: foi assim que a primeira versão estourou o layout de
  /// todas as linhas de configuração da tela do Echo.
  ///
  /// Não há `expect`: um `RenderFlex overflowed` já reprova o teste sozinho.
  testWidgets('a região cede largura em vez de espremer o conteúdo', (
    tester,
  ) async {
    await pumpHub(tester);
    await openMeeting(tester);

    // Da janela que ainda não cresceu (880 é a largura de partida do Hub) até a
    // já expandida.
    for (final width in [880.0, 1000.0, 1100.0, 1360.0, 1440.0]) {
      tester.view.physicalSize = Size(width, 900);
      await tester.pumpAndSettle();

      expect(find.byType(HubDetailRegion), findsOneWidget);
    }
  });

  testWidgets('apagar a reunião pergunta antes, e cancelar não apaga', (
    tester,
  ) async {
    await pumpHub(tester);
    await openMeeting(tester);

    await tester.tap(find.text('Apagar'));
    await tester.pumpAndSettle();

    expect(find.byType(EgConfirmDialog), findsOneWidget);
    expect(repository.loadAll(), hasLength(1), reason: 'só abriu o aviso');

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(repository.loadAll(), hasLength(1));
    expect(find.byType(HubDetailRegion), findsOneWidget);
  });

  testWidgets('apagar a última reunião fecha a região', (tester) async {
    await pumpHub(tester);
    await openMeeting(tester);

    // O rótulo "Apagar" existe no botão da região e no do aviso; o do aviso é
    // o último a entrar na árvore.
    await tester.tap(find.text('Apagar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apagar').last);
    await tester.pumpAndSettle();

    expect(find.byType(HubDetailRegion), findsNothing);
    expect(find.text('Nenhuma reunião gravada'), findsOneWidget);
  });

  testWidgets('apagar tudo pergunta antes e poupa a reunião guardada', (
    tester,
  ) async {
    repository.insert(
      Meeting(
        title: 'Planejamento',
        startedAt: DateTime.now().subtract(const Duration(days: 1)),
        durationMs: const Duration(minutes: 10).inMilliseconds,
        language: TranscriptionLanguage.ptBR,
        isKept: true,
        segments: const [],
      ),
    );
    await pumpHub(tester);
    await openMeeting(tester);

    await tester.tap(find.text('Apagar tudo'));
    await tester.pumpAndSettle();
    expect(find.byType(EgConfirmDialog), findsOneWidget);
    expect(repository.loadAll(), hasLength(2), reason: 'só abriu o aviso');

    await tester.tap(find.text('Apagar').last);
    await tester.pumpAndSettle();

    expect(repository.loadAll().map((meeting) => meeting.title), [
      'Planejamento',
    ]);
    // A reunião aberta foi junto: a região se fecha. E sem nada para apagar,
    // o cartão some.
    expect(find.byType(HubDetailRegion), findsNothing);
    expect(find.text('Apagar tudo'), findsNothing);
  });

  /// O caminho inteiro de "Exportar": o botão, a ViewModel, o texto montado e
  /// o arquivo escrito. Os pedaços têm teste próprio; o que se prende aqui é a
  /// fiação entre eles — e que o que sai é a **face aberta**, não a reunião
  /// toda.
  testWidgets('exportar escreve a face aberta, com nome próprio', (
    tester,
  ) async {
    await pumpHub(tester);
    await openMeeting(tester);

    await tester.tap(find.text('Transcrição'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Exportar'));
    await tester.pumpAndSettle();

    expect(exports.written, hasLength(1));

    final written = exports.written.single;
    expect(written.baseName, endsWith('-alinhamento-de-escopo-transcricao'));
    expect(written.content, contains('# Alinhamento de escopo'));
    expect(written.content, contains('## Transcrição'));
    expect(written.content, contains('Então, a ideia é fechar o escopo hoje.'));

    // O arquivo vai parar numa pasta funda demais para alguém achá-la
    // sozinho: mostrar no Finder é o que completa a ação.
    expect(exports.revealed, hasLength(1));

    expect(find.text('Transcrição exportada'), findsOneWidget);
  });

  /// A reunião deste teste não tem resumo, e um botão que copiaria vazio
  /// promete uma cópia que não acontece.
  testWidgets('sem resumo, a aba do resumo não oferece o que levar', (
    tester,
  ) async {
    await pumpHub(tester);
    await openMeeting(tester);

    expect(
      tester
          .widget<EgButton>(
            find.ancestor(
              of: find.text('Exportar'),
              matching: find.byType(EgButton),
            ),
          )
          .onPressed,
      isNull,
    );
    expect(exports.written, isEmpty);
  });

  group('áudio', () {
    void giveAudio() {
      audio.files.add('reuniao.m4a');
      repository.setAudioFile(meetingId, 'reuniao.m4a');
    }

    Future<void> openTranscript(WidgetTester tester) async {
      await pumpHub(tester);
      await openMeeting(tester);
      await tester.tap(find.text('Transcrição'));
      await tester.pumpAndSettle();
    }

    testWidgets('reunião sem áudio não mostra player nenhum', (tester) async {
      await openTranscript(tester);

      expect(find.byTooltip('Tocar (espaço)'), findsNothing);
    });

    testWidgets('o player fica no topo e toca pelo botão', (tester) async {
      giveAudio();
      await openTranscript(tester);

      expect(find.text('32:00'), findsOneWidget);

      await tester.tap(find.byTooltip('Tocar (espaço)'));
      await tester.pump();
      expect(player.isPlaying, isTrue);

      await tester.tap(find.byTooltip('Pausar (espaço)'));
      await tester.pumpAndSettle();
      expect(player.isPlaying, isFalse);
    });

    testWidgets('clicar numa palavra leva o áudio até ela', (tester) async {
      giveAudio();
      await openTranscript(tester);

      // "escopo" também está no título; o que se clica é a fala.
      await tester.tapOnText(
        find.textRange.ofSubstring(
          'scop',
          descendentOf: find.byWidgetPredicate(
            (widget) =>
                widget is RichText &&
                widget.text.toPlainText().contains('escopo hoje'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(player.positionMs, 6300);
    });

    /// Tocando, o player pergunta a posição de 80 em 80 ms e a fala é
    /// redesenhada a cada resposta. Um clique que atravessa uma dessas
    /// respostas — apertar antes, soltar depois — precisa saltar do mesmo
    /// jeito: era o que falhava "às vezes".
    testWidgets('clicar numa palavra com o áudio tocando salta mesmo '
        'quando a posição muda no meio do clique', (tester) async {
      giveAudio();
      await openTranscript(tester);

      await tester.tap(find.byTooltip('Tocar (espaço)'));
      await tester.pump();

      final word = find.textRange
          .ofSubstring(
            'scop',
            descendentOf: find.byWidgetPredicate(
              (widget) =>
                  widget is RichText &&
                  widget.text.toPlainText().contains('escopo hoje'),
            ),
          )
          .evaluate()
          .single;
      final box = word.renderObject
          .getBoxesForSelection(
            TextSelection(
              baseOffset: word.textRange.start,
              extentOffset: word.textRange.end,
            ),
          )
          .first
          .toRect();
      final at = word.renderObject.localToGlobal(box.center);

      final gesture = await tester.startGesture(at);
      player.positionMs = 1200;
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.up();
      await tester.pump();

      expect(player.positionMs, 6300);

      await tester.tap(find.byTooltip('Pausar (espaço)'));
      await tester.pumpAndSettle();
    });

    /// Com uma reunião aberta, o espaço e o S são do player — menos dentro de
    /// um campo de texto, onde são texto. Consumidos pelo Hub, eles nunca
    /// chegavam ao vocabulário nem à instrução do resumo.
    testWidgets('num campo de texto, o espaço e o S são texto, não player', (
      tester,
    ) async {
      giveAudio();
      await openTranscript(tester);

      await tester.tap(find.text('Ajustes'));
      await tester.pumpAndSettle();

      for (final hint in [
        EchoSettings.vocabularyHint,
        EchoSettings.defaultInstructionsHint,
      ]) {
        final field = find.descendant(
          of: find.byWidgetPredicate(
            (widget) => widget is EgTextField && widget.hintText == hint,
          ),
          matching: find.byType(EditableText),
        );
        await tester.ensureVisible(field);
        await tester.tap(field);
        await tester.pump();

        expect(await tester.sendKeyEvent(LogicalKeyboardKey.space), isFalse);
        expect(await tester.sendKeyEvent(LogicalKeyboardKey.keyS), isFalse);
        await tester.pump();

        expect(player.isPlaying, isFalse);
        expect(player.rate, 1.0);
      }
    });

    /// O que está aceso na fala, pedaço por pedaço.
    List<String> lit(WidgetTester tester) {
      final paragraph = tester.widget<RichText>(
        find.byWidgetPredicate(
          (widget) =>
              widget is RichText &&
              widget.text.toPlainText().contains('escopo hoje'),
        ),
      );
      final spans = (paragraph.text as TextSpan).children!.first as TextSpan;
      return [
        for (final span in spans.children!.whereType<TextSpan>())
          if (span.style?.color != null) span.text!,
      ];
    }

    testWidgets('tudo o que já foi dito fica aceso', (tester) async {
      giveAudio();
      await openTranscript(tester);

      player.positionMs = 6500;
      await tester.tap(find.byTooltip('Tocar (espaço)'));
      await tester.pump(const Duration(milliseconds: 200));

      expect(lit(tester), [
        'Então,',
        ' a',
        ' ideia',
        ' é',
        ' fechar',
        ' o',
        ' escopo',
      ]);

      await tester.tap(find.byTooltip('Pausar (espaço)'));
      await tester.pumpAndSettle();
    });

    testWidgets('clicar lá na frente acende todas as anteriores', (
      tester,
    ) async {
      giveAudio();
      await openTranscript(tester);
      expect(lit(tester), isEmpty);

      await tester.tapOnText(
        find.textRange.ofSubstring(
          'hoj',
          descendentOf: find.byWidgetPredicate(
            (widget) =>
                widget is RichText &&
                widget.text.toPlainText().contains('escopo hoje'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(lit(tester), hasLength(8));
      expect(lit(tester).last, ' hoje.');
    });

    testWidgets('espaço toca e pausa; as setas saltam 10 s', (tester) async {
      giveAudio();
      await openTranscript(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(player.isPlaying, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(player.positionMs, 10000);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(player.positionMs, 0);

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(player.isPlaying, isFalse);
    });

    testWidgets('a velocidade gira pelo clique e pelo S, e volta ao normal', (
      tester,
    ) async {
      giveAudio();
      await openTranscript(tester);

      expect(find.text('1×'), findsOneWidget);

      await tester.tap(find.text('1×'));
      await tester.pump();
      expect(player.rate, 1.25);
      expect(find.text('1,25×'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.pump();
      expect(find.text('1,5×'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.pump();
      expect(player.rate, 2.0);
      expect(find.text('2×'), findsOneWidget);

      await tester.tap(find.text('2×'));
      await tester.pump();
      expect(player.rate, 1.0);
      expect(find.text('1×'), findsOneWidget);
    });
  });
}
