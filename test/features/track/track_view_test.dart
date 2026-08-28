import 'package:evergreen/app/providers.dart';
import 'package:evergreen/core/design/app_theme.dart';
import 'package:evergreen/core/storage/app_database.dart';
import 'package:evergreen/features/echo/data/echo_channel.dart';
import 'package:evergreen/features/echo/data/echo_repository.dart';
import 'package:evergreen/features/home/models/evergreen_module.dart';
import 'package:evergreen/features/home/presentation/views/hub_view.dart';
import 'package:evergreen/features/home/presentation/widgets/hub_detail_region.dart';
import 'package:evergreen/features/pin/models/clipboard_item_type.dart';
import 'package:evergreen/features/track/data/track_repository.dart';
import 'package:evergreen/features/track/presentation/widgets/track_day_list.dart';
import 'package:evergreen/features/track/presentation/widgets/track_week_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';

import '../echo/fake_echo_channel.dart';
import '../focus/fake_focus_session_repository.dart';
import '../pin/fake_clipboard_repository.dart';

/// A tela do Track dentro do Hub.
///
/// O módulo não captura nada: tudo que estes testes montam vai direto para as
/// tabelas que os outros quatro módulos escrevem, e o Track aparece lendo.
void main() {
  late SharedPreferences preferences;
  late Database db;
  late FakeEchoChannel channel;

  /// Quarta-feira às 15h30, para que "ontem" caia na mesma semana.
  final now = DateTime(2026, 8, 19, 15, 30);
  DateTime at(int daysAgo, int hour, int minute) =>
      DateTime(now.year, now.month, now.day - daysAgo, hour, minute);

  setUp(() async {
    // Com um nome guardado: sem ele, a abertura animada termina levando o Hub
    // para a tela do aplicativo, onde a pergunta do nome espera. É o caminho
    // da primeira vez, e tem teste próprio em `app_settings_view_test.dart`.
    SharedPreferences.setMockInitialValues({'app.user_name': 'Lucas'});
    preferences = await SharedPreferences.getInstance();

    db = sqlite3.openInMemory();
    AppDatabase.migrate(db);
    channel = FakeEchoChannel();
  });

  tearDown(() => db.close());

  void insertFocus(DateTime startedAt, Duration duration, [String? activity]) {
    db.execute(
      'INSERT INTO focus_sessions (started_at, duration_seconds, activity) '
      'VALUES (?, ?, ?);',
      [startedAt.millisecondsSinceEpoch, duration.inSeconds, activity],
    );
  }

  void insertMeeting(DateTime startedAt, Duration duration, String title) {
    db.execute(
      'INSERT INTO echo_meetings '
      '(title, started_at, duration_ms, language, transcript) '
      'VALUES (?, ?, ?, ?, ?);',
      [
        title,
        startedAt.millisecondsSinceEpoch,
        duration.inMilliseconds,
        'pt-BR',
        '[]',
      ],
    );
  }

  void insertCopy(DateTime copiedAt, String content, ClipboardItemType type) {
    db.execute(
      'INSERT INTO clipboard_items (content, type, is_pinned, copied_at) '
      'VALUES (?, ?, 0, ?);',
      [content, type.name, copiedAt.millisecondsSinceEpoch],
    );
  }

  Future<void> pumpTrack(WidgetTester tester) async {
    // Larga e alta o bastante para a janela "já expandida": sob `flutter test`
    // não há janela nativa para crescer de verdade, e a região de leitura
    // precisa caber ao lado do conteúdo.
    tester.view.physicalSize = const Size(1600, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          clipboardRepositoryProvider.overrideWithValue(
            FakeClipboardRepository([]),
          ),
          focusSessionRepositoryProvider.overrideWithValue(
            FakeFocusSessionRepository(),
          ),
          echoRepositoryProvider.overrideWithValue(SqliteEchoRepository(db)),
          echoChannelProvider.overrideWithValue(channel),
          trackRepositoryProvider.overrideWithValue(SqliteTrackRepository(db)),
          clockProvider.overrideWithValue(() => now),
        ],
        child: MaterialApp(theme: AppTheme.build(), home: const HubView()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(EvergreenModule.track.name));
    await tester.pumpAndSettle();
  }

  /// O texto dentro da lista de dias — "Hoje" também é o nome de uma pílula do
  /// recorte, e sem isto o `find` acharia as duas.
  Finder inDayList(String text) =>
      find.descendant(of: find.byType(TrackDayList), matching: find.text(text));

  testWidgets('o balanço conta o período numa frase', (tester) async {
    insertFocus(at(0, 9, 12), const Duration(minutes: 25), 'Refatorar o auth');
    insertFocus(at(0, 14, 30), const Duration(minutes: 40));
    insertMeeting(at(0, 10, 0), const Duration(minutes: 45), 'Weekly');
    insertCopy(at(0, 11, 0), 'https://exemplo.com', ClipboardItemType.link);

    await pumpTrack(tester);

    expect(find.textContaining('1h 05min'), findsWidgets);
    expect(find.textContaining('focadas em 2 sessões'), findsOneWidget);
    expect(find.textContaining('em 1 reunião'), findsOneWidget);
    expect(find.textContaining('item copiado'), findsWidgets);
  });

  testWidgets('cada dia com registro vira uma linha', (tester) async {
    insertFocus(at(0, 9, 0), const Duration(minutes: 25));
    insertFocus(at(1, 9, 0), const Duration(minutes: 50));

    await pumpTrack(tester);

    expect(inDayList('Hoje'), findsOneWidget);
    expect(inDayList('Ontem'), findsOneWidget);
    expect(inDayList('50 min'), findsOneWidget);
  });

  testWidgets('hoje tem linha mesmo sem nada registrado', (tester) async {
    insertFocus(at(2, 9, 0), const Duration(minutes: 25));

    await pumpTrack(tester);

    // A linha que a pessoa vem procurar não pode faltar às dez da manhã, antes
    // de ela ter feito qualquer coisa.
    expect(inDayList('Hoje'), findsOneWidget);
    expect(inDayList('Nada registrado'), findsOneWidget);
  });

  testWidgets('o recorte de hoje encolhe a lista e recolhe a faixa', (
    tester,
  ) async {
    insertFocus(at(0, 9, 0), const Duration(minutes: 25));
    insertFocus(at(1, 9, 0), const Duration(minutes: 50));

    await pumpTrack(tester);
    expect(find.byType(TrackWeekStrip), findsOneWidget);

    await tester.tap(find.text('Hoje').first);
    await tester.pumpAndSettle();

    expect(inDayList('Ontem'), findsNothing);
    expect(inDayList('Hoje'), findsOneWidget);
    // Uma barra sozinha não compara nada com nada.
    expect(find.byType(TrackWeekStrip), findsNothing);
  });

  testWidgets('clicar num dia abre a região de leitura com o dia inteiro', (
    tester,
  ) async {
    insertFocus(at(0, 9, 12), const Duration(minutes: 25), 'Refatorar o auth');
    insertMeeting(at(0, 10, 0), const Duration(minutes: 45), 'Weekly do time');
    insertCopy(at(0, 11, 0), 'https://exemplo.com', ClipboardItemType.link);

    await pumpTrack(tester);
    expect(find.byType(HubDetailRegion), findsNothing);

    await tester.tap(inDayList('Hoje'));
    await tester.pumpAndSettle();

    expect(find.byType(HubDetailRegion), findsOneWidget);
    expect(find.text('FOCO'), findsOneWidget);
    expect(find.text('Refatorar o auth'), findsOneWidget);
    expect(find.text('REUNIÕES'), findsOneWidget);
    expect(find.text('Weekly do time'), findsOneWidget);
    expect(find.text('COPIADO'), findsOneWidget);
    // O tipo e a contagem, nunca o que foi copiado.
    expect(find.text('Links'), findsOneWidget);
    expect(find.text('https://exemplo.com'), findsNothing);
  });

  testWidgets('o parágrafo do modelo abre o dia', (tester) async {
    channel.summaryValue = 'Você passou a manhã no auth e teve uma reunião.';
    insertFocus(at(0, 9, 12), const Duration(minutes: 25), 'Refatorar o auth');

    await pumpTrack(tester);
    await tester.tap(inDayList('Hoje'));
    await tester.pumpAndSettle();

    expect(
      find.text('Você passou a manhã no auth e teve uma reunião.'),
      findsOneWidget,
    );
  });

  testWidgets('sem modelo, o dia continua inteiro e só falta o parágrafo', (
    tester,
  ) async {
    channel.failWith = const EchoException(
      'unsupported_os',
      'O Echo precisa do macOS 26 ou superior.',
    );
    insertFocus(at(0, 9, 12), const Duration(minutes: 25), 'Refatorar o auth');

    await pumpTrack(tester);
    await tester.tap(inDayList('Hoje'));
    await tester.pumpAndSettle();

    expect(find.byType(HubDetailRegion), findsOneWidget);
    expect(find.text('Refatorar o auth'), findsOneWidget);
    // Nem parágrafo, nem aviso de que ele falta: o resumo é enfeite.
    expect(find.textContaining('resumo'), findsNothing);
  });

  testWidgets('sem nada registrado, a tela diz o que falta acontecer', (
    tester,
  ) async {
    await pumpTrack(tester);

    expect(find.text('Nada registrado ainda'), findsOneWidget);
    expect(find.byType(TrackDayList), findsNothing);
  });
}
