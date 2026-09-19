import 'package:evergreen/app/providers.dart';
import 'package:evergreen/core/design/app_theme.dart';
import 'package:evergreen/core/storage/app_database.dart';
import 'package:evergreen/features/echo/data/echo_repository.dart';
import 'package:evergreen/features/echo/models/meeting.dart';
import 'package:evergreen/features/echo/models/meeting_segment.dart';
import 'package:evergreen/features/echo/models/transcription_language.dart';
import 'package:evergreen/features/home/models/evergreen_module.dart';
import 'package:evergreen/features/home/presentation/views/hub_view.dart';
import 'package:evergreen/features/home/presentation/widgets/hub_detail_region.dart';
import 'package:evergreen/shared/widgets/eg_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../pin/fake_clipboard_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';

import 'fake_echo_channel.dart';
import 'fake_export_service.dart';

/// A região de leitura do Hub — a coluna que a janela cresce para mostrar.
///
/// O que estes testes prendem é o ciclo dela: abre no clique, fecha por `esc`,
/// fecha ao trocar de módulo e fecha quando não sobra reunião nenhuma. Uma
/// região que fica aberta sozinha é uma coluna de 480px encostada na tela
/// errada — e a janela, que cresceu para caber nela, não volta.
void main() {
  late SharedPreferences preferences;
  late Database db;
  late FakeExportService exports;

  setUp(() async {
    // Duas chaves, dois caminhos de primeira vez que este teste não quer: a
    // apresentação de boas-vindas (que espera cinco cliques em "Próximo") e a
    // pergunta do nome (que leva o Hub para a tela do aplicativo). Aqui o app
    // já foi apresentado e já sabe com quem fala.
    SharedPreferences.setMockInitialValues({
      'app.onboarding_seen': true,
      'app.user_name': 'Lucas',
    });
    preferences = await SharedPreferences.getInstance();

    db = sqlite3.openInMemory();
    AppDatabase.migrate(db);
    exports = FakeExportService();

    final repository = SqliteEchoRepository(db);
    repository.insert(
      Meeting(
        title: 'Alinhamento de escopo',
        startedAt: DateTime.now().subtract(const Duration(hours: 3)),
        durationMs: const Duration(minutes: 32).inMilliseconds,
        language: TranscriptionLanguage.ptBR,
        segments: const [
          MeetingSegment(
            speaker: Speaker.others,
            startMs: 4000,
            endMs: 9000,
            text: 'Então, a ideia é fechar o escopo hoje.',
          ),
        ],
      ),
    );
  });

  tearDown(() => db.close());

  Future<void> pumpHub(WidgetTester tester) async {
    // Larga o bastante para a janela "já expandida": sob `flutter test` não há
    // janela nativa para crescer de verdade.
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          // O Hub abre no Pin, e a tela dele conta os itens por tipo.
          clipboardRepositoryProvider.overrideWithValue(
            FakeClipboardRepository(),
          ),
          echoRepositoryProvider.overrideWithValue(SqliteEchoRepository(db)),
          echoChannelProvider.overrideWithValue(FakeEchoChannel()),
          exportServiceProvider.overrideWithValue(exports),
        ],
        child: MaterialApp(theme: AppTheme.build(), home: const HubView()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(EvergreenModule.echo.name));
    await tester.pumpAndSettle();

    // A tela abre em "Ajustes", que é a aba padrão de todo módulo. A lista
    // mora na outra.
    await tester.tap(find.text('Reuniões'));
    await tester.pumpAndSettle();
  }

  Future<void> openMeeting(WidgetTester tester) async {
    await tester.tap(find.textContaining('Alinhamento de escopo'));
    await tester.pumpAndSettle();
  }

  testWidgets('a reunião só abre quando se clica nela', (tester) async {
    await pumpHub(tester);

    // A lista já vem com uma reunião selecionada, mas a região não se abre
    // sozinha: abrir é um gesto, e a janela cresce junto.
    expect(find.byType(HubDetailRegion), findsNothing);

    await openMeeting(tester);

    expect(find.byType(HubDetailRegion), findsOneWidget);
    expect(find.text('Resumo'), findsOneWidget);
    expect(find.text('Transcrição'), findsOneWidget);
  });

  testWidgets('a transcrição e o resumo se alternam, um de cada vez', (
    tester,
  ) async {
    await pumpHub(tester);
    await openMeeting(tester);

    expect(find.textContaining('Então, a ideia'), findsNothing);

    await tester.tap(find.text('Transcrição'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Então, a ideia'), findsOneWidget);
  });

  testWidgets('esc fecha a região', (tester) async {
    await pumpHub(tester);
    await openMeeting(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byType(HubDetailRegion), findsNothing);
  });

  testWidgets('trocar de módulo fecha a região', (tester) async {
    await pumpHub(tester);
    await openMeeting(tester);

    // Awake, e não Focus: a tela do Focus lê o banco, e o que este teste quer
    // saber é o que acontece com a região ao trocar de módulo.
    await tester.tap(find.text(EvergreenModule.awake.name));
    await tester.pumpAndSettle();

    // Uma reunião aberta ao lado das preferências de outro módulo seria a
    // leitura de um módulo dentro de outro.
    expect(find.byType(HubDetailRegion), findsNothing);
  });

  /// A janela cresce para caber a região, mas a resposta do lado nativo é
  /// animada — e num monitor pequeno ela pode nem crescer o bastante. Nesses
  /// quadros o Hub tem menos largura do que a região gostaria, e quem precisa
  /// ceder é a região: foi assim que a primeira versão estourou o layout de
  /// todas as linhas de configuração da tela do Echo.
  ///
  /// Não há `expect`: um `RenderFlex overflowed` já reprova o teste sozinho.
  testWidgets('a região cede largura em vez de espremer o conteúdo', (
    tester,
  ) async {
    await pumpHub(tester);
    await openMeeting(tester);

    // Da janela que ainda não cresceu (880 é a largura de partida do Hub) até a
    // já expandida.
    for (final width in [880.0, 1000.0, 1100.0, 1360.0, 1440.0]) {
      tester.view.physicalSize = Size(width, 900);
      await tester.pumpAndSettle();

      expect(find.byType(HubDetailRegion), findsOneWidget);
    }
  });

  testWidgets('apagar a última reunião fecha a região', (tester) async {
    await pumpHub(tester);
    await openMeeting(tester);

    await tester.tap(find.text('Apagar'));
    await tester.pumpAndSettle();

    expect(find.byType(HubDetailRegion), findsNothing);
    expect(find.text('Nenhuma reunião gravada'), findsOneWidget);
  });

  /// O caminho inteiro de "Exportar": o botão, a ViewModel, o texto montado e
  /// o arquivo escrito. Os pedaços têm teste próprio; o que se prende aqui é a
  /// fiação entre eles — e que o que sai é a **face aberta**, não a reunião
  /// toda.
  testWidgets('exportar escreve a face aberta, com nome próprio', (
    tester,
  ) async {
    await pumpHub(tester);
    await openMeeting(tester);

    await tester.tap(find.text('Transcrição'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Exportar'));
    await tester.pumpAndSettle();

    expect(exports.written, hasLength(1));

    final written = exports.written.single;
    expect(written.baseName, endsWith('-alinhamento-de-escopo-transcricao'));
    expect(written.content, contains('# Alinhamento de escopo'));
    expect(written.content, contains('## Transcrição'));
    expect(written.content, contains('Então, a ideia é fechar o escopo hoje.'));

    // O arquivo vai parar numa pasta funda demais para alguém achá-la
    // sozinho: mostrar no Finder é o que completa a ação.
    expect(exports.revealed, hasLength(1));

    expect(find.text('Transcrição exportada'), findsOneWidget);
  });

  /// A reunião deste teste não tem resumo, e um botão que copiaria vazio
  /// promete uma cópia que não acontece.
  testWidgets('sem resumo, a aba do resumo não oferece o que levar', (
    tester,
  ) async {
    await pumpHub(tester);
    await openMeeting(tester);

    expect(
      tester
          .widget<EgButton>(
            find.ancestor(
              of: find.text('Exportar'),
              matching: find.byType(EgButton),
            ),
          )
          .onPressed,
      isNull,
    );
    expect(exports.written, isEmpty);
  });
}
