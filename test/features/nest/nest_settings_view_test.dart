import 'package:evergreen/app/providers.dart';
import 'package:evergreen/core/design/app_theme.dart';
import 'package:evergreen/features/nest/models/nest_destination.dart';
import 'package:evergreen/features/nest/models/nest_settings.dart';
import 'package:evergreen/features/nest/models/nest_transfer_mode.dart';
import 'package:evergreen/features/nest/presentation/viewmodels/nest_settings_view_model.dart';
import 'package:evergreen/features/nest/presentation/views/nest_settings_view.dart';
import 'package:evergreen/shared/widgets/eg_text_field.dart';
import 'package:evergreen/shared/widgets/eg_toggle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_nest_channel.dart';

void main() {
  late SharedPreferences preferences;
  late FakeNestChannel channel;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    channel = FakeNestChannel();
  });

  tearDown(() => channel.dispose());

  Future<ProviderContainer> pumpSettings(
    WidgetTester tester, {
    NestSettings? settings,
  }) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final overrides = [
      sharedPreferencesProvider.overrideWithValue(preferences),
      nestChannelProvider.overrideWithValue(channel),
    ];

    if (settings != null) {
      final setup = ProviderContainer(overrides: overrides);
      await setup.read(nestSettingsRepositoryProvider).save(settings);
      setup.dispose();
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          theme: AppTheme.build(),
          home: const Scaffold(
            body: SingleChildScrollView(child: NestSettingsView()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    return ProviderScope.containerOf(
      tester.element(find.byType(NestSettingsView)),
    );
  }

  testWidgets('num Mac sem recorte, a linha do notch não aparece', (
    tester,
  ) async {
    await pumpSettings(tester);

    expect(
      find.text('Receber arquivos pelo recorte da tela'),
      findsNothing,
    );
  });

  testWidgets('com recorte, ela aparece e liga o lado nativo', (tester) async {
    channel.notch = true;
    await pumpSettings(tester);

    expect(find.text('Receber arquivos pelo recorte da tela'), findsOneWidget);

    await tester.tap(find.byType(EgToggle));
    await tester.pumpAndSettle();

    expect(channel.isNotchEnabled, isFalse);
  });

  testWidgets('a escolha entre copiar e mover é escrita na hora', (
    tester,
  ) async {
    final container = await pumpSettings(tester);

    await tester.tap(find.text('Mover'));
    await tester.pumpAndSettle();

    expect(
      container.read(nestSettingsViewModelProvider).defaultMode,
      NestTransferMode.move,
    );
    expect(
      container.read(nestSettingsRepositoryProvider).load().defaultMode,
      NestTransferMode.move,
    );
  });

  testWidgets('sem pasta nenhuma, a tela explica para que servem', (
    tester,
  ) async {
    await pumpSettings(tester);

    expect(find.textContaining('Sem nenhuma pasta aqui'), findsOneWidget);
  });

  testWidgets('adicionar guarda o que o seletor do sistema devolveu', (
    tester,
  ) async {
    channel.folderToChoose = '/Users/eu/Recibos';
    final container = await pumpSettings(tester);

    await tester.tap(find.text('Adicionar pasta…'));
    await tester.pumpAndSettle();

    expect(
      container.read(nestSettingsViewModelProvider).destinations.single.path,
      '/Users/eu/Recibos',
    );
    // O nome da pasta é o rótulo enquanto ninguém der um apelido a ela.
    expect(find.text('Recibos'), findsOneWidget);
  });

  testWidgets('cancelar o seletor não acrescenta nada', (tester) async {
    final container = await pumpSettings(tester);

    await tester.tap(find.text('Adicionar pasta…'));
    await tester.pumpAndSettle();

    expect(container.read(nestSettingsViewModelProvider).destinations, isEmpty);
  });

  testWidgets('a mesma pasta duas vezes não vira duas linhas', (tester) async {
    channel.folderToChoose = '/Users/eu/Recibos';
    final container = await pumpSettings(tester);

    await tester.tap(find.text('Adicionar pasta…'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Adicionar pasta…'));
    await tester.pumpAndSettle();

    expect(
      container.read(nestSettingsViewModelProvider).destinations,
      hasLength(1),
    );
  });

  testWidgets('o apelido é guardado ao sair do campo', (tester) async {
    final container = await pumpSettings(
      tester,
      settings: NestSettings(
        destinations: [const NestDestination(path: '/Users/eu/Recibos')],
      ),
    );

    await tester.enterText(find.byType(EgTextField), 'Notas fiscais');
    // Tirar o foco do campo é o que guarda — a convenção do apelido do Pin e do
    // cartão do Leaf.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    expect(
      container.read(nestSettingsViewModelProvider).destinations.single.alias,
      'Notas fiscais',
    );
  });

  testWidgets('a lista cheia desabilita o botão e diz por quê', (tester) async {
    await pumpSettings(
      tester,
      settings: NestSettings(
        destinations: [
          for (var index = 0; index < NestSettings.maxDestinations; index++)
            NestDestination(path: '/Users/eu/pasta$index'),
        ],
      ),
    );

    expect(find.textContaining('pastas no máximo'), findsOneWidget);
  });
}
