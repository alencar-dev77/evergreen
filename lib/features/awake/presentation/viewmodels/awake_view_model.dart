import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../data/awake_session_repository.dart';
import '../../data/awake_settings_repository.dart';
import '../../data/sleep_assertion_service.dart';
import '../../models/awake_duration.dart';
import '../../models/awake_mode.dart';
import '../../models/awake_session.dart';
import 'awake_state.dart';

final awakeViewModelProvider = NotifierProvider<AwakeViewModel, AwakeState>(
  AwakeViewModel.new,
);

/// Segura a tela acesa pelo prazo escolhido.
///
/// Vive no engine da janela flutuante, que nunca é destruído — é o que faz a
/// trava continuar valendo com o painel fechado, igual ao cronômetro do Focus.
class AwakeViewModel extends Notifier<AwakeState> {
  late final AwakeSettingsRepository _settingsRepository;
  late final SleepAssertionService _sleep;
  late final AwakeSessionRepository _sessions;
  late final DateTime Function() _now;

  Timer? _ticker;

  /// Quando a trava que está de pé foi ligada. `null` com ela solta.
  DateTime? _startedAt;

  /// Instante em que a trava se solta sozinha. A contagem é derivada dele a
  /// cada tique, e não subtraída de um contador: assim uma suspensão do Mac
  /// não "congela" o prazo.
  DateTime? _endsAt;

  /// Quanto a trava valeu de fato desde que foi ligada.
  ///
  /// Acumulado tique a tique, como o `_focused` do Focus, e não derivado de
  /// `agora - começo`: a trava segura o sono por inatividade, não a tampa
  /// fechada. Fechar a tampa com prazo de uma hora e abrir nove horas depois
  /// gravava nove horas acordado — o Mac dormiu quase todas elas.
  Duration _held = Duration.zero;

  /// Instante do último tique, para saber quanto cada um acrescenta.
  DateTime? _lastTickAt;

  /// A duração e o modo da última trava que venceu sozinha.
  ///
  /// São o que o "Mais …" da notificação promete repetir. Lidos do estado na
  /// hora do clique, eles já podiam ter mudado: abrir o painel depois do aviso
  /// relê as preferências e troca a duração e o modo da tela de partida.
  AwakeDuration? _expiredDuration;
  AwakeMode? _expiredMode;

  /// Um tique por segundo basta: o painel mostra segundos e o menu, minutos.
  static const _tick = Duration(seconds: 1);

  /// Abaixo disso a trava não entra no dia reconstruído.
  ///
  /// Mesmo limiar do Focus, pela mesma razão: ligar e desligar por engano não é
  /// um período acordado, e uma linha de quinze segundos no Track só atrapalha
  /// a leitura do dia.
  static const _minimumRecorded = Duration(minutes: 1);

  /// Vão entre tiques a partir do qual o processo esteve suspenso — o Mac
  /// dormiu. Mesmo limiar do `_sleepGap` do Focus, e pelas mesmas razões: o
  /// App Nap atrasa e agrupa os timers de um app sem janela, mas nada perto de
  /// um minuto.
  static const _sleepGap = Duration(minutes: 1);

  @override
  AwakeState build() {
    _settingsRepository = ref.watch(awakeSettingsRepositoryProvider);
    _sleep = ref.watch(sleepAssertionServiceProvider);
    _sessions = ref.watch(awakeSessionRepositoryProvider);
    _now = ref.watch(clockProvider);

    ref.onDispose(() {
      _stopTicker();
      // A trava é do processo, não do provider: soltá-la aqui evita deixar o
      // Mac acordado se este container morrer antes do app.
      unawaited(_sleep.disable());
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
    if (state.isOn) return;

    await _sleep.enable(state.mode);
    // A trava que o sistema recusou não segura nada: marcar ligado mostraria
    // "Mantendo a tela acesa" com a tela apagando, e gravaria no Track um
    // período que não existiu.
    if (_sleep.mode != state.mode) return;

    final now = _now();
    _startedAt = now;
    _lastTickAt = now;
    _held = Duration.zero;
    state = state.copyWith(isOn: true);
    await _startDeadline();
  }

  /// O "Mais …" da notificação de prazo vencido: liga de novo com a duração e
  /// o modo da trava que venceu, e não com o que a tela de partida mostra agora.
  ///
  /// Sem trava vencida, ou com uma já ligada, não faz nada — o botão vive na
  /// Central de Notificações e pode ser clicado muito depois.
  Future<void> turnOnAgain() async {
    final duration = _expiredDuration;
    final mode = _expiredMode;
    if (state.isOn || duration == null || mode == null) return;

    state = state.copyWith(duration: duration, mode: mode);
    await turnOn();
  }

  /// Solta a trava — por decisão de quem ligou, pelo prazo vencido ou pelo
  /// aplicativo sendo encerrado — e registra o período que ela valeu.
  Future<void> turnOff() async {
    // Cobrado antes de o prazo sair de cena: é ele que põe o teto no último
    // trecho.
    _accrue();
    _stopTicker();
    await _sleep.disable();
    _record();
    state = state.copyWith(isOn: false, clearRemaining: true);
  }

  /// Põe no banco o período que acabou de terminar.
  ///
  /// É a única escrita do módulo, e ela existe para o Track: sem ela, o Awake
  /// era o único módulo que não aparecia no dia reconstruído. O que se grava é
  /// quando começou, quanto durou e o que estava segurando — nada mais, porque
  /// nada mais existe aqui.
  void _record() {
    final startedAt = _startedAt;
    _startedAt = null;
    if (startedAt == null) return;

    final duration = _held;
    _held = Duration.zero;
    _lastTickAt = null;
    if (duration < _minimumRecorded) return;

    _sessions.insert(
      AwakeSession(startedAt: startedAt, duration: duration, mode: state.mode),
    );
  }

  /// O prazo venceu: solta a trava e conta a vez, para a notificação.
  Future<void> _expire() async {
    _expiredDuration = state.duration;
    _expiredMode = state.mode;
    await turnOff();
    state = state.copyWith(expirations: state.expirations + 1);
  }

  /// Põe de pé o prazo da duração escolhida — ou nenhum, em "Sempre".
  ///
  /// O tique roda nos dois casos: sem prazo não há contagem a mostrar, mas há
  /// o cochilo do Mac a descontar.
  Future<void> _startDeadline() async {
    // O que valeu até aqui fica cobrado sob o prazo anterior, antes de ele sair.
    _accrue();
    _stopTicker();

    final total = state.duration.duration;
    if (total == null) {
      state = state.copyWith(clearRemaining: true);
    } else {
      _endsAt = _now().add(total);
      state = state.copyWith(remaining: total);
    }
    _ticker = Timer.periodic(_tick, (_) => _onTick());
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
    _endsAt = null;
  }

  /// Cobra o tempo desde o tique anterior, até o prazo e nunca além dele.
  ///
  /// Um vão maior que [_sleepGap] é o Mac tendo dormido, e não entra. O teto
  /// no prazo vale para o tique que chega atrasado: a trava se soltaria no
  /// prazo, e o que passou dele não foi segurado por ninguém.
  void _accrue() {
    final last = _lastTickAt;
    if (last == null) return;

    final endsAt = _endsAt;
    final now = _now();
    final until = endsAt != null && endsAt.isBefore(now) ? endsAt : now;
    _lastTickAt = until;

    final since = until.difference(last);
    if (since.isNegative || since >= _sleepGap) return;

    _held += since;
  }

  void _onTick() {
    _accrue();

    final endsAt = _endsAt;
    if (endsAt == null) return;

    final remaining = endsAt.difference(_now());
    if (remaining <= Duration.zero) {
      unawaited(_expire());
      return;
    }

    state = state.copyWith(remaining: remaining);
  }
}
