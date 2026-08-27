import 'package:evergreen/core/storage/app_database.dart';
import 'package:evergreen/features/pin/models/clipboard_item_type.dart';
import 'package:evergreen/features/track/data/track_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

/// A leitura que o Track faz das tabelas dos outros módulos.
///
/// O que estes testes prendem é a promessa do módulo: ele agrupa por dia o que
/// já estava gravado, não inventa dia nenhum, e **nunca toca no conteúdo
/// copiado** — o Pin registra tudo que passa pela área de transferência, senha
/// inclusive, e é essa consulta que separa "quantos itens" de "quais itens".
void main() {
  late Database db;
  late TrackRepository repository;

  /// Quarta-feira, para que "ontem" caia na mesma semana.
  final now = DateTime(2026, 8, 19, 15, 30);
  DateTime at(int daysAgo, int hour, int minute) =>
      DateTime(now.year, now.month, now.day - daysAgo, hour, minute);

  setUp(() {
    db = sqlite3.openInMemory();
    AppDatabase.migrate(db);
    repository = SqliteTrackRepository(db);
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

  void insertAwake(DateTime startedAt, Duration duration, String mode) {
    db.execute(
      'INSERT INTO awake_sessions (started_at, duration_seconds, mode) '
      'VALUES (?, ?, ?);',
      [startedAt.millisecondsSinceEpoch, duration.inSeconds, mode],
    );
  }

  void insertNote(DateTime createdAt, int slot) {
    db.execute(
      'INSERT INTO leaf_notes (slot, content, created_at) VALUES (?, ?, ?);',
      [slot, 'anotação', createdAt.millisecondsSinceEpoch],
    );
  }

  test('junta as quatro fontes no dia em que aconteceram', () {
    insertFocus(at(0, 9, 12), const Duration(minutes: 25), 'Refatorar o auth');
    insertFocus(at(0, 14, 30), const Duration(minutes: 40));
    insertMeeting(at(0, 10, 0), const Duration(minutes: 45), 'Weekly');
    insertCopy(at(0, 11, 0), 'https://exemplo.com', ClipboardItemType.link);
    insertNote(at(0, 16, 0), 1);

    final days = repository.loadDays(since: at(6, 0, 0));
    expect(days, hasLength(1));

    final today = days.single;
    expect(today.focus, hasLength(2));
    expect(today.focusTotal, const Duration(minutes: 65));
    expect(today.meetings, hasLength(1));
    expect(today.meetingTotal, const Duration(minutes: 45));
    expect(today.copiedTotal, 1);
    expect(today.notesWritten, 1);
    // Tempo registrado é foco mais reunião — a medida do Track.
    expect(today.registered, const Duration(minutes: 110));
  });

  test('um dia por linha, do mais recente para o mais antigo', () {
    insertFocus(at(0, 9, 0), const Duration(minutes: 25));
    insertFocus(at(1, 9, 0), const Duration(minutes: 25));
    insertFocus(at(2, 9, 0), const Duration(minutes: 25));

    final days = repository.loadDays(since: at(6, 0, 0));

    expect(days.map((day) => day.date), [
      DateTime(now.year, now.month, now.day),
      DateTime(now.year, now.month, now.day - 1),
      DateTime(now.year, now.month, now.day - 2),
    ]);
  });

  test('dia sem registro nenhum não vira linha', () {
    insertFocus(at(2, 9, 0), const Duration(minutes: 25));

    final days = repository.loadDays(since: at(6, 0, 0));

    // Quem decide se o dia de hoje merece uma linha mesmo vazio é a tela — o
    // repositório só devolve o que existe.
    expect(days, hasLength(1));
    expect(days.single.date, DateTime(now.year, now.month, now.day - 2));
  });

  test('o que é de antes do recorte fica de fora', () {
    insertFocus(at(0, 9, 0), const Duration(minutes: 25));
    insertFocus(at(5, 9, 0), const Duration(minutes: 25));

    final days = repository.loadDays(since: at(1, 0, 0));

    expect(days, hasLength(1));
    expect(days.single.date, DateTime(now.year, now.month, now.day));
  });

  test('o recorte começa na meia-noite do dia pedido', () {
    insertFocus(at(0, 2, 15), const Duration(minutes: 25));

    // Pedindo a partir das 15h30 de hoje, a sessão das 2h15 ainda é de hoje.
    final days = repository.loadDays(since: now);

    expect(days, hasLength(1));
    expect(days.single.focus, hasLength(1));
  });

  test('a área de transferência entra como contagem por tipo', () {
    insertCopy(at(0, 9, 0), 'https://a.com', ClipboardItemType.link);
    insertCopy(at(0, 9, 1), 'https://b.com', ClipboardItemType.link);
    insertCopy(at(0, 9, 2), 'git status', ClipboardItemType.command);
    insertCopy(at(1, 9, 0), 'ontem', ClipboardItemType.text);

    final days = repository.loadDays(since: at(6, 0, 0));

    expect(days.first.copied, {
      ClipboardItemType.link: 2,
      ClipboardItemType.command: 1,
    });
    expect(days.last.copied, {ClipboardItemType.text: 1});
  });

  test('o conteúdo copiado não sai do banco', () {
    insertCopy(at(0, 9, 0), 'senha-do-banco-123', ClipboardItemType.text);

    final day = repository.loadDays(since: at(6, 0, 0)).single;

    // A garantia é estrutural: o dia guarda um mapa de contagens, e não há
    // campo nenhum onde o texto copiado pudesse caber.
    expect(day.copiedTotal, 1);
    expect(day.copied[ClipboardItemType.text], 1);
    expect(day.toString(), isNot(contains('senha-do-banco')));
  });

  test('o dia se lê da manhã para a noite, ao contrário da lista de dias', () {
    insertFocus(at(0, 15, 5), const Duration(minutes: 50), 'Tarde');
    insertFocus(at(0, 9, 12), const Duration(minutes: 25), 'Manhã');
    insertFocus(at(1, 9, 0), const Duration(minutes: 25), 'Ontem');

    final days = repository.loadDays(since: at(6, 0, 0));

    // A lista de dias é uma lista: hoje na primeira linha.
    expect(days.first.date, DateTime(now.year, now.month, now.day));
    // Um dia aberto é uma história, e história se lê do começo.
    expect(days.first.focus.map((entry) => entry.label), ['Manhã', 'Tarde']);
  });

  test('a sessão sem atividade chega sem nome, e não com um nome vazio', () {
    insertFocus(at(0, 9, 0), const Duration(minutes: 25));

    final day = repository.loadDays(since: at(6, 0, 0)).single;

    expect(day.focus.single.hasLabel, isFalse);
    expect(day.focus.single.label, isNull);
  });

  test('banco sem nada devolve lista vazia', () {
    expect(repository.loadDays(since: at(6, 0, 0)), isEmpty);
  });

  test('o Awake entra no dia como período, com o que ele segurava', () {
    insertAwake(at(0, 22, 10), const Duration(hours: 3), 'system');
    insertAwake(at(0, 9, 0), const Duration(minutes: 40), 'screen');
    insertAwake(at(1, 9, 0), const Duration(minutes: 15), 'screen');

    final days = repository.loadDays(since: at(6, 0, 0));
    final today = days.first;

    // Dentro do dia, na ordem em que aconteceu — como as sessões e as reuniões.
    expect(today.awake.map((entry) => entry.label), [
      'Tela acesa',
      'Sistema acordado',
    ]);
    expect(today.awakeTotal, const Duration(hours: 3, minutes: 40));
    expect(days[1].awake, hasLength(1));

    // A trava não é trabalho: ela não infla o tempo registrado do dia.
    expect(today.registered, Duration.zero);
    expect(today.isEmpty, isFalse);
    expect(today.highlights, contains('3h 40min acordado'));
  });
}
