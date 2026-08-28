import 'package:evergreen/app/providers.dart';
import 'package:evergreen/core/design/app_theme.dart';
import 'package:evergreen/features/focus/data/focus_session_repository.dart';
import 'package:evergreen/features/focus/models/focus_session.dart';
import 'package:evergreen/features/focus/models/focus_session_note.dart';
import 'package:evergreen/features/focus/presentation/views/focus_settings_view.dart';
import 'package:evergreen/features/focus/presentation/widgets/focus_week_strip.dart';
import 'package:evergreen/shared/widgets/eg_confirm_dialog.dart';
import 'package:evergreen/shared/widgets/eg_settings_row.dart';
import 'package:evergreen/shared/widgets/eg_toggle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_focus_session_repository.dart';

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
    SharedPreferences.setMockInitialValues({});
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

  Future<void> pumpSettings(WidgetTester tester) async {
    // Tela alta: com a faixa da semana e o histórico agrupado, a superfície
    // padrão de 800x600 deixaria os toggles do fim da tela fora do viewport, e
    // um `tap` neles não acertaria nada — falharia como se a preferência não
    // respondesse.
    tester.view.physicalSize = const Size(1800, 3200);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          focusSessionRepositoryProvider.overrideWithValue(repository),
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
        child: MaterialApp(
          theme: AppTheme.build(),
          home: const Scaffold(
            body: SingleChildScrollView(child: FocusSettingsView()),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  EgToggle toggleFor(WidgetTester tester, String label) {
    return tester.widget<EgToggle>(
      find.descendant(
        of: find.ancestor(
          of: find.text(label),
          matching: find.byType(EgSettingsRow),
        ),
        matching: find.byType(EgToggle),
      ),
    );
  }

  testWidgets('o resumo soma o dia e a semana', (tester) async {
    await pumpSettings(tester);

    // Os dois totais vivem num parágrafo só, para se alinharem pela linha de
    // base e quebrarem linha numa janela estreita — daí a busca por trecho.
    expect(find.textContaining('hoje'), findsOneWidget);
    expect(find.textContaining('na semana'), findsOneWidget);
    expect(
      find.textContaining('1h 05min'),
      findsWidgets,
      reason: '25 + 40 minutos',
    );
    // A semana também é mostrada em barras, uma por dia.
    expect(find.byType(FocusWeekStrip), findsOneWidget);
    expect(find.text('seg'), findsOneWidget);
    expect(find.text('dom'), findsOneWidget);
  });

  testWidgets('cada linha do histórico diz quando, quanto e o que há dentro', (
    tester,
  ) async {
    await pumpSettings(tester);

    // O dia é do grupo, não da linha: a linha fica com a hora.
    expect(find.text('HOJE'), findsOneWidget);
    expect(find.text('09:12'), findsOneWidget);
    // Título e anúncio num parágrafo só, como o apelido na linha do Pin — daí
    // a busca por trecho em vez de texto exato.
    expect(find.textContaining('Refatorar o módulo de auth'), findsOneWidget);
    expect(find.text('40 min'), findsOneWidget);
    // A linha anuncia o que o detalhe guarda, sem despejar na lista.
    expect(find.textContaining('1 anotação · resumo'), findsOneWidget);
    // Sem atividade escrita, a linha se apresenta como o registro sem nome que
    // é — a hora já está na coluna da esquerda.
    expect(find.text('14:30'), findsOneWidget);
    expect(find.text('Sessão'), findsOneWidget);
  });

  testWidgets('apenas Pomodoro desabilita as perguntas sem escondê-las', (
    tester,
  ) async {
    await pumpSettings(tester);

    expect(
      toggleFor(tester, 'Perguntar a atividade ao iniciar').onChanged,
      isNotNull,
    );

    await tester.tap(
      find.descendant(
        of: find.ancestor(
          of: find.text('Utilizar apenas Pomodoro'),
          matching: find.byType(EgSettingsRow),
        ),
        matching: find.byType(EgToggle),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Perguntar a atividade ao iniciar'), findsOneWidget);
    expect(
      toggleFor(tester, 'Perguntar a atividade ao iniciar').onChanged,
      isNull,
    );
    expect(toggleFor(tester, 'Pedir um resumo ao terminar').onChanged, isNull);
    // O que não depende do modo continua editável.
    expect(toggleFor(tester, 'Tocar som ao finalizar').onChanged, isNotNull);
  });

  testWidgets('limpar histórico pede confirmação antes de apagar', (
    tester,
  ) async {
    await pumpSettings(tester);

    await tester.tap(find.text('Limpar'));
    await tester.pumpAndSettle();

    expect(find.byType(EgConfirmDialog), findsOneWidget);
    expect(repository.loadRecent(), hasLength(2));

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(repository.loadRecent(), hasLength(2));

    await tester.tap(find.text('Limpar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Limpar').last);
    await tester.pumpAndSettle();

    expect(repository.loadRecent(), isEmpty);
    expect(find.text('Nenhuma sessão esta semana'), findsOneWidget);
  });

  testWidgets('o que é da semana passada não aparece nem conta', (
    tester,
  ) async {
    // Um minuto antes da segunda-feira desta semana — a fronteira do histórico.
    final lastWeek = SqliteFocusSessionRepository.startOfWeek(
      today,
    ).subtract(const Duration(minutes: 1));

    repository.insert(
      FocusSession(
        startedAt: lastWeek,
        duration: const Duration(minutes: 50),
        activity: 'Coisa da semana passada',
      ),
    );

    await pumpSettings(tester);

    expect(find.text('Coisa da semana passada'), findsNothing);
    expect(
      find.textContaining('1h 05min'),
      findsWidgets,
      reason: 'o total da semana ignora o que ficou para trás',
    );
    expect(
      repository.loadRecent(),
      hasLength(2),
      reason: 'a linha foi apagada',
    );
  });

  testWidgets('as perguntas desligadas pelo Pomodoro puro aparecem desligadas', (
    tester,
  ) async {
    // O que o usuário deixou gravado antes de ligar o Pomodoro puro.
    SharedPreferences.setMockInitialValues({
      'focus.ask_activity': true,
      'focus.ask_summary': true,
      'focus.pomodoro_only': true,
    });
    preferences = await SharedPreferences.getInstance();

    await pumpSettings(tester);

    // O valor efetivo é "não pergunta" — e é ele que o controle mostra. Exibir
    // o toggle ligado (só apagadinho) prometeria um resumo que nunca vem.
    expect(
      toggleFor(tester, 'Perguntar a atividade ao iniciar').value,
      isFalse,
    );
    expect(toggleFor(tester, 'Pedir um resumo ao terminar').value, isFalse);
  });

  testWidgets('desligar o Pomodoro puro devolve as escolhas guardadas', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'focus.ask_summary': true,
      'focus.pomodoro_only': true,
    });
    preferences = await SharedPreferences.getInstance();

    await pumpSettings(tester);
    expect(toggleFor(tester, 'Pedir um resumo ao terminar').value, isFalse);

    await tester.tap(
      find.descendant(
        of: find.ancestor(
          of: find.text('Utilizar apenas Pomodoro'),
          matching: find.byType(EgSettingsRow),
        ),
        matching: find.byType(EgToggle),
      ),
    );
    await tester.pumpAndSettle();

    expect(toggleFor(tester, 'Pedir um resumo ao terminar').value, isTrue);
  });
}
