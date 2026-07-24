import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/evergreen_app.dart';
import 'app/evergreen_bootstrap.dart';
import 'app/providers.dart';
import 'core/storage/app_database.dart';
import 'core/window/pin_overlay_window.dart';
import 'core/window/window_kind.dart';

/// Ponto de entrada de todas as janelas do Evergreen.
///
/// Cada janela roda um engine Flutter próprio e executa este mesmo `main`. O
/// argumento recebido pelo engine diz qual painel construir; a janela 0 (sem
/// argumento) é o overlay do Pin e também hospeda os serviços de background.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final window = await WindowController.fromCurrentEngine();
  final kind = WindowKind.fromArguments(window.arguments);

  final container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(await AppDatabase.open()),
      sharedPreferencesProvider.overrideWithValue(
        await SharedPreferences.getInstance(),
      ),
    ],
  );

  if (kind == WindowKind.pinOverlay) {
    await PinOverlayWindow.instance.configure();
    await EvergreenBootstrap(container).start();
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: EvergreenApp(kind: kind),
    ),
  );
}
