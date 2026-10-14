import 'package:evergreen/features/echo/models/meeting.dart';
import 'package:evergreen/features/echo/models/meeting_search.dart';
import 'package:evergreen/features/echo/models/meeting_segment.dart';
import 'package:evergreen/features/echo/models/transcription_language.dart';
import 'package:evergreen/shared/utils/text_fold.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  var nextId = 1;

  Meeting meeting(
    String title, {
    List<MeetingSegment> segments = const [],
    String? summary,
    DateTime? at,
  }) => Meeting(
    id: nextId++,
    title: title,
    startedAt: at ?? DateTime(2026, 10, 1, 10),
    durationMs: 60000,
    language: TranscriptionLanguage.ptBR,
    segments: segments,
    summary: summary,
  );

  MeetingSegment said(
    String text, {
    int at = 0,
    Speaker speaker = Speaker.others,
    int? voice,
    List<MeetingWord> words = const [],
  }) => MeetingSegment(
    speaker: speaker,
    startMs: at,
    endMs: at + 2000,
    text: text,
    voice: voice,
    words: words,
  );

  /// O texto com os grifos entre colchetes — mais fácil de ler no teste do
  /// que uma lista de posições.
  String marked(String text, List<MatchRange> marks) {
    final buffer = StringBuffer();
    var cursor = 0;
    for (final mark in marks) {
      buffer
        ..write(text.substring(cursor, mark.start))
        ..write('[${text.substring(mark.start, mark.end)}]');
      cursor = mark.end;
    }
    return (buffer..write(text.substring(cursor))).toString();
  }

  group('TextFold', () {
    test('tira acento e maiúscula sem mudar o comprimento', () {
      const text = 'Orçamento AÇÃO é Último';
      final folded = TextFold.fold(text);

      expect(folded, 'orcamento acao e ultimo');
      expect(folded.length, text.length);
    });
  });

  group('MeetingQuery', () {
    test('quebra em palavras dobradas e sem repetição', () {
      expect(MeetingQuery.parse('  Orçamento, SEXTA orçamento ').terms, [
        'orcamento',
        'sexta',
      ]);
    });

    test('letra solta não é busca', () {
      expect(MeetingQuery.parse('a proposta').terms, ['proposta']);
      // Sozinha, casaria com toda reunião: a busca começa na segunda letra.
      expect(MeetingQuery.parse('p').isEmpty, isTrue);
      expect(MeetingQuery.parse('pr').terms, ['pr']);
    });

    test('só espaço e pontuação é busca vazia', () {
      expect(MeetingQuery.parse(' ?! ').isEmpty, isTrue);
    });
  });

  group('MeetingSearch', () {
    test('acha sem acento e pelo começo da palavra', () {
      final search = MeetingSearch.index([
        meeting(
          'Planejamento',
          segments: [said('O orçamento fecha na sexta.')],
        ),
      ]);

      final hit = search.search('orcam').single.hits.single;
      expect(marked(hit.snippet, hit.marks), 'O [orçam]ento fecha na sexta.');
    });

    test('não acha no meio de uma palavra', () {
      final search = MeetingSearch.index([
        meeting('Revisão', segments: [said('Isso é um acusto qualquer.')]),
      ]);

      expect(search.search('custo'), isEmpty);
    });

    test('todas as palavras precisam estar na reunião', () {
      final search = MeetingSearch.index([
        meeting('Só orçamento', segments: [said('O orçamento subiu.')]),
        meeting(
          'Orçamento e prazo',
          segments: [said('O orçamento subiu.'), said('A sexta é o prazo.')],
        ),
      ]);

      expect(search.search('orçamento sexta').map((r) => r.meeting.title), [
        'Orçamento e prazo',
      ]);
    });

    test('as palavras podem estar em trechos diferentes da reunião', () {
      final search = MeetingSearch.index([
        meeting(
          'Alinhamento',
          segments: [
            said('Vamos falar do orçamento.', at: 0),
            said('Combinado, até sexta.', at: 60000, speaker: Speaker.me),
          ],
        ),
      ]);

      final result = search.search('orçamento sexta').single;
      expect(result.hits, hasLength(2));
      expect(result.hits.map((hit) => hit.coverage), [1, 1]);
    });

    test('o título com todas as palavras vem antes', () {
      final search = MeetingSearch.index([
        meeting(
          'Daily',
          segments: [said('Alguém falou de orçamento aqui.')],
          at: DateTime(2026, 10, 5),
        ),
        meeting(
          'Orçamento 2027',
          segments: [said('Começamos.')],
          at: DateTime(2026, 9, 1),
        ),
      ]);

      expect(search.search('orçamento').map((r) => r.meeting.title), [
        'Orçamento 2027',
        'Daily',
      ]);
      expect(search.search('orçamento').first.titleMarks, [
        const MatchRange(0, 9),
      ]);
    });

    test('as palavras juntas na mesma fala valem mais', () {
      final search = MeetingSearch.index([
        meeting(
          'Espalhada',
          segments: [said('O orçamento.', at: 0), said('A sexta.', at: 90000)],
          at: DateTime(2026, 10, 9),
        ),
        meeting(
          'Junta',
          segments: [said('O orçamento fecha na sexta.')],
          at: DateTime(2026, 9, 1),
        ),
      ]);

      expect(search.search('orçamento sexta').first.meeting.title, 'Junta');
    });

    test('no empate, a mais recente primeiro', () {
      final search = MeetingSearch.index([
        meeting(
          'Antiga',
          segments: [said('roadmap')],
          at: DateTime(2026, 9, 1),
        ),
        meeting('Nova', segments: [said('roadmap')], at: DateTime(2026, 10, 1)),
      ]);

      expect(search.search('roadmap').map((r) => r.meeting.title), [
        'Nova',
        'Antiga',
      ]);
    });

    test('mostra três trechos, na ordem da reunião, e conta o resto', () {
      final search = MeetingSearch.index([
        meeting(
          'Longa',
          segments: [
            for (var i = 0; i < 6; i++)
              said('Trecho $i fala do roadmap.', at: i * 40000),
          ],
        ),
      ]);

      final result = search.search('roadmap').single;
      expect(result.hitCount, 6);
      expect(result.hits, hasLength(MeetingSearch.shownHits));
      final starts = result.hits.map((hit) => hit.turnStartMs!).toList();
      expect(starts, [...starts]..sort());
    });

    test('o resumo entra, linha por linha, antes da conversa', () {
      final search = MeetingSearch.index([
        meeting(
          'Com resumo',
          summary: '- O time aprovou o roadmap.\n- Lucas revisa o contrato.',
          segments: [said('Precisamos revisar o contrato.', at: 5000)],
        ),
      ]);

      final hits = search.search('contrato').single.hits;
      expect(hits.map((hit) => hit.kind), [
        MeetingHitKind.summary,
        MeetingHitKind.transcript,
      ]);
      // Sem o traço da lista: no resultado ela é um trecho, não um tópico.
      expect(hits.first.snippet, 'Lucas revisa o contrato.');
      expect(hits.first.atMs, isNull);
    });

    test('o trecho leva o relógio da palavra que casou e quem falou', () {
      final search = MeetingSearch.index([
        meeting(
          'Com voz',
          segments: [
            said(
              'pode ser na sexta',
              at: 10000,
              voice: 2,
              words: const [
                MeetingWord(startMs: 10000, endMs: 10400, text: 'pode'),
                MeetingWord(startMs: 10400, endMs: 10700, text: ' ser'),
                MeetingWord(startMs: 10700, endMs: 10900, text: ' na'),
                MeetingWord(startMs: 11000, endMs: 11600, text: ' sexta'),
              ],
            ),
          ],
        ),
      ]);

      final hit = search.search('sexta').single.hits.single;
      expect(hit.atMs, 11000);
      expect(hit.turnStartMs, 10000);
      expect(hit.timestamp, '00:10');
      expect(hit.speaker, 'Pessoa 2');
    });

    test('o nome de quem usa vale no rótulo do trecho', () {
      final search = MeetingSearch.index([
        meeting('Minha', segments: [said('eu mando', speaker: Speaker.me)]),
      ], userName: 'Lucas');

      expect(search.search('mando').single.hits.single.speaker, 'Lucas');
    });

    test('fala longa é recortada em volta do que casou', () {
      final long =
          '${List.filled(40, 'palavra').join(' ')} o orçamento '
          '${List.filled(60, 'depois').join(' ')}';
      final search = MeetingSearch.index([
        meeting('Longa', segments: [said(long)]),
      ]);

      final hit = search.search('orçamento').single.hits.single;
      expect(hit.snippet, startsWith('…'));
      expect(hit.snippet, endsWith('…'));
      expect(marked(hit.snippet, hit.marks), contains('[orçamento]'));
      // Começa numa palavra inteira, não no meio de uma.
      expect(hit.snippet.substring(1), startsWith('palavra'));
    });

    test('busca vazia não devolve nada', () {
      final search = MeetingSearch.index([
        meeting('Qualquer', segments: [said('texto')]),
      ]);

      expect(search.search('   '), isEmpty);
    });
  });

  group('MeetingSearch.marksIn', () {
    test('grifa todas as ocorrências, juntando as que se sobrepõem', () {
      const text = 'Orçamento: o orçamento e a orça.';

      expect(
        marked(text, MeetingSearch.marksIn(text, 'orç orçamento')),
        '[Orçamento]: o [orçamento] e a [orç]a.',
      );
    });
  });
}
