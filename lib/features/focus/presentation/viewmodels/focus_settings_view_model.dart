import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../data/focus_settings_repository.dart';
import '../../models/focus_settings.dart';

final focusSettingsViewModelProvider =
    NotifierProvider<FocusSettingsViewModel, FocusSettings>(
  FocusSettingsViewModel.new,
);

/// Preferências do Focus, com escrita imediata.
///
/// Igual ao Pin: mexer no controle já persiste. Não existe botão de salvar nem
/// confirmação de "salvo" — o próprio controle mudando é o feedback.
class FocusSettingsViewModel extends Notifier<FocusSettings> {
  late final FocusSettingsRepository _repository;

  @override
  FocusSettings build() {
    _repository = ref.watch(focusSettingsRepositoryProvider);
    return _repository.load();
  }

  Future<void> setFocusMinutes(int value) =>
      _update(state.copyWith(focusMinutes: value));

  Future<void> setBreakMinutes(int value) =>
      _update(state.copyWith(breakMinutes: value));

  Future<void> setPomodoroOnly(bool value) =>
      _update(state.copyWith(pomodoroOnly: value));

  Future<void> setAskActivity(bool value) =>
      _update(state.copyWith(askActivity: value));

  Future<void> setAskSummary(bool value) =>
      _update(state.copyWith(askSummary: value));

  Future<void> setPlaySound(bool value) =>
      _update(state.copyWith(playSound: value));

  Future<void> setAlertOnScreen(bool value) =>
      _update(state.copyWith(alertOnScreen: value));

  Future<void> _update(FocusSettings settings) async {
    state = settings;
    await _repository.save(settings);
  }
}
