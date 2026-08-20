import 'package:evergreen/features/pin/data/clipboard_repository.dart';
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

  /// Reproduz o `ORDER BY is_pinned DESC, pinned_at ASC, copied_at DESC` do
  /// SQLite: fixados primeiro na ordem em que foram fixados, depois os recentes
  /// do mais novo para o mais antigo.
  @override
  List<ClipboardItem> loadAll({int limit = 500}) {
    final sorted = [..._items]..sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;

        if (a.isPinned) {
          final aPinned = a.pinnedAt;
          final bPinned = b.pinnedAt;
          if (aPinned != null && bPinned != null) {
            return aPinned.compareTo(bPinned);
          }
        }

        return b.copiedAt.compareTo(a.copiedAt);
      });

    return sorted.take(limit).toList(growable: false);
  }

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
    final first = _items.indexWhere((it) => it.id == firstId);
    final second = _items.indexWhere((it) => it.id == secondId);
    if (first < 0 || second < 0) return;
    if (!_items[first].isPinned || !_items[second].isPinned) return;

    final firstAt = _items[first].pinnedAt ?? _items[first].copiedAt;
    final secondAt = _items[second].pinnedAt ?? _items[second].copiedAt;

    _items[first] = _items[first].copyWith(pinnedAt: secondAt);
    _items[second] = _items[second].copyWith(pinnedAt: firstAt);
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
  void clearAll() => _items.removeWhere((it) => !it.isPinned);
}
