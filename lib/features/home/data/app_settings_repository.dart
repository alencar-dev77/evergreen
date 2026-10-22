import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/local_model/local_model.dart';
import '../models/app_settings.dart';

/// Persistência das preferências do aplicativo.
///
/// Chaves com prefixo `app.` porque não são de módulo nenhum — até a v0.2 elas
/// moravam no `pin.`, herança de quando o Pin era o único módulo.
class AppSettingsRepository {
  AppSettingsRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _userNameKey = 'app.user_name';
  static const _launchAtLoginKey = 'app.launch_at_login';
  static const _startMinimizedKey = 'app.start_minimized';
  static const _automaticBackupKey = 'app.automatic_backup';
  static const _localModelSourceKey = 'app.local_model_source';
  static const _localModelIdKey = 'app.local_model_id';
  static const _localModelNameKey = 'app.local_model_name';

  AppSettings load() {
    const defaults = AppSettings();

    return AppSettings(
      userName: _prefs.getString(_userNameKey) ?? defaults.userName,
      launchAtLogin:
          _prefs.getBool(_launchAtLoginKey) ?? defaults.launchAtLogin,
      startMinimized:
          _prefs.getBool(_startMinimizedKey) ?? defaults.startMinimized,
      automaticBackup:
          _prefs.getBool(_automaticBackupKey) ?? defaults.automaticBackup,
      localModel: LocalModelChoice(
        source: LocalModelSource.fromId(_prefs.getString(_localModelSourceKey)),
        modelId: _prefs.getString(_localModelIdKey) ?? '',
        modelName: _prefs.getString(_localModelNameKey) ?? '',
      ),
    );
  }

  Future<void> save(AppSettings settings) async {
    await Future.wait([
      _prefs.setString(_userNameKey, settings.userName),
      _prefs.setBool(_launchAtLoginKey, settings.launchAtLogin),
      _prefs.setBool(_startMinimizedKey, settings.startMinimized),
      _prefs.setBool(_automaticBackupKey, settings.automaticBackup),
      _saveLocalModel(settings.localModel),
    ]);
  }

  /// Só o que difere do padrão vai para o disco: com o Apple Intelligence as
  /// três chaves somem, e uma versão que mude o padrão alcança quem nunca
  /// escolheu nada.
  Future<void> _saveLocalModel(LocalModelChoice choice) async {
    if (choice.source == LocalModelSource.apple) {
      await Future.wait([
        _prefs.remove(_localModelSourceKey),
        _prefs.remove(_localModelIdKey),
        _prefs.remove(_localModelNameKey),
      ]);
      return;
    }

    await Future.wait([
      _prefs.setString(_localModelSourceKey, choice.source.id),
      _prefs.setString(_localModelIdKey, choice.modelId),
      _prefs.setString(_localModelNameKey, choice.modelName),
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
