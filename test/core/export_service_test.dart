import 'dart:convert';
import 'dart:io';

import 'package:evergreen/core/storage/app_database.dart';
import 'package:evergreen/core/storage/export_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

/// A exportação em JSON.
///
/// O que estes testes prendem é o que a issue #19 pedia: que dê para tirar o
/// dado de dentro do Evergreen sem depender do Evergreen para lê-lo de volta —
/// e que a exportação não precise ser lembrada a cada módulo novo.
void main() {
  late Database db;
  late Directory root;
  late ExportService service;

  setUp(() {
    db = sqlite3.openInMemory();
    AppDatabase.migrate(db);

    root = Directory.systemTemp.createTempSync('evergreen-export-test');
    service = ExportService(
      database: db,
      directory: Directory('${root.path}/Exports'),
    );
  });

  tearDown(() {
    db.close();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  void insertItem(String content, {String? alias, int copiedAt = 1}) {
    db.execute(
      'INSERT INTO clipboard_items (content, type, is_pinned, copied_at, alias) '
      "VALUES (?, 'text', 0, ?, ?);",
      [content, copiedAt, alias],
    );
  }

  Map<String, Object?> readExport(File file) =>
      jsonDecode(file.readAsStringSync()) as Map<String, Object?>;

  Map<String, Object?> tablesOf(File file) =>
      readExport(file)['tables']! as Map<String, Object?>;

  test('escreve um JSON com o conteúdo do momento', () {
    insertItem('primeiro', alias: 'chave pix');

    final file = service.create(at: DateTime(2026, 8, 26, 14, 32));

    expect(file.existsSync(), isTrue);
    expect(file.path, endsWith('evergreen-2026-08-26-1432.json'));

    final items = tablesOf(file)['clipboard_items']! as List<Object?>;
    final first = items.single as Map<String, Object?>;

    expect(first['content'], 'primeiro');
    expect(first['alias'], 'chave pix');
  });

  test('o arquivo se identifica para quem for lê-lo depois', () {
    final export = readExport(service.create(appVersion: '0.5.0'));

    expect(export['app'], 'Evergreen');
    expect(export['appVersion'], '0.5.0');
    expect(export['formatVersion'], ExportService.formatVersion);
    expect(export['exportedAt'], isA<String>());
  });

  test('a versão do aplicativo é opcional, não obrigatória', () {
    // Antes do `AppInfo.load` a versão é vazia, e um arquivo sem ela é melhor
    // que um com `"appVersion": ""`.
    expect(readExport(service.create()).containsKey('appVersion'), isFalse);
  });

  test('descobre as tabelas sozinho — módulo novo entra de graça', () {
    db.execute('CREATE TABLE modulo_futuro (id INTEGER PRIMARY KEY, x TEXT);');
    db.execute("INSERT INTO modulo_futuro (x) VALUES ('veio junto');");

    final tables = tablesOf(service.create());

    expect(tables.keys, contains('modulo_futuro'));
    expect(
      (tables['modulo_futuro']! as List<Object?>).single,
      containsPair('x', 'veio junto'),
    );
  });

  test('o registro de migrações fica de fora', () {
    // Ele é do banco que está rodando, e não diz nada a quem abre o arquivo.
    expect(tablesOf(service.create()).keys, isNot(contains('schema_migrations')));
  });

  test('tabela vazia aparece vazia, não some', () {
    final tables = tablesOf(service.create());

    expect(tables.keys, contains('clipboard_items'));
    expect(tables['clipboard_items'], isEmpty);
  });

  test('binário sai em base64 em vez de derrubar o arquivo', () {
    db.execute('CREATE TABLE com_blob (id INTEGER PRIMARY KEY, dado BLOB);');
    db.execute('INSERT INTO com_blob (dado) VALUES (?);', [
      [1, 2, 3],
    ]);

    final linha = (tablesOf(service.create())['com_blob']! as List<Object?>)
        .single as Map<String, Object?>;

    expect(base64Decode(linha['dado']! as String), [1, 2, 3]);
  });

  test('duas exportações no mesmo minuto não se sobrescrevem', () {
    final at = DateTime(2026, 8, 26, 14, 32);

    final primeira = service.create(at: at);
    final segunda = service.create(at: at);

    expect(primeira.path, isNot(segunda.path));
    expect(primeira.existsSync(), isTrue);
    expect(segunda.existsSync(), isTrue);
  });
}
