import 'awake_duration.dart';

/// Preferências do módulo Awake.
class AwakeSettings {
  const AwakeSettings({this.defaultDuration = AwakeDuration.hour1});

  /// Duração que vem escolhida quando o painel abre.
  ///
  /// Uma hora por padrão: é o prazo que cobre uma reunião ou uma compilação
  /// longa sem deixar a tela acesa a noite inteira por esquecimento.
  final AwakeDuration defaultDuration;

  AwakeSettings copyWith({AwakeDuration? defaultDuration}) =>
      AwakeSettings(defaultDuration: defaultDuration ?? this.defaultDuration);
}
