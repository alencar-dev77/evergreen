import 'package:evergreen/features/echo/models/meeting.dart';
import 'package:evergreen/features/echo/models/meeting_document.dart';
import 'package:evergreen/features/echo/models/meeting_segment.dart';
import 'package:evergreen/features/echo/models/transcription_language.dart';
import 'package:flutter_test/flutter_test.dart';

/// A reunião virada texto, para sair do Evergreen.
///
/// O que estes testes prendem é a promessa do botão: **o que sai é o que está
/// na tela**. Copiar a transcrição tem de devolver os turnos, e não os trechos
/// picados do banco; copiar o resumo tem de devolver o resumo, e não a linha
/// que explica que ainda não há um.
void main() {
  Meeting meetingWith({
    String title = 'Alinhamento de escopo',
    String? summary,
    String? summaryPrompt,
    List<MeetingSegment> segments = const [
      MeetingSegment(
        speaker: Speaker.others,
        startMs: 4000,
        endMs: 9000,
        text: 'Então, a ideia é fechar o escopo hoje.',
      ),
      MeetingSegment(
        speaker: Speaker.me,
        startMs: 10000,
        endMs: 12000,
        text: 'Fechado, mando a proposta',
      ),
      MeetingSegment(
        speaker: Speaker.me,
        startMs: 12000,
        endMs: 14000,
        text: ' até sexta.',
      ),
    ],
  }) => Meeting(
    id: 1,
    title: title,
    startedAt: DateTime(2026, 8, 26, 10, 5),
    durationMs: const Duration(minutes: 32).inMilliseconds,
    language: TranscriptionLanguage.ptBR,
    summary: summary,
    summaryPrompt: summaryPrompt,
    segments: segments,
  );

  group('o que se copia', () {
    test('o resumo sai sozinho, sem título nem data', () {
      final text = MeetingDocument.body(
        meetingWith(summary: 'O time fechou o escopo.'),
        MeetingDocumentKind.summary,
      );

      // Copiar é colar em outro lugar, que já tem o contexto — o cabeçalho é
      // do arquivo exportado, que sai sozinho no disco.
      expect(text, 'O time fechou o escopo.');
    });

    test('sem resumo não há o que copiar', () {
      final text = MeetingDocument.body(
        meetingWith(),
        MeetingDocumentKind.summary,
      );

      expect(text, isNull);
    });

    test('a transcrição sai em turnos, não em trechos', () {
      final text = MeetingDocument.body(
        meetingWith(),
        MeetingDocumentKind.transcript,
      );

      // Os dois trechos seguidos da mesma pessoa viram um parágrafo só — é o
      // que a tela desenha, e copiar tem de entregar o mesmo.
      expect(text, contains('Fechado, mando a proposta até sexta.'));
      expect(text, contains('Reunião · 00:04'));
      expect(text, contains('Você · 00:10'));
    });

    test('o nome de quem usa vale também no que sai daqui', () {
      final text = MeetingDocument.body(
        meetingWith(),
        MeetingDocumentKind.transcript,
        userName: 'Lucas',
      );

      expect(text, contains('Lucas · 00:10'));
      expect(text, isNot(contains('Você')));
    });

    test('reunião sem fala nenhuma não tem transcrição', () {
      final text = MeetingDocument.body(
        meetingWith(segments: const []),
        MeetingDocumentKind.transcript,
      );

      expect(text, isNull);
    });
  });

  group('o que se exporta', () {
    test('o arquivo se apresenta: título, data absoluta e seção', () {
      final file = MeetingDocument.file(
        meetingWith(summary: 'O time fechou o escopo.'),
        MeetingDocumentKind.summary,
      );

      expect(file, contains('# Alinhamento de escopo'));
      // Data absoluta, e nunca "Hoje": um arquivo é lido meses depois.
      expect(file, contains('26/08/2026 · 10:05 · 32 min'));
      expect(file, contains('## Resumo'));
      expect(file, contains('O time fechou o escopo.'));
    });

    test('a instrução do resumo vai junto, depois do texto', () {
      final file = MeetingDocument.file(
        meetingWith(
          summary: 'O time fechou o escopo.',
          summaryPrompt: 'Escreva em tópicos curtos.',
        ),
        MeetingDocumentKind.summary,
      )!;

      expect(
        file.indexOf('Instrução deste resumo'),
        greaterThan(file.indexOf('O time fechou o escopo.')),
      );
    });

    test('a transcrição não carrega instrução nenhuma', () {
      final file = MeetingDocument.file(
        meetingWith(
          summary: 'O time fechou o escopo.',
          summaryPrompt: 'Escreva em tópicos curtos.',
        ),
        MeetingDocumentKind.transcript,
      );

      expect(file, isNot(contains('Instrução deste resumo')));
    });

    test('sem o que dizer, não há arquivo a escrever', () {
      expect(
        MeetingDocument.file(meetingWith(), MeetingDocumentKind.summary),
        isNull,
      );
    });
  });

  group('o nome do arquivo', () {
    test('data na frente, título sem acento, face no fim', () {
      expect(
        MeetingDocument.fileName(
          meetingWith(title: 'Alinhamento de Escopo — Ação!'),
          MeetingDocumentKind.summary,
        ),
        '2026-08-26-alinhamento-de-escopo-acao-resumo',
      );
    });

    test('a transcrição se distingue pelo sufixo', () {
      expect(
        MeetingDocument.fileName(meetingWith(), MeetingDocumentKind.transcript),
        endsWith('-transcricao'),
      );
    });

    test('título sem uma letra sequer ainda vira um nome', () {
      expect(
        MeetingDocument.fileName(
          meetingWith(title: '— · —'),
          MeetingDocumentKind.summary,
        ),
        '2026-08-26-reuniao-resumo',
      );
    });

    test('título comprido é cortado, e não termina em hífen', () {
      final name = MeetingDocument.fileName(
        meetingWith(title: '${'a' * 30} ${'b' * 30}'),
        MeetingDocumentKind.summary,
      );

      expect(name, startsWith('2026-08-26-'));
      expect(name, endsWith('-resumo'));
      expect(
        name.length,
        lessThan('2026-08-26-'.length + 48 + '-resumo'.length + 1),
      );
    });
  });
}
