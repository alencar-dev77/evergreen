/// Preferências do módulo Focus.
class FocusSettings {
  const FocusSettings({
    this.focusMinutes = 25,
    this.breakMinutes = 5,
    this.pomodoroOnly = false,
    this.askActivity = true,
    this.askSummary = false,
    this.playSound = true,
    this.alertOnScreen = true,
  });

  /// Duração de uma sessão de foco.
  final int focusMinutes;

  /// Duração da pausa oferecida ao fim de cada sessão.
  final int breakMinutes;

  /// Modo Pomodoro puro: só o cronômetro, sem atividade nem resumo.
  ///
  /// É um interruptor mestre — quando ligado, [askActivity] e [askSummary]
  /// deixam de valer (e aparecem desabilitados na tela de preferências, em vez
  /// de sumirem: a pessoa precisa ver que as opções existem).
  final bool pomodoroOnly;

  /// Perguntar em que a pessoa vai trabalhar antes de iniciar.
  final bool askActivity;

  /// Pedir um resumo curto ao terminar.
  ///
  /// Desligado por padrão: perguntar no fim custa atenção no momento em que a
  /// pessoa já quer levantar da cadeira. Quem quiser o registro completo liga.
  final bool askSummary;

  /// Tocar o som de alerta do sistema quando o tempo acaba.
  final bool playSound;

  /// Trazer o painel do Focus para a frente quando o tempo acaba.
  ///
  /// É o aviso do Evergreen — o painel é sempre-no-topo, então ele aparece por
  /// cima do app em uso sem depender da Central de Notificações do macOS.
  final bool alertOnScreen;

  /// Opções oferecidas na tela de configurações.
  ///
  /// O piso do foco é 5 min — o "só respondo esse e-mail". Abaixo disso não é
  /// sessão de foco, é cronômetro de teste.
  static const focusMinutesOptions = <int>[5, 15, 25, 45, 60];
  static const breakMinutesOptions = <int>[3, 5, 10, 15];

  Duration get focusDuration => Duration(minutes: focusMinutes);
  Duration get breakDuration => Duration(minutes: breakMinutes);

  bool get asksActivity => !pomodoroOnly && askActivity;
  bool get asksSummary => !pomodoroOnly && askSummary;

  /// Anotar durante a sessão faz parte do modo com registro de atividade. No
  /// Pomodoro puro não existe registro nenhum — só o cronômetro.
  bool get asksNotes => !pomodoroOnly;

  FocusSettings copyWith({
    int? focusMinutes,
    int? breakMinutes,
    bool? pomodoroOnly,
    bool? askActivity,
    bool? askSummary,
    bool? playSound,
    bool? alertOnScreen,
  }) {
    return FocusSettings(
      focusMinutes: focusMinutes ?? this.focusMinutes,
      breakMinutes: breakMinutes ?? this.breakMinutes,
      pomodoroOnly: pomodoroOnly ?? this.pomodoroOnly,
      askActivity: askActivity ?? this.askActivity,
      askSummary: askSummary ?? this.askSummary,
      playSound: playSound ?? this.playSound,
      alertOnScreen: alertOnScreen ?? this.alertOnScreen,
    );
  }
}
