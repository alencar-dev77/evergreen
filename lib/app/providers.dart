import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/storage/app_database.dart';
import '../core/window/overlay_panel.dart';
import '../features/awake/data/awake_settings_repository.dart';
import '../features/awake/data/display_sleep_service.dart';
import '../features/focus/data/focus_session_repository.dart';
import '../features/focus/data/focus_settings_repository.dart';
import '../features/home/data/app_settings_repository.dart';
import '../features/leaf/data/leaf_repository.dart';
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

final appSettingsRepositoryProvider = Provider<AppSettingsRepository>(
  (ref) => AppSettingsRepository(ref.watch(sharedPreferencesProvider)),
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

/// Relógio da aplicação.
///
/// É uma dependência como outra qualquer: o cronômetro do Focus mede tempo
/// real, e sem esta costura não daria para verificar uma sessão de 25 minutos
/// sem esperar 25 minutos.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final focusSessionRepositoryProvider = Provider<FocusSessionRepository>(
  (ref) => SqliteFocusSessionRepository(ref.watch(appDatabaseProvider).db),
);

final focusSettingsRepositoryProvider = Provider<FocusSettingsRepository>(
  (ref) => FocusSettingsRepository(ref.watch(sharedPreferencesProvider)),
);

final awakeSettingsRepositoryProvider = Provider<AwakeSettingsRepository>(
  (ref) => AwakeSettingsRepository(ref.watch(sharedPreferencesProvider)),
);

final leafRepositoryProvider = Provider<LeafRepository>(
  (ref) => SqliteLeafRepository(ref.watch(appDatabaseProvider).db),
);

/// A trava que impede o display de dormir.
///
/// Provider (e não uma instância global) porque é o que o teste substitui para
/// verificar o cronômetro do Awake sem tocar no IOKit.
final displaySleepServiceProvider = Provider<DisplaySleepService>(
  (ref) => WakelockDisplaySleepService(),
);

/// Painel que a janela flutuante está mostrando.
///
/// Só faz sentido no engine da janela 0, o único que desenha o overlay: o
/// atalho global de cada módulo escreve aqui antes de mandar a janela aparecer.
final overlayPanelProvider =
    NotifierProvider<OverlayPanelController, OverlayPanel>(
  OverlayPanelController.new,
);

class OverlayPanelController extends Notifier<OverlayPanel> {
  @override
  OverlayPanel build() => OverlayPanel.pin;

  void show(OverlayPanel panel) => state = panel;
}
