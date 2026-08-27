import 'package:sqlite3/sqlite3.dart';

import '../../../shared/utils/day_bounds.dart';
import '../../awake/models/awake_mode.dart';
import '../../pin/models/clipboard_item_type.dart';
import '../models/track_day.dart';

/// Contrato de leitura do Track.
///
/// Só leitura, de propósito: o Track não tem tabela, não escreve linha nenhuma
/// e não faz migração. Ele é uma consulta sobre o que os outros quatro módulos
/// já gravaram — e é isso que faz cada módulo novo alimentá-lo de graça.
abstract interface class TrackRepository {
  /// Os dias com registro desde [since], do mais recente para o mais antigo —
  /// e o que aconteceu **dentro** de cada dia na ordem inversa, da manhã para a
  /// noite.
  ///
  /// As duas ordens discordam de propósito. A lista de dias é uma lista: quem
  /// abre o módulo quer hoje na primeira linha. Um dia aberto é uma história, e
  /// história se lê do começo — a sessão das nove antes da das três é o que
  /// reconstrói o dia, que é o nome do módulo.
  ///
  /// Dias em que nada aconteceu não vêm na lista: quem monta a tela é quem
  /// decide se um dia vazio merece uma linha (hoje merece, uma quarta-feira de
  /// folga não).
  List<TrackDay> loadDays({required DateTime since});
}

/// Implementação sobre SQLite.
///
/// **O conteúdo copiado nunca sai do banco.** A consulta do Pin pede
/// `copied_at` e `type`, e mais nada: não é uma escolha da tela, é a fronteira
/// do módulo. O Pin registra tudo que passa pela área de transferência, senha
/// colada inclusive, e uma tela que mostrasse "o que você copiou hoje" seria,
/// sem esse cuidado, uma tela de senhas em texto puro — que ainda por cima
/// seguiria para o modelo que escreve o resumo.
class SqliteTrackRepository implements TrackRepository {
  SqliteTrackRepository(this._db);

  final Database _db;

  @override
  List<TrackDay> loadDays({required DateTime since}) {
    final from = DayBounds.startOfDay(since).millisecondsSinceEpoch;
    final days = <DateTime, _DayBucket>{};

    _DayBucket bucketOf(int timestamp) {
      final moment = DateTime.fromMillisecondsSinceEpoch(timestamp);
      return days.putIfAbsent(DayBounds.startOfDay(moment), _DayBucket.new);
    }

    // Cinco varreduras curtas, uma por tabela, em vez de um `JOIN` entre
    // coisas que não se relacionam: uma sessão de foco não tem nada a ver com
    // um item copiado além de terem acontecido no mesmo dia, e é o Dart que
    // agrupa por dia — converter epoch em data local dentro do SQLite obrigaria
    // a confiar no fuso do processo, que é justamente o que o `DateTime` já faz
    // certo.
    for (final row in _db.select(
      '''
      SELECT started_at, duration_seconds, activity
        FROM focus_sessions
       WHERE started_at >= ?
       ORDER BY started_at ASC;
      ''',
      [from],
    )) {
      final at = row['started_at'] as int;
      bucketOf(at).focus.add(
            TrackEntry(
              at: DateTime.fromMillisecondsSinceEpoch(at),
              duration: Duration(seconds: row['duration_seconds'] as int),
              label: row['activity'] as String?,
            ),
          );
    }

    for (final row in _db.select(
      '''
      SELECT started_at, duration_ms, title
        FROM echo_meetings
       WHERE started_at >= ?
       ORDER BY started_at ASC;
      ''',
      [from],
    )) {
      final at = row['started_at'] as int;
      bucketOf(at).meetings.add(
            TrackEntry(
              at: DateTime.fromMillisecondsSinceEpoch(at),
              duration: Duration(milliseconds: row['duration_ms'] as int),
              label: row['title'] as String?,
            ),
          );
    }

    for (final row in _db.select(
      '''
      SELECT started_at, duration_seconds, mode
        FROM awake_sessions
       WHERE started_at >= ?
       ORDER BY started_at ASC;
      ''',
      [from],
    )) {
      final at = row['started_at'] as int;
      bucketOf(at).awake.add(
            TrackEntry(
              at: DateTime.fromMillisecondsSinceEpoch(at),
              duration: Duration(seconds: row['duration_seconds'] as int),
              label: AwakeMode.fromName(row['mode'] as String?).periodLabel,
            ),
          );
    }

    // `copied_at` e `type`. Nunca `content` — ver a nota da classe.
    for (final row in _db.select(
      '''
      SELECT copied_at, type
        FROM clipboard_items
       WHERE copied_at >= ?;
      ''',
      [from],
    )) {
      final bucket = bucketOf(row['copied_at'] as int);
      final type = ClipboardItemType.fromName(row['type'] as String);
      bucket.copied[type] = (bucket.copied[type] ?? 0) + 1;
    }

    for (final row in _db.select(
      'SELECT created_at FROM leaf_notes WHERE created_at >= ?;',
      [from],
    )) {
      bucketOf(row['created_at'] as int).notesWritten++;
    }

    final dates = days.keys.toList()..sort((a, b) => b.compareTo(a));

    return [
      for (final date in dates) days[date]!.freeze(date),
    ];
  }
}

/// O dia sendo montado, enquanto as quatro varreduras acontecem.
class _DayBucket {
  final focus = <TrackEntry>[];
  final meetings = <TrackEntry>[];
  final awake = <TrackEntry>[];
  final copied = <ClipboardItemType, int>{};
  int notesWritten = 0;

  TrackDay freeze(DateTime date) => TrackDay(
        date: date,
        focus: List.unmodifiable(focus),
        meetings: List.unmodifiable(meetings),
        awake: List.unmodifiable(awake),
        copied: Map.unmodifiable(copied),
        notesWritten: notesWritten,
      );
}
