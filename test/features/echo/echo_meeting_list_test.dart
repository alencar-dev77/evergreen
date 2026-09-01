import 'package:evergreen/core/design/app_theme.dart';
import 'package:evergreen/features/echo/models/meeting.dart';
import 'package:evergreen/features/echo/models/meeting_segment.dart';
import 'package:evergreen/features/echo/models/transcription_language.dart';
import 'package:evergreen/features/echo/presentation/widgets/echo_meeting_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A lista de reuniões: o que cada linha diz sem ser aberta.
///
/// O estado de uma reunião — transcrita, sendo resumida, resumo pronto — é a
/// única coisa da linha que muda sozinha depois de a gravação acabar, e é o
/// que decide se vale abrir. Ele vivia atrás do nome, como um "resumida" que o
/// corte por ellipsis comia primeiro em qualquer título comprido.
void main() {
  final today = DateTime(2026, 8, 28, 18);

  Meeting meeting({
    required int id,
    required String title,
    required int hour,
    required int minutes,
    String? summary,
    bool withMyVoice = true,
  }) => Meeting(
    id: id,
    title: title,
    startedAt: DateTime(today.year, today.month, today.day, hour),
    durationMs: Duration(minutes: minutes).inMilliseconds,
    language: TranscriptionLanguage.ptBR,
    summary: summary,
    segments: [
      const MeetingSegment(
        speaker: Speaker.others,
        startMs: 0,
        endMs: 4000,
        text: 'Vamos fechar o escopo hoje.',
      ),
      if (withMyVoice)
        const MeetingSegment(
          speaker: Speaker.me,
          startMs: 5000,
          endMs: 9000,
          text: 'Mando a proposta até sexta com os números revisados.',
        ),
    ],
  );

  Future<void> pumpList(
    WidgetTester tester,
    List<Meeting> meetings, {
    int? summarizingId,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: EchoMeetingList(
              meetings: meetings,
              selectedId: null,
              summarizingId: summarizingId,
              onSelect: (_) {},
              onToggleKept: (_) {},
              now: today,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('o estado da reunião', () {
    testWidgets('resumo pronto, só transcrição, resumindo', (tester) async {
      await pumpList(
        tester,
        [
          meeting(id: 1, title: 'Alinhamento', hour: 10, minutes: 32),
          meeting(
            id: 2,
            title: 'Retro da sprint',
            hour: 14,
            minutes: 28,
            summary: 'Ficou decidido que…',
          ),
          meeting(id: 3, title: '1:1', hour: 16, minutes: 25),
        ],
        summarizingId: 3,
      );

      expect(find.textContaining('só transcrição'), findsOneWidget);
      expect(find.textContaining('resumo pronto'), findsOneWidget);
      expect(find.textContaining('resumindo…'), findsOneWidget);
    });

    testWidgets('a hora da reunião vem na mesma linha do estado', (
      tester,
    ) async {
      await pumpList(tester, [
        meeting(id: 1, title: 'Alinhamento', hour: 10, minutes: 32),
      ]);

      expect(find.textContaining('10:00'), findsOneWidget);
    });
  });

  group('o cabeçalho do dia', () {
    testWidgets('soma as durações daquele dia', (tester) async {
      await pumpList(tester, [
        meeting(id: 1, title: 'Alinhamento', hour: 10, minutes: 32),
        meeting(id: 2, title: 'Retro da sprint', hour: 14, minutes: 28),
      ]);

      // 32 + 28: o total é do dia, não da lista.
      expect(find.text('1h'), findsOneWidget);
    });
  });
}
