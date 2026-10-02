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

  /// A janela para a qual o [defaultMaxChars] foi medido — a do macOS 26.
  static const referenceContextTokens = 4096;

  /// Caracteres por token, pelo lado de baixo da faixa do português.
  static const _charsPerToken = 3;

  /// O teto de caracteres para uma janela de [contextTokens].
  ///
  /// A reserva para a instrução e para a resposta já está paga dentro do
  /// [defaultMaxChars], e ela não cresce com a janela: um resumo de bloco não
  /// fica mais comprido porque o modelo enxerga mais. Então todo token além da
  /// janela de referência é espaço para texto — no macOS 27, que dobrou a
  /// janela, o bloco passa de 5 mil para uns 17 mil caracteres, e uma reunião
  /// de meia hora que dava quatro blocos (e um resumo de resumos) cabe em um.
  ///
  /// Janela desconhecida ou menor que a de referência fica no teto de sempre:
  /// o bloco que estoura ainda é repartido por quem chama, mas cada estouro é
  /// uma chamada jogada fora.
  static int maxCharsFor(int? contextTokens) {
    if (contextTokens == null || contextTokens <= referenceContextTokens) {
      return defaultMaxChars;
    }

    return defaultMaxChars +
        (contextTokens - referenceContextTokens) * _charsPerToken;
  }

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
