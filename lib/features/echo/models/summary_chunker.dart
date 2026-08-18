/// Corta a transcrição em blocos que cabem na janela do modelo local.
///
/// O modelo do Apple Intelligence tem uma janela de contexto de alguns milhares
/// de tokens — meia hora de reunião não cabe de uma vez. O modelo não degrada
/// com elegância quando estoura: ele devolve erro, não um resumo parcial. Por
/// isso quem decide o tamanho é este código, e não o acaso.
///
/// Fica em Dart de propósito. É a única parte do resumo que é lógica pura, e
/// lógica pura se testa sem microfone, sem reunião e sem modelo.
abstract final class SummaryChunker {
  /// Teto de caracteres por bloco.
  ///
  /// Conservador: em português um token dá algo entre três e quatro caracteres,
  /// e a janela precisa caber a instrução, o texto **e** a resposta. Chutar
  /// para baixo custa uma chamada a mais; chutar para cima custa o erro que a
  /// pessoa vê na tela.
  static const defaultMaxChars = 5000;

  /// Divide [text] em blocos de no máximo [maxChars].
  ///
  /// O corte respeita as linhas, que aqui são as falas: partir uma fala no meio
  /// entregaria ao modelo meia frase sem quem a disse. Linha que sozinha passa
  /// do teto é cortada na força — mas isso só acontece com um monólogo de
  /// milhares de caracteres sem pausa nenhuma.
  static List<String> chunk(String text, {int maxChars = defaultMaxChars}) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return const [];
    if (trimmed.length <= maxChars) return [trimmed];

    final chunks = <String>[];
    final buffer = StringBuffer();

    void flush() {
      final pending = buffer.toString().trim();
      if (pending.isNotEmpty) chunks.add(pending);
      buffer.clear();
    }

    for (final line in trimmed.split('\n')) {
      for (final piece in _split(line, maxChars)) {
        // +1 pela quebra de linha que vai reunir as falas dentro do bloco.
        if (buffer.isNotEmpty && buffer.length + piece.length + 1 > maxChars) {
          flush();
        }

        if (buffer.isNotEmpty) buffer.write('\n');
        buffer.write(piece);
      }
    }

    flush();
    return chunks;
  }

  /// Quebra uma linha longa demais em pedaços que cabem.
  static Iterable<String> _split(String line, int maxChars) sync* {
    if (line.length <= maxChars) {
      yield line;
      return;
    }

    for (var start = 0; start < line.length; start += maxChars) {
      final end = start + maxChars;
      yield line.substring(start, end > line.length ? line.length : end);
    }
  }
}
