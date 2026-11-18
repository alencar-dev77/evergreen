import 'awake_duration.dart';
import 'awake_mode.dart';
import 'keyboard_lock_duration.dart';

/// Preferências do módulo Awake.
class AwakeSettings {
  const AwakeSettings({
    this.defaultDuration = AwakeDuration.hour1,
    this.mode = AwakeMode.screen,
    this.keyboardLockDuration = KeyboardLockDuration.minute1,
  });

  /// Duração que vem escolhida quando o painel abre.
  ///
  /// Uma hora por padrão: é o prazo que cobre uma reunião ou uma compilação
  /// longa sem deixar a tela acesa a noite inteira por esquecimento.
  final AwakeDuration defaultDuration;

  /// O que a trava segura: a tela ou só o sistema.
  ///
  /// Preferência, e não escolha do painel, porque é uma decisão que se toma uma
  /// vez — o painel do Awake tem uma pergunta só ("por quanto tempo?") e cada
  /// linha a mais nele seria uma decisão que ninguém pediu na hora de ligar.
  final AwakeMode mode;

  /// Por quanto tempo o teclado fica bloqueado ao bloquear.
  ///
  /// Só aqui, e não no painel: o painel bloqueado não tem teclado para trocar
  /// de opção, e na hora de bloquear ninguém quer decidir um número.
  final KeyboardLockDuration keyboardLockDuration;

  AwakeSettings copyWith({
    AwakeDuration? defaultDuration,
    AwakeMode? mode,
    KeyboardLockDuration? keyboardLockDuration,
  }) => AwakeSettings(
    defaultDuration: defaultDuration ?? this.defaultDuration,
    mode: mode ?? this.mode,
    keyboardLockDuration: keyboardLockDuration ?? this.keyboardLockDuration,
  );
}
