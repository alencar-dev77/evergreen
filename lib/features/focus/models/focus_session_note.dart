import 'package:flutter/foundation.dart';

/// Uma observação escrita no meio de uma sessão de foco.
///
/// "Terminei a task e comecei outra" — o valor dela está em *quando* foi
/// escrita, por isso carrega o minuto da sessão, não o horário do relógio.
@immutable
class FocusSessionNote {
  const FocusSessionNote({required this.minute, required this.text});

  /// Minutos decorridos de sessão no momento da escrita.
  final int minute;

  final String text;

  /// Como o momento é lido na interface.
  String get label => minute <= 0 ? 'no início' : 'aos $minute min';

  /// Uma observação é de uma linha só — sempre, venha de onde vier.
  ///
  /// O `\n` é o separador de registros da serialização, então um dentro do
  /// texto não deixa a nota feia: parte a linha em duas, e a segunda metade
  /// não tem `minuto|` na frente, some no `decodeList` e leva o resto da
  /// observação junto. Colar um parágrafo no campo era o caminho: o campo é de
  /// uma linha, mas colar não respeita isso.
  ///
  /// Achatar aqui, e não só no campo, é o que fecha a porta: [encodeList]
  /// aplica de novo antes de gravar, então nenhum caminho — nem um teste, nem
  /// uma leitura de rastro antigo — consegue escrever uma linha quebrada.
  static String sanitize(String text) =>
      text.replaceAll(RegExp(r'\s*[\r\n]+\s*'), ' ').trim();

  /// Serialização para a coluna `notes` do SQLite: uma linha por observação,
  /// `minuto|texto`.
  static String? encodeList(List<FocusSessionNote> notes) {
    if (notes.isEmpty) return null;

    return notes
        .map((note) => '${note.minute}|${sanitize(note.text)}')
        .join('\n');
  }

  static List<FocusSessionNote> decodeList(String? encoded) {
    if (encoded == null || encoded.isEmpty) return const [];

    final notes = <FocusSessionNote>[];

    for (final line in encoded.split('\n')) {
      final divider = line.indexOf('|');
      if (divider <= 0) continue;

      final minute = int.tryParse(line.substring(0, divider));
      if (minute == null) continue;

      notes.add(
        FocusSessionNote(minute: minute, text: line.substring(divider + 1)),
      );
    }

    return List.unmodifiable(notes);
  }
}
