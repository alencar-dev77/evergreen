import 'package:evergreen/app/providers.dart';
import 'package:evergreen/core/design/app_theme.dart';
import 'package:evergreen/core/system/global_shortcut_slot.dart';
import 'package:evergreen/features/home/data/module_settings_repository.dart';
import 'package:evergreen/features/home/presentation/widgets/global_shortcut_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_module_settings_notifier.dart';

void main() {
  late SharedPreferences preferences;
  late FakeModuleSettingsNotifier notifier;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    notifier = FakeModuleSettingsNotifier();
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          moduleSettingsNotifierProvider.overrideWithValue(notifier),
        ],
        child: MaterialApp(
          theme: AppTheme.build(),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: GlobalShortcutSection(slot: GlobalShortcutSlot.pin),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  /// Segura as modificadoras, aperta a tecla e solta tudo — na ordem em que uma
  /// pessoa faria.
  Future<void> press(
    WidgetTester tester,
    LogicalKeyboardKey key, {
    List<LogicalKeyboardKey> modifiers = const [],
  }) async {
    for (final modifier in modifiers) {
      await tester.sendKeyDownEvent(modifier);
    }
    await tester.sendKeyDownEvent(key);
    await tester.sendKeyUpEvent(key);
    for (final modifier in modifiers.reversed) {
      await tester.sendKeyUpEvent(modifier);
    }
    await tester.pumpAndSettle();
  }

  Future<void> startRecording(WidgetTester tester) async {
    await tester.tap(find.text('Alterar'));
    await tester.pumpAndSettle();
  }

  testWidgets('em repouso mostra a combinação em vigor e o botão de trocar', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('C'), findsOneWidget);
    expect(find.text('Alterar'), findsOneWidget);
    // Sem nada gravado, não há para onde restaurar.
    expect(find.text('Restaurar'), findsNothing);
  });

  testWidgets('a combinação apertada vira o atalho, no estado e no disco', (
    tester,
  ) async {
    await pump(tester);
    await startRecording(tester);

    expect(find.text('Aperte a combinação'), findsOneWidget);

    await press(
      tester,
      LogicalKeyboardKey.keyG,
      modifiers: [LogicalKeyboardKey.metaLeft, LogicalKeyboardKey.altLeft],
    );

    expect(find.text('Aperte a combinação'), findsNothing);
    expect(
      ModuleSettingsRepository(preferences)
          .load()
          .bindingFor(GlobalShortcutSlot.pin)
          .compact,
      '⌘⌥G',
    );
    // E a linha de restaurar aparece, porque agora há um padrão a que voltar.
    expect(find.text('Restaurar'), findsOneWidget);
  });

  testWidgets('segurar só a modificadora não termina a gravação', (
    tester,
  ) async {
    await pump(tester);
    await startRecording(tester);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.pumpAndSettle();

    // A pessoa está no meio do gesto: o ⌘ sozinho não é combinação nenhuma.
    expect(find.text('Aperte a combinação'), findsOneWidget);

    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pumpAndSettle();
    expect(preferences.getKeys(), isEmpty);
  });

  testWidgets('uma combinação recusada explica o motivo e continua à escuta', (
    tester,
  ) async {
    await pump(tester);
    await startRecording(tester);

    // Uma modificadora só: é onde mora o ⌘C.
    await press(
      tester,
      LogicalKeyboardKey.keyG,
      modifiers: [LogicalKeyboardKey.metaLeft],
    );

    expect(find.textContaining('duas modificadoras'), findsOneWidget);
    expect(find.text('Aperte a combinação'), findsOneWidget);
    expect(preferences.getKeys(), isEmpty);

    // E a tentativa seguinte funciona, sem precisar apertar "Alterar" de novo.
    await press(
      tester,
      LogicalKeyboardKey.keyG,
      modifiers: [LogicalKeyboardKey.metaLeft, LogicalKeyboardKey.altLeft],
    );

    expect(find.text('Aperte a combinação'), findsNothing);
    expect(find.textContaining('duas modificadoras'), findsNothing);
  });

  testWidgets('a tecla de outro módulo é recusada com o nome do dono', (
    tester,
  ) async {
    await pump(tester);
    await startRecording(tester);

    await press(
      tester,
      LogicalKeyboardKey.keyE,
      modifiers: [LogicalKeyboardKey.metaLeft, LogicalKeyboardKey.shiftLeft],
    );

    expect(find.textContaining('já é o atalho do Echo'), findsOneWidget);
  });

  testWidgets('Esc cancela sem gravar', (tester) async {
    await pump(tester);
    await startRecording(tester);

    await press(tester, LogicalKeyboardKey.escape);

    expect(find.text('Aperte a combinação'), findsNothing);
    expect(find.text('Alterar'), findsOneWidget);
    expect(preferences.getKeys(), isEmpty);
  });

  testWidgets('restaurar devolve a combinação de fábrica', (tester) async {
    await pump(tester);
    await startRecording(tester);
    await press(
      tester,
      LogicalKeyboardKey.keyG,
      modifiers: [LogicalKeyboardKey.metaLeft, LogicalKeyboardKey.altLeft],
    );

    await tester.tap(find.text('Restaurar'));
    await tester.pumpAndSettle();

    expect(find.text('C'), findsOneWidget);
    expect(find.text('Restaurar'), findsNothing);
    expect(preferences.getKeys(), isEmpty);
  });

  testWidgets('gravar suspende os atalhos globais e os devolve no fim', (
    tester,
  ) async {
    await pump(tester);
    await startRecording(tester);

    // Suspensos **antes** de a tela dizer que está à escuta: sem isso, apertar
    // ⌘⇧C para gravar abriria o painel do Pin por cima desta tela.
    expect(notifier.suspensions, [true]);

    await press(
      tester,
      LogicalKeyboardKey.keyG,
      modifiers: [LogicalKeyboardKey.metaLeft, LogicalKeyboardKey.altLeft],
    );

    expect(notifier.suspensions, [true, false]);
    expect(notifier.reapplied, 1);
  });
}
