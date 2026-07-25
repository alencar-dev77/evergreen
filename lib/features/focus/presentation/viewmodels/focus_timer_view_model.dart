import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../data/focus_session_repository.dart';
import '../../data/focus_settings_repository.dart';
import '../../models/focus_phase.dart';
import '../../models/focus_session.dart';
import '../../models/focus_session_note.dart';
import 'focus_timer_state.dart';

final focusTimerViewModelProvider =
    NotifierProvider<FocusTimerViewModel, FocusTimerState>(
  FocusTimerViewModel.new,
);

/// O cronômetro do Focus.
///
/// Vive no engine da janela flutuante, que nunca é destruída — por isso a
/// sessão continua correndo com o painel fechado, com o Hub fechado, e o
/// usuário acompanha pela barra de menus.
class FocusTimerViewModel extends Notifier<FocusTimerState> {
  late final FocusSessionRepository _sessions;
  late final FocusSettingsRepository _settingsRepository;
  late final DateTime Function() _now;

  Timer? _ticker;

  /// Instante em que a fase atual acaba. A contagem é derivada dele a cada
  /// tique, e não subtraída de um contador: assim o relógio não acumula desvio
  /// e uma suspensão do Mac não "congela" o tempo.
  DateTime? _endsAt;

  /// Frequência do tique. Menor que um segundo para que a virada do relógio
  /// chegue à tela quase no instante certo; o estado só é reemitido quando o
  /// segundo exibido muda.
  static const _tick = Duration(milliseconds: 250);

  /// Abaixo disso a sessão não entra no histórico — abrir e fechar o painel por
  /// engano não deve virar registro.
  static const _minimumRecorded = Duration(minutes: 1);

  /// Quanto o `+5 min` acrescenta.
  static const _extension = Duration(minutes: 5);

  @override
  FocusTimerState build() {
    _sessions = ref.watch(focusSessionRepositoryProvider);
    _settingsRepository = ref.watch(focusSettingsRepositoryProvider);
    _now = ref.watch(clockProvider);

    ref.onDispose(_stopTicker);

    return FocusTimerState.idle(_settingsRepository.load());
  }

  /// Relê as preferências antes de o painel aparecer.
  ///
  /// Elas são editadas no Hub, que roda em outro engine: sem isso, mudar a
  /// duração do foco só teria efeito no próximo lançamento do app. Uma sessão
  /// em andamento mantém a duração com que começou.
  Future<void> prepareForOpen() async {
    await _settingsRepository.reload();
    final settings = _settingsRepository.load();

    state = state.isIdle
        ? FocusTimerState.idle(settings)
        : state.copyWith(settings: settings);
  }

  /// Inicia uma sessão de foco.
  void start({String activity = ''}) {
    _beginPhase(
      FocusPhase.focus,
      state.settings.focusDuration,
      activity: activity,
    );
  }

  /// Inicia a pausa. Opcionalmente grava o resumo escrito na tela anterior.
  void startRest({String? summary}) {
    _saveSummary(summary);
    _beginPhase(FocusPhase.rest, state.settings.breakDuration);
  }

  void pause() {
    if (!state.isRunning) return;

    // O tempo restante é recalculado agora, e não herdado do último tique: a
    // pausa deve congelar o instante do clique, não um quarto de segundo antes.
    final remaining = _remainingNow();

    _stopTicker();
    state = state.copyWith(
      status: FocusStatus.paused,
      remaining: remaining,
    );
  }

  void resume() {
    if (!state.isPaused) return;

    _endsAt = _now().add(state.remaining);
    state = state.copyWith(status: FocusStatus.running);
    _startTicker();
  }

  void togglePause() => state.isPaused ? resume() : pause();

  /// Anota uma observação com o minuto atual da sessão.
  ///
  /// Só durante o foco: a pausa não tem o que anotar, e o registro pertence à
  /// sessão que está correndo.
  void addNote(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || !state.isActive || !state.phase.isFocus) return;

    final elapsed = state.total - _remainingNow();

    state = state.copyWith(
      notes: [
        ...state.notes,
        FocusSessionNote(minute: elapsed.inMinutes, text: trimmed),
      ],
    );
  }

  /// Estende a sessão em 5 minutos — uma única vez.
  ///
  /// A regra de "uma vez só" é do produto: o `+5 min` existe para terminar o
  /// que está quase pronto, não para adiar a pausa indefinidamente.
  void extendFocus() {
    if (!state.canExtend) return;

    _endsAt = _endsAt?.add(_extension);

    state = state.copyWith(
      total: state.total + _extension,
      remaining: state.remaining + _extension,
      isExtended: true,
    );
  }

  /// Encerra a fase atual antes da hora.
  ///
  /// O que já foi focado conta: quem parou aos 18 minutos focou 18 minutos, e o
  /// histórico registra isso em vez de descartar a sessão. Sem som e sem trazer
  /// a janela para a frente — o usuário está olhando para o painel.
  void stop() {
    if (!state.isActive) return;
    _finish(alert: false);
  }

  /// Fecha o ciclo: grava o resumo, se houver, e volta ao estado de partida.
  void dismiss({String? summary}) {
    _saveSummary(summary);
    _stopTicker();
    state = FocusTimerState.idle(state.settings);
  }

  /// [activity] nulo mantém a atividade atual — é o que faz a pausa e a sessão
  /// seguinte continuarem no mesmo trabalho, sem pedir de novo o que a pessoa
  /// já disse no início do ciclo.
  void _beginPhase(FocusPhase phase, Duration total, {String? activity}) {
    final now = _now();
    _endsAt = now.add(total);

    state = FocusTimerState(
      settings: state.settings,
      phase: phase,
      status: FocusStatus.running,
      remaining: total,
      total: total,
      activity: (activity ?? state.activity).trim(),
      startedAt: now,
      alerts: state.alerts,
      // Notas e extensão são por sessão: a fase nova zera as duas.
    );

    _startTicker();
  }

  /// Fim da fase — por tempo esgotado ([alert] ligado) ou por decisão do
  /// usuário.
  void _finish({required bool alert}) {
    final remaining = _remainingNow();
    _stopTicker();

    // O que foi focado sai daqui, antes de o estado mudar: é o total menos o
    // que sobrou no instante exato do fim.
    final session = state.phase.isFocus ? _record(remaining) : null;
    if (alert && state.settings.playSound) _playAlertSound();

    state = FocusTimerState(
      settings: state.settings,
      phase: state.phase,
      status: FocusStatus.finished,
      // O que sobrou é guardado como estava: zero quando o tempo acabou, o
      // restante real quando a pessoa encerrou antes — é dele que a tela de
      // conclusão tira quanto durou a sessão.
      remaining: remaining,
      total: state.total,
      activity: state.activity,
      startedAt: state.startedAt,
      lastSession: session,
      alerts: state.alerts +
          (alert && state.settings.alertOnScreen ? 1 : 0),
      notes: state.notes,
      isExtended: state.isExtended,
    );
  }

  /// Registra no histórico o tempo efetivamente focado.
  ///
  /// `total - remaining` é exatamente o tempo que o cronômetro correu: a pausa
  /// congela os dois, então o que foi suspenso não entra na conta.
  FocusSession? _record(Duration remaining) {
    final startedAt = state.startedAt;
    if (startedAt == null) return null;

    final focused = state.total - remaining;
    if (focused < _minimumRecorded) return null;

    // A semana anterior sai de cena na primeira sessão da semana nova — o
    // histórico do Focus guarda só a semana corrente.
    _sessions.trimToCurrentWeek(now: startedAt);

    return _sessions.insert(
      FocusSession(
        startedAt: startedAt,
        duration: focused,
        activity: state.hasActivity ? state.activity.trim() : null,
        notes: state.notes,
      ),
    );
  }

  void _saveSummary(String? summary) {
    final id = state.lastSession?.id;
    if (id == null) return;

    final text = summary?.trim() ?? '';
    if (text.isEmpty) return;

    _sessions.setSummary(id, text);
  }

  /// Som de alerta do próprio sistema, pelo canal de plataforma do Flutter —
  /// nenhum pacote de áudio, nenhum arquivo empacotado. Se o macOS estiver com
  /// os alertas silenciados, o aviso visual continua valendo.
  void _playAlertSound() =>
      unawaited(SystemSound.play(SystemSoundType.alert));

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(_tick, (_) => _onTick());
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
    _endsAt = null;
  }

  /// Quanto falta neste exato instante.
  ///
  /// Com o cronômetro parado não há prazo para consultar, e o que vale é o
  /// tempo congelado no estado.
  Duration _remainingNow() {
    final endsAt = _endsAt;
    if (endsAt == null) return state.remaining;

    final remaining = endsAt.difference(_now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  void _onTick() {
    if (_endsAt == null) return;

    final remaining = _remainingNow();

    if (remaining == Duration.zero) {
      _finish(alert: true);
      return;
    }

    // Quatro tiques por segundo, uma emissão por segundo: sem isso a árvore
    // reconstruiria quatro vezes para mostrar o mesmo `24:13`.
    if (remaining.inSeconds == state.remaining.inSeconds) return;

    state = state.copyWith(remaining: remaining);
  }
}
