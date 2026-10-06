import '../../../shared/utils/day_bounds.dart';
import '../../focus/data/focus_session_repository.dart';

/// O recorte de tempo que a tela do Track está mostrando.
///
/// Dois, e não uma régua de datas: o Track existe para responder "o que eu fiz
/// hoje" e para fechar uma sexta-feira. Um seletor de intervalo arbitrário
/// transformaria o módulo num relatório, que é o que ele não é. Voltar no tempo
/// é andar de semana em semana dentro do recorte de semana (ver [maxWeeksAgo]),
/// não abrir um calendário.
enum TrackRange {
  today('Hoje'),
  week('Semana');

  const TrackRange(this.label);

  /// Rótulo da pílula no seletor.
  final String label;

  /// Até quantas semanas para trás o recorte de semana anda.
  ///
  /// É o que o Focus guarda, e não o que o Pin ou o Echo guardam: antes disso
  /// as reuniões ainda estariam lá e o foco não, e a semana sairia desenhada
  /// como uma semana sem trabalho.
  static const maxWeeksAgo = FocusSessionRepository.keptWeeks - 1;

  /// A partir de quando o recorte lê. [weeksAgo] só vale para a semana.
  DateTime since(DateTime now, {int weeksAgo = 0}) => switch (this) {
    TrackRange.today => DayBounds.startOfDay(now),
    TrackRange.week => DayBounds.startOfWeek(now, weeksAgo: weeksAgo),
  };

  /// Onde o recorte termina, exclusivo — `null` quando ele chega até agora.
  DateTime? until(DateTime now, {int weeksAgo = 0}) => switch (this) {
    TrackRange.today => null,
    TrackRange.week when weeksAgo == 0 => null,
    TrackRange.week => DayBounds.startOfWeek(now, weeksAgo: weeksAgo - 1),
  };
}
