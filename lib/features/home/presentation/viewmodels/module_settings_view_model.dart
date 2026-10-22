import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../core/system/global_shortcut_slot.dart';
import '../../../../core/system/module_settings_host.dart';
import '../../../../core/system/shortcut_binding.dart';
import '../../../../core/system/shortcut_rules.dart';
import '../../data/module_settings_repository.dart';
import '../../models/evergreen_module.dart';
import '../../models/module_settings.dart';

final moduleSettingsViewModelProvider =
    NotifierProvider<ModuleSettingsViewModel, ModuleSettings>(
      ModuleSettingsViewModel.new,
    );

/// Quais módulos estão ligados e que tecla abre cada um.
///
/// Escrita imediata, como toda preferência do Evergreen — e, diferente das
/// outras, **com um segundo passo**: além de gravar no disco, cada mudança
/// avisa a janela 0, que é quem tem os atalhos registrados no sistema e o
/// ícone da barra de menus na mão. Ver [ModuleSettingsHost].
class ModuleSettingsViewModel extends Notifier<ModuleSettings> {
  late final ModuleSettingsRepository _repository;
  late final ModuleSettingsNotifier _notifier;

  @override
  ModuleSettings build() {
    _repository = ref.watch(moduleSettingsRepositoryProvider);
    _notifier = ref.watch(moduleSettingsNotifierProvider);
    return _repository.load();
  }

  Future<void> setEnabled(
    EvergreenModule module, {
    required bool enabled,
  }) async {
    final disabled = Set<EvergreenModule>.of(state.disabled);
    if (enabled) {
      disabled.remove(module);
    } else {
      disabled.add(module);
    }

    state = state.copyWith(disabled: disabled);
    await _repository.setEnabled(module, enabled: enabled);
    await _notifier.reapply();
  }

  /// Tenta gravar [binding] em [slot].
  ///
  /// Devolve o motivo da recusa, ou `null` quando gravou. Quem chama é o
  /// gravador da tela, que mostra o motivo e continua esperando outra
  /// combinação — recusar e sair obrigaria a começar de novo por um `⌘C`
  /// digitado sem pensar.
  Future<String?> record(
    GlobalShortcutSlot slot,
    ShortcutBinding binding,
  ) async {
    final refusal = ShortcutRules.refuse(
      binding,
      slot: slot,
      taken: state.allBindings,
      ownerOf: ownerOf,
    );
    if (refusal != null) return refusal;

    final custom = Map<GlobalShortcutSlot, ShortcutBinding>.of(state.custom);
    // Gravar de volta a combinação de fábrica é o mesmo que restaurar: sem
    // isto, o slot ficaria marcado como "trocado" mostrando exatamente o padrão,
    // com um botão "Restaurar padrão" que não faria diferença nenhuma.
    if (binding == slot.fallback) {
      custom.remove(slot);
      await _repository.clearBinding(slot);
    } else {
      custom[slot] = binding;
      await _repository.setBinding(slot, binding);
    }

    state = state.copyWith(custom: custom);
    await _notifier.reapply();
    return null;
  }

  /// Volta o slot para a combinação de fábrica.
  Future<void> restoreDefault(GlobalShortcutSlot slot) async {
    if (!state.isCustom(slot)) return;

    final custom = Map<GlobalShortcutSlot, ShortcutBinding>.of(state.custom)
      ..remove(slot);

    state = state.copyWith(custom: custom);
    await _repository.clearBinding(slot);
    await _notifier.reapply();
  }

  /// Tira os atalhos globais do sistema enquanto a tela grava um novo, e os
  /// devolve depois. Ver [ModuleSettingsHost.setSuspended].
  Future<void> setRecording({required bool recording}) =>
      _notifier.setSuspended(suspended: recording);

  /// Como uma recusa por conflito aponta o dono da tecla.
  ///
  /// Já com a preposição — "do Pin", "das preferências" —, porque em português
  /// ela muda com o artigo: montá-la do lado das regras daria "o atalho de o
  /// Pin". A frase inteira é "⌘⇧C já é o atalho do Pin", e ela existe para
  /// dizer onde ir desfazer aquilo.
  static String ownerOf(GlobalShortcutSlot slot) {
    if (slot == GlobalShortcutSlot.hub) return 'das preferências';

    for (final module in EvergreenModule.values) {
      if (module.shortcutSlot == slot) return 'do ${module.name}';
    }

    return 'de ${slot.name}';
  }
}
