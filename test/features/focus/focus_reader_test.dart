import 'package:evergreen/app/providers.dart';
import 'package:evergreen/core/design/app_theme.dart';
import 'package:evergreen/features/focus/models/focus_session.dart';
import 'package:evergreen/features/focus/models/focus_session_note.dart';
import 'package:evergreen/features/home/models/evergreen_module.dart';
import 'package:evergreen/features/home/presentation/views/hub_view.dart';
import 'package:evergreen/features/home/presentation/widgets/hub_detail_region.dart';
import 'package:evergreen/shared/widgets/eg_confirm_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../pin/fake_clipboard_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_focus_session_repository.dart';

/// A sessão do histórico na região de leitura do Hub.
///
/// Era um diálogo modal até aqui, e virou a mesma região que o Echo usa para a
/// reunião: no Evergreen, documento longo para reler abre na coluna que a
/// janela cresce para caber. O que estes testes prendem é o ciclo dela — abre
/// no clique, fecha por `esc`, fecha ao trocar de módulo e fecha quando a
/// sessão aberta deixa de existir.
void main() {
  late FakeFocusSessionRepository repository;
  late SharedPreferences preferences;

  final today = DateTime.now();

  /// Tudo dentro da semana corrente de propósito: o histórico do Focus zera na
  /// segunda-feira, e uma fixture "de ontem" sumiria quando o teste rodasse
  /// numa segunda.
  DateTime at(int hour, int minute) =>
      DateTime(today.year, today.month, today.day, hour, minute);

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

    repository = FakeFocusSessionRepository([
      FocusSession(
        id: 1,
        startedAt: at(9, 12),
        duration: const Duration(minutes: 25),
        activity: 'Refatorar o módulo de auth',
        summary: 'Terminei a migração',
        notes: const [
          FocusSessionNote(minute: 12, text: 'terminei a task e comecei outra'),
        ],
      ),
      FocusSession(
        id: 2,
        startedAt: at(14, 30),
        duration: const Duration(minutes: 40),
      ),
    ]);
  });

  Future<void> pumpHub(WidgetTester tester) async {
    // Larga o bastante para a janela "já expandida": sob `flutter test` não há
    // janela nativa para crescer de verdade.
    tester.view.physicalSize = const Size(1440, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          focusSessionRepositoryProvider.overrideWithValue(repository),
          sharedPreferencesProvider.overrideWithValue(preferences),
          // O Hub abre no Pin, e a tela dele conta os itens por tipo.
          clipboardRepositoryProvider.overrideWithValue(
            FakeClipboardRepository(),
          ),
        ],
        child: MaterialApp(theme: AppTheme.build(), home: const HubView()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(EvergreenModule.focus.name));
    await tester.pumpAndSettle();

    // A tela abre em "Ajustes", que é a aba padrão de todo módulo. A lista
    // mora na outra.
    await tester.tap(find.text('Histórico'));
    await tester.pumpAndSettle();
  }

  Future<void> openSession(WidgetTester tester) async {
    await tester.tap(find.textContaining('Refatorar o módulo de auth'));
    await tester.pumpAndSettle();
  }

  testWidgets('a sessão só abre quando se clica nela', (tester) async {
    await pumpHub(tester);

    // Nenhuma sessão nasce aberta: abrir é um gesto, e a janela cresce junto.
    expect(find.byType(HubDetailRegion), findsNothing);

    await openSession(tester);

    final region = find.byType(HubDetailRegion);
    expect(region, findsOneWidget);
    expect(find.text('Hoje · 09:12 · 25 min'), findsOneWidget);
    // A atividade é o título da região, e não se repete dentro dela.
    expect(
      find.descendant(
        of: region,
        matching: find.text('Refatorar o módulo de auth'),
      ),
      findsOneWidget,
    );
    expect(find.text('ANOTAÇÕES'), findsOneWidget);
    expect(
      find.text('aos 12 min — terminei a task e comecei outra'),
      findsOneWidget,
    );
    expect(find.text('RESUMO'), findsOneWidget);
    expect(find.text('Terminei a migração'), findsOneWidget);
  });

  testWidgets('a lista continua à vista, e trocar de sessão é um clique', (
    tester,
  ) async {
    await pumpHub(tester);
    await openSession(tester);

    // O que o diálogo modal não permitia: a outra sessão continua clicável
    // atrás — não há barreira escurecendo a tela.
    await tester.tap(find.textContaining('Sessão'));
    await tester.pumpAndSettle();

    expect(find.byType(HubDetailRegion), findsOneWidget);
    expect(find.text('Hoje · 14:30 · 40 min'), findsOneWidget);
    expect(find.text('Nenhuma anotação nesta sessão.'), findsOneWidget);
  });

  testWidgets('esc fecha a região', (tester) async {
    await pumpHub(tester);
    await openSession(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byType(HubDetailRegion), findsNothing);
  });

  testWidgets('trocar de módulo fecha a região', (tester) async {
    await pumpHub(tester);
    await openSession(tester);

    await tester.tap(find.text(EvergreenModule.awake.name));
    await tester.pumpAndSettle();

    // Uma sessão aberta ao lado das preferências de outro módulo seria a
    // leitura de um módulo dentro de outro.
    expect(find.byType(HubDetailRegion), findsNothing);
  });

  testWidgets('apagar pela região pede confirmação e não leva as outras', (
    tester,
  ) async {
    await pumpHub(tester);
    await openSession(tester);

    await tester.tap(find.text('Apagar'));
    await tester.pumpAndSettle();

    expect(find.byType(EgConfirmDialog), findsOneWidget);
    expect(repository.loadRecent(), hasLength(2), reason: 'só abriu o aviso');

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(repository.loadRecent(), hasLength(2));
    expect(
      find.byType(HubDetailRegion),
      findsOneWidget,
      reason: 'cancelar volta para a leitura, não fecha a região',
    );

    // O rótulo "Apagar" existe no botão da região e no do aviso; o do aviso é
    // o último a entrar na árvore. O cartão que leva a semana inteira diz
    // "Apagar tudo", justamente para não se confundir com este.
    await tester.tap(find.text('Apagar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apagar').last);
    await tester.pumpAndSettle();

    // Sem sessão aberta não há região — e a janela volta ao tamanho de antes.
    expect(find.byType(HubDetailRegion), findsNothing);
    expect(repository.loadRecent(), hasLength(1));
    expect(find.textContaining('Refatorar o módulo de auth'), findsNothing);
    // A outra sessão continua onde estava, e o resumo da semana acompanha.
    expect(find.text('14:30'), findsOneWidget);
    expect(find.text('40 min'), findsWidgets);
  });

  testWidgets('limpar o histórico inteiro fecha a região', (tester) async {
    await pumpHub(tester);
    await openSession(tester);

    await tester.tap(find.text('Apagar tudo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apagar').last);
    await tester.pumpAndSettle();

    expect(find.byType(HubDetailRegion), findsNothing);
    expect(find.text('Nenhuma sessão esta semana'), findsOneWidget);
  });

  /// A janela cresce para caber a região, mas a resposta do lado nativo é
  /// animada — e num monitor pequeno ela pode nem crescer o bastante. Nesses
  /// quadros o Hub tem menos largura do que a região gostaria, e quem precisa
  /// ceder é a região, nunca a tela de preferências ao lado.
  ///
  /// Não há `expect` de largura: um `RenderFlex overflowed` já reprova o teste
  /// sozinho.
  testWidgets('a região cede largura em vez de espremer o conteúdo', (
    tester,
  ) async {
    await pumpHub(tester);
    await openSession(tester);

    // Da janela que ainda não cresceu (880 é a largura de partida do Hub) até a
    // já expandida.
    for (final width in [880.0, 1000.0, 1100.0, 1360.0, 1440.0]) {
      tester.view.physicalSize = Size(width, 1600);
      await tester.pumpAndSettle();

      expect(find.byType(HubDetailRegion), findsOneWidget);
    }
  });
}
