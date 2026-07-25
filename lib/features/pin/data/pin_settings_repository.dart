import 'package:shared_preferences/shared_preferences.dart';

import '../models/pin_settings.dart';

/// Persistência das preferências do Pin.
///
/// Preferências são poucas e pequenas, então `SharedPreferences` (plist nativo
/// no macOS) é mais adequado que o banco — e continua tudo local.
class PinSettingsRepository {
  PinSettingsRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _historyLimitKey = 'pin.history_limit';
  static const _autoPasteKey = 'pin.auto_paste';

  PinSettings load() {
    const defaults = PinSettings();

    return PinSettings(
      historyLimit: _prefs.getInt(_historyLimitKey) ?? defaults.historyLimit,
      autoPaste: _prefs.getBool(_autoPasteKey) ?? defaults.autoPaste,
    );
  }

  /// Relê o cache do `SharedPreferences` a partir do plist nativo.
  ///
  /// O overlay do Pin e o Hub rodam em engines Flutter separados, cada um com
  /// seu próprio cache em memória. Sem um `reload`, uma preferência alterada no
  /// Hub só chegaria ao overlay num relançamento — inaceitável para o auto-colar,
  /// que precisa refletir o toggle na hora.
  Future<void> reload() => _prefs.reload();

  Future<void> save(PinSettings settings) async {
    await Future.wait([
      _prefs.setInt(_historyLimitKey, settings.historyLimit),
      _prefs.setBool(_autoPasteKey, settings.autoPaste),
    ]);
  }
}
