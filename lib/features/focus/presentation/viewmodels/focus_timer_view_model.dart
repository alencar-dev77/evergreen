import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../data/focus_run_repository.dart';
import '../../data/focus_session_repository.dart';
import '../../data/focus_settings_repository.dart';
import '../../models/focus_phase.dart';
import '../../models/focus_run.dart';
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
  late final FocusRunRepository _runs;
  late final DateTime Function() _now;

  Timer? _ticker;

  /// Instante em que a fase atual acaba. A contagem é derivada dele a cada
  /// tique, e não subtraída de um contador: assim o relógio não acumula desvio
  /// e uma suspensão do Mac não "congela" o tempo.
  DateTime? _endsAt;

  /// Quanto o cronômetro realmente correu nesta fase — ver [FocusTimerState.focused].
  ///
  /// Acumulado tique a tique, e não derivado de `total - remaining`: é a
  /// diferença entre "o prazo venceu" e "alguém focou até o prazo vencer".
  Duration _focused = Duration.zero;

  /// Instante do último tique, para saber quanto tempo cada um acrescenta.
  DateTime? _lastTickAt;

  /// Quanto de [_focused] já foi para o disco. O batimento sai daqui.
  Duration _lastBeat = Duration.zero;

  /// Frequência do tique. Menor que um segundo para que a virada do relógio
  /// chegue à tela quase no instante certo; o estado só é reemitido quando o
  /// segundo exibido muda.
  static const _tick = Duration(milliseconds: 250);

  /// Abaixo disso a sessão não entra no histórico — abrir e fechar o painel por
  /// engano não deve virar registro.
  static const _minimumRecorded = Duration(minutes: 1);

  /// Quanto o `+5 min` acrescenta.
  static const _extension = Duration(minutes: 5);

  /// Intervalo entre tiques a partir do qual entendemos que o processo esteve
  /// suspenso — o Mac dormiu, tipicamente. O tempo desse vão passou no relógio,
  /// mas ninguém o focou, então ele não entra em [_focused].
  ///
  /// Um minuto, e não os poucos segundos que bastariam para separar um tique
  /// atrasado de um cochilo: o Evergreen é `LSUIElement` e passa quase todo o
  /// tempo sem janela visível, que é o perfil que o **App Nap** do macOS
  /// escolhe para atrasar e agrupar timers. Com um limiar curto, um tique que
  /// chegasse oito segundos atrasado faria o módulo descartar oito segundos de
  /// trabalho real — e em silêncio, que é o pior jeito de errar num módulo cujo
  /// único produto é o número.
  ///
  /// Um minuto põe os dois erros do lado certo: nenhum agrupamento de timer
  /// chega perto disso, e cochilo de máquina praticamente não dura menos que
  /// isso. O pior caso passa a ser contar até um minuto a mais de um cochilo
  /// curto, que não muda nenhum número que alguém vá ler.
  ///
  /// O jeito exato seria ouvir `NSWorkspaceWillSleep`/`DidWake` no Swift, que é
  /// o sistema avisando em vez de nós adivinhando. Fica para quando este limiar
  /// se mostrar insuficiente: é código nativo novo, e o projeto prefere Flutter
  /// puro enquanto ele der conta.
  static const _sleepGap = Duration(minutes: 1);

  /// De quanto em quanto tempo focado o rastro vai para o disco.
  ///
  /// É o que se perde se o aplicativo morrer sem aviso — quinze segundos de uma
  /// sessão de vinte e cinco minutos. Mais frequente que isso seria escrever no
  /// plist a cada segundo para ganhar precisão que ninguém lê.
  static const _heartbeat = Duration(seconds: 15);

  @override
  FocusTimerState build() {
    _sessions = ref.watch(focusSessionRepositoryProvider);
    _settingsRepository = ref.watch(focusSettingsRepositoryProvider);
    _runs = ref.watch(focusRunRepositoryProvider);
    _now = ref.watch(clockProvider);

    ref.onDispose(_stopTicker);

    return FocusTimerState.idle(_settingsRepository.load());
  }

  /// Registra a sessão que o fechamento do aplicativo interrompeu, se houver.
  ///
  /// Chamado uma vez, na subida do `EvergreenBootstrap`. O cronômetro vive na
  /// memória do engine, então encerrar o Evergreen no meio de uma sessão a
  /// apagava inteira — o histórico só era escrito no fim, e o fim não chegava.
  /// O que se recupera é o último batimento (ver [FocusRun]): o tempo que o
  /// cronômetro tinha corrido quando o aplicativo ainda estava de pé.
  ///
  /// A sessão volta como **terminada**, não em andamento. Retomar uma contagem
  /// depois de um relançamento seria devolver à tela um prazo que já venceu, e
  /// o que interessa recuperar não é a contagem — é o tempo trabalhado.
  Future<void> recoverInterruptedSession() async {
    final run = _runs.load();
    if (run == null) return;

    await _runs.clear();
    if (run.focused < _minimumRecorded) return;

    _sessions.trimToCurrentWeek(now: run.startedAt);
    _sessions.insert(
      FocusSession(
        startedAt: run.startedAt,
        duration: run.focused,
        activity: run.activity.trim().isEmpty ? null : run.activity.trim(),
        notes: run.notes,
      ),
    );
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

    _accrue();
    _stopTicker();
    state = state.copyWith(
      status: FocusStatus.paused,
      remaining: remaining,
    );
    _syncRun();
  }

  void resume() {
    if (!state.isPaused) return;

    final now = _now();
    _endsAt = now.add(state.remaining);
    // O tique seguinte não pode cobrar o tempo em que a sessão esteve parada.
    _lastTickAt = now;
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

    _accrue();

    state = state.copyWith(
      notes: [
        ...state.notes,
        FocusSessionNote(minute: _focused.inMinutes, text: trimmed),
      ],
    );
    // O rastro vai junto: uma observação escrita aos 12 minutos não pode se
    // perder porque o batimento seguinte só chegaria aos 15.
    _syncRun();
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
    unawaited(_runs.clear());
    state = FocusTimerState.idle(state.settings);
  }

  /// [activity] nulo mantém a atividade atual — é o que faz a pausa e a sessão
  /// seguinte continuarem no mesmo trabalho, sem pedir de novo o que a pessoa
  /// já disse no início do ciclo.
  void _beginPhase(FocusPhase phase, Duration total, {String? activity}) {
    final now = _now();
    _endsAt = now.add(total);
    // A fase nova começa com o contador de tempo focado zerado, como as notas e
    // a extensão.
    _focused = Duration.zero;
    _lastTickAt = now;
    _lastBeat = Duration.zero;

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
    _syncRun();
  }

  /// Fim da fase — por tempo esgotado ([alert] ligado) ou por decisão do
  /// usuário.
  void _finish({required bool alert}) {
    // Cobra o tempo desde o último tique antes de fechar a conta. Sem isto, um
    // encerramento pelo botão perderia a fração de segundo final — e um fim que
    // chega depois de o Mac dormir cobraria o cochilo inteiro.
    _accrue();

    final remaining = _remainingNow();
    final focused = _focused;
    _stopTicker();

    // O que foi focado sai daqui, antes de o estado mudar.
    final session = state.phase.isFocus ? _record(focused) : null;
    if (alert && state.settings.playSound) _playAlertSound();

    state = FocusTimerState(
      settings: state.settings,
      phase: state.phase,
      status: FocusStatus.finished,
      // O que sobrou é guardado como estava: zero quando o tempo acabou, o
      // restante real quando a pessoa encerrou antes. Quanto a sessão durou não
      // sai daqui — sai de [focused], logo abaixo.
      remaining: remaining,
      total: state.total,
      focused: focused,
      activity: state.activity,
      startedAt: state.startedAt,
      lastSession: session,
      alerts: state.alerts +
          (alert && state.settings.alertOnScreen ? 1 : 0),
      notes: state.notes,
      isExtended: state.isExtended,
    );

    // A sessão já está no histórico (ou não tinha tempo para entrar): o rastro
    // cumpriu o papel dele e não pode sobreviver para ser registrado de novo na
    // abertura seguinte.
    unawaited(_runs.clear());
  }

  /// Registra no histórico o tempo efetivamente focado.
  ///
  /// [focused] vem do acumulador, não de `total - remaining`: é o tempo em que o
  /// cronômetro esteve de pé, sem a pausa e sem o que passou com o processo
  /// suspenso.
  FocusSession? _record(Duration focused) {
    final startedAt = state.startedAt;
    if (startedAt == null) return null;

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
    _lastTickAt = null;
  }

  /// Cobra o tempo decorrido desde o tique anterior.
  ///
  /// É aqui que mora a diferença entre "o prazo venceu" e "alguém focou até o
  /// prazo vencer": um vão maior que [_sleepGap] entre dois tiques é o processo
  /// tendo sido suspenso — o Mac dormiu —, e esse tempo não é cobrado de
  /// ninguém. Sem isto, dormir no minuto 3 de uma sessão de 25 registrava 25
  /// minutos focados.
  void _accrue() {
    final now = _now();
    final last = _lastTickAt;
    _lastTickAt = now;
    if (last == null) return;

    final since = now.difference(last);
    if (since.isNegative || since >= _sleepGap) return;

    _focused += since;
  }

  /// Grava o rastro se já passou um [_heartbeat] desde o último.
  ///
  /// Só o tique bate. O fim da fase não: ele apaga o rastro logo em seguida, e
  /// um batimento na mesma respiração seria escrever para apagar.
  void _beat() {
    if (_focused - _lastBeat < _heartbeat) return;

    _syncRun();
  }

  /// Põe o rastro em dia com a sessão em andamento — ou o apaga, quando não há
  /// uma que valha recuperar.
  ///
  /// A pausa **não** apaga: uma sessão pausada tem tempo focado, e é justamente
  /// o caso em que a pessoa sai da frente do Mac.
  void _syncRun() {
    final startedAt = state.startedAt;

    if (startedAt == null || !state.phase.isFocus || !state.isActive) {
      unawaited(_runs.clear());
      return;
    }

    _lastBeat = _focused;
    unawaited(
      _runs.save(
        FocusRun(
          startedAt: startedAt,
          focused: _focused,
          activity: state.activity,
          notes: state.notes,
        ),
      ),
    );
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

    _accrue();
    _beat();

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
