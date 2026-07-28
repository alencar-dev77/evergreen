import 'package:evergreen/app/providers.dart';
import 'package:evergreen/core/design/app_theme.dart';
import 'package:evergreen/features/home/models/evergreen_module.dart';
import 'package:evergreen/features/home/presentation/views/hub_view.dart';
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
    tester.view.physicalSize = const Size(900, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          clipboardRepositoryProvider
              .overrideWithValue(FakeClipboardRepository([])),
          focusSessionRepositoryProvider
              .overrideWithValue(FakeFocusSessionRepository()),
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
        child: MaterialApp(theme: AppTheme.build(), home: const HubView()),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// A tela de um módulo curto (o Awake) tem menos conteúdo que a janela, e a
  /// área de detalhe rola: sem esticar a linha do Hub, ela encolhia até a altura
  /// do conteúdo e o `Row` a centralizava verticalmente — o módulo abria com o
  /// texto no meio da tela enquanto Pin e Focus abriam no topo.
  testWidgets('toda tela do Hub começa no topo, cheia ou vazia',
      (tester) async {
    await pumpHub(tester);

    double topOf(EvergreenModule module) {
      // `.last` porque o nome do módulo aparece duas vezes: na barra lateral e
      // no cabeçalho da tela.
      return tester.getTopLeft(find.text(module.name).last).dy;
    }

    final expected = topOf(EvergreenModule.pin);

    for (final module in EvergreenModule.values) {
      await tester.tap(find.text(module.name).first);
      await tester.pumpAndSettle();

      expect(
        topOf(module),
        expected,
        reason: 'o cabeçalho de ${module.name} não começa na mesma altura',
      );
    }
  });
}
