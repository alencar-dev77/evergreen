import 'package:flutter/widgets.dart';

import '../../../../shared/utils/day_bounds.dart';
import '../../../../shared/utils/day_label.dart';
import '../../../../shared/widgets/eg_day_bars.dart';
import '../../models/track_day.dart';

/// O tempo registrado em cada dia da semana, em sete barras.
///
/// A barra mede **foco mais reunião** (`TrackDay.registered`), não só o foco:
/// é a diferença entre esta faixa e a do Focus, e é o que a torna a faixa do
/// Track — uma manhã inteira de reunião é uma manhã de trabalho, e uma semana
/// que só mostrasse foco a contaria como vazia.
class TrackWeekStrip extends StatelessWidget {
  const TrackWeekStrip({super.key, required this.days, this.now});

  final List<TrackDay> days;

  /// Injetável para o teste e para os goldens não dependerem do relógio real.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final today = now ?? DateTime.now();
    final monday = DayBounds.startOfWeek(today);
    final totals = List.filled(DayLabel.weekdays.length, Duration.zero);

    for (final day in days) {
      final index = DayBounds.daysBetween(monday, day.date);
      if (index < 0 || index >= totals.length) continue;

      totals[index] = day.registered;
    }

    return EgDayBars(
      values: totals,
      labels: DayLabel.weekdays,
      highlight: today.weekday - 1,
    );
  }
}
