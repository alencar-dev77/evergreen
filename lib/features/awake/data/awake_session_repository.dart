import 'package:sqlite3/sqlite3.dart';

import '../models/awake_session.dart';

/// Contrato de persistência dos períodos do Awake.
///
/// Só escrita: quem lê é o Track, direto da tabela, como faz com as dos outros
/// módulos. O Awake não tem tela de histórico — o painel responde "está ligado?"
/// e o dia reconstruído responde "por quanto tempo ficou?".
abstract interface class AwakeSessionRepository {
  /// Registra um período encerrado.
  void insert(AwakeSession session);
}

/// Implementação sobre SQLite.
///
/// Sem limpeza automática, diferente do Pin e do Echo: é uma linha de quatro
/// números por trava solta, duas ou três por dia no uso pesado. O que justifica
/// um teto nos outros é o tamanho do que eles guardam (o histórico inteiro da
/// área de transferência, transcrições de reunião), e aqui não há tamanho.
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
  }
}
