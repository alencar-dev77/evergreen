import 'package:flutter/foundation.dart';

import '../../../../shared/utils/duration_format.dart';
import '../../models/focus_phase.dart';
import '../../models/focus_session.dart';
import '../../models/focus_session_note.dart';
import '../../models/focus_settings.dart';

/// Em que ponto do ciclo o cronômetro está.
enum FocusStatus {
  /// Nenhuma sessão em andamento — a tela de partida.
  idle,

  /// Contando.
  running,

  /// Contando, mas suspenso pelo usuário.
  paused,

  /// O tempo acabou e o Focus está esperando a próxima decisão (iniciar a
  /// pausa, escrever o resumo, encerrar).
  finished,
}

/// Estado renderizável do painel do Focus.
///
/// Carrega as preferências junto porque a tela depende delas para decidir o que
/// mostrar (campo de atividade, campo de resumo) — assim a view lê um objeto
/// só, e não dois providers que podem chegar dessincronizados.
@immutable
class FocusTimerState {
  const FocusTimerState({
    required this.settings,
    this.phase = FocusPhase.focus,
    this.status = FocusStatus.idle,
    this.remaining = Duration.zero,
    this.total = Duration.zero,
    this.focused = Duration.zero,
    this.activity = '',
    this.startedAt,
    this.lastSession,
    this.alerts = 0,
    this.notes = const [],
    this.isExtended = false,
  });

  /// Estado de partida: sem sessão, com a duração de foco configurada à vista.
  factory FocusTimerState.idle(FocusSettings settings) => FocusTimerState(
        settings: settings,
        remaining: settings.focusDuration,
        total: settings.focusDuration,
      );

  final FocusSettings settings;
  final FocusPhase phase;
  final FocusStatus status;

  /// Quanto falta para o fim da fase atual.
  final Duration remaining;

  /// Duração total da fase atual — a base do progresso.
  final Duration total;

  /// Quanto o cronômetro **realmente correu** nesta fase, quando [status] é
  /// [FocusStatus.finished].
  ///
  /// Não é `total - remaining`. Os dois só coincidem quando a sessão foi do
  /// começo ao fim com o aplicativo acordado, que é o caso comum e não o único:
  /// se o Mac dormir no minuto 3 de uma sessão de 25, o prazo vence enquanto o
  /// processo está suspenso e `remaining` chega a zero sem que ninguém tenha
  /// focado 25 minutos. Este número conta só o tempo que o cronômetro esteve de
  /// pé, e é ele que a tela de conclusão mostra e o histórico registra — os
  /// dois precisam dizer a mesma coisa.
  final Duration focused;

  /// Atividade informada para a sessão em andamento (ou para a próxima).
  final String activity;

  final DateTime? startedAt;

  /// A sessão que acabou de ser registrada, quando [status] é
  /// [FocusStatus.finished] — é ela que recebe o resumo.
  final FocusSession? lastSession;

  /// Quantas vezes o Focus pediu a tela desde que o app subiu.
  ///
  /// Um contador, e não um bool: o app precisa distinguir "acabou de terminar"
  /// de "continua terminado" para não reabrir o painel a cada rebuild.
  final int alerts;

  /// Observações escritas nesta sessão, na ordem em que foram escritas.
  final List<FocusSessionNote> notes;

  /// A sessão já ganhou os +5 min — só se estende uma vez.
  final bool isExtended;

  /// A partir de quanto tempo restante o `+5 min` é oferecido. Antes disso a
  /// oferta seria ruído: quem está a 20 minutos do fim não decide sobre isso.
  static const extendThreshold = Duration(minutes: 5);

  bool get isIdle => status == FocusStatus.idle;
  bool get isRunning => status == FocusStatus.running;
  bool get isPaused => status == FocusStatus.paused;
  bool get isFinished => status == FocusStatus.finished;

  /// Sessão em andamento (contando ou pausada).
  bool get isActive => isRunning || isPaused;

  bool get hasActivity => activity.trim().isNotEmpty;

  /// A última observação escrita, se houver — o painel a mostra como eco.
  FocusSessionNote? get lastNote => notes.isEmpty ? null : notes.last;

  /// Reta final de uma sessão de foco ainda não estendida.
  bool get canExtend =>
      isActive &&
      phase.isFocus &&
      !isExtended &&
      remaining <= extendThreshold;

  /// Fração já cumprida da fase, de 0 a 1.
  double get progress {
    if (total == Duration.zero) return 0;
    final done = total - remaining;
    return (done.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
  }

  /// Texto ao lado do ícone na barra de menus, ou `null` para não mostrar nada.
  ///
  /// A fase e o estado entram como palavra, não como cor ou símbolo: na barra
  /// de menus não há espaço para legenda, e "04:13" sozinho não diz se é foco
  /// ou pausa.
  String? get menuBarLabel => switch (status) {
        FocusStatus.idle => null,
        FocusStatus.running =>
          phase.isFocus ? _clock : 'Pausa $_clock',
        FocusStatus.paused => 'Pausado $_clock',
        FocusStatus.finished => 'Concluído',
      };

  String get _clock => DurationFormat.countdown(remaining);

  FocusTimerState copyWith({
    FocusSettings? settings,
    FocusPhase? phase,
    FocusStatus? status,
    Duration? remaining,
    Duration? total,
    Duration? focused,
    String? activity,
    DateTime? startedAt,
    FocusSession? lastSession,
    int? alerts,
    List<FocusSessionNote>? notes,
    bool? isExtended,
  }) {
    return FocusTimerState(
      settings: settings ?? this.settings,
      phase: phase ?? this.phase,
      status: status ?? this.status,
      remaining: remaining ?? this.remaining,
      total: total ?? this.total,
      focused: focused ?? this.focused,
      activity: activity ?? this.activity,
      startedAt: startedAt ?? this.startedAt,
      lastSession: lastSession ?? this.lastSession,
      alerts: alerts ?? this.alerts,
      notes: notes ?? this.notes,
      isExtended: isExtended ?? this.isExtended,
    );
  }
}
