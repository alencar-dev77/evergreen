import 'package:evergreen/app/providers.dart';
import 'package:evergreen/core/design/app_theme.dart';
import 'package:evergreen/core/storage/app_database.dart';
import 'package:evergreen/features/echo/data/echo_repository.dart';
import 'package:evergreen/features/echo/models/echo_settings.dart';
import 'package:evergreen/features/echo/presentation/viewmodels/echo_settings_view_model.dart';
import 'package:evergreen/features/echo/presentation/views/echo_settings_view.dart';
import 'package:evergreen/shared/widgets/eg_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';

import 'fake_echo_channel.dart';

void main() {
  late SharedPreferences preferences;
  late Database db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();

    db = sqlite3.openInMemory();
    AppDatabase.migrate(db);
  });

  tearDown(() => db.close());

  Future<ProviderContainer> pumpSettings(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          echoRepositoryProvider.overrideWithValue(SqliteEchoRepository(db)),
          echoChannelProvider.overrideWithValue(FakeEchoChannel()),
        ],
        child: MaterialApp(
          theme: AppTheme.build(),
          home: const Scaffold(
            body: SingleChildScrollView(child: EchoSettingsView()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    return ProviderScope.containerOf(
      tester.element(find.byType(EchoSettingsView)),
    );
  }

  testWidgets('a instrução do resumo tem altura de várias linhas', (tester) async {
    await pumpSettings(tester);

    final field = tester.widget<EgTextField>(find.byType(EgTextField));

    // Um campo de uma linha para um texto de três pede uma palavra sem querer.
    expect(field.minLines, 3);
    expect(field.maxLines, greaterThan(3));
  });

  testWidgets('a instrução mostra o padrão apagado enquanto está vazia',
      (tester) async {
    await pumpSettings(tester);

    final field = tester.widget<EgTextField>(find.byType(EgTextField));

    // Campo vazio não vira instrução vazia: o app usa a dele, e a pessoa
    // precisa ver o que acontece se não escrever nada.
    expect(field.hintText, EchoSettings.defaultInstructionsHint);
    expect(field.controller.text, isEmpty);
  });

  testWidgets('sair do campo guarda o que foi escrito', (tester) async {
    final container = await pumpSettings(tester);

    await tester.enterText(find.byType(EgTextField), 'Só os itens de ação.');
    // Tirar o foco é o que confirma — não há Enter para submeter num campo de
    // várias linhas, e a mesma regra vale para o apelido do Pin.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    expect(
      container.read(echoSettingsViewModelProvider).summaryInstructions,
      'Só os itens de ação.',
    );
  });
}
