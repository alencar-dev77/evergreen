import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

/// Acesso ao banco SQLite local do Evergreen.
///
/// Um único arquivo `evergreen.db` guarda os dados de todos os módulos; cada
/// feature é dona das suas tabelas e registra as próprias migrações em
/// [_migrations]. Nada sai da máquina.
class AppDatabase {
  AppDatabase._(this.db);

  final Database db;

  static AppDatabase? _instance;

  /// Nome do arquivo dentro de `~/Library/Application Support/<bundle>`.
  static const _fileName = 'evergreen.db';

  /// Migrações indexadas pela versão que produzem. Para evoluir o schema,
  /// acrescente uma nova entrada — nunca edite uma já publicada.
  static const _migrations = <String>[
    '''
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
    '''
    ALTER TABLE clipboard_items ADD COLUMN pinned_at INTEGER;
    UPDATE clipboard_items SET pinned_at = copied_at WHERE is_pinned = 1;
    CREATE INDEX IF NOT EXISTS idx_clipboard_pinned
      ON clipboard_items (is_pinned DESC, pinned_at ASC);
    ''',
    // Histórico do Focus. Guardamos o início e o tempo efetivamente focado, e
    // não o fim: com pausas os dois não se derivam um do outro, e o fim não
    // aparece em lugar nenhum da interface — o histórico mostra "quando começou"
    // e "quanto durou".
    '''
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
    '''
    ALTER TABLE focus_sessions ADD COLUMN notes TEXT;
    ''',
  ];

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

    return _instance = AppDatabase._(database);
  }

  /// Aplica as migrações pendentes. Público para que os testes possam preparar
  /// um banco em memória com o mesmo schema.
  ///
  /// Roda dentro de uma transação: as duas janelas do Evergreen abrem o banco
  /// ao mesmo tempo, e sem isso as duas poderiam ler a mesma versão antiga e
  /// aplicar a mesma migração em seguida.
  static void migrate(Database database) {
    database.execute('BEGIN IMMEDIATE;');

    try {
      final currentVersion = _userVersion(database);

      for (var version = currentVersion;
          version < _migrations.length;
          version++) {
        _apply(database, _migrations[version]);
      }

      // Só avança, nunca retrocede. Escrever o número às cegas fazia um binário
      // antigo (com menos migrações) rebobinar a versão de um banco já
      // migrado — e o binário novo, na abertura seguinte, tentava aplicar de
      // novo uma migração que já estava lá.
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

  /// A coluna já existe — ou seja, esta migração já rodou, mesmo que a versão
  /// gravada diga o contrário. Acontece em bancos que passaram pelo bug de
  /// versão descrito em [migrate]; tolerar aqui é o que os conserta sozinhos.
  static bool _isAlreadyApplied(SqliteException error) =>
      error.message.contains('duplicate column name');

  void close() {
    db.close();
    _instance = null;
  }
}
