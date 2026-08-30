import 'package:evergreen/app/providers.dart';
import 'package:evergreen/core/design/app_theme.dart';
import 'package:evergreen/features/pin/models/clipboard_item.dart';
import 'package:evergreen/features/pin/presentation/views/pin_settings_view.dart';
import 'package:evergreen/shared/widgets/eg_confirm_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_clipboard_repository.dart';

void main() {
  late FakeClipboardRepository repository;
  late SharedPreferences preferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();

    repository = FakeClipboardRepository([
      ClipboardItem.capture('fixado').copyWith(id: 1, isPinned: true),
      ClipboardItem.capture('recente').copyWith(id: 2),
    ]);
  });

  Future<void> pumpSettings(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          clipboardRepositoryProvider.overrideWithValue(repository),
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
        child: MaterialApp(
          theme: AppTheme.build(),
          home: const Scaffold(
            body: SingleChildScrollView(child: PinSettingsView()),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  testWidgets('limpar histórico pede confirmação antes de apagar', (
    tester,
  ) async {
    await pumpSettings(tester);

    await tester.tap(find.text('Apagar'));
    await tester.pumpAndSettle();

    expect(find.byType(EgConfirmDialog), findsOneWidget);
    // Nada foi apagado só por abrir o diálogo.
    expect(repository.loadAll(), hasLength(2));

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(find.byType(EgConfirmDialog), findsNothing);
    expect(repository.loadAll(), hasLength(2));
  });

  testWidgets('confirmar remove os não fixados e preserva os fixados', (
    tester,
  ) async {
    await pumpSettings(tester);

    await tester.tap(find.text('Apagar'));
    await tester.pumpAndSettle();

    // O rótulo "Limpar" existe no botão da linha e no diálogo; o do diálogo é o
    // último a entrar na árvore.
    await tester.tap(find.text('Apagar').last);
    await tester.pumpAndSettle();

    expect(find.byType(EgConfirmDialog), findsNothing);
    expect(repository.loadAll().map((item) => item.content), ['fixado']);
  });
}
