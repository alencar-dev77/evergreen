import 'package:evergreen/core/storage/app_database.dart';
import 'package:evergreen/features/echo/data/echo_audio_store.dart';
import 'package:evergreen/features/echo/data/echo_repository.dart';
import 'package:evergreen/features/echo/models/echo_audio_retention.dart';
import 'package:evergreen/features/echo/models/meeting.dart';
import 'package:evergreen/features/echo/models/meeting_segment.dart';
import 'package:evergreen/features/echo/models/transcription_language.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'fake_echo_audio.dart';

/// O áudio das reuniões: quanto tempo ele fica, e quem o tira do disco.
///
/// A regra é "14 dias, ou até a reunião sair — o que vier primeiro", com a
/// estrela guardando os dois. O que estes testes prendem é que todo caminho
/// pelo qual uma reunião perde o áudio acaba com o arquivo fora do disco e a
/// linha sem apontar para ele.
void main() {
  /// Quarta-feira, 19/08, às 15h.
  final now = DateTime(2026, 8, 19, 15);

  group('EchoAudioRetention', () {
    EchoAudioRef ref(DateTime startedAt, {bool kept = false}) => EchoAudioRef(
      meetingId: 1,
      fileName: 'a.m4a',
      startedAt: startedAt,
      isKept: kept,
    );

    test('vale por 14 dias de calendário', () {
      // Gravada no dia 5 às 23h: vence no começo do dia 19, inteira.
      expect(
        EchoAudioRetention.isExpired(ref(DateTime(2026, 8, 5, 23)), now),
        isTrue,
      );
      expect(
        EchoAudioRetention.isExpired(ref(DateTime(2026, 8, 6, 9)), now),
        isFalse,
      );
    });

    test('a estrela guarda o áudio', () {
      expect(
        EchoAudioRetention.isExpired(
          ref(DateTime(2026, 1, 1), kept: true),
          now,
        ),
        isFalse,
      );
    });
  });

  group('EchoAudioJanitor', () {
    late Database db;
    late EchoRepository repository;
    late FakeEchoAudioStore store;
    late EchoAudioJanitor janitor;

    setUp(() {
      db = sqlite3.openInMemory();
      AppDatabase.migrate(db);
      repository = SqliteEchoRepository(db);
      store = FakeEchoAudioStore();
      janitor = EchoAudioJanitor(repository: repository, store: store);
    });

    tearDown(() => db.close());

    Meeting insert(DateTime startedAt, String? file, {bool kept = false}) {
      if (file != null) store.files.add(file);
      return repository.insert(
        Meeting(
          title: 'R',
          startedAt: startedAt,
          durationMs: 60000,
          language: TranscriptionLanguage.ptBR,
          segments: const [],
          isKept: kept,
          audioFile: file,
        ),
      );
    }

    test('o áudio vencido sai do disco e da linha; o texto fica', () {
      final old = insert(DateTime(2026, 8, 1), 'velha.m4a');
      final fresh = insert(DateTime(2026, 8, 18), 'nova.m4a');
      final kept = insert(DateTime(2026, 7, 1), 'guardada.m4a', kept: true);

      janitor.sweep(now);

      expect(store.files, {'nova.m4a', 'guardada.m4a'});
      expect(repository.findById(old.id!)!.audioFile, isNull);
      expect(repository.findById(old.id!), isNotNull);
      expect(repository.findById(fresh.id!)!.audioFile, 'nova.m4a');
      expect(repository.findById(kept.id!)!.audioFile, 'guardada.m4a');
    });

    test('apagar a reunião deixa o áudio órfão, e a varredura o leva', () {
      final meeting = insert(DateTime(2026, 8, 18), 'apagada.m4a');
      repository.delete(meeting.id!);

      janitor.sweep(now);

      expect(store.files, isEmpty);
    });

    test('o teto de reuniões leva o áudio junto, antes dos 14 dias', () {
      insert(DateTime(2026, 8, 17), 'primeira.m4a');
      insert(DateTime(2026, 8, 18), 'segunda.m4a');

      repository.trimHistory(1);
      janitor.sweep(now);

      expect(store.files, {'segunda.m4a'});
    });

    test('a linha que aponta para um áudio que sumiu é solta', () {
      // O backup traz o banco e não o áudio: depois de restaurar, a linha
      // diria que tem áudio e a tela ofereceria um player sem o que tocar.
      final meeting = insert(DateTime(2026, 8, 18), null);
      repository.setAudioFile(meeting.id!, 'perdida.m4a');

      janitor.sweep(now);

      expect(repository.findById(meeting.id!)!.audioFile, isNull);
    });
  });

  group('MeetingWord', () {
    test('as palavras vão e voltam do banco, e reunião antiga lê sem elas', () {
      const segment = MeetingSegment(
        speaker: Speaker.me,
        startMs: 0,
        endMs: 900,
        text: ' bom dia',
        words: [
          MeetingWord(startMs: 0, endMs: 400, text: ' bom'),
          MeetingWord(startMs: 450, endMs: 900, text: ' dia'),
        ],
      );

      final decoded = MeetingSegment.fromMap(segment.toJson());
      expect(decoded.words.map((word) => word.text), [' bom', ' dia']);
      expect(decoded.words.last.startMs, 450);

      final old = MeetingSegment.fromMap(const {
        'speaker': 'me',
        'startMs': 0,
        'endMs': 900,
        'text': 'bom dia',
      });
      expect(old.words, isEmpty);
      expect(old.toJson().containsKey('words'), isFalse);
    });
  });
}
