import 'package:sqlite3/sqlite3.dart';

import '../models/echo_audio_retention.dart';
import '../models/meeting.dart';
import '../models/transcription_language.dart';

/// Contrato de persistência das reuniões do Echo.
abstract interface class EchoRepository {
  /// As reuniões, da mais recente para a mais antiga.
  List<Meeting> loadAll({int limit});

  Meeting? findById(int id);

  /// Grava uma reunião nova e devolve com o `id` que o banco deu.
  Meeting insert(Meeting meeting);

  /// Grava o resumo **e** a instrução que o produziu — sempre os dois juntos.
  ///
  /// Um parâmetro só, e obrigatório, porque texto e instrução são o mesmo
  /// fato: um resumo cuja instrução não foi registrada é o que esta coluna
  /// existe para acabar.
  void setSummary(int id, String summary, {required String prompt});

  void setTitle(int id, String title);

  /// Marca (ou desmarca) a reunião como guardada — ela deixa de entrar na
  /// conta da limpeza automática.
  void setKept(int id, {required bool isKept});

  void delete(int id);

  /// Apaga todas as reuniões não guardadas — a guardada fica, como o item
  /// fixado no "Apagar histórico" do Pin.
  void clearAll();

  /// Apaga as reuniões não guardadas que excedam [maxMeetings].
  void trimHistory(int maxMeetings);

  /// Liga (ou solta, com `null`) o arquivo de áudio da reunião.
  void setAudioFile(int id, String? fileName);

  /// As reuniões que dizem ter áudio — só o necessário para decidir se ele
  /// vence, sem trazer a transcrição junto.
  List<EchoAudioRef> audioRefs();
}

/// Implementação sobre SQLite.
class SqliteEchoRepository implements EchoRepository {
  SqliteEchoRepository(this._db);

  final Database _db;

  static const _columns =
      'id, title, started_at, duration_ms, language, transcript, summary, '
      'summary_prompt, is_kept, audio_file';

  @override
  List<Meeting> loadAll({int limit = 200}) {
    final rows = _db.select(
      'SELECT $_columns FROM echo_meetings ORDER BY started_at DESC LIMIT ?;',
      [limit],
    );

    return rows.map(_fromRow).toList(growable: false);
  }

  @override
  Meeting? findById(int id) {
    final rows = _db.select(
      'SELECT $_columns FROM echo_meetings WHERE id = ?;',
      [id],
    );

    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  @override
  Meeting insert(Meeting meeting) {
    _db.execute(
      '''
      INSERT INTO echo_meetings
        (title, started_at, duration_ms, language, transcript, summary,
         summary_prompt, is_kept, audio_file)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
      ''',
      [
        meeting.title,
        meeting.startedAt.millisecondsSinceEpoch,
        meeting.durationMs,
        meeting.language.locale,
        meeting.encodeSegments(),
        meeting.summary,
        meeting.summaryPrompt,
        meeting.isKept ? 1 : 0,
        meeting.audioFile,
      ],
    );

    return meeting.copyWith(id: _db.lastInsertRowId);
  }

  @override
  void setSummary(int id, String summary, {required String prompt}) {
    _db.execute(
      'UPDATE echo_meetings SET summary = ?, summary_prompt = ? WHERE id = ?;',
      [summary, prompt, id],
    );
  }

  @override
  void setTitle(int id, String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;

    _db.execute('UPDATE echo_meetings SET title = ? WHERE id = ?;', [
      trimmed,
      id,
    ]);
  }

  @override
  void setKept(int id, {required bool isKept}) {
    _db.execute('UPDATE echo_meetings SET is_kept = ? WHERE id = ?;', [
      isKept ? 1 : 0,
      id,
    ]);
  }

  @override
  void delete(int id) {
    _db.execute('DELETE FROM echo_meetings WHERE id = ?;', [id]);
  }

  @override
  void clearAll() {
    _db.execute('DELETE FROM echo_meetings WHERE is_kept = 0;');
  }

  /// A limpeza nunca alcança reunião guardada — nem para contar.
  ///
  /// Contar as guardadas faria o teto se fechar sozinho: com [maxMeetings]
  /// reuniões marcadas, toda reunião nova nasceria já elegível para a limpeza e
  /// sumiria na gravação seguinte. Mesma regra do item fixado no Pin.
  @override
  void trimHistory(int maxMeetings) {
    _db.execute(
      '''
      DELETE FROM echo_meetings
       WHERE is_kept = 0
         AND id NOT IN (
           SELECT id FROM echo_meetings
            WHERE is_kept = 0
            ORDER BY started_at DESC
            LIMIT ?
         );
      ''',
      [maxMeetings],
    );
  }

  @override
  void setAudioFile(int id, String? fileName) {
    _db.execute('UPDATE echo_meetings SET audio_file = ? WHERE id = ?;', [
      fileName,
      id,
    ]);
  }

  @override
  List<EchoAudioRef> audioRefs() {
    final rows = _db.select(
      'SELECT id, started_at, is_kept, audio_file FROM echo_meetings '
      'WHERE audio_file IS NOT NULL;',
    );

    return [
      for (final row in rows)
        EchoAudioRef(
          meetingId: row['id'] as int,
          fileName: row['audio_file'] as String,
          startedAt: DateTime.fromMillisecondsSinceEpoch(
            row['started_at'] as int,
          ),
          isKept: (row['is_kept'] as int? ?? 0) == 1,
        ),
    ];
  }

  Meeting _fromRow(Row row) => Meeting(
    id: row['id'] as int,
    title: row['title'] as String,
    startedAt: DateTime.fromMillisecondsSinceEpoch(row['started_at'] as int),
    durationMs: row['duration_ms'] as int,
    language: TranscriptionLanguage.fromLocale(
      row['language'] as String? ?? 'pt-BR',
    ),
    segments: Meeting.decodeSegments(row['transcript'] as String?),
    summary: row['summary'] as String?,
    summaryPrompt: row['summary_prompt'] as String?,
    isKept: (row['is_kept'] as int? ?? 0) == 1,
    audioFile: row['audio_file'] as String?,
  );
}
