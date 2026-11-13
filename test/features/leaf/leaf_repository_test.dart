import 'package:evergreen/core/storage/app_database.dart';
import 'package:evergreen/features/leaf/data/leaf_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

/// Confere a parede direto no SQLite — o `FakeLeafRepository` imita este
/// comportamento nos testes de ViewModel, e é aqui que se verifica que a
/// imitação corresponde ao banco de verdade.
void main() {
  late Database database;
  late SqliteLeafRepository repository;

  final createdAt = DateTime(2026, 8, 4, 10);

  setUp(() {
    database = sqlite3.openInMemory();
    AppDatabase.migrate(database);
    repository = SqliteLeafRepository(database);
  });

  tearDown(() => database.close());

  test('carrega em ordem de vaga, não de inserção', () {
    repository.create(slot: 5, content: 'quinta', createdAt: createdAt);
    repository.create(slot: 1, content: 'primeira', createdAt: createdAt);
    repository.create(slot: 3, content: 'terceira', createdAt: createdAt);

    expect(repository.loadAll().map((note) => note.slot), [1, 3, 5]);
  });

  test('a vaga é única — duas anotações não disputam o mesmo ⌘N', () {
    repository.create(slot: 2, content: 'primeira', createdAt: createdAt);

    expect(
      () =>
          repository.create(slot: 2, content: 'segunda', createdAt: createdAt),
      throwsA(isA<SqliteException>()),
    );
  });

  test('apagar libera a vaga para ser reocupada', () {
    final note = repository.create(
      slot: 4,
      content: 'sai',
      createdAt: createdAt,
    );

    repository.delete(note.id);
    repository.create(slot: 4, content: 'entra', createdAt: createdAt);

    expect(repository.loadAll().single.content, 'entra');
  });

  test(
    'editar troca o texto e a data de edição, preservando vaga e criação',
    () {
      final note = repository.create(
        slot: 7,
        content: 'antes',
        createdAt: createdAt,
      );
      expect(note.updatedAt, isNull, reason: 'anotação nova não foi editada');

      final editedAt = createdAt.add(const Duration(days: 21));
      repository.updateContent(note.id, 'depois', at: editedAt);

      final stored = repository.loadAll().single;
      expect(stored.content, 'depois');
      expect(stored.slot, 7);
      expect(stored.createdAt, createdAt);
      expect(stored.updatedAt, editedAt);
      // É esta que o cartão mostra: a idade do recado, não a do papel.
      expect(stored.changedAt, editedAt);
    },
  );

  test('devolver uma anotação à parede preserva as duas datas', () {
    final editedAt = createdAt.add(const Duration(hours: 3));

    final restored = repository.create(
      slot: 1,
      content: 'voltou',
      createdAt: createdAt,
      updatedAt: editedAt,
    );

    expect(repository.loadAll().single.createdAt, createdAt);
    expect(repository.loadAll().single.updatedAt, editedAt);
    expect(restored.changedAt, editedAt);
  });

  test('trocar dois cartões de lugar não esbarra na unicidade da vaga', () {
    final a = repository.create(slot: 1, content: 'a', createdAt: createdAt);
    final b = repository.create(slot: 2, content: 'b', createdAt: createdAt);
    final c = repository.create(slot: 3, content: 'c', createdAt: createdAt);

    // A vaga 2 está ocupada quando a 1 tenta ir para ela.
    repository.assignSlots({a.id: 2, b.id: 1, c.id: 9});

    expect(repository.loadAll().map((note) => '${note.slot}:${note.content}'), [
      '1:b',
      '2:a',
      '9:c',
    ]);
  });

  test('esvaziar tira tudo da parede', () {
    repository.create(slot: 1, content: 'a', createdAt: createdAt);
    repository.create(slot: 2, content: 'b', createdAt: createdAt);

    repository.clearAll();

    expect(repository.loadAll(), isEmpty);
  });
}
