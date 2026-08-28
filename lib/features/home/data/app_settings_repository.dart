import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/design/app_theme_id.dart';
import '../models/app_settings.dart';

/// Persistência das preferências do aplicativo.
///
/// Chaves com prefixo `app.` porque não são de módulo nenhum — até a v0.2 elas
/// moravam no `pin.`, herança de quando o Pin era o único módulo.
class AppSettingsRepository {
  AppSettingsRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _userNameKey = 'app.user_name';
  static const _themeKey = 'app.theme';
  static const _launchAtLoginKey = 'app.launch_at_login';
  static const _startMinimizedKey = 'app.start_minimized';
  static const _automaticBackupKey = 'app.automatic_backup';

  AppSettings load() {
    const defaults = AppSettings();

    return AppSettings(
      theme: AppThemeId.fromName(_prefs.getString(_themeKey)),
      userName: _prefs.getString(_userNameKey) ?? defaults.userName,
      launchAtLogin:
          _prefs.getBool(_launchAtLoginKey) ?? defaults.launchAtLogin,
      startMinimized:
          _prefs.getBool(_startMinimizedKey) ?? defaults.startMinimized,
      automaticBackup:
          _prefs.getBool(_automaticBackupKey) ?? defaults.automaticBackup,
    );
  }

  Future<void> save(AppSettings settings) async {
    await Future.wait([
      _prefs.setString(_themeKey, settings.theme.name),
      _prefs.setString(_userNameKey, settings.userName),
      _prefs.setBool(_launchAtLoginKey, settings.launchAtLogin),
      _prefs.setBool(_startMinimizedKey, settings.startMinimized),
      _prefs.setBool(_automaticBackupKey, settings.automaticBackup),
    ]);
  }

  /// Relê o que está no disco.
  ///
  /// Existe pelo nome: ele é escrito na janela do Hub e lido no engine da
  /// janela 0, que é onde o resumo roda. Cada engine tem a sua cópia em
  /// memória do `shared_preferences`, então sem isto o primeiro resumo depois
  /// de a pessoa se apresentar sairia chamando ela de "a pessoa" ainda. É a
  /// mesma armadilha que a instrução do resumo já tinha.
  Future<void> reload() => _prefs.reload();
}
