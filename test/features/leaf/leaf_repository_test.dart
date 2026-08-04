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

    expect(
      repository.loadAll().map((note) => note.slot),
      [1, 3, 5],
    );
  });

  test('a vaga é única — duas anotações não disputam o mesmo ⌘N', () {
    repository.create(slot: 2, content: 'primeira', createdAt: createdAt);

    expect(
      () => repository.create(slot: 2, content: 'segunda', createdAt: createdAt),
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

  test('editar troca só o texto, preservando vaga e data', () {
    final note = repository.create(
      slot: 7,
      content: 'antes',
      createdAt: createdAt,
    );

    repository.updateContent(note.id, 'depois');

    final stored = repository.loadAll().single;
    expect(stored.content, 'depois');
    expect(stored.slot, 7);
    expect(stored.createdAt, createdAt);
  });

  test('reassentar fecha o buraco sem esbarrar na unicidade da vaga', () {
    repository.create(slot: 1, content: 'a', createdAt: createdAt);
    final b = repository.create(slot: 2, content: 'b', createdAt: createdAt);
    final c = repository.create(slot: 3, content: 'c', createdAt: createdAt);
    final d = repository.create(slot: 4, content: 'd', createdAt: createdAt);

    // Apagou a primeira: as três restantes descem uma vaga cada, e a vaga 2
    // ainda está ocupada quando a 3 tenta virar 2.
    repository.delete(repository.loadAll().first.id);
    repository.reassignSlots([b.id, c.id, d.id]);

    expect(
      repository.loadAll().map((note) => '${note.slot}:${note.content}'),
      ['1:b', '2:c', '3:d'],
    );
  });

  test('esvaziar tira tudo da parede', () {
    repository.create(slot: 1, content: 'a', createdAt: createdAt);
    repository.create(slot: 2, content: 'b', createdAt: createdAt);

    repository.clearAll();

    expect(repository.loadAll(), isEmpty);
  });
}
