import 'package:sqlite3/sqlite3.dart';

import '../../focus/data/focus_session_repository.dart';
import '../models/nest_transfer.dart';

/// Contrato de persistência do que o Nest organizou.
///
/// Só escrita, como o do Awake: quem lê é o Track, direto da tabela. O painel
/// responde "o que está na prateleira agora?", e o dia reconstruído responde
/// "quantos arquivos você organizou?".
abstract interface class NestTransferRepository {
  /// Registra uma transferência concluída e devolve o número da linha.
  ///
  /// O número é o que permite [delete]: uma transferência desfeita pelo `⌘Z`
  /// não organizou nada, e deixá-la no dia reconstruído faria o Track contar
  /// arquivos que voltaram para onde estavam. Zero quando não havia o que
  /// registrar.
  int insert(NestTransfer transfer);

  /// Apaga uma linha desfeita.
  void delete(int id);
}

/// Implementação sobre SQLite.
///
/// **Nenhum caminho e nenhum nome de arquivo chegam aqui.** É a mesma fronteira
/// que faz a consulta do Track pedir só `copied_at` e `type` ao Pin, e pelo
/// mesmo motivo: nome de arquivo é conteúdo — `demissão.pdf` conta uma história
/// inteira —, e o que está no banco vai para o backup e para o modelo que
/// escreve o parágrafo do dia. A linha guarda quando, quantos e se copiou ou
/// moveu. Nada mais existe para ser guardado.
///
/// Guarda as mesmas semanas do Focus ([FocusSessionRepository.keptWeeks]),
/// como o Awake: o Track é o único leitor e não volta mais que isso, e a
/// política de privacidade promete o prazo. A limpeza vai junto da escrita.
class SqliteNestTransferRepository implements NestTransferRepository {
  SqliteNestTransferRepository(this._db);

  final Database _db;

  @override
  int insert(NestTransfer transfer) {
    if (transfer.isEmpty) return 0;

    _db.execute(
      '''
      INSERT INTO nest_transfers (moved_at, file_count, mode)
      VALUES (?, ?, ?);
      ''',
      [
        transfer.at.millisecondsSinceEpoch,
        transfer.fileCount,
        transfer.mode.name,
      ],
    );
    final id = _db.lastInsertRowId;

    _db.execute('DELETE FROM nest_transfers WHERE moved_at < ?;', [
      FocusSessionRepository.keptSince(transfer.at).millisecondsSinceEpoch,
    ]);

    return id;
  }

  @override
  void delete(int id) {
    if (id == 0) return;

    _db.execute('DELETE FROM nest_transfers WHERE id = ?;', [id]);
  }
}
