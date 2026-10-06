import '../../../shared/utils/day_bounds.dart';
import '../../../shared/utils/day_label.dart';
import '../../../shared/utils/duration_format.dart';

/// As quatro respostas prontas do seletor de lembrete.
///
/// Quatro, e fixas: "daqui a pouco", "daqui a uma hora", "mais tarde" e
/// "amanhã cedo" cobrem quase todo lembrete de post-it. Uma lista que mudasse
/// com a hora do dia seria mais esperta e menos decorável — quem usa sabe que
/// o terceiro botão é "3 h" sem precisar ler.
enum LeafReminderPreset {
  minutes30('30 min'),
  hour1('1 h'),
  hours3('3 h'),
  tomorrow('Amanhã 9h');

  const LeafReminderPreset(this.label);

  final String label;

  DateTime at(DateTime now) => switch (this) {
    LeafReminderPreset.minutes30 => now.add(const Duration(minutes: 30)),
    LeafReminderPreset.hour1 => now.add(const Duration(hours: 1)),
    LeafReminderPreset.hours3 => now.add(const Duration(hours: 3)),
    LeafReminderPreset.tomorrow => DateTime(
      now.year,
      now.month,
      now.day + 1,
      9,
    ),
  };
}

/// Lê "16:30", "amanhã 10h", "sexta 14h", "em 45 min" — e escreve de volta.
///
/// **Um campo, não um calendário.** O Leaf é um painel de teclado, e um
/// seletor de data com setas e roletas obrigaria a soltar o teclado para
/// marcar "sexta às duas". O que torna o campo seguro é a prévia: a tela
/// mostra o que entendeu antes de a pessoa confirmar, então uma leitura
/// diferente da pretendida nunca vira lembrete em silêncio.
abstract final class LeafReminder {
  /// Hora usada quando só o dia foi dito ("amanhã", "sexta").
  static const defaultHour = 9;

  /// O instante que [input] descreve, visto de [now] — ou `null` se o texto
  /// não for um horário, ou se ele já passou.
  static DateTime? parse(String input, DateTime now) {
    final text = _normalize(input);
    if (text.isEmpty) return null;

    final at = _duration(text, now) ?? _moment(text, now);
    return at != null && at.isAfter(now) ? at : null;
  }

  /// Como o cartão mostra o lembrete no rodapé: "15:30", "amanhã 09:00",
  /// "sex 14:00", "12 out 14:00".
  static String label(DateTime at, DateTime now) {
    final time = DayLabel.time(at);

    return switch (DayBounds.daysBetween(now, at)) {
      0 => time,
      1 => 'amanhã $time',
      < 7 => '${DayLabel.weekdays[at.weekday - 1]} $time',
      _ => '${DayLabel.dayMonth(at)} $time',
    };
  }

  /// O que o seletor mostra enquanto a pessoa digita: "Hoje às 15:30 · em 45
  /// min". O dia por extenso e a distância juntos — um responde "é o que eu
  /// quis dizer?", o outro "falta quanto?".
  static String preview(DateTime at, DateTime now) {
    final days = DayBounds.daysBetween(now, at);
    final day = switch (days) {
      0 => 'Hoje',
      1 => 'Amanhã',
      < 7 => _weekdays[at.weekday - 1],
      _ => DayLabel.dayMonth(at),
    };

    return '$day às ${DayLabel.time(at)} · ${relative(at, now)}';
  }

  /// "em 45 min", "em 2h 10min", "em 3 dias".
  static String relative(DateTime at, DateTime now) {
    final days = DayBounds.daysBetween(now, at);
    if (days >= 2) return 'em $days dias';

    // Arredondado para cima: "em 0 min" para um lembrete daqui a 40 segundos
    // diria que ele já passou.
    final minutes = (at.difference(now).inSeconds / 60).ceil();
    return 'em ${DurationFormat.compact(Duration(minutes: minutes))}';
  }

  static const _weekdays = <String>[
    'Segunda',
    'Terça',
    'Quarta',
    'Quinta',
    'Sexta',
    'Sábado',
    'Domingo',
  ];

  /// Minúsculas, sem acento e sem espaço sobrando: "Amanhã  às 10H" e
  /// "amanha as 10h" são a mesma frase.
  static String _normalize(String input) {
    const accents = {
      'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', //
      'é': 'e', 'ê': 'e', 'í': 'i', 'ó': 'o', //
      'ô': 'o', 'õ': 'o', 'ú': 'u', 'ç': 'c',
    };

    final lower = input.toLowerCase().trim();
    final buffer = StringBuffer();
    for (final char in lower.split('')) {
      buffer.write(accents[char] ?? char);
    }

    return buffer
        .toString()
        .replaceAll(RegExp(r'[.!]+$'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  // ── Duração: "em 45 min", "2 horas", "1h30" ──────────────────────────────

  static final _prefix = RegExp(r'^(?:em|daqui(?: a)?|\+) ?');
  static final _minutes = RegExp(r'^(\d+) ?(?:m|min|mins|minuto|minutos)$');
  static final _hourWords = RegExp(r'^(\d+) ?(?:hr|hrs|hora|horas)$');
  static final _hoursShort = RegExp(r'^(\d+) ?h(?: ?(\d{1,2}) ?(?:m|min)?)?$');
  static final _hoursAnd = RegExp(
    r'^(\d+) ?(?:h|hora|horas) e (\d+) ?(?:m|min|minuto|minutos)?$',
  );
  static final _days = RegExp(r'^(\d+) ?(?:d|dia|dias)$');

  /// "3h" é daqui a três horas ou às três da manhã? **Até 6, duração; de 7
  /// em diante, hora do dia.** Ninguém marca lembrete para as 3h da
  /// madrugada, e ninguém pede "daqui a 14 horas" escrevendo "14h". O "em"
  /// na frente desfaz a dúvida, e a prévia mostra a leitura de qualquer jeito.
  static const _maxBareHours = 6;

  static DateTime? _duration(String text, DateTime now) {
    final prefixed = _prefix.hasMatch(text);
    final body = text.replaceFirst(_prefix, '');

    if (body == 'meia hora') return now.add(const Duration(minutes: 30));
    if (body == 'uma hora') return now.add(const Duration(hours: 1));

    if (_minutes.firstMatch(body) case final m?) {
      return now.add(Duration(minutes: int.parse(m[1]!)));
    }
    if (_hourWords.firstMatch(body) case final m?) {
      return now.add(Duration(hours: int.parse(m[1]!)));
    }
    if (_hoursAnd.firstMatch(body) case final m?) {
      return now.add(
        Duration(hours: int.parse(m[1]!), minutes: int.parse(m[2]!)),
      );
    }
    if (_days.firstMatch(body) case final m?) {
      final days = int.parse(m[1]!);
      return DateTime(
        now.year,
        now.month,
        now.day + days,
        now.hour,
        now.minute,
      );
    }
    if (_hoursShort.firstMatch(body) case final m?) {
      final hours = int.parse(m[1]!);
      if (!prefixed && hours > _maxBareHours) return null;
      return now.add(Duration(hours: hours, minutes: int.parse(m[2] ?? '0')));
    }

    return null;
  }

  // ── Dia e hora: "amanhã 10h", "sexta às 14:30", "16:30", "12/10 9h" ──────

  static final _weekdayPattern = RegExp(
    r'\b(segunda|seg|terca|ter|quarta|qua|quinta|qui|sexta|sex|sabado|sab|'
    r'domingo|dom)(?:-feira| feira)?\b',
  );
  static final _datePattern = RegExp(r'\b(\d{1,2})/(\d{1,2})(?:/(\d{2,4}))?\b');
  static final _clock = RegExp(r'^(\d{1,2})(?:(?::|h) ?(\d{2})|h)?$');
  static final _period = RegExp(r' ?(?:da|de) (manha|tarde|noite)$');
  static final _filler = RegExp(r'\b(?:as|a|ao|na|no|em|para|pra)\b');

  static const _weekdayKeys = <String, int>{
    'seg': DateTime.monday,
    'ter': DateTime.tuesday,
    'qua': DateTime.wednesday,
    'qui': DateTime.thursday,
    'sex': DateTime.friday,
    'sab': DateTime.saturday,
    'dom': DateTime.sunday,
  };

  static DateTime? _moment(String text, DateTime now) {
    var rest = text;
    DateTime? day;
    var explicitYear = false;

    if (rest.contains('depois de amanha')) {
      day = DateTime(now.year, now.month, now.day + 2);
      rest = rest.replaceFirst('depois de amanha', ' ');
    } else if (RegExp(r'\bamanha\b').hasMatch(rest)) {
      day = DateTime(now.year, now.month, now.day + 1);
      rest = rest.replaceFirst(RegExp(r'\bamanha\b'), ' ');
    } else if (RegExp(r'\bhoje\b').hasMatch(rest)) {
      day = DateTime(now.year, now.month, now.day);
      rest = rest.replaceFirst(RegExp(r'\bhoje\b'), ' ');
    } else if (_weekdayPattern.firstMatch(rest) case final m?) {
      final weekday = _weekdayKeys[m[1]!.substring(0, 3)]!;
      final ahead = (weekday - now.weekday) % 7;
      day = DateTime(now.year, now.month, now.day + ahead);
      rest = rest.replaceFirst(m[0]!, ' ');
    } else if (_datePattern.firstMatch(rest) case final m?) {
      final month = int.parse(m[2]!);
      final dayOfMonth = int.parse(m[1]!);
      if (month < 1 || month > 12 || dayOfMonth < 1 || dayOfMonth > 31) {
        return null;
      }
      var year = now.year;
      if (m[3] case final y?) {
        explicitYear = true;
        year = y.length == 2 ? 2000 + int.parse(y) : int.parse(y);
      }
      day = DateTime(year, month, dayOfMonth);
      // "31/2" vira 3 de março no `DateTime`; é data que não existe.
      if (day.month != month) return null;
      rest = rest.replaceFirst(m[0]!, ' ');
    }

    final time = _time(
      rest.replaceAll(_filler, ' ').trim(),
      hasDay: day != null,
    );
    if (time == null) return null;

    final (hour, minute) = time;
    if (day == null) {
      // Só a hora: hoje, ou amanhã se ela já passou.
      final today = DateTime(now.year, now.month, now.day, hour, minute);
      return today.isAfter(now)
          ? today
          : DateTime(now.year, now.month, now.day + 1, hour, minute);
    }

    var at = DateTime(day.year, day.month, day.day, hour, minute);
    if (!at.isAfter(now)) {
      // "sexta" dito numa sexta à noite é a próxima; "12/10" passado é o do
      // ano que vem. Os outros casos passados não têm segunda leitura.
      if (_weekdayPattern.hasMatch(text)) {
        at = DateTime(at.year, at.month, at.day + 7, hour, minute);
      } else if (_datePattern.hasMatch(text) && !explicitYear) {
        at = DateTime(at.year + 1, at.month, at.day, hour, minute);
      }
    }
    return at;
  }

  /// `(hora, minuto)` de "14:30", "14h30", "14h", "9 da manhã", "meio-dia" — ou
  /// a hora padrão quando o dia veio sozinho.
  static (int, int)? _time(String text, {required bool hasDay}) {
    var rest = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (rest.isEmpty) return hasDay ? (defaultHour, 0) : null;

    if (rest == 'meio-dia' || rest == 'meio dia') return (12, 0);
    if (rest == 'meia-noite' || rest == 'meia noite') return (0, 0);

    String? period;
    if (_period.firstMatch(rest) case final m?) {
      period = m[1];
      rest = rest.substring(0, m.start).trim();
    }

    final m = _clock.firstMatch(rest);
    if (m == null) return null;

    // Número solto ("sexta 14") só vale com o dia ao lado ou o período depois:
    // sozinho, "14" pode ser qualquer coisa.
    final bare = !rest.contains('h') && !rest.contains(':');
    if (bare && !hasDay && period == null) return null;

    var hour = int.parse(m[1]!);
    final minute = int.parse(m[2] ?? '0');
    if ((period == 'tarde' || period == 'noite') && hour < 12) hour += 12;
    if (hour > 23 || minute > 59) return null;

    return (hour, minute);
  }
}
