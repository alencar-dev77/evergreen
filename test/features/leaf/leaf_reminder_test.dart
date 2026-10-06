import 'package:evergreen/features/leaf/models/leaf_reminder.dart';
import 'package:flutter_test/flutter_test.dart';

/// O campo do lembrete entende o jeito como se fala de hora em português — e
/// recusa o que não entende, em vez de chutar.
void main() {
  /// Terça-feira, 6 de outubro de 2026, 10h.
  final now = DateTime(2026, 10, 6, 10);

  DateTime? parse(String text) => LeafReminder.parse(text, now);

  group('duração', () {
    test('minutos, horas e dias', () {
      expect(parse('45 min'), DateTime(2026, 10, 6, 10, 45));
      expect(parse('em 45 minutos'), DateTime(2026, 10, 6, 10, 45));
      expect(parse('2 horas'), DateTime(2026, 10, 6, 12));
      expect(parse('daqui a 2h'), DateTime(2026, 10, 6, 12));
      expect(parse('1h30'), DateTime(2026, 10, 6, 11, 30));
      expect(parse('1 hora e 15 min'), DateTime(2026, 10, 6, 11, 15));
      expect(parse('meia hora'), DateTime(2026, 10, 6, 10, 30));
      expect(parse('2 dias'), DateTime(2026, 10, 8, 10));
    });

    test('"3h" é duração; "14h" é hora do dia', () {
      expect(parse('3h'), DateTime(2026, 10, 6, 13));
      expect(parse('14h'), DateTime(2026, 10, 6, 14));
      expect(parse('em 8h'), DateTime(2026, 10, 6, 18));
    });
  });

  group('hora do dia', () {
    test('hoje, ou amanhã se já passou', () {
      expect(parse('16:30'), DateTime(2026, 10, 6, 16, 30));
      expect(parse('às 16h30'), DateTime(2026, 10, 6, 16, 30));
      expect(parse('9:00'), DateTime(2026, 10, 7, 9));
    });

    test('período do dia', () {
      expect(parse('3 da tarde'), DateTime(2026, 10, 6, 15));
      expect(parse('8 da noite'), DateTime(2026, 10, 6, 20));
      expect(parse('meio-dia'), DateTime(2026, 10, 6, 12));
    });
  });

  group('dia', () {
    test('amanhã, depois de amanhã, hoje', () {
      expect(parse('amanhã'), DateTime(2026, 10, 7, 9));
      expect(parse('Amanhã às 10h'), DateTime(2026, 10, 7, 10));
      expect(parse('depois de amanhã 14:00'), DateTime(2026, 10, 8, 14));
      expect(parse('hoje 18h'), DateTime(2026, 10, 6, 18));
    });

    test('dia da semana: o próximo', () {
      expect(parse('sexta 14h'), DateTime(2026, 10, 9, 14));
      expect(parse('sexta-feira'), DateTime(2026, 10, 9, 9));
      expect(parse('seg 8:30'), DateTime(2026, 10, 12, 8, 30));
      // Terça às 9h já passou nesta terça: é a da semana que vem.
      expect(parse('terça 9h'), DateTime(2026, 10, 13, 9));
      expect(parse('terça 15h'), DateTime(2026, 10, 6, 15));
    });

    test('data', () {
      expect(parse('12/10 9h'), DateTime(2026, 10, 12, 9));
      expect(parse('1/1'), DateTime(2027, 1, 1, 9));
      expect(parse('31/2'), isNull);
    });
  });

  test('o que não é horário não vira lembrete', () {
    expect(parse(''), isNull);
    expect(parse('reunião'), isNull);
    expect(parse('14'), isNull);
    expect(parse('25:00'), isNull);
    expect(parse('hoje 8h'), isNull);
  });

  test('os botões prontos', () {
    expect(LeafReminderPreset.minutes30.at(now), DateTime(2026, 10, 6, 10, 30));
    expect(LeafReminderPreset.tomorrow.at(now), DateTime(2026, 10, 7, 9));
  });

  test('o rodapé do cartão e a prévia', () {
    expect(LeafReminder.label(DateTime(2026, 10, 6, 15, 30), now), '15:30');
    expect(LeafReminder.label(DateTime(2026, 10, 7, 9), now), 'amanhã 09:00');
    expect(LeafReminder.label(DateTime(2026, 10, 9, 14), now), 'sex 14:00');
    expect(LeafReminder.label(DateTime(2026, 10, 20, 14), now), '20 out 14:00');

    expect(
      LeafReminder.preview(DateTime(2026, 10, 6, 10, 45), now),
      'Hoje às 10:45 · em 45 min',
    );
    expect(
      LeafReminder.preview(DateTime(2026, 10, 9, 14), now),
      'Sexta às 14:00 · em 3 dias',
    );
  });
}
