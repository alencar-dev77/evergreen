import 'package:shared_preferences/shared_preferences.dart';

import '../models/clipboard_item_type.dart';
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
  static const _ignoredTypesKey = 'pin.ignored_types';

  PinSettings load() {
    const defaults = PinSettings();

    return PinSettings(
      historyLimit: _prefs.getInt(_historyLimitKey) ?? defaults.historyLimit,
      autoPaste: _prefs.getBool(_autoPasteKey) ?? defaults.autoPaste,
      ignoredTypes: _readIgnored(),
    );
  }

  /// Relê o cache do `SharedPreferences` a partir do plist nativo.
  ///
  /// O overlay do Pin e o Hub rodam em engines Flutter separados, cada um com
  /// seu próprio cache em memória. Sem um `reload`, uma preferência alterada no
  /// Hub só chegaria ao overlay num relançamento — inaceitável para o auto-colar,
  /// que precisa refletir o toggle na hora.
  Future<void> reload() => _prefs.reload();

  /// Lê a lista do disco desprezando nome que não existe mais.
  ///
  /// Um tipo pode sair do classificador entre duas versões, e a preferência de
  /// quem o tinha desligado continua no plist. Ignorar o nome desconhecido é o
  /// que impede uma preferência velha de derrubar a leitura inteira.
  Set<ClipboardItemType> _readIgnored() {
    final stored = _prefs.getStringList(_ignoredTypesKey);
    if (stored == null) return const <ClipboardItemType>{};

    return {
      for (final name in stored)
        for (final type in ClipboardItemType.values)
          if (type.name == name) type,
    };
  }

  Future<void> save(PinSettings settings) async {
    await Future.wait([
      _prefs.setInt(_historyLimitKey, settings.historyLimit),
      _prefs.setBool(_autoPasteKey, settings.autoPaste),
      _prefs.setStringList(_ignoredTypesKey, [
        for (final type in settings.ignoredTypes) type.name,
      ]),
    ]);
  }
}
