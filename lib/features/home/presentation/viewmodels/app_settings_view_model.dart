import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../core/system/startup_service.dart';
import '../../data/app_settings_repository.dart';
import '../../models/app_settings.dart';

final appSettingsViewModelProvider =
    NotifierProvider<AppSettingsViewModel, AppSettings>(
      AppSettingsViewModel.new,
    );

/// Preferências do aplicativo, com escrita imediata — mesma regra dos módulos:
/// mexer no controle já persiste, sem botão de salvar.
class AppSettingsViewModel extends Notifier<AppSettings> {
  late final AppSettingsRepository _repository;

  @override
  AppSettings build() {
    _repository = ref.watch(appSettingsRepositoryProvider);
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

  /// Guardado sem espaço sobrando: o nome vira rótulo de quem falou na
  /// transcrição e entra na instrução que vai para o modelo, e nos dois lugares
  /// um espaço à toa aparece.
  Future<void> setUserName(String value) =>
      _update(state.copyWith(userName: value.trim()));

  Future<void> setStartMinimized(bool value) =>
      _update(state.copyWith(startMinimized: value));

  Future<void> setAutomaticBackup(bool value) =>
      _update(state.copyWith(automaticBackup: value));

  /// Relê as preferências do disco e adota o que achar.
  ///
  /// Existe para a janela flutuante: ela roda em outro engine, com a própria
  /// cópia em memória do `shared_preferences`, e não fica sabendo que a
  /// aparência mudou no Hub. Sem isto, o painel do Pin continuaria no tema
  /// antigo até o app reiniciar — e é justamente o painel que a pessoa abre
  /// logo depois de trocar, para ver como ficou.
  Future<void> refreshFromDisk() async {
    await _repository.reload();
    state = _repository.load();
  }

  Future<void> _update(AppSettings settings) async {
    state = settings;
    await _repository.save(settings);
  }
}
