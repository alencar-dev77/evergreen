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
    DateTime? remindAt,
    bool isHidden = false,
  }) {
    final note = LeafNote(
      id: _nextId++,
      slot: slot,
      content: content,
      createdAt: createdAt,
      updatedAt: updatedAt,
      remindAt: remindAt,
      isHidden: isHidden,
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
  void setHidden(int id, {required bool hidden}) {
    final index = _notes.indexWhere((note) => note.id == id);
    if (index < 0) return;

    _notes[index] = _notes[index].copyWith(isHidden: hidden);
  }

  @override
  void setReminder(int id, DateTime? at) {
    final index = _notes.indexWhere((note) => note.id == id);
    if (index < 0) return;

    _notes[index] = _notes[index].copyWith(
      remindAt: at,
      clearReminder: at == null,
    );
  }

  @override
  void assignSlots(Map<int, int> slotById) {
    for (final MapEntry(key: id, value: slot) in slotById.entries) {
      final index = _notes.indexWhere((note) => note.id == id);
      if (index < 0) continue;

      _notes[index] = _notes[index].copyWith(slot: slot);
    }
  }

  @override
  void delete(int id) => _notes.removeWhere((note) => note.id == id);

  @override
  void clearAll() => _notes.clear();
}
