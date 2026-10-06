import 'package:sqlite3/sqlite3.dart';

import '../models/leaf_note.dart';

/// Contrato de persistência das anotações do Leaf.
///
/// Mesma fronteira do Pin e do Focus: a ViewModel só conhece esta interface, e
/// o SQLite não vaza para a camada de apresentação.
abstract interface class LeafRepository {
  /// Todas as anotações, em ordem de vaga.
  List<LeafNote> loadAll();

  /// Grava uma anotação nova na [slot] indicada.
  ///
  /// [updatedAt] existe para quem está **devolvendo** uma anotação à parede —
  /// o desfazer de um apagar. Uma anotação nova nunca tem data de edição.
  LeafNote create({
    required int slot,
    required String content,
    required DateTime createdAt,
    DateTime? updatedAt,
    DateTime? remindAt,
  });

  /// Marca (ou, com `null`, tira) o lembrete da anotação.
  void setReminder(int id, DateTime? at);

  /// Reescreve o texto e marca a hora em que isso aconteceu.
  ///
  /// [at] vem de quem chama, e não de um `DateTime.now()` aqui dentro, pela
  /// mesma razão de todo relógio do projeto: o teste precisa poder dizer que
  /// horas são.
  void updateContent(int id, String content, {required DateTime at});

  /// Reassenta as anotações nas vagas 1..N, na ordem em que vierem.
  ///
  /// Em lote, e não uma a uma, porque a vaga é única no banco: `[3, 4]` virando
  /// `[1, 2]` só é seguro se ninguém observar o meio do caminho.
  void reassignSlots(List<int> idsInOrder);

  void delete(int id);

  void clearAll();
}

/// Implementação sobre SQLite.
class SqliteLeafRepository implements LeafRepository {
  SqliteLeafRepository(this._db);

  final Database _db;

  @override
  List<LeafNote> loadAll() {
    final rows = _db.select('''
      SELECT id, slot, content, created_at, updated_at, remind_at
        FROM leaf_notes
       ORDER BY slot ASC;
      ''');

    return rows.map(_fromRow).toList(growable: false);
  }

  @override
  LeafNote create({
    required int slot,
    required String content,
    required DateTime createdAt,
    DateTime? updatedAt,
    DateTime? remindAt,
  }) {
    _db.execute(
      '''
      INSERT INTO leaf_notes (slot, content, created_at, updated_at, remind_at)
      VALUES (?, ?, ?, ?, ?);
      ''',
      [
        slot,
        content,
        createdAt.millisecondsSinceEpoch,
        updatedAt?.millisecondsSinceEpoch,
        remindAt?.millisecondsSinceEpoch,
      ],
    );

    return LeafNote(
      id: _db.lastInsertRowId,
      slot: slot,
      content: content,
      createdAt: createdAt,
      updatedAt: updatedAt,
      remindAt: remindAt,
    );
  }

  @override
  void setReminder(int id, DateTime? at) {
    _db.execute('UPDATE leaf_notes SET remind_at = ? WHERE id = ?;', [
      at?.millisecondsSinceEpoch,
      id,
    ]);
  }

  @override
  void updateContent(int id, String content, {required DateTime at}) {
    _db.execute(
      'UPDATE leaf_notes SET content = ?, updated_at = ? WHERE id = ?;',
      [content, at.millisecondsSinceEpoch, id],
    );
  }

  /// Numera as vagas em duas passadas, e não em uma.
  ///
  /// A vaga é única no banco. Fechar o buraco de trás para a frente (`3` vira
  /// `2`, `4` vira `3`) até funcionaria em ordem crescente, mas qualquer outra
  /// ordem colidiria com uma vaga ainda ocupada. Mandar todo mundo para o
  /// negativo primeiro tira a ordem da conta: nenhum destino final está
  /// ocupado quando a segunda passada começa.
  @override
  void reassignSlots(List<int> idsInOrder) {
    final statement = _db.prepare(
      'UPDATE leaf_notes SET slot = ? WHERE id = ?;',
    );

    try {
      _db.execute('BEGIN IMMEDIATE;');

      for (var i = 0; i < idsInOrder.length; i++) {
        statement.execute([-(i + 1), idsInOrder[i]]);
      }
      for (var i = 0; i < idsInOrder.length; i++) {
        statement.execute([i + 1, idsInOrder[i]]);
      }

      _db.execute('COMMIT;');
    } catch (_) {
      _db.execute('ROLLBACK;');
      rethrow;
    } finally {
      statement.close();
    }
  }

  @override
  void delete(int id) =>
      _db.execute('DELETE FROM leaf_notes WHERE id = ?;', [id]);

  @override
  void clearAll() => _db.execute('DELETE FROM leaf_notes;');

  LeafNote _fromRow(Row row) {
    final updatedAt = row['updated_at'] as int?;
    final remindAt = row['remind_at'] as int?;

    return LeafNote(
      id: row['id'] as int,
      slot: row['slot'] as int,
      content: row['content'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      updatedAt: updatedAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(updatedAt),
      remindAt: remindAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(remindAt),
    );
  }
}
