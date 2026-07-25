import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';

/// Persistência das preferências do aplicativo.
///
/// Chaves com prefixo `app.` porque não são de módulo nenhum — até a v0.2 elas
/// moravam no `pin.`, herança de quando o Pin era o único módulo.
class AppSettingsRepository {
  AppSettingsRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _launchAtLoginKey = 'app.launch_at_login';
  static const _startMinimizedKey = 'app.start_minimized';

  AppSettings load() {
    const defaults = AppSettings();

    return AppSettings(
      launchAtLogin: _prefs.getBool(_launchAtLoginKey) ?? defaults.launchAtLogin,
      startMinimized:
          _prefs.getBool(_startMinimizedKey) ?? defaults.startMinimized,
    );
  }

  Future<void> save(AppSettings settings) async {
    await Future.wait([
      _prefs.setBool(_launchAtLoginKey, settings.launchAtLogin),
      _prefs.setBool(_startMinimizedKey, settings.startMinimized),
    ]);
  }
}
