import 'package:evergreen/features/echo/models/meeting_segment.dart';
import 'package:evergreen/features/echo/models/meeting_turn.dart';
import 'package:evergreen/features/echo/models/voice_separation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Um trecho com uma palavra a cada [step] ms, a partir de [startMs].
  ///
  /// As palavras levam o espaço na frente, como o modelo de fala entrega — e
  /// juntas dão o texto do trecho, que é a condição para o Echo confiar nelas.
  MeetingSegment spoken(
    List<String> words, {
    Speaker speaker = Speaker.others,
    int startMs = 0,
    int step = 400,
  }) {
    final timed = [
      for (var index = 0; index < words.length; index++)
        MeetingWord(
          startMs: startMs + index * step,
          endMs: startMs + (index + 1) * step,
          text: index == 0 ? words[index] : ' ${words[index]}',
        ),
    ];

    return MeetingSegment(
      speaker: speaker,
      startMs: startMs,
      endMs: startMs + words.length * step,
      text: timed.map((word) => word.text).join(),
      words: timed,
    );
  }

  VoiceTurn turn(String voice, int startMs, int endMs) =>
      VoiceTurn(voice: voice, startMs: startMs, endMs: endMs);

  group('VoiceSeparation', () {
    test('parte o trecho onde a voz troca, pelo relógio das palavras', () {
      // "pode ser na sexta? Sexta eu consigo." — um trecho só do modelo de
      // fala, duas pessoas de verdade.
      final segments = VoiceSeparation.apply(
        [
          spoken(['pode', 'ser', 'na', 'sexta?', 'Sexta', 'eu', 'consigo.']),
        ],
        [turn('S1', 0, 1600), turn('S2', 1600, 2800)],
      );

      expect(segments.map((segment) => segment.text), [
        'pode ser na sexta?',
        ' Sexta eu consigo.',
      ]);
      expect(segments.map((segment) => segment.voice), [1, 2]);

      // As pontas de fora continuam as do trecho; a costura é a palavra.
      expect(segments.first.startMs, 0);
      expect(segments.first.endMs, 1600);
      expect(segments.last.startMs, 1600);
      expect(segments.last.endMs, 2800);
    });

    test('o texto da reunião não muda uma letra ao ser partido', () {
      final original = [
        spoken(['bom', 'dia,', 'tudo', 'certo?']),
        spoken(['tudo', 'ótimo,', 'e', 'você?'], startMs: 2000),
      ];

      final separated = VoiceSeparation.apply(original, [
        turn('A', 0, 1000),
        turn('B', 1000, 2000),
        turn('A', 2000, 3600),
      ]);

      expect(
        separated.map((segment) => segment.text).join(),
        original.map((segment) => segment.text).join(),
      );
    });

    test('numera na ordem em que cada voz aparece na reunião', () {
      // O identificador do modelo não quer dizer nada: "S7" falou primeiro,
      // então é a Pessoa 1.
      final segments = VoiceSeparation.apply(
        [
          spoken(['oi'], startMs: 0),
          spoken(['olá'], startMs: 1000),
          spoken(['de', 'novo'], startMs: 2000),
        ],
        [turn('S7', 0, 500), turn('S2', 1000, 1500), turn('S7', 2000, 3000)],
      );

      expect(segments.map((segment) => segment.voice), [1, 2, 1]);
      expect(segments.map((segment) => segment.labelFor('')), [
        'Pessoa 1',
        'Pessoa 2',
        'Pessoa 1',
      ]);
    });

    test('três vozes, três números, sem pular nenhum', () {
      final segments = VoiceSeparation.apply(
        [
          spoken(['um'], startMs: 0),
          spoken(['dois'], startMs: 1000),
          spoken(['três'], startMs: 2000),
          spoken(['um', 'de', 'novo'], startMs: 3000),
        ],
        [
          turn('x', 0, 400),
          turn('y', 1000, 1400),
          turn('z', 2000, 2400),
          turn('x', 3000, 4200),
        ],
      );

      expect(segments.map((segment) => segment.voice), [1, 2, 3, 1]);
    });

    test('o pedaço partido volta para o seu lugar no tempo', () {
      // O trecho da reunião vai de 0 a 6 s e o seu "Oi" entra aos 3 s, no
      // meio dele. Partido em duas vozes, o segundo pedaço começa aos 4 s —
      // e precisa ficar depois do seu "Oi", não antes. Fora de ordem, a
      // leitura punha a sua fala depois da resposta a ela, e o player
      // acendia o turno errado.
      const words = [
        MeetingWord(startMs: 0, endMs: 1000, text: 'pode'),
        MeetingWord(startMs: 1000, endMs: 2000, text: ' ser?'),
        MeetingWord(startMs: 4000, endMs: 5000, text: ' Sexta'),
        MeetingWord(startMs: 5000, endMs: 6000, text: ' consigo.'),
      ];
      final segments = VoiceSeparation.apply(
        [
          const MeetingSegment(
            speaker: Speaker.others,
            startMs: 0,
            endMs: 6000,
            text: 'pode ser? Sexta consigo.',
            words: words,
          ),
          spoken(['Oi'], speaker: Speaker.me, startMs: 3000),
        ],
        [turn('S1', 0, 2500), turn('S2', 3800, 6000)],
      );

      expect(segments.map((segment) => segment.labelFor('')), [
        'Pessoa 1',
        'Você',
        'Pessoa 2',
      ]);
      expect(segments.map((segment) => segment.startMs), [0, 3000, 4000]);
    });

    test('o microfone nunca ganha voz — ele é você', () {
      final segments = VoiceSeparation.apply(
        [
          spoken(['pergunta'], startMs: 0),
          spoken(['minha', 'resposta'], speaker: Speaker.me, startMs: 1000),
          spoken(['réplica'], startMs: 2000),
        ],
        [turn('A', 0, 900), turn('B', 900, 3000)],
      );

      final mine = segments.singleWhere((s) => s.speaker == Speaker.me);
      expect(mine.voice, isNull);
      expect(mine.labelFor('Lucas'), 'Lucas');
      expect(
        segments.where((s) => s.speaker == Speaker.others).map((s) => s.voice),
        [1, 2],
      );
    });

    test('uma voz só do outro lado continua "Reunião"', () {
      final original = [
        spoken(['vamos', 'começar']),
      ];

      final segments = VoiceSeparation.apply(original, [
        turn('S1', 0, 400),
        turn('S1', 400, 800),
      ]);

      expect(segments, same(original));
      expect(segments.single.labelFor(''), 'Reunião');
    });

    test('duas vozes no modelo e uma só nas palavras também', () {
      // A segunda voz falou onde o modelo de fala não ouviu nada — ruído, ou
      // um murmúrio. Para quem lê, do outro lado havia uma pessoa.
      final original = [
        spoken(['só', 'eu', 'falei']),
      ];

      final segments = VoiceSeparation.apply(original, [
        turn('S1', 0, 1200),
        turn('S2', 60000, 61000),
      ]);

      expect(segments, same(original));
    });

    test('sem resposta da diarização, a transcrição sai como veio', () {
      final original = [
        spoken(['nada', 'muda']),
      ];

      expect(VoiceSeparation.apply(original, const []), same(original));
    });

    test('uma palavra que "troca de dono" no meio da frase volta', () {
      // A diarização erra nas bordas — uma tosse, uma palavra dita junto —, e
      // sem o piso a frase sairia em três parágrafos.
      final segments = VoiceSeparation.apply(
        [
          spoken(['a', 'gente', 'fecha', 'isso', 'amanhã'], step: 300),
          spoken(['certo'], startMs: 3000),
        ],
        [
          turn('A', 0, 600),
          turn('B', 600, 900), // "fecha", 300 ms
          turn('A', 900, 1500),
          turn('B', 3000, 3500),
        ],
      );

      expect(segments.first.text, 'a gente fecha isso amanhã');
      expect(segments.first.voice, 1);
      expect(segments.last.voice, 2);
    });

    test('uma fala curta na ponta do trecho não é ilha', () {
      // Sem a mesma voz dos dois lados, ela é uma troca de pessoa de verdade.
      final segments = VoiceSeparation.apply(
        [
          spoken(['então', 'combinado', 'sim'], step: 300),
        ],
        [turn('A', 0, 600), turn('B', 600, 900)],
      );

      expect(segments.map((segment) => segment.text), [
        'então combinado',
        ' sim',
      ]);
    });

    test('palavra fora de toda voz fica com a mais próxima no tempo', () {
      final segments = VoiceSeparation.apply(
        [
          spoken(['primeiro'], startMs: 0),
          // Entre as duas vozes, mais perto da segunda.
          spoken(['murmúrio'], startMs: 2400),
          spoken(['segundo'], startMs: 3000),
        ],
        [turn('A', 0, 400), turn('B', 3000, 3400)],
      );

      expect(segments.map((segment) => segment.voice), [1, 2, 2]);
    });

    test('trecho sem relógio por palavra vai inteiro para quem mais falou', () {
      const semPalavras = MeetingSegment(
        speaker: Speaker.others,
        startMs: 1000,
        endMs: 4000,
        text: 'reunião antiga, sem palavras',
      );

      final segments = VoiceSeparation.apply(
        [
          spoken(['antes'], startMs: 0),
          semPalavras,
        ],
        [turn('A', 0, 1500), turn('B', 1500, 4000)],
      );

      expect(segments, hasLength(2));
      expect(segments.last.text, semPalavras.text);
      expect(segments.last.voice, 2);
    });

    test('ignora intervalos sem duração', () {
      final original = [
        spoken(['oi']),
      ];

      expect(
        VoiceSeparation.apply(original, [turn('A', 0, 400), turn('B', 50, 50)]),
        same(original),
      );
    });

    test('vozes diferentes viram parágrafos diferentes, mesmo sem pausa', () {
      final turns = MeetingTurn.from(
        VoiceSeparation.apply(
          [
            spoken(['pode', 'ser', 'sexta?', 'pode', 'sim.']),
          ],
          [turn('A', 0, 1200), turn('B', 1200, 2000)],
        ),
      );

      expect(turns.map((turn) => turn.labelFor('')), ['Pessoa 1', 'Pessoa 2']);
      expect(turns.map((turn) => turn.text), ['pode ser sexta?', 'pode sim.']);
    });
  });

  group('VoiceTurn.fromMap', () {
    test('lê o que o canal devolve', () {
      final parsed = VoiceTurn.fromMap({
        'voice': 'S1',
        'startMs': 1200,
        'endMs': 3400.0,
      });

      expect(parsed?.voice, 'S1');
      expect(parsed?.startMs, 1200);
      expect(parsed?.endMs, 3400);
    });

    test('descarta o que não tem forma de voz', () {
      expect(VoiceTurn.fromMap({'voice': 1, 'startMs': 0, 'endMs': 1}), isNull);
      expect(VoiceTurn.fromMap({'voice': 'S1'}), isNull);
    });
  });

  group('MeetingSegment.voice', () {
    test('sobrevive ao banco — e trecho sem voz não ganha a chave', () {
      final withVoice = spoken(['oi']).withVoice(2);
      final roundTrip = MeetingSegment.fromMap(withVoice.toJson());

      expect(roundTrip.voice, 2);
      expect(roundTrip.words, hasLength(1));
      expect(spoken(['oi']).toJson().containsKey('voice'), isFalse);
    });

    test('reunião de antes da separação continua lendo "Reunião"', () {
      final legado = MeetingSegment.fromMap({
        'speaker': 'others',
        'startMs': 0,
        'endMs': 1000,
        'text': 'gravada na v0.26',
      });

      expect(legado.voice, isNull);
      expect(legado.labelFor('Lucas'), 'Reunião');
    });
  });
}
