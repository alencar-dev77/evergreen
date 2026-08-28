import 'package:evergreen/shared/utils/duration_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('countdown', () {
    test('sempre com dois dígitos, para a largura não dançar', () {
      expect(DurationFormat.countdown(const Duration(minutes: 25)), '25:00');
      expect(
        DurationFormat.countdown(const Duration(minutes: 4, seconds: 7)),
        '04:07',
      );
    });

    test('trata o tempo esgotado como zero', () {
      expect(DurationFormat.countdown(const Duration(seconds: -3)), '00:00');
    });

    test('descarta a fração de segundo que nunca chega à tela', () {
      expect(
        DurationFormat.countdown(
          const Duration(seconds: 90, milliseconds: 750),
        ),
        '01:30',
      );
    });
  });

  group('clock', () {
    test('abaixo de uma hora é idêntico ao countdown', () {
      expect(
        DurationFormat.clock(const Duration(minutes: 59, seconds: 58)),
        '59:58',
      );
      expect(DurationFormat.clock(Duration.zero), '00:00');
    });

    test('a partir de uma hora ganha a casa das horas', () {
      expect(
        DurationFormat.clock(
          const Duration(hours: 1, minutes: 59, seconds: 58),
        ),
        '1:59:58',
      );
      expect(DurationFormat.clock(const Duration(hours: 2)), '2:00:00');
    });

    test('trata o tempo esgotado como zero', () {
      expect(DurationFormat.clock(const Duration(seconds: -3)), '00:00');
    });
  });

  group('compact', () {
    test('minutos puros abaixo de uma hora', () {
      expect(DurationFormat.compact(const Duration(minutes: 45)), '45 min');
      expect(DurationFormat.compact(Duration.zero), '0 min');
    });

    test('horas cheias não mostram os minutos', () {
      expect(DurationFormat.compact(const Duration(hours: 2)), '2h');
    });

    test('horas e minutos', () {
      expect(
        DurationFormat.compact(const Duration(hours: 1, minutes: 5)),
        '1h 05min',
      );
    });

    test('os segundos não entram na conta', () {
      expect(
        DurationFormat.compact(const Duration(minutes: 24, seconds: 59)),
        '24 min',
      );
    });
  });
}
