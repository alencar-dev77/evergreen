/// As duas fronteiras de tempo que o Evergreen usa para agrupar registro: o
/// começo do dia e o começo da semana.
///
/// Construídas por **componentes de data** (e não por `subtract`) para
/// atravessar mudanças de horário de verão sem escorregar uma hora — um
/// `subtract(Duration(days: 1))` na virada do horário cai às 23h do dia
/// anterior, e a linha do dia iria parar no grupo errado.
///
/// A semana começa na segunda porque é onde o histórico do Focus vira
/// (`FocusSessionRepository.trimOldWeeks`): qualquer recorte que discordasse
/// disso cortaria uma semana guardada ao meio.
abstract final class DayBounds {
  static DateTime startOfDay(DateTime moment) =>
      DateTime(moment.year, moment.month, moment.day);

  /// Segunda-feira desta semana, à meia-noite — ou a de [weeksAgo] semanas
  /// atrás.
  static DateTime startOfWeek(DateTime moment, {int weeksAgo = 0}) {
    final daysSinceMonday = moment.weekday - DateTime.monday;
    return DateTime(
      moment.year,
      moment.month,
      moment.day - daysSinceMonday - 7 * weeksAgo,
    );
  }

  /// Quantos dias separam dois momentos, contando por calendário.
  ///
  /// Pela data em UTC, e não por `difference` entre horários locais: no dia em
  /// que o relógio anda, dois dias vizinhos ficam a 23 (ou 25) horas um do
  /// outro, e `inDays` responde 0 — o que jogaria a barra de segunda em cima da
  /// de domingo, uma vez por ano.
  static int daysBetween(DateTime from, DateTime to) => DateTime.utc(
    to.year,
    to.month,
    to.day,
  ).difference(DateTime.utc(from.year, from.month, from.day)).inDays;
}
