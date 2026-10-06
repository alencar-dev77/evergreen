import 'package:evergreen/core/storage/app_database.dart';
import 'package:evergreen/features/focus/data/focus_session_repository.dart';
import 'package:evergreen/features/focus/models/focus_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

/// O que o disco do Focus guarda, e o que a tela dele mostra.
///
/// São duas janelas diferentes de propósito: a tela é da semana corrente, e o
/// disco guarda [FocusSessionRepository.keptWeeks] semanas para o Track
/// conseguir reconstruir as anteriores.
void main() {
  late Database db;
  late SqliteFocusSessionRepository repository;

  /// Quarta-feira. A segunda desta semana é 17/08.
  final now = DateTime(2026, 8, 19, 15, 30);

  setUp(() {
    db = sqlite3.openInMemory();
    AppDatabase.migrate(db);
    repository = SqliteFocusSessionRepository(db);
  });

  tearDown(() => db.close());

  void insert(DateTime startedAt) => repository.insert(
    FocusSession(startedAt: startedAt, duration: const Duration(minutes: 25)),
  );

  int stored() =>
      db.select('SELECT COUNT(*) AS n FROM focus_sessions;').first['n'] as int;

  test('a virada guarda as semanas que o Track lê e apaga o resto', () {
    final oldestKept = FocusSessionRepository.keptSince(now);
    expect(oldestKept, DateTime(2026, 7, 27));

    insert(now);
    insert(DateTime(2026, 8, 11, 9)); // semana passada
    insert(oldestKept); // primeiro minuto da semana mais antiga guardada
    insert(oldestKept.subtract(const Duration(minutes: 1)));

    repository.trimOldWeeks(now: now);

    expect(stored(), 3);
  });

  test('a lista e os totais do Focus continuam sendo da semana corrente', () {
    insert(now);
    insert(DateTime(2026, 8, 11, 9));

    repository.trimOldWeeks(now: now);

    expect(repository.loadRecent(now: now), hasLength(1));
    expect(repository.stats(now: now).week, const Duration(minutes: 25));
  });
}
