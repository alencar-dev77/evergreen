import 'package:evergreen/app/providers.dart';
import 'package:evergreen/core/design/app_theme.dart';
import 'package:evergreen/features/home/models/evergreen_module.dart';
import 'package:evergreen/features/home/presentation/views/app_settings_view.dart';
import 'package:evergreen/features/home/presentation/views/hub_view.dart';
import 'package:evergreen/features/pin/presentation/views/pin_settings_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../focus/fake_focus_session_repository.dart';
import '../pin/fake_clipboard_repository.dart';

void main() {
  late SharedPreferences preferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
  });

  Future<void> pumpHub(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1800, 1400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          clipboardRepositoryProvider.overrideWithValue(
            FakeClipboardRepository(),
          ),
          focusSessionRepositoryProvider.overrideWithValue(
            FakeFocusSessionRepository(),
          ),
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
        child: MaterialApp(theme: AppTheme.build(), home: const HubView()),
      ),
    );

    await tester.pumpAndSettle();
  }

  testWidgets('a marca da barra lateral abre as preferências do aplicativo',
      (tester) async {
    await pumpHub(tester);

    // O Hub abre no Pin, e o que é do aplicativo não mora mais lá.
    expect(find.byType(PinSettingsView), findsOneWidget);
    expect(find.text('Iniciar com o macOS'), findsNothing);

    await tester.tap(find.text('Preferências do aplicativo'));
    await tester.pumpAndSettle();

    expect(find.byType(AppSettingsView), findsOneWidget);
    expect(find.text('Iniciar com o macOS'), findsOneWidget);
    expect(find.text('Abrir minimizado'), findsOneWidget);
    // O atalho que abre esta janela finalmente tem onde ser ensinado.
    expect(find.text('Abrir preferências'), findsOneWidget);
    expect(find.textContaining('Evergreen v'), findsOneWidget);
  });

  testWidgets('voltar para um módulo troca o painel', (tester) async {
    await pumpHub(tester);

    await tester.tap(find.text('Preferências do aplicativo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(EvergreenModule.pin.name));
    await tester.pumpAndSettle();

    expect(find.byType(AppSettingsView), findsNothing);
    expect(find.byType(PinSettingsView), findsOneWidget);
  });
}
