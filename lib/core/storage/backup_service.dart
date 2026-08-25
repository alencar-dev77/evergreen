import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../../features/home/models/backup_file.dart';
import 'app_database.dart';

/// Cópias de segurança do banco local.
///
/// O Evergreen não manda nada para lugar nenhum, o que tem uma consequência
/// desconfortável: se este arquivo se perder, não há servidor de onde puxar de
/// volta. O backup é a resposta a isso — e, pela mesma razão, ele é um arquivo
/// nesta máquina que a pessoa pode copiar para onde quiser.
///
/// **O snapshot é feito com `VACUUM INTO`, e não copiando o arquivo.** O banco
/// roda em WAL com duas conexões abertas (a janela flutuante e o Hub): copiar
/// `evergreen.db` no disco pegaria o arquivo sem as páginas que ainda estão no
/// log, e o backup nasceria faltando o que foi escrito nos últimos minutos.
/// O `VACUUM INTO` pede ao próprio SQLite um banco novo, consistente e
/// compactado, num arquivo só — sem `-wal` nem `-shm` para acompanhar.
class BackupService {
  BackupService({required Database database, required Directory directory})
      : _db = database,
        _directory = directory;

  final Database _db;
  final Directory _directory;

  /// Quantos backups automáticos ficam na pasta.
  ///
  /// Cinco, e não "todos": um backup semanal sem teto vira um depósito que
  /// ninguém revisita e que só cresce. Cinco cobre mais de um mês — tempo de
  /// sobra para perceber que algo se perdeu — e é o mesmo raciocínio do teto de
  /// nove anotações do Leaf: o limite é o produto, não uma limitação técnica.
  static const maxBackups = 5;

  /// De quanto em quanto tempo o backup automático acontece.
  static const interval = Duration(days: 7);

  static const _prefix = 'evergreen-';
  static const _extension = '.db';

  /// `evergreen-2026-08-25-1432.db`, com um sufixo opcional para o segundo
  /// backup do mesmo minuto.
  ///
  /// É por este padrão que um arquivo é reconhecido como nosso — e não só pelo
  /// prefixo: um `evergreen-do-notebook.db` salvo à mão pela pessoa continua
  /// sendo um arquivo dela, fora da conta da limpeza automática.
  static final _ourName = RegExp(
    r'^evergreen-(\d{4})-(\d{2})-(\d{2})-(\d{2})(\d{2})(?:-\d+)?\.db$',
  );

  Directory get directory => _directory;

  /// O caminho da pasta como se escreve para uma pessoa (`~/Library/…`).
  ///
  /// A tela precisa responder "onde isso fica" sem gastar duas linhas com o
  /// `/Users/<nome>` que a pessoa já sabe de cor.
  String get directoryLabel {
    final home = Platform.environment['HOME'];
    if (home == null || home.isEmpty) return _directory.path;

    return _directory.path.startsWith(home)
        ? '~${_directory.path.substring(home.length)}'
        : _directory.path;
  }

  /// Faz um backup agora e devolve o arquivo criado.
  BackupFile create({DateTime? at}) {
    _directory.createSync(recursive: true);

    final file = _freeNameFor(at ?? DateTime.now());
    // O `VACUUM INTO` se recusa a escrever por cima de um arquivo existente, e
    // é bom que se recuse: nome livre é escolhido antes, nunca sobrescrito.
    _db.execute('VACUUM INTO ?;', [file.path]);

    prune();

    return _describe(file);
  }

  /// Os backups da pasta, do mais recente para o mais antigo.
  ///
  /// Qualquer `.db` que estiver ali entra na lista, não só os que o Evergreen
  /// escreveu: é assim que se traz um backup de outra máquina — arrasta para a
  /// pasta e ele aparece aqui para ser restaurado. Não há seletor de arquivo
  /// no caminho porque a pasta **é** a interface.
  List<BackupFile> list() {
    if (!_directory.existsSync()) return const [];

    final files = <BackupFile>[
      for (final entity in _directory.listSync())
        if (entity is File && p.extension(entity.path) == _extension)
          _describe(entity),
    ];

    return files..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Está na hora do backup automático?
  ///
  /// A resposta sai da pasta, e não de uma data guardada nas preferências: o
  /// arquivo mais novo é a única fonte que não desencontra: as duas janelas do
  /// Evergreen rodam em engines separados e não veem a preferência uma da
  /// outra, mas veem a mesma pasta. Apagar os backups à mão também volta a
  /// pedir um novo, que é o que a pessoa esperaria.
  bool isDue({DateTime? now}) {
    final ours = list().where((backup) => backup.isOurs);
    if (ours.isEmpty) return true;

    return (now ?? DateTime.now()).difference(ours.first.createdAt) >= interval;
  }

  /// Apaga os backups do Evergreen que excedem [maxBackups] e devolve quantos
  /// saíram.
  ///
  /// Só os nossos entram na conta — ver [BackupFile.isOurs].
  int prune() {
    final ours = list().where((backup) => backup.isOurs).toList();
    if (ours.length <= maxBackups) return 0;

    final excess = ours.sublist(maxBackups);
    for (final backup in excess) {
      File(backup.path).deleteSync();
    }

    return excess.length;
  }

  /// Põe o conteúdo de [backup] no lugar do que está no banco agora.
  ///
  /// Tabela a tabela dentro de uma transação, e não trocando o arquivo no
  /// disco: as duas janelas do Evergreen têm este banco aberto, e um arquivo
  /// substituído por baixo delas deixaria as duas conexões apontando para um
  /// inode que não existe mais. Assim a restauração vale na hora, sem reiniciar
  /// o aplicativo — os painéis releem ao abrir e as telas do Hub ao montar.
  ///
  /// O backup é **migrado antes de ser lido**: um arquivo de três versões atrás
  /// não tem as colunas de hoje, e sem isso a cópia falharia justamente no
  /// backup mais antigo, que é o que se restaura em desespero.
  void restore(BackupFile backup) {
    final source = sqlite3.open(backup.path);
    try {
      AppDatabase.migrate(source);
    } finally {
      source.close();
    }

    _db.execute('ATTACH DATABASE ? AS backup;', [backup.path]);

    try {
      _db.execute('BEGIN IMMEDIATE;');

      try {
        for (final table in _restorableTables()) {
          final columns = _sharedColumns(table);
          if (columns.isEmpty) continue;

          final list = columns.map((column) => '"$column"').join(', ');
          _db.execute('DELETE FROM main."$table";');
          _db.execute(
            'INSERT INTO main."$table" ($list) SELECT $list FROM backup."$table";',
          );
        }

        _db.execute('COMMIT;');
      } catch (_) {
        _db.execute('ROLLBACK;');
        rethrow;
      }
    } finally {
      _db.execute('DETACH DATABASE backup;');
    }
  }

  /// Abre a pasta no Finder.
  ///
  /// `open` do próprio macOS, e não um canal nativo: é uma linha de processo e
  /// o Evergreen não roda em sandbox (ver `Release.entitlements`).
  Future<void> reveal() async {
    _directory.createSync(recursive: true);
    await Process.run('open', [_directory.path]);
  }

  /// As tabelas que existem dos dois lados.
  ///
  /// Descobertas, e não escritas à mão: assim a tabela de um módulo futuro
  /// entra no backup e na restauração sozinha, sem ninguém lembrar de vir aqui.
  ///
  /// `schema_migrations` fica de fora de propósito — o registro de migrações é
  /// do banco que está rodando, não do backup. Restaurá-lo faria o banco atual
  /// achar que uma migração já aplicada ainda não rodou.
  List<String> _restorableTables() {
    final main = _tableNames('main');
    final backup = _tableNames('backup');

    return [
      for (final table in main)
        if (backup.contains(table)) table,
    ];
  }

  Set<String> _tableNames(String schema) => _db
      .select(
        '''
        SELECT name FROM $schema.sqlite_master
         WHERE type = 'table'
           AND name NOT LIKE 'sqlite_%'
           AND name <> 'schema_migrations';
        ''',
      )
      .map((row) => row['name'] as String)
      .toSet();

  /// As colunas que os dois lados têm em comum, na ordem do banco atual.
  ///
  /// Depois da migração do backup elas coincidem — a interseção é a rede para
  /// o caso em que não coincidirem, e é o que faz uma coluna nova nascer com o
  /// valor padrão em vez de derrubar a restauração inteira.
  List<String> _sharedColumns(String table) {
    final backup = _db
        .select('PRAGMA backup.table_info("$table");')
        .map((row) => row['name'] as String)
        .toSet();

    return [
      for (final row in _db.select('PRAGMA main.table_info("$table");'))
        if (backup.contains(row['name'] as String)) row['name'] as String,
    ];
  }

  /// Nome livre para o backup deste instante.
  ///
  /// `evergreen-2026-08-25-1432.db` — ordenável e legível de relance. Dois
  /// backups no mesmo minuto (o manual logo depois do automático) ganham um
  /// sufixo em vez de disputar o nome.
  File _freeNameFor(DateTime moment) {
    final stamp = '${moment.year}-${_pad(moment.month)}-${_pad(moment.day)}'
        '-${_pad(moment.hour)}${_pad(moment.minute)}';

    var file = File(p.join(_directory.path, '$_prefix$stamp$_extension'));
    var attempt = 2;

    while (file.existsSync()) {
      file = File(p.join(_directory.path, '$_prefix$stamp-$attempt$_extension'));
      attempt++;
    }

    return file;
  }

  /// Quem é o arquivo e de quando ele é.
  ///
  /// Nos nossos a data sai **do nome**, e não da data de modificação: copiar a
  /// pasta para outro disco, restaurar de um Time Machine ou sincronizar por
  /// alguma nuvem reescreve o `mtime`, e um backup de março passaria a se
  /// apresentar como de hoje — adiando por uma semana o backup que deveria
  /// acontecer agora. Num arquivo de fora não há nome que se possa ler, e aí a
  /// data de modificação é a melhor aproximação que existe.
  static BackupFile _describe(File file) {
    final match = _ourName.firstMatch(p.basename(file.path));
    if (match == null) return BackupFile.of(file, isOurs: false);

    final stat = file.statSync();

    return BackupFile(
      path: file.path,
      createdAt: DateTime(
        int.parse(match.group(1)!),
        int.parse(match.group(2)!),
        int.parse(match.group(3)!),
        int.parse(match.group(4)!),
        int.parse(match.group(5)!),
      ),
      sizeBytes: stat.size,
      isOurs: true,
    );
  }

  static String _pad(int value) => value.toString().padLeft(2, '0');
}
