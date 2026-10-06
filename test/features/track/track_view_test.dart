import 'package:evergreen/app/providers.dart';
import 'package:evergreen/core/app_info.dart';
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
import 'package:evergreen/shared/widgets/eg_stat_card.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';

import '../echo/fake_echo_channel.dart';
import '../focus/fake_focus_session_repository.dart';
import '../pin/fake_clipboard_repository.dart';
import '../echo/fake_export_service.dart';

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
          exportServiceProvider.overrideWithValue(FakeExportService()),
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

  /// O balanço em três blocos, e não numa frase corrida: numa frase, o tempo
  /// focado, a contagem de sessões e o número de reuniões tinham o mesmo peso e
  /// se liam um atrás do outro.
  testWidgets('o balanço conta o período em três medidas', (tester) async {
    insertFocus(at(0, 9, 12), const Duration(minutes: 25), 'Refatorar o auth');
    insertFocus(at(0, 14, 30), const Duration(minutes: 40));
    insertMeeting(at(0, 10, 0), const Duration(minutes: 45), 'Weekly');
    insertCopy(at(0, 11, 0), 'https://exemplo.com', ClipboardItemType.link);

    expect(find.byType(EgStatCard), findsNothing);

    await pumpTrack(tester);

    expect(find.byType(EgStatCard), findsNWidgets(3));

    Finder inCard(String label, String text) => find.descendant(
      of: find.ancestor(
        of: find.text(label),
        matching: find.byType(EgStatCard),
      ),
      matching: find.textContaining(text),
    );

    expect(inCard('FOCO', '1h 05min'), findsOneWidget);
    expect(inCard('FOCO', '2 sessões'), findsOneWidget);
    expect(inCard('REUNIÃO', '45 min'), findsOneWidget);
    expect(inCard('REUNIÃO', '1 reunião'), findsOneWidget);
    expect(inCard('COPIADO', '1'), findsWidgets);
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

    // Escopo na região: "FOCO" e "COPIADO" também são etiquetas dos cartões de
    // balanço da coluna ao lado, e são legítimas nos dois lugares.
    Finder inDetail(String text) => find.descendant(
      of: find.byType(HubDetailRegion),
      matching: find.text(text),
    );

    expect(inDetail('FOCO'), findsOneWidget);
    expect(find.text('Refatorar o auth'), findsOneWidget);
    expect(inDetail('REUNIÕES'), findsOneWidget);
    expect(find.text('Weekly do time'), findsOneWidget);
    expect(inDetail('COPIADO'), findsOneWidget);
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

  testWidgets('as setas andam de semana em semana', (tester) async {
    insertFocus(at(0, 9, 0), const Duration(minutes: 25), 'Desta semana');
    // Terça da semana passada.
    insertFocus(at(8, 10, 0), const Duration(minutes: 40), 'Da passada');

    await pumpTrack(tester);
    expect(find.text('Esta semana'), findsOneWidget);
    expect(inDayList('Hoje'), findsOneWidget);

    await tester.tap(find.byTooltip('Semana anterior'));
    await tester.pumpAndSettle();

    expect(find.text('10 ago – 16 ago'), findsOneWidget);
    expect(inDayList('Hoje'), findsNothing);
    expect(inDayList('11 ago'), findsOneWidget);
    expect(find.byType(TrackWeekStrip), findsOneWidget);

    await tester.tap(find.byTooltip('Próxima semana'));
    await tester.pumpAndSettle();

    expect(find.text('Esta semana'), findsOneWidget);
    expect(inDayList('Hoje'), findsOneWidget);
  });

  testWidgets('segunda de manhã, a semana vazia ainda deixa voltar', (
    tester,
  ) async {
    // Só a semana passada tem registro — a segunda-feira em que se abre o
    // Track para fechar a semana anterior.
    insertFocus(at(8, 10, 0), const Duration(minutes: 40), 'Da passada');

    await pumpTrack(tester);

    // O recorte vazio não leva o controle junto.
    expect(find.byTooltip('Semana anterior'), findsOneWidget);
    expect(find.text('Hoje'), findsWidgets);

    await tester.tap(find.byTooltip('Semana anterior'));
    await tester.pumpAndSettle();

    expect(inDayList('11 ago'), findsOneWidget);
  });

  testWidgets('a semana passada vazia diz que está vazia, não que é estreia', (
    tester,
  ) async {
    insertFocus(at(0, 9, 0), const Duration(minutes: 25));

    await pumpTrack(tester);
    await tester.tap(find.byTooltip('Semana anterior'));
    await tester.pumpAndSettle();

    expect(find.text('Nada registrado nesta semana'), findsOneWidget);
    expect(find.text('Nada registrado ainda'), findsNothing);
  });
}
