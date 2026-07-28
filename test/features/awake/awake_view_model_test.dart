import 'package:evergreen/app/providers.dart';
import 'package:evergreen/features/awake/models/awake_duration.dart';
import 'package:evergreen/features/awake/presentation/viewmodels/awake_state.dart';
import 'package:evergreen/features/awake/presentation/viewmodels/awake_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_display_sleep_service.dart';

/// Pelo mesmo motivo do cronômetro do Focus, tudo roda dentro de `testWidgets`:
/// só ali o relógio é falso, e é o que permite verificar um prazo de duas horas
/// sem esperar duas horas.
void main() {
  late FakeDisplaySleepService display;
  late SharedPreferences preferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    display = FakeDisplaySleepService();
  });

  ProviderContainer containerFor(WidgetTester tester) {
    final container = ProviderContainer(
      overrides: [
        displaySleepServiceProvider.overrideWithValue(display),
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

    expect(display.isEnabled, isTrue);
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

    expect(display.isEnabled, isFalse);
    expect(stateOf(container).isOn, isFalse);
    expect(stateOf(container).remaining, isNull);
  });

  testWidgets('sem limite não tem contagem nem fim', (tester) async {
    final container = containerFor(tester);

    await viewModelOf(container).selectDuration(AwakeDuration.indefinite);
    await viewModelOf(container).turnOn();

    await tester.pump(const Duration(hours: 6));

    expect(display.isEnabled, isTrue);
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
    expect(display.enableCount, 1);
    expect(display.isEnabled, isTrue);

    await viewModelOf(container).turnOff();
  });

  testWidgets('desligar solta a trava e para a contagem', (tester) async {
    final container = containerFor(tester);

    await viewModelOf(container).selectDuration(AwakeDuration.hour1);
    await viewModelOf(container).turnOn();
    await viewModelOf(container).turnOff();

    expect(display.isEnabled, isFalse);
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
