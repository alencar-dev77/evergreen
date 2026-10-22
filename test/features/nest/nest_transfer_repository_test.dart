import 'package:evergreen/core/storage/app_database.dart';
import 'package:evergreen/features/nest/data/nest_transfer_repository.dart';
import 'package:evergreen/features/nest/models/nest_transfer.dart';
import 'package:evergreen/features/nest/models/nest_transfer_mode.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Database db;

  setUp(() {
    db = sqlite3.openInMemory();
    AppDatabase.migrate(db);
  });

  tearDown(() => db.close());

  List<int> movedAt() => db
      .select('SELECT moved_at FROM nest_transfers ORDER BY moved_at;')
      .map((row) => row['moved_at'] as int)
      .toList();

  NestTransfer at(DateTime when) => NestTransfer(
    at: when,
    mode: NestTransferMode.copy,
    destinationPath: '/destino',
    movements: const [NestMovement(source: '/a.txt', destination: '/b.txt')],
  );

  // Quarta-feira, 22/10/2026: a janela começa na segunda de três semanas atrás.
  final now = DateTime(2026, 10, 22, 15);
  final windowStart = DateTime(2026, 9, 28);

  test('gravar tira o que ficou antes das semanas que o Track lê', () {
    final repository = SqliteNestTransferRepository(db);
    final old = windowStart.subtract(const Duration(minutes: 1));
    final kept = windowStart.add(const Duration(minutes: 1));

    repository.insert(at(old));
    repository.insert(at(kept));
    final id = repository.insert(at(now));

    expect(movedAt(), [
      kept.millisecondsSinceEpoch,
      now.millisecondsSinceEpoch,
    ]);
    // O número devolvido ainda é o da linha gravada — é com ele que o `⌘Z`
    // desfaz.
    repository.delete(id);
    expect(movedAt(), [kept.millisecondsSinceEpoch]);
  });
}
