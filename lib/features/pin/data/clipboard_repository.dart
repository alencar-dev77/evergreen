import 'package:sqlite3/sqlite3.dart';

import '../models/clipboard_item.dart';
import '../models/clipboard_item_type.dart';
import '../models/pin_image.dart';

/// Contrato de persistência do histórico do Pin.
///
/// A ViewModel só conhece esta interface — trocar SQLite por outro motor no
/// futuro não toca nenhuma linha da camada de apresentação.
abstract interface class ClipboardRepository {
  /// Todos os itens: fixados primeiro, depois os mais recentes.
  List<ClipboardItem> loadAll({int limit});

  /// Quantos itens de cada tipo o histórico guarda hoje.
  ///
  /// Uma consulta agregada, e não `loadAll().length` por tipo: a tela de
  /// preferências quer o número, não os quinhentos itens — e ler o conteúdo
  /// para contar seria trazer senha para a memória do Hub sem precisar.
  Map<ClipboardItemType, int> countByType();

  /// Registra um conteúdo capturado.
  ///
  /// Se o conteúdo já existir, apenas atualiza o `copiedAt` (o item sobe para o
  /// topo) preservando o estado de fixado. Retorna o item persistido.
  ClipboardItem upsert(ClipboardItem item);

  void setPinned(int id, {required bool isPinned});

  /// Dá (ou tira) o apelido de um item. Texto em branco apaga o apelido.
  void setAlias(int id, String? alias);

  /// Troca de lugar dois itens fixados na ordem dos fixados.
  ///
  /// Ignora o pedido se algum dos dois não existir ou não estiver fixado — só
  /// os fixados têm ordem própria para trocar.
  void swapPinnedOrder(int firstId, int secondId);

  void delete(int id);

  /// Reclassifica os itens guardados por uma versão anterior do classificador
  /// e devolve quantos mudaram de tipo.
  ///
  /// Roda uma vez por atualização do classificador (ver
  /// [ClipboardItemClassifier.version]) e não faz nada nas aberturas seguintes.
  int reclassifyOutdated();

  /// Remove os itens não fixados mais antigos que excedam [maxItems].
  void trimHistory(int maxItems);

  /// Os arquivos de imagem que alguma linha ainda quer — o que a varredura da
  /// pasta de imagens não pode apagar. Ver `PinImageJanitor`.
  Set<String> imageFiles();

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
      SELECT id, content, type, is_pinned, copied_at, pinned_at, alias, image
        FROM clipboard_items
       ORDER BY is_pinned DESC, pinned_at ASC, copied_at DESC
       LIMIT ?;
      ''',
      [limit],
    );

    return rows.map(_fromRow).toList(growable: false);
  }

  @override
  Map<ClipboardItemType, int> countByType() {
    final rows = _db.select(
      'SELECT type, COUNT(*) AS total FROM clipboard_items GROUP BY type;',
    );

    return {
      for (final type in ClipboardItemType.values)
        type: rows
                .where((row) => row['type'] == type.name)
                .map((row) => row['total'] as int)
                .firstOrNull ??
            0,
    };
  }

  @override
  ClipboardItem upsert(ClipboardItem item) {
    final timestamp = item.copiedAt.millisecondsSinceEpoch;

    _db.execute(
      '''
      INSERT INTO clipboard_items
             (content, type, is_pinned, copied_at, classifier_version, image)
      VALUES (?, ?, ?, ?, ?, ?)
      ON CONFLICT(content) DO UPDATE SET
        copied_at = excluded.copied_at,
        -- A mesma imagem copiada de outro lugar: vale a origem mais recente.
        -- Vinda primeiro do navegador e depois do Finder, ela ganha o nome e
        -- o caminho — e passa a ser achada por eles.
        image = COALESCE(excluded.image, image);
      ''',
      [
        item.content,
        item.type.name,
        item.isPinned ? 1 : 0,
        timestamp,
        ClipboardItemClassifier.version,
        item.image?.toJson(),
      ],
    );

    final row = _db.select(
      'SELECT id, content, type, is_pinned, copied_at, pinned_at, alias, image FROM clipboard_items WHERE content = ?;',
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
  void setAlias(int id, String? alias) {
    final trimmed = alias?.trim();

    _db.execute(
      'UPDATE clipboard_items SET alias = ? WHERE id = ?;',
      // Apelido em branco é ausência de apelido: guardar `''` faria a coluna
      // ter dois jeitos de dizer a mesma coisa.
      [trimmed == null || trimmed.isEmpty ? null : trimmed, id],
    );
  }

  @override
  void swapPinnedOrder(int firstId, int secondId) {
    final rows = _db.select(
      '''
      SELECT id, pinned_at, copied_at
        FROM clipboard_items
       WHERE id IN (?, ?) AND is_pinned = 1;
      ''',
      [firstId, secondId],
    );
    if (rows.length != 2) return;

    final order = {
      for (final row in rows)
        row['id'] as int: (row['pinned_at'] as int?) ?? row['copied_at'] as int,
    };

    final first = order[firstId]!;
    // Dois fixados no mesmo milissegundo não têm ordem entre si para trocar:
    // a troca escreveria o mesmo valor nos dois e nada se moveria. Separá-los
    // aqui é o que garante que o ⌥↑/⌥↓ sempre resulte em movimento.
    final second = order[secondId] == first ? first + 1 : order[secondId]!;

    // Uma única instrução: a troca não pode ficar pela metade se o processo
    // morrer no meio dela.
    _db.execute(
      '''
      UPDATE clipboard_items
         SET pinned_at = CASE id WHEN ? THEN ? ELSE ? END
       WHERE id IN (?, ?);
      ''',
      [firstId, second, first, firstId, secondId],
    );
  }

  @override
  void delete(int id) {
    _db.execute('DELETE FROM clipboard_items WHERE id = ?;', [id]);
  }

  @override
  int reclassifyOutdated() {
    final rows = _db.select(
      '''
      SELECT id, content, type
        FROM clipboard_items
       WHERE classifier_version < ? AND image IS NULL;
      ''',
      [ClipboardItemClassifier.version],
    );
    if (rows.isEmpty) return 0;

    var changed = 0;

    // Uma transação só para o histórico inteiro: são até 500 linhas, e meia
    // reclassificação deixaria o filtro respondendo diferente conforme o item.
    _db.execute('BEGIN;');
    try {
      final update = _db.prepare(
        'UPDATE clipboard_items SET type = ?, classifier_version = ? WHERE id = ?;',
      );

      try {
        for (final row in rows) {
          final type = ClipboardItemClassifier.classify(
            row['content'] as String,
          );
          if (type.name != row['type'] as String) changed++;

          update.execute([
            type.name,
            ClipboardItemClassifier.version,
            row['id'] as int,
          ]);
        }
      } finally {
        update.close();
      }

      _db.execute('COMMIT;');
    } catch (_) {
      _db.execute('ROLLBACK;');
      rethrow;
    }

    return changed;
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
  Set<String> imageFiles() {
    final rows = _db.select(
      'SELECT image FROM clipboard_items WHERE image IS NOT NULL;',
    );

    return {
      for (final row in rows)
        ?PinImage.fromJson(row['image'] as String?)?.fileName,
    };
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
      alias: row['alias'] as String?,
      image: PinImage.fromJson(row['image'] as String?),
    );
  }
}
