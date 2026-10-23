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
  ///
  /// Sem teto próprio: quem limita o histórico é o [trimHistory], e só sobre
  /// os não fixados. Um `LIMIT` aqui contava os fixados junto, e com o teto
  /// de 500 e alguns fixados os itens mais recentes sumiam da lista — estavam
  /// no banco, mas o painel não os lia.
  List<ClipboardItem> loadAll();

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

  /// A ordem da lista, num lugar só: o [swapPinnedOrder] precisa ler os
  /// fixados exatamente como o painel os mostra. O `id` no fim desempata o
  /// que sobra — sem ele, dois itens iguais em tudo podiam trocar de lugar
  /// entre uma leitura e outra.
  static const _order =
      'is_pinned DESC, pinned_at ASC, copied_at DESC, id DESC';

  @override
  List<ClipboardItem> loadAll() {
    final rows = _db.select('''
      SELECT id, content, type, is_pinned, copied_at, pinned_at, alias, image
        FROM clipboard_items
       ORDER BY $_order;
      ''');

    return rows.map(_fromRow).toList(growable: false);
  }

  @override
  Map<ClipboardItemType, int> countByType() {
    final rows = _db.select(
      'SELECT type, COUNT(*) AS total FROM clipboard_items GROUP BY type;',
    );

    return {
      for (final type in ClipboardItemType.values)
        type:
            rows
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
    // Uma transação só, e aberta antes da leitura: a troca não pode ficar pela
    // metade se o processo morrer no meio dela, e o Hub — a outra conexão —
    // não pode desafixar um item entre ler a ordem e gravá-la.
    _db.execute('BEGIN IMMEDIATE;');
    try {
      _swapPinnedOrder(firstId, secondId);
      _db.execute('COMMIT;');
    } catch (_) {
      _db.execute('ROLLBACK;');
      rethrow;
    }
  }

  void _swapPinnedOrder(int firstId, int secondId) {
    final rows = _db.select('''
      SELECT id, pinned_at
        FROM clipboard_items
       WHERE is_pinned = 1
       ORDER BY $_order;
      ''');

    final ids = [for (final row in rows) row['id'] as int];
    final firstIndex = ids.indexOf(firstId);
    final secondIndex = ids.indexOf(secondId);
    if (firstIndex < 0 || secondIndex < 0 || firstIndex == secondIndex) return;

    // Antes de trocar, cada fixado ganha um carimbo só dele, crescente na
    // ordem em que aparece. Trocar os dois valores não move nada quando eles
    // empatam (dois `setPinned` no mesmo milissegundo, ou um fixado antigo
    // sem `pinned_at`), e separar o empate com um `+1` só acertava quando o
    // desempate por data de cópia — que é quem ordena o empate — concordava
    // por acaso com a soma; nos outros casos o ⌥↑ não saía do lugar. O
    // carimbo de quem já estava em ordem fica como está: só o empate é
    // empurrado.
    final stamps = <int>[];
    for (final row in rows) {
      final previous = stamps.lastOrNull;
      var stamp = (row['pinned_at'] as int?) ?? previous ?? 0;
      if (previous != null && stamp <= previous) stamp = previous + 1;
      stamps.add(stamp);
    }

    final swapped = [...stamps];
    swapped[firstIndex] = stamps[secondIndex];
    swapped[secondIndex] = stamps[firstIndex];

    final update = _db.prepare(
      'UPDATE clipboard_items SET pinned_at = ? WHERE id = ?;',
    );
    try {
      for (var i = 0; i < ids.length; i++) {
        if (swapped[i] == rows[i]['pinned_at']) continue;
        update.execute([swapped[i], ids[i]]);
      }
    } finally {
      update.close();
    }
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
