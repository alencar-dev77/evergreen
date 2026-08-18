/// Quem falou num trecho da reunião.
///
/// São só dois, e é de propósito: o Echo não separa voz por voz. Ele grava duas
/// faixas — o microfone, que é você, e o áudio do computador, que é todo mundo
/// menos você — e o rótulo sai de qual faixa o trecho veio. Não há modelo de
/// reconhecimento de voz envolvido, e por isso não há como errar.
enum Speaker {
  me('Você'),
  others('Reunião');

  const Speaker(this.label);

  final String label;

  static Speaker fromName(String name) =>
      values.firstWhere((speaker) => speaker.name == name, orElse: () => Speaker.others);
}

/// Um trecho falado, com quem falou e quando.
class MeetingSegment {
  const MeetingSegment({
    required this.speaker,
    required this.startMs,
    required this.endMs,
    required this.text,
  });

  final Speaker speaker;

  /// Milissegundos desde o começo da gravação.
  ///
  /// É o que permite intercalar as duas faixas numa conversa só: cada uma é
  /// transcrita em separado, e o tempo é a única coisa que as reaproxima.
  final int startMs;
  final int endMs;

  final String text;

  factory MeetingSegment.fromMap(Map<Object?, Object?> map) => MeetingSegment(
    speaker: Speaker.fromName(map['speaker'] as String? ?? 'others'),
    startMs: (map['startMs'] as num?)?.toInt() ?? 0,
    endMs: (map['endMs'] as num?)?.toInt() ?? 0,
    text: map['text'] as String? ?? '',
  );

  Map<String, Object?> toJson() => {
    'speaker': speaker.name,
    'startMs': startMs,
    'endMs': endMs,
    'text': text,
  };

  /// `12:03` — o relógio do trecho dentro da reunião.
  String get timestamp {
    final totalSeconds = startMs ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;

    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
}
