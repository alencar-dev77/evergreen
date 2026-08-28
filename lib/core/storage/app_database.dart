import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

/// Acesso ao banco SQLite local do Evergreen.
///
/// Um único arquivo `evergreen.db` guarda os dados de todos os módulos; cada
/// feature é dona das suas tabelas e registra as próprias migrações em
/// [_migrations]. Nada sai da máquina.
class AppDatabase {
  AppDatabase._(this.db, this.directoryPath);

  final Database db;

  /// A pasta em que o `evergreen.db` mora
  /// (`~/Library/Application Support/<bundle>`).
  ///
  /// Exposta porque o backup escreve numa subpasta dela, e resolvê-la de novo
  /// lá seria um segundo `await getApplicationSupportDirectory()` para chegar
  /// ao mesmo lugar — com o risco de os dois discordarem um dia.
  final String directoryPath;

  static AppDatabase? _instance;

  /// Nome do arquivo dentro de `~/Library/Application Support/<bundle>`.
  static const _fileName = 'evergreen.db';

  /// Migrações identificadas por nome, na ordem em que foram escritas. Para
  /// evoluir o schema, acrescente uma entrada com chave nova — nunca edite nem
  /// reaproveite uma chave já publicada.
  ///
  /// A chave existe porque a posição não distingue duas migrações escritas em
  /// paralelo: duas branches criando cada uma "a quinta migração" produzem o
  /// mesmo número, e a que chegasse depois seria pulada em silêncio — o erro só
  /// aparecia semanas adiante, num `SELECT` de coluna inexistente.
  static const _migrations = <String, String>{
    'clipboard-items': '''
    CREATE TABLE IF NOT EXISTS clipboard_items (
      id         INTEGER PRIMARY KEY AUTOINCREMENT,
      content    TEXT    NOT NULL,
      type       TEXT    NOT NULL,
      is_pinned  INTEGER NOT NULL DEFAULT 0,
      copied_at  INTEGER NOT NULL
    );
    CREATE UNIQUE INDEX IF NOT EXISTS idx_clipboard_content
      ON clipboard_items (content);
    CREATE INDEX IF NOT EXISTS idx_clipboard_recent
      ON clipboard_items (is_pinned DESC, copied_at DESC);
    ''',
    // Os fixados passam a ter ordem própria, definida por quando foram
    // fixados. Sem isso eles se reordenariam a cada nova cópia e os atalhos
    // ⌥1..⌥5 mudariam de item sozinhos.
    'clipboard-pinned-order': '''
    ALTER TABLE clipboard_items ADD COLUMN pinned_at INTEGER;
    UPDATE clipboard_items SET pinned_at = copied_at WHERE is_pinned = 1;
    CREATE INDEX IF NOT EXISTS idx_clipboard_pinned
      ON clipboard_items (is_pinned DESC, pinned_at ASC);
    ''',
    // Histórico do Focus. Guardamos o início e o tempo efetivamente focado, e
    // não o fim: com pausas os dois não se derivam um do outro, e o fim não
    // aparece em lugar nenhum da interface — o histórico mostra "quando começou"
    // e "quanto durou".
    'focus-sessions': '''
    CREATE TABLE IF NOT EXISTS focus_sessions (
      id               INTEGER PRIMARY KEY AUTOINCREMENT,
      started_at       INTEGER NOT NULL,
      duration_seconds INTEGER NOT NULL,
      activity         TEXT,
      summary          TEXT
    );
    CREATE INDEX IF NOT EXISTS idx_focus_sessions_recent
      ON focus_sessions (started_at DESC);
    ''',
    // Observações escritas durante a sessão ("terminei a task e comecei
    // outra"), uma por linha no formato `minuto|texto` — ver FocusSessionNote.
    'focus-session-notes': '''
    ALTER TABLE focus_sessions ADD COLUMN notes TEXT;
    ''',
    // Apelido dado pela pessoa a um item do histórico ("chave pix"). É só um
    // nome para reencontrar o item na lista — o conteúdo copiado continua
    // sendo o original, e por isso mora numa coluna à parte de `content`.
    'clipboard-alias': '''
    ALTER TABLE clipboard_items ADD COLUMN alias TEXT;
    ''',
    // O classificador do Pin passou a reconhecer e-mail, telefone e CPF. Como
    // o tipo é decidido na captura e gravado na linha, o histórico já guardado
    // continuaria inteiro como "Texto" — e os filtros novos nasceriam vazios
    // justamente para quem usa o Pin há mais tempo. A coluna guarda com qual
    // versão do classificador cada item foi classificado; quem ficou para trás
    // é reclassificado em Dart na primeira carga (validar dígito verificador de
    // CPF não é trabalho para SQL). Zero é "antes de existir versão".
    'clipboard-classifier-version': '''
    ALTER TABLE clipboard_items
      ADD COLUMN classifier_version INTEGER NOT NULL DEFAULT 0;
    ''',
    // Anotações do Leaf. A vaga (1..9) é única porque ela é a identidade da
    // anotação na parede — é dela que saem o número do cartão e o `⌘N` que o
    // copia, e duas anotações na mesma vaga significariam dois cartões
    // disputando a mesma tecla.
    'leaf-notes': '''
    CREATE TABLE IF NOT EXISTS leaf_notes (
      id         INTEGER PRIMARY KEY AUTOINCREMENT,
      slot       INTEGER NOT NULL,
      content    TEXT    NOT NULL,
      created_at INTEGER NOT NULL
    );
    CREATE UNIQUE INDEX IF NOT EXISTS idx_leaf_slot ON leaf_notes (slot);
    ''',
    // Quando o cartão passou a dizer o que diz.
    //
    // O rodapé do cartão tem espaço para uma data só, e ela era sempre a de
    // criação: uma anotação reescrita hoje continuava se apresentando como "há
    // 3 semanas", que é a idade do papel e não a do recado. Nulo é "nunca
    // editada depois de escrita" — e é por isso que a coluna não tem valor
    // padrão: o que já estava na parede não foi editado, foi criado.
    'leaf-notes-updated': '''
    ALTER TABLE leaf_notes ADD COLUMN updated_at INTEGER;
    ''',
    // Reuniões do Echo. O áudio não aparece aqui de propósito: ele é apagado
    // assim que a transcrição entra, então o banco guarda só texto.
    //
    // `transcript` é JSON, e não o formato `campo|campo` das observações do
    // Focus — ali o texto é escrito pela pessoa num campo de uma linha, aqui é
    // fala transcrita, que pode conter qualquer separador que se improvisasse.
    //
    // `is_kept` é o "guardar" da reunião: mesma função do `is_pinned` do Pin,
    // tirar a linha do alcance da limpeza automática.
    'echo-meetings': '''
    CREATE TABLE IF NOT EXISTS echo_meetings (
      id          INTEGER PRIMARY KEY AUTOINCREMENT,
      title       TEXT    NOT NULL,
      started_at  INTEGER NOT NULL,
      duration_ms INTEGER NOT NULL,
      language    TEXT    NOT NULL,
      transcript  TEXT    NOT NULL,
      summary     TEXT,
      is_kept     INTEGER NOT NULL DEFAULT 0
    );
    CREATE INDEX IF NOT EXISTS idx_echo_meetings_recent
      ON echo_meetings (started_at DESC);
    ''',
    // Quanto tempo o Mac ficou acordado por ordem do Awake.
    //
    // É a única linha que o módulo grava, e ela existe para o Track: dos cinco
    // módulos que registram alguma coisa, o Awake era o único que não aparecia
    // no dia reconstruído — não por decisão, mas porque não tinha tabela. Uma
    // trava por vez, gravada quando ela se solta; a que ainda está de pé não
    // está aqui, porque ainda não tem duração.
    'awake-sessions': '''
    CREATE TABLE IF NOT EXISTS awake_sessions (
      id               INTEGER PRIMARY KEY AUTOINCREMENT,
      started_at       INTEGER NOT NULL,
      duration_seconds INTEGER NOT NULL,
      mode             TEXT    NOT NULL
    );
    CREATE INDEX IF NOT EXISTS idx_awake_sessions_recent
      ON awake_sessions (started_at DESC);
    ''',
    // A instrução que produziu o resumo que está na linha.
    //
    // Refazer um resumo é barato e é o jeito de experimentar formatos — mas
    // sem esta coluna o texto novo chegava sem nada dizendo de qual instrução
    // ele saiu, e a anterior já tinha sido sobrescrita no campo de
    // preferências. Comparar dois formatos exigia lembrar de cor o que estava
    // escrito ali semana passada.
    //
    // Guardada por reunião, e não uma vez só nas preferências, porque a
    // instrução das preferências é a **próxima**; esta é a que valeu para este
    // texto. Nulo é resumo feito antes desta coluna existir.
    'echo-summary-prompt': '''
    ALTER TABLE echo_meetings ADD COLUMN summary_prompt TEXT;
    ''',
  };

  /// Abre (ou reaproveita) a conexão com o banco.
  static Future<AppDatabase> open() async {
    if (_instance != null) return _instance!;

    final directory = await getApplicationSupportDirectory();
    await directory.create(recursive: true);

    final database = sqlite3.open(p.join(directory.path, _fileName));

    // Duas janelas, dois engines, duas conexões no mesmo arquivo: sem espera, a
    // segunda a chegar levaria SQLITE_BUSY em vez de esperar sua vez.
    database.execute('PRAGMA busy_timeout = 5000;');

    // WAL mantém leituras rápidas mesmo com a janela do Hub e o overlay
    // acessando o mesmo arquivo simultaneamente.
    database.execute('PRAGMA journal_mode = WAL;');
    database.execute('PRAGMA synchronous = NORMAL;');

    migrate(database);

    return _instance = AppDatabase._(database, directory.path);
  }

  /// Aplica as migrações pendentes. Público para que os testes possam preparar
  /// um banco em memória com o mesmo schema.
  ///
  /// Roda dentro de uma transação: as duas janelas do Evergreen abrem o banco
  /// ao mesmo tempo, e sem isso as duas poderiam ler o mesmo registro antigo e
  /// aplicar a mesma migração em seguida.
  static void migrate(Database database) {
    database.execute('BEGIN IMMEDIATE;');

    try {
      final currentVersion = _userVersion(database);
      final applied = _openLedger(database, currentVersion);

      for (final migration in _migrations.entries) {
        if (applied.contains(migration.key)) continue;

        _apply(database, migration.value);
        database.execute(
          'INSERT INTO schema_migrations (id, applied_at) VALUES (?, ?);',
          [migration.key, DateTime.now().millisecondsSinceEpoch],
        );
      }

      // `user_version` não manda mais em nada aqui — quem decide é o registro.
      // Continua sendo escrito só para um binário anterior a esta mudança, que
      // ainda conta migrações, encontrar um número alto e não tentar reaplicar
      // as suas por cima. Só avança, nunca retrocede.
      if (_migrations.length > currentVersion) {
        database.execute('PRAGMA user_version = ${_migrations.length};');
      }

      database.execute('COMMIT;');
    } catch (_) {
      database.execute('ROLLBACK;');
      rethrow;
    }
  }

  static int _userVersion(Database database) =>
      database.select('PRAGMA user_version;').first.values.first as int;

  /// Garante o registro de migrações aplicadas e devolve o que há nele.
  ///
  /// Um banco anterior a este registro só sabe dizer *quantas* migrações rodou,
  /// em [currentVersion]. Como até ali a ordem do arquivo era a ordem de
  /// aplicação, as primeiras [currentVersion] chaves são exatamente as que já
  /// rodaram: semeá-las converte o banco sem reaplicar nada. A contagem só
  /// decide este primeiro instante — daqui em diante quem responde "esta rodou?"
  /// é a chave, e branches paralelas deixam de colidir.
  static Set<String> _openLedger(Database database, int currentVersion) {
    database.execute('''
      CREATE TABLE IF NOT EXISTS schema_migrations (
        id         TEXT    PRIMARY KEY,
        applied_at INTEGER NOT NULL
      );
    ''');

    final applied = database
        .select('SELECT id FROM schema_migrations;')
        .map((row) => row['id'] as String)
        .toSet();

    if (applied.isNotEmpty || currentVersion == 0) return applied;

    for (final id in _migrations.keys.take(currentVersion)) {
      database.execute(
        'INSERT INTO schema_migrations (id, applied_at) VALUES (?, ?);',
        [id, DateTime.now().millisecondsSinceEpoch],
      );
      applied.add(id);
    }

    return applied;
  }

  /// Executa uma migração instrução a instrução.
  ///
  /// Uma de cada vez para que a tolerância abaixo não engula o resto do bloco:
  /// se o `ALTER TABLE` já tinha rodado, o `CREATE INDEX` seguinte ainda
  /// precisa rodar. O `split` é seguro porque migração é DDL — não há `;`
  /// dentro de literal de texto aqui.
  static void _apply(Database database, String migration) {
    final statements = migration
        .split(';')
        .map((statement) => statement.trim())
        .where((statement) => statement.isNotEmpty);

    for (final statement in statements) {
      try {
        database.execute(statement);
      } on SqliteException catch (error) {
        if (!_isAlreadyApplied(error)) rethrow;
      }
    }
  }

  /// A coluna já existe — ou seja, esta migração já rodou, mesmo que o registro
  /// diga o contrário. Rede para bancos que atravessaram a época em que a
  /// contagem de [_userVersion] mandava e podia descrever mal o que rodou;
  /// tolerar aqui é o que os conserta sozinhos.
  static bool _isAlreadyApplied(SqliteException error) =>
      error.message.contains('duplicate column name');

  void close() {
    db.close();
    _instance = null;
  }
}
