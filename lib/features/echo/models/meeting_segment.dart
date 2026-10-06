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

  /// O rótulo padrão, de quem nunca disse como se chama.
  final String label;

  /// O rótulo com o nome da pessoa, quando ela deu um.
  ///
  /// Vale para a tela e para o texto que vai ao modelo, e é de propósito que
  /// sejam o mesmo: é do rótulo que o resumo tira como chamar quem falou, e uma
  /// transcrição que mostra "Lucas" enquanto manda "Você" para o modelo produz
  /// um resumo que fala de um estranho. Só [Speaker.me] tem nome — do outro
  /// lado pode haver cinco pessoas, e o Echo não separa voz por voz.
  String labelFor(String userName) =>
      this == Speaker.me && userName.isNotEmpty ? userName : label;

  static Speaker fromName(String name) => values.firstWhere(
    (speaker) => speaker.name == name,
    orElse: () => Speaker.others,
  );
}

/// Uma palavra do trecho, com o relógio dela.
///
/// É o que o player usa para destacar o que está tocando e o que o clique na
/// transcrição usa para levar o áudio até ali. [text] vem com o espaço e a
/// pontuação colados como o modelo de fala entregou: juntar as palavras de um
/// trecho devolve o texto dele, sem nada a mais nem a menos.
class MeetingWord {
  const MeetingWord({
    required this.startMs,
    required this.endMs,
    required this.text,
  });

  final int startMs;
  final int endMs;
  final String text;

  /// `[início, fim, texto]` — uma lista, e não um mapa: são milhares por
  /// reunião, e as chaves repetidas em cada uma quase dobrariam a coluna.
  static MeetingWord? fromJson(Object? raw) {
    if (raw is! List || raw.length < 3) return null;

    final start = raw[0];
    final end = raw[1];
    final text = raw[2];
    if (start is! num || end is! num || text is! String) return null;

    return MeetingWord(startMs: start.toInt(), endMs: end.toInt(), text: text);
  }

  List<Object> toJson() => [startMs, endMs, text];
}

/// Um trecho falado, com quem falou e quando.
class MeetingSegment {
  const MeetingSegment({
    required this.speaker,
    required this.startMs,
    required this.endMs,
    required this.text,
    this.words = const [],
  });

  final Speaker speaker;

  /// Milissegundos desde o começo da gravação.
  ///
  /// É o que permite intercalar as duas faixas numa conversa só: cada uma é
  /// transcrita em separado, e o tempo é a única coisa que as reaproxima.
  final int startMs;
  final int endMs;

  final String text;

  /// As palavras com relógio, quando o modelo de fala as deu.
  ///
  /// Vazio em reunião transcrita antes de o Echo guardar o relógio de cada
  /// palavra — aí o destaque anda de trecho em trecho, não de palavra em
  /// palavra.
  final List<MeetingWord> words;

  factory MeetingSegment.fromMap(Map<Object?, Object?> map) => MeetingSegment(
    speaker: Speaker.fromName(map['speaker'] as String? ?? 'others'),
    startMs: (map['startMs'] as num?)?.toInt() ?? 0,
    endMs: (map['endMs'] as num?)?.toInt() ?? 0,
    text: map['text'] as String? ?? '',
    words: [
      for (final raw in (map['words'] as List<Object?>?) ?? const [])
        ?MeetingWord.fromJson(raw),
    ],
  );

  Map<String, Object?> toJson() => {
    'speaker': speaker.name,
    'startMs': startMs,
    'endMs': endMs,
    'text': text,
    if (words.isNotEmpty) 'words': [for (final word in words) word.toJson()],
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
