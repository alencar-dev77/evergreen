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

  test('uma migração que falha de verdade não é engolida', () {
    database.execute('CREATE TABLE clipboard_items (wrong INTEGER);');

    expect(() => AppDatabase.migrate(database), throwsA(isA<SqliteException>()));
    // Transação: o banco não fica no meio do caminho.
    expect(versionOf(database), 0);
  });
}
