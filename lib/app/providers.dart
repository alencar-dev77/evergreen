import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/storage/app_database.dart';
import '../features/pin/data/clipboard_repository.dart';
import '../features/pin/data/clipboard_watcher.dart';
import '../features/pin/data/pin_settings_repository.dart';

/// Dependências resolvidas antes do `runApp` e injetadas via `overrides`.
///
/// Manter banco e preferências como providers sobrescritos evita `await` dentro
/// da árvore de widgets — a UI nunca precisa lidar com um estado "carregando
/// infraestrutura".
final appDatabaseProvider = Provider<AppDatabase>(
  (ref) => throw StateError('appDatabaseProvider precisa de override no main'),
);

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw StateError('sharedPreferencesProvider precisa de override no main'),
);

final clipboardRepositoryProvider = Provider<ClipboardRepository>(
  (ref) => SqliteClipboardRepository(ref.watch(appDatabaseProvider).db),
);

final pinSettingsRepositoryProvider = Provider<PinSettingsRepository>(
  (ref) => PinSettingsRepository(ref.watch(sharedPreferencesProvider)),
);

final clipboardWatcherProvider = Provider<ClipboardWatcher>((ref) {
  final watcher = ClipboardWatcher();
  ref.onDispose(watcher.dispose);
  return watcher;
});
