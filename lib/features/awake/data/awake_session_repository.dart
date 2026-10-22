import 'package:sqlite3/sqlite3.dart';

import '../../focus/data/focus_session_repository.dart';
import '../models/awake_session.dart';

/// Contrato de persistência dos períodos do Awake.
///
/// Só escrita: quem lê é o Track, direto da tabela, como faz com as dos outros
/// módulos. O Awake não tem tela de histórico — o painel responde "está ligado?"
/// e o dia reconstruído responde "por quanto tempo ficou?".
abstract interface class AwakeSessionRepository {
  /// Registra um período encerrado — e tira os de antes do que o Track lê.
  void insert(AwakeSession session);
}

/// Implementação sobre SQLite.
///
/// Guarda as mesmas semanas do Focus ([FocusSessionRepository.keptWeeks]), e
/// pela mesma régua: o Track é o único leitor e não volta mais que isso. O
/// tamanho nunca foi o motivo — são quatro números por trava solta —; o motivo
/// é que uma linha que ninguém lê não tem por que continuar no disco, e a
/// política de privacidade promete o prazo. A limpeza vai junto da escrita,
/// como no Focus: é o único momento em que o Awake mexe na tabela.
class SqliteAwakeSessionRepository implements AwakeSessionRepository {
  SqliteAwakeSessionRepository(this._db);

  final Database _db;

  @override
  void insert(AwakeSession session) {
    _db.execute(
      '''
      INSERT INTO awake_sessions (started_at, duration_seconds, mode)
      VALUES (?, ?, ?);
      ''',
      [
        session.startedAt.millisecondsSinceEpoch,
        session.duration.inSeconds,
        session.mode.name,
      ],
    );

    _db.execute('DELETE FROM awake_sessions WHERE started_at < ?;', [
      FocusSessionRepository.keptSince(
        session.startedAt,
      ).millisecondsSinceEpoch,
    ]);
  }
}
