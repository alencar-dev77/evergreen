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

    /// Um parágrafo que sabe que houve "3 h em duas sessões" e não sabe em quê
    /// elas foram é um relatório de ponto. O resumo que a pessoa escreveu ao
    /// fechar a sessão, e o que o modelo escreveu sobre a reunião, já estão no
    /// banco — e são texto que ela escolheu produzir sobre o próprio trabalho,
    /// ao contrário do conteúdo do Pin, que continua fora daqui.
    group('levam os resumos que já existem', () {
      test('o da sessão de foco, com o nome da atividade na frente', () {
        final facts = TrackSummarizer.factsOf(
          dayWith(
            focus: [
              TrackEntry(
                at: date.add(const Duration(hours: 9)),
                duration: const Duration(minutes: 50),
                label: 'Refatorar o auth',
                summary: 'Separei o token do refresh e cobri com teste.',
              ),
            ],
          ),
        );

        expect(facts, contains('Sobre as sessões'));
        expect(facts, contains('Refatorar o auth — Separei o token'));
      });

      test('o da reunião', () {
        final facts = TrackSummarizer.factsOf(
          dayWith(
            meetings: [
              TrackEntry(
                at: date.add(const Duration(hours: 10)),
                duration: const Duration(minutes: 45),
                label: 'Weekly',
                summary: 'Decidido adiar o lançamento para a semana que vem.',
              ),
            ],
          ),
        );

        expect(facts, contains('Sobre as reuniões'));
        expect(facts, contains('Decidido adiar o lançamento'));
      });

      test('a sessão sem resumo não abre a linha', () {
        final facts = TrackSummarizer.factsOf(
          dayWith(
            focus: [
              TrackEntry(
                at: date.add(const Duration(hours: 9)),
                duration: const Duration(minutes: 25),
                label: 'Refatorar o auth',
              ),
            ],
          ),
        );

        expect(facts, isNot(contains('Sobre as sessões')));
      });

      /// O resumo de uma reunião é um documento; o parágrafo do dia tem três
      /// frases. Mandar os documentos inteiros estouraria a janela de contexto
      /// — e ali não há conserto: o dia perde o parágrafo por inteiro.
      test('um resumo comprido é cortado, e vira uma linha só', () {
        final facts = TrackSummarizer.factsOf(
          dayWith(
            meetings: [
              TrackEntry(
                at: date.add(const Duration(hours: 10)),
                duration: const Duration(minutes: 45),
                summary: 'Tópico.\n${'palavra ' * 400}',
              ),
            ],
          ),
        )!;

        final linha = facts
            .split('\n')
            .firstWhere((line) => line.startsWith('Sobre as reuniões'));

        expect(linha.length, lessThan(500));
        expect(linha, contains('…'));
        expect(linha, contains('Tópico. palavra'));
      });

      test('entram no máximo três de cada tipo', () {
        final facts = TrackSummarizer.factsOf(
          dayWith(
            meetings: [
              for (var i = 1; i <= 5; i++)
                TrackEntry(
                  at: date.add(Duration(hours: 8 + i)),
                  duration: const Duration(minutes: 30),
                  summary: 'reuniao$i',
                ),
            ],
          ),
        )!;

        expect(facts, contains('reuniao3'));
        expect(facts, isNot(contains('reuniao4')));
      });
    });
  });

  /// O parágrafo é cache, com assinatura do dia: se ela não vir os resumos,
  /// resumir uma reunião de terça na quinta deixa na tela o parágrafo de terça
  /// escrito sem ele — e um texto que não bate com os números ao lado é pior
  /// que texto nenhum.
  group('a assinatura do dia', () {
    TrackDay dayWithMeeting({String? summary}) => TrackDay(
      date: date,
      meetings: [
        TrackEntry(
          at: date.add(const Duration(hours: 10)),
          duration: const Duration(minutes: 45),
          summary: summary,
        ),
      ],
    );

    test('muda quando um resumo aparece', () {
      expect(
        dayWithMeeting().signature,
        isNot(dayWithMeeting(summary: 'o que foi decidido').signature),
      );
    });

    test('muda quando um resumo é reescrito', () {
      expect(
        dayWithMeeting(summary: 'primeira versão').signature,
        isNot(dayWithMeeting(summary: 'segunda versao').signature),
      );
    });

    test('não muda com o mesmo dia lido duas vezes', () {
      expect(
        dayWithMeeting(summary: 'igual').signature,
        dayWithMeeting(summary: 'igual').signature,
      );
    });
  });

  group('escrever o parágrafo', () {
    test('devolve o que o modelo escreveu', () async {
      final channel = FakeEchoChannel()..summaryValue = 'Foi um dia de foco.';

      final text = await TrackSummarizer(channel, '').write(
        dayWith(
          focus: [TrackEntry(at: date, duration: const Duration(minutes: 25))],
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
          focus: [TrackEntry(at: date, duration: const Duration(minutes: 25))],
        ),
      );

      expect(text, isNull);
    });

    test('um retorno vazio é o mesmo que não ter parágrafo', () async {
      final channel = FakeEchoChannel()..summaryValue = '   ';

      final text = await TrackSummarizer(channel, '').write(
        dayWith(
          focus: [TrackEntry(at: date, duration: const Duration(minutes: 25))],
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
