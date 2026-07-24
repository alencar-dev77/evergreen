/// Formata instantes como texto curto em português ("agora", "há 5 min").
///
/// Nos metadados do Pin o que importa é a ordem de grandeza, não a precisão —
/// por isso arredondamos para a maior unidade que ainda faça sentido.
abstract final class RelativeTime {
  static String format(DateTime moment, {DateTime? now}) {
    final elapsed = (now ?? DateTime.now()).difference(moment);

    if (elapsed.inSeconds < 45) return 'agora';
    if (elapsed.inMinutes < 60) return 'há ${elapsed.inMinutes} min';
    if (elapsed.inHours < 24) return 'há ${elapsed.inHours} h';
    if (elapsed.inDays == 1) return 'ontem';
    if (elapsed.inDays < 7) return 'há ${elapsed.inDays} dias';

    final weeks = elapsed.inDays ~/ 7;
    if (weeks < 5) return 'há $weeks ${weeks == 1 ? 'semana' : 'semanas'}';

    final months = elapsed.inDays ~/ 30;
    return 'há $months ${months == 1 ? 'mês' : 'meses'}';
  }
}
