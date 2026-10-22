import 'package:evergreen/core/storage/app_database.dart';
import 'package:evergreen/features/awake/data/awake_session_repository.dart';
import 'package:evergreen/features/awake/models/awake_mode.dart';
import 'package:evergreen/features/awake/models/awake_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Database db;

  setUp(() {
    db = sqlite3.openInMemory();
    AppDatabase.migrate(db);
  });

  tearDown(() => db.close());

  List<int> startedAt() => db
      .select('SELECT started_at FROM awake_sessions ORDER BY started_at;')
      .map((row) => row['started_at'] as int)
      .toList();

  AwakeSession at(DateTime when) => AwakeSession(
    startedAt: when,
    duration: const Duration(hours: 1),
    mode: AwakeMode.screen,
  );

  // Quarta-feira, 22/10/2026: a janela começa na segunda de três semanas atrás.
  final now = DateTime(2026, 10, 22, 15);
  final windowStart = DateTime(2026, 9, 28);

  test('gravar tira o que ficou antes das semanas que o Track lê', () {
    final repository = SqliteAwakeSessionRepository(db);
    final old = windowStart.subtract(const Duration(minutes: 1));
    final kept = windowStart.add(const Duration(minutes: 1));

    repository.insert(at(old));
    repository.insert(at(kept));
    repository.insert(at(now));

    expect(startedAt(), [
      kept.millisecondsSinceEpoch,
      now.millisecondsSinceEpoch,
    ]);
  });
}
