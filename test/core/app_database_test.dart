import 'package:evergreen/core/storage/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Database database;

  setUp(() => database = sqlite3.openInMemory());
  tearDown(() => database.close());

  int versionOf(Database database) =>
      database.select('PRAGMA user_version;').first.values.first as int;

  List<String> columnsOf(Database database, String table) => database
      .select('PRAGMA table_info($table);')
      .map((row) => row['name'] as String)
      .toList();

  test('migra um banco vazio e marca a versão', () {
    AppDatabase.migrate(database);

    expect(versionOf(database), greaterThan(0));
    expect(columnsOf(database, 'clipboard_items'), contains('pinned_at'));
    expect(columnsOf(database, 'focus_sessions'), contains('notes'));
  });

  test('migrar de novo não faz nada', () {
    AppDatabase.migrate(database);
    final version = versionOf(database);

    AppDatabase.migrate(database);

    expect(versionOf(database), version);
  });

  test('um banco com a versão rebobinada se conserta sozinho', () {
    AppDatabase.migrate(database);
    final version = versionOf(database);

    // É o que um binário antigo fazia: escrever a própria contagem de migrações
    // por cima de um banco já mais novo. A migração seguinte tentava criar uma
    // coluna que já existia e o app não abria mais.
    database.execute('PRAGMA user_version = ${version - 1};');

    expect(() => AppDatabase.migrate(database), returnsNormally);
    expect(versionOf(database), version);
    expect(columnsOf(database, 'focus_sessions'), contains('notes'));
  });

  test('versão maior que a conhecida não é rebobinada', () {
    AppDatabase.migrate(database);
    final version = versionOf(database);

    // Um binário antigo abrindo um banco migrado por um mais novo: ele não
    // entende as migrações futuras, mas não pode apagar o registro delas.
    database.execute('PRAGMA user_version = ${version + 5};');
    AppDatabase.migrate(database);

    expect(versionOf(database), version + 5);
  });

  List<String> appliedIn(Database database) => database
      .select('SELECT id FROM schema_migrations ORDER BY id;')
      .map((row) => row['id'] as String)
      .toList();

  test('um banco antigo é convertido sem reaplicar o que já rodou', () {
    // O estado de quem vinha da contagem: schema completo, nenhum registro.
    AppDatabase.migrate(database);
    final ids = appliedIn(database);
    database.execute('DROP TABLE schema_migrations;');
    database.execute('INSERT INTO clipboard_items (content, type, is_pinned, '
        'copied_at, pinned_at) VALUES (?, ?, 1, 10, 99);', ['pix', 'text']);

    AppDatabase.migrate(database);

    expect(appliedIn(database), ids);
    // Reaplicar a migração da ordem dos fixados teria jogado `pinned_at` de
    // volta para `copied_at` — é o dado que o registro protege.
    expect(
      database.select('SELECT pinned_at FROM clipboard_items;').first.values.first,
      99,
    );
  });

  test('migração de outra branch não é pulada por ocupar a mesma posição', () {
    AppDatabase.migrate(database);

    // Uma branch paralela chegou antes, criou a própria tabela e deixou a
    // contagem no mesmo número que esta lista de migrações produz. Pelo número
    // não haveria nada pendente; pela chave, a última daqui nunca rodou.
    database.execute('DELETE FROM schema_migrations WHERE id = ?;',
        ['clipboard-alias']);
    database.execute('ALTER TABLE clipboard_items DROP COLUMN alias;');

    AppDatabase.migrate(database);

    expect(columnsOf(database, 'clipboard_items'), contains('alias'));
  });

  test('uma migração que falha de verdade não é engolida', () {
    database.execute('CREATE TABLE clipboard_items (wrong INTEGER);');

    expect(() => AppDatabase.migrate(database), throwsA(isA<SqliteException>()));
    // Transação: o banco não fica no meio do caminho.
    expect(versionOf(database), 0);
  });
}
