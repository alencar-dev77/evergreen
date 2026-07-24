import 'package:sqlite3/sqlite3.dart';

import '../models/clipboard_item.dart';
import '../models/clipboard_item_type.dart';

/// Contrato de persistência do histórico do Pin.
///
/// A ViewModel só conhece esta interface — trocar SQLite por outro motor no
/// futuro não toca nenhuma linha da camada de apresentação.
abstract interface class ClipboardRepository {
  /// Todos os itens: fixados primeiro, depois os mais recentes.
  List<ClipboardItem> loadAll({int limit});

  /// Registra um conteúdo capturado.
  ///
  /// Se o conteúdo já existir, apenas atualiza o `copiedAt` (o item sobe para o
  /// topo) preservando o estado de fixado. Retorna o item persistido.
  ClipboardItem upsert(ClipboardItem item);

  void setPinned(int id, {required bool isPinned});

  void delete(int id);

  /// Remove os itens não fixados mais antigos que excedam [maxItems].
  void trimHistory(int maxItems);

  void clearAll();
}

/// Implementação sobre SQLite. Todas as consultas são preparadas na abertura,
/// mantendo a leitura do histórico praticamente instantânea.
class SqliteClipboardRepository implements ClipboardRepository {
  SqliteClipboardRepository(this._db);

  final Database _db;

  @override
  List<ClipboardItem> loadAll({int limit = 500}) {
    final rows = _db.select(
      '''
      SELECT id, content, type, is_pinned, copied_at, pinned_at
        FROM clipboard_items
       ORDER BY is_pinned DESC, pinned_at ASC, copied_at DESC
       LIMIT ?;
      ''',
      [limit],
    );

    return rows.map(_fromRow).toList(growable: false);
  }

  @override
  ClipboardItem upsert(ClipboardItem item) {
    final timestamp = item.copiedAt.millisecondsSinceEpoch;

    _db.execute(
      '''
      INSERT INTO clipboard_items (content, type, is_pinned, copied_at)
      VALUES (?, ?, ?, ?)
      ON CONFLICT(content) DO UPDATE SET copied_at = excluded.copied_at;
      ''',
      [item.content, item.type.name, item.isPinned ? 1 : 0, timestamp],
    );

    final row = _db.select(
      'SELECT id, content, type, is_pinned, copied_at, pinned_at FROM clipboard_items WHERE content = ?;',
      [item.content],
    ).first;

    return _fromRow(row);
  }

  @override
  void setPinned(int id, {required bool isPinned}) {
    _db.execute(
      'UPDATE clipboard_items SET is_pinned = ?, pinned_at = ? WHERE id = ?;',
      [
        isPinned ? 1 : 0,
        isPinned ? DateTime.now().millisecondsSinceEpoch : null,
        id,
      ],
    );
  }

  @override
  void delete(int id) {
    _db.execute('DELETE FROM clipboard_items WHERE id = ?;', [id]);
  }

  @override
  void trimHistory(int maxItems) {
    _db.execute(
      '''
      DELETE FROM clipboard_items
       WHERE is_pinned = 0
         AND id NOT IN (
               SELECT id FROM clipboard_items
                WHERE is_pinned = 0
                ORDER BY copied_at DESC
                LIMIT ?
             );
      ''',
      [maxItems],
    );
  }

  @override
  void clearAll() {
    _db.execute('DELETE FROM clipboard_items WHERE is_pinned = 0;');
  }

  ClipboardItem _fromRow(Row row) {
    final pinnedAt = row['pinned_at'] as int?;

    return ClipboardItem(
      id: row['id'] as int,
      content: row['content'] as String,
      type: ClipboardItemType.fromName(row['type'] as String),
      isPinned: (row['is_pinned'] as int) == 1,
      copiedAt: DateTime.fromMillisecondsSinceEpoch(row['copied_at'] as int),
      pinnedAt: pinnedAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(pinnedAt),
    );
  }
}
