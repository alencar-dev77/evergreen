import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

/// Leva os dados do Evergreen para fora dele, em JSON.
///
/// O backup (`BackupService`) já protege contra perda, mas só o Evergreen sabe
/// ler um `.db` dele. Isto aqui é a outra metade: um arquivo que **outra
/// ferramenta** consegue abrir — o histórico do Focus numa planilha, as
/// anotações do Leaf num editor, os fixados do Pin onde a pessoa quiser.
///
/// JSON e não CSV: o dado do Evergreen tem lista dentro de linha (os turnos de
/// uma reunião, as notas de uma sessão), e achatar isso em colunas perderia
/// justamente o que vale a pena levar.
///
/// **As tabelas são descobertas pelo `sqlite_master`**, exatamente como no
/// backup: a tabela de um módulo novo entra na exportação sozinha, sem ninguém
/// precisar vir aqui. Fora fica só `schema_migrations`, que é do banco que está
/// rodando e não diz nada a quem lê o arquivo.
///
/// O arquivo sai na pasta do aplicativo, ao lado dos backups, e não por um
/// diálogo de "salvar como": é a mesma razão que pôs o backup ali — a pasta do
/// aplicativo não pede permissão ao macOS, e a pasta **é** a interface (o botão
/// "Mostrar no Finder" leva até ela).
class ExportService {
  ExportService({required Database database, required Directory directory})
      : _db = database,
        _directory = directory;

  final Database _db;
  final Directory _directory;

  static const _prefix = 'evergreen-';
  static const _extension = '.json';

  /// Versão do formato do arquivo.
  ///
  /// Escrita no próprio arquivo para que quem o leia daqui a um ano saiba com o
  /// que está lidando — inclusive nós, se um dia houver importação.
  static const formatVersion = 1;

  Directory get directory => _directory;

  /// O caminho da pasta como se escreve para uma pessoa (`~/Library/…`).
  String get directoryLabel {
    final home = Platform.environment['HOME'];
    if (home == null || home.isEmpty) return _directory.path;

    return _directory.path.startsWith(home)
        ? '~${_directory.path.substring(home.length)}'
        : _directory.path;
  }

  /// Escreve a exportação e devolve o arquivo criado.
  File create({DateTime? at, String? appVersion}) {
    _directory.createSync(recursive: true);

    final moment = at ?? DateTime.now();
    final file = _freeNameFor(moment);

    final payload = <String, Object?>{
      'app': 'Evergreen',
      'appVersion': ?appVersion,
      'formatVersion': formatVersion,
      'exportedAt': moment.toIso8601String(),
      'tables': {
        for (final table in _exportableTables()) table: _rowsOf(table),
      },
    };

    // Indentado: o arquivo existe para ser aberto por uma pessoa ou por uma
    // ferramenta, e nos dois casos o que se perde em bytes se ganha em poder
    // ler o que saiu sem passar por um formatador antes.
    file.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(payload),
    );

    return file;
  }

  /// Abre a pasta no Finder.
  ///
  /// `open` do próprio macOS, como no backup: o Evergreen não roda em sandbox.
  Future<void> reveal() async {
    _directory.createSync(recursive: true);
    await Process.run('open', [_directory.path]);
  }

  /// As tabelas do banco, menos o registro de migrações.
  List<String> _exportableTables() => _db
      .select(
        '''
        SELECT name FROM sqlite_master
         WHERE type = 'table'
           AND name NOT LIKE 'sqlite_%'
           AND name <> 'schema_migrations'
         ORDER BY name;
        ''',
      )
      .map((row) => row['name'] as String)
      .toList();

  /// As linhas de uma tabela, na ordem do banco.
  List<Map<String, Object?>> _rowsOf(String table) {
    return _db
        .select('SELECT * FROM "$table";')
        .map(
          (row) => <String, Object?>{
            for (final column in row.keys) column: _jsonValue(row[column]),
          },
        )
        .toList();
  }

  /// O valor como o JSON aceita.
  ///
  /// Só o BLOB precisa de tradução — os outros tipos do SQLite (inteiro, real,
  /// texto e nulo) já são tipos de JSON. Hoje nenhuma tabela guarda binário,
  /// mas a exportação descobre as tabelas sozinha: a primeira que guardar não
  /// pode derrubar o arquivo inteiro por causa de uma coluna.
  static Object? _jsonValue(Object? value) {
    if (value is Uint8List) return base64Encode(value);

    return value;
  }

  /// `evergreen-2026-08-26-1432.json`, com sufixo se o minuto já tiver um.
  File _freeNameFor(DateTime at) {
    final stamp = '${at.year.toString().padLeft(4, '0')}-'
        '${at.month.toString().padLeft(2, '0')}-'
        '${at.day.toString().padLeft(2, '0')}-'
        '${at.hour.toString().padLeft(2, '0')}'
        '${at.minute.toString().padLeft(2, '0')}';

    var file = File(p.join(_directory.path, '$_prefix$stamp$_extension'));
    var suffix = 2;
    while (file.existsSync()) {
      file = File(p.join(_directory.path, '$_prefix$stamp-$suffix$_extension'));
      suffix++;
    }

    return file;
  }
}
