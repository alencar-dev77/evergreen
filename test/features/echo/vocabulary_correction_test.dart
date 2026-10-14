import 'package:evergreen/features/echo/models/echo_settings.dart';
import 'package:evergreen/features/echo/models/meeting_segment.dart';
import 'package:evergreen/features/echo/models/vocabulary_correction.dart';
import 'package:flutter_test/flutter_test.dart';

/// A troca do vocabulário: o que o modelo de fala insiste em errar, consertado
/// depois — com o relógio de cada palavra junto.
void main() {
  MeetingWord word(int start, int end, String text) =>
      MeetingWord(startMs: start, endMs: end, text: text);

  MeetingSegment segment(List<MeetingWord> words) => MeetingSegment(
    speaker: Speaker.others,
    startMs: words.first.startMs,
    endMs: words.last.endMs,
    text: words.map((word) => word.text).join(),
    words: words,
  );

  const asap = VocabularyCorrection(heard: 'a zap', written: 'ASAP');

  group('o campo', () {
    test('lê a troca com seta, com => e com =', () {
      for (final entry in ['a zap -> ASAP', 'a zap=>ASAP', 'a zap = ASAP']) {
        final correction = VocabularyCorrection.parse(entry)!;
        expect(correction.heard, 'a zap');
        expect(correction.written, 'ASAP');
      }
      expect(VocabularyCorrection.parse('Riverpod'), isNull);
      expect(VocabularyCorrection.parse('-> ASAP'), isNull);
    });

    test('palavras e trocas convivem; o lado certo vira vocabulário', () {
      const settings = EchoSettings(
        vocabulary: 'Evergreen, a zap -> ASAP\nzap -> ASAP; Riverpod',
      );

      expect(settings.vocabularyTerms, ['Evergreen', 'ASAP', 'Riverpod']);
      expect(settings.vocabularyCorrections.map((c) => c.heard), [
        'a zap',
        'zap',
      ]);
    });
  });

  test('duas palavras viram uma, do começo da primeira ao fim da segunda', () {
    final fixed = VocabularyCorrection.apply(
      [
        segment([
          word(0, 300, 'Preciso'),
          word(300, 500, ' disso'),
          word(600, 700, ' a'),
          word(700, 1100, ' zap.'),
        ]),
      ],
      [asap],
    ).single;

    expect(fixed.text, 'Preciso disso ASAP.');
    expect(fixed.words.map((w) => w.text), ['Preciso', ' disso', ' ASAP.']);
    expect(fixed.words.last.startMs, 600);
    expect(fixed.words.last.endMs, 1100);
  });

  test('sem diferença de maiúscula, e só palavra inteira', () {
    final fixed = VocabularyCorrection.apply(
      [
        segment([
          word(0, 200, 'A'),
          word(200, 600, ' zap'),
          word(700, 900, ' zapping'),
        ]),
      ],
      // A curta antes, de propósito: a longa precisa casar primeiro.
      [const VocabularyCorrection(heard: 'zap', written: 'ASAP'), asap],
    ).single;

    expect(fixed.text, 'ASAP zapping');
  });

  test('trecho sem relógio por palavra troca só o texto', () {
    final fixed = VocabularyCorrection.apply(
      [
        const MeetingSegment(
          speaker: Speaker.me,
          startMs: 0,
          endMs: 1000,
          text: 'Manda a zap',
        ),
      ],
      [asap],
    ).single;

    expect(fixed.text, 'Manda ASAP');
    expect(fixed.words, isEmpty);
  });

  test('sem troca que case, o trecho volta o mesmo', () {
    final original = segment([word(0, 100, 'Oi')]);

    expect(
      VocabularyCorrection.apply([original], [asap]).single,
      same(original),
    );
  });
}
