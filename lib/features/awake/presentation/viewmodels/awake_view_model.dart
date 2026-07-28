import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../data/awake_settings_repository.dart';
import '../../data/display_sleep_service.dart';
import '../../models/awake_duration.dart';
import 'awake_state.dart';

final awakeViewModelProvider =
    NotifierProvider<AwakeViewModel, AwakeState>(AwakeViewModel.new);

/// Segura a tela acesa pelo prazo escolhido.
///
/// Vive no engine da janela flutuante, que nunca é destruído — é o que faz a
/// trava continuar valendo com o painel fechado, igual ao cronômetro do Focus.
class AwakeViewModel extends Notifier<AwakeState> {
  late final AwakeSettingsRepository _settingsRepository;
  late final DisplaySleepService _display;
  late final DateTime Function() _now;

  Timer? _ticker;

  /// Instante em que a trava se solta sozinha. A contagem é derivada dele a
  /// cada tique, e não subtraída de um contador: assim uma suspensão do Mac
  /// não "congela" o prazo.
  DateTime? _endsAt;

  /// Um tique por segundo basta: o painel mostra segundos e o menu, minutos.
  static const _tick = Duration(seconds: 1);

  @override
  AwakeState build() {
    _settingsRepository = ref.watch(awakeSettingsRepositoryProvider);
    _display = ref.watch(displaySleepServiceProvider);
    _now = ref.watch(clockProvider);

    ref.onDispose(() {
      _stopTicker();
      // A trava é do processo, não do provider: soltá-la aqui evita deixar a
      // tela acesa se este container morrer antes do app.
      unawaited(_display.disable());
    });

    return AwakeState.off(_settingsRepository.load());
  }

  /// Relê as preferências antes de o painel aparecer.
  ///
  /// Elas são editadas no Hub, que roda em outro engine. Com a trava ligada a
  /// duração em curso é mantida: trocar o prazo debaixo de quem já ligou seria
  /// mexer no que está acontecendo.
  Future<void> prepareForOpen() async {
    await _settingsRepository.reload();
    final settings = _settingsRepository.load();

    state = state.isOn
        ? state.copyWith(settings: settings)
        : AwakeState.off(settings);
  }

  /// Troca a duração escolhida.
  ///
  /// Com a trava ligada, o prazo novo vale a partir de agora — quem escolhe
  /// "2 h" no meio de uma hora está pedindo mais duas horas, não o resto da
  /// anterior. "Sem limite" simplesmente tira o prazo.
  Future<void> selectDuration(AwakeDuration duration) async {
    if (duration == state.duration) return;

    state = state.copyWith(duration: duration, clearRemaining: true);
    if (state.isOn) await _startDeadline();
  }

  /// Anda uma opção para o lado na escala de durações (`←` / `→`).
  ///
  /// Para nas pontas em vez de dar a volta: a lista é curta e visível inteira,
  /// e uma seta que salta de "30 min" para "Sempre" faria a escolha passar
  /// direto pelo que a pessoa procurava.
  Future<void> cycleDuration(int delta) {
    final options = AwakeDuration.options;
    final current = options.indexOf(state.duration);
    final next = (current + delta).clamp(0, options.length - 1);

    return selectDuration(options[next]);
  }

  Future<void> toggle() => state.isOn ? turnOff() : turnOn();

  Future<void> turnOn() async {
    await _display.enable();
    state = state.copyWith(isOn: true);
    await _startDeadline();
  }

  Future<void> turnOff() async {
    _stopTicker();
    await _display.disable();
    state = state.copyWith(isOn: false, clearRemaining: true);
  }

  Future<void> _startDeadline() async {
    _stopTicker();

    final total = state.duration.duration;
    if (total == null) {
      state = state.copyWith(clearRemaining: true);
      return;
    }

    _endsAt = _now().add(total);
    state = state.copyWith(remaining: total);
    _ticker = Timer.periodic(_tick, (_) => _onTick());
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
    _endsAt = null;
  }

  void _onTick() {
    final endsAt = _endsAt;
    if (endsAt == null) return;

    final remaining = endsAt.difference(_now());
    if (remaining <= Duration.zero) {
      unawaited(turnOff());
      return;
    }

    state = state.copyWith(remaining: remaining);
  }
}
