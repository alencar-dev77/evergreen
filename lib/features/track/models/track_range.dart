import '../../../shared/utils/day_bounds.dart';

/// O recorte de tempo que a tela do Track está mostrando.
///
/// Dois, e não uma régua de datas: o Track existe para responder "o que eu fiz
/// hoje" e para fechar uma sexta-feira. Um seletor de intervalo arbitrário
/// transformaria o módulo num relatório, que é o que ele não é — e, de resto,
/// o histórico do Focus zera toda segunda, então não há foco para mostrar
/// antes disso.
enum TrackRange {
  today('Hoje'),
  week('Semana');

  const TrackRange(this.label);

  /// Rótulo da pílula no seletor.
  final String label;

  /// A partir de quando o recorte lê.
  DateTime since(DateTime now) => switch (this) {
    TrackRange.today => DayBounds.startOfDay(now),
    TrackRange.week => DayBounds.startOfWeek(now),
  };
}
