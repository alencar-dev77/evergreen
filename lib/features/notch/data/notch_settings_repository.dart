import 'package:shared_preferences/shared_preferences.dart';

import '../models/notch_settings.dart';

/// Persistência do que cada módulo faz no notch.
///
/// Uma chave por módulo (`notch.<id>`), escrita só quando difere do padrão —
/// ligado não tem chave. É o mesmo raciocínio do `ModuleSettingsRepository`.
class NotchSettingsRepository {
  NotchSettingsRepository(this._prefs);

  final SharedPreferences _prefs;

  static String _key(NotchModule module) => 'notch.${module.id}';

  NotchSettings load() => NotchSettings(
    disabled: {
      for (final module in NotchModule.values)
        if (_prefs.getBool(_key(module)) == false) module,
    },
  );

  /// Relê o plist: quem escreve é o Hub, e quem aplica na abertura é a
  /// janela 0, que é outro engine.
  Future<void> reload() => _prefs.reload();

  Future<void> save(NotchModule module, {required bool enabled}) => enabled
      ? _prefs.remove(_key(module))
      : _prefs.setBool(_key(module), false);
}
