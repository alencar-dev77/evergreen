import 'dart:io';

import 'package:evergreen/core/storage/app_database.dart';
import 'package:evergreen/core/storage/backup_service.dart';
import 'package:evergreen/features/home/models/backup_file.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

/// As cópias de segurança do banco.
///
/// O Evergreen não manda nada para lugar nenhum, o que significa que não há
/// servidor de onde puxar de volta: o que estes testes prendem é que o arquivo
/// sai íntegro, que a pasta não vira depósito e que restaurar um backup antigo
/// — o caso em que se restaura de verdade — não esbarra no schema de hoje.
void main() {
  late Database db;
  late Directory root;
  late BackupService service;

  setUp(() {
    db = sqlite3.openInMemory();
    AppDatabase.migrate(db);

    root = Directory.systemTemp.createTempSync('evergreen-backup-test');
    service = BackupService(
      database: db,
      directory: Directory('${root.path}/Backups'),
    );
  });

  tearDown(() {
    db.close();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  void insertItem(String content, {int copiedAt = 1}) {
    db.execute(
      'INSERT INTO clipboard_items (content, type, is_pinned, copied_at) '
      "VALUES (?, 'text', 0, ?);",
      [content, copiedAt],
    );
  }

  List<String> contentsOf(Database database) => database
      .select('SELECT content FROM clipboard_items ORDER BY id;')
      .map((row) => row['content'] as String)
      .toList();

  group('criar', () {
    test('escreve um banco íntegro, com o conteúdo do momento', () {
      insertItem('antes do backup');

      final backup = service.create();

      expect(File(backup.path).existsSync(), isTrue);
      expect(backup.isOurs, isTrue);

      final copy = sqlite3.open(backup.path);
      addTearDown(copy.close);
      expect(contentsOf(copy), ['antes do backup']);
    });

    test('a pasta nasce junto com o primeiro backup', () {
      expect(service.directory.existsSync(), isFalse);

      service.create();

      expect(service.directory.existsSync(), isTrue);
    });

    test('dois backups no mesmo minuto não disputam o nome', () {
      final moment = DateTime(2026, 8, 25, 14, 32);

      final first = service.create(at: moment);
      final second = service.create(at: moment);

      expect(first.path, isNot(second.path));
      expect(File(first.path).existsSync(), isTrue);
      expect(File(second.path).existsSync(), isTrue);
    });
  });

  group('a pasta não vira depósito', () {
    test('guarda os cinco mais recentes e apaga o resto', () {
      for (var day = 1; day <= 8; day++) {
        service.create(at: DateTime(2026, 8, day, 10));
      }

      final kept = service.list();

      expect(kept, hasLength(BackupService.maxBackups));
      // Os que ficaram são os mais novos, do mais recente para o mais antigo.
      expect(kept.first.createdAt.isAfter(kept.last.createdAt), isTrue);
    });

    test('arquivo trazido de fora fica onde está', () {
      service.directory.createSync(recursive: true);
      final stranger = File('${service.directory.path}/do-macbook-antigo.db')
        ..writeAsBytesSync(<int>[]);

      for (var day = 1; day <= 8; day++) {
        service.create(at: DateTime(2026, 8, day, 10));
      }

      // A pessoa o pôs ali de propósito: apagá-lo por causa de um teto que ela
      // não escolheu seria perder justamente o backup que mais importava.
      expect(stranger.existsSync(), isTrue);
      expect(service.list().where((backup) => !backup.isOurs), hasLength(1));
    });

    test('a lista traz qualquer .db da pasta, e só .db', () {
      service.create();
      service.directory
        ..createSync(recursive: true)
        ..childFile('leia-me.txt').writeAsStringSync('nada a ver');

      expect(service.list(), hasLength(1));
    });
  });

  group('quando o automático é devido', () {
    test('sem backup nenhum, agora', () {
      expect(service.isDue(), isTrue);
    });

    test('com um da semana passada, agora', () {
      final now = DateTime(2026, 8, 25, 10);
      service.create(at: now.subtract(const Duration(days: 8)));

      expect(service.isDue(now: now), isTrue);
    });

    test('com um de anteontem, ainda não', () {
      final now = DateTime(2026, 8, 25, 10);
      service.create(at: now.subtract(const Duration(days: 2)));

      expect(service.isDue(now: now), isFalse);
    });

    test('um arquivo trazido de fora não adia o backup automático', () {
      service.directory.createSync(recursive: true);
      service.directory.childFile('de-outra-maquina.db').writeAsBytesSync(<int>[]);

      // Ele não é uma cópia deste banco: contar com ele deixaria a máquina uma
      // semana sem backup de verdade.
      expect(service.isDue(), isTrue);
    });
  });

  group('restaurar', () {
    test('põe o conteúdo do backup no lugar do que está agora', () {
      insertItem('conteúdo antigo');
      final backup = service.create();

      db.execute('DELETE FROM clipboard_items;');
      insertItem('conteúdo de agora', copiedAt: 2);

      service.restore(backup);

      expect(contentsOf(db), ['conteúdo antigo']);
    });

    test('leva as quatro tabelas dos módulos, não só a do Pin', () {
      insertItem('copiado');
      db.execute(
        'INSERT INTO focus_sessions (started_at, duration_seconds) '
        'VALUES (1, 1500);',
      );
      db.execute(
        "INSERT INTO leaf_notes (slot, content, created_at) VALUES (1, 'oi', 1);",
      );

      final backup = service.create();
      db
        ..execute('DELETE FROM clipboard_items;')
        ..execute('DELETE FROM focus_sessions;')
        ..execute('DELETE FROM leaf_notes;');

      service.restore(backup);

      expect(db.select('SELECT id FROM clipboard_items;'), hasLength(1));
      expect(db.select('SELECT id FROM focus_sessions;'), hasLength(1));
      expect(db.select('SELECT id FROM leaf_notes;'), hasLength(1));
    });

    test('não traz o registro de migrações do backup', () {
      final backup = service.create();
      final applied = db.select('SELECT id FROM schema_migrations;').length;

      service.restore(backup);

      // O registro é do banco que está rodando: restaurá-lo faria uma migração
      // já aplicada parecer pendente.
      expect(db.select('SELECT id FROM schema_migrations;'), hasLength(applied));
    });

    test('um backup de uma versão anterior do schema sobe antes de entrar', () {
      service.directory.createSync(recursive: true);
      final path = '${service.directory.path}/evergreen-antigo.db';

      // O schema da v0.1: clipboard_items sem apelido, sem versão de
      // classificador e sem ordem de fixado.
      final old = sqlite3.open(path);
      old
        ..execute('''
          CREATE TABLE clipboard_items (
            id         INTEGER PRIMARY KEY AUTOINCREMENT,
            content    TEXT    NOT NULL,
            type       TEXT    NOT NULL,
            is_pinned  INTEGER NOT NULL DEFAULT 0,
            copied_at  INTEGER NOT NULL
          );
        ''')
        ..execute(
          "INSERT INTO clipboard_items (content, type, copied_at) "
          "VALUES ('de três versões atrás', 'text', 1);",
        )
        ..close();

      // É justamente o backup mais antigo que se restaura em desespero: se ele
      // não entrasse, o backup não serviria para nada.
      service.restore(BackupFile.of(File(path), isOurs: false));

      expect(contentsOf(db), ['de três versões atrás']);
      final row = db.select('SELECT alias FROM clipboard_items;').first;
      expect(row['alias'], isNull);
    });
  });
}

extension on Directory {
  File childFile(String name) => File('$path${Platform.pathSeparator}$name');
}
