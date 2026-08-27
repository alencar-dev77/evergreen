import 'package:evergreen/app/providers.dart';
import 'package:evergreen/features/awake/models/awake_duration.dart';
import 'package:evergreen/features/awake/models/awake_mode.dart';
import 'package:evergreen/features/awake/presentation/viewmodels/awake_state.dart';
import 'package:evergreen/features/awake/presentation/viewmodels/awake_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_sleep_assertion_service.dart';

/// Pelo mesmo motivo do cronômetro do Focus, tudo roda dentro de `testWidgets`:
/// só ali o relógio é falso, e é o que permite verificar um prazo de duas horas
/// sem esperar duas horas.
void main() {
  late FakeSleepAssertionService sleep;
  late FakeAwakeSessionRepository sessions;
  late SharedPreferences preferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    sleep = FakeSleepAssertionService();
    sessions = FakeAwakeSessionRepository();
  });

  ProviderContainer containerFor(WidgetTester tester) {
    final container = ProviderContainer(
      overrides: [
        sleepAssertionServiceProvider.overrideWithValue(sleep),
        awakeSessionRepositoryProvider.overrideWithValue(sessions),
        sharedPreferencesProvider.overrideWithValue(preferences),
        clockProvider.overrideWithValue(() => tester.binding.clock.now()),
      ],
    );

    addTearDown(container.dispose);
    return container;
  }

  AwakeState stateOf(ProviderContainer container) =>
      container.read(awakeViewModelProvider);

  AwakeViewModel viewModelOf(ProviderContainer container) =>
      container.read(awakeViewModelProvider.notifier);

  testWidgets('ligar aciona a trava e começa a contagem', (tester) async {
    final container = containerFor(tester);

    await viewModelOf(container).selectDuration(AwakeDuration.minutes30);
    await viewModelOf(container).turnOn();

    expect(sleep.isEnabled, isTrue);
    expect(stateOf(container).isOn, isTrue);
    expect(stateOf(container).remaining, const Duration(minutes: 30));

    await tester.pump(const Duration(minutes: 10));

    expect(stateOf(container).remaining, const Duration(minutes: 20));
    expect(stateOf(container).display, '20:00');

    // Toda trava com prazo é desligada antes do fim do teste: o ticker é um
    // `Timer.periodic` de verdade, e o binding acusa qualquer um que sobreviva
    // ao teste que o criou.
    await viewModelOf(container).turnOff();
  });

  testWidgets('o prazo vencido solta a trava sozinho', (tester) async {
    final container = containerFor(tester);

    await viewModelOf(container).selectDuration(AwakeDuration.minutes30);
    await viewModelOf(container).turnOn();

    await tester.pump(const Duration(minutes: 30));

    expect(sleep.isEnabled, isFalse);
    expect(stateOf(container).isOn, isFalse);
    expect(stateOf(container).remaining, isNull);
  });

  testWidgets('sem limite não tem contagem nem fim', (tester) async {
    final container = containerFor(tester);

    await viewModelOf(container).selectDuration(AwakeDuration.indefinite);
    await viewModelOf(container).turnOn();

    await tester.pump(const Duration(hours: 6));

    expect(sleep.isEnabled, isTrue);
    expect(stateOf(container).remaining, isNull);
    expect(stateOf(container).display, '∞');
  });

  testWidgets('trocar a duração com a trava ligada conta o prazo novo do zero',
      (tester) async {
    final container = containerFor(tester);

    await viewModelOf(container).selectDuration(AwakeDuration.minutes30);
    await viewModelOf(container).turnOn();
    await tester.pump(const Duration(minutes: 25));

    await viewModelOf(container).selectDuration(AwakeDuration.hours2);

    // Duas horas cheias, e não o que sobrava da meia hora: quem escolhe "2 h"
    // no meio do caminho está pedindo mais duas horas.
    expect(stateOf(container).remaining, const Duration(hours: 2));
    expect(stateOf(container).display, '2:00:00');
    // E a trava nunca chegou a ser solta no meio da troca.
    expect(sleep.enableCount, 1);
    expect(sleep.isEnabled, isTrue);

    await viewModelOf(container).turnOff();
  });

  testWidgets('a trava segue o modo escolhido nas preferências',
      (tester) async {
    SharedPreferences.setMockInitialValues({'flutter.awake.mode': 'system'});
    preferences = await SharedPreferences.getInstance();
    final container = containerFor(tester);

    await viewModelOf(container).turnOn();

    // Com a tela fora da conta, o que a trava segura é o sistema: é o caso do
    // build da madrugada, em que manter a tela acesa a noite inteira resolveria
    // um problema que não é dela.
    expect(sleep.mode, AwakeMode.system);
    expect(stateOf(container).statusLabel, 'Mantendo o sistema acordado');

    await viewModelOf(container).turnOff();
  });

  testWidgets('o modo em curso não muda por baixo de uma trava ligada',
      (tester) async {
    final container = containerFor(tester);
    await viewModelOf(container).turnOn();
    expect(sleep.mode, AwakeMode.screen);

    // A preferência trocou no Hub, que roda em outro engine, e o painel foi
    // reaberto: o que já está valendo continua valendo.
    await preferences.setString('flutter.awake.mode', 'system');
    await viewModelOf(container).prepareForOpen();

    expect(stateOf(container).mode, AwakeMode.screen);
    expect(sleep.mode, AwakeMode.screen);

    await viewModelOf(container).turnOff();
  });

  testWidgets('o período fica no histórico quando a trava se solta',
      (tester) async {
    final container = containerFor(tester);

    await viewModelOf(container).selectDuration(AwakeDuration.minutes30);
    await viewModelOf(container).turnOn();
    final startedAt = tester.binding.clock.now();

    await tester.pump(const Duration(minutes: 12));
    await viewModelOf(container).turnOff();

    // É a única linha que o Awake grava, e ela existe para o Track: sem ela o
    // módulo não aparecia no dia reconstruído.
    final session = sessions.sessions.single;
    expect(session.startedAt, startedAt);
    expect(session.duration, const Duration(minutes: 12));
    expect(session.mode, AwakeMode.screen);
    expect(session.label, 'Tela acesa');
  });

  testWidgets('o prazo vencido também registra o período', (tester) async {
    final container = containerFor(tester);

    await viewModelOf(container).selectDuration(AwakeDuration.minutes30);
    await viewModelOf(container).turnOn();
    await tester.pump(const Duration(minutes: 30));

    expect(sessions.sessions.single.duration, const Duration(minutes: 30));
  });

  testWidgets('ligar e desligar em segundos não vira registro',
      (tester) async {
    final container = containerFor(tester);

    await viewModelOf(container).turnOn();
    await tester.pump(const Duration(seconds: 20));
    await viewModelOf(container).turnOff();

    // Uma linha de vinte segundos no dia reconstruído só atrapalha a leitura —
    // mesmo limiar do Focus, pela mesma razão.
    expect(sessions.sessions, isEmpty);
  });

  testWidgets('desligar solta a trava e para a contagem', (tester) async {
    final container = containerFor(tester);

    await viewModelOf(container).selectDuration(AwakeDuration.hour1);
    await viewModelOf(container).turnOn();
    await viewModelOf(container).turnOff();

    expect(sleep.isEnabled, isFalse);
    expect(stateOf(container).isOn, isFalse);

    // Sem ticker vivo: o estado não se mexe mais sozinho.
    await tester.pump(const Duration(hours: 2));
    expect(stateOf(container).isOn, isFalse);
  });

  testWidgets('a barra de menus só conta os minutos que faltam', (tester) async {
    final container = containerFor(tester);

    expect(stateOf(container).menuBarDetail, isNull);

    await viewModelOf(container).selectDuration(AwakeDuration.hour1);
    await viewModelOf(container).turnOn();
    await tester.pump(const Duration(minutes: 22));

    expect(stateOf(container).menuBarDetail, '38 min');

    await viewModelOf(container).selectDuration(AwakeDuration.indefinite);
    expect(stateOf(container).menuBarDetail, 'sem limite');
  });

  testWidgets('a duração padrão vem das preferências e não atropela a trava',
      (tester) async {
    SharedPreferences.setMockInitialValues({'awake.default_duration': 'hours2'});
    preferences = await SharedPreferences.getInstance();

    final container = containerFor(tester);
    await viewModelOf(container).prepareForOpen();

    expect(stateOf(container).duration, AwakeDuration.hours2);

    await viewModelOf(container).selectDuration(AwakeDuration.minutes30);
    await viewModelOf(container).turnOn();

    // Reabrir o painel com a trava ligada mantém o prazo em curso — reler as
    // preferências aqui trocaria a duração debaixo de quem já ligou.
    await viewModelOf(container).prepareForOpen();

    expect(stateOf(container).duration, AwakeDuration.minutes30);
    expect(stateOf(container).isOn, isTrue);

    await viewModelOf(container).turnOff();
  });
}
