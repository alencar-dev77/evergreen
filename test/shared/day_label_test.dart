import 'package:evergreen/shared/utils/day_label.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 7, 25, 15, 30);

  test('o dia corrente e o anterior viram palavra', () {
    expect(DayLabel.of(DateTime(2026, 7, 25, 0, 5), now: now), 'Hoje');
    expect(DayLabel.of(DateTime(2026, 7, 24, 23, 55), now: now), 'Ontem');
  });

  test('datas mais antigas do mesmo ano vão sem o ano', () {
    expect(DayLabel.of(DateTime(2026, 7, 20), now: now), '20 jul');
    expect(DayLabel.of(DateTime(2026, 1, 3), now: now), '3 jan');
  });

  test('outro ano aparece por extenso', () {
    expect(DayLabel.of(DateTime(2025, 12, 31), now: now), '31 dez 2025');
  });

  test('horário em 24h, com zero à esquerda', () {
    expect(DayLabel.time(DateTime(2026, 7, 25, 9, 12)), '09:12');
    expect(DayLabel.time(DateTime(2026, 7, 25, 14, 5)), '14:05');
  });
}
