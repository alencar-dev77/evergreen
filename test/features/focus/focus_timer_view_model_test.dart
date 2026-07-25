import 'package:evergreen/app/providers.dart';
import 'package:evergreen/features/focus/models/focus_phase.dart';
import 'package:evergreen/features/focus/models/focus_session.dart';
import 'package:evergreen/features/focus/models/focus_session_note.dart';
import 'package:evergreen/features/focus/presentation/viewmodels/focus_timer_state.dart';
import 'package:evergreen/features/focus/presentation/viewmodels/focus_timer_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_focus_session_repository.dart';

/// O cronômetro é testado dentro de `testWidgets` porque só ali o tempo é
/// falso: `tester.pump` avança o relógio do binding, que é o mesmo relógio
/// injetado no `clockProvider` — assim uma sessão de 25 minutos passa em um
/// quadro, sem esperar 25 minutos nem esburacar a ViewModel com atalhos de
/// teste.
void main() {
  late FakeFocusSessionRepository repository;
  late SharedPreferences preferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    repository = FakeFocusSessionRepository();
  });

  ProviderContainer containerFor(WidgetTester tester) {
    final container = ProviderContainer(
      overrides: [
        focusSessionRepositoryProvider.overrideWithValue(repository),
        sharedPreferencesProvider.overrideWithValue(preferences),
        clockProvider.overrideWithValue(() => tester.binding.clock.now()),
      ],
    );

    addTearDown(container.dispose);
    return container;
  }

  FocusTimerState stateOf(ProviderContainer container) =>
      container.read(focusTimerViewModelProvider);

  FocusTimerViewModel viewModelOf(ProviderContainer container) =>
      container.read(focusTimerViewModelProvider.notifier);

  /// O histórico é da semana corrente, e a semana aqui é a do relógio falso —
  /// que não é a de hoje. Ler com ele evita filtrar fora o que acabou de ser
  /// gravado.
  List<FocusSession> saved(WidgetTester tester) =>
      repository.loadRecent(now: tester.binding.clock.now());

  testWidgets('parte parado, com a duração configurada à vista',
      (tester) async {
    final container = containerFor(tester);

    expect(stateOf(container).isIdle, isTrue);
    expect(stateOf(container).remaining, const Duration(minutes: 25));
    expect(stateOf(container).menuBarLabel, isNull);
  });

  testWidgets('a contagem corre e aparece na barra de menus', (tester) async {
    final container = containerFor(tester);
    viewModelOf(container).start(activity: 'Refatorar o módulo de auth');

    await tester.pump(const Duration(seconds: 90));

    final state = stateOf(container);
    expect(state.isRunning, isTrue);
    expect(state.activity, 'Refatorar o módulo de auth');
    // O valor exibido é o que importa: o tique roda quatro vezes por segundo e
    // o estado carrega frações de segundo que nunca chegam à tela.
    expect(state.menuBarLabel, '23:30');

    // Um cronômetro correndo é um timer pendente; o teste precisa fechá-lo.
    viewModelOf(container).dismiss();
  });

  testWidgets('pausar congela o tempo restante', (tester) async {
    final container = containerFor(tester);
    viewModelOf(container).start();

    await tester.pump(const Duration(minutes: 5));
    viewModelOf(container).pause();
    await tester.pump(const Duration(minutes: 10));

    expect(stateOf(container).isPaused, isTrue);
    expect(stateOf(container).remaining, const Duration(minutes: 20));
    expect(stateOf(container).menuBarLabel, 'Pausado 20:00');

    viewModelOf(container).resume();
    await tester.pump(const Duration(minutes: 1));

    expect(stateOf(container).isRunning, isTrue);
    expect(stateOf(container).menuBarLabel, '19:00');

    viewModelOf(container).dismiss();
  });

  testWidgets('sessão completa entra no histórico e pede a tela',
      (tester) async {
    final container = containerFor(tester);
    viewModelOf(container).start(activity: 'Escrever o handoff');

    await tester.pump(const Duration(minutes: 25));

    final state = stateOf(container);
    expect(state.isFinished, isTrue);
    expect(state.alerts, 1, reason: 'o aviso na tela vem ligado por padrão');

    final sessions = saved(tester);
    expect(sessions, hasLength(1));
    expect(sessions.single.duration, const Duration(minutes: 25));
    expect(sessions.single.activity, 'Escrever o handoff');
  });

  testWidgets('encerrar antes da hora registra o que foi focado',
      (tester) async {
    final container = containerFor(tester);
    viewModelOf(container).start();

    await tester.pump(const Duration(minutes: 18));
    viewModelOf(container).stop();

    expect(saved(tester).single.duration, const Duration(minutes: 18));
    // Encerrar é decisão do usuário, que já está olhando para o painel: não há
    // por que trazer a janela para a frente.
    expect(stateOf(container).alerts, 0);
  });

  testWidgets('sessão curta demais não vira registro', (tester) async {
    final container = containerFor(tester);
    viewModelOf(container).start();

    await tester.pump(const Duration(seconds: 20));
    viewModelOf(container).stop();

    expect(saved(tester), isEmpty);
    expect(stateOf(container).lastSession, isNull);
  });

  testWidgets('o resumo é gravado na sessão que acabou de terminar',
      (tester) async {
    final container = containerFor(tester);
    viewModelOf(container).start();

    await tester.pump(const Duration(minutes: 25));
    viewModelOf(container).dismiss(summary: '  Terminei a migração  ');

    expect(saved(tester).single.summary, 'Terminei a migração');
    expect(stateOf(container).isIdle, isTrue);
  });

  testWidgets('a pausa herda a atividade e não vira registro', (tester) async {
    final container = containerFor(tester);
    viewModelOf(container).start(activity: 'Revisar PR');

    await tester.pump(const Duration(minutes: 25));
    viewModelOf(container).startRest();

    expect(stateOf(container).phase, FocusPhase.rest);
    expect(stateOf(container).activity, 'Revisar PR');
    expect(stateOf(container).menuBarLabel, 'Pausa 05:00');

    await tester.pump(const Duration(minutes: 5));

    expect(stateOf(container).isFinished, isTrue);
    expect(
      saved(tester),
      hasLength(1),
      reason: 'só a fase de foco entra no histórico',
    );
  });

  testWidgets('a observação carrega o minuto em que foi escrita',
      (tester) async {
    final container = containerFor(tester);
    viewModelOf(container).start(activity: 'Refatorar o módulo de auth');

    await tester.pump(const Duration(minutes: 12, seconds: 30));
    viewModelOf(container).addNote('  terminei a task e comecei outra  ');

    final note = stateOf(container).lastNote!;
    expect(note.minute, 12);
    expect(note.text, 'terminei a task e comecei outra');
    expect(note.label, 'aos 12 min');

    // Segue com a sessão até o fim: as notas vão junto para o histórico.
    await tester.pump(const Duration(minutes: 13));

    final session = saved(tester).single;
    expect(session.notes, hasLength(1));
    expect(session.notes.single.minute, 12);
  });

  testWidgets('nota vazia ou fora do foco não registra nada', (tester) async {
    final container = containerFor(tester);
    viewModelOf(container).start();

    viewModelOf(container).addNote('   ');
    expect(stateOf(container).notes, isEmpty);

    await tester.pump(const Duration(minutes: 25));
    viewModelOf(container).startRest();
    viewModelOf(container).addNote('na pausa não');

    expect(stateOf(container).notes, isEmpty);

    viewModelOf(container).dismiss();
  });

  testWidgets('+5 min só vale na reta final e uma única vez', (tester) async {
    final container = containerFor(tester);
    viewModelOf(container).start();

    // Longe do fim: a extensão nem é oferecida.
    await tester.pump(const Duration(minutes: 10));
    expect(stateOf(container).canExtend, isFalse);
    viewModelOf(container).extendFocus();
    expect(stateOf(container).isExtended, isFalse);

    // Reta final: estende — e a segunda tentativa não faz nada.
    await tester.pump(const Duration(minutes: 11));
    expect(stateOf(container).canExtend, isTrue);
    viewModelOf(container).extendFocus();
    expect(stateOf(container).isExtended, isTrue);
    expect(stateOf(container).canExtend, isFalse);

    // Termina nos 30 minutos (25 + 5), e o histórico registra o total real.
    await tester.pump(const Duration(minutes: 9));
    expect(stateOf(container).isFinished, isTrue);
    expect(saved(tester).single.duration, const Duration(minutes: 30));
  });

  testWidgets('a serialização de notas sobrevive à ida e volta', (tester) async {
    const notes = [
      FocusSessionNote(minute: 0, text: 'começando'),
      FocusSessionNote(minute: 12, text: 'terminei a task | comecei outra'),
    ];

    final decoded =
        FocusSessionNote.decodeList(FocusSessionNote.encodeList(notes));

    expect(decoded, hasLength(2));
    expect(decoded[0].label, 'no início');
    expect(decoded[1].minute, 12);
    expect(decoded[1].text, 'terminei a task | comecei outra');
  });
}
