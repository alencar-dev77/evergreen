import 'package:evergreen/features/echo/models/cross_talk_filter.dart';
import 'package:evergreen/features/echo/models/meeting_segment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  MeetingSegment segment(
    Speaker speaker,
    int startMs,
    int endMs,
    String text,
  ) => MeetingSegment(
    speaker: speaker,
    startMs: startMs,
    endMs: endMs,
    text: text,
  );

  group('CrossTalkFilter', () {
    test('tira da minha faixa o eco da caixa de som', () {
      // A mesma fala nas duas faixas: saiu pela caixa e voltou pelo microfone.
      final limpo = CrossTalkFilter.clean([
        segment(Speaker.others, 1000, 4000, 'Vamos fechar o escopo hoje'),
        segment(Speaker.me, 1200, 4100, 'vamos fechar o escopo hoje'),
      ]);

      expect(limpo, hasLength(1));
      expect(limpo.single.speaker, Speaker.others);
    });

    test('preserva a minha resposta de verdade', () {
      final limpo = CrossTalkFilter.clean([
        segment(Speaker.others, 1000, 4000, 'Vamos fechar o escopo hoje'),
        segment(Speaker.me, 4500, 6000, 'Fechado, mando a proposta sexta'),
      ]);

      expect(limpo, hasLength(2));
    });

    test('texto igual em momentos distantes não é eco', () {
      // O eco é imediato. Repetir a mesma frase minutos depois é conversa.
      final limpo = CrossTalkFilter.clean([
        segment(Speaker.others, 1000, 3000, 'bom dia pessoal'),
        segment(Speaker.me, 600000, 602000, 'bom dia pessoal'),
      ]);

      expect(limpo, hasLength(2));
    });

    test('concordância curta sobrevive', () {
      // "isso" no meio de uma fala longa da reunião não faz da minha um eco:
      // a semelhança é medida sobre as minhas palavras, mas o tempo também
      // precisa bater, e concordar acontece depois.
      final limpo = CrossTalkFilter.clean([
        segment(
          Speaker.others,
          1000,
          8000,
          'Então a proposta é essa, isso resolve o problema todo',
        ),
        segment(Speaker.me, 12000, 12500, 'isso'),
      ]);

      expect(limpo, hasLength(2));
    });

    test('eco reconhecido com erro ainda é filtrado', () {
      // O que volta pela sala chega degradado, e o reconhecimento erra palavras
      // que acertou no áudio limpo. Exigir texto idêntico não filtraria nada.
      final limpo = CrossTalkFilter.clean([
        segment(
          Speaker.others,
          1000,
          5000,
          'Ficou decidido que o Lucas manda a proposta até sexta',
        ),
        segment(
          Speaker.me,
          1300,
          5200,
          'ficou decidido que o lucas manda a proposta até serta',
        ),
      ]);

      expect(limpo, hasLength(1));
      expect(limpo.single.speaker, Speaker.others);
    });

    test('sem faixa da reunião, nada é filtrado', () {
      final apenasEu = [
        segment(Speaker.me, 0, 2000, 'anotação sozinho'),
        segment(Speaker.me, 3000, 5000, 'outra coisa'),
      ];

      expect(CrossTalkFilter.clean(apenasEu), hasLength(2));
    });

    test('a faixa da reunião nunca é tocada', () {
      // Ela é a fonte da verdade: vem do fluxo de áudio antes de virar som no
      // ar, então não tem como conter eco de nada.
      final limpo = CrossTalkFilter.clean([
        segment(Speaker.others, 1000, 3000, 'repetindo a mesma coisa'),
        segment(Speaker.others, 1100, 3100, 'repetindo a mesma coisa'),
      ]);

      expect(limpo, hasLength(2));
    });

    test('lista vazia continua vazia', () {
      expect(CrossTalkFilter.clean(const []), isEmpty);
    });
  });

  group('CrossTalkFilter, palavra a palavra', () {
    // Um trecho com o relógio de cada palavra, como o modelo de fala entrega:
    // as palavras seguidas, a partir de `startMs`, de `step` em `step` ms.
    MeetingSegment spoken(
      Speaker speaker,
      int startMs,
      String text, {
      int step = 300,
    }) {
      final pieces = text.split(' ');
      final words = [
        for (var index = 0; index < pieces.length; index++)
          MeetingWord(
            startMs: startMs + index * step,
            endMs: startMs + (index + 1) * step,
            text: index == 0 ? pieces[index] : ' ${pieces[index]}',
          ),
      ];

      return MeetingSegment(
        speaker: speaker,
        startMs: startMs,
        endMs: startMs + pieces.length * step,
        text: text,
        words: words,
      );
    }

    test('eco que a reunião partiu em vários trechos sai inteiro', () {
      // O reconhecimento fecha os trechos em lugares diferentes nas duas
      // faixas: o eco é um trecho só de um lado e três do outro.
      final limpo = CrossTalkFilter.clean([
        spoken(Speaker.others, 1260, 'É o que'),
        spoken(Speaker.others, 2160, 'você'),
        spoken(Speaker.others, 2460, 'mandou lá na planilha ontem'),
        spoken(Speaker.me, 1200, 'é o que você mandou lá na'),
      ]);

      expect(limpo.where((segment) => segment.speaker == Speaker.me), isEmpty);
    });

    test('palavra ouvida diferente nas duas faixas ainda é eco', () {
      final limpo = CrossTalkFilter.clean([
        spoken(Speaker.others, 8520, 'Interna o teste'),
        spoken(Speaker.me, 8400, 'Interno'),
        spoken(Speaker.others, 23520, 'dieta que é um dos'),
        spoken(Speaker.me, 23400, 'direta'),
      ]);

      expect(limpo.where((segment) => segment.speaker == Speaker.me), isEmpty);
    });

    test('número inteiro de um lado e partido do outro é eco', () {
      final limpo = CrossTalkFilter.clean([
        spoken(Speaker.others, 9420, '1234 5678 90', step: 1000),
        spoken(Speaker.me, 9300, '1234567891', step: 3000),
      ]);

      expect(limpo.where((segment) => segment.speaker == Speaker.me), isEmpty);
    });

    test('a sua fala depois de um eco, no mesmo trecho, fica', () {
      final limpo = CrossTalkFilter.clean([
        spoken(Speaker.others, 1000, 'vamos fechar o escopo hoje'),
        spoken(
          Speaker.me,
          1050,
          'vamos fechar o escopo hoje beleza concordo totalmente',
        ),
      ]);

      final meu = limpo.singleWhere((segment) => segment.speaker == Speaker.me);
      expect(meu.text, 'beleza concordo totalmente');
      expect(meu.startMs, 1050 + 5 * 300);
      expect(meu.words, hasLength(3));
    });

    test('palavra curta junto com a reunião não é prova de eco', () {
      // "é" e "não" aparecem em toda fala: dizê-los ao mesmo tempo que alguém
      // é conversa.
      final limpo = CrossTalkFilter.clean([
        spoken(Speaker.others, 1000, 'é isso não tem jeito'),
        spoken(Speaker.me, 1000, 'é'),
        spoken(Speaker.me, 1600, 'não'),
      ]);

      expect(
        limpo.where((segment) => segment.speaker == Speaker.me),
        hasLength(2),
      );
    });

    test('cumprimento dito junto com alguém fica', () {
      final limpo = CrossTalkFilter.clean([
        spoken(Speaker.others, 1000, 'bom dia'),
        spoken(Speaker.me, 1050, 'bom dia'),
        spoken(Speaker.others, 5000, 'tá bom'),
        spoken(Speaker.me, 5100, 'tá bom'),
      ]);

      expect(
        limpo.where((segment) => segment.speaker == Speaker.me),
        hasLength(2),
      );
    });

    test('reunião longa continua achando o eco no fim', () {
      // A busca olha só a vizinhança de cada palavra: o eco do fim de uma
      // reunião cheia não pode se perder na conta.
      final limpo = CrossTalkFilter.clean([
        for (var index = 0; index < 2000; index++)
          spoken(
            Speaker.others,
            index * 2000,
            'assunto qualquer número $index',
          ),
        spoken(Speaker.others, 4000000, 'fechamos o orçamento hoje'),
        spoken(Speaker.me, 4000050, 'fechamos o orçamento hoje'),
      ]);

      expect(limpo.where((segment) => segment.speaker == Speaker.me), isEmpty);
    });

    test('repetir a palavra de alguém um tempo depois é resposta', () {
      final limpo = CrossTalkFilter.clean([
        spoken(Speaker.others, 1000, 'orçamento aprovado'),
        spoken(Speaker.me, 4000, 'orçamento aprovado'),
      ]);

      expect(
        limpo.where((segment) => segment.speaker == Speaker.me),
        hasLength(1),
      );
    });

    test('a sua fala junto com a reunião, com outras palavras, fica', () {
      final limpo = CrossTalkFilter.clean([
        spoken(Speaker.others, 1000, 'então a gente entrega na sexta'),
        spoken(Speaker.me, 1100, 'espera deixa eu anotar o código'),
      ]);

      expect(
        limpo.where((segment) => segment.speaker == Speaker.me),
        hasLength(1),
      );
    });
  });
}
