/// Datas e horários curtos em português, para metadados de lista.
///
/// Escrito à mão em vez de `DateFormat('pt_BR')` porque a formatação com locale
/// explícito exige inicializar os dados de localização no start do app — custo
/// e risco desproporcionais para "Hoje · 09:12".
abstract final class DayLabel {
  static const _months = <String>[
    'jan',
    'fev',
    'mar',
    'abr',
    'mai',
    'jun',
    'jul',
    'ago',
    'set',
    'out',
    'nov',
    'dez',
  ];

  /// Abreviações dos dias da semana, de segunda a domingo.
  ///
  /// Na ordem em que a faixa de barras (`EgDayBars`) as desenha — a mesma
  /// ordem do `DateTime.weekday`, que começa na segunda.
  static const weekdays = <String>[
    'seg',
    'ter',
    'qua',
    'qui',
    'sex',
    'sáb',
    'dom',
  ];

  /// "Hoje", "Ontem" ou "23 jul" — e com o ano quando não for o corrente.
  static String of(DateTime moment, {DateTime? now}) {
    final today = _startOfDay(now ?? DateTime.now());
    final day = _startOfDay(moment);
    final difference = today.difference(day).inDays;

    if (difference == 0) return 'Hoje';
    if (difference == 1) return 'Ontem';

    final label = '${moment.day} ${_months[moment.month - 1]}';
    return moment.year == today.year ? label : '$label ${moment.year}';
  }

  /// Horário no formato de 24h (`09:12`), como o resto do sistema em pt-BR.
  static String time(DateTime moment) =>
      '${_pad(moment.hour)}:${_pad(moment.minute)}';

  static DateTime _startOfDay(DateTime moment) =>
      DateTime(moment.year, moment.month, moment.day);

  static String _pad(int value) => value.toString().padLeft(2, '0');
}
