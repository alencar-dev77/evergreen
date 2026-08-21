import 'package:evergreen/app/providers.dart';
import 'package:evergreen/core/design/app_theme.dart';
import 'package:evergreen/core/storage/app_database.dart';
import 'package:evergreen/core/window/overlay_window.dart';
import 'package:evergreen/features/echo/data/echo_repository.dart';
import 'package:evergreen/features/echo/presentation/views/echo_overlay_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';

import 'fake_echo_channel.dart';

void main() {
  late SharedPreferences preferences;
  late Database db;

  setUp(() async {
    OverlayWindow.instance.resetForTest();
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    db = sqlite3.openInMemory();
    AppDatabase.migrate(db);
  });

  tearDown(() => db.close());

  Future<void> pumpPanel(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          echoChannelProvider.overrideWithValue(FakeEchoChannel()),
          echoRepositoryProvider.overrideWithValue(SqliteEchoRepository(db)),
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
        child: MaterialApp(
          theme: AppTheme.build(),
          home: const EchoOverlayView(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// `OverlayWindow.hide` começa avisando o lado nativo (`beginHide`), então é
  /// essa chamada que diz "o painel está indo embora" sem precisar de janela de
  /// verdade no ambiente de teste.
  List<String> watchClosing() {
    final calls = <String>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const channel = MethodChannel('previous_app_focus');

    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    return calls;
  }

  testWidgets('Esc fecha o painel', (tester) async {
    final closing = watchClosing();
    await pumpPanel(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(closing, contains('beginHide'));
  });

  /// O Echo não tem campo de texto — quem segura o teclado é o próprio painel
  /// —, então o clique não tem como levar o foco embora. O teste prende isso
  /// com um teste, e não com herança de casca, como nos outros quatro painéis.
  testWidgets('clicar no painel não emudece o Esc', (tester) async {
    final closing = watchClosing();
    await pumpPanel(tester);

    await tester.tapAt(tester.getCenter(find.text('Antes de gravar')));
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(closing, contains('beginHide'));
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
}
