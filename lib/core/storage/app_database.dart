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
  ];

  /// Abre (ou reaproveita) a conexão com o banco.
  static Future<AppDatabase> open() async {
    if (_instance != null) return _instance!;

    final directory = await getApplicationSupportDirectory();
    await directory.create(recursive: true);

    final database = sqlite3.open(p.join(directory.path, _fileName));

    // WAL mantém leituras rápidas mesmo com a janela do Hub e o overlay
    // acessando o mesmo arquivo simultaneamente.
    database.execute('PRAGMA journal_mode = WAL;');
    database.execute('PRAGMA synchronous = NORMAL;');

    migrate(database);

    return _instance = AppDatabase._(database);
  }

  /// Aplica as migrações pendentes. Público para que os testes possam preparar
  /// um banco em memória com o mesmo schema.
  static void migrate(Database database) {
    final currentVersion =
        database.select('PRAGMA user_version;').first.values.first as int;

    for (var version = currentVersion; version < _migrations.length; version++) {
      database.execute(_migrations[version]);
    }

    database.execute('PRAGMA user_version = ${_migrations.length};');
  }

  void close() {
    db.close();
    _instance = null;
  }
}
