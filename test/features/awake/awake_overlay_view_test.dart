import 'package:evergreen/app/providers.dart';
import 'package:evergreen/core/design/app_theme.dart';
import 'package:evergreen/features/awake/models/awake_duration.dart';
import 'package:evergreen/features/awake/presentation/viewmodels/awake_view_model.dart';
import 'package:evergreen/features/awake/presentation/views/awake_overlay_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_display_sleep_service.dart';

void main() {
  late FakeDisplaySleepService display;
  late SharedPreferences preferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    display = FakeDisplaySleepService();
  });

  Future<ProviderContainer> pumpPanel(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          displaySleepServiceProvider.overrideWithValue(display),
          sharedPreferencesProvider.overrideWithValue(preferences),
          clockProvider.overrideWithValue(() => tester.binding.clock.now()),
        ],
        child: MaterialApp(
          theme: AppTheme.build(),
          home: const AwakeOverlayView(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    return ProviderScope.containerOf(tester.element(find.byType(AwakeOverlayView)));
  }

  testWidgets('desligado, o painel propõe a duração padrão', (tester) async {
    await pumpPanel(tester);

    expect(find.text('DESLIGADO'), findsOneWidget);
    // Uma hora é o padrão, e ele aparece como proposta antes de qualquer
    // clique — a mesma leitura da tela de partida do Focus.
    expect(find.text('1:00:00'), findsOneWidget);
    expect(find.text('Manter a tela acesa'), findsOneWidget);
    expect(find.text('Desligar'), findsNothing);
  });

  testWidgets('ligar aciona a trava e a tela passa a contar', (tester) async {
    final container = await pumpPanel(tester);

    await tester.tap(find.text('30 min'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manter a tela acesa'));
    await tester.pumpAndSettle();

    expect(display.isEnabled, isTrue);
    expect(find.text('MANTENDO A TELA ACESA'), findsOneWidget);
    expect(find.text('Desligar'), findsOneWidget);

    await tester.pump(const Duration(minutes: 1));
    expect(find.text('29:00'), findsOneWidget);

    // O rodapé anuncia o que o Enter faz agora, e não o que ele fazia.
    expect(find.text('desligar'), findsOneWidget);

    await container.read(awakeViewModelProvider.notifier).turnOff();
    await tester.pumpAndSettle();
  });

  testWidgets('sempre troca a contagem pelo infinito', (tester) async {
    final container = await pumpPanel(tester);

    await tester.tap(find.text('Sempre'));
    await tester.pumpAndSettle();

    expect(
      container.read(awakeViewModelProvider).duration,
      AwakeDuration.indefinite,
    );
    expect(find.text('∞'), findsOneWidget);
  });
}
