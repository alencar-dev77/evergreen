import 'package:evergreen/shared/utils/day_groups.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 8, 18, 15);

  DateTime at(int day, int hour) => DateTime(2026, 8, day, hour);

  test('junta o que é do mesmo dia sob um rótulo só', () {
    final groups = DayGroups.of(
      [at(18, 14), at(18, 9), at(17, 10)],
      (item) => item,
      now: now,
    );

    expect(groups.map((group) => group.label), ['Hoje', 'Ontem']);
    expect(groups.first.items, [at(18, 14), at(18, 9)]);
    expect(groups.last.items, [at(17, 10)]);
  });

  test('preserva a ordem de chegada, dos grupos e de dentro deles', () {
    final groups = DayGroups.of(
      [at(18, 9), at(16, 8), at(17, 11)],
      (item) => item,
      now: now,
    );

    expect(groups.map((group) => group.label), ['Hoje', '16 ago', 'Ontem']);
  });

  test('um dia solto não vira dois grupos com o mesmo nome', () {
    final groups = DayGroups.of(
      [at(18, 9), at(17, 8), at(18, 7)],
      (item) => item,
      now: now,
    );

    expect(groups.map((group) => group.label), ['Hoje', 'Ontem']);
    expect(groups.first.items.length, 2);
  });

  test('lista vazia não produz grupo nenhum', () {
    expect(DayGroups.of(<DateTime>[], (item) => item, now: now), isEmpty);
  });
}
