import 'package:evergreen/features/echo/models/meeting_segment.dart';
import 'package:evergreen/features/echo/models/meeting_turn.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  MeetingSegment segment(
    Speaker speaker,
    int startMs,
    int endMs,
    String text,
  ) => MeetingSegment(
    speaker: speaker,
    startMs: startMs,
    endMs: endMs,
    text: text,
  );

  group('MeetingTurn', () {
    test('junta os pedaços de uma frase num parágrafo só', () {
      // Exatamente o que o modelo devolveu num teste real de 8 segundos.
      final turns = MeetingTurn.from([
        segment(
          Speaker.others,
          0,
          3800,
          'Bom dia pessoal, vamos fechar o escopo do projeto',
        ),
        segment(Speaker.others, 3800, 4600, ' hoje.'),
        segment(Speaker.others, 4600, 5000, ' ficou'),
        segment(
          Speaker.others,
          5000,
          7800,
          ' decidido que o Lucas manda a proposta até',
        ),
        segment(Speaker.others, 7800, 8600, ' sexta-feira.'),
      ]);

      expect(turns, hasLength(1));
      expect(
        turns.single.text,
        'Bom dia pessoal, vamos fechar o escopo do projeto hoje. ficou '
        'decidido que o Lucas manda a proposta até sexta-feira.',
      );
    });

    test('não põe espaço antes de pontuação', () {
      final turns = MeetingTurn.from([
        segment(Speaker.me, 0, 1000, 'tudo certo'),
        segment(Speaker.me, 1000, 1500, ', combinado'),
        segment(Speaker.me, 1500, 2000, '.'),
      ]);

      expect(turns.single.text, 'tudo certo, combinado.');
    });

    test('trocar de pessoa começa um turno novo', () {
      final turns = MeetingTurn.from([
        segment(Speaker.others, 0, 3000, 'você consegue até sexta?'),
        segment(Speaker.me, 3500, 5000, 'consigo sim'),
        segment(Speaker.others, 5500, 7000, 'ótimo'),
      ]);

      expect(turns, hasLength(3));
      expect(turns.map((turn) => turn.speaker), [
        Speaker.others,
        Speaker.me,
        Speaker.others,
      ]);
    });

    test('silêncio longo corta o turno mesmo sem trocar de pessoa', () {
      // A mesma pessoa voltando depois de meio minuto está dizendo outra coisa.
      final turns = MeetingTurn.from([
        segment(Speaker.others, 0, 2000, 'vamos começar'),
        segment(Speaker.others, 90000, 92000, 'voltando ao assunto'),
      ]);

      expect(turns, hasLength(2));
      expect(turns.first.text, 'vamos começar');
      expect(turns.last.text, 'voltando ao assunto');
    });

    test('o horário do turno é o do primeiro pedaço', () {
      final turns = MeetingTurn.from([
        segment(Speaker.me, 62000, 63000, 'olha só'),
        segment(Speaker.me, 63000, 64000, 'uma coisa'),
      ]);

      expect(turns.single.startMs, 62000);
      expect(turns.single.timestamp, '01:02');
    });

    test('pedaço vazio é descartado sem quebrar o turno', () {
      final turns = MeetingTurn.from([
        segment(Speaker.me, 0, 1000, 'primeira parte'),
        segment(Speaker.me, 1000, 1100, '   '),
        segment(Speaker.me, 1100, 2000, 'segunda parte'),
      ]);

      expect(turns, hasLength(1));
      expect(turns.single.text, 'primeira parte segunda parte');
    });

    test('sem trechos, sem turnos', () {
      expect(MeetingTurn.from(const []), isEmpty);
    });
  });

  group('pedaços com relógio', () {
    const withWords = MeetingSegment(
      speaker: Speaker.others,
      startMs: 0,
      endMs: 2000,
      text: ' vamos fechar o escopo',
      words: [
        MeetingWord(startMs: 0, endMs: 400, text: ' vamos'),
        MeetingWord(startMs: 450, endMs: 900, text: ' fechar'),
        MeetingWord(startMs: 950, endMs: 1100, text: ' o'),
        MeetingWord(startMs: 1150, endMs: 2000, text: ' escopo'),
      ],
    );

    const old = MeetingSegment(
      speaker: Speaker.others,
      startMs: 2100,
      endMs: 3000,
      text: ' hoje.',
    );

    test('os pedaços somam exatamente o texto da fala', () {
      final turn = MeetingTurn.from(const [withWords, old]).single;

      expect(turn.pieces.map((piece) => piece.text).join(), turn.text);
      expect(turn.text, 'vamos fechar o escopo hoje.');
      // Palavra por palavra onde há palavras; o trecho antigo, inteiro.
      expect(turn.pieces, hasLength(5));
      expect(turn.endMs, 3000);
    });

    test('palavras que não batem com o trecho caem para o trecho inteiro', () {
      const mismatch = MeetingSegment(
        speaker: Speaker.me,
        startMs: 0,
        endMs: 1000,
        text: 'oi',
        words: [MeetingWord(startMs: 0, endMs: 500, text: 'olá')],
      );

      final turn = MeetingTurn.from(const [mismatch]).single;
      expect(turn.pieces.single.text, 'oi');
    });

    test('o que já foi dito fica aceso, cumulativo', () {
      final turn = MeetingTurn.from(const [withWords]).single;

      expect(turn.spokenCount(0), 1); // "vamos" começou
      expect(turn.spokenCount(500), 2); // até "fechar"
      expect(turn.spokenCount(920), 2); // entre palavras, nada se apaga
      expect(turn.spokenCount(1500), 4); // até "escopo"
      expect(turn.spokenCount(9000), 4, reason: 'a fala que passou fica toda');
    });

    test('a fala que ainda não chegou fica apagada', () {
      final turn = MeetingTurn.from(const [old]).single;

      expect(turn.spokenCount(1000), 0);
    });
  });
}
