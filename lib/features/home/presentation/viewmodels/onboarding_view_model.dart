import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../shared/feature_flags.dart';
import '../../data/onboarding_repository.dart';
import '../../models/onboarding_step.dart';

final onboardingViewModelProvider =
    NotifierProvider<OnboardingViewModel, OnboardingState>(
      OnboardingViewModel.new,
    );

/// Onde a apresentação está: em qual passo, ou fora da tela.
class OnboardingState {
  const OnboardingState({required this.index, required this.visible});

  /// Passo atual em [OnboardingStep.all].
  final int index;

  final bool visible;

  OnboardingStep get step => OnboardingStep.all[index];

  int get total => OnboardingStep.all.length;

  bool get isLast => index == total - 1;
}

/// Conduz a apresentação de boas-vindas.
///
/// Avançar e pular terminam no mesmo lugar — a tela sai e a preferência é
/// gravada —, e é de propósito: quem pulou respondeu, não adiou.
class OnboardingViewModel extends Notifier<OnboardingState> {
  late final OnboardingRepository _repository;
  late final String _stamp;

  @override
  OnboardingState build() {
    _repository = ref.watch(onboardingRepositoryProvider);
    _stamp = ref.watch(buildStampProvider);

    // A bandeira responde antes do "já vi", e de propósito não o grava:
    // desligada, ela não consome a apresentação de ninguém.
    return OnboardingState(
      index: 0,
      visible: FeatureFlags.onboarding && _repository.shouldShow(_stamp),
    );
  }

  /// Avança; no último passo, encerra.
  Future<void> next() async {
    if (!state.visible) return;
    if (state.isLast) return finish();
    state = OnboardingState(index: state.index + 1, visible: true);
  }

  /// Volta um passo. Não fecha a apresentação no primeiro: sair é o que o
  /// "pular" faz, e uma tecla que às vezes volta e às vezes fecha é uma tecla
  /// que ninguém aperta com confiança.
  void previous() {
    if (!state.visible || state.index == 0) return;
    state = OnboardingState(index: state.index - 1, visible: true);
  }

  Future<void> finish() async {
    if (!state.visible) return;
    state = OnboardingState(index: state.index, visible: false);
    await _repository.markSeen(_stamp);
  }
}
