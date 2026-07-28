import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../data/awake_settings_repository.dart';
import '../../models/awake_duration.dart';
import '../../models/awake_settings.dart';

final awakeSettingsViewModelProvider =
    NotifierProvider<AwakeSettingsViewModel, AwakeSettings>(
  AwakeSettingsViewModel.new,
);

/// Preferências do Awake, com escrita imediata.
///
/// Igual ao Pin e ao Focus: mexer no controle já persiste, sem botão de salvar
/// e sem confirmação de "salvo".
class AwakeSettingsViewModel extends Notifier<AwakeSettings> {
  late final AwakeSettingsRepository _repository;

  @override
  AwakeSettings build() {
    _repository = ref.watch(awakeSettingsRepositoryProvider);
    return _repository.load();
  }

  Future<void> setDefaultDuration(AwakeDuration value) async {
    state = state.copyWith(defaultDuration: value);
    await _repository.save(state);
  }
}
