import 'package:flutter/foundation.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../../shared/utils/day_bounds.dart';
import '../models/focus_session.dart';
import '../models/focus_session_note.dart';

/// Os dois números que o Focus mostra sobre o próprio uso.
///
/// Deliberadamente dois: "quanto foquei hoje" responde a pergunta do dia, e
/// "esta semana" dá a ela um contexto que o número sozinho não dá. Mais que
/// isso viraria dashboard, que é exatamente o que este módulo não é.
@immutable
class FocusStats {
  const FocusStats({required this.today, required this.week});

  /// Tempo focado desde a meia-noite de hoje.
  final Duration today;

  /// Tempo focado desde a segunda-feira desta semana.
  final Duration week;

  static const empty = FocusStats(today: Duration.zero, week: Duration.zero);

  bool get isEmpty => week == Duration.zero;
}

/// Contrato de persistência do histórico do Focus.
///
/// O histórico do Focus é **da semana corrente**: tudo que é de antes da
/// segunda-feira sai do caminho (ver [trimToCurrentWeek]). O módulo responde
/// "em que trabalhei nesta semana?", não é um arquivo histórico — e o que não
/// é consultado não precisa ser guardado.
abstract interface class FocusSessionRepository {
  /// Sessões desta semana, da mais recente para a mais antiga.
  List<FocusSession> loadRecent({int limit, DateTime? now});

  /// Registra uma sessão concluída e devolve a versão persistida (com `id`).
  FocusSession insert(FocusSession session);

  /// Grava o resumo escrito depois que a sessão já terminou.
  void setSummary(int id, String? summary);

  /// Remove uma sessão específica.
  void delete(int id);

  void clearAll();

  /// Totais de hoje e da semana corrente, ancorados em [now].
  FocusStats stats({DateTime? now});

  /// Apaga as sessões de semanas anteriores.
  void trimToCurrentWeek({DateTime? now});
}

/// Implementação sobre SQLite.
class SqliteFocusSessionRepository implements FocusSessionRepository {
  SqliteFocusSessionRepository(this._db);

  final Database _db;

  @override
  List<FocusSession> loadRecent({int limit = 50, DateTime? now}) {
    final rows = _db.select(
      '''
      SELECT id, started_at, duration_seconds, activity, summary, notes
        FROM focus_sessions
       WHERE started_at >= ?
       ORDER BY started_at DESC
       LIMIT ?;
      ''',
      [startOfWeek(now ?? DateTime.now()).millisecondsSinceEpoch, limit],
    );

    return rows.map(_fromRow).toList(growable: false);
  }

  @override
  FocusSession insert(FocusSession session) {
    _db.execute(
      '''
      INSERT INTO focus_sessions (started_at, duration_seconds, activity, summary, notes)
      VALUES (?, ?, ?, ?, ?);
      ''',
      [
        session.startedAt.millisecondsSinceEpoch,
        session.duration.inSeconds,
        _emptyAsNull(session.activity),
        _emptyAsNull(session.summary),
        FocusSessionNote.encodeList(session.notes),
      ],
    );

    return session.copyWith(id: _db.lastInsertRowId);
  }

  @override
  void setSummary(int id, String? summary) {
    _db.execute(
      'UPDATE focus_sessions SET summary = ? WHERE id = ?;',
      [_emptyAsNull(summary), id],
    );
  }

  @override
  void delete(int id) =>
      _db.execute('DELETE FROM focus_sessions WHERE id = ?;', [id]);

  @override
  void clearAll() => _db.execute('DELETE FROM focus_sessions;');

  @override
  void trimToCurrentWeek({DateTime? now}) {
    _db.execute(
      'DELETE FROM focus_sessions WHERE started_at < ?;',
      [startOfWeek(now ?? DateTime.now()).millisecondsSinceEpoch],
    );
  }

  @override
  FocusStats stats({DateTime? now}) {
    final moment = now ?? DateTime.now();
    final today = _startOfDay(moment);
    final weekStart = startOfWeek(moment);

    // Uma varredura só: a janela da semana filtra as linhas e o total de hoje
    // sai de um `CASE` dentro dela.
    final row = _db.select(
      '''
      SELECT
        COALESCE(SUM(CASE WHEN started_at >= ? THEN duration_seconds END), 0) AS today,
        COALESCE(SUM(duration_seconds), 0) AS week
      FROM focus_sessions
      WHERE started_at >= ?;
      ''',
      [today.millisecondsSinceEpoch, weekStart.millisecondsSinceEpoch],
    ).first;

    return FocusStats(
      today: Duration(seconds: row['today'] as int),
      week: Duration(seconds: row['week'] as int),
    );
  }

  static DateTime _startOfDay(DateTime moment) => DayBounds.startOfDay(moment);

  /// Segunda-feira desta semana, à meia-noite — a fronteira do histórico.
  ///
  /// Continua exposta aqui porque é o Focus quem define a fronteira; a conta
  /// mora em [DayBounds] desde que o Track passou a precisar do mesmo recorte.
  static DateTime startOfWeek(DateTime moment) => DayBounds.startOfWeek(moment);

  /// Campo em branco é ausência de informação, não string vazia — o histórico
  /// distingue "sessão sem atividade" de "atividade vazia".
  static String? _emptyAsNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static FocusSession _fromRow(Row row) => FocusSession(
        id: row['id'] as int,
        startedAt:
            DateTime.fromMillisecondsSinceEpoch(row['started_at'] as int),
        duration: Duration(seconds: row['duration_seconds'] as int),
        activity: row['activity'] as String?,
        summary: row['summary'] as String?,
        notes: FocusSessionNote.decodeList(row['notes'] as String?),
      );
}
