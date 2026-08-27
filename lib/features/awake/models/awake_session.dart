import 'awake_mode.dart';

/// Um período em que o Mac ficou acordado por ordem do Awake.
///
/// Nasce quando a trava se solta — por decisão de quem ligou, pelo prazo que
/// venceu ou pelo aplicativo sendo encerrado. A trava que ainda está de pé não
/// vira registro: ela ainda não tem duração, e o painel já mostra o que ela
/// está fazendo.
class AwakeSession {
  const AwakeSession({
    required this.startedAt,
    required this.duration,
    required this.mode,
  });

  final DateTime startedAt;
  final Duration duration;

  /// O que estava sendo segurado — é o que o Track mostra como nome da linha.
  final AwakeMode mode;

  /// Como o período se chama no dia reconstruído.
  String get label => mode.periodLabel;
}
