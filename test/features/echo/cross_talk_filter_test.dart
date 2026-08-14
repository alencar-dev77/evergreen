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
        segment(Speaker.others, 1000, 8000,
            'Então a proposta é essa, isso resolve o problema todo'),
        segment(Speaker.me, 12000, 12500, 'isso'),
      ]);

      expect(limpo, hasLength(2));
    });

    test('eco reconhecido com erro ainda é filtrado', () {
      // O que volta pela sala chega degradado, e o reconhecimento erra palavras
      // que acertou no áudio limpo. Exigir texto idêntico não filtraria nada.
      final limpo = CrossTalkFilter.clean([
        segment(Speaker.others, 1000, 5000,
            'Ficou decidido que o Lucas manda a proposta até sexta'),
        segment(Speaker.me, 1300, 5200,
            'ficou decidido que o lucas manda a proposta até serta'),
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
}
