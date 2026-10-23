import 'package:evergreen/features/pin/data/clipboard_repository.dart';
import 'package:evergreen/features/pin/models/clipboard_item_type.dart';
import 'package:evergreen/features/pin/models/clipboard_item.dart';

/// Repositório em memória, com a mesma ordenação do SQLite (fixados primeiro,
/// depois por data de cópia decrescente).
class FakeClipboardRepository implements ClipboardRepository {
  FakeClipboardRepository([List<ClipboardItem> initial = const []])
    : _items = [...initial];

  final List<ClipboardItem> _items;

  int _nextId = 1000;

  /// Quantas vezes a reclassificação foi pedida.
  int reclassifyCalls = 0;

  /// Reproduz o `ORDER BY is_pinned DESC, pinned_at ASC, copied_at DESC,
  /// id DESC` do SQLite: fixados primeiro na ordem em que foram fixados (o
  /// sem carimbo antes de todos, como o NULL de lá), depois os recentes do
  /// mais novo para o mais antigo.
  @override
  List<ClipboardItem> loadAll() {
    final sorted = [..._items]..sort(_compare);

    return sorted.toList(growable: false);
  }

  @override
  Map<ClipboardItemType, int> countByType() => {
    for (final type in ClipboardItemType.values)
      type: _items.where((item) => item.type == type).length,
  };

  @override
  ClipboardItem upsert(ClipboardItem item) {
    final index = _items.indexWhere((it) => it.content == item.content);

    if (index >= 0) {
      final updated = _items[index].copyWith(copiedAt: item.copiedAt);
      _items[index] = updated;
      return updated;
    }

    final created = item.copyWith(id: _nextId++);
    _items.add(created);
    return created;
  }

  @override
  void setPinned(int id, {required bool isPinned}) {
    final index = _items.indexWhere((it) => it.id == id);
    if (index < 0) return;

    final current = _items[index];
    _items[index] = ClipboardItem(
      id: current.id,
      content: current.content,
      type: current.type,
      isPinned: isPinned,
      copiedAt: current.copiedAt,
      pinnedAt: isPinned ? DateTime.now() : null,
      alias: current.alias,
    );
  }

  @override
  void setAlias(int id, String? alias) {
    final index = _items.indexWhere((it) => it.id == id);
    if (index < 0) return;

    final trimmed = alias?.trim() ?? '';
    final current = _items[index];

    _items[index] = ClipboardItem(
      id: current.id,
      content: current.content,
      type: current.type,
      isPinned: current.isPinned,
      copiedAt: current.copiedAt,
      pinnedAt: current.pinnedAt,
      alias: trimmed.isEmpty ? null : trimmed,
    );
  }

  @override
  void swapPinnedOrder(int firstId, int secondId) {
    // A mesma conta do SQLite: carimbos crescentes na ordem de agora, e só
    // então a troca — senão um empate não sairia do lugar aqui e sairia lá.
    final pinned = _items.where((it) => it.isPinned).toList()..sort(_compare);
    final ids = [for (final item in pinned) item.id];
    final first = ids.indexOf(firstId);
    final second = ids.indexOf(secondId);
    if (first < 0 || second < 0 || first == second) return;

    final stamps = <DateTime>[];
    for (final item in pinned) {
      final previous = stamps.lastOrNull;
      var stamp =
          item.pinnedAt ?? previous ?? DateTime.fromMillisecondsSinceEpoch(0);
      if (previous != null && !stamp.isAfter(previous)) {
        stamp = previous.add(const Duration(milliseconds: 1));
      }
      stamps.add(stamp);
    }

    final swapped = [...stamps];
    swapped[first] = stamps[second];
    swapped[second] = stamps[first];

    for (var i = 0; i < pinned.length; i++) {
      final index = _items.indexWhere((it) => it.id == ids[i]);
      _items[index] = _items[index].copyWith(pinnedAt: swapped[i]);
    }
  }

  static int _compare(ClipboardItem a, ClipboardItem b) {
    if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;

    if (a.isPinned) {
      final aPinned = a.pinnedAt;
      final bPinned = b.pinnedAt;
      if (aPinned == null && bPinned != null) return -1;
      if (aPinned != null && bPinned == null) return 1;
      if (aPinned != null && bPinned != null && aPinned != bPinned) {
        return aPinned.compareTo(bPinned);
      }
    }

    final copied = b.copiedAt.compareTo(a.copiedAt);
    if (copied != 0) return copied;
    return (b.id ?? 0).compareTo(a.id ?? 0);
  }

  @override
  void delete(int id) => _items.removeWhere((it) => it.id == id);

  /// O fake nasce com os itens já classificados pelo teste, então não há o que
  /// reclassificar — o contador conta quantas vezes foi chamado, que é o que os
  /// testes verificam.
  @override
  int reclassifyOutdated() {
    reclassifyCalls++;
    return 0;
  }

  @override
  void trimHistory(int maxItems) {
    final unpinned = _items.where((it) => !it.isPinned).toList()
      ..sort((a, b) => b.copiedAt.compareTo(a.copiedAt));

    for (final item in unpinned.skip(maxItems)) {
      _items.remove(item);
    }
  }

  @override
  Set<String> imageFiles() => {
    for (final item in _items) ?item.image?.fileName,
  };

  @override
  void clearAll() => _items.removeWhere((it) => !it.isPinned);
}
