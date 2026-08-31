import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../core/system/module_settings_host.dart';
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

  late final ModuleSettingsNotifier _notifier;

  @override
  PinSettings build() {
    _repository = ref.watch(pinSettingsRepositoryProvider);
    _notifier = ref.watch(moduleSettingsNotifierProvider);

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

  /// Liga ou desliga um tipo.
  ///
  /// Desligar tira o tipo **do Pin**: ele deixa de ser registrado daqui para a
  /// frente e some do painel — da lista e da fila de filtros —, na abertura
  /// seguinte. Um tipo desligado que continuasse aparecendo seria a tela
  /// dizendo uma coisa e o painel fazendo outra.
  ///
  /// O que já está no banco **não é apagado**: religar o tipo devolve o
  /// histórico dele inteiro, e apagar de vez continua sendo o cartão de apagar
  /// histórico — que pergunta antes.
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

    // Gravar no disco não avisa ninguém, e quem captura a área de transferência
    // é a janela 0 — outro engine, com a própria cópia em memória das
    // preferências. Sem esta ponte, desligar um tipo só valia no lançamento
    // seguinte: o Pin continuava guardando o que a tela dizia estar desligado.
    await _notifier.reapply();
  }
}
