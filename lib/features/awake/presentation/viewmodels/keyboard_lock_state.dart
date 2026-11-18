import '../../../../shared/utils/duration_format.dart';
import '../../data/keyboard_lock_service.dart';
import '../../models/keyboard_lock_duration.dart';

/// Estado do bloqueio de teclado: bloqueado ou não, por quanto tempo e quanto
/// falta — ou por que o último pedido não bloqueou.
class KeyboardLockState {
  const KeyboardLockState({
    required this.duration,
    this.isLocked = false,
    this.remaining,
    this.refusal,
  });

  /// O prazo das preferências: o que vale agora, se bloqueado, ou o que valerá
  /// ao bloquear.
  final KeyboardLockDuration duration;

  final bool isLocked;

  /// Quanto falta para o teclado voltar sozinho. `null` em "Sempre" ou
  /// desbloqueado.
  final Duration? remaining;

  /// Por que o último pedido não bloqueou. Some no pedido seguinte e ao abrir o
  /// painel de novo.
  final KeyboardLockRefusal? refusal;

  /// Fração já corrida do prazo, de 0 a 1. `null` esconde a linha.
  double? get progress {
    final remaining = this.remaining;
    final total = duration.duration;
    if (!isLocked || remaining == null || total == null) return null;
    if (total.inSeconds == 0) return 1;

    final elapsed = total - remaining;
    return (elapsed.inSeconds / total.inSeconds).clamp(0.0, 1.0);
  }

  /// O número grande do painel bloqueado: a contagem, ou o infinito em
  /// "Sempre".
  String get display {
    final remaining = this.remaining;
    if (remaining == null) return '∞';

    return DurationFormat.countdown(remaining);
  }

  /// A frase da recusa, quando houve uma.
  String? get refusalMessage => switch (refusal) {
    null => null,
    KeyboardLockRefusal.accessibility =>
      'Para bloquear o teclado, o Evergreen precisa da permissão de '
          'Acessibilidade.',
    KeyboardLockRefusal.secureInput =>
      'Um campo de senha está protegendo o teclado agora. Saia dele e tente '
          'de novo.',
    KeyboardLockRefusal.unavailable =>
      'O macOS não deixou bloquear o teclado agora.',
  };

  KeyboardLockState copyWith({
    KeyboardLockDuration? duration,
    bool? isLocked,
    Duration? remaining,
    bool clearRemaining = false,
    KeyboardLockRefusal? refusal,
    bool clearRefusal = false,
  }) {
    return KeyboardLockState(
      duration: duration ?? this.duration,
      isLocked: isLocked ?? this.isLocked,
      remaining: clearRemaining ? null : remaining ?? this.remaining,
      refusal: clearRefusal ? null : refusal ?? this.refusal,
    );
  }
}
