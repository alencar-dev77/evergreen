import 'package:flutter/foundation.dart';

import '../../../core/system/notification_service.dart';
import '../../../shared/utils/day_bounds.dart';
import '../../../shared/utils/day_label.dart';
import '../../../shared/utils/duration_format.dart';
import 'track_day.dart';

/// A semana que acabou, contada numa notificação na segunda-feira.
///
/// Mede o mesmo que a tela do Track — foco mais reunião
/// (`TrackDay.registered`) — e conta o resto (cópias, anotações, arquivos) só
/// quando a semana não teve tempo registrado nenhum, para a frase não virar
/// inventário.
@immutable
class TrackWeekDigest {
  const TrackWeekDigest._({
    required this.weekStart,
    required this.daily,
    required this.totals,
    required this.extras,
  });

  /// `null` quando a semana não teve nada — notificar "você não fez nada" não
  /// é um resumo, é cobrança.
  static TrackWeekDigest? of(
    List<TrackDay> days, {
    required DateTime weekStart,
  }) {
    final monday = DayBounds.startOfDay(weekStart);
    final week = [
      for (final day in days)
        if (_indexOf(monday, day.date) case final index? when index >= 0)
          (index, day),
    ];
    if (week.every((entry) => entry.$2.isEmpty)) return null;

    final daily = List.filled(7, Duration.zero);
    var copied = 0;
    var notes = 0;
    var files = 0;
    for (final (index, day) in week) {
      daily[index] += day.registered;
      copied += day.copiedTotal;
      notes += day.notesWritten;
      files += day.filesOrganized;
    }

    return TrackWeekDigest._(
      weekStart: monday,
      daily: List.unmodifiable(daily),
      totals: TrackTotals.of([for (final entry in week) entry.$2]),
      extras: [
        if (copied > 0)
          TrackCounts.of(copied, 'item copiado', 'itens copiados'),
        if (notes > 0) TrackCounts.of(notes, 'anotação', 'anotações'),
        if (files > 0)
          TrackCounts.of(files, 'arquivo organizado', 'arquivos organizados'),
      ],
    );
  }

  static int? _indexOf(DateTime monday, DateTime date) {
    final index = DayBounds.daysBetween(monday, date);
    return index < 7 ? index : null;
  }

  static const id = 'track.week';
  static const openTrack = 'track.open';

  /// Nomes por extenso, de segunda a domingo — "seu melhor dia foi quarta".
  static const _weekdays = <String>[
    'segunda',
    'terça',
    'quarta',
    'quinta',
    'sexta',
    'sábado',
    'domingo',
  ];

  final DateTime weekStart;

  /// Tempo registrado em cada dia, de segunda a domingo.
  final List<Duration> daily;

  final TrackTotals totals;

  /// "120 itens copiados", "4 anotações" — o que a semana teve além de tempo.
  final List<String> extras;

  DateTime get weekEnd =>
      DateTime(weekStart.year, weekStart.month, weekStart.day + 6);

  /// "29 set – 5 out".
  String get rangeLabel =>
      '${DayLabel.dayMonth(weekStart)} – ${DayLabel.dayMonth(weekEnd)}';

  /// O dia com mais tempo registrado, ou `null` numa semana sem tempo.
  int? get bestDay {
    int? best;
    for (var i = 0; i < daily.length; i++) {
      if (daily[i] == Duration.zero) continue;
      if (best == null || daily[i] > daily[best]) best = i;
    }
    return best;
  }

  String title(String userName) {
    final name = userName.trim();
    return name.isEmpty ? 'Sua semana passada' : '$name, sua semana passada';
  }

  String get body {
    final registered = totals.registered;
    if (registered == Duration.zero) {
      return 'Nenhum foco ou reunião registrado, mas ${_join(extras)}.';
    }

    final parts = [
      if (totals.focusSessions > 0)
        '${DurationFormat.compact(totals.focus)} de foco em '
            '${TrackCounts.of(totals.focusSessions, 'sessão', 'sessões')}',
      if (totals.meetingCount > 0)
        '${DurationFormat.compact(totals.meetings)} em '
            '${TrackCounts.of(totals.meetingCount, 'reunião', 'reuniões')}',
    ];

    final best = bestDay!;
    return '${DurationFormat.compact(registered)} registradas — '
        '${_join(parts)}. Seu melhor dia foi ${_weekdays[best]}, '
        'com ${DurationFormat.compact(daily[best])}.';
  }

  EgNotification notification({required String userName, String? imagePath}) =>
      EgNotification(
        id: id,
        thread: 'track',
        title: title(userName),
        subtitle: rangeLabel,
        body: body,
        sound: true,
        imagePath: imagePath,
        actions: const [EgNotificationAction(openTrack, 'Abrir o Track')],
      );

  static String _join(List<String> parts) => switch (parts.length) {
    0 => '',
    1 => parts.single,
    _ => '${parts.sublist(0, parts.length - 1).join(', ')} e ${parts.last}',
  };
}
