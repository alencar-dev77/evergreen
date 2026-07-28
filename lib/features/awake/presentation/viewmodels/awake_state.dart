import '../../../../shared/utils/duration_format.dart';
import '../../models/awake_duration.dart';
import '../../models/awake_settings.dart';

/// Estado do Awake: ligado ou não, com que prazo e quanto falta dele.
class AwakeState {
  const AwakeState({
    required this.settings,
    required this.duration,
    this.isOn = false,
    this.remaining,
  });

  /// Estado de partida, com a duração que as preferências escolheram.
  AwakeState.off(AwakeSettings settings)
      : this(settings: settings, duration: settings.defaultDuration);

  final AwakeSettings settings;

  /// Duração escolhida no seletor — a que vale agora, se estiver ligado, ou a
  /// que valerá quando ligar.
  final AwakeDuration duration;

  final bool isOn;

  /// Quanto falta para desligar sozinho. `null` sem prazo ou desligado.
  final Duration? remaining;

  bool get hasDeadline => isOn && remaining != null;

  /// Fração já corrida do prazo, de 0 a 1. `null` esconde a linha de progresso
  /// — sem prazo não há progresso nenhum a mostrar.
  double? get progress {
    final remaining = this.remaining;
    final total = duration.duration;
    if (!isOn || remaining == null || total == null) return null;
    if (total.inSeconds == 0) return 1;

    final elapsed = total - remaining;
    return (elapsed.inSeconds / total.inSeconds).clamp(0.0, 1.0);
  }

  /// O rótulo grande do painel.
  ///
  /// Ligado com prazo, é a contagem regressiva; sem prazo, o infinito — um
  /// número que não corre seria mentira. Desligado, mostra o prazo proposto,
  /// esmaecido, como a tela de partida do Focus.
  String get display {
    if (!duration.hasDeadline) return '∞';

    final remaining = this.remaining;
    return DurationFormat.clock(
      isOn && remaining != null ? remaining : duration.duration!,
    );
  }

  /// Situação, em caixa alta, acima do número.
  String get statusLabel => isOn ? 'Mantendo a tela acesa' : 'Desligado';

  /// Como o estado aparece no item do menu da barra.
  ///
  /// Só o item do menu carrega o tempo restante: o título ao lado do ícone
  /// mostra apenas que o Awake está ligado, para não disputar espaço com a
  /// contagem do Focus.
  String? get menuBarDetail {
    if (!isOn) return null;
    if (!hasDeadline) return 'sem limite';

    return DurationFormat.compact(remaining!);
  }

  AwakeState copyWith({
    AwakeSettings? settings,
    AwakeDuration? duration,
    bool? isOn,
    Duration? remaining,
    bool clearRemaining = false,
  }) {
    return AwakeState(
      settings: settings ?? this.settings,
      duration: duration ?? this.duration,
      isOn: isOn ?? this.isOn,
      remaining: clearRemaining ? null : remaining ?? this.remaining,
    );
  }
}
