import 'package:evergreen/core/design/app_theme.dart';
import 'package:evergreen/features/echo/models/echo_capabilities.dart';
import 'package:evergreen/features/echo/models/meeting.dart';
import 'package:evergreen/features/echo/models/meeting_segment.dart';
import 'package:evergreen/features/echo/models/transcription_language.dart';
import 'package:evergreen/features/echo/presentation/widgets/echo_meeting_detail.dart';
import 'package:evergreen/shared/widgets/eg_button.dart';
import 'package:evergreen/shared/widgets/eg_spinner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Resumir tem de ter onde aparecer.
///
/// O botão saía da árvore no instante em que era apertado: a linha subia, o
/// "Apagar" pulava para a esquerda e nada dizia que o resumo estava sendo
/// feito. Refazendo era pior — o corpo da aba devolve o resumo antigo, então
/// não sobrava indicação nenhuma na tela.
void main() {
  Meeting meetingWith({String? summary, String? summaryPrompt}) => Meeting(
        id: 1,
        title: 'Alinhamento de escopo',
        startedAt: DateTime(2026, 8, 26, 10),
        durationMs: const Duration(minutes: 32).inMilliseconds,
        language: TranscriptionLanguage.ptBR,
        summary: summary,
        summaryPrompt: summaryPrompt,
        segments: const [
          MeetingSegment(
            speaker: Speaker.others,
            startMs: 4000,
            endMs: 9000,
            text: 'Então, a ideia é fechar o escopo hoje.',
          ),
        ],
      );

  Future<void> pumpDetail(
    WidgetTester tester, {
    required Meeting meeting,
    required bool isSummarizing,
    (int, int)? progress,
    String userName = '',
  }) async {
    tester.view.physicalSize = const Size(900, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(),
        home: Scaffold(
          body: EchoMeetingDetail(
            meeting: meeting,
            userName: userName,
            summaries: SummaryAvailability.available,
            isSummarizing: isSummarizing,
            progress: progress,
            onSummarize: () {},
            onDelete: () {},
          ),
        ),
      ),
    );
    // `pump`, e não `pumpAndSettle`: o spinner gira para sempre, e esperar a
    // árvore ficar parada seria esperar o resumo terminar — que é justamente o
    // estado sob teste.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// A aba do resumo é a única com ação; a de transcrição não tem o que refazer.
  Future<void> openSummaryTab(WidgetTester tester) async {
    final resumo = find.text('Resumo');
    if (resumo.evaluate().isNotEmpty) {
      await tester.tap(resumo);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  group('primeiro resumo', () {
    testWidgets('resumindo, o botão fica na tela carregando', (tester) async {
      await pumpDetail(
        tester,
        meeting: meetingWith(),
        isSummarizing: true,
      );
      await openSummaryTab(tester);

      expect(find.text('Resumir'), findsOneWidget);
      expect(find.byType(EgSpinner), findsOneWidget);
    });
  });

  group('refazer resumo', () {
    testWidgets('refazendo, o botão fica na tela carregando', (tester) async {
      await pumpDetail(
        tester,
        meeting: meetingWith(summary: 'O time fechou o escopo.'),
        isSummarizing: true,
      );
      await openSummaryTab(tester);

      expect(find.text('Refazer resumo'), findsOneWidget);
      expect(find.byType(EgSpinner), findsOneWidget);
    });

    testWidgets('refazendo, o resumo antigo continua legível', (tester) async {
      await pumpDetail(
        tester,
        meeting: meetingWith(summary: 'O time fechou o escopo.'),
        isSummarizing: true,
      );
      await openSummaryTab(tester);

      expect(find.text('O time fechou o escopo.'), findsOneWidget);
    });

    testWidgets('refazendo em blocos, o progresso aparece', (tester) async {
      await pumpDetail(
        tester,
        meeting: meetingWith(summary: 'O time fechou o escopo.'),
        isSummarizing: true,
        progress: (2, 4),
      );
      await openSummaryTab(tester);

      expect(find.text('Resumindo — bloco 2 de 4'), findsOneWidget);
    });

    testWidgets('parado, não há spinner nem progresso', (tester) async {
      await pumpDetail(
        tester,
        meeting: meetingWith(summary: 'O time fechou o escopo.'),
        isSummarizing: false,
      );
      await openSummaryTab(tester);

      expect(find.byType(EgSpinner), findsNothing);
      expect(find.textContaining('Resumindo'), findsNothing);
      expect(find.text('Refazer resumo'), findsOneWidget);
    });
  });

  /// A instrução que produziu o resumo, embaixo dele.
  ///
  /// Existe porque refazer o resumo troca o texto e não avisa com qual
  /// instrução — e o campo das preferências, que é onde ela era escrita, já
  /// guarda a **próxima**, não a que valeu para o que está na tela.
  group('instrução do resumo', () {
    testWidgets('aparece depois do resumo, não antes dele', (tester) async {
      await pumpDetail(
        tester,
        meeting: meetingWith(
          summary: 'O time fechou o escopo.',
          summaryPrompt: 'Escreva em tópicos curtos.',
        ),
        isSummarizing: false,
      );
      await openSummaryTab(tester);

      expect(find.text('INSTRUÇÃO DESTE RESUMO'), findsOneWidget);
      expect(find.text('Escreva em tópicos curtos.'), findsOneWidget);

      // Nota de rodapé: o que a pessoa veio ler continua vindo primeiro.
      expect(
        tester.getTopLeft(find.text('Escreva em tópicos curtos.')).dy,
        greaterThan(tester.getTopLeft(find.text('O time fechou o escopo.')).dy),
      );
    });

    testWidgets('resumo antigo, sem registro, não inventa bloco', (tester) async {
      await pumpDetail(
        tester,
        meeting: meetingWith(summary: 'O time fechou o escopo.'),
        isSummarizing: false,
      );
      await openSummaryTab(tester);

      expect(find.text('O time fechou o escopo.'), findsOneWidget);
      expect(find.text('INSTRUÇÃO DESTE RESUMO'), findsNothing);
    });

    testWidgets('sem resumo não há instrução para mostrar', (tester) async {
      await pumpDetail(
        tester,
        meeting: meetingWith(summaryPrompt: 'Escreva em tópicos curtos.'),
        isSummarizing: false,
      );
      await openSummaryTab(tester);

      expect(find.text('INSTRUÇÃO DESTE RESUMO'), findsNothing);
    });

    testWidgets('refazendo, a instrução mostrada ainda é a do texto na tela', (
      tester,
    ) async {
      await pumpDetail(
        tester,
        meeting: meetingWith(
          summary: 'O time fechou o escopo.',
          summaryPrompt: 'Escreva em tópicos curtos.',
        ),
        isSummarizing: true,
        progress: (2, 4),
      );
      await openSummaryTab(tester);

      expect(find.text('Escreva em tópicos curtos.'), findsOneWidget);
    });
  });

  /// O "Apagar" fica na ponta oposta justamente para não ser acertado sem
  /// querer; se o botão de resumir sumir, ele escorrega para o lugar do dedo.
  testWidgets('o botão de apagar não muda de lugar ao resumir', (tester) async {
    final meeting = meetingWith(summary: 'O time fechou o escopo.');

    await pumpDetail(tester, meeting: meeting, isSummarizing: false);
    await openSummaryTab(tester);
    final parado = tester.getTopLeft(
      find.ancestor(
        of: find.text('Apagar'),
        matching: find.byType(EgButton),
      ),
    );

    await pumpDetail(tester, meeting: meeting, isSummarizing: true);
    await openSummaryTab(tester);
    final resumindo = tester.getTopLeft(
      find.ancestor(
        of: find.text('Apagar'),
        matching: find.byType(EgButton),
      ),
    );

    expect(resumindo, parado);
  });
}
