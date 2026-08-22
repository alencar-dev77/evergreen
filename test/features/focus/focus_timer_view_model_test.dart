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

  /// Os dois jeitos que o cronômetro tinha de mentir sobre o tempo focado.
  ///
  /// Os dois vinham da mesma raiz: a sessão só se reconciliava com o banco no
  /// fim, e a duração registrada era `total - restante` — o que o **relógio**
  /// andou, não o que o cronômetro correu.
  group('o tempo registrado é o tempo que o cronômetro correu', () {
    /// Container com um relógio que pode dar um salto sem que os tiques
    /// aconteçam — que é exatamente o que o Mac dormindo faz com o processo.
    ///
    /// O `pump` do teste não serve para isso sozinho: ele adianta o relógio
    /// falso executando **todos** os tiques do caminho, como uma máquina
    /// acordada. O desvio é o que separa "o tempo passou" de "o tempo passou e
    /// alguém estava lá".
    ({ProviderContainer container, void Function(Duration) skip}) suspendable(
      WidgetTester tester,
    ) {
      var skew = Duration.zero;

      final container = ProviderContainer(
        overrides: [
          focusSessionRepositoryProvider.overrideWithValue(repository),
          sharedPreferencesProvider.overrideWithValue(preferences),
          clockProvider
              .overrideWithValue(() => tester.binding.clock.now().add(skew)),
        ],
      );
      addTearDown(container.dispose);

      return (container: container, skip: (gap) => skew += gap);
    }

    testWidgets('o Mac dormindo não conta como foco', (tester) async {
      final (:container, :skip) = suspendable(tester);
      viewModelOf(container).start(activity: 'Revisar a PR');

      await tester.pump(const Duration(minutes: 3));
      // O Mac dorme por duas horas: nenhum tique acontece, e quando ele acorda
      // o prazo da sessão já venceu há muito.
      skip(const Duration(hours: 2));
      await tester.pump(const Duration(milliseconds: 250));

      final state = stateOf(container);
      expect(state.isFinished, isTrue);
      // Três minutos foram focados; os outros vinte e dois passaram no relógio.
      expect(state.focused, const Duration(minutes: 3));
      expect(saved(tester).single.duration, const Duration(minutes: 3));
    });

    testWidgets('um tique atrasado não descarta o trabalho real',
        (tester) async {
      final (:container, :skip) = suspendable(tester);
      viewModelOf(container).start();

      await tester.pump(const Duration(minutes: 3));
      // Meio minuto sem tique nenhum com a pessoa trabalhando: é o App Nap
      // atrasando o timer de um aplicativo sem janela à vista, não um cochilo.
      // Um limiar curto jogaria esses trinta segundos fora em silêncio.
      skip(const Duration(seconds: 30));
      await tester.pump(const Duration(milliseconds: 250));

      viewModelOf(container).stop();

      expect(
        saved(tester).single.duration,
        greaterThanOrEqualTo(const Duration(minutes: 3, seconds: 30)),
      );
    });

    testWidgets('a pausa não entra na conta', (tester) async {
      final container = containerFor(tester);
      viewModelOf(container).start();

      await tester.pump(const Duration(minutes: 4));
      viewModelOf(container).pause();
      await tester.pump(const Duration(minutes: 30));
      viewModelOf(container).resume();
      await tester.pump(const Duration(minutes: 2));
      viewModelOf(container).stop();

      expect(saved(tester).single.duration, const Duration(minutes: 6));
    });
  });

  /// A sessão vive na memória do engine, e o que está na memória morre com o
  /// aplicativo. O rastro (`FocusRun`) é o que sobrevive.
  group('a sessão sobrevive ao fechamento do aplicativo', () {
    testWidgets('o tempo focado até a morte do app entra no histórico',
        (tester) async {
      final container = containerFor(tester);
      viewModelOf(container).start(activity: 'Escrever o handoff');
      viewModelOf(container).addNote('comecei pelo diagrama');

      await tester.pump(const Duration(minutes: 12));

      // O aplicativo morre no meio da sessão: nada de stop, nada de dismiss.
      container.dispose();

      // A abertura seguinte, com as mesmas preferências no disco.
      final next = containerFor(tester);
      await viewModelOf(next).recoverInterruptedSession();

      final recovered = saved(tester).single;
      expect(recovered.duration, const Duration(minutes: 12));
      expect(recovered.activity, 'Escrever o handoff');
      expect(recovered.notes.single.text, 'comecei pelo diagrama');
    });

    testWidgets('o batimento é o que se perde, e é pouco', (tester) async {
      final container = containerFor(tester);
      viewModelOf(container).start();

      // 80 segundos: o último batimento foi aos 75, e o seguinte só viria aos
      // 90. O pior caso é perder um batimento inteiro, e é ele que precisa
      // continuar sendo aceitável.
      await tester.pump(const Duration(seconds: 80));
      container.dispose();

      final next = containerFor(tester);
      await viewModelOf(next).recoverInterruptedSession();

      expect(saved(tester).single.duration, const Duration(seconds: 75));
    });

    testWidgets('sessão terminada normalmente não é registrada duas vezes',
        (tester) async {
      final container = containerFor(tester);
      viewModelOf(container).start();

      await tester.pump(const Duration(minutes: 25));
      expect(saved(tester), hasLength(1));

      container.dispose();

      final next = containerFor(tester);
      await viewModelOf(next).recoverInterruptedSession();

      // O rastro foi apagado no fim: a abertura seguinte não tem o que
      // recuperar, e a sessão continua sendo uma só.
      expect(saved(tester), hasLength(1));
    });

    testWidgets('sessão curta demais também não é recuperada', (tester) async {
      final container = containerFor(tester);
      viewModelOf(container).start();

      await tester.pump(const Duration(seconds: 40));
      container.dispose();

      final next = containerFor(tester);
      await viewModelOf(next).recoverInterruptedSession();

      expect(saved(tester), isEmpty);
    });
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
