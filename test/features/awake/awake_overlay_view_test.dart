import 'package:evergreen/app/providers.dart';
import 'package:evergreen/core/design/app_theme.dart';
import 'package:evergreen/core/window/overlay_window.dart';
import 'package:evergreen/features/awake/models/awake_duration.dart';
import 'package:evergreen/features/awake/presentation/viewmodels/awake_view_model.dart';
import 'package:evergreen/features/awake/presentation/views/awake_overlay_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_sleep_assertion_service.dart';

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

  Future<ProviderContainer> pumpPanel(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sleepAssertionServiceProvider.overrideWithValue(sleep),
          awakeSessionRepositoryProvider.overrideWithValue(sessions),
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

    return ProviderScope.containerOf(
      tester.element(find.byType(AwakeOverlayView)),
    );
  }

  /// O Awake não tem campo de texto — quem segura o teclado é o próprio painel
  /// —, então o clique não tem como levar o foco embora. O teste existe para
  /// que o Esc do painel mais simples da suíte fique preso por um teste como o
  /// dos outros quatro, e não por herança de casca.
  testWidgets(
    'clicar no painel não emudece o Esc',
    (tester) async {
      OverlayWindow.instance.resetForTest();
      final closing = <String>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const channel = MethodChannel('previous_app_focus');
      messenger.setMockMethodCallHandler(channel, (call) async {
        closing.add(call.method);
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

      await pumpPanel(tester);

      await tester.tapAt(tester.getCenter(find.text('1:00:00')));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(closing, contains('beginHide'));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

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

    expect(sleep.isEnabled, isTrue);
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
