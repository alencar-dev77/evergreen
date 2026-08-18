import 'package:flutter/foundation.dart';

import 'day_label.dart';

/// Um dia e o que aconteceu nele.
@immutable
class DayGroup<T> {
  const DayGroup({required this.label, required this.items});

  /// "Hoje", "Ontem", "23 jul" — pronto para o `EgSectionLabel`.
  final String label;

  final List<T> items;
}

/// Quebra uma lista cronológica em grupos de um dia.
///
/// Existe porque a alternativa é repetir a data em toda linha, e foi assim que
/// o histórico do Focus acabou com "Hoje ·" escrito cinco vezes na mesma tela.
/// A data é do grupo, não da linha: a linha fica com a hora, que é o que
/// distingue uma sessão da outra dentro do mesmo dia.
///
/// A ordem de entrada é preservada — as duas listas que usam isto (sessões do
/// Focus, reuniões do Echo) já chegam da mais recente para a mais antiga, e a
/// ordem do dia dentro do grupo é a mesma que o repositório entregou.
abstract final class DayGroups {
  static List<DayGroup<T>> of<T>(
    Iterable<T> items,
    DateTime Function(T item) dateOf, {
    DateTime? now,
  }) {
    // Agrupa pela chave do dia em vez de comparar com o vizinho: com uma lista
    // fora de ordem, o vizinho criaria dois grupos com o mesmo rótulo, e uma
    // tela com "Hoje" escrito duas vezes é pior que uma lista desordenada.
    final byDay = <DateTime, List<T>>{};

    for (final item in items) {
      final date = dateOf(item);
      final day = DateTime(date.year, date.month, date.day);
      (byDay[day] ??= <T>[]).add(item);
    }

    return [
      for (final entry in byDay.entries)
        DayGroup(
          label: DayLabel.of(entry.key, now: now),
          items: entry.value,
        ),
    ];
  }
}
