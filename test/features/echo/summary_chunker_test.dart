import 'package:evergreen/features/echo/models/summary_chunker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SummaryChunker.maxCharsFor', () {
    test('sem saber a janela, fica no teto de sempre', () {
      expect(SummaryChunker.maxCharsFor(null), SummaryChunker.defaultMaxChars);
    });

    test('a janela do macOS 26 dá o teto medido para ela', () {
      expect(SummaryChunker.maxCharsFor(4096), SummaryChunker.defaultMaxChars);
    });

    test('janela menor que a de referência não encolhe o teto', () {
      // Encolher seria adivinhar: o teto conservador já foi medido, e o
      // estouro continua tendo a saída de repartir o bloco.
      expect(SummaryChunker.maxCharsFor(2048), SummaryChunker.defaultMaxChars);
    });

    test('a janela do macOS 27 vira texto, não reserva', () {
      // 4.096 tokens a mais, três caracteres cada.
      expect(SummaryChunker.maxCharsFor(8192), 5000 + 4096 * 3);
    });
  });

  group('SummaryChunker', () {
    test('texto que cabe vira um bloco só', () {
      final chunks = SummaryChunker.chunk('Você: bom dia', maxChars: 100);

      expect(chunks, ['Você: bom dia']);
    });

    test('texto vazio não vira bloco nenhum', () {
      expect(SummaryChunker.chunk('   \n  '), isEmpty);
    });

    test('corta em blocos dentro do teto', () {
      final falas = List.generate(40, (i) => 'Reunião: fala número $i');
      final chunks = SummaryChunker.chunk(falas.join('\n'), maxChars: 120);

      expect(chunks.length, greaterThan(1));
      for (final chunk in chunks) {
        expect(chunk.length, lessThanOrEqualTo(120));
      }
    });

    test('não parte uma fala no meio', () {
      final falas = [
        'Você: primeira fala inteira aqui',
        'Reunião: segunda fala inteira aqui',
        'Você: terceira fala inteira aqui',
      ];

      final chunks = SummaryChunker.chunk(falas.join('\n'), maxChars: 40);

      // Cada linha aparece inteira em algum bloco — nenhuma foi dividida.
      for (final fala in falas) {
        expect(
          chunks.any((chunk) => chunk.contains(fala)),
          isTrue,
          reason: fala,
        );
      }
    });

    test('preserva todas as falas, na ordem', () {
      final falas = List.generate(30, (i) => 'Reunião: fala $i');
      final chunks = SummaryChunker.chunk(falas.join('\n'), maxChars: 100);

      expect(chunks.join('\n').split('\n'), falas);
    });

    test('fala mais longa que o teto é cortada na força', () {
      final monologo = 'Reunião: ${'a' * 500}';
      final chunks = SummaryChunker.chunk(monologo, maxChars: 100);

      expect(chunks.length, greaterThan(1));
      for (final chunk in chunks) {
        expect(chunk.length, lessThanOrEqualTo(100));
      }
      expect(chunks.join().replaceAll('\n', ''), monologo.replaceAll('\n', ''));
    });
  });
}
