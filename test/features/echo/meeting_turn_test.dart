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
}
