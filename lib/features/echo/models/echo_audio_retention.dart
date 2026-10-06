/// Uma reunião que diz ter áudio — o bastante para decidir se ele vence.
class EchoAudioRef {
  const EchoAudioRef({
    required this.meetingId,
    required this.fileName,
    required this.startedAt,
    required this.isKept,
  });

  final int meetingId;
  final String fileName;
  final DateTime startedAt;
  final bool isKept;
}

/// Quanto tempo o áudio de uma reunião fica no disco.
///
/// **Catorze dias, ou até a reunião sair — o que vier primeiro.** O teto de
/// reuniões (`EchoSettings.historyLimit`) continua mandando: com 25 reuniões e
/// seis por dia, a reunião some no quinto dia, e o áudio vai junto com ela. A
/// estrela guarda os dois — é o mesmo gesto, e uma reunião guardada sem a voz
/// dela seria uma estrela pela metade.
///
/// Fixo, e não preferência: o número existe para o disco não crescer sem que
/// ninguém perceba (uns 600 MB no ritmo de seis reuniões por dia), e quem
/// quer uma reunião para sempre tem a estrela. A conta está em
/// `docs/Ideis projeto/echo-audio-da-reuniao.md`.
abstract final class EchoAudioRetention {
  static const days = 14;

  /// O áudio desta reunião já venceu?
  ///
  /// Por data de calendário, e não por horas: a reunião das 9h de uma
  /// segunda vence na segunda seguinte à próxima, inteira, e não às 9h01.
  static bool isExpired(EchoAudioRef ref, DateTime now) {
    if (ref.isKept) return false;

    final started = DateTime(
      ref.startedAt.year,
      ref.startedAt.month,
      ref.startedAt.day,
    );
    final expires = DateTime(started.year, started.month, started.day + days);

    return !now.isBefore(expires);
  }
}
