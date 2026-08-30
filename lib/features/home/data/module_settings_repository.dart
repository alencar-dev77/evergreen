import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/system/global_shortcut_slot.dart';
import '../../../core/system/shortcut_binding.dart';
import '../models/evergreen_module.dart';
import '../models/module_settings.dart';

/// Persistência de quais módulos estão ligados e de que tecla abre cada um.
///
/// Uma chave por módulo (`module.<nome>.enabled`) e uma por slot
/// (`shortcut.<nome>`), em vez de uma lista serializada: o dia em que um módulo
/// sai do enum, a chave dele fica órfã no plist sem quebrar a leitura dos
/// outros — e uma lista teria de ser lida inteira para responder "o Pin está
/// ligado?".
///
/// **Só grava o que difere do padrão.** Um módulo ligado não tem chave, e um
/// atalho intocado também não. Isso é o que faz a preferência sobreviver a uma
/// versão nova que mude a tecla de fábrica de algum módulo: quem nunca gravou
/// nada recebe a tecla nova; quem gravou continua com a dele.
class ModuleSettingsRepository {
  ModuleSettingsRepository(this._prefs);

  final SharedPreferences _prefs;

  /// Pelo [EvergreenModule.id], nunca pelo `name` — que neste enum é o nome de
  /// exibição.
  static String _enabledKey(EvergreenModule module) =>
      'module.${module.id}.enabled';

  ModuleSettings load() {
    final disabled = <EvergreenModule>{};
    for (final module in EvergreenModule.values) {
      if (_prefs.getBool(_enabledKey(module)) == false) disabled.add(module);
    }

    final custom = <GlobalShortcutSlot, ShortcutBinding>{};
    for (final slot in GlobalShortcutSlot.values) {
      final binding = ShortcutBinding.parse(_prefs.getString(slot.storageKey));
      if (binding != null) custom[slot] = binding;
    }

    return ModuleSettings(disabled: disabled, custom: custom);
  }

  Future<void> setEnabled(EvergreenModule module, {required bool enabled}) {
    // Ligado é a ausência da chave, não `true` gravado: ver a nota da classe.
    return enabled
        ? _prefs.remove(_enabledKey(module))
        : _prefs.setBool(_enabledKey(module), false);
  }

  Future<void> setBinding(GlobalShortcutSlot slot, ShortcutBinding binding) =>
      _prefs.setString(slot.storageKey, binding.storageValue);

  /// Volta o slot para a combinação de fábrica, apagando a chave.
  Future<void> clearBinding(GlobalShortcutSlot slot) =>
      _prefs.remove(slot.storageKey);

  /// Relê o que está no disco.
  ///
  /// Pela mesma razão do `AppSettingsRepository.reload`: isto aqui é escrito no
  /// Hub e lido no engine da janela 0, e cada engine tem a própria cópia em
  /// memória do `shared_preferences`. Sem reler, a janela 0 registraria os
  /// atalhos de antes da troca.
  Future<void> reload() => _prefs.reload();
}
