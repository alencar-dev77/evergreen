import 'dart:async';

import 'package:evergreen/core/design/app_theme.dart';
import 'package:evergreen/core/design/eg_tokens.dart';
import 'package:evergreen/features/echo/models/echo_capabilities.dart';
import 'package:evergreen/features/echo/models/meeting.dart';
import 'package:evergreen/features/echo/models/meeting_document.dart';
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
    VoidCallback? onCancelSummary,
    Future<String?> Function(MeetingDocumentKind kind)? onCopy,
    Future<String?> Function(MeetingDocumentKind kind)? onExport,
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
            onCancelSummary: onCancelSummary ?? () {},
            onCopy: onCopy ?? (_) async => null,
            onExport: onExport ?? (_) async => null,
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
      await pumpDetail(tester, meeting: meetingWith(), isSummarizing: true);
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

    testWidgets('resumo antigo, sem registro, não inventa bloco', (
      tester,
    ) async {
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
      find.ancestor(of: find.text('Apagar'), matching: find.byType(EgButton)),
    );

    await pumpDetail(tester, meeting: meeting, isSummarizing: true);
    await openSummaryTab(tester);
    final resumindo = tester.getTopLeft(
      find.ancestor(of: find.text('Apagar'), matching: find.byType(EgButton)),
    );

    expect(resumindo, parado);
  });

  group('desistir do resumo', () {
    testWidgets('o botão só existe enquanto há resumo em curso', (
      tester,
    ) async {
      final meeting = meetingWith();

      await pumpDetail(tester, meeting: meeting, isSummarizing: false);
      await openSummaryTab(tester);
      expect(find.text('Cancelar'), findsNothing);

      await pumpDetail(tester, meeting: meeting, isSummarizing: true);
      await openSummaryTab(tester);
      expect(find.text('Cancelar'), findsOneWidget);
    });

    testWidgets('apertar avisa quem sabe desistir', (tester) async {
      var pedidos = 0;

      await pumpDetail(
        tester,
        meeting: meetingWith(),
        isSummarizing: true,
        onCancelSummary: () => pedidos++,
      );
      await openSummaryTab(tester);
      await tester.tap(find.text('Cancelar'));
      await tester.pump();

      expect(pedidos, 1);
    });

    /// O "Resumir" continua na tela ao lado do "Cancelar": é ele que carrega a
    /// espera, e trocá-lo pelo outro no instante do clique é a armadilha que o
    /// teste do "Apagar" acima já descreve.
    testWidgets('o botão de resumir não sai do lugar', (tester) async {
      final meeting = meetingWith();

      await pumpDetail(tester, meeting: meeting, isSummarizing: true);
      await openSummaryTab(tester);

      expect(find.text('Resumir'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
    });
  });

  /// Copiar e exportar são do **documento aberto**, não da reunião.
  ///
  /// É a razão de os dois botões morarem na linha do seletor, e não no rodapé
  /// com "Resumir" e "Apagar": o alvo deles muda junto com a aba, e ver as duas
  /// coisas na mesma linha é o que torna isso óbvio sem uma palavra escrita.
  group('copiar e exportar', () {
    testWidgets('os dois botões existem nas duas abas', (tester) async {
      await pumpDetail(
        tester,
        meeting: meetingWith(summary: 'O time fechou o escopo.'),
        isSummarizing: false,
      );
      await openSummaryTab(tester);

      expect(find.text('Copiar'), findsOneWidget);
      expect(find.text('Exportar'), findsOneWidget);

      await tester.tap(find.text('Transcrição'));
      await tester.pumpAndSettle();

      expect(find.text('Copiar'), findsOneWidget);
      expect(find.text('Exportar'), findsOneWidget);
    });

    testWidgets('o alvo do botão é a aba aberta', (tester) async {
      final pedidos = <MeetingDocumentKind>[];

      await pumpDetail(
        tester,
        meeting: meetingWith(summary: 'O time fechou o escopo.'),
        isSummarizing: false,
        onCopy: (kind) async {
          pedidos.add(kind);
          return kind.copiedLabel;
        },
      );
      await openSummaryTab(tester);

      await tester.tap(find.text('Copiar'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Transcrição'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Copiar'));
      await tester.pumpAndSettle();

      expect(pedidos, [
        MeetingDocumentKind.summary,
        MeetingDocumentKind.transcript,
      ]);
    });

    /// Sem resumo não há o que copiar, e um botão que copiaria vazio promete
    /// uma cópia que não acontece. A transcrição, essa sempre existe quando a
    /// reunião tem fala.
    testWidgets('sem resumo, os botões da aba do resumo não respondem', (
      tester,
    ) async {
      await pumpDetail(tester, meeting: meetingWith(), isSummarizing: false);
      await openSummaryTab(tester);

      final copiar = tester.widget<EgButton>(
        find.ancestor(of: find.text('Copiar'), matching: find.byType(EgButton)),
      );
      final exportar = tester.widget<EgButton>(
        find.ancestor(
          of: find.text('Exportar'),
          matching: find.byType(EgButton),
        ),
      );

      expect(copiar.onPressed, isNull);
      expect(exportar.onPressed, isNull);

      await tester.tap(find.text('Transcrição'));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<EgButton>(
              find.ancestor(
                of: find.text('Copiar'),
                matching: find.byType(EgButton),
              ),
            )
            .onPressed,
        isNotNull,
      );
    });

    testWidgets('a confirmação aparece e sai sozinha', (tester) async {
      await pumpDetail(
        tester,
        meeting: meetingWith(summary: 'O time fechou o escopo.'),
        isSummarizing: false,
        onCopy: (kind) async => kind.copiedLabel,
      );
      await openSummaryTab(tester);

      expect(find.text('Resumo copiado'), findsNothing);

      await tester.tap(find.text('Copiar'));
      await tester.pumpAndSettle();
      expect(find.text('Resumo copiado'), findsOneWidget);

      // Ela responde "deu certo", e a resposta perde o sentido assim que a
      // pessoa volta ao texto — permanente, viraria um rótulo fixo.
      await tester.pump(const Duration(seconds: 4));
      expect(find.text('Resumo copiado'), findsNothing);
    });

    /// A confirmação é da face que estava aberta: mantida, ela diria que o
    /// resumo foi copiado enquanto a transcrição está na tela.
    testWidgets('trocar de aba apaga a confirmação', (tester) async {
      await pumpDetail(
        tester,
        meeting: meetingWith(summary: 'O time fechou o escopo.'),
        isSummarizing: false,
        onCopy: (kind) async => kind.copiedLabel,
      );
      await openSummaryTab(tester);

      await tester.tap(find.text('Copiar'));
      await tester.pumpAndSettle();
      expect(find.text('Resumo copiado'), findsOneWidget);

      await tester.tap(find.text('Transcrição'));
      await tester.pumpAndSettle();

      expect(find.text('Resumo copiado'), findsNothing);
    });

    /// Exportar mexe no disco e abre o Finder. O botão carrega a espera em vez
    /// de sair da tela — a mesma regra do "Refazer resumo" logo acima.
    testWidgets('exportando, o botão fica na tela carregando', (tester) async {
      final release = Completer<String?>();

      await pumpDetail(
        tester,
        meeting: meetingWith(summary: 'O time fechou o escopo.'),
        isSummarizing: false,
        onExport: (_) => release.future,
      );
      await openSummaryTab(tester);

      await tester.tap(find.text('Exportar'));
      await tester.pump();

      expect(find.text('Exportar'), findsOneWidget);
      expect(find.byType(EgSpinner), findsOneWidget);

      release.complete('Resumo exportado');
      await tester.pumpAndSettle();

      expect(find.byType(EgSpinner), findsNothing);
      expect(find.text('Resumo exportado'), findsOneWidget);
    });

    /// Falhar em escrever não pode confirmar nada: quem devolve `null` é quem
    /// já pôs o aviso de erro no lugar de sempre.
    testWidgets('exportação que falhou não confirma nada', (tester) async {
      await pumpDetail(
        tester,
        meeting: meetingWith(summary: 'O time fechou o escopo.'),
        isSummarizing: false,
        onExport: (_) async => null,
      );
      await openSummaryTab(tester);

      await tester.tap(find.text('Exportar'));
      await tester.pumpAndSettle();

      expect(find.textContaining('exportad'), findsNothing);
    });
  });

  group('vozes do outro lado', () {
    testWidgets('cada voz é um turno com o número dela, no neutro', (
      tester,
    ) async {
      final meeting = Meeting(
        id: 2,
        title: 'Planejamento',
        startedAt: DateTime(2026, 10, 2, 14),
        durationMs: const Duration(minutes: 5).inMilliseconds,
        language: TranscriptionLanguage.ptBR,
        segments: const [
          MeetingSegment(
            speaker: Speaker.others,
            startMs: 0,
            endMs: 2000,
            text: 'Pode ser sexta?',
            voice: 1,
          ),
          MeetingSegment(
            speaker: Speaker.me,
            startMs: 2500,
            endMs: 3500,
            text: 'Por mim tudo bem.',
          ),
          MeetingSegment(
            speaker: Speaker.others,
            startMs: 4000,
            endMs: 6000,
            text: 'Sexta eu consigo.',
            voice: 2,
          ),
        ],
      );

      await pumpDetail(
        tester,
        meeting: meeting,
        isSummarizing: false,
        userName: 'Lucas',
      );
      await tester.tap(find.text('Transcrição'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Pessoa 1'), findsOneWidget);
      expect(find.text('Pessoa 2'), findsOneWidget);
      expect(find.text('Lucas'), findsOneWidget);
      expect(find.text('Reunião'), findsNothing);

      // O verde é seu. As vozes do outro lado se distinguem pelo nome escrito,
      // e todas no mesmo tom.
      final context = tester.element(find.text('Pessoa 1'));
      final neutral = context.eg.colors.textSecondary;
      for (final label in ['Pessoa 1', 'Pessoa 2']) {
        expect(tester.widget<Text>(find.text(label)).style?.color, neutral);
      }
    });
  });
}
