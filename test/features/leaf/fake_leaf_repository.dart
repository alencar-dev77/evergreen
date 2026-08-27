import 'package:evergreen/features/leaf/data/leaf_repository.dart';
import 'package:evergreen/features/leaf/models/leaf_note.dart';

/// Parede em memória, com a mesma ordenação por vaga do SQLite.
class FakeLeafRepository implements LeafRepository {
  FakeLeafRepository([List<LeafNote> initial = const []])
      : _notes = [...initial];

  final List<LeafNote> _notes;

  int _nextId = 1000;

  @override
  List<LeafNote> loadAll() {
    final sorted = [..._notes]..sort((a, b) => a.slot.compareTo(b.slot));
    return sorted;
  }

  @override
  LeafNote create({
    required int slot,
    required String content,
    required DateTime createdAt,
    DateTime? updatedAt,
  }) {
    final note = LeafNote(
      id: _nextId++,
      slot: slot,
      content: content,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );

    _notes.add(note);
    return note;
  }

  @override
  void updateContent(int id, String content, {required DateTime at}) {
    final index = _notes.indexWhere((note) => note.id == id);
    if (index < 0) return;

    _notes[index] = _notes[index].copyWith(content: content, updatedAt: at);
  }

  @override
  void reassignSlots(List<int> idsInOrder) {
    for (var i = 0; i < idsInOrder.length; i++) {
      final index = _notes.indexWhere((note) => note.id == idsInOrder[i]);
      if (index < 0) continue;

      _notes[index] = _notes[index].copyWith(slot: i + 1);
    }
  }

  @override
  void delete(int id) => _notes.removeWhere((note) => note.id == id);

  @override
  void clearAll() => _notes.clear();
}
