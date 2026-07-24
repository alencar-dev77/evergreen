import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../core/system/previous_app_focus_channel.dart';
import '../../../../core/system/startup_service.dart';
import '../../data/pin_settings_repository.dart';
import '../../models/pin_settings.dart';

final pinSettingsViewModelProvider =
    NotifierProvider<PinSettingsViewModel, PinSettings>(
  PinSettingsViewModel.new,
);

/// Preferências do Pin, com escrita imediata.
///
/// Cada alteração persiste na hora — a tela de configurações não tem botão de
/// salvar, e o usuário nunca deve perder um ajuste ao fechar a janela.
class PinSettingsViewModel extends Notifier<PinSettings> {
  late final PinSettingsRepository _repository;

  @override
  PinSettings build() {
    _repository = ref.watch(pinSettingsRepositoryProvider);
    return _repository.load();
  }

  /// Só grava o que o sistema aceitou: se o macOS recusar o item de início, o
  /// toggle volta sozinho em vez de mentir para o usuário.
  Future<void> setLaunchAtLogin(bool value) async {
    final applied = await StartupService.instance.setEnabled(enabled: value);
    await _update(state.copyWith(launchAtLogin: applied));
  }

  /// Adota o estado que o sistema já tem, sem tentar alterá-lo.
  ///
  /// Usado na inicialização: o usuário pode ter removido o Evergreen dos itens
  /// de início pelos Ajustes do macOS, e é o sistema que manda.
  Future<void> adoptSystemLaunchAtLogin(bool value) async {
    if (state.launchAtLogin == value) return;
    await _update(state.copyWith(launchAtLogin: value));
  }

  Future<void> setStartMinimized(bool value) =>
      _update(state.copyWith(startMinimized: value));

  /// Liga/desliga o auto-colar. Ao ligar, pede a permissão de Acessibilidade —
  /// sem ela o macOS não deixa sintetizar o ⌘V. A preferência é salva de todo
  /// jeito: reflete a intenção, e o colar passa a funcionar assim que a
  /// permissão for concedida.
  Future<void> setAutoPaste(bool value) async {
    if (value) {
      await PreviousAppFocusChannel.requestAccessibilityPermission();
    }
    await _update(state.copyWith(autoPaste: value));
  }

  Future<void> setHistoryLimit(int value) =>
      _update(state.copyWith(historyLimit: value));

  Future<void> _update(PinSettings settings) async {
    state = settings;
    await _repository.save(settings);
  }
}
