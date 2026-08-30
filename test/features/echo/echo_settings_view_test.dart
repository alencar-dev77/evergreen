import 'package:evergreen/app/providers.dart';
import 'package:evergreen/core/design/app_theme.dart';
import 'package:evergreen/core/storage/app_database.dart';
import 'package:evergreen/features/echo/data/echo_repository.dart';
import 'package:evergreen/features/echo/models/echo_settings.dart';
import 'package:evergreen/features/echo/models/transcription_language.dart';
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

  Future<ProviderContainer> pumpSettings(
    WidgetTester tester, {
    FakeEchoChannel? channel,
  }) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          echoRepositoryProvider.overrideWithValue(SqliteEchoRepository(db)),
          echoChannelProvider.overrideWithValue(channel ?? FakeEchoChannel()),
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

  /// A tela tem mais de um campo de texto: o do resumo e o do vocabulário.
  /// Achar pelo tipo pegaria os dois, e um teste que depende da ordem em que
  /// eles aparecem quebra na primeira vez que a tela for reorganizada.
  Finder fieldWithHint(String hint) => find.byWidgetPredicate(
    (widget) => widget is EgTextField && widget.hintText == hint,
  );

  testWidgets('a instrução do resumo tem altura de várias linhas', (
    tester,
  ) async {
    await pumpSettings(tester);

    final field = tester.widget<EgTextField>(
      fieldWithHint(EchoSettings.defaultInstructionsHint),
    );

    // Um campo de uma linha para um texto de três pede uma palavra sem querer.
    expect(field.minLines, 3);
    expect(field.maxLines, greaterThan(3));
  });

  testWidgets('a instrução mostra o padrão apagado enquanto está vazia', (
    tester,
  ) async {
    await pumpSettings(tester);

    final field = tester.widget<EgTextField>(
      fieldWithHint(EchoSettings.defaultInstructionsHint),
    );

    // Campo vazio não vira instrução vazia: o app usa a dele, e a pessoa
    // precisa ver o que acontece se não escrever nada.
    expect(field.hintText, EchoSettings.defaultInstructionsHint);
    expect(field.controller.text, isEmpty);
  });

  testWidgets('sair do campo guarda o que foi escrito', (tester) async {
    final container = await pumpSettings(tester);

    await tester.enterText(
      fieldWithHint(EchoSettings.defaultInstructionsHint),
      'Só os itens de ação.',
    );
    // Tirar o foco é o que confirma — não há Enter para submeter num campo de
    // várias linhas, e a mesma regra vale para o apelido do Pin.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    expect(
      container.read(echoSettingsViewModelProvider).summaryInstructions,
      'Só os itens de ação.',
    );
  });

  testWidgets('o vocabulário guarda ao sair do campo, como a instrução', (
    tester,
  ) async {
    final container = await pumpSettings(tester);

    await tester.enterText(
      fieldWithHint(EchoSettings.vocabularyHint),
      'Riverpod\nDiletta',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    expect(
      container.read(echoSettingsViewModelProvider).vocabulary,
      'Riverpod\nDiletta',
    );
  });

  testWidgets('idioma sem modelo nesta máquina aparece como aviso na tela', (
    tester,
  ) async {
    // O sistema atende inglês e não atende o português escolhido: é o caso que
    // fazia a transcrição sair cheia de palavra trocada sem nada explicar.
    final channel = FakeEchoChannel()
      ..resolvedLocales = const {'en-US': 'en-US'};

    await pumpSettings(tester, channel: channel);

    expect(
      find.textContaining('não tem modelo para'),
      findsOneWidget,
    );
  });

  testWidgets('sem resposta do sistema, a tela não acusa falta de idioma', (
    tester,
  ) async {
    // Mapa vazio é "não deu para perguntar" — em máquina sem o lado nativo,
    // avisar seria inventar um problema.
    await pumpSettings(tester);

    expect(find.textContaining('não tem modelo para'), findsNothing);
  });

  testWidgets('variante atendida por outro modelo é dita, não escondida', (
    tester,
  ) async {
    final channel = FakeEchoChannel()
      ..resolvedLocales = const {'pt-BR': 'pt-BR', 'pt-PT': 'pt-BR'};

    await pumpSettings(tester, channel: channel);

    // O padrão é PT-BR, atendido por ele mesmo: nada a dizer.
    expect(find.textContaining('atende'), findsNothing);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(EchoSettingsView)),
    );
    container
        .read(echoSettingsViewModelProvider.notifier)
        .setLanguage(TranscriptionLanguage.ptPT);
    await tester.pumpAndSettle();

    expect(find.textContaining('atende Português (Portugal)'), findsOneWidget);
  });
}
