import 'package:evergreen/shared/utils/relative_time.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 7, 23, 12);

  String ago(Duration elapsed) =>
      RelativeTime.format(now.subtract(elapsed), now: now);

  test('instantes recentes viram "agora"', () {
    expect(ago(const Duration(seconds: 3)), 'agora');
    expect(ago(const Duration(seconds: 44)), 'agora');
  });

  test('minutos e horas', () {
    expect(ago(const Duration(minutes: 2)), 'há 2 min');
    expect(ago(const Duration(minutes: 59)), 'há 59 min');
    expect(ago(const Duration(hours: 5)), 'há 5 h');
  });

  test('dias, com "ontem" para exatamente um dia', () {
    expect(ago(const Duration(days: 1)), 'ontem');
    expect(ago(const Duration(days: 3)), 'há 3 dias');
  });

  test('semanas e meses usam plural correto', () {
    expect(ago(const Duration(days: 7)), 'há 1 semana');
    expect(ago(const Duration(days: 21)), 'há 3 semanas');
    expect(ago(const Duration(days: 60)), 'há 2 meses');
  });
}
