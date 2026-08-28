import 'package:evergreen/features/echo/data/echo_channel.dart';
import 'package:evergreen/features/pin/models/clipboard_item_type.dart';
import 'package:evergreen/features/track/data/track_summarizer.dart';
import 'package:evergreen/features/track/models/track_day.dart';
import 'package:flutter_test/flutter_test.dart';

import '../echo/fake_echo_channel.dart';

/// O parágrafo do dia — e as duas regras que valem mais que ele.
///
/// A primeira: **o resumo é enfeite, o dado é o produto.** Sem macOS 26, sem
/// Apple Intelligence, ou com qualquer falha no meio, o Track continua inteiro
/// e só não escreve o parágrafo.
///
/// A segunda: o que vai para o modelo é o agregado. Contagem de itens
/// copiados, sim; o que foi copiado, nunca.
void main() {
  final date = DateTime(2026, 8, 19);

  TrackDay dayWith({
    List<TrackEntry> focus = const [],
    List<TrackEntry> meetings = const [],
    Map<ClipboardItemType, int> copied = const {},
    int notes = 0,
  }) {
    return TrackDay(
      date: date,
      focus: focus,
      meetings: meetings,
      copied: copied,
      notesWritten: notes,
    );
  }

  group('os fatos que vão para o modelo', () {
    test('trazem os totais e os nomes que a pessoa deu', () {
      final facts = TrackSummarizer.factsOf(
        dayWith(
          focus: [
            TrackEntry(
              at: date.add(const Duration(hours: 9)),
              duration: const Duration(minutes: 25),
              label: 'Refatorar o auth',
            ),
            TrackEntry(
              at: date.add(const Duration(hours: 14)),
              duration: const Duration(minutes: 40),
            ),
          ],
          meetings: [
            TrackEntry(
              at: date.add(const Duration(hours: 10)),
              duration: const Duration(minutes: 45),
              label: 'Weekly do time',
            ),
          ],
          notes: 2,
        ),
      );

      expect(facts, contains('1h 05min em 2 sessões'));
      expect(facts, contains('Refatorar o auth'));
      expect(facts, contains('Weekly do time'));
      expect(facts, contains('2 anotações'));
    });

    test('da área de transferência levam número e tipo, nunca conteúdo', () {
      final facts = TrackSummarizer.factsOf(
        dayWith(
          copied: const {
            ClipboardItemType.link: 9,
            ClipboardItemType.command: 6,
          },
        ),
      );

      expect(facts, contains('Itens copiados: 15'));
      expect(facts, contains('9 links'));
      expect(facts, contains('6 comandos'));
    });

    test('não existem num dia sem nada', () {
      expect(TrackSummarizer.factsOf(dayWith()), isNull);
    });
  });

  group('escrever o parágrafo', () {
    test('devolve o que o modelo escreveu', () async {
      final channel = FakeEchoChannel()..summaryValue = 'Foi um dia de foco.';

      final text = await TrackSummarizer(channel, '').write(
        dayWith(
          focus: [
            TrackEntry(at: date, duration: const Duration(minutes: 25)),
          ],
        ),
      );

      expect(text, 'Foi um dia de foco.');
      expect(channel.summarizedTexts, hasLength(1));
    });

    test('degrada em silêncio quando o modelo não está disponível', () async {
      final channel = FakeEchoChannel()
        ..failWith = const EchoException(
          'unsupported_os',
          'O Echo precisa do macOS 26 ou superior.',
        );

      final text = await TrackSummarizer(channel, '').write(
        dayWith(
          focus: [
            TrackEntry(at: date, duration: const Duration(minutes: 25)),
          ],
        ),
      );

      expect(text, isNull);
    });

    test('um retorno vazio é o mesmo que não ter parágrafo', () async {
      final channel = FakeEchoChannel()..summaryValue = '   ';

      final text = await TrackSummarizer(channel, '').write(
        dayWith(
          focus: [
            TrackEntry(at: date, duration: const Duration(minutes: 25)),
          ],
        ),
      );

      expect(text, isNull);
    });

    test('não incomoda o modelo com um dia vazio', () async {
      final channel = FakeEchoChannel();

      expect(await TrackSummarizer(channel, '').write(dayWith()), isNull);
      expect(channel.summarizedTexts, isEmpty);
    });
  });

  /// Sem nome, o parágrafo é sobre "a pessoa" — um relatório escrito por quem
  /// não sabe de quem está falando.
  group('o nome na instrução', () {
    test('vazio, a instrução fala de "a pessoa"', () {
      expect(
        TrackSummarizer.instructionsFor(''),
        contains('contando o que a pessoa fez'),
      );
    });

    test('preenchido, a instrução chama pelo nome', () {
      final instructions = TrackSummarizer.instructionsFor('Lucas');

      expect(instructions, contains('contando o que Lucas fez'));
      expect(instructions, isNot(contains('a pessoa')));
    });
  });
}