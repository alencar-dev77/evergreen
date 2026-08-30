import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../data/pin_settings_repository.dart';
import '../../models/clipboard_item_type.dart';
import '../../models/pin_settings.dart';
import 'accessibility_permission_view_model.dart';

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

  /// Liga/desliga o auto-colar. Ao ligar, pede a permissão de Acessibilidade —
  /// sem ela o macOS não deixa sintetizar o ⌘V. A preferência é salva de todo
  /// jeito: reflete a intenção, e o colar passa a funcionar assim que a
  /// permissão for concedida.
  Future<void> setAutoPaste(bool value) async {
    if (value) {
      await ref.read(accessibilityPermissionProvider.notifier).request();
    }
    await _update(state.copyWith(autoPaste: value));
  }

  Future<void> setHistoryLimit(int value) =>
      _update(state.copyWith(historyLimit: value));

  /// Liga ou desliga a captura de um tipo.
  ///
  /// Desligar não apaga o que já entrou: os itens daquele tipo continuam no
  /// histórico e continuam buscáveis. O que muda é o que passa a **não** ser
  /// registrado daqui para a frente — apagar o passado é outra ação, e ela tem
  /// o cartão dela.
  Future<void> setTypeCaptured(
    ClipboardItemType type, {
    required bool captured,
  }) {
    final ignored = {...state.ignoredTypes};
    if (captured) {
      ignored.remove(type);
    } else {
      ignored.add(type);
    }

    return _update(state.copyWith(ignoredTypes: ignored));
  }

  Future<void> _update(PinSettings settings) async {
    state = settings;
    await _repository.save(settings);
  }
}
