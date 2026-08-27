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

  /// Quantas redes de restauração ficam na pasta.
  ///
  /// Três, e com teto próprio: elas respondem a outra pergunta que os
  /// automáticos ("o que eu tinha antes de clicar em restaurar?"), e são
  /// escritas em rajada — quem erra o arquivo tende a tentar de novo. Um teto
  /// só, compartilhado, faria a terceira tentativa apagar a cópia da primeira,
  /// que é justamente a única em que o dia de trabalho ainda estava inteiro.
  static const maxSafetyCopies = 3;

  /// De quanto em quanto tempo o backup automático acontece.
  static const interval = Duration(days: 7);

  static const _prefix = 'evergreen-';
  static const _safetyInfix = 'antes-de-restaurar-';
  static const _extension = '.db';

  /// `evergreen-2026-08-25-1432.db` — ou
  /// `evergreen-antes-de-restaurar-2026-08-25-1432.db`, quando o arquivo é a
  /// rede de uma restauração —, com um sufixo opcional para o segundo backup
  /// do mesmo minuto.
  ///
  /// É por este padrão que um arquivo é reconhecido como nosso — e não só pelo
  /// prefixo: um `evergreen-do-notebook.db` salvo à mão pela pessoa continua
  /// sendo um arquivo dela, fora da conta da limpeza automática.
  static final _ourName = RegExp(
    r'^evergreen-(?:antes-de-restaurar-)?'
    r'(\d{4})-(\d{2})-(\d{2})-(\d{2})(\d{2})(?:-\d+)?\.db$',
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
    final file = _snapshot(at ?? DateTime.now());
    prune();

    return _describe(file);
  }

  /// Escreve o banco deste instante num arquivo novo da pasta.
  File _snapshot(DateTime moment, {String infix = ''}) {
    _directory.createSync(recursive: true);

    final file = _freeNameFor(moment, infix: infix);
    // O `VACUUM INTO` se recusa a escrever por cima de um arquivo existente, e
    // é bom que se recuse: nome livre é escolhido antes, nunca sobrescrito.
    _db.execute('VACUUM INTO ?;', [file.path]);

    return file;
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
    // A rede que uma restauração deixou não conta: ela é do dia em que se
    // restaurou algo, não do fim de uma semana — e adiaria por sete dias um
    // backup que ninguém pediu para adiar.
    final ours = list().where(
      (backup) => backup.isOurs && !backup.isSafetyCopy,
    );
    if (ours.isEmpty) return true;

    return (now ?? DateTime.now()).difference(ours.first.createdAt) >= interval;
  }

  /// Apaga os backups do Evergreen que excedem o teto e devolve quantos saíram.
  ///
  /// Só os nossos entram na conta — ver [BackupFile.isOurs] —, e os dois tipos
  /// contam separado: os automáticos por [maxBackups], as redes de restauração
  /// por [maxSafetyCopies].
  ///
  /// [protecting] é o arquivo que não pode sair de jeito nenhum: o que está
  /// prestes a ser restaurado. Sem isso, restaurar o backup **mais antigo** de
  /// uma pasta cheia o apagava um instante antes de lê-lo — a rede recém-criada
  /// entrava como sexto arquivo e empurrava justamente ele para fora. O
  /// `sqlite3.open` seguinte criava um banco vazio no lugar do que sumiu, e as
  /// zero linhas dele eram copiadas por cima de tudo, com a tela anunciando
  /// "Backup restaurado".
  int prune({String? protecting}) {
    final ours = list().where((backup) => backup.isOurs);

    return _pruneGroup(
          ours.where((backup) => !backup.isSafetyCopy),
          maxBackups,
          protecting,
        ) +
        _pruneGroup(
          ours.where((backup) => backup.isSafetyCopy),
          maxSafetyCopies,
          protecting,
        );
  }

  /// Apaga o que passa de [keep] num grupo já ordenado do mais recente para o
  /// mais antigo.
  int _pruneGroup(Iterable<BackupFile> group, int keep, String? protecting) {
    var removed = 0;

    for (final backup in group.skip(keep)) {
      if (backup.path == protecting) continue;

      File(backup.path).deleteSync();
      removed++;
    }

    return removed;
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
  ///
  /// Devolve a rede deixada para trás — o banco de agora, guardado antes de a
  /// primeira linha ser apagada.
  BackupFile restore(BackupFile backup) {
    // O arquivo ainda está lá?
    //
    // `sqlite3.open` num caminho que não existe **cria** um banco vazio, e o
    // resto deste método copiaria com prazer as zero linhas dele por cima de
    // tudo. A pasta é a interface do backup: um arquivo arrastado para o lixo
    // no Finder com o Hub aberto chega até aqui como uma linha da lista que já
    // não corresponde a nada.
    if (!File(backup.path).existsSync()) throw BackupMissing(backup.name);

    // Antes de apagar qualquer coisa: restaurar é a única operação do Evergreen
    // que apaga tudo de uma vez, e ter clicado na linha errada não pode custar
    // o dia de hoje. A rede nasce aqui, e não em quem chama, porque ela precisa
    // proteger o arquivo que este método está prestes a ler — ver [prune].
    final safety = _snapshotBeforeRestoring(backup);

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

    return safety;
  }

  /// O banco de agora, guardado com nome próprio antes de uma restauração.
  ///
  /// Nome próprio (`evergreen-antes-de-restaurar-…`) por duas razões: na lista,
  /// é o que distingue "o meu estado de antes" de mais um backup semanal — e é
  /// nessa lista que se vai procurá-lo, no minuto em que se percebe o engano; e
  /// na limpeza, é o que lhe dá um teto separado, em [maxSafetyCopies].
  BackupFile _snapshotBeforeRestoring(BackupFile backup) {
    final file = _snapshot(DateTime.now(), infix: _safetyInfix);
    prune(protecting: backup.path);

    return _describe(file);
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
  File _freeNameFor(DateTime moment, {String infix = ''}) {
    final stamp = '${moment.year}-${_pad(moment.month)}-${_pad(moment.day)}'
        '-${_pad(moment.hour)}${_pad(moment.minute)}';

    var file = File(
      p.join(_directory.path, '$_prefix$infix$stamp$_extension'),
    );
    var attempt = 2;

    while (file.existsSync()) {
      file = File(
        p.join(_directory.path, '$_prefix$infix$stamp-$attempt$_extension'),
      );
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
    final name = p.basename(file.path);
    final match = _ourName.firstMatch(name);
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
      isSafetyCopy: name.startsWith('$_prefix$_safetyInfix'),
    );
  }

  static String _pad(int value) => value.toString().padLeft(2, '0');
}

/// O arquivo escolhido para restaurar não está mais na pasta.
///
/// Classe própria, e não um `StateError`, porque esta frase chega inteira à
/// tela pelo `toString` — ver `BackupViewModel`, que mostra a primeira linha do
/// erro. "Bad state:" não é português.
class BackupMissing implements Exception {
  const BackupMissing(this.name);

  /// O nome do arquivo, como ele aparecia na lista.
  final String name;

  @override
  String toString() => 'o arquivo $name não está mais na pasta';
}
