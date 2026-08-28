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
      service.directory
          .childFile('de-outra-maquina.db')
          .writeAsBytesSync(<int>[]);

      // Ele não é uma cópia deste banco: contar com ele deixaria a máquina uma
      // semana sem backup de verdade.
      expect(service.isDue(), isTrue);
    });

    test('a rede de uma restauração não adia o automático', () {
      insertItem('qualquer coisa');
      final backup = service.create(at: DateTime(2026, 8, 1, 10));

      // A restauração deixa na pasta uma cópia com a data de hoje. Ela responde
      // "o que eu tinha antes de clicar em restaurar?", não "quando foi o
      // último backup semanal" — e contá-la adiaria por sete dias um backup que
      // ninguém pediu para adiar.
      service.restore(backup);

      expect(service.isDue(now: DateTime(2026, 8, 26, 10)), isTrue);
    });
  });

  group('limpar', () {
    test('nunca apaga o arquivo protegido, mesmo passando do teto', () {
      final protegido = service.create(at: DateTime(2026, 7, 1, 10));
      final bytes = File(protegido.path).readAsBytesSync();

      // Escritos direto na pasta: `create` limpa a cada volta e nunca deixaria
      // sete arquivos nossos ali ao mesmo tempo.
      for (var day = 2; day <= 7; day++) {
        service.directory
            .childFile('evergreen-2026-07-0$day-1000.db')
            .writeAsBytesSync(bytes);
      }

      final removed = service.prune(protecting: protegido.path);

      // Sete arquivos, teto de cinco: sairiam os dois mais antigos, mas o mais
      // antigo é o que está prestes a ser lido por uma restauração.
      expect(removed, 1);
      expect(File(protegido.path).existsSync(), isTrue);
    });

    test('as redes têm teto próprio e não tomam a vaga dos automáticos', () {
      final automatico = service.create(at: DateTime(2026, 7, 1, 10));
      final bytes = File(automatico.path).readAsBytesSync();

      for (var day = 1; day <= 4; day++) {
        service.directory
            .childFile('evergreen-antes-de-restaurar-2026-08-0$day-1000.db')
            .writeAsBytesSync(bytes);
      }

      service.prune();

      final kept = service.list();
      expect(
        kept.where((backup) => backup.isSafetyCopy),
        hasLength(BackupService.maxSafetyCopies),
      );
      // O automático é o mais antigo de todos e continua ali: quatro
      // restaurações seguidas não podem varrer o backup semanal.
      expect(kept.map((backup) => backup.name), contains(automatico.name));
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
      expect(
        db.select('SELECT id FROM schema_migrations;'),
        hasLength(applied),
      );
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

    test('guarda o estado de agora com nome próprio, para desfazer', () {
      insertItem('conteúdo antigo');
      final backup = service.create(at: DateTime(2026, 8, 20, 10));

      db.execute('DELETE FROM clipboard_items;');
      insertItem('o dia de hoje', copiedAt: 2);

      final safety = service.restore(backup);

      // Nome próprio: é na lista que se procura por ela, no minuto em que se
      // percebe que a linha clicada era a errada.
      expect(safety.isSafetyCopy, isTrue);
      expect(safety.name, startsWith('evergreen-antes-de-restaurar-'));
      expect(safety.isOurs, isTrue);

      final rescued = sqlite3.open(safety.path);
      addTearDown(rescued.close);
      expect(contentsOf(rescued), ['o dia de hoje']);
    });

    test('com a pasta cheia, o arquivo escolhido sobrevive à rede', () {
      insertItem('o que se quer de volta');
      final oldest = service.create(at: DateTime(2026, 7, 1, 10));

      db.execute('DELETE FROM clipboard_items;');
      insertItem('uma semana qualquer', copiedAt: 2);
      for (var week = 1; week <= 4; week++) {
        service.create(at: DateTime(2026, 7, 1 + 7 * week, 10));
      }

      // Restaurar o mais antigo de uma pasta no teto é o caso real: cinco
      // backups semanais, e o que se procura é o de cinco semanas atrás. A rede
      // criada agora entrava como sexto arquivo e empurrava justamente ele para
      // fora — e o que se lia em seguida era um banco vazio recém-criado pelo
      // `sqlite3.open`, copiado por cima de tudo.
      service.restore(oldest);

      expect(File(oldest.path).existsSync(), isTrue);
      expect(contentsOf(db), ['o que se quer de volta']);
    });

    test('desfazer uma restauração antiga não apaga a rede escolhida', () {
      insertItem('o estado que se quer de volta');
      final base = service.create(at: DateTime(2026, 7, 1, 10));
      final bytes = File(base.path).readAsBytesSync();

      // Três restaurações anteriores deixaram três redes na pasta — o teto
      // delas. Desfazer a mais antiga é o caso: a rede que esta restauração vai
      // criar entra como quarta e empurraria justamente ela para fora.
      for (var day = 1; day <= 3; day++) {
        service.directory
            .childFile('evergreen-antes-de-restaurar-2026-08-0$day-1000.db')
            .writeAsBytesSync(bytes);
      }
      final target = service.list().where((backup) => backup.isSafetyCopy).last;

      db.execute('DELETE FROM clipboard_items;');
      insertItem('o engano de agora', copiedAt: 2);

      service.restore(target);

      expect(contentsOf(db), ['o estado que se quer de volta']);
    });

    test('o arquivo que sumiu da pasta não vira uma restauração vazia', () {
      insertItem('o dia de hoje');
      final backup = service.create();

      // A pasta é a interface do backup: arrastar o arquivo para o lixo com o
      // Hub aberto deixa na lista uma linha que já não corresponde a nada.
      File(backup.path).deleteSync();

      expect(() => service.restore(backup), throwsA(isA<BackupMissing>()));
      expect(contentsOf(db), ['o dia de hoje']);
      // A recusa vem antes de tudo: nem o banco foi tocado, nem sobrou rede.
      expect(service.list().where((backup) => backup.isSafetyCopy), isEmpty);
    });
  });
}

extension on Directory {
  File childFile(String name) => File('$path${Platform.pathSeparator}$name');
}
