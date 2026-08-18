import 'package:evergreen/core/storage/app_database.dart';
import 'package:evergreen/features/echo/data/echo_repository.dart';
import 'package:evergreen/features/echo/models/meeting.dart';
import 'package:evergreen/features/echo/models/meeting_segment.dart';
import 'package:evergreen/features/echo/models/transcription_language.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Database db;
  late EchoRepository repository;

  Meeting meetingAt(int day, {String? title, bool isKept = false}) => Meeting(
    title: title ?? 'Reunião $day',
    startedAt: DateTime(2026, 8, day),
    durationMs: const Duration(minutes: 30).inMilliseconds,
    language: TranscriptionLanguage.ptBR,
    isKept: isKept,
    segments: const [
      MeetingSegment(speaker: Speaker.me, startMs: 0, endMs: 2000, text: 'bom dia'),
      MeetingSegment(
        speaker: Speaker.others,
        startMs: 2500,
        endMs: 5000,
        text: 'bom dia, vamos começar',
      ),
    ],
  );

  setUp(() {
    db = sqlite3.openInMemory();
    AppDatabase.migrate(db);
    repository = SqliteEchoRepository(db);
  });

  tearDown(() => db.close());

  test('guarda e relê a transcrição inteira', () {
    final saved = repository.insert(meetingAt(1));

    final loaded = repository.findById(saved.id!)!;
    expect(loaded.title, 'Reunião 1');
    expect(loaded.segments, hasLength(2));
    expect(loaded.segments.first.speaker, Speaker.me);
    expect(loaded.segments.last.text, 'bom dia, vamos começar');
    expect(loaded.hasSummary, isFalse);
  });

  test('texto com barra vertical e quebra de linha sobrevive', () {
    // É por isso que a transcrição é JSON e não `campo|campo`: fala transcrita
    // pode conter qualquer separador que se improvisasse.
    final complicado = repository.insert(
      Meeting(
        title: 'Complicada',
        startedAt: DateTime(2026, 8, 2),
        durationMs: 1000,
        language: TranscriptionLanguage.ptBR,
        segments: const [
          MeetingSegment(
            speaker: Speaker.others,
            startMs: 0,
            endMs: 1000,
            text: 'usa o pipe | assim\ne quebra a linha',
          ),
        ],
      ),
    );

    final loaded = repository.findById(complicado.id!)!;
    expect(loaded.segments.single.text, 'usa o pipe | assim\ne quebra a linha');
  });

  test('a lista vem da mais recente para a mais antiga', () {
    repository.insert(meetingAt(1));
    repository.insert(meetingAt(5));
    repository.insert(meetingAt(3));

    expect(
      repository.loadAll().map((meeting) => meeting.title),
      ['Reunião 5', 'Reunião 3', 'Reunião 1'],
    );
  });

  test('a limpeza tira as mais antigas', () {
    for (var day = 1; day <= 5; day++) {
      repository.insert(meetingAt(day));
    }

    repository.trimHistory(3);

    expect(
      repository.loadAll().map((meeting) => meeting.title),
      ['Reunião 5', 'Reunião 4', 'Reunião 3'],
    );
  });

  test('reunião guardada sobrevive à limpeza e não ocupa vaga', () {
    repository.insert(meetingAt(1, title: 'Planejamento', isKept: true));
    for (var day = 2; day <= 6; day++) {
      repository.insert(meetingAt(day));
    }

    repository.trimHistory(2);

    final titles = repository.loadAll().map((meeting) => meeting.title).toList();
    // A guardada continua lá — e as duas vagas do teto foram para as ordinárias
    // mais recentes, não consumidas por ela.
    expect(titles, contains('Planejamento'));
    expect(titles, containsAll(['Reunião 6', 'Reunião 5']));
    expect(titles, hasLength(3));
  });

  test('guardar e desguardar alterna', () {
    final saved = repository.insert(meetingAt(1));

    repository.setKept(saved.id!, isKept: true);
    expect(repository.findById(saved.id!)!.isKept, isTrue);

    repository.setKept(saved.id!, isKept: false);
    expect(repository.findById(saved.id!)!.isKept, isFalse);
  });

  test('o resumo é gravado separado da transcrição', () {
    final saved = repository.insert(meetingAt(1));

    repository.setSummary(saved.id!, '- decidimos começar');

    final loaded = repository.findById(saved.id!)!;
    expect(loaded.summary, '- decidimos começar');
    expect(loaded.segments, hasLength(2));
  });

  test('renomear ignora título em branco', () {
    final saved = repository.insert(meetingAt(1));

    repository.setTitle(saved.id!, '   ');
    expect(repository.findById(saved.id!)!.title, 'Reunião 1');

    repository.setTitle(saved.id!, 'Retro da sprint');
    expect(repository.findById(saved.id!)!.title, 'Retro da sprint');
  });

  test('o texto que vai para o resumo diz quem falou', () {
    final meeting = meetingAt(1);

    expect(meeting.plainText, 'Você: bom dia\nReunião: bom dia, vamos começar');
  });
}
