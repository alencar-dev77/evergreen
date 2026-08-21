import 'package:evergreen/app/providers.dart';
import 'package:evergreen/core/design/app_theme.dart';
import 'package:evergreen/core/window/overlay_window.dart';
import 'package:evergreen/features/focus/models/focus_session.dart';
import 'package:evergreen/features/focus/presentation/viewmodels/focus_timer_view_model.dart';
import 'package:evergreen/features/focus/presentation/views/focus_overlay_view.dart';
import 'package:evergreen/shared/widgets/eg_button.dart';
import 'package:evergreen/shared/widgets/eg_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_focus_session_repository.dart';

void main() {
  late FakeFocusSessionRepository repository;

  setUp(() {
    repository = FakeFocusSessionRepository();
  });

  /// [preferences] entra como o plist já gravado — é assim que a tela recebe
  /// uma configuração diferente da padrão.
  Future<ProviderContainer> pumpOverlay(
    WidgetTester tester, {
    Map<String, Object> preferences = const {},
  }) async {
    SharedPreferences.setMockInitialValues(preferences);
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          focusSessionRepositoryProvider.overrideWithValue(repository),
          sharedPreferencesProvider.overrideWithValue(prefs),
          clockProvider.overrideWithValue(() => tester.binding.clock.now()),
        ],
        child: MaterialApp(
          theme: AppTheme.build(),
          home: const FocusOverlayView(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    return ProviderScope.containerOf(
      tester.element(find.byType(FocusOverlayView)),
    );
  }

  /// Mesma razão do teste da ViewModel: o relógio do binding não está na
  /// semana de hoje, e o histórico é da semana corrente.
  List<FocusSession> saved(WidgetTester tester) =>
      repository.loadRecent(now: tester.binding.clock.now());

  /// Deixa o cronômetro parado antes do fim do teste — uma sessão correndo é um
  /// timer pendente, e o binding reclama disso com razão.
  void stop(ProviderContainer container) =>
      container.read(focusTimerViewModelProvider.notifier).dismiss();

  /// O que um clique dentro do painel faz com o teclado.
  ///
  /// Só no macOS, que é onde o `TextField` larga o foco a cada clique fora
  /// dele. O foco largado ia parar no escopo da rota — acima do `Shortcuts` do
  /// painel —, e dali nenhuma tecla voltava a descer: o Esc, o space e o Enter
  /// paravam juntos. Nas outras plataformas o campo não larga nada, e o teste
  /// passaria sem testar.
  testWidgets('clicar fora do campo não emudece o Esc do painel',
      (tester) async {
    final closing = <String>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const channel = MethodChannel('previous_app_focus');
    messenger.setMockMethodCallHandler(channel, (call) async {
      closing.add(call.method);
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    OverlayWindow.instance.resetForTest();

    await pumpOverlay(tester);

    // Um clique dentro do painel, fora do campo: o número da contagem.
    await tester.tapAt(tester.getCenter(find.text('25:00')));
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(closing, contains('beginHide'));
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('a tela de partida propõe a sessão e pergunta a atividade',
      (tester) async {
    await pumpOverlay(tester);

    expect(find.text('FOCO'), findsOneWidget);
    expect(find.text('25:00'), findsOneWidget);
    expect(find.text('Em que você vai trabalhar?'), findsOneWidget);
    expect(find.text('Iniciar foco'), findsOneWidget);
    expect(find.text('iniciar'), findsOneWidget, reason: 'dica do rodapé');

    // O cursor já está no campo: quem abriu o painel quer digitar, não procurar
    // onde clicar.
    final field = tester.widget<EgTextField>(find.byType(EgTextField));
    expect(field.focusNode?.hasFocus, isTrue);
  });

  testWidgets('apenas Pomodoro tira o campo de atividade do caminho',
      (tester) async {
    await pumpOverlay(tester, preferences: {'focus.pomodoro_only': true});

    expect(find.byType(EgTextField), findsNothing);
    expect(find.text('Iniciar foco'), findsOneWidget);
  });

  testWidgets('Enter inicia a sessão com o que foi digitado', (tester) async {
    final container = await pumpOverlay(tester);

    await tester.enterText(
      find.byType(EgTextField),
      'Refatorar o módulo de auth',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(seconds: 30));

    expect(find.text('24:30'), findsOneWidget);
    expect(find.text('Refatorar o módulo de auth'), findsOneWidget);
    // Começou: o campo agora é o de anotação, e as dicas são as da sessão.
    expect(find.text('Anotar o que aconteceu'), findsOneWidget);
    expect(find.text('pausar'), findsOneWidget);

    stop(container);
  });

  testWidgets('space pausa e retoma sem sair do painel', (tester) async {
    final container = await pumpOverlay(tester);

    await tester.tap(find.text('Iniciar foco'));
    await tester.pump(const Duration(minutes: 5));

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();

    expect(find.text('PAUSADO'), findsOneWidget);
    expect(find.text('Retomar'), findsOneWidget);
    expect(find.text('retomar'), findsOneWidget, reason: 'dica do rodapé');

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();

    expect(find.text('FOCO'), findsOneWidget);
    expect(find.text('Pausar'), findsOneWidget);

    stop(container);
  });

  testWidgets('encerrar leva à tela de conclusão, com a pausa à mão',
      (tester) async {
    await pumpOverlay(tester);

    await tester.tap(find.text('Iniciar foco'));
    await tester.pump(const Duration(minutes: 18));

    await tester.tap(find.text('Encerrar'));
    await tester.pump();

    expect(find.text('SESSÃO CONCLUÍDA'), findsOneWidget);
    expect(find.text('18 min'), findsOneWidget);
    expect(find.text('Iniciar pausa'), findsOneWidget);
    expect(saved(tester), hasLength(1));
  });

  testWidgets('com resumo ligado, o campo aparece ao terminar', (tester) async {
    final container = await pumpOverlay(
      tester,
      preferences: {'focus.ask_summary': true},
    );

    await tester.tap(find.text('Iniciar foco'));
    await tester.pump(const Duration(minutes: 25));
    await tester.pumpAndSettle();

    expect(find.text('O que você fez?'), findsOneWidget);

    await tester.enterText(find.byType(EgTextField), 'Terminei a migração');
    await tester.tap(find.text('Iniciar pausa'));
    await tester.pump();

    expect(saved(tester).single.summary, 'Terminei a migração');
    expect(find.text('PAUSA'), findsOneWidget);

    stop(container);
  });

  testWidgets('Enter anota com o minuto e o espaço volta a ser espaço',
      (tester) async {
    final container = await pumpOverlay(tester);

    await tester.tap(find.text('Iniciar foco'));
    await tester.pump(const Duration(minutes: 12));

    await tester.enterText(
      find.byType(EgTextField),
      'terminei a task e comecei outra',
    );
    // Espaços chegaram ao texto: com o campo focado, `space` não pausa.
    expect(container.read(focusTimerViewModelProvider).isRunning, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(
      find.text('aos 12 min — terminei a task e comecei outra'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<EgTextField>(find.byType(EgTextField))
          .controller
          .text,
      isEmpty,
      reason: 'o campo limpa para a próxima anotação',
    );

    stop(container);
  });

  testWidgets('+5 min aparece na reta final e some depois de usado',
      (tester) async {
    final container = await pumpOverlay(tester);

    await tester.tap(find.text('Iniciar foco'));
    await tester.pump(const Duration(minutes: 10));

    expect(find.text('+5 min'), findsNothing);

    await tester.pump(const Duration(minutes: 11));
    await tester.pump();

    expect(find.text('+5 min'), findsWidgets, reason: 'botão e dica do rodapé');

    await tester.tap(find.widgetWithText(EgButton, '+5 min'));
    await tester.pump();

    expect(find.text('+5 min'), findsNothing);
    expect(find.text('09:00'), findsOneWidget);

    stop(container);
  });

  testWidgets('o diário da sessão sobrevive a fechar e reabrir o painel',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    // Container próprio, vivo entre as duas montagens: é o que acontece de
    // verdade quando a janela some e volta — o painel é reconstruído, a
    // ViewModel não.
    final container = ProviderContainer(
      overrides: [
        focusSessionRepositoryProvider.overrideWithValue(repository),
        sharedPreferencesProvider.overrideWithValue(prefs),
        clockProvider.overrideWithValue(() => tester.binding.clock.now()),
      ],
    );
    addTearDown(container.dispose);

    Future<void> mountPanel() async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.build(),
            home: const FocusOverlayView(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await mountPanel();

    await tester.enterText(
      find.byType(EgTextField),
      'Refatorar o módulo de auth',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(minutes: 12));

    await tester.enterText(
      find.byType(EgTextField),
      'terminei a task e comecei outra',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    // Fecha o painel (a janela some, o widget sai da árvore) e reabre.
    await tester.pumpWidget(const SizedBox.shrink());
    await mountPanel();

    expect(find.text('Refatorar o módulo de auth'), findsOneWidget);
    expect(
      find.text('aos 12 min — terminei a task e comecei outra'),
      findsOneWidget,
    );

    container.read(focusTimerViewModelProvider.notifier).dismiss();
  });

  testWidgets('apenas Pomodoro também tira o campo de anotação da sessão',
      (tester) async {
    final container = await pumpOverlay(
      tester,
      preferences: {'focus.pomodoro_only': true},
    );

    await tester.tap(find.text('Iniciar foco'));
    await tester.pump(const Duration(minutes: 5));

    // Pomodoro puro é só o cronômetro: nem atividade, nem anotação, nem resumo.
    expect(find.byType(EgTextField), findsNothing);

    stop(container);
  });

  testWidgets('preferência mudada no Hub vale na próxima abertura do painel',
      (tester) async {
    final container = await pumpOverlay(tester);

    // O Hub roda em outro engine e grava direto no plist.
    await container
        .read(sharedPreferencesProvider)
        .setBool('focus.ask_summary', true);

    // Reabrir o painel é o que relê o disco (o que o atalho global faz).
    await container.read(focusTimerViewModelProvider.notifier).prepareForOpen();
    await tester.pump();

    await tester.tap(find.text('Iniciar foco'));
    await tester.pump(const Duration(minutes: 25));
    await tester.pumpAndSettle();

    expect(find.text('SESSÃO CONCLUÍDA'), findsOneWidget);
    expect(find.text('O que você fez?'), findsOneWidget);

    stop(container);
  });

  testWidgets('o campo de resumo sobrevive ao caminho real do fim de sessão',
      (tester) async {
    final container = await pumpOverlay(
      tester,
      preferences: {'focus.ask_summary': true},
    );

    await tester.tap(find.text('Iniciar foco'));
    await tester.pump(const Duration(minutes: 25));

    // É o que o bootstrap faz ao trazer o painel para a frente no alerta de
    // fim de fase — e o que o teste anterior não exercitava.
    await container.read(focusTimerViewModelProvider.notifier).prepareForOpen();
    await tester.pumpAndSettle();

    expect(find.text('SESSÃO CONCLUÍDA'), findsOneWidget);
    expect(find.text('O que você fez?'), findsOneWidget);

    stop(container);
  });

  testWidgets('o fim de sessão não promete nada sobre a tarefa', (tester) async {
    final container = await pumpOverlay(tester);

    await tester.tap(find.text('Iniciar foco'));
    await tester.pump(const Duration(minutes: 25));
    await tester.pumpAndSettle();

    // "Concluir" lia-se como "concluí a tarefa"; o botão só fecha o ciclo.
    expect(find.text('Concluir'), findsNothing);
    expect(find.widgetWithText(EgButton, 'Encerrar'), findsOneWidget);
    expect(find.text('Iniciar pausa'), findsOneWidget);

    await tester.tap(find.widgetWithText(EgButton, 'Encerrar'));
    await tester.pumpAndSettle();

    expect(container.read(focusTimerViewModelProvider).isIdle, isTrue);
  });
}
